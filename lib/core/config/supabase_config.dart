/// Central Supabase configuration for Darzi Pro
/// Self-hosted on Coolify (Hostinger VPS)
class SupabaseConfig {
  // -----------------------------------------------------------
  // Connection — used by supabase_flutter (anon client)
  // -----------------------------------------------------------
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://darzipro-db.isaif.cloud',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc4NDgxMDI4MCwiZXhwIjo0OTQwNDgzODgwLCJyb2xlIjoiYW5vbiJ9.Key8p4vdiPvgQSJtgYve946Tpoy-y2IesXyOIVEyEeI',
  );



  // -----------------------------------------------------------
  // Storage base URLs
  // -----------------------------------------------------------
  static const String storageBase = '$url/storage/v1/object/public';
  static const String shopLogosUrl = '$storageBase/shop-logos';
  static const String designImagesUrl = '$storageBase/design-images';

  // -----------------------------------------------------------
  // Deep link redirect (for password reset)
  // -----------------------------------------------------------
  static const String passwordResetRedirect =
      'io.supabase.darzipro://reset-password';
}
