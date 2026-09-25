-- ============================================================
-- DARZI PRO — SUBSCRIPTION ENGINE FUNCTIONS
-- Phase 2: Auto-upgrade engine + billing cycle logic
-- ============================================================

-- ── CHECK AND APPLY PLAN (main auto-upgrade engine) ─────────
-- Called after every order creation and customer addition.
-- NEVER blocks — always returns immediately. Never downgrades.

create or replace function check_and_apply_plan(p_shop_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current_plan_code    text;
  v_current_sort_order   int;
  v_cycle_id             uuid;
  v_orders_count         int  := 0;
  v_active_customers     int  := 0;
  v_fitting_plan_code    text;
  v_fitting_sort_order   int;
  v_fitting_price_pkr    int;
  v_is_lifetime          boolean := false;
  v_status               text;
begin
  -- 1. Get shop's current state
  select plan_code, subscription_status, lifetime_access
  into   v_current_plan_code, v_status, v_is_lifetime
  from   shops
  where  id = p_shop_id;

  if not found then
    return jsonb_build_object('error', 'shop_not_found');
  end if;

  -- Lifetime shops never auto-upgrade (they're already unlimited)
  if v_is_lifetime or v_status = 'lifetime' then
    return jsonb_build_object(
      'upgraded', false,
      'plan',     v_current_plan_code,
      'lifetime', true
    );
  end if;

  -- 2. Get current plan's sort_order
  select sort_order
  into   v_current_sort_order
  from   subscription_plans
  where  code = v_current_plan_code;

  -- Default if plan not found in table (e.g., old plan codes during migration)
  v_current_sort_order := coalesce(v_current_sort_order, 0);

  -- 3. Get current cycle orders_count
  select id, orders_count
  into   v_cycle_id, v_orders_count
  from   shop_usage_cycles
  where  shop_id    = p_shop_id
    and  cycle_start <= current_date
    and  cycle_end   >= current_date
  order  by cycle_start desc
  limit  1;

  v_orders_count := coalesce(v_orders_count, 0);

  -- 4. Calculate active customers (orders in last 12 months, distinct customers)
  select count(distinct o.customer_id)
  into   v_active_customers
  from   orders o
  where  o.shop_id    = p_shop_id
    and  o.order_date >= (current_date - interval '12 months');

  v_active_customers := coalesce(v_active_customers, 0);

  -- 5. Find the LOWEST plan (by sort_order) where BOTH metrics fit
  -- Dual-metric rule: whichever metric is higher wins
  select code, sort_order, price_pkr
  into   v_fitting_plan_code, v_fitting_sort_order, v_fitting_price_pkr
  from   subscription_plans
  where  is_active = true
    and  (max_orders_per_month is null or v_orders_count  <= max_orders_per_month)
    and  (max_active_customers is null or v_active_customers <= max_active_customers)
  order  by sort_order asc
  limit  1;

  -- 6. If no fitting plan found, use unlimited
  if v_fitting_plan_code is null then
    select code, sort_order, price_pkr
    into   v_fitting_plan_code, v_fitting_sort_order, v_fitting_price_pkr
    from   subscription_plans
    where  max_orders_per_month is null
      and  max_active_customers is null
      and  is_active = true
    order  by sort_order desc
    limit  1;
  end if;

  -- 7. Auto-upgrade if fitting plan is HIGHER than current (NEVER downgrade)
  if v_fitting_sort_order > v_current_sort_order then
    -- Update shop's plan
    update shops
    set    plan_code            = v_fitting_plan_code,
           subscription_status  = case
                                    when v_status = 'trial' then 'active'
                                    else v_status
                                  end
    where  id = p_shop_id;

    -- Update current cycle record
    if v_cycle_id is not null then
      update shop_usage_cycles
      set    plan_code_at_end  = v_fitting_plan_code,
             amount_due_pkr    = v_fitting_price_pkr,
             active_customers_snapshot = v_active_customers
      where  id = v_cycle_id;
    end if;

    return jsonb_build_object(
      'upgraded',           true,
      'old_plan',           v_current_plan_code,
      'new_plan',           v_fitting_plan_code,
      'new_plan_price_pkr', v_fitting_price_pkr,
      'orders_used',        v_orders_count,
      'active_customers',   v_active_customers
    );
  end if;

  -- No upgrade needed — update snapshot for reference
  if v_cycle_id is not null then
    update shop_usage_cycles
    set    active_customers_snapshot = v_active_customers
    where  id = v_cycle_id;
  end if;

  return jsonb_build_object(
    'upgraded',         false,
    'plan',             v_current_plan_code,
    'orders_used',      v_orders_count,
    'active_customers', v_active_customers
  );
end;
$$;


-- ── INITIALIZE SHOP TRIAL (called when a new shop is approved) ─

create or replace function initialize_shop_trial(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_trial_days int;
  v_now        timestamptz := now();
  v_start_date date        := current_date;
  v_end_date   date;
begin
  -- Get trial duration from plan definition
  select trial_days into v_trial_days
  from   subscription_plans
  where  code = 'trial';

  v_trial_days := coalesce(v_trial_days, 14);
  v_end_date   := v_start_date + v_trial_days;

  -- Set shop trial state
  update shops
  set    plan_code            = 'trial',
         subscription_status  = 'trial',
         trial_started_at     = v_now,
         billing_cycle_start  = v_start_date,
         billing_cycle_end    = v_end_date
  where  id = p_shop_id;

  -- Create first usage cycle row
  insert into shop_usage_cycles
    (shop_id, cycle_start, cycle_end, orders_count, plan_code_at_start, payment_status)
  values
    (p_shop_id, v_start_date, v_end_date, 0, 'trial', 'waived')
  on conflict (shop_id, cycle_start) do nothing;
end;
$$;


-- ── INCREMENT ORDER COUNT (called when a new order is created) ─

create or replace function increment_cycle_orders(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update shop_usage_cycles
  set    orders_count = orders_count + 1
  where  shop_id    = p_shop_id
    and  cycle_start <= current_date
    and  cycle_end   >= current_date;
end;
$$;


-- ── CLOSE AND RENEW BILLING CYCLE ────────────────────────────

create or replace function close_and_renew_billing_cycle(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current_plan_code text;
  v_plan_price        int;
  v_new_start         date := current_date;
  v_new_end           date;
  v_old_cycle_id      uuid;
begin
  -- Get current plan
  select plan_code into v_current_plan_code
  from   shops
  where  id = p_shop_id;

  -- Get plan price (reads live from table)
  select price_pkr into v_plan_price
  from   subscription_plans
  where  code = v_current_plan_code;

  -- Close current cycle
  select id into v_old_cycle_id
  from   shop_usage_cycles
  where  shop_id    = p_shop_id
    and  cycle_end   < current_date
  order  by cycle_end desc
  limit  1;

  if v_old_cycle_id is not null then
    update shop_usage_cycles
    set    plan_code_at_end = v_current_plan_code,
           amount_due_pkr   = coalesce(amount_due_pkr, v_plan_price)
    where  id = v_old_cycle_id;
  end if;

  -- New cycle: one calendar month from today
  v_new_end := v_new_start + interval '30 days';

  -- Update shop billing dates
  update shops
  set    billing_cycle_start  = v_new_start,
         billing_cycle_end    = v_new_end,
         subscription_status  = 'expiring'
  where  id = p_shop_id;

  -- Create new usage cycle row
  insert into shop_usage_cycles
    (shop_id, cycle_start, cycle_end, orders_count, plan_code_at_start, amount_due_pkr, payment_status)
  values
    (p_shop_id, v_new_start, v_new_end, 0, v_current_plan_code, v_plan_price, 'pending')
  on conflict (shop_id, cycle_start) do nothing;
end;
$$;


-- ── GET CURRENT USAGE (for Flutter UI) ──────────────────────

create or replace function get_shop_subscription_state(p_shop_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_shop              record;
  v_plan              record;
  v_cycle             record;
  v_active_customers  int;
  v_orders_pct        numeric;
  v_customers_pct     numeric;
begin
  -- Get shop
  select * into v_shop from shops where id = p_shop_id;
  if not found then
    return jsonb_build_object('error', 'shop_not_found');
  end if;

  -- Lifetime shops: never have any amount due, cycle end, or payment required
  if coalesce(v_shop.lifetime_access, false) = true or v_shop.subscription_status = 'lifetime' then
    select count(distinct o.customer_id)
    into   v_active_customers
    from   orders o
    where  o.shop_id    = p_shop_id
      and  o.order_date >= (current_date - interval '12 months');

    return jsonb_build_object(
      'shop_id',              p_shop_id,
      'plan_code',            'unlimited',
      'plan_name_en',         'Unlimited (Lifetime)',
      'plan_name_ur',         'ان لمیٹڈ (لائف ٹائم)',
      'plan_price_pkr',       0,
      'max_orders',           null,
      'max_customers',        null,
      'orders_used',          0,
      'active_customers',     coalesce(v_active_customers, 0),
      'cycle_start',          null,
      'cycle_end',            null,
      'amount_due_pkr',       0,
      'payment_status',       'waived',
      'subscription_status',  'lifetime',
      'is_lifetime',          true,
      'trial_started_at',     null
    );
  end if;

  -- Get plan definition (live, not cached)
  select * into v_plan from subscription_plans where code = v_shop.plan_code;

  -- Get current cycle
  select * into v_cycle
  from   shop_usage_cycles
  where  shop_id    = p_shop_id
    and  cycle_start <= current_date
    and  cycle_end   >= current_date
  order  by cycle_start desc
  limit  1;

  -- Active customers (12-month window)
  select count(distinct o.customer_id)
  into   v_active_customers
  from   orders o
  where  o.shop_id    = p_shop_id
    and  o.order_date >= (current_date - interval '12 months');

  v_active_customers := coalesce(v_active_customers, 0);

  return jsonb_build_object(
    'shop_id',              p_shop_id,
    'plan_code',            v_shop.plan_code,
    'plan_name_en',         coalesce(v_plan.name_en, v_shop.plan_code),
    'plan_name_ur',         coalesce(v_plan.name_ur, v_shop.plan_code),
    'plan_price_pkr',       coalesce(v_plan.price_pkr, 0),
    'max_orders',           v_plan.max_orders_per_month,
    'max_customers',        v_plan.max_active_customers,
    'orders_used',          coalesce(v_cycle.orders_count, 0),
    'active_customers',     v_active_customers,
    'cycle_start',          v_cycle.cycle_start,
    'cycle_end',            v_shop.billing_cycle_end,
    'amount_due_pkr',       coalesce(v_cycle.amount_due_pkr, v_plan.price_pkr, 0),
    'payment_status',       coalesce(v_cycle.payment_status, 'pending'),
    'subscription_status',  v_shop.subscription_status,
    'is_lifetime',          coalesce(v_shop.lifetime_access, false),
    'trial_started_at',     v_shop.trial_started_at
  );
end;
$$;

-- ── FREE SIGN-UP REGISTRATION FUNCTION ───────────────────────
-- Creates shop record on Free Trial, user profile, and initial usage cycle.
-- Atomic, security definer. Every new shop gets 14-day / 20-order Free Trial.

create or replace function register_new_shop_free_trial(
  p_user_id       uuid,
  p_shop_name     text,
  p_owner_name    text,
  p_phone         text,
  p_address       text,
  p_city          text default null,
  p_invite_code   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_shop_id       uuid;
  v_invite_code   text;
  v_cycle_id      uuid;
begin
  -- 1. Generate unique 6-character uppercase invite code for the new shop
  v_invite_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));

  -- 2. Insert new shop on Free Trial
  insert into shops (
    name,
    owner_name,
    phone,
    address,
    city,
    currency,
    invite_code,
    invited_by_code,
    plan_code,
    subscription_status,
    trial_started_at,
    created_at
  ) values (
    p_shop_name,
    p_owner_name,
    p_phone,
    p_address,
    p_city,
    'PKR',
    v_invite_code,
    p_invite_code,
    'trial',
    'trial',
    now(),
    now()
  )
  returning id into v_shop_id;

  -- 3. Insert profile for user
  insert into profiles (
    id,
    shop_id,
    full_name,
    role,
    created_at
  ) values (
    p_user_id,
    v_shop_id,
    p_owner_name,
    'owner',
    now()
  )
  on conflict (id) do update set
    shop_id = excluded.shop_id,
    full_name = excluded.full_name,
    role = 'owner';

  -- 4. Create initial usage cycle for trial (14 days)
  insert into shop_usage_cycles (
    shop_id,
    cycle_start,
    cycle_end,
    orders_count,
    active_customers_snapshot,
    plan_code_at_start,
    plan_code_at_end,
    amount_due_pkr,
    payment_status
  ) values (
    v_shop_id,
    current_date,
    current_date + interval '14 days',
    0,
    0,
    'trial',
    'trial',
    0,
    'waived'
  )
  returning id into v_cycle_id;

  -- 5. Record in public_registrations for admin visibility
  insert into public_registrations (
    shop_name,
    owner_name,
    email,
    phone,
    address,
    plan_selected,
    status,
    email_verified,
    created_at
  ) values (
    p_shop_name,
    p_owner_name,
    (select email from auth.users where id = p_user_id),
    p_phone,
    p_address,
    'trial',
    'approved',
    true,
    now()
  );

  return jsonb_build_object(
    'success', true,
    'shop_id', v_shop_id,
    'invite_code', v_invite_code,
    'plan', 'trial'
  );
exception when others then
  return jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
end;
$$;
