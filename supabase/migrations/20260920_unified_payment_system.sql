-- ============================================================
-- DARZI PRO — PLUGGABLE MULTI-PROVIDER PAYMENT SYSTEM
-- Migration: 20260920_unified_payment_system.sql
-- Supports: Stripe + Manual (Bank, JazzCash, Easypaisa) + Extensible
-- ============================================================

-- ── 1. PAYMENT PROVIDERS REGISTRY ────────────────────────────
create table if not exists payment_providers (
  code                  text primary key,              -- 'stripe', 'manual'
  display_name          text not null,
  enabled               boolean default false,
  supported_currencies  text[] default array['PKR'],   -- ['USD','EUR'] or ['*'] for any
  allowed_countries     text[] default array['*'],     -- ['PK'] or ['*'] for all
  priority              int default 50,                -- lower = shown first
  is_instant            boolean default false,
  config                jsonb default '{}',            -- non-secret display config only
  updated_at            timestamptz default now()
);

-- Seed Initial Providers (Stripe + Manual)
insert into payment_providers (
  code, display_name, enabled, supported_currencies, allowed_countries, priority, is_instant
) values
  ('stripe', 'Card / Stripe', false, ARRAY['USD','EUR','GBP','AED','PKR'], ARRAY['*'], 1, true),
  ('manual', 'Bank / Easypaisa / JazzCash', true, ARRAY['*'], ARRAY['*'], 99, false)
on conflict (code) do update set
  display_name = excluded.display_name,
  priority = excluded.priority,
  is_instant = excluded.is_instant,
  updated_at = now();

-- ── 2. UNIFIED PAYMENTS TABLE ────────────────────────────────
create table if not exists unified_payments (
  id                    uuid primary key default gen_random_uuid(),
  shop_id               uuid not null references shops(id),
  provider_code         text not null references payment_providers(code),
  purpose               text not null,              -- 'subscriptionMonthly','foundingActivation','storageMonthly','storageAnnual'
  amount_minor          bigint not null,            -- integer paisa / cents
  currency              text not null default 'PKR',
  provider_reference    text,                       -- Stripe payment_intent_id or manual reference
  status                text not null default 'pending'
    check (status in ('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'awaitingReview', 'expired')),
  failure_reason        text,
  receipt_url           text,
  manual_transaction_id text,
  reviewed_by           uuid references admin_users(id),
  reviewed_at           timestamptz,
  usage_cycle_id        uuid references shop_usage_cycles(id),
  metadata              jsonb default '{}',
  created_at            timestamptz default now(),
  completed_at          timestamptz,
  unique(provider_code, provider_reference)
);

create index if not exists idx_unified_payments_shop on unified_payments(shop_id);
create index if not exists idx_unified_payments_status on unified_payments(status);
create index if not exists idx_unified_payments_purpose on unified_payments(purpose);
create index if not exists idx_unified_payments_provider on unified_payments(provider_code);

-- ── 3. MULTI-CURRENCY PLAN PRICING ───────────────────────────
create table if not exists plan_prices (
  plan_code             text not null,
  currency              text not null,
  amount_minor          bigint not null,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now(),
  primary key (plan_code, currency)
);

-- Seed PKR pricing from existing subscription_plans (amount in minor units: price_pkr * 100)
insert into plan_prices (plan_code, currency, amount_minor)
select code, 'PKR', (price_pkr::bigint * 100) from subscription_plans
on conflict (plan_code, currency) do update
set amount_minor = excluded.amount_minor, updated_at = now();

-- Seed Storage Addon Pricing in minor units (1200 PKR -> 120000, 10000 PKR -> 1000000)
insert into plan_prices (plan_code, currency, amount_minor) values
  ('storage_monthly', 'PKR', 120000),
  ('storage_annual',  'PKR', 1000000)
on conflict (plan_code, currency) do nothing;

-- ── 4. SHOP LOCALE FIELDS ────────────────────────────────────
alter table shops
  add column if not exists country_code        text default 'PK',
  add column if not exists preferred_currency  text default 'PKR';

-- ── 5. ROW LEVEL SECURITY (RLS) ──────────────────────────────
alter table payment_providers enable row level security;
alter table unified_payments  enable row level security;
alter table plan_prices       enable row level security;

-- payment_providers: readable by all authenticated users
drop policy if exists "payment_providers_read_all" on payment_providers;
create policy "payment_providers_read_all"
  on payment_providers for select
  to authenticated
  using (true);

-- plan_prices: readable by all authenticated users
drop policy if exists "plan_prices_read_all" on plan_prices;
create policy "plan_prices_read_all"
  on plan_prices for select
  to authenticated
  using (true);

-- unified_payments: shop owner can read their own payments
drop policy if exists "unified_payments_shop_read" on unified_payments;
create policy "unified_payments_shop_read"
  on unified_payments for select
  to authenticated
  using (
    shop_id in (select shop_id from profiles where id = auth.uid())
    or exists (select 1 from admin_users where id = auth.uid())
  );

-- unified_payments: shop owner can create a payment record
drop policy if exists "unified_payments_shop_insert" on unified_payments;
create policy "unified_payments_shop_insert"
  on unified_payments for insert
  to authenticated
  with check (
    shop_id in (select shop_id from profiles where id = auth.uid())
    or exists (select 1 from admin_users where id = auth.uid())
  );

-- unified_payments: update allowed for admin or service role
drop policy if exists "unified_payments_admin_update" on unified_payments;
create policy "unified_payments_admin_update"
  on unified_payments for update
  to authenticated
  using (
    exists (select 1 from admin_users where id = auth.uid())
  );

-- ── 5B. ADMIN AUDIT & ALERTS LOG ──────────────────────────────────────────
create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  severity text not null default 'critical',
  category text not null,
  shop_id uuid references shops(id) on delete set null,
  payment_id uuid references unified_payments(id) on delete cascade,
  title text not null,
  message text not null,
  metadata jsonb default '{}'::jsonb,
  is_resolved boolean default false,
  created_at timestamptz default now()
);

alter table public.admin_audit_logs enable row level security;

create policy admin_audit_logs_service_role
  on public.admin_audit_logs for all
  to service_role
  using (true)
  with check (true);

create policy admin_audit_logs_admin_select
  on public.admin_audit_logs for select
  to authenticated
  using (
    exists (select 1 from admin_users where id = auth.uid())
  );

-- ── 6. SHARED FULFILLMENT FUNCTION (One Function, All Providers) ─
-- Atomic, idempotent, handles all payment purposes & invite profit sharing
create or replace function fulfill_payment(
  p_payment_id uuid,
  p_is_test boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_payment           record;
  v_now               timestamptz := now();
  v_free_months       int         := 6;
  v_storage_gb        numeric     := 5;
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
  v_new_plan_code     text;
  v_is_test           boolean;
  v_shop_is_test      boolean := false;
begin
  -- 1. Lock payment row
  select * into v_payment from unified_payments where id = p_payment_id for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'payment_not_found');
  end if;

  v_is_test := coalesce(p_is_test, false) or coalesce(v_payment.is_test, false);
  select coalesce(is_test, false) into v_shop_is_test from shops where id = v_payment.shop_id;

  -- 2. Idempotency Check: if already succeeded and completed, exit cleanly
  if v_payment.status = 'succeeded' and v_payment.completed_at is not null then
    return jsonb_build_object(
      'success', true,
      'already_fulfilled', true,
      'purpose', v_payment.purpose
    );
  end if;

  -- 3. Mark payment as succeeded in unified_payments
  update unified_payments
  set status = 'succeeded',
      completed_at = v_now,
      reviewed_at = coalesce(reviewed_at, v_now)
  where id = p_payment_id;

  -- 4. Guard: Test payments must NEVER grant subscription time or alter plans on live shops
  if v_is_test is true and v_shop_is_test is not true then
    insert into admin_audit_logs (
      severity, category, shop_id, payment_id, title, message, metadata
    ) values (
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

    update unified_payments
    set failure_reason = 'BYPASSED_TEST_PAYMENT_ON_LIVE_SHOP'
    where id = p_payment_id;

    return jsonb_build_object(
      'success', true,
      'payment_id', p_payment_id,
      'purpose', v_payment.purpose,
      'test_payment_recorded', true,
      'live_shop_bypassed', true,
      'admin_alert_created', true
    );
  end if;

  -- 5. Route business logic by purpose
  if v_payment.purpose = 'subscriptionMonthly' then
    v_new_plan_code := coalesce(nullif(v_payment.metadata->>'plan_code', ''), 'standard');

        -- Extend billing cycle end date by 1 month, activate shop, and set plan_code
        update shops set
          subscription_status = 'active',
          plan_code = coalesce(v_new_plan_code, plan_code),
          billing_cycle_end = case
            when billing_cycle_end is null or billing_cycle_end < current_date
              then (current_date + interval '1 month')::date
            else (billing_cycle_end + interval '1 month')::date
          end
        where id = v_payment.shop_id;

    -- Update linked usage cycle to paid
    if v_payment.usage_cycle_id is not null then
      update shop_usage_cycles set
        payment_status = 'paid',
        paid_at = v_now
      where id = v_payment.usage_cycle_id;
    else
      -- Update current pending cycle if found
      update shop_usage_cycles set
        payment_status = 'paid',
        paid_at = v_now
      where shop_id = v_payment.shop_id
        and payment_status = 'pending'
        and cycle_start <= current_date and cycle_end >= current_date;
    end if;

  elsif v_payment.purpose = 'foundingActivation' then
    -- Read founding settings from app_settings
    begin
      select coalesce(nullif(value, ''), '6')::int into v_free_months
      from app_settings where key = 'founding_free_months';
    exception when others then
      v_free_months := 6;
    end;

    begin
      select coalesce(nullif(value, ''), '5')::numeric into v_storage_gb
      from app_settings where key = 'founding_storage_limit_gb';
    exception when others then
      v_storage_gb := 5;
    end;

    v_free_months   := coalesce(v_free_months, 6);
    v_storage_gb    := coalesce(v_storage_gb, 5);
    v_free_until    := (current_date + (v_free_months || ' months')::interval)::date;
    v_storage_bytes := (v_storage_gb * 1073741824)::bigint;

    update shops set
      plan_code                    = 'founding',
      subscription_status          = 'founding',
      founding_activated_at        = v_now,
      founding_free_until          = v_free_until,
      founding_storage_limit_bytes = v_storage_bytes,
      billing_cycle_start          = current_date,
      billing_cycle_end            = v_free_until
    where id = v_payment.shop_id;

    insert into shop_usage_cycles
      (shop_id, cycle_start, cycle_end, orders_count, plan_code_at_start, payment_status)
    values
      (v_payment.shop_id, current_date, v_free_until, 0, 'founding', 'waived')
    on conflict (shop_id, cycle_start) do nothing;

  elsif v_payment.purpose = 'storageMonthly' then
    update shops set
      storage_addon_active = true,
      storage_addon_type = 'monthly',
      storage_addon_expires_at = case
        when storage_addon_expires_at is null or storage_addon_expires_at < v_now
          then v_now + interval '1 month'
        else storage_addon_expires_at + interval '1 month'
      end
    where id = v_payment.shop_id;

  elsif v_payment.purpose = 'storageAnnual' then
    update shops set
      storage_addon_active = true,
      storage_addon_type = 'annual',
      storage_addon_expires_at = case
        when storage_addon_expires_at is null or storage_addon_expires_at < v_now
          then v_now + interval '1 year'
        else storage_addon_expires_at + interval '1 year'
      end
    where id = v_payment.shop_id;
  end if;

  -- 5. Multi-Level Invite Profit Calculation (Idempotent per payment)
  -- Convert amount_minor to major unit (e.g. 50000 paisa -> 500 PKR)
  v_major_amount := round(v_payment.amount_minor / 100.0);

  -- Retrieve platform owner shop ID if configured
  begin
    select value::uuid into v_platform_owner_id
    from app_settings where key = 'platform_owner_shop_id';
  exception when others then
    v_platform_owner_id := null;
  end;

  v_curr_shop_id := v_payment.shop_id;

  for lvl in 1..4 loop
    -- Find inviter code of current shop
    select invited_by_code into v_inviter_code
    from shops where id = v_curr_shop_id;

    exit when v_inviter_code is null or v_inviter_code = '';

    -- Find inviter shop
    select id, status, coalesce(invite_level_unlocked, 1) as level_unlocked
    into v_inviter_shop
    from shops where invite_code = v_inviter_code;

    exit when not found;

    v_target_inviter_id := v_inviter_shop.id;
    if v_inviter_shop.status = 'deleted' and v_platform_owner_id is not null then
      v_target_inviter_id := v_platform_owner_id;
    end if;

    -- Check if this inviter has unlocked this level
    if v_inviter_shop.level_unlocked >= lvl then
      v_earning := round(v_major_amount * v_level_pcts[lvl]);

      -- Insert into profit_earnings if not already recorded for this payment & level
      if v_earning > 0 then
        insert into profit_earnings (
          inviter_shop_id,
          invited_shop_id,
          earning_type,
          amount,
          level,
          status,
          created_at
        ) values (
          v_target_inviter_id,
          v_payment.shop_id,
          v_payment.purpose,
          v_earning::int,
          lvl,
          'pending',
          v_now
        );
      end if;
    end if;

    if v_target_inviter_id = v_platform_owner_id then
      exit;
    end if;
    v_curr_shop_id := v_target_inviter_id;
  end loop;

  return jsonb_build_object(
    'success', true,
    'payment_id', p_payment_id,
    'purpose', v_payment.purpose
  );
end;
$$;

-- ── 7. REJECTION RPC FOR UNIFIED PAYMENTS ────────────────────
create or replace function reject_unified_payment(
  p_payment_id uuid,
  p_reason text,
  p_admin_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update unified_payments
  set status = 'failed',
      failure_reason = p_reason,
      reviewed_by = coalesce(p_admin_id, reviewed_by),
      reviewed_at = now()
  where id = p_payment_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'payment_not_found');
  end if;

  return jsonb_build_object('success', true);
end;
$$;

-- ── 8. DATA MIGRATION FROM LEGACY TABLES ─────────────────────
-- Migrate subscription_payments rows into unified_payments
insert into unified_payments (
  id,
  shop_id,
  provider_code,
  purpose,
  amount_minor,
  currency,
  provider_reference,
  status,
  failure_reason,
  receipt_url,
  manual_transaction_id,
  reviewed_by,
  reviewed_at,
  usage_cycle_id,
  metadata,
  created_at,
  completed_at
)
select
  sp.id,
  sp.shop_id,
  'manual',
  case
    when sp.payment_type = 'founding_activation' then 'foundingActivation'
    else 'subscriptionMonthly'
  end,
  (sp.amount_pkr::bigint * 100),
  'PKR',
  coalesce(nullif(sp.transaction_id, ''), sp.id::text),
  case
    when sp.status in ('approved', 'confirmed') then 'succeeded'
    when sp.status = 'rejected' then 'failed'
    else 'awaitingReview'
  end,
  sp.rejection_reason,
  sp.payment_screenshot_url,
  sp.transaction_id,
  sp.reviewed_by,
  sp.reviewed_at,
  sp.usage_cycle_id,
  jsonb_build_object(
    'legacy_table', 'subscription_payments',
    'plan_code', sp.plan_code,
    'payment_method', sp.payment_method
  ),
  sp.created_at,
  case
    when sp.status in ('approved', 'confirmed')
      then coalesce(sp.reviewed_at, sp.created_at)
    else null
  end
from subscription_payments sp
on conflict (id) do nothing;

-- Also migrate legacy storage_addon_payments if table exists
do $$
begin
  if exists (select 1 from information_schema.tables where table_name = 'storage_addon_payments') then
    insert into unified_payments (
      id,
      shop_id,
      provider_code,
      purpose,
      amount_minor,
      currency,
      provider_reference,
      status,
      receipt_url,
      manual_transaction_id,
      metadata,
      created_at,
      completed_at
    )
    select
      sap.id,
      sap.shop_id,
      'manual',
      case
        when sap.amount >= 10000 then 'storageAnnual'
        else 'storageMonthly'
      end,
      (sap.amount::bigint * 100),
      'PKR',
      coalesce(nullif(sap.transaction_id, ''), sap.id::text),
      case
        when sap.status in ('approved', 'confirmed') then 'succeeded'
        when sap.status = 'rejected' then 'failed'
        else 'awaitingReview'
      end,
      sap.payment_screenshot_url,
      sap.transaction_id,
      jsonb_build_object(
        'legacy_table', 'storage_addon_payments',
        'addon_type', case when sap.amount >= 10000 then 'annual' else 'monthly' end,
        'payment_method', sap.payment_method
      ),
      sap.created_at,
      case
        when sap.status in ('approved', 'confirmed') then sap.created_at
        else null
      end
    from storage_addon_payments sap
    on conflict (id) do nothing;
  end if;
end $$;
