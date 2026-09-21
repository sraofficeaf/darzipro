-- ============================================================
-- DARZI PRO — Create and Configure 'shop-logos' Storage Bucket
-- Date: 2026-09-21
-- Fix: Allows shop owners to upload and display shop logos.
-- ============================================================

-- 1. Insert bucket into storage.buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'shop-logos',
  'shop-logos',
  true,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml'];

-- 2. Storage Objects Policies
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow public read access to all logos in 'shop-logos'
DROP POLICY IF EXISTS "Public View Shop Logos" ON storage.objects;
CREATE POLICY "Public View Shop Logos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'shop-logos');

-- Allow authenticated users to upload logos into 'shop-logos'
DROP POLICY IF EXISTS "Authenticated Users Upload Shop Logos" ON storage.objects;
CREATE POLICY "Authenticated Users Upload Shop Logos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'shop-logos');

-- Allow authenticated users to update their logos in 'shop-logos'
DROP POLICY IF EXISTS "Authenticated Users Update Shop Logos" ON storage.objects;
CREATE POLICY "Authenticated Users Update Shop Logos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'shop-logos');

-- Allow authenticated users to delete logos from 'shop-logos'
DROP POLICY IF EXISTS "Authenticated Users Delete Shop Logos" ON storage.objects;
CREATE POLICY "Authenticated Users Delete Shop Logos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'shop-logos');
