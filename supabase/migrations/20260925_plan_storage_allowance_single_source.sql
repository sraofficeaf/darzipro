-- Migration: 20260925_plan_storage_allowance_single_source.sql
-- Purpose: Store the five exact plan storage allowances in subscription_plans in one column once.
-- Free Trial: 100 MB (104857600 bytes)
-- Basic: 250 MB (262144000 bytes)
-- Standard: 1 GB (1073741824 bytes)
-- Unlimited: 3 GB (3221225472 bytes)
-- Founding Member: 5 GB (5368709120 bytes)

-- 1. Add storage_allowance_bytes to subscription_plans
ALTER TABLE subscription_plans 
ADD COLUMN IF NOT EXISTS storage_allowance_bytes bigint NOT NULL DEFAULT 104857600;

-- 2. Populate the exact byte counts agreed with the owner
UPDATE subscription_plans SET storage_allowance_bytes = 104857600 WHERE code = 'trial';
UPDATE subscription_plans SET storage_allowance_bytes = 262144000 WHERE code = 'basic';
UPDATE subscription_plans SET storage_allowance_bytes = 1073741824 WHERE code = 'standard';
UPDATE subscription_plans SET storage_allowance_bytes = 3221225472 WHERE code = 'unlimited';
UPDATE subscription_plans SET storage_allowance_bytes = 5368709120 WHERE code = 'founding';

-- 3. Drop obsolete storage_allowance_mb so allowance lives in one column, once
ALTER TABLE subscription_plans DROP COLUMN IF EXISTS storage_allowance_mb;

-- 4. Drop older overloaded RPCs and recreate admin_upsert_subscription_plan taking p_storage_allowance_bytes
DROP FUNCTION IF EXISTS public.admin_upsert_subscription_plan(text, text, text, integer, integer, integer, integer, integer, boolean);
DROP FUNCTION IF EXISTS public.admin_upsert_subscription_plan(text, text, text, integer, integer, integer, integer, integer, boolean, integer);
DROP FUNCTION IF EXISTS public.admin_upsert_subscription_plan(text, text, text, integer, integer, integer, integer, integer, boolean, bigint);

CREATE OR REPLACE FUNCTION public.admin_upsert_subscription_plan(
  p_code                  text,
  p_name_en               text,
  p_name_ur               text,
  p_price_pkr             integer,
  p_max_orders_per_month  integer,
  p_max_active_customers  integer,
  p_trial_days            integer,
  p_sort_order            integer,
  p_is_active             boolean,
  p_storage_allowance_bytes bigint DEFAULT null
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_is_admin     boolean := false;
  v_row          subscription_plans%ROWTYPE;
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

  INSERT INTO subscription_plans (
    code, name_en, name_ur, price_pkr,
    max_orders_per_month, max_active_customers,
    trial_days, sort_order, is_active,
    storage_allowance_bytes, updated_at
  )
  VALUES (
    p_code, p_name_en, p_name_ur, p_price_pkr,
    p_max_orders_per_month, p_max_active_customers,
    p_trial_days, p_sort_order, p_is_active,
    COALESCE(p_storage_allowance_bytes, 104857600), now()
  )
  ON CONFLICT (code) DO UPDATE SET
    name_en                 = EXCLUDED.name_en,
    name_ur                 = EXCLUDED.name_ur,
    price_pkr               = EXCLUDED.price_pkr,
    max_orders_per_month    = EXCLUDED.max_orders_per_month,
    max_active_customers    = EXCLUDED.max_active_customers,
    trial_days              = EXCLUDED.trial_days,
    sort_order              = EXCLUDED.sort_order,
    is_active               = EXCLUDED.is_active,
    storage_allowance_bytes = COALESCE(EXCLUDED.storage_allowance_bytes, subscription_plans.storage_allowance_bytes),
    updated_at              = now()
  RETURNING * INTO v_row;

  RETURN row_to_json(v_row);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_subscription_plan(text, text, text, integer, integer, integer, integer, integer, boolean, bigint) TO authenticated;
