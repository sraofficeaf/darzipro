-- ============================================================
-- DARZI PRO — CLEANUP: DELETE SYNTHETIC TEST E2E DATA
-- Removes synthetic test records created during automated E2E tests:
--   - public_registrations (id: e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2)
--   - Any associated subscription payments, cycles, licenses & shops
-- ============================================================

-- 1. Delete subscription payments for test shops
DELETE FROM subscription_payments
WHERE shop_id IN (
  SELECT id FROM shops WHERE lower(name) LIKE '%test e2e%'
);

-- 2. Delete test storage addon payments
DELETE FROM storage_addon_payments
WHERE shop_id IN (
  SELECT id FROM shops WHERE lower(name) LIKE '%test e2e%'
);

-- 3. Delete test usage cycles
DELETE FROM shop_usage_cycles
WHERE shop_id IN (
  SELECT id FROM shops WHERE lower(name) LIKE '%test e2e%'
);

-- 4. Delete profit earnings linked to test shops
DELETE FROM profit_earnings
WHERE shop_id IN (
  SELECT id FROM shops WHERE lower(name) LIKE '%test e2e%'
) OR from_shop_id IN (
  SELECT id FROM shops WHERE lower(name) LIKE '%test e2e%'
);

-- 5. Delete associated licenses
DELETE FROM licenses
WHERE lower(shop_name) LIKE '%test e2e%'
   OR license_key LIKE '%E2E%'
   OR shop_id IN (
     SELECT id FROM shops WHERE lower(name) LIKE '%test e2e%'
   );

-- 6. Delete associated shops
DELETE FROM shops
WHERE lower(name) LIKE '%test e2e%';

-- 7. Delete from public_registrations
DELETE FROM public_registrations
WHERE id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2'
   OR lower(shop_name) LIKE '%test e2e%';
