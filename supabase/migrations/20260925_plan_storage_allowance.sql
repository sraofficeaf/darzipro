-- Migration: 20260925_plan_storage_allowance.sql
-- Description:
-- 1. Add storage_allowance_mb to subscription_plans.
-- 2. Seed per-plan storage allowance values:
--    Free Trial: 100 MB, Basic: 250 MB, Standard: 1024 MB (1 GB), Unlimited: 3072 MB (3 GB), Founding: 5120 MB (5 GB).
-- 3. Update admin_upsert_subscription_plan RPC to support storage_allowance_mb.
-- 4. Reprice storage add-on in app_settings (Monthly: 250 PKR, Annual: 2500 PKR per 1 GB).
-- 5. Delete obsolete base_storage_allowance_mb from app_settings.

-- 1. Add column to subscription_plans if not exists
ALTER TABLE subscription_plans
ADD COLUMN IF NOT EXISTS storage_allowance_mb integer NOT NULL DEFAULT 1000;

-- 2. Seed initial per-plan storage allowances
UPDATE subscription_plans SET storage_allowance_mb = 100 WHERE code = 'trial';
UPDATE subscription_plans SET storage_allowance_mb = 250 WHERE code = 'basic';
UPDATE subscription_plans SET storage_allowance_mb = 1024 WHERE code = 'standard';
UPDATE subscription_plans SET storage_allowance_mb = 3072 WHERE code = 'unlimited';
UPDATE subscription_plans SET storage_allowance_mb = 5120 WHERE code = 'founding';

-- 3. Update admin_upsert_subscription_plan RPC
CREATE OR REPLACE FUNCTION admin_upsert_subscription_plan(
  p_code                  text,
  p_name_en               text     DEFAULT null,
  p_name_ur               text     DEFAULT null,
  p_price_pkr             integer  DEFAULT null,
  p_max_orders_per_month  integer  DEFAULT null,
  p_max_active_customers  integer  DEFAULT null,
  p_trial_days            integer  DEFAULT null,
  p_sort_order            integer  DEFAULT null,
  p_is_active             boolean  DEFAULT null,
  p_storage_allowance_mb  integer  DEFAULT null
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
    max_active_customers, trial_days, sort_order, is_active,
    storage_allowance_mb, updated_at
  ) VALUES (
    p_code, p_name_en, p_name_ur, p_price_pkr, p_max_orders_per_month,
    p_max_active_customers, p_trial_days, p_sort_order, COALESCE(p_is_active, true),
    COALESCE(p_storage_allowance_mb, 1000), now()
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
    storage_allowance_mb = COALESCE(EXCLUDED.storage_allowance_mb, subscription_plans.storage_allowance_mb),
    updated_at           = now()
  RETURNING * INTO v_result;

  RETURN v_result;
END;
$$;

-- 4. Reprice storage add-on in app_settings (Rs 250/mo, Rs 2,500/yr per 1 GB)
INSERT INTO app_settings (key, value, is_public, updated_at)
VALUES 
  ('storage_addon_price_monthly', '250', true, now()),
  ('storage_addon_price_annual', '2500', true, now())
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    is_public = true,
    updated_at = now();

-- 5. Remove obsolete global base_storage_allowance_mb
DELETE FROM app_settings WHERE key = 'base_storage_allowance_mb';
