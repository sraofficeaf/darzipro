-- Migration: 20260925_base_storage_allowance_setting.sql
-- Description: Move base storage allowance from hardcoded code constant to app_settings table.

INSERT INTO app_settings (key, value, is_public, updated_at)
VALUES ('base_storage_allowance_mb', '1000', true, now())
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    is_public = true,
    updated_at = now();
