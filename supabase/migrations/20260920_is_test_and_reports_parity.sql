-- ============================================================
-- Migration: 20260920_is_test_and_reports_parity.sql
-- Description:
--   1. Add is_test boolean column to unified_payments
--   2. Mark existing test rows as is_test = true
--   3. Guard fulfill_payment: skip profit distribution when is_test = true
--   4. Update get_admin_reports_data to filter out test payments and provide total_revenue
-- ============================================================

-- 1. Add is_test column to unified_payments
ALTER TABLE unified_payments
  ADD COLUMN IF NOT EXISTS is_test boolean NOT NULL DEFAULT false;

-- 2. Mark existing test records as is_test = true (targeted by exact UUID)
UPDATE unified_payments
SET is_test = true
WHERE id IN (
  'b6515861-c9cf-4eef-b980-5548c4fc264e',
  '64e88ed8-9953-401a-bb9a-a58cf6b1cac3',
  '737e0e15-7d9d-4cd6-8a05-48025db73ce2'
);

-- 3. Update fulfill_payment to guard profit distribution against test payments
DROP FUNCTION IF EXISTS public.fulfill_payment(uuid);
CREATE OR REPLACE FUNCTION public.fulfill_payment(
  p_payment_id uuid,
  p_is_test    boolean DEFAULT null
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payment           record;
  v_now               timestamptz := now();
  v_free_months       int         := 6;
  v_storage_gb        numeric     := 5;
  v_free_until        date;
  v_storage_bytes     bigint;
  v_level_pcts        numeric[]   := array[0.15, 0.025, 0.015, 0.01];
  v_major_amount      numeric;
  v_curr_shop_id      uuid;
  v_inviter_code      text;
  v_inviter_shop      record;
  v_earning           numeric;
  v_platform_owner_id uuid;
  v_target_inviter_id uuid;
  v_cycle_id          uuid;
BEGIN
  -- 1. Lock payment row
  SELECT * INTO v_payment FROM unified_payments WHERE id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_not_found');
  END IF;

  -- 2. Idempotency Check: if already succeeded and completed, exit cleanly
  IF v_payment.status = 'succeeded' AND v_payment.completed_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_fulfilled', true,
      'purpose', v_payment.purpose
    );
  END IF;

  -- 3. Mark payment as succeeded
  UPDATE unified_payments
  SET status = 'succeeded',
      completed_at = v_now,
      reviewed_at = COALESCE(reviewed_at, v_now),
      is_test = COALESCE(p_is_test, is_test)
  WHERE id = p_payment_id;

  IF p_is_test IS NOT NULL THEN
    v_payment.is_test := p_is_test;
  END IF;

  -- 4. Route business logic by purpose
  IF v_payment.purpose = 'subscriptionMonthly' THEN
    UPDATE shops SET
      subscription_status = 'active',
      billing_cycle_end = CASE
        WHEN billing_cycle_end IS NULL OR billing_cycle_end < current_date
          THEN (current_date + interval '1 month')::date
        ELSE (billing_cycle_end + interval '1 month')::date
      END
    WHERE id = v_payment.shop_id;

    IF v_payment.usage_cycle_id IS NOT NULL THEN
      UPDATE shop_usage_cycles SET
        payment_status = 'paid',
        paid_at = v_now
      WHERE id = v_payment.usage_cycle_id;
    ELSE
      UPDATE shop_usage_cycles SET
        payment_status = 'paid',
        paid_at = v_now
      WHERE shop_id = v_payment.shop_id
        AND payment_status = 'pending'
        AND cycle_start <= current_date AND cycle_end >= current_date;
    END IF;

  ELSIF v_payment.purpose = 'foundingActivation' THEN
    BEGIN
      SELECT COALESCE(NULLIF(value, ''), '6')::int INTO v_free_months
      FROM app_settings WHERE key = 'founding_free_months';
    EXCEPTION WHEN others THEN
      v_free_months := 6;
    END;

    BEGIN
      SELECT COALESCE(NULLIF(value, ''), '5')::numeric INTO v_storage_gb
      FROM app_settings WHERE key = 'founding_storage_limit_gb';
    EXCEPTION WHEN others THEN
      v_storage_gb := 5;
    END;

    v_free_until := (current_date + (v_free_months || ' months')::interval)::date;
    v_storage_bytes := (v_storage_gb * 1024 * 1024 * 1024)::bigint;

    UPDATE shops SET
      plan_code = 'founding',
      subscription_status = 'active',
      founding_activated_at = COALESCE(founding_activated_at, v_now),
      founding_free_until = v_free_until,
      founding_storage_limit_bytes = v_storage_bytes,
      billing_cycle_start = current_date,
      billing_cycle_end = v_free_until
    WHERE id = v_payment.shop_id;

    INSERT INTO shop_usage_cycles
      (shop_id, cycle_start, cycle_end, orders_count, plan_code_at_start, payment_status)
    VALUES
      (v_payment.shop_id, current_date, v_free_until, 0, 'founding', 'waived')
    ON CONFLICT (shop_id, cycle_start) DO NOTHING;

  ELSIF v_payment.purpose = 'storageMonthly' THEN
    UPDATE shops SET
      storage_addon_active = true,
      storage_addon_type = 'monthly',
      storage_addon_expires_at = CASE
        WHEN storage_addon_expires_at IS NULL OR storage_addon_expires_at < v_now
          THEN v_now + interval '1 month'
        ELSE storage_addon_expires_at + interval '1 month'
      END
    WHERE id = v_payment.shop_id;

  ELSIF v_payment.purpose = 'storageAnnual' THEN
    UPDATE shops SET
      storage_addon_active = true,
      storage_addon_type = 'annual',
      storage_addon_expires_at = CASE
        WHEN storage_addon_expires_at IS NULL OR storage_addon_expires_at < v_now
          THEN v_now + interval '1 year'
        ELSE storage_addon_expires_at + interval '1 year'
      END
    WHERE id = v_payment.shop_id;
  END IF;

  -- 5. Multi-Level Invite Profit Calculation (GUARDED: Skip test payments)
  IF COALESCE(v_payment.is_test, false) = true THEN
    RETURN jsonb_build_object(
      'success', true,
      'purpose', v_payment.purpose,
      'is_test', true,
      'profit_sharing_skipped', true
    );
  END IF;

  v_major_amount := round(v_payment.amount_minor / 100.0);

  BEGIN
    SELECT value::uuid INTO v_platform_owner_id
    FROM app_settings WHERE key = 'platform_owner_shop_id';
  EXCEPTION WHEN others THEN
    v_platform_owner_id := null;
  END;

  v_curr_shop_id := v_payment.shop_id;

  FOR lvl IN 1..4 LOOP
    SELECT invited_by_code INTO v_inviter_code
    FROM shops WHERE id = v_curr_shop_id;

    EXIT WHEN v_inviter_code IS NULL OR v_inviter_code = '';

    SELECT id, status, COALESCE(invite_level_unlocked, 1) AS level_unlocked
    INTO v_inviter_shop
    FROM shops WHERE invite_code = v_inviter_code;

    EXIT WHEN NOT FOUND;

    v_target_inviter_id := v_inviter_shop.id;
    IF v_inviter_shop.status = 'deleted' AND v_platform_owner_id IS NOT NULL THEN
      v_target_inviter_id := v_platform_owner_id;
    END IF;

    IF v_inviter_shop.level_unlocked >= lvl THEN
      v_earning := round(v_major_amount * v_level_pcts[lvl]);

      IF v_earning > 0 THEN
        INSERT INTO profit_earnings (
          inviter_shop_id,
          invited_shop_id,
          earning_type,
          amount,
          level,
          status,
          created_at
        ) VALUES (
          v_target_inviter_id,
          v_payment.shop_id,
          v_payment.purpose,
          v_earning::int,
          lvl,
          'pending',
          v_now
        );
      END IF;
    END IF;

    IF v_target_inviter_id = v_platform_owner_id THEN
      EXIT;
    END IF;

    v_curr_shop_id := v_target_inviter_id;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'purpose', v_payment.purpose,
    'payment_id', p_payment_id
  );
END;
$$;

-- 4. Update get_admin_reports_data to exclude is_test payments and return total_revenue
DROP FUNCTION IF EXISTS public.get_admin_reports_data();

CREATE OR REPLACE FUNCTION public.get_admin_reports_data(
  p_start_date timestamptz DEFAULT null,
  p_end_date   timestamptz DEFAULT null
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin     boolean;
  v_result       json;
  v_total_rev    bigint;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF current_user IN ('postgres', 'service_role', 'supabase_admin') THEN
    v_is_admin := true;
  ELSE
    IF v_caller_email IS NULL OR v_caller_email = '' THEN
      RAISE EXCEPTION 'Unauthorized: No authenticated session';
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM admin_users
      WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')
    ) INTO v_is_admin;
  END IF;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Forbidden: Not an admin user';
  END IF;

  -- Total revenue from succeeded non-test payments
  SELECT COALESCE(SUM(round(up.amount_minor / 100.0)), 0)
  INTO v_total_rev
  FROM unified_payments up
  WHERE up.status = 'succeeded'
    AND up.is_test = false
    AND (p_start_date IS NULL OR up.created_at >= p_start_date)
    AND (p_end_date IS NULL OR up.created_at <= p_end_date);

  SELECT json_build_object(
    'total_revenue', v_total_rev,
    'public_registrations', COALESCE((SELECT json_agg(r) FROM public_registrations r WHERE r.status = 'approved'), '[]'::json),
    'upgrades', COALESCE((SELECT json_agg(u) FROM upgrade_requests u WHERE u.status = 'approved'), '[]'::json),
    'storage_payments', COALESCE((SELECT json_agg(s) FROM storage_addon_payments s), '[]'::json),
    'licenses', COALESCE((SELECT json_agg(l) FROM licenses l), '[]'::json),
    'payouts', COALESCE((SELECT json_agg(p) FROM profit_payouts p), '[]'::json),
    'earnings', COALESCE((SELECT json_agg(e) FROM (SELECT pe.*, json_build_object('name', sh.name) AS inviter_shop FROM profit_earnings pe LEFT JOIN shops sh ON sh.id = pe.inviter_shop_id) e), '[]'::json),
    'unified_payments', COALESCE((
      SELECT json_agg(u)
      FROM (
        SELECT up.*, json_build_object('name', s.name) AS shops
        FROM unified_payments up
        LEFT JOIN shops s ON s.id = up.shop_id
        WHERE up.status = 'succeeded'
          AND up.is_test = false
          AND (p_start_date IS NULL OR up.created_at >= p_start_date)
          AND (p_end_date IS NULL OR up.created_at <= p_end_date)
        ORDER BY up.created_at DESC
      ) u
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- 5. RPC: admin_set_payment_test_flag allows admin to flag/unflag manual or any payment as test
CREATE OR REPLACE FUNCTION public.admin_set_payment_test_flag(
  p_payment_id uuid,
  p_is_test    boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin     boolean;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF current_user IN ('postgres', 'service_role', 'supabase_admin') THEN
    v_is_admin := true;
  ELSE
    IF v_caller_email IS NULL OR v_caller_email = '' THEN
      RAISE EXCEPTION 'Unauthorized: No authenticated session';
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM admin_users
      WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')
    ) INTO v_is_admin;
  END IF;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Forbidden: Not an admin user';
  END IF;

  UPDATE unified_payments
  SET is_test = p_is_test
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_not_found');
  END IF;

  RETURN jsonb_build_object('success', true, 'payment_id', p_payment_id, 'is_test', p_is_test);
END;
$$;

-- 6. Trigger to automatically enforce is_test fallback only when omitted (is_test IS NULL)
-- If is_test is explicitly supplied (from Stripe livemode in Edge Functions or admin RPC),
-- the trigger DEFERs completely and NEVER overrides.
ALTER TABLE unified_payments ALTER COLUMN is_test DROP DEFAULT;

CREATE OR REPLACE FUNCTION public.trg_unified_payments_set_test_mode()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_stripe_mode text;
BEGIN
  -- 1. DEFER: If caller explicitly provided is_test (true or false), NEVER override it!
  IF NEW.is_test IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- 2. Fallback only when is_test was omitted (is NULL):
  -- Check metadata livemode if provided
  IF NEW.metadata->>'livemode' IS NOT NULL THEN
    NEW.is_test := NOT (NEW.metadata->>'livemode')::boolean;
    RETURN NEW;
  END IF;

  -- If Stripe provider and mode was omitted, check payment_providers configuration
  IF NEW.provider_code = 'stripe' THEN
    SELECT COALESCE(
      config->>'mode',
      CASE WHEN (config->>'test_mode')::boolean = false THEN 'live' ELSE 'test' END
    )
    INTO v_stripe_mode
    FROM payment_providers
    WHERE code = 'stripe';

    IF v_stripe_mode = 'live' THEN
      NEW.is_test := false;
    ELSE
      NEW.is_test := true;
    END IF;
  ELSE
    -- Other providers (manual, etc.) default to false
    NEW.is_test := false;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_unified_payments_test_flag ON unified_payments;
CREATE TRIGGER trg_unified_payments_test_flag
  BEFORE INSERT OR UPDATE OF provider_code, metadata, is_test ON unified_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_unified_payments_set_test_mode();



