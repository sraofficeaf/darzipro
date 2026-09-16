-- ============================================================
-- DARZI PRO — EMERGENCY FIX: LIFETIME GRANDFATHERED SHOPS
-- Ensures Sra Tailor, Khan, and all legacy paid shops have:
--   - lifetime_access = true
--   - subscription_status = 'lifetime'
--   - plan_code = 'unlimited'
--   - billing_cycle_start = NULL, billing_cycle_end = NULL
--   - amount_due_pkr = 0, payment_status = 'waived'
--   - 5 GB cloud storage quota
-- ============================================================

-- 1. Explicitly update Sra Tailor and Khan + any legacy full_access shops
UPDATE shops
SET
  lifetime_access              = true,
  subscription_status          = 'lifetime',
  plan_code                    = 'unlimited',
  billing_cycle_start          = null,
  billing_cycle_end            = null,
  trial_started_at             = null,
  lifetime_storage_limit_bytes = 5368709120  -- 5 GB
WHERE
  lower(name) LIKE '%sra tailor%'
  OR lower(name) LIKE '%sra office%'
  OR lower(name) LIKE '%khan%'
  OR plan_code IN ('full_access', 'full_access_3yr', 'mobile_only', 'unlimited')
  OR lifetime_access IS TRUE;

-- 2. Update/Clean up shop_usage_cycles for lifetime shops
-- Ensure no cycle has any pending payment or amount due
UPDATE shop_usage_cycles
SET
  amount_due_pkr     = 0,
  payment_status     = 'waived',
  plan_code_at_start = 'unlimited',
  plan_code_at_end   = 'unlimited'
WHERE shop_id IN (
  SELECT id FROM shops WHERE lifetime_access = true OR subscription_status = 'lifetime'
);

-- 3. Delete any accidental pending subscription payments for lifetime shops
DELETE FROM subscription_payments
WHERE shop_id IN (
  SELECT id FROM shops WHERE lifetime_access = true OR subscription_status = 'lifetime'
);

-- 4. Replace get_shop_subscription_state to guarantee 0 amount due for lifetime shops
CREATE OR REPLACE FUNCTION get_shop_subscription_state(p_shop_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shop              record;
  v_plan              record;
  v_cycle             record;
  v_active_customers  int;
BEGIN
  -- Get shop
  SELECT * INTO v_shop FROM shops WHERE id = p_shop_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'shop_not_found');
  END IF;

  -- ── LIFETIME SHOPS: Always 0 due, no cycle end, waived status ──────
  IF COALESCE(v_shop.lifetime_access, false) = true OR v_shop.subscription_status = 'lifetime' THEN
    SELECT COUNT(DISTINCT o.customer_id)
    INTO   v_active_customers
    FROM   orders o
    WHERE  o.shop_id    = p_shop_id
      AND  o.order_date >= (CURRENT_DATE - INTERVAL '12 months');

    RETURN jsonb_build_object(
      'shop_id',              p_shop_id,
      'plan_code',            'unlimited',
      'plan_name_en',         'Unlimited (Lifetime)',
      'plan_name_ur',         'ان لمیٹڈ (لائف ٹائم)',
      'plan_price_pkr',       0,
      'max_orders',           null,
      'max_customers',        null,
      'orders_used',          0,
      'active_customers',     COALESCE(v_active_customers, 0),
      'cycle_start',          null,
      'cycle_end',            null,
      'amount_due_pkr',       0,
      'payment_status',       'waived',
      'subscription_status',  'lifetime',
      'is_lifetime',          true,
      'trial_started_at',     null
    );
  END IF;

  -- Get plan definition
  SELECT * INTO v_plan FROM subscription_plans WHERE code = v_shop.plan_code;

  -- Get current cycle
  SELECT * INTO v_cycle
  FROM   shop_usage_cycles
  WHERE  shop_id    = p_shop_id
    AND  cycle_start <= CURRENT_DATE
    AND  cycle_end   >= CURRENT_DATE
  ORDER  BY cycle_start DESC
  LIMIT  1;

  -- Active customers (12-month window)
  SELECT COUNT(DISTINCT o.customer_id)
  INTO   v_active_customers
  FROM   orders o
  WHERE  o.shop_id    = p_shop_id
    AND  o.order_date >= (CURRENT_DATE - INTERVAL '12 months');

  RETURN jsonb_build_object(
    'shop_id',              p_shop_id,
    'plan_code',            v_shop.plan_code,
    'plan_name_en',         COALESCE(v_plan.name_en, v_shop.plan_code),
    'plan_name_ur',         COALESCE(v_plan.name_ur, v_shop.plan_code),
    'plan_price_pkr',       COALESCE(v_plan.price_pkr, 0),
    'max_orders',           v_plan.max_orders_per_month,
    'max_customers',        v_plan.max_active_customers,
    'orders_used',          COALESCE(v_cycle.orders_count, 0),
    'active_customers',     COALESCE(v_active_customers, 0),
    'cycle_start',          v_cycle.cycle_start,
    'cycle_end',            v_shop.billing_cycle_end,
    'amount_due_pkr',       COALESCE(v_cycle.amount_due_pkr, v_plan.price_pkr, 0),
    'payment_status',       COALESCE(v_cycle.payment_status, 'pending'),
    'subscription_status',  v_shop.subscription_status,
    'is_lifetime',          COALESCE(v_shop.lifetime_access, false),
    'trial_started_at',     v_shop.trial_started_at
  );
END;
$$;

-- 5. Confirmation Verification Query
-- Run this in SQL Editor to confirm both shops are 100% lifetime:
SELECT 
  id,
  name,
  plan_code,
  subscription_status,
  lifetime_access,
  billing_cycle_start,
  billing_cycle_end,
  lifetime_storage_limit_bytes / (1024*1024*1024) AS storage_gb
FROM shops
WHERE lower(name) LIKE '%sra%' OR lower(name) LIKE '%khan%';
