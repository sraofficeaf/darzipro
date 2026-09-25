-- Migration: 20260924_realtime_publication_shops.sql
-- Description: Idempotently add 'shops' and 'shop_usage_cycles' to supabase_realtime publication
-- Ensures subscription plan and usage cycle changes are pushed in real time to authorized tenant sessions.

DO $$
BEGIN
  -- Add shops table if not already present in supabase_realtime publication
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'shops'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.shops;
  END IF;

  -- Add shop_usage_cycles table if not already present in supabase_realtime publication
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'shop_usage_cycles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.shop_usage_cycles;
  END IF;
END $$;
