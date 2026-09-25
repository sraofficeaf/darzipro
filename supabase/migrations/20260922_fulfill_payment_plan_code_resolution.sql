-- Migration: 20260922_fulfill_payment_plan_code_resolution.sql
-- Description: Updates fulfill_payment:
-- 1) plan_code is matched strictly from metadata->>'plan_code' (validated against subscription_plans).
-- 2) Never guesses from price or amount.
-- 3) If plan_code is missing/invalid, shop's current plan is left UNCHANGED, payment is marked for review, and an admin_audit_logs warning is written.
-- 4) Founding activation is strictly driven by purpose = 'foundingActivation' or plan_code = 'founding' (never by price/amount).

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
  v_payment           unified_payments%ROWTYPE;
  v_now               timestamptz := clock_timestamp();
  v_free_months       int;
  v_storage_gb        numeric;
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
  v_raw_plan_code     text;
  v_new_plan_code     text;
  v_is_test           boolean;
  v_shop_is_test      boolean := false;
  v_current_plan_code text;
BEGIN
  -- 1. Lock payment row
  SELECT * INTO v_payment FROM unified_payments WHERE id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_not_found');
  END IF;

  v_is_test := COALESCE(p_is_test, false) OR COALESCE(v_payment.is_test, false);

  -- Check if shop is marked as a test shop and fetch current plan
  SELECT COALESCE(is_test, false), plan_code 
  INTO v_shop_is_test, v_current_plan_code 
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

  -- 6. Multi-tier profit calculation (ONLY for real payments, skipped for test payments)
  IF v_is_test IS NOT TRUE THEN
    v_major_amount := (v_payment.amount_minor / 100.0);
    SELECT id INTO v_platform_owner_id FROM shops WHERE is_platform_account = true LIMIT 1;
    v_curr_shop_id := v_payment.shop_id;

    FOR v_level IN 1..4 LOOP
      SELECT invited_by_code INTO v_inviter_code FROM shops WHERE id = v_curr_shop_id;
      EXIT WHEN v_inviter_code IS NULL OR v_inviter_code = '';

      SELECT id, is_platform_account, invite_level_unlocked INTO v_inviter_shop
      FROM shops WHERE invite_code = v_inviter_code;
      EXIT WHEN NOT FOUND;

      v_earning := ROUND(v_major_amount * v_level_pcts[v_level], 2);

      IF v_inviter_shop.invite_level_unlocked >= v_level THEN
        v_target_inviter_id := v_inviter_shop.id;
      ELSE
        v_target_inviter_id := v_platform_owner_id;
      END IF;

      IF v_earning > 0 AND v_target_inviter_id IS NOT NULL THEN
        INSERT INTO profit_earnings (
          unified_payment_id,
          source_shop_id,
          target_shop_id,
          level,
          percentage,
          earning_amount_pkr
        ) VALUES (
          p_payment_id,
          v_payment.shop_id,
          v_target_inviter_id,
          v_level,
          v_level_pcts[v_level] * 100,
          v_earning
        )
        ON CONFLICT (unified_payment_id, level) DO NOTHING;
      END IF;

      v_curr_shop_id := v_inviter_shop.id;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', p_payment_id,
    'purpose', v_payment.purpose,
    'is_test', v_is_test
  );
END;
$$;
