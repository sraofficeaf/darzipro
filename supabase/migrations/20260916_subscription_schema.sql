-- ============================================================
-- DARZI PRO — SUBSCRIPTION SYSTEM SCHEMA
-- Phase 1: New monthly subscription model
-- Replaces: mobile_only / full_access / full_access_3yr
-- ============================================================

-- ── PLAN DEFINITIONS (admin-editable, NOT hardcoded) ────────

create table if not exists subscription_plans (
  id               uuid primary key default gen_random_uuid(),
  code             text unique not null,          -- 'trial','basic','standard','unlimited'
  name_en          text not null,
  name_ur          text not null,
  price_pkr        int  not null,
  max_orders_per_month int,                       -- null = unlimited
  max_active_customers  int,                      -- null = unlimited
  trial_days       int,                           -- only for trial plan
  sort_order       int  not null,
  is_active        boolean default true,
  updated_at       timestamptz default now()
);

-- Seed plans (idempotent)
insert into subscription_plans
  (code, name_en, name_ur, price_pkr, max_orders_per_month, max_active_customers, trial_days, sort_order)
values
  ('trial',     'Free Trial', 'مفت ٹرائل',   0,    20,  null, 14, 0),
  ('basic',     'Basic',      'بیسک',        500,  150,  300, null, 1),
  ('standard',  'Standard',   'سٹینڈرڈ',    1500,  500, 1000, null, 2),
  ('unlimited', 'Unlimited',  'ان لمیٹڈ',   2500, null, null, null, 3)
on conflict (code) do nothing;

-- ── PER-SHOP SUBSCRIPTION STATE ─────────────────────────────

alter table shops
  add column if not exists plan_code              text default 'trial',
  add column if not exists billing_cycle_start    date,
  add column if not exists billing_cycle_end      date,
  add column if not exists subscription_status    text default 'trial'
    check (subscription_status in ('trial','active','expiring','grace','read_only','lifetime')),
  add column if not exists trial_started_at       timestamptz,
  add column if not exists lifetime_access        boolean default false,
  add column if not exists lifetime_storage_limit_bytes bigint;

-- ── MONTHLY USAGE TRACKING ──────────────────────────────────

create table if not exists shop_usage_cycles (
  id                    uuid primary key default gen_random_uuid(),
  shop_id               uuid not null references shops(id) on delete cascade,
  cycle_start           date not null,
  cycle_end             date not null,
  orders_count          int  default 0,
  active_customers_snapshot int default 0,
  plan_code_at_start    text,
  plan_code_at_end      text,
  amount_due_pkr        int,
  payment_status        text default 'pending'
    check (payment_status in ('pending','paid','overdue','waived')),
  paid_at               timestamptz,
  created_at            timestamptz default now(),
  unique(shop_id, cycle_start)
);

-- ── SUBSCRIPTION PAYMENTS ────────────────────────────────────

create table if not exists subscription_payments (
  id                    uuid primary key default gen_random_uuid(),
  shop_id               uuid not null references shops(id),
  usage_cycle_id        uuid references shop_usage_cycles(id),
  amount_pkr            int  not null,
  plan_code             text not null,
  payment_method        text,
  transaction_id        text,
  payment_screenshot_url text,
  status                text default 'pending_admin_review'
    check (status in ('pending_admin_review','approved','rejected')),
  rejection_reason      text,
  reviewed_by           uuid references admin_users(id),
  reviewed_at           timestamptz,
  created_at            timestamptz default now()
);

-- ── ROW LEVEL SECURITY ───────────────────────────────────────

alter table shop_usage_cycles  enable row level security;
alter table subscription_payments enable row level security;

-- Shops can only read their own usage cycles
create policy if not exists "shop_usage_cycles_shop_read"
  on shop_usage_cycles for select
  using (
    shop_id in (
      select shop_id from profiles where id = auth.uid()
    )
  );

-- Shops can only read their own subscription payments
create policy if not exists "subscription_payments_shop_read"
  on subscription_payments for select
  using (
    shop_id in (
      select shop_id from profiles where id = auth.uid()
    )
  );

-- Shops can insert their own subscription payments
create policy if not exists "subscription_payments_shop_insert"
  on subscription_payments for insert
  with check (
    shop_id in (
      select shop_id from profiles where id = auth.uid()
    )
  );

-- ── INDEXES FOR PERFORMANCE ──────────────────────────────────

create index if not exists idx_shop_usage_cycles_shop_id    on shop_usage_cycles(shop_id);
create index if not exists idx_shop_usage_cycles_cycle_start on shop_usage_cycles(cycle_start);
create index if not exists idx_subscription_payments_shop_id on subscription_payments(shop_id);
create index if not exists idx_subscription_payments_status  on subscription_payments(status);
create index if not exists idx_shops_plan_code               on shops(plan_code);
create index if not exists idx_shops_subscription_status     on shops(subscription_status);
