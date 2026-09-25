-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: 20260920_admin_security_definer_rpcs.sql
-- Description: SECURITY DEFINER RPCs for administrative writes with server-side
--              JWT admin verification (auth.jwt() ->> 'email') against admin_users.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. RPC: admin_update_payment_provider ─────────────────────────────────
CREATE OR REPLACE FUNCTION admin_update_payment_provider(
  p_code                 text,
  p_enabled              boolean  DEFAULT null,
  p_supported_currencies text[]   DEFAULT null,
  p_allowed_countries    text[]   DEFAULT null,
  p_priority             integer  DEFAULT null,
  p_display_name         text     DEFAULT null
) RETURNS payment_providers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_updated payment_providers;
BEGIN
  -- 1. Server-side caller identity verification from JWT
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users 
    WHERE email = v_caller_email 
      AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  -- 2. Validate p_code
  IF p_code IS NULL OR trim(p_code) = '' THEN
    RAISE EXCEPTION 'Invalid parameter: p_code is required';
  END IF;

  -- 3. Atomic update with pass-through semantics (NULL leaves column unchanged)
  UPDATE payment_providers
  SET
    enabled              = COALESCE(p_enabled, enabled),
    supported_currencies = COALESCE(p_supported_currencies, supported_currencies),
    allowed_countries    = COALESCE(p_allowed_countries, allowed_countries),
    priority             = COALESCE(p_priority, priority),
    display_name         = COALESCE(p_display_name, display_name),
    updated_at           = now()
  WHERE code = p_code
  RETURNING * INTO v_updated;

  -- 4. Check matching row
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment provider with code % not found', p_code;
  END IF;

  RETURN v_updated;
END;
$$;

-- ── 2. RPC: admin_upsert_plan_price ───────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_upsert_plan_price(
  p_plan_code     text,
  p_currency      text,
  p_amount_minor  integer
) RETURNS plan_prices
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_result plan_prices;
BEGIN
  -- Verify admin identity
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users 
    WHERE email = v_caller_email 
      AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  IF p_plan_code IS NULL OR trim(p_plan_code) = '' OR p_currency IS NULL OR trim(p_currency) = '' THEN
    RAISE EXCEPTION 'Invalid parameters: plan_code and currency are required';
  END IF;

  INSERT INTO plan_prices (plan_code, currency, amount_minor, updated_at)
  VALUES (p_plan_code, upper(trim(p_currency)), p_amount_minor, now())
  ON CONFLICT (plan_code, currency)
  DO UPDATE SET
    amount_minor = EXCLUDED.amount_minor,
    updated_at = now()
  RETURNING * INTO v_result;

  RETURN v_result;
END;
$$;

-- ── 3. RPC: admin_delete_plan_price ───────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_delete_plan_price(
  p_plan_code text,
  p_currency  text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users 
    WHERE email = v_caller_email 
      AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  DELETE FROM plan_prices
  WHERE plan_code = p_plan_code AND currency = upper(trim(p_currency));

  RETURN true;
END;
$$;

-- ── 4. RPC: admin_upsert_subscription_plan ────────────────────────────────
CREATE OR REPLACE FUNCTION admin_upsert_subscription_plan(
  p_code                  text,
  p_name_en               text     DEFAULT null,
  p_name_ur               text     DEFAULT null,
  p_price_pkr             integer  DEFAULT null,
  p_max_orders_per_month  integer  DEFAULT null,
  p_max_active_customers  integer  DEFAULT null,
  p_trial_days            integer  DEFAULT null,
  p_sort_order            integer  DEFAULT null,
  p_is_active             boolean  DEFAULT null
) RETURNS subscription_plans
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_result subscription_plans;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users 
    WHERE email = v_caller_email 
      AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  IF p_code IS NULL OR trim(p_code) = '' THEN
    RAISE EXCEPTION 'Invalid parameter: p_code is required';
  END IF;

  INSERT INTO subscription_plans (
    code, name_en, name_ur, price_pkr, max_orders_per_month,
    max_active_customers, trial_days, sort_order, is_active, updated_at
  ) VALUES (
    p_code, p_name_en, p_name_ur, p_price_pkr, p_max_orders_per_month,
    p_max_active_customers, p_trial_days, p_sort_order, COALESCE(p_is_active, true), now()
  )
  ON CONFLICT (code)
  DO UPDATE SET
    name_en              = COALESCE(EXCLUDED.name_en, subscription_plans.name_en),
    name_ur              = COALESCE(EXCLUDED.name_ur, subscription_plans.name_ur),
    price_pkr            = COALESCE(EXCLUDED.price_pkr, subscription_plans.price_pkr),
    max_orders_per_month = COALESCE(EXCLUDED.max_orders_per_month, subscription_plans.max_orders_per_month),
    max_active_customers = COALESCE(EXCLUDED.max_active_customers, subscription_plans.max_active_customers),
    trial_days           = COALESCE(EXCLUDED.trial_days, subscription_plans.trial_days),
    sort_order           = COALESCE(EXCLUDED.sort_order, subscription_plans.sort_order),
    is_active            = COALESCE(EXCLUDED.is_active, subscription_plans.is_active),
    updated_at           = now()
  RETURNING * INTO v_result;

  RETURN v_result;
END;
$$;

-- ── 5. RPC: admin_update_app_setting ──────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_update_app_setting(
  p_key   text,
  p_value text
) RETURNS app_settings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_result app_settings;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM admin_users 
    WHERE email = v_caller_email 
      AND (role = 'superadmin' OR role = 'admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  IF p_key IS NULL OR trim(p_key) = '' THEN
    RAISE EXCEPTION 'Invalid parameter: p_key is required';
  END IF;

  INSERT INTO app_settings (key, value, updated_at)
  VALUES (p_key, p_value, now())
  ON CONFLICT (key)
  DO UPDATE SET
    value = EXCLUDED.value,
    updated_at = now()
  RETURNING * INTO v_result;

  RETURN v_result;
END;
$$;

-- ── 6. RLS Hardening for Audit Tables ─────────────────────────────────────
-- Ensure subscription_plans and app_settings are locked down from direct anon/client writes,
-- while maintaining SELECT access for normal app runtime operations.

ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS subscription_plans_read_all ON subscription_plans;
CREATE POLICY subscription_plans_read_all ON subscription_plans
  FOR SELECT TO authenticated, anon USING (true);

ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_settings_read_all ON app_settings;
CREATE POLICY app_settings_read_all ON app_settings
  FOR SELECT TO authenticated, anon USING (true);
