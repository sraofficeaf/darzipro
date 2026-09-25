-- ============================================================================
-- Migration: 20260925_admin_query_scoping_and_platform_exclusion.sql
-- Description:
--   1. Create get_admin_subscription_stats RPC (SECURITY DEFINER)
--   2. Update get_admin_shops_data RPC to return owner profile and exclude platform shop
--   3. Update get_admin_reports_data RPC to exclude platform shop from stats & revenue
--   4. Ensure all admin RPCs enforce search_path and admin authorization check
-- ============================================================================

-- ── 1. get_admin_subscription_stats ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_admin_subscription_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller_email      text;
  v_is_admin          boolean := false;
  v_platform_shop_id  uuid := 'bb800b6f-fd70-4ca7-8b51-3b934d3c18c1'::uuid;
  v_result            json;
  v_mrr               int := 0;
  v_founding_mrr      int := 0;
  v_founding_activations int := 0;
  v_grace_count       int := 0;
  v_read_only_count   int := 0;
  v_lifetime_count    int := 0;
  v_founding_count    int := 0;
  v_upcoming_renewals int := 0;
  v_total_shops       int := 0;
  v_founding_monthly_fee int := 500;
  v_founding_mode     text := 'linked';
  v_basic_price       int := 500;
  v_now               timestamptz := clock_timestamp();
  r_shop              record;
  v_plan_counts       jsonb := '{}'::jsonb;
  v_plan_prices       jsonb := '{}'::jsonb;
  v_code              text;
  v_price             int;
BEGIN
  -- Authenticate admin caller
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

  -- Build plan prices map
  FOR v_code, v_price IN
    SELECT code, price_pkr FROM subscription_plans WHERE is_active = true
  LOOP
    v_plan_prices := jsonb_set(v_plan_prices, ARRAY[v_code], to_jsonb(v_price));
    IF v_code = 'basic' THEN
      v_basic_price := v_price;
    END IF;
  END LOOP;

  -- Founding fee setting
  SELECT COALESCE((SELECT value FROM app_settings WHERE key = 'founding_monthly_mode'), 'linked')
  INTO v_founding_mode;
  IF v_founding_mode = 'fixed' THEN
    SELECT COALESCE(NULLIF(value, '')::int, 500) INTO v_founding_monthly_fee
    FROM app_settings WHERE key = 'founding_monthly_fixed';
  ELSE
    v_founding_monthly_fee := v_basic_price;
  END IF;

  -- Loop through real client shops (excluding platform shop and deleted shops)
  FOR r_shop IN
    SELECT
      id,
      plan_code,
      subscription_status,
      billing_cycle_end,
      founding_free_until
    FROM shops
    WHERE id != v_platform_shop_id
      AND coalesce(is_platform_account, false) = false
      AND coalesce(status, 'active') != 'deleted'
  LOOP
    v_total_shops := v_total_shops + 1;
    v_code := coalesce(r_shop.plan_code, 'trial');

    -- Increment plan counts
    v_plan_counts := jsonb_set(
      v_plan_counts,
      ARRAY[v_code],
      to_jsonb(coalesce((v_plan_counts ->> v_code)::int, 0) + 1)
    );

    IF r_shop.subscription_status = 'lifetime' THEN
      v_lifetime_count := v_lifetime_count + 1;
    ELSIF v_code = 'founding' OR r_shop.subscription_status = 'founding' THEN
      v_founding_count := v_founding_count + 1;
      IF r_shop.founding_free_until IS NOT NULL AND v_now < r_shop.founding_free_until THEN
        v_founding_activations := v_founding_activations + 1;
      ELSE
        v_founding_mrr := v_founding_mrr + v_founding_monthly_fee;
      END IF;
    ELSIF r_shop.subscription_status IN ('active', 'expiring') THEN
      v_mrr := v_mrr + coalesce((v_plan_prices ->> v_code)::int, 0);
    ELSIF r_shop.subscription_status = 'grace' THEN
      v_grace_count := v_grace_count + 1;
    ELSIF r_shop.subscription_status = 'read_only' THEN
      v_read_only_count := v_read_only_count + 1;
    END IF;

    -- Renewals in next 7 days
    IF r_shop.billing_cycle_end IS NOT NULL
       AND r_shop.billing_cycle_end > v_now
       AND r_shop.billing_cycle_end <= (v_now + interval '7 days') THEN
      v_upcoming_renewals := v_upcoming_renewals + 1;
    END IF;
  END LOOP;

  SELECT json_build_object(
    'total_shops',           v_total_shops,
    'mrr',                   v_mrr,
    'total_mrr',             v_mrr + v_founding_mrr,
    'founding_mrr',          v_founding_mrr,
    'founding_activations',  v_founding_activations,
    'grace_count',           v_grace_count,
    'read_only_count',       v_read_only_count,
    'lifetime_count',        v_lifetime_count,
    'founding_count',        v_founding_count,
    'upcoming_renewals',     v_upcoming_renewals,
    'upcoming_renewals_7d',  v_upcoming_renewals,
    'plan_counts',           v_plan_counts,
    'plan_prices',           v_plan_prices
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ── 2. Update get_admin_shops_data ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_admin_shops_data()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller_email      text;
  v_is_admin          boolean := false;
  v_platform_shop_id  uuid := 'bb800b6f-fd70-4ca7-8b51-3b934d3c18c1'::uuid;
  v_result            json;
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

  SELECT COALESCE(
    (
      SELECT json_agg(s)
      FROM (
        SELECT
          sh.id,
          sh.name,
          sh.name AS shop_name,
          sh.phone,
          sh.phone AS whatsapp_number,
          sh.address,
          sh.city,
          sh.currency,
          sh.country_code,
          sh.plan_code,
          sh.plan_code AS plan,
          sh.subscription_status,
          sh.billing_cycle_start,
          sh.billing_cycle_end,
          sh.trial_started_at,
          sh.storage_used_bytes,
          sh.lifetime_access,
          sh.storage_addon_active,
          sh.bundled_storage_expires_at,
          sh.created_at,
          coalesce(
            (SELECT p.full_name FROM profiles p WHERE p.shop_id = sh.id AND p.role = 'owner' LIMIT 1),
            (SELECT p.full_name FROM profiles p WHERE p.shop_id = sh.id LIMIT 1),
            'N/A'
          ) AS shop_owner_name,
          coalesce(
            (SELECT u.email FROM profiles p JOIN auth.users u ON u.id = p.id WHERE p.shop_id = sh.id AND p.role = 'owner' LIMIT 1),
            (SELECT lic.email FROM licenses lic WHERE lic.shop_id = sh.id AND lic.email IS NOT NULL LIMIT 1),
            'N/A'
          ) AS email,
          json_build_object(
            'plan', sh.plan_code,
            'status', sh.subscription_status
          ) AS licenses
        FROM shops sh
        WHERE sh.id != v_platform_shop_id
          AND coalesce(sh.is_platform_account, false) = false
          AND coalesce(sh.status, 'active') != 'deleted'
        ORDER BY sh.created_at DESC
      ) s
    ),
    '[]'::json
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ── 3. Update get_admin_reports_data ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_admin_reports_data(
  p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_end_date   timestamp with time zone DEFAULT NULL::timestamp with time zone
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller_email      text;
  v_is_admin          boolean := false;
  v_platform_shop_id  uuid := 'bb800b6f-fd70-4ca7-8b51-3b934d3c18c1'::uuid;
  v_result            json;
  v_total_rev         bigint;
  v_agency_profit     bigint;
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

  -- Total revenue from succeeded non-test payments (excluding platform shop)
  SELECT COALESCE(SUM(round(up.amount_minor / 100.0)), 0)
  INTO v_total_rev
  FROM unified_payments up
  WHERE up.status = 'succeeded'
    AND up.is_test = false
    AND up.shop_id != v_platform_shop_id
    AND (p_start_date IS NULL OR up.created_at >= p_start_date)
    AND (p_end_date IS NULL OR up.created_at <= p_end_date);

  -- Total agency profit
  SELECT COALESCE(SUM(ae.earning_minor), 0)
  INTO v_agency_profit
  FROM agency_earnings ae
  WHERE ae.is_test = false
    AND ae.source_shop_id != v_platform_shop_id
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
          AND ae.source_shop_id != v_platform_shop_id
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
          AND up.shop_id != v_platform_shop_id
          AND (p_start_date IS NULL OR up.created_at >= p_start_date)
          AND (p_end_date IS NULL OR up.created_at <= p_end_date)
        ORDER BY up.created_at DESC
      ) u
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ── 4. Fix RLS on unified_payments & admin_audit_logs to use JWT email ───────
DROP POLICY IF EXISTS unified_payments_shop_read ON unified_payments;
CREATE POLICY unified_payments_shop_read ON unified_payments FOR SELECT TO authenticated
USING (
  shop_id IN (SELECT profiles.shop_id FROM profiles WHERE profiles.id = auth.uid())
  OR EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = (auth.jwt() ->> 'email')
      AND (role = 'superadmin' OR role = 'admin')
  )
);

DROP POLICY IF EXISTS unified_payments_admin_update ON unified_payments;
CREATE POLICY unified_payments_admin_update ON unified_payments FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = (auth.jwt() ->> 'email')
      AND (role = 'superadmin' OR role = 'admin')
  )
);

DROP POLICY IF EXISTS admin_audit_logs_admin_select ON admin_audit_logs;
CREATE POLICY admin_audit_logs_admin_select ON admin_audit_logs FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM admin_users
    WHERE email = (auth.jwt() ->> 'email')
      AND (role = 'superadmin' OR role = 'admin')
  )
);


-- ── 5. Update get_admin_approvals_data ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_admin_approvals_data()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller_email text;
  v_is_admin     boolean := false;
  v_result       json;
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

  SELECT json_build_object(
    'pending_registrations', COALESCE((
      SELECT json_agg(r) FROM (
        SELECT * FROM public_registrations
        WHERE status = 'pending_admin_review'
        ORDER BY created_at DESC
      ) r
    ), '[]'::json),
    'pending_upgrades', COALESCE((
      SELECT json_agg(u) FROM (
        SELECT * FROM upgrade_requests
        WHERE status = 'pending_approval'
        ORDER BY created_at DESC
      ) u
    ), '[]'::json),
    'pending_payments', COALESCE((
      SELECT json_agg(p) FROM (
        SELECT
          up.*,
          json_build_object(
            'id', s.id,
            'name', s.name,
            'phone', s.phone,
            'city', s.city,
            'invite_code', s.invite_code,
            'invited_by_code', s.agency_shop_id
          ) AS shops
        FROM unified_payments up
        LEFT JOIN shops s ON s.id = up.shop_id
        WHERE up.status = 'awaitingReview'
        ORDER BY up.created_at DESC
      ) p
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

