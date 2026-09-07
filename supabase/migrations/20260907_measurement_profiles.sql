-- ============================================================
-- Migration: Multiple Measurement Profiles + Order Item Profile Link
-- Date: 2026-09-07
-- ============================================================

-- 1. Add profile_name column to measurements table
ALTER TABLE measurements
  ADD COLUMN IF NOT EXISTS profile_name TEXT DEFAULT 'Naap';

-- 2. Remove any unique constraint that limits one measurement row per customer_id
--    (common constraint names — DROP CONSTRAINT is idempotent with IF EXISTS)
ALTER TABLE measurements
  DROP CONSTRAINT IF EXISTS measurements_customer_id_shop_id_key;

ALTER TABLE measurements
  DROP CONSTRAINT IF EXISTS measurements_customer_id_key;

ALTER TABLE measurements
  DROP CONSTRAINT IF EXISTS unique_customer_measurement;

-- 3. Add measurement_profile_id to order_items (nullable FK to measurements)
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS measurement_profile_id UUID
    REFERENCES measurements(id) ON DELETE SET NULL;
