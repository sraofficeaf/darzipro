-- ============================================================
-- DARZI PRO — Fix Shops Table RLS Update Policy
-- Date: 2026-09-19
-- Problem: Users cannot update their own shop fields (phone, name, address, logo)
--          because shops table was missing an UPDATE policy.
-- ============================================================

-- Enable RLS on shops (safe if already enabled)
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;

-- ── READ: shop owner can select their own shop ───────────────
DROP POLICY IF EXISTS "shops_select_own" ON shops;
CREATE POLICY "shops_select_own"
  ON shops FOR SELECT
  USING (
    id IN (
      SELECT shop_id FROM profiles WHERE id = auth.uid()
    )
    OR owner_id = auth.uid()
  );

-- ── UPDATE: shop owner can update their own shop ─────────────
DROP POLICY IF EXISTS "shops_update_own" ON shops;
CREATE POLICY "shops_update_own"
  ON shops FOR UPDATE
  USING (
    id IN (
      SELECT shop_id FROM profiles WHERE id = auth.uid()
    )
    OR owner_id = auth.uid()
  )
  WITH CHECK (
    id IN (
      SELECT shop_id FROM profiles WHERE id = auth.uid()
    )
    OR owner_id = auth.uid()
  );

-- ── INSERT: authenticated user can create their shop ─────────
DROP POLICY IF EXISTS "shops_insert_own" ON shops;
CREATE POLICY "shops_insert_own"
  ON shops FOR INSERT
  WITH CHECK (
    owner_id = auth.uid()
  );

-- ── Admin: service_role bypasses all RLS (already default) ───
-- No change needed for service_role.

-- ── PROFILES table: owner can update their own profile ───────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (id = auth.uid());

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
