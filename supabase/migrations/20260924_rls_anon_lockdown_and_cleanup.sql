-- Migration: 20260924_rls_anon_lockdown_and_cleanup.sql
-- Description:
-- 1. Eliminate anon insert vulnerability on `shops` (drop shop_insert).
--    Shops can only be inserted by SECURITY DEFINER register_new_shop_free_trial RPC or service_role.
-- 2. Consolidate duplicate SELECT and UPDATE policies on `shops`:
--    - Drop shop_own and shops_select_own -> create single policy shop_select_own
--    - Drop shop_update and shops_update_own -> create single policy shop_update_own
-- 3. Eliminate anon insert vulnerability on `profiles` (drop profile_insert).
--    Profiles are only created by register_new_shop_free_trial or service_role.
-- 4. Consolidate duplicate SELECT and UPDATE policies on `profiles`:
--    - Drop profile_select and profiles_select_own -> create single policy profile_select_own
--    - Drop profile_update and profiles_update_own -> create single policy profile_update_own
-- 5. Enable RLS on `schema_migrations` to prevent unauthenticated anon read/write.

-- ============================================================================
-- 1. SHOPS
-- ============================================================================
DROP POLICY IF EXISTS shop_insert ON public.shops;
DROP POLICY IF EXISTS shop_own ON public.shops;
DROP POLICY IF EXISTS shops_select_own ON public.shops;
DROP POLICY IF EXISTS shop_update ON public.shops;
DROP POLICY IF EXISTS shops_update_own ON public.shops;

-- Consolidate SELECT: authenticated user can only select their own shop
CREATE POLICY shop_select_own ON public.shops
  FOR SELECT TO authenticated
  USING (id = current_shop_id());

-- Consolidate UPDATE: only authenticated shop owners can update their own shop
CREATE POLICY shop_update_own ON public.shops
  FOR UPDATE TO authenticated
  USING (
    (id = current_shop_id())
    AND EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
        AND profiles.role = 'owner'
    )
  )
  WITH CHECK (
    (id = current_shop_id())
    AND EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
        AND profiles.role = 'owner'
    )
  );

-- ============================================================================
-- 2. PROFILES
-- ============================================================================
DROP POLICY IF EXISTS profile_insert ON public.profiles;
DROP POLICY IF EXISTS profile_select ON public.profiles;
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profile_update ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;

-- Consolidate SELECT: authenticated user can see profiles within their shop or own profile
CREATE POLICY profile_select_own ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid() 
    OR shop_id = current_shop_id()
  );

-- Consolidate UPDATE: authenticated user can update only their own profile
CREATE POLICY profile_update_own ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ============================================================================
-- 3. SCHEMA_MIGRATIONS
-- ============================================================================
ALTER TABLE public.schema_migrations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS schema_migrations_service_role ON public.schema_migrations;
CREATE POLICY schema_migrations_service_role ON public.schema_migrations
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
