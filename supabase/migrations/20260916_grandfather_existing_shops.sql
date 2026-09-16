-- ============================================================
-- DARZI PRO — GRANDFATHER EXISTING SHOPS
-- Phase 7: Migrate old-model shops to lifetime access
-- Sra Tailor and Khan → lifetime, 5 GB storage
-- All other shops with old plan codes → lifetime too
-- ============================================================

-- Grant lifetime access to existing shops with old plan codes.
-- These shops paid Rs 35,000 under the old one-time model and must
-- NEVER be asked to pay monthly.

update shops
set
  lifetime_access                = true,
  subscription_status            = 'lifetime',
  plan_code                      = 'unlimited',
  lifetime_storage_limit_bytes   = 5368709120  -- 5 GB
where
  plan_code in ('mobile_only', 'full_access', 'full_access_3yr')
  or lower(name) like '%sra tailor%'
  or lower(name) like '%sra office%'
  or lower(name) like '%khan%';

-- Initialize usage cycles for any existing shops that don't have one yet
-- (shops that were created before this subscription system existed).
-- They get a "lifetime" cycle row that is permanently waived.
insert into shop_usage_cycles
  (shop_id, cycle_start, cycle_end, orders_count, plan_code_at_start, payment_status)
select
  id,
  current_date,
  '2099-12-31'::date,
  0,
  'unlimited',
  'waived'
from shops
where lifetime_access = true
  and id not in (select distinct shop_id from shop_usage_cycles)
on conflict (shop_id, cycle_start) do nothing;

-- For shops that don't have plan_code set yet (null or empty),
-- default them to trial so they get the proper new-user experience.
update shops
set
  plan_code           = 'trial',
  subscription_status = 'trial',
  trial_started_at    = coalesce(trial_started_at, created_at, now())
where
  (plan_code is null or plan_code = '')
  and lifetime_access is not true;
