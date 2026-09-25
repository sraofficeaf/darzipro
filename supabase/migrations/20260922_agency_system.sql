-- Migration: 20260922_agency_system.sql
-- Description: Replaces the 4-level Invite & Earn MLM system with the single-level Agency reseller system.

-- 1. DROP OLD MULTI-LEVEL TABLES & OBSOLETE COLUMNS
DROP TABLE IF EXISTS profit_earnings CASCADE;
DROP TABLE IF EXISTS profit_payouts CASCADE;

DROP POLICY IF EXISTS shop_read_invited ON shops;

ALTER TABLE shops DROP CONSTRAINT IF EXISTS shops_invite_level_unlocked_check;
ALTER TABLE shops DROP COLUMN IF EXISTS invite_level_unlocked;
ALTER TABLE shops DROP COLUMN IF EXISTS invited_by_code;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS city text;

-- 2. CREATE agency_profiles
CREATE TABLE IF NOT EXISTS agency_profiles (
  shop_id uuid PRIMARY KEY REFERENCES shops(id) ON DELETE CASCADE,
  agency_code text UNIQUE NOT NULL,
  display_name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  activated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deactivated_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- 3. CREATE agency_rate_history WITH EXCLUSION CONSTRAINT (CORRECTION A)
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE IF NOT EXISTS agency_rate_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_shop_id uuid NOT NULL REFERENCES agency_profiles(shop_id) ON DELETE CASCADE,
  percent numeric(5,2) NOT NULL CHECK (percent >= 0 AND percent <= 100),
  effective_from date NOT NULL,
  effective_to date,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT agency_rate_valid_range CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

ALTER TABLE agency_rate_history
  DROP CONSTRAINT IF EXISTS agency_rate_no_overlap;

ALTER TABLE agency_rate_history
  ADD CONSTRAINT agency_rate_no_overlap
  EXCLUDE USING gist (
    agency_shop_id WITH =,
    daterange(effective_from, COALESCE(effective_to, 'infinity'::date), '[]') WITH &&
  );

-- 4. LINK shops TO agency_profiles
ALTER TABLE shops ADD COLUMN IF NOT EXISTS agency_shop_id uuid REFERENCES agency_profiles(shop_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_shops_agency_shop_id ON shops(agency_shop_id);

-- 5. CREATE agency_payouts
CREATE TABLE IF NOT EXISTS agency_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_shop_id uuid NOT NULL REFERENCES agency_profiles(shop_id) ON DELETE CASCADE,
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  currency text NOT NULL DEFAULT 'PKR',
  status text NOT NULL CHECK (status IN ('requested', 'approved', 'paid', 'rejected')),
  method text,
  reference text,
  notes text,
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  approved_at timestamptz,
  paid_at timestamptz,
  processed_by text
);
CREATE INDEX IF NOT EXISTS idx_agency_payouts_agency ON agency_payouts(agency_shop_id);

-- 6. CREATE agency_earnings
CREATE TABLE IF NOT EXISTS agency_earnings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_shop_id uuid NOT NULL REFERENCES agency_profiles(shop_id) ON DELETE CASCADE,
  source_shop_id uuid NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  unified_payment_id uuid NOT NULL UNIQUE REFERENCES unified_payments(id) ON DELETE RESTRICT,
  payment_amount_minor bigint NOT NULL,
  percent_applied numeric(5,2) NOT NULL,
  earning_minor bigint NOT NULL,
  currency text NOT NULL,
  status text NOT NULL CHECK (status IN ('pending', 'available', 'paid')),
  available_at timestamptz NOT NULL,
  paid_at timestamptz,
  payout_id uuid REFERENCES agency_payouts(id) ON DELETE SET NULL,
  is_test boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS idx_agency_earnings_agency ON agency_earnings(agency_shop_id);
CREATE INDEX IF NOT EXISTS idx_agency_earnings_status ON agency_earnings(status);

-- 7. PROMOTION HELPER & CRON JOB (CORRECTION B)
CREATE OR REPLACE FUNCTION public.promote_available_agency_earnings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE agency_earnings
  SET status = 'available'
  WHERE status = 'pending'
    AND available_at <= clock_timestamp();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Register hourly cron promotion job
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'promote-available-agency-earnings';
    PERFORM cron.schedule(
      'promote-available-agency-earnings',
      '0 * * * *',
      'SELECT public.promote_available_agency_earnings();'
    );
  END IF;
END $$;

-- 8. REWRITE fulfill_payment (INTEGRATES PART 3 & CORRECTION C)
CREATE OR REPLACE FUNCTION public.fulfill_payment(
  p_payment_id uuid,
  p_is_test boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payment               unified_payments%ROWTYPE;
  v_now                   timestamptz := clock_timestamp();
  v_free_months           int;
  v_storage_gb            numeric;
  v_free_until            date;
  v_storage_bytes         bigint;
  v_raw_plan_code         text;
  v_new_plan_code         text;
  v_is_test               boolean;
  v_shop_is_test          boolean := false;
  v_current_plan_code     text;
  v_paying_agency_shop_id uuid;
  v_agency_is_active      boolean := false;
  v_payment_date          date;
  v_agency_percent        numeric(5,2);
  v_earning_minor         bigint;
  v_payout_delay_days     int;
  v_available_at          timestamptz;
BEGIN
  -- 1. Lock payment row
  SELECT * INTO v_payment FROM unified_payments WHERE id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_not_found');
  END IF;

  v_is_test := COALESCE(p_is_test, false) OR COALESCE(v_payment.is_test, false);

  -- Check if shop is marked as a test shop, fetch current plan and agency attribution
  SELECT COALESCE(is_test, false), plan_code, agency_shop_id
  INTO v_shop_is_test, v_current_plan_code, v_paying_agency_shop_id
  FROM shops WHERE id = v_payment.shop_id;

  -- 2. Idempotency Check: if already succeeded and completed, exit cleanly
  IF v_payment.status = 'succeeded' AND v_payment.completed_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_fulfilled', true,
      'purpose', v_payment.purpose
    );
  END IF;

  -- 3. Mark payment as succeeded in unified_payments
  UPDATE unified_payments
  SET status = 'succeeded',
      completed_at = v_now,
      reviewed_at = COALESCE(reviewed_at, v_now)
  WHERE id = p_payment_id;

  -- 4. Guard: Test payments must NEVER grant subscription time or alter plans on live shops
  IF v_is_test IS TRUE AND v_shop_is_test IS NOT TRUE THEN
    INSERT INTO admin_audit_logs (
      severity, category, shop_id, payment_id, title, message, metadata
    ) VALUES (
      'critical',
      'payment_test_bypass',
      v_payment.shop_id,
      p_payment_id,
      'Test Payment Bypassed on Live Shop',
      'Payment marked succeeded in ledger but subscription was NOT extended because is_test=true was received on a live shop (shop_id: ' || v_payment.shop_id || '). If this was a genuine customer payment, check payment_providers config mode immediately.',
      jsonb_build_object(
        'payment_id', p_payment_id,
        'provider_code', v_payment.provider_code,
        'amount_minor', v_payment.amount_minor,
        'currency', v_payment.currency,
        'provider_reference', v_payment.provider_reference
      )
    );

    UPDATE unified_payments
    SET failure_reason = 'BYPASSED_TEST_PAYMENT_ON_LIVE_SHOP'
    WHERE id = p_payment_id;

    RETURN jsonb_build_object(
      'success', true,
      'payment_id', p_payment_id,
      'purpose', v_payment.purpose,
      'test_payment_recorded', true,
      'live_shop_bypassed', true,
      'admin_alert_created', true
    );
  END IF;

  -- 5. Route business logic by purpose (Real payments OR test payments on designated test shops)

  -- Founding Activation is strictly driven by purpose = 'foundingActivation' OR explicit plan_code = 'founding' (NEVER by price)
  IF v_payment.purpose = 'foundingActivation'
     OR (v_payment.purpose = 'subscriptionMonthly' AND v_payment.metadata->>'plan_code' = 'founding') THEN
    BEGIN
      SELECT COALESCE(NULLIF(value, ''), '6')::int INTO v_free_months
      FROM app_settings WHERE key = 'founding_free_months';
    EXCEPTION WHEN OTHERS THEN
      v_free_months := 6;
    END;

    BEGIN
      SELECT COALESCE(NULLIF(value, ''), '5')::numeric INTO v_storage_gb
      FROM app_settings WHERE key = 'founding_storage_limit_gb';
    EXCEPTION WHEN OTHERS THEN
      v_storage_gb := 5;
    END;

    v_free_months   := COALESCE(v_free_months, 6);
    v_storage_gb    := COALESCE(v_storage_gb, 5);
    v_free_until    := (CURRENT_DATE + (v_free_months || ' months')::interval)::date;
    v_storage_bytes := (v_storage_gb * 1073741824)::bigint;

    UPDATE shops SET
      plan_code                    = 'founding',
      subscription_status          = 'founding',
      founding_activated_at        = v_now,
      founding_free_until          = v_free_until,
      founding_storage_limit_bytes = v_storage_bytes,
      billing_cycle_start          = CURRENT_DATE,
      billing_cycle_end            = v_free_until
    WHERE id = v_payment.shop_id;

    INSERT INTO shop_usage_cycles
      (shop_id, cycle_start, cycle_end, orders_count, plan_code_at_start, amount_due_pkr, payment_status)
    VALUES
      (v_payment.shop_id, CURRENT_DATE, v_free_until, 0, 'founding', 0, 'waived')
    ON CONFLICT (shop_id, cycle_start) DO NOTHING;

  ELSIF v_payment.purpose = 'subscriptionMonthly' THEN
    v_raw_plan_code := NULLIF(v_payment.metadata->>'plan_code', '');

    -- Validate raw plan_code against subscription_plans table
    IF v_raw_plan_code IS NOT NULL THEN
      SELECT code INTO v_new_plan_code
      FROM subscription_plans
      WHERE code = v_raw_plan_code AND is_active = true
      LIMIT 1;
    END IF;

    -- If plan_code is missing or invalid: DO NOT guess from price.
    -- Leave the shop's plan unchanged, mark payment for review, and write to admin_audit_logs.
    IF v_new_plan_code IS NULL THEN
      v_new_plan_code := v_current_plan_code;

      INSERT INTO admin_audit_logs (
        severity, category, shop_id, payment_id, title, message, metadata
      ) VALUES (
        'warning',
        'payment_missing_plan_code',
        v_payment.shop_id,
        p_payment_id,
        'Payment Missing Plan Code',
        'Payment received without a valid plan_code in metadata. Shop plan was left unchanged (' || COALESCE(v_current_plan_code, 'none') || '). Please review the payment and manually set plan if necessary.',
        jsonb_build_object(
          'payment_id', p_payment_id,
          'provider_code', v_payment.provider_code,
          'amount_minor', v_payment.amount_minor,
          'currency', v_payment.currency,
          'raw_plan_code_received', v_raw_plan_code,
          'metadata', v_payment.metadata
        )
      );

      UPDATE unified_payments
      SET failure_reason = 'MISSING_PLAN_CODE_RETAINED_CURRENT_PLAN'
      WHERE id = p_payment_id;
    END IF;

    -- Extend billing cycle end date by 1 month and activate shop (plan_code is set to validated new plan or retained current plan)
    UPDATE shops SET
      subscription_status = 'active',
      plan_code = COALESCE(v_new_plan_code, plan_code),
      billing_cycle_start = COALESCE(billing_cycle_start, CURRENT_DATE),
      billing_cycle_end = CASE
        WHEN billing_cycle_end IS NULL OR billing_cycle_end < CURRENT_DATE
          THEN (CURRENT_DATE + INTERVAL '1 month')::date
        ELSE (billing_cycle_end + INTERVAL '1 month')::date
      END
    WHERE id = v_payment.shop_id;

    -- Update linked usage cycle to paid
    IF v_payment.usage_cycle_id IS NOT NULL THEN
      UPDATE shop_usage_cycles SET
        payment_status = 'paid',
        paid_at = v_now,
        amount_due_pkr = 0
      WHERE id = v_payment.usage_cycle_id;
    ELSE
      -- Update current pending cycle if found
      UPDATE shop_usage_cycles SET
        payment_status = 'paid',
        paid_at = v_now,
        amount_due_pkr = 0
      WHERE shop_id = v_payment.shop_id
        AND payment_status = 'pending'
        AND cycle_start <= CURRENT_DATE AND cycle_end >= CURRENT_DATE;

      IF NOT FOUND THEN
        -- Insert active cycle if none existed
        INSERT INTO shop_usage_cycles
          (shop_id, cycle_start, cycle_end, orders_count, plan_code_at_start, amount_due_pkr, payment_status, paid_at)
        SELECT
          v_payment.shop_id,
          CURRENT_DATE,
          (CURRENT_DATE + INTERVAL '1 month')::date,
          0,
          COALESCE(v_new_plan_code, plan_code, 'basic'),
          0,
          'paid',
          v_now
        FROM shops WHERE id = v_payment.shop_id
        ON CONFLICT (shop_id, cycle_start) DO UPDATE
        SET payment_status = 'paid',
            paid_at = v_now,
            amount_due_pkr = 0;
      END IF;
    END IF;

  ELSIF v_payment.purpose = 'storageMonthly' THEN
    UPDATE shops SET
      storage_addon_active = true,
      storage_addon_type = 'monthly',
      storage_addon_status = 'active',
      storage_addon_cycle_end = CASE
        WHEN storage_addon_cycle_end IS NULL OR storage_addon_cycle_end < CURRENT_DATE
          THEN (CURRENT_DATE + INTERVAL '1 month')::date
        ELSE (storage_addon_cycle_end + INTERVAL '1 month')::date
      END
    WHERE id = v_payment.shop_id;

  ELSIF v_payment.purpose = 'storageAnnual' THEN
    UPDATE shops SET
      storage_addon_active = true,
      storage_addon_type = 'annual',
      storage_addon_status = 'active',
      storage_addon_cycle_end = CASE
        WHEN storage_addon_cycle_end IS NULL OR storage_addon_cycle_end < CURRENT_DATE
          THEN (CURRENT_DATE + INTERVAL '1 year')::date
        ELSE (storage_addon_cycle_end + INTERVAL '1 year')::date
      END
    WHERE id = v_payment.shop_id;

  END IF;

  -- 6. AGENCY PROFIT CALCULATION (PART 3 & CORRECTION C)
  -- Conditions:
  -- 1. Payment is succeeded (asserted in step 3)
  -- 2. Purpose is subscriptionMonthly or foundingActivation
  -- 3. is_test is false (test payments never create agency earnings)
  -- 4. Not bypassed by live-shop guard
  -- 5. Paying shop has a non-null agency_shop_id
  -- 6. Agency exists in agency_profiles and is_active = true
  -- 7. agency_shop_id <> source_shop_id (agencies never earn from their own payments)
  -- 8. No agency_earnings row already exists for this unified_payment_id
  IF v_is_test IS NOT TRUE
     AND (v_payment.purpose IN ('subscriptionMonthly', 'foundingActivation'))
     AND (v_payment.failure_reason IS NULL OR v_payment.failure_reason <> 'BYPASSED_TEST_PAYMENT_ON_LIVE_SHOP')
     AND v_paying_agency_shop_id IS NOT NULL
     AND v_paying_agency_shop_id <> v_payment.shop_id
     AND NOT EXISTS (SELECT 1 FROM agency_earnings WHERE unified_payment_id = p_payment_id)
  THEN
    -- Check if agency is active
    SELECT is_active INTO v_agency_is_active
    FROM agency_profiles
    WHERE shop_id = v_paying_agency_shop_id;

    IF v_agency_is_active IS TRUE THEN
      v_payment_date := (v_now)::date;

      -- Resolve percentage from agency_rate_history using payment date
      SELECT percent INTO v_agency_percent
      FROM agency_rate_history
      WHERE agency_shop_id = v_paying_agency_shop_id
        AND effective_from <= v_payment_date
        AND (effective_to IS NULL OR effective_to >= v_payment_date)
      ORDER BY effective_from DESC
      LIMIT 1;

      -- If no rate is in force, DO NOT guess and DO NOT fallback to default.
      -- Write admin_audit_logs row and create no earning.
      IF v_agency_percent IS NULL THEN
        INSERT INTO admin_audit_logs (
          severity, category, shop_id, payment_id, title, message, metadata
        ) VALUES (
          'warning',
          'agency_missing_rate',
          v_paying_agency_shop_id,
          p_payment_id,
          'Agency Earning Skipped - Missing Rate',
          'Attributed shop completed payment but agency (shop_id: ' || v_paying_agency_shop_id || ') has no effective rate row for date ' || v_payment_date || '. No agency earning created.',
          jsonb_build_object(
            'payment_id', p_payment_id,
            'agency_shop_id', v_paying_agency_shop_id,
            'source_shop_id', v_payment.shop_id,
            'amount_minor', v_payment.amount_minor,
            'payment_date', v_payment_date
          )
        );
      ELSE
        -- Integer arithmetic: platform absorbs fractional remainder via floor
        v_earning_minor := floor((v_payment.amount_minor * v_agency_percent) / 100.0)::bigint;

        -- Read payout_delay_days from app_settings (Correction B: explicit key lookup with fallback). If missing, log warning and use 0.
        SELECT NULLIF(value, '')::int INTO v_payout_delay_days
        FROM app_settings WHERE key = 'agency_payout_delay_days';

        IF v_payout_delay_days IS NULL THEN
          SELECT NULLIF(value, '')::int INTO v_payout_delay_days
          FROM app_settings WHERE key = 'payout_delay_days';
        END IF;

        IF v_payout_delay_days IS NULL THEN
          INSERT INTO admin_audit_logs (
            severity, category, shop_id, payment_id, title, message, metadata
          ) VALUES (
            'warning',
            'missing_setting',
            v_payment.shop_id,
            p_payment_id,
            'Missing payout_delay_days Setting',
            'app_settings key payout_delay_days is missing. Earning was made immediately available (delay = 0 days).',
            jsonb_build_object('payment_id', p_payment_id)
          );
          v_payout_delay_days := 0;
        END IF;

        v_available_at := v_now + (v_payout_delay_days || ' days')::interval;

        INSERT INTO agency_earnings (
          agency_shop_id,
          source_shop_id,
          unified_payment_id,
          payment_amount_minor,
          percent_applied,
          earning_minor,
          currency,
          status,
          available_at,
          is_test
        ) VALUES (
          v_paying_agency_shop_id,
          v_payment.shop_id,
          p_payment_id,
          v_payment.amount_minor,
          v_agency_percent,
          v_earning_minor,
          v_payment.currency,
          CASE WHEN v_available_at <= v_now THEN 'available' ELSE 'pending' END,
          v_available_at,
          false
        )
        ON CONFLICT (unified_payment_id) DO NOTHING;
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', p_payment_id,
    'purpose', v_payment.purpose,
    'is_test', v_is_test
  );
END;
$$;

-- 9. ADMIN RPCS (PART 5 & CORRECTION A)

-- 9a. Grant Agency Role
CREATE OR REPLACE FUNCTION public.admin_grant_agency_role(
  p_shop_id uuid,
  p_agency_code text,
  p_display_name text,
  p_initial_percent numeric
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
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated admin session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Forbidden: Not an admin user';
  END IF;

  -- Validate percent
  IF p_initial_percent < 0 OR p_initial_percent > 100 THEN
    RAISE EXCEPTION 'Invalid percentage: must be between 0 and 100';
  END IF;

  -- Insert profile
  INSERT INTO agency_profiles (shop_id, agency_code, display_name, is_active, activated_at, notes)
  VALUES (p_shop_id, UPPER(TRIM(p_agency_code)), TRIM(p_display_name), true, clock_timestamp(), 'Granted by ' || v_caller_email)
  ON CONFLICT (shop_id) DO UPDATE
  SET agency_code = UPPER(TRIM(p_agency_code)),
      display_name = TRIM(p_display_name),
      is_active = true,
      deactivated_at = NULL,
      updated_at = clock_timestamp();

  -- Insert initial rate row starting from current date
  INSERT INTO agency_rate_history (agency_shop_id, percent, effective_from, effective_to, created_by)
  VALUES (p_shop_id, p_initial_percent, CURRENT_DATE, NULL, v_caller_email)
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object('success', true, 'shop_id', p_shop_id, 'agency_code', UPPER(TRIM(p_agency_code)));
END;
$$;

-- 9b. Revoke Agency Role
CREATE OR REPLACE FUNCTION public.admin_revoke_agency_role(
  p_agency_shop_id uuid
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
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated admin session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Forbidden: Not an admin user';
  END IF;

  UPDATE agency_profiles
  SET is_active = false,
      deactivated_at = clock_timestamp(),
      updated_at = clock_timestamp()
  WHERE shop_id = p_agency_shop_id;

  RETURN jsonb_build_object('success', true, 'agency_shop_id', p_agency_shop_id);
END;
$$;

-- 9c. Update Agency Rate (CORRECTION A: strictly handles multiple changes in same month)
CREATE OR REPLACE FUNCTION public.admin_update_agency_rate(
  p_agency_shop_id uuid,
  p_new_percent numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email    text;
  v_is_admin        boolean;
  v_next_month      date;
  v_cur_month_end   date;
  v_existing_future uuid;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated admin session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin'))
  INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Forbidden: Not an admin user';
  END IF;

  IF p_new_percent < 0 OR p_new_percent > 100 THEN
    RAISE EXCEPTION 'Invalid percentage: must be between 0 and 100';
  END IF;

  v_next_month := (date_trunc('month', CURRENT_DATE) + interval '1 month')::date;
  v_cur_month_end := (v_next_month - interval '1 day')::date;

  -- Check if a pending rate row starting on the 1st of next month already exists (Correction A)
  SELECT id INTO v_existing_future
  FROM agency_rate_history
  WHERE agency_shop_id = p_agency_shop_id
    AND effective_from = v_next_month;

  IF v_existing_future IS NOT NULL THEN
    -- Update existing future row instead of closing/inserting again (Correction D: populate updated_by & updated_at)
    UPDATE agency_rate_history
    SET percent = p_new_percent,
        updated_by = v_caller_email,
        updated_at = clock_timestamp()
    WHERE id = v_existing_future;
  ELSE
    -- Close current active row at the end of current month
    UPDATE agency_rate_history
    SET effective_to = v_cur_month_end,
        updated_by = v_caller_email,
        updated_at = clock_timestamp()
    WHERE agency_shop_id = p_agency_shop_id
      AND effective_to IS NULL;

    -- Insert new row effective the 1st of next month
    INSERT INTO agency_rate_history (agency_shop_id, percent, effective_from, effective_to, created_by, created_at)
    VALUES (p_agency_shop_id, p_new_percent, v_next_month, NULL, v_caller_email, clock_timestamp());
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'agency_shop_id', p_agency_shop_id,
    'new_percent', p_new_percent,
    'effective_from', v_next_month
  );
END;
$$;

-- 9d. Assign Shop to Agency
CREATE OR REPLACE FUNCTION public.admin_assign_shop_agency(
  p_shop_id uuid,
  p_agency_shop_id uuid
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
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated admin session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Forbidden: Not an admin user';
  END IF;

  IF p_agency_shop_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM agency_profiles WHERE shop_id = p_agency_shop_id) THEN
    RAISE EXCEPTION 'Agency profile not found';
  END IF;

  UPDATE shops
  SET agency_shop_id = p_agency_shop_id
  WHERE id = p_shop_id;

  RETURN jsonb_build_object('success', true, 'shop_id', p_shop_id, 'agency_shop_id', p_agency_shop_id);
END;
$$;

-- 9e. Get All Agencies List for Admin
CREATE OR REPLACE FUNCTION public.admin_get_agencies()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin     boolean;
  v_result       json;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated admin session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Forbidden: Not an admin user';
  END IF;

  PERFORM public.promote_available_agency_earnings();

  SELECT json_agg(a) INTO v_result
  FROM (
    SELECT
      ap.shop_id,
      ap.agency_code,
      ap.display_name,
      ap.is_active,
      ap.activated_at,
      ap.deactivated_at,
      ap.notes,
      s.name as shop_name,
      -- Current percent
      (
        SELECT arh.percent
        FROM agency_rate_history arh
        WHERE arh.agency_shop_id = ap.shop_id
          AND arh.effective_from <= CURRENT_DATE
          AND (arh.effective_to IS NULL OR arh.effective_to >= CURRENT_DATE)
        ORDER BY arh.effective_from DESC
        LIMIT 1
      ) as current_percent,
      -- Pending future percent
      (
        SELECT arh.percent
        FROM agency_rate_history arh
        WHERE arh.agency_shop_id = ap.shop_id
          AND arh.effective_from > CURRENT_DATE
        ORDER BY arh.effective_from ASC
        LIMIT 1
      ) as pending_percent,
      (
        SELECT arh.effective_from
        FROM agency_rate_history arh
        WHERE arh.agency_shop_id = ap.shop_id
          AND arh.effective_from > CURRENT_DATE
        ORDER BY arh.effective_from ASC
        LIMIT 1
      ) as pending_percent_effective_from,
      -- Shops brought stats
      (SELECT count(*) FROM shops WHERE agency_shop_id = ap.shop_id) as shops_count,
      (SELECT count(*) FROM shops WHERE agency_shop_id = ap.shop_id AND subscription_status IN ('active', 'founding', 'lifetime')) as active_shops_count,
      -- Earnings stats (minor units, non-test)
      COALESCE((SELECT SUM(earning_minor) FROM agency_earnings WHERE agency_shop_id = ap.shop_id AND is_test = false), 0) as total_earned_minor,
      COALESCE((SELECT SUM(earning_minor) FROM agency_earnings WHERE agency_shop_id = ap.shop_id AND is_test = false AND status = 'available'), 0) as available_minor,
      COALESCE((SELECT SUM(earning_minor) FROM agency_earnings WHERE agency_shop_id = ap.shop_id AND is_test = false AND status = 'paid'), 0) as paid_minor,
      COALESCE((SELECT SUM(earning_minor) FROM agency_earnings WHERE agency_shop_id = ap.shop_id AND is_test = false AND status = 'pending'), 0) as pending_minor
    FROM agency_profiles ap
    JOIN shops s ON s.id = ap.shop_id
    ORDER BY ap.created_at DESC
  ) a;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- 9f. Admin Process Agency Payout
CREATE OR REPLACE FUNCTION public.admin_process_agency_payout(
  p_payout_id uuid,
  p_action text,
  p_reference text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin     boolean;
  v_payout       agency_payouts%ROWTYPE;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated admin session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Forbidden: Not an admin user';
  END IF;

  SELECT * INTO v_payout FROM agency_payouts WHERE id = p_payout_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout not found';
  END IF;

  IF p_action = 'approve' THEN
    UPDATE agency_payouts
    SET status = 'approved',
        approved_at = clock_timestamp(),
        processed_by = v_caller_email
    WHERE id = p_payout_id;
  ELSIF p_action = 'reject' THEN
    UPDATE agency_payouts
    SET status = 'rejected',
        processed_by = v_caller_email
    WHERE id = p_payout_id;

    -- Release linked earnings back to available
    UPDATE agency_earnings
    SET status = 'available',
        payout_id = NULL
    WHERE payout_id = p_payout_id;
  ELSIF p_action = 'paid' THEN
    UPDATE agency_payouts
    SET status = 'paid',
        paid_at = clock_timestamp(),
        reference = COALESCE(p_reference, reference),
        processed_by = v_caller_email
    WHERE id = p_payout_id;

    -- Mark linked earnings as paid
    UPDATE agency_earnings
    SET status = 'paid',
        paid_at = clock_timestamp()
    WHERE payout_id = p_payout_id;
  ELSE
    RAISE EXCEPTION 'Invalid action: %', p_action;
  END IF;

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', p_action);
END;
$$;

-- 10. AGENCY USER RPCS (PART 4 & CORRECTION D)

-- Helper: assert agency role and return agency profile
CREATE OR REPLACE FUNCTION public.get_current_agency_profile()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shop_id uuid;
  v_res     json;
BEGIN
  v_shop_id := current_shop_id();
  IF v_shop_id IS NULL THEN
    RETURN json_build_object('is_agency', false);
  END IF;

  SELECT json_build_object(
    'is_agency', true,
    'shop_id', ap.shop_id,
    'agency_code', ap.agency_code,
    'display_name', ap.display_name,
    'is_active', ap.is_active,
    'activated_at', ap.activated_at,
    'deactivated_at', ap.deactivated_at
  ) INTO v_res
  FROM agency_profiles ap
  WHERE ap.shop_id = v_shop_id;

  RETURN COALESCE(v_res, json_build_object('is_agency', false));
END;
$$;

-- 10a. Agency Overview
CREATE OR REPLACE FUNCTION public.get_agency_overview()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shop_id       uuid;
  v_ap            agency_profiles%ROWTYPE;
  v_cur_percent   numeric(5,2);
  v_cur_from      date;
  v_pend_percent  numeric(5,2);
  v_pend_from     date;
  v_min_threshold bigint := 500000; -- 5000 PKR in minor
  v_setting_val   text;
BEGIN
  v_shop_id := current_shop_id();
  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: No active shop';
  END IF;

  SELECT * INTO v_ap FROM agency_profiles WHERE shop_id = v_shop_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Forbidden: Not an agency';
  END IF;

  -- Promote available earnings
  PERFORM public.promote_available_agency_earnings();

  -- Rates
  SELECT percent, effective_from INTO v_cur_percent, v_cur_from
  FROM agency_rate_history
  WHERE agency_shop_id = v_shop_id
    AND effective_from <= CURRENT_DATE
    AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
  ORDER BY effective_from DESC LIMIT 1;

  SELECT percent, effective_from INTO v_pend_percent, v_pend_from
  FROM agency_rate_history
  WHERE agency_shop_id = v_shop_id
    AND effective_from > CURRENT_DATE
  ORDER BY effective_from ASC LIMIT 1;

  -- Minimum threshold from app_settings
  SELECT value INTO v_setting_val FROM app_settings WHERE key = 'minimum_payout_threshold';
  IF v_setting_val IS NOT NULL AND v_setting_val ~ '^\d+$' THEN
    v_min_threshold := (v_setting_val::bigint) * 100;
  END IF;

  RETURN json_build_object(
    'is_agency', true,
    'agency_code', v_ap.agency_code,
    'display_name', v_ap.display_name,
    'is_active', v_ap.is_active,
    'current_percent', v_cur_percent,
    'current_rate_effective_from', v_cur_from,
    'pending_percent', v_pend_percent,
    'pending_rate_effective_from', v_pend_from,
    'total_earned_minor', COALESCE((SELECT SUM(earning_minor) FROM agency_earnings WHERE agency_shop_id = v_shop_id AND is_test = false), 0),
    'available_minor', COALESCE((SELECT SUM(earning_minor) FROM agency_earnings WHERE agency_shop_id = v_shop_id AND is_test = false AND status = 'available'), 0),
    'pending_minor', COALESCE((SELECT SUM(earning_minor) FROM agency_earnings WHERE agency_shop_id = v_shop_id AND is_test = false AND status = 'pending'), 0),
    'paid_minor', COALESCE((SELECT SUM(earning_minor) FROM agency_earnings WHERE agency_shop_id = v_shop_id AND is_test = false AND status = 'paid'), 0),
    'total_shops', (SELECT count(*) FROM shops WHERE agency_shop_id = v_shop_id),
    'active_shops', (SELECT count(*) FROM shops WHERE agency_shop_id = v_shop_id AND subscription_status IN ('active', 'founding', 'lifetime')),
    'lapsed_shops', (SELECT count(*) FROM shops WHERE agency_shop_id = v_shop_id AND subscription_status NOT IN ('active', 'founding', 'lifetime')),
    'minimum_payout_threshold_minor', v_min_threshold
  );
END;
$$;

-- 10b. Agency Shops (STRICT PRIVACY ISOLATION - CORRECTION D)
-- Returns name, city, plan, subscription status, date joined, month of last payment, total earned.
-- NEVER returns address, phone, orders, customers, measurements, or shop turnover.
CREATE OR REPLACE FUNCTION public.get_agency_shops()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shop_id uuid;
  v_result  json;
BEGIN
  v_shop_id := current_shop_id();
  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: No active shop';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM agency_profiles WHERE shop_id = v_shop_id) THEN
    RAISE EXCEPTION 'Forbidden: Not an agency';
  END IF;

  SELECT json_agg(s) INTO v_result
  FROM (
    SELECT
      sh.id,
      sh.name,
      COALESCE(sh.city, '') as city,
      sh.plan_code,
      sh.subscription_status,
      sh.created_at as joined_at,
      to_char(
        (SELECT MAX(completed_at) FROM unified_payments up WHERE up.shop_id = sh.id AND up.status = 'succeeded'),
        'Mon YYYY'
      ) as last_payment_month,
      COALESCE((SELECT SUM(ae.earning_minor) FROM agency_earnings ae WHERE ae.source_shop_id = sh.id AND ae.agency_shop_id = v_shop_id AND ae.is_test = false), 0) as total_earned_minor
    FROM shops sh
    WHERE sh.agency_shop_id = v_shop_id
    ORDER BY sh.created_at DESC
  ) s;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- 10c. Agency Earnings List
CREATE OR REPLACE FUNCTION public.get_agency_earnings(p_month text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shop_id uuid;
  v_result  json;
BEGIN
  v_shop_id := current_shop_id();
  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: No active shop';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM agency_profiles WHERE shop_id = v_shop_id) THEN
    RAISE EXCEPTION 'Forbidden: Not an agency';
  END IF;

  PERFORM public.promote_available_agency_earnings();

  SELECT json_agg(e) INTO v_result
  FROM (
    SELECT
      ae.id,
      ae.created_at as earned_at,
      s.name as source_shop_name,
      COALESCE(s.plan_code, 'standard') as plan_code,
      ae.payment_amount_minor,
      ae.percent_applied,
      ae.earning_minor,
      ae.currency,
      ae.status,
      ae.available_at,
      ae.paid_at
    FROM agency_earnings ae
    JOIN shops s ON s.id = ae.source_shop_id
    WHERE ae.agency_shop_id = v_shop_id
      AND ae.is_test = false
      AND (p_month IS NULL OR to_char(ae.created_at, 'YYYY-MM') = p_month)
    ORDER BY ae.created_at DESC
  ) e;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- 10d. Agency Payouts List
CREATE OR REPLACE FUNCTION public.get_agency_payouts()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shop_id uuid;
  v_result  json;
BEGIN
  v_shop_id := current_shop_id();
  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: No active shop';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM agency_profiles WHERE shop_id = v_shop_id) THEN
    RAISE EXCEPTION 'Forbidden: Not an agency';
  END IF;

  SELECT json_agg(p) INTO v_result
  FROM (
    SELECT
      ap.id,
      ap.amount_minor,
      ap.currency,
      ap.status,
      ap.method,
      ap.reference,
      ap.requested_at,
      ap.approved_at,
      ap.paid_at
    FROM agency_payouts ap
    WHERE ap.agency_shop_id = v_shop_id
    ORDER BY ap.requested_at DESC
  ) p;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- 10e. Request Agency Payout
CREATE OR REPLACE FUNCTION public.request_agency_payout(
  p_amount_minor bigint,
  p_method text,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shop_id         uuid;
  v_available_minor bigint;
  v_min_threshold   bigint := 500000;
  v_setting_val     text;
  v_payout_id       uuid;
BEGIN
  v_shop_id := current_shop_id();
  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: No active shop';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM agency_profiles WHERE shop_id = v_shop_id AND is_active = true) THEN
    RAISE EXCEPTION 'Forbidden: Agency role is not active';
  END IF;

  PERFORM public.promote_available_agency_earnings();

  SELECT COALESCE(SUM(earning_minor), 0) INTO v_available_minor
  FROM agency_earnings
  WHERE agency_shop_id = v_shop_id
    AND is_test = false
    AND status = 'available';

  -- Check minimum payout threshold
  SELECT value INTO v_setting_val FROM app_settings WHERE key = 'minimum_payout_threshold';
  IF v_setting_val IS NOT NULL AND v_setting_val ~ '^\d+$' THEN
    v_min_threshold := (v_setting_val::bigint) * 100;
  END IF;

  IF p_amount_minor < v_min_threshold THEN
    RAISE EXCEPTION 'Payout amount is below minimum threshold of Rs %', (v_min_threshold / 100);
  END IF;

  IF p_amount_minor > v_available_minor THEN
    RAISE EXCEPTION 'Requested amount exceeds available balance of Rs %', (v_available_minor / 100);
  END IF;

  INSERT INTO agency_payouts (agency_shop_id, amount_minor, status, method, notes)
  VALUES (v_shop_id, p_amount_minor, 'requested', p_method, p_notes)
  RETURNING id INTO v_payout_id;

  RETURN jsonb_build_object('success', true, 'payout_id', v_payout_id, 'amount_minor', p_amount_minor);
END;
$$;

-- 11. UPDATE get_admin_reports_data FOR AGENCY PROFIT REPORTING
CREATE OR REPLACE FUNCTION public.get_admin_reports_data(
  p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone
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
  v_agency_profit bigint;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated admin session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

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

  -- Total agency profit
  SELECT COALESCE(SUM(ae.earning_minor), 0)
  INTO v_agency_profit
  FROM agency_earnings ae
  WHERE ae.is_test = false
    AND (p_start_date IS NULL OR ae.created_at >= p_start_date)
    AND (p_end_date IS NULL OR ae.created_at <= p_end_date);

  SELECT json_build_object(
    'total_revenue', v_total_rev,
    'total_agency_profit_minor', v_agency_profit,
    'agency_earnings', COALESCE((
      SELECT json_agg(e)
      FROM (
        SELECT
          ae.id,
          ae.agency_shop_id,
          ae.source_shop_id,
          ae.payment_amount_minor,
          ae.percent_applied,
          ae.earning_minor,
          ae.currency,
          ae.status,
          ae.created_at,
          json_build_object('name', ag_s.name) as agency_shop,
          json_build_object('name', src_s.name) as source_shop
        FROM agency_earnings ae
        JOIN shops ag_s ON ag_s.id = ae.agency_shop_id
        JOIN shops src_s ON src_s.id = ae.source_shop_id
        WHERE ae.is_test = false
          AND (p_start_date IS NULL OR ae.created_at >= p_start_date)
          AND (p_end_date IS NULL OR ae.created_at <= p_end_date)
        ORDER BY ae.created_at DESC
      ) e
    ), '[]'::json),
    'agency_payouts', COALESCE((
      SELECT json_agg(p)
      FROM (
        SELECT ap.*, json_build_object('name', sh.name) as agency_shop
        FROM agency_payouts ap
        JOIN shops sh ON sh.id = ap.agency_shop_id
        WHERE (p_start_date IS NULL OR ap.requested_at >= p_start_date)
          AND (p_end_date IS NULL OR ap.requested_at <= p_end_date)
        ORDER BY ap.requested_at DESC
      ) p
    ), '[]'::json),
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
