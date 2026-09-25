-- ============================================================
-- Migration: 20260920_payment_expiry_and_status_constraint.sql
-- Description:
--   1. Update unified_payments status check constraint to include 'expired'
--   2. Add expire_stale_unified_payments function for automated / cron expiry
-- ============================================================

-- 1. Update check constraint on unified_payments.status to support 'expired'
ALTER TABLE unified_payments
  DROP CONSTRAINT IF EXISTS unified_payments_status_check;

ALTER TABLE unified_payments
  ADD CONSTRAINT unified_payments_status_check
  CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'awaitingReview', 'expired'));

-- 2. Stale payment expiry function: transitions pending payments older than window (default 24h) to 'expired'
-- Note: fulfill_payment allows late fulfillment of 'expired' rows if webhook arrives later.
CREATE OR REPLACE FUNCTION expire_stale_unified_payments(p_older_than interval DEFAULT interval '24 hours')
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE unified_payments
  SET status = 'expired'
  WHERE status = 'pending'
    AND created_at < (now() - p_older_than);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- 3. Enable pg_cron and schedule hourly stale payment expiry (24-hour window matching Stripe)
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('expire-stale-payments-hourly')
    FROM cron.job WHERE jobname = 'expire-stale-payments-hourly';

    PERFORM cron.schedule(
      'expire-stale-payments-hourly',
      '0 * * * *',
      'select public.expire_stale_unified_payments(interval ''24 hours'');'
    );
  END IF;
END $$;
