-- ============================================================
-- DARZI PRO — CLEANUP: DELETE SYNTHETIC TEST E2E DATA
-- Removes synthetic test records created during automated E2E tests:
--   - public_registrations (id: e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2)
--   - Any associated subscription payments, cycles, licenses & shops
-- ============================================================

-- 1. Delete subscription payments linked to synthetic test registration
DELETE FROM subscription_payments
WHERE shop_id IN (
  SELECT created_shop_id FROM public_registrations
  WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2' 
    AND created_shop_id IS NOT NULL
    AND created_shop_id NOT IN (SELECT shop_id FROM unified_payments)
);

-- 2. Delete test storage addon payments
DELETE FROM storage_addon_payments
WHERE shop_id IN (
  SELECT created_shop_id FROM public_registrations
  WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2' 
    AND created_shop_id IS NOT NULL
    AND created_shop_id NOT IN (SELECT shop_id FROM unified_payments)
);

-- 3. Delete test usage cycles
DELETE FROM shop_usage_cycles
WHERE shop_id IN (
  SELECT created_shop_id FROM public_registrations
  WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2' 
    AND created_shop_id IS NOT NULL
    AND created_shop_id NOT IN (SELECT shop_id FROM unified_payments)
);

-- 4. Delete profit earnings linked to synthetic test registration
DELETE FROM profit_earnings
WHERE (inviter_shop_id IN (
  SELECT created_shop_id FROM public_registrations
  WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2' 
    AND created_shop_id IS NOT NULL
    AND created_shop_id NOT IN (SELECT shop_id FROM unified_payments)
) OR invited_shop_id IN (
  SELECT created_shop_id FROM public_registrations
  WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2' 
    AND created_shop_id IS NOT NULL
    AND created_shop_id NOT IN (SELECT shop_id FROM unified_payments)
));

-- 5. Delete associated licenses
DELETE FROM licenses
WHERE shop_id IN (
  SELECT created_shop_id FROM public_registrations
  WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2' 
    AND created_shop_id IS NOT NULL
    AND created_shop_id NOT IN (SELECT shop_id FROM unified_payments)
);

-- 6. Delete associated shops (guarded against active shops with payments)
DELETE FROM shops
WHERE id IN (
  SELECT created_shop_id FROM public_registrations
  WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2' 
    AND created_shop_id IS NOT NULL
    AND created_shop_id NOT IN (SELECT shop_id FROM unified_payments)
);

-- 7. Delete synthetic registration if unlinked from active shop
DELETE FROM public_registrations
WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2'
  AND (created_shop_id IS NULL OR created_shop_id NOT IN (SELECT shop_id FROM unified_payments));
