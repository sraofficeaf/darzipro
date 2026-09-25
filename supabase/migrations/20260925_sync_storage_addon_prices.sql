-- Synchronize plan_prices with active storage add-on pricing from app_settings
-- Monthly storage: Rs 250 (25,000 paisa)
-- Annual storage: Rs 2,500 (250,000 paisa)

UPDATE plan_prices 
SET amount_minor = 25000, updated_at = NOW()
WHERE plan_code = 'storage_monthly' AND currency = 'PKR';

UPDATE plan_prices 
SET amount_minor = 250000, updated_at = NOW()
WHERE plan_code = 'storage_annual' AND currency = 'PKR';
