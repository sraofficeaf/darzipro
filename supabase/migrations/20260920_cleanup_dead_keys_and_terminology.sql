-- ============================================================
-- Migration: 20260920_cleanup_dead_keys_and_terminology.sql
-- Description:
--   1. Delete obsolete plan_* settings from app_settings (dead pricing)
--   2. Historical rename: rename legacy key to storage_addon_profit_percent
-- ============================================================

-- 1. Delete dead legacy pricing keys from old one-time purchase model
DELETE FROM app_settings
WHERE key IN (
  'plan_price_basic',
  'plan_price_professional',
  'plan_price_enterprise',
  'plan_active_basic',
  'plan_active_professional',
  'plan_active_enterprise'
);

-- 2. Historical rename: update legacy setting key to storage_addon_profit_percent
-- (Historical note: this renames the legacy storage add-on percentage key to adhere to the project's Invite & Profit terminology)
UPDATE app_settings
SET key = 'storage_addon_profit_percent'
WHERE key = 'storage_addon_commission_percent';
