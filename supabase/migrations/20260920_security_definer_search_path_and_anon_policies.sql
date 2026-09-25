-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: 20260920_security_definer_search_path_and_anon_policies.sql
-- Description:
-- 1. Adds is_public boolean to app_settings; scopes anon SELECT to is_public = true.
-- 2. Scopes payment_providers and plan_prices for public SELECT to anon and authenticated.
-- 3. Defines all legacy SECURITY DEFINER functions with SET search_path = public, pg_temp.
-- 4. Re-asserts search_path pinning across all 26 public SECURITY DEFINER functions.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. App Settings: is_public Column and RLS Scoping ─────────────────────
ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS is_public boolean NOT NULL DEFAULT false;

-- Mark public settings (promotional founding offer & public addon rates)
UPDATE app_settings
SET is_public = true
WHERE key IN (
  'founding_activation_fee',
  'founding_free_months',
  'founding_monthly_fixed',
  'founding_monthly_mode',
  'founding_offer_enabled',
  'founding_offer_end_date',
  'founding_slots_total',
  'founding_storage_limit_gb',
  'storage_active_annual',
  'storage_active_monthly',
  'storage_addon_price_annual',
  'storage_addon_price_monthly'
);

-- Mark internal-only settings as private (platform IDs, thresholds, profit rates)
UPDATE app_settings
SET is_public = false
WHERE key IN (
  'minimum_payout_threshold',
  'payout_delay_days',
  'platform_owner_shop_id',
  'storage_addon_profit_percent'
);

-- RLS for app_settings
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_settings_read_all ON app_settings;
DROP POLICY IF EXISTS app_settings_read_anon ON app_settings;
DROP POLICY IF EXISTS app_settings_read_auth ON app_settings;

CREATE POLICY app_settings_read_anon ON app_settings
  FOR SELECT TO anon
  USING (is_public = true);

CREATE POLICY app_settings_read_auth ON app_settings
  FOR SELECT TO authenticated
  USING (true);

-- ── 2. Allow anon role to read plan_prices and payment_providers ───────────
DROP POLICY IF EXISTS payment_providers_read_all ON payment_providers;
CREATE POLICY payment_providers_read_all ON payment_providers
  FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS plan_prices_read_all ON plan_prices;
CREATE POLICY plan_prices_read_all ON plan_prices
  FOR SELECT TO authenticated, anon USING (true);

-- ── 3. Legacy SECURITY DEFINER Functions with Explicit search_path ────────
CREATE OR REPLACE FUNCTION public.approve_storage_addon(p_payment_id uuid, p_shop_id uuid, p_invited_by_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_admin_id uuid;
  v_amount integer;
  v_addon_type text;
  v_is_annual boolean;
  v_expires_at timestamptz;
  v_earning_type text;
  v_platform_owner_id uuid;
  v_level_percentages numeric[] := ARRAY[0.15, 0.025, 0.015, 0.01];
  v_current_shop_id uuid;
  v_inviter_code text;
  v_inviter_shop_id uuid;
  v_invite_level_unlocked integer;
  v_inviter_status text;
  v_earning integer;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;
  SELECT id, (role = 'superadmin' OR role = 'admin') INTO v_admin_id, v_is_admin 
  FROM admin_users WHERE email = v_caller_email;
  IF NOT v_is_admin OR v_admin_id IS NULL THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  SELECT amount, addon_type INTO v_amount, v_addon_type
  FROM storage_addon_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found';
  END IF;

  v_amount := COALESCE(v_amount, 1200);
  v_addon_type := COALESCE(v_addon_type, CASE WHEN v_amount >= 10000 THEN 'annual' ELSE 'monthly' END);
  v_is_annual := (v_addon_type = 'annual' OR v_amount >= 10000);
  v_expires_at := CASE WHEN v_is_annual THEN now() + INTERVAL '365 days' ELSE now() + INTERVAL '30 days' END;
  v_earning_type := CASE WHEN v_is_annual THEN 'storage_addon_annual' ELSE 'storage_addon_monthly' END;

  UPDATE storage_addon_payments SET
    status = 'confirmed',
    reviewed_by = v_admin_id,
    reviewed_at = now()
  WHERE id = p_payment_id;

  UPDATE shops SET
    storage_addon_active = true,
    storage_addon_type = CASE WHEN v_is_annual THEN 'annual' ELSE 'monthly' END,
    storage_addon_expires_at = v_expires_at
  WHERE id = p_shop_id;

  IF p_invited_by_code IS NOT NULL AND p_invited_by_code <> '' THEN
    SELECT value::uuid INTO v_platform_owner_id FROM app_settings WHERE key = 'platform_owner_shop_id';
    v_current_shop_id := p_shop_id;

    FOR level IN 1..4 LOOP
      SELECT invited_by_code INTO v_inviter_code FROM shops WHERE id = v_current_shop_id;
      IF v_inviter_code IS NULL OR v_inviter_code = '' THEN
        EXIT;
      END IF;

      SELECT id, invite_level_unlocked, status INTO v_inviter_shop_id, v_invite_level_unlocked, v_inviter_status
      FROM shops WHERE invite_code = v_inviter_code;
      IF NOT FOUND THEN
        EXIT;
      END IF;

      IF v_inviter_status = 'deleted' AND v_platform_owner_id IS NOT NULL THEN
        v_inviter_shop_id := v_platform_owner_id;
      END IF;

      IF COALESCE(v_invite_level_unlocked, 1) >= level THEN
        v_earning := ROUND(v_amount * v_level_percentages[level]);
        INSERT INTO profit_earnings (
          inviter_shop_id, invited_shop_id, earning_type, amount, level, status, created_at
        ) VALUES (
          v_inviter_shop_id, p_shop_id, v_earning_type, v_earning, level, 'pending', now()
        );
      END IF;

      IF v_inviter_shop_id = v_platform_owner_id THEN
        v_current_shop_id := NULL;
      ELSE
        v_current_shop_id := v_inviter_shop_id;
      END IF;

      IF v_current_shop_id IS NULL THEN
        EXIT;
      END IF;
    END LOOP;
  END IF;

  RETURN json_build_object('success', true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.approve_upgrade_request(p_upgrade_request_id uuid, p_shop_id uuid, p_invited_by_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_admin_id uuid;
  v_upgrade_type text;
  v_amount integer;
  v_target_plan text;
  v_target_invite_level integer;
  v_earning_type text;
  v_platform_owner_id uuid;
  v_level_percentages numeric[] := ARRAY[0.15, 0.025, 0.015, 0.01];
  v_current_shop_id uuid;
  v_inviter_code text;
  v_inviter_shop_id uuid;
  v_invite_level_unlocked integer;
  v_inviter_status text;
  v_earning integer;
BEGIN
  -- 1. Check authorization
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;
  SELECT id, (role = 'superadmin' OR role = 'admin') INTO v_admin_id, v_is_admin 
  FROM admin_users WHERE email = v_caller_email;
  IF NOT v_is_admin OR v_admin_id IS NULL THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  -- 2. Get upgrade details
  SELECT upgrade_type, amount INTO v_upgrade_type, v_amount
  FROM upgrade_requests WHERE id = p_upgrade_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Upgrade request not found';
  END IF;

  v_upgrade_type := COALESCE(v_upgrade_type, 'to_full_access');
  v_amount := COALESCE(v_amount, CASE WHEN v_upgrade_type = 'mobile_to_3yr' THEN 58000 WHEN v_upgrade_type = 'to_3yr' THEN 35000 ELSE 23000 END);

  -- 3. Determine plan details
  v_target_plan := 'full_access';
  v_target_invite_level := 2;
  v_earning_type := 'upgrade_to_full_access';

  IF v_upgrade_type = 'to_3yr' THEN
    v_target_plan := 'full_access_3yr';
    v_target_invite_level := 4;
    v_earning_type := 'upgrade_to_3yr';
  ELSIF v_upgrade_type = 'mobile_to_3yr' THEN
    v_target_plan := 'full_access_3yr';
    v_target_invite_level := 4;
    v_earning_type := 'upgrade_mobile_to_3yr';
  END IF;

  -- 4. Update upgrade request status
  UPDATE upgrade_requests SET
    status = 'approved',
    reviewed_by = v_admin_id,
    reviewed_at = now()
  WHERE id = p_upgrade_request_id;

  -- 5. Update shop
  UPDATE shops SET
    plan = v_target_plan,
    plan_type = v_target_plan,
    invite_level_unlocked = v_target_invite_level,
    bundled_storage_expires_at = CASE WHEN v_target_plan = 'full_access_3yr' THEN now() + INTERVAL '3 years' ELSE bundled_storage_expires_at END
  WHERE id = p_shop_id;

  -- 6. Update license
  UPDATE licenses SET
    plan = v_target_plan,
    plan_type = v_target_plan
  WHERE shop_id = p_shop_id;

  -- 7. Multi-level profit calculation
  IF p_invited_by_code IS NOT NULL AND p_invited_by_code <> '' THEN
    SELECT value::uuid INTO v_platform_owner_id FROM app_settings WHERE key = 'platform_owner_shop_id';
    v_current_shop_id := p_shop_id;

    FOR level IN 1..4 LOOP
      SELECT invited_by_code INTO v_inviter_code FROM shops WHERE id = v_current_shop_id;
      IF v_inviter_code IS NULL OR v_inviter_code = '' THEN
        EXIT;
      END IF;

      SELECT id, invite_level_unlocked, status INTO v_inviter_shop_id, v_invite_level_unlocked, v_inviter_status
      FROM shops WHERE invite_code = v_inviter_code;
      IF NOT FOUND THEN
        EXIT;
      END IF;

      IF v_inviter_status = 'deleted' AND v_platform_owner_id IS NOT NULL THEN
        v_inviter_shop_id := v_platform_owner_id;
      END IF;

      IF COALESCE(v_invite_level_unlocked, 1) >= level THEN
        v_earning := ROUND(v_amount * v_level_percentages[level]);
        INSERT INTO profit_earnings (
          inviter_shop_id, invited_shop_id, earning_type, amount, level, status, created_at
        ) VALUES (
          v_inviter_shop_id, p_shop_id, v_earning_type, v_earning, level, 'pending', now()
        );
      END IF;

      IF v_inviter_shop_id = v_platform_owner_id THEN
        v_current_shop_id := NULL;
      ELSE
        v_current_shop_id := v_inviter_shop_id;
      END IF;

      IF v_current_shop_id IS NULL THEN
        EXIT;
      END IF;
    END LOOP;
  END IF;

  RETURN json_build_object('success', true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.current_shop_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT shop_id FROM public.profiles WHERE id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.current_shop_invite_code()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT invite_code FROM shops WHERE id = current_shop_id() LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_admin_approvals_data()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_result json;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;
  SELECT EXISTS (SELECT 1 FROM admin_users WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')) INTO v_is_admin;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Forbidden: Not an admin user'; END IF;
  SELECT json_build_object(
    'pending_registrations', COALESCE((SELECT json_agg(r) FROM public_registrations r WHERE r.status = 'pending_admin_review'), '[]'::json),
    'pending_upgrades', COALESCE((SELECT json_agg(u) FROM upgrade_requests u WHERE u.status = 'pending_approval'), '[]'::json)
  ) INTO v_result;
  RETURN v_result;
END;
$function$
;

DROP FUNCTION IF EXISTS public.get_admin_reports_data();

CREATE OR REPLACE FUNCTION public.get_admin_reports_data(
  p_start_date timestamptz DEFAULT null,
  p_end_date   timestamptz DEFAULT null
)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_result json;
  v_total_rev bigint;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF current_user IN ('postgres', 'service_role', 'supabase_admin') THEN
    v_is_admin := true;
  ELSE
    IF v_caller_email IS NULL OR v_caller_email = '' THEN
      RAISE EXCEPTION 'Unauthorized: No authenticated session';
    END IF;
    SELECT EXISTS (SELECT 1 FROM admin_users WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')) INTO v_is_admin;
  END IF;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Forbidden: Not an admin user'; END IF;

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
$function$
;

CREATE OR REPLACE FUNCTION public.get_admin_shops_data()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_result json;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;
  SELECT EXISTS (SELECT 1 FROM admin_users WHERE email = v_caller_email AND (role = 'superadmin' OR role = 'admin')) INTO v_is_admin;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Forbidden: Not an admin user'; END IF;
  SELECT COALESCE((SELECT json_agg(s) FROM (SELECT sh.*, json_build_object('plan', lic.plan, 'status', lic.status) AS licenses FROM shops sh LEFT JOIN licenses lic ON lic.shop_id = sh.id ORDER BY sh.created_at DESC) s), '[]'::json) INTO v_result;
  RETURN v_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.perform_shop_deletion(p_shop_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_platform_id UUID;
  v_shop_name   TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM shops WHERE id = p_shop_id AND status = 'deleted') THEN
    RETURN;
  END IF;

  SELECT value::uuid INTO v_platform_id
  FROM app_settings WHERE key = 'platform_owner_shop_id';

  IF v_platform_id IS NULL THEN
    RAISE EXCEPTION 'Platform owner shop not configured in app_settings';
  END IF;

  SELECT name INTO v_shop_name FROM shops WHERE id = p_shop_id;

  UPDATE profit_earnings
  SET inviter_shop_id = v_platform_id
  WHERE inviter_shop_id = p_shop_id
    AND status IN ('pending', 'included_in_payout');

  UPDATE profit_payouts
  SET inviter_shop_id = v_platform_id
  WHERE inviter_shop_id = p_shop_id
    AND status = 'pending';

  DELETE FROM order_images WHERE shop_id = p_shop_id;
  DELETE FROM payments WHERE shop_id = p_shop_id;
  DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders WHERE shop_id = p_shop_id);
  DELETE FROM measurements WHERE shop_id = p_shop_id;
  DELETE FROM measurement_templates WHERE shop_id = p_shop_id;
  DELETE FROM orders WHERE shop_id = p_shop_id;
  DELETE FROM customers WHERE shop_id = p_shop_id;
  DELETE FROM reminders WHERE shop_id = p_shop_id;

  UPDATE shops SET
    name                  = '[Deleted Account]',
    logo_url              = NULL,
    address               = NULL,
    phone                 = NULL,
    payout_method         = NULL,
    payout_account_number = NULL,
    payout_account_name   = NULL,
    deleted_at            = NOW(),
    status                = 'deleted'
  WHERE id = p_shop_id;

  UPDATE licenses SET
    shop_name = '[Deleted Account]',
    email     = NULL,
    phone     = NULL
  WHERE shop_name = v_shop_name OR shop_id = p_shop_id;

  -- FIX: owner_name in public_registrations has NOT NULL constraint, set to '[Deleted Account]' instead of NULL
  UPDATE public_registrations SET
    shop_name  = '[Deleted Account]',
    owner_name = '[Deleted Account]',
    email      = NULL,
    logo_url   = NULL
  WHERE created_shop_id = p_shop_id;

  UPDATE profiles SET
    full_name = '[Deleted Account]'
  WHERE shop_id = p_shop_id;

END $function$
;

CREATE OR REPLACE FUNCTION public.reject_registration(p_registration_id uuid, p_reason text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_admin_id uuid;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;
  SELECT id, (role = 'superadmin' OR role = 'admin') INTO v_admin_id, v_is_admin 
  FROM admin_users WHERE email = v_caller_email;
  IF NOT v_is_admin OR v_admin_id IS NULL THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  UPDATE public_registrations SET
    status = 'rejected',
    rejection_reason = p_reason,
    admin_notes = p_reason,
    reviewed_by = v_admin_id,
    reviewed_at = now()
  WHERE id = p_registration_id;

  RETURN json_build_object('success', true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reject_storage_addon(p_payment_id uuid, p_reason text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_admin_id uuid;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;
  SELECT id, (role = 'superadmin' OR role = 'admin') INTO v_admin_id, v_is_admin 
  FROM admin_users WHERE email = v_caller_email;
  IF NOT v_is_admin OR v_admin_id IS NULL THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  UPDATE storage_addon_payments SET
    status = 'rejected',
    admin_notes = p_reason,
    reviewed_by = v_admin_id,
    reviewed_at = now()
  WHERE id = p_payment_id;

  RETURN json_build_object('success', true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reject_upgrade_request(p_upgrade_request_id uuid, p_reason text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_email text;
  v_is_admin boolean;
  v_admin_id uuid;
BEGIN
  v_caller_email := (auth.jwt() ->> 'email');
  IF v_caller_email IS NULL OR v_caller_email = '' THEN
    RAISE EXCEPTION 'Unauthorized: No authenticated session';
  END IF;
  SELECT id, (role = 'superadmin' OR role = 'admin') INTO v_admin_id, v_is_admin 
  FROM admin_users WHERE email = v_caller_email;
  IF NOT v_is_admin OR v_admin_id IS NULL THEN 
    RAISE EXCEPTION 'Forbidden: Not an admin user'; 
  END IF;

  UPDATE upgrade_requests SET
    status = 'rejected',
    admin_notes = p_reason,
    reviewed_by = v_admin_id,
    reviewed_at = now()
  WHERE id = p_upgrade_request_id;

  RETURN json_build_object('success', true);
END;
$function$
;

-- ── 4. Assert Durable search_path Pinning on All 26 Functions ──────────────
ALTER FUNCTION public.activate_founding_membership(p_shop_id uuid, p_payment_id uuid, p_free_months integer, p_storage_limit_gb numeric) SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_delete_plan_price(p_plan_code text, p_currency text) SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_update_app_setting(p_key text, p_value text) SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_update_payment_provider(p_code text, p_enabled boolean, p_supported_currencies text[], p_allowed_countries text[], p_priority integer, p_display_name text) SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_upsert_plan_price(p_plan_code text, p_currency text, p_amount_minor integer) SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_upsert_subscription_plan(p_code text, p_name_en text, p_name_ur text, p_price_pkr integer, p_max_orders_per_month integer, p_max_active_customers integer, p_trial_days integer, p_sort_order integer, p_is_active boolean) SET search_path = public, pg_temp;
ALTER FUNCTION public.approve_storage_addon(p_payment_id uuid, p_shop_id uuid, p_invited_by_code text) SET search_path = public, pg_temp;
ALTER FUNCTION public.approve_upgrade_request(p_upgrade_request_id uuid, p_shop_id uuid, p_invited_by_code text) SET search_path = public, pg_temp;
ALTER FUNCTION public.check_and_apply_plan(p_shop_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.close_and_renew_billing_cycle(p_shop_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.count_founding_shops() SET search_path = public, pg_temp;
ALTER FUNCTION public.current_shop_id() SET search_path = public, pg_temp;
ALTER FUNCTION public.current_shop_invite_code() SET search_path = public, pg_temp;
ALTER FUNCTION public.fulfill_payment(uuid, boolean) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_admin_approvals_data() SET search_path = public, pg_temp;
ALTER FUNCTION public.get_admin_reports_data(timestamptz, timestamptz) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_admin_shops_data() SET search_path = public, pg_temp;
ALTER FUNCTION public.get_shop_subscription_state(p_shop_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.increment_cycle_orders(p_shop_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.initialize_shop_trial(p_shop_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.perform_shop_deletion(p_shop_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.register_new_shop_free_trial(p_user_id uuid, p_shop_name text, p_owner_name text, p_phone text, p_address text, p_city text, p_invite_code text) SET search_path = public, pg_temp;
ALTER FUNCTION public.reject_registration(p_registration_id uuid, p_reason text) SET search_path = public, pg_temp;
ALTER FUNCTION public.reject_storage_addon(p_payment_id uuid, p_reason text) SET search_path = public, pg_temp;
ALTER FUNCTION public.reject_unified_payment(p_payment_id uuid, p_reason text, p_admin_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.reject_upgrade_request(p_upgrade_request_id uuid, p_reason text) SET search_path = public, pg_temp;
