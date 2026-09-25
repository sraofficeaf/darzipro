-- ============================================================
-- DARZI PRO — FOUNDING MEMBER (بانی ممبر) LIFETIME PLAN
-- Migration: 20260917_founding_member_plan.sql
--
-- How it works:
--   1. Shop pays ONE-TIME activation fee (default Rs 35,000)
--   2. Gets FREE period (default 6 months) — unlimited orders/customers
--   3. After free period: recurring monthly fee begins (Rs 500/mo default)
--   4. NEVER auto-upgrades/downgrades — plan_code stays 'founding' forever
--   5. Storage capped at 5 GB (founding_storage_limit_gb setting)
-- ============================================================

-- ── 1. INSERT FOUNDING PLAN ──────────────────────────────────
-- sort_order = 5 (above unlimited = 3)
-- price_pkr = 0 because actual recurring fee is read from app_settings

insert into subscription_plans
  (code, name_en, name_ur, price_pkr,
   max_orders_per_month, max_active_customers, trial_days, sort_order, is_active)
values
  ('founding', 'Founding Member', 'Bani Member', 0,
   null, null, null, 5, true)
on conflict (code) do update
  set name_en    = excluded.name_en,
      name_ur    = excluded.name_ur,
      sort_order = excluded.sort_order,
      is_active  = excluded.is_active,
      updated_at = now();

-- ── 2. APP_SETTINGS TABLE ─────────────────────────────────────

create table if not exists app_settings (
  key        text primary key,
  value      text not null default '',
  updated_at timestamptz default now()
);

-- ── 3. SEED FOUNDING SETTINGS ─────────────────────────────────

insert into app_settings (key, value) values
  ('founding_activation_fee',   '35000'),
  ('founding_free_months',      '6'),
  ('founding_monthly_mode',     'linked'),
  ('founding_monthly_fixed',    '500'),
  ('founding_storage_limit_gb', '5'),
  ('founding_slots_total',      '50'),
  ('founding_offer_end_date',   ''),
  ('founding_offer_enabled',    'true')
on conflict (key) do nothing;

-- ── 4. ADD FOUNDING COLUMNS TO shops ─────────────────────────

alter table shops
  add column if not exists founding_activated_at        timestamptz,
  add column if not exists founding_free_until           date,
  add column if not exists founding_storage_limit_bytes  bigint;

-- ── 5. ADD payment_type TO subscription_payments ─────────────

alter table subscription_payments
  add column if not exists payment_type text not null default 'monthly'
    check (payment_type in ('monthly', 'founding_activation'));

-- ── 6. EXTEND subscription_status CHECK ──────────────────────

alter table shops drop constraint if exists shops_subscription_status_check;

alter table shops add constraint shops_subscription_status_check
  check (subscription_status in (
    'trial', 'active', 'expiring', 'grace', 'read_only', 'lifetime', 'founding'
  ));

-- ── 7. UPDATE check_and_apply_plan — SKIP FOUNDING SHOPS ─────

create or replace function check_and_apply_plan(p_shop_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $func$
declare
  v_current_plan_code  text;
  v_current_sort_order int;
  v_cycle_id           uuid;
  v_orders_count       int     := 0;
  v_active_customers   int     := 0;
  v_fitting_plan_code  text;
  v_fitting_sort_order int;
  v_fitting_price_pkr  int;
  v_is_lifetime        boolean := false;
  v_status             text;
begin
  select plan_code, subscription_status, lifetime_access
  into   v_current_plan_code, v_status, v_is_lifetime
  from   shops where id = p_shop_id;

  if not found then
    return jsonb_build_object('error', 'shop_not_found');
  end if;

  if v_is_lifetime or v_status = 'lifetime' then
    return jsonb_build_object('upgraded', false, 'plan', v_current_plan_code, 'lifetime', true);
  end if;

  -- FOUNDING SHOPS: never auto-upgrade
  if v_current_plan_code = 'founding' or v_status = 'founding' then
    return jsonb_build_object('upgraded', false, 'plan', v_current_plan_code, 'founding', true);
  end if;

  select sort_order into v_current_sort_order
  from   subscription_plans where code = v_current_plan_code;
  v_current_sort_order := coalesce(v_current_sort_order, 0);

  select id, orders_count into v_cycle_id, v_orders_count
  from   shop_usage_cycles
  where  shop_id = p_shop_id and cycle_start <= current_date and cycle_end >= current_date
  order  by cycle_start desc limit 1;
  v_orders_count := coalesce(v_orders_count, 0);

  select count(distinct o.customer_id) into v_active_customers
  from   orders o
  where  o.shop_id = p_shop_id
    and  o.order_date >= (current_date - interval '12 months');
  v_active_customers := coalesce(v_active_customers, 0);

  -- Find lowest fitting plan (exclude founding from targets)
  select code, sort_order, price_pkr
  into   v_fitting_plan_code, v_fitting_sort_order, v_fitting_price_pkr
  from   subscription_plans
  where  is_active = true and code != 'founding'
    and  (max_orders_per_month is null or v_orders_count <= max_orders_per_month)
    and  (max_active_customers is null or v_active_customers <= max_active_customers)
  order  by sort_order asc limit 1;

  if v_fitting_plan_code is null then
    select code, sort_order, price_pkr
    into   v_fitting_plan_code, v_fitting_sort_order, v_fitting_price_pkr
    from   subscription_plans
    where  max_orders_per_month is null and max_active_customers is null
      and  code != 'founding' and is_active = true
    order  by sort_order desc limit 1;
  end if;

  if v_fitting_sort_order > v_current_sort_order then
    update shops
    set    plan_code           = v_fitting_plan_code,
           subscription_status = case when v_status = 'trial' then 'active' else v_status end
    where  id = p_shop_id;

    if v_cycle_id is not null then
      update shop_usage_cycles
      set    plan_code_at_end           = v_fitting_plan_code,
             amount_due_pkr             = v_fitting_price_pkr,
             active_customers_snapshot  = v_active_customers
      where  id = v_cycle_id;
    end if;

    return jsonb_build_object(
      'upgraded', true, 'old_plan', v_current_plan_code, 'new_plan', v_fitting_plan_code,
      'new_plan_price_pkr', v_fitting_price_pkr,
      'orders_used', v_orders_count, 'active_customers', v_active_customers
    );
  end if;

  if v_cycle_id is not null then
    update shop_usage_cycles set active_customers_snapshot = v_active_customers where id = v_cycle_id;
  end if;

  return jsonb_build_object(
    'upgraded', false, 'plan', v_current_plan_code,
    'orders_used', v_orders_count, 'active_customers', v_active_customers
  );
end;
$func$;

-- ── 8. RPC: activate_founding_membership ─────────────────────
-- Called by admin after approving a founding_activation payment.

create or replace function activate_founding_membership(
  p_shop_id          uuid,
  p_payment_id       uuid,
  p_free_months      int     default 6,
  p_storage_limit_gb numeric default 5
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $func$
declare
  v_now           timestamptz := now();
  v_free_until    date        := (current_date + (p_free_months || ' months')::interval)::date;
  v_storage_bytes bigint      := (p_storage_limit_gb * 1073741824)::bigint;
begin
  update shops set
    plan_code                    = 'founding',
    subscription_status          = 'founding',
    founding_activated_at        = v_now,
    founding_free_until          = v_free_until,
    founding_storage_limit_bytes = v_storage_bytes,
    billing_cycle_start          = current_date,
    billing_cycle_end            = v_free_until
  where id = p_shop_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'shop_not_found');
  end if;

  update subscription_payments
  set    status = 'approved', reviewed_at = v_now
  where  id = p_payment_id;

  insert into shop_usage_cycles
    (shop_id, cycle_start, cycle_end, orders_count, plan_code_at_start, payment_status)
  values
    (p_shop_id, current_date, v_free_until, 0, 'founding', 'waived')
  on conflict (shop_id, cycle_start) do nothing;

  return jsonb_build_object(
    'success', true,
    'free_until', v_free_until::text,
    'storage_bytes', v_storage_bytes
  );
end;
$func$;

-- ── 9. RPC: count_founding_shops ─────────────────────────────
-- Returns count of shops with founding plan (for slots countdown).

create or replace function count_founding_shops()
returns int
language sql
security definer
set search_path = public, pg_temp
stable
as $func$
  select count(*)::int from shops where plan_code = 'founding';
$func$;

-- ── 10. INDEXES ───────────────────────────────────────────────

create index if not exists idx_shops_founding_plan
  on shops(plan_code) where plan_code = 'founding';

create index if not exists idx_subscription_payments_type
  on subscription_payments(payment_type);
