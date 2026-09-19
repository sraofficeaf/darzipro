-- ============================================================
-- DARZI PRO — Fix Shops Table RLS Update Policy (CORRECTED)
-- Date: 2026-09-19
-- Fix: removed owner_id (column does not exist in shops table)
-- shops table is linked via profiles.shop_id = shops.id
-- ============================================================

-- Enable RLS on shops
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;

-- ── SELECT: shop owner can read their own shop ───────────────
DROP POLICY IF EXISTS "shops_select_own" ON shops;
CREATE POLICY "shops_select_own"
  ON shops FOR SELECT
  USING (
    id IN (
      SELECT shop_id FROM profiles WHERE id = auth.uid()
    )
  );

-- ── UPDATE: shop owner can update their own shop ─────────────
DROP POLICY IF EXISTS "shops_update_own" ON shops;
CREATE POLICY "shops_update_own"
  ON shops FOR UPDATE
  USING (
    id IN (
      SELECT shop_id FROM profiles WHERE id = auth.uid()
    )
  )
  WITH CHECK (
    id IN (
      SELECT shop_id FROM profiles WHERE id = auth.uid()
    )
  );

-- ── PROFILES table: user can read and update their own row ───
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
