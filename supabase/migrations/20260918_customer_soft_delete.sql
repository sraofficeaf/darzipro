-- Migration: Add soft delete columns to customers table
ALTER TABLE customers ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Index for querying active customers efficiently
CREATE INDEX IF NOT EXISTS idx_customers_active ON customers (shop_id, is_archived) WHERE is_archived = false;
