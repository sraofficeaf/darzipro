import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'license_model.dart';

class LicenseService {
  static const String _boxKey = 'license_data';
  final Box _box = Hive.box('license_box');

  // Load license from Hive
  LicenseModel loadLicense() {
    final data = _box.get(_boxKey);
    if (data == null) return LicenseModel.free();
    return LicenseModel.fromHive(Map.from(data));
  }

  // Save license to Hive
  Future<void> saveLicense(LicenseModel license) async {
    await _box.put(_boxKey, license.toHive());
  }

  // Activate license key
  // Key format: DARZI-XXXX-XXXX-XXXX
  // Validation: check against master Supabase licenses table
  Future<LicenseActivationResult> activateLicense(String key) async {
    final cleanKey = key.trim().toUpperCase();

    // Basic format check
    if (!_isValidKeyFormat(cleanKey)) {
      return const LicenseActivationResult.error('Invalid key format. Use: DARZI-XXXX-XXXX-XXXX');
    }

    try {
      // Check against MASTER Supabase (separate from shop data)
      final response = await Supabase.instance.client
        .from('licenses')
        .select()
        .eq('license_key', cleanKey)
        .eq('status', 'active')
        .maybeSingle();

      if (response == null) {
        return const LicenseActivationResult.error('License key not found or already used.');
      }

      final expiresAtStr = response['expires_at'];
      final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        return const LicenseActivationResult.error('This license has expired.');
      }

      // Save to Hive
      final license = LicenseModel(
        plan: response['plan'] ?? 'pro',
        licenseKey: cleanKey,
        isActive: true,
        expiresAt: expiresAt,
        shopName: response['shop_name'] ?? '',
        email: response['email'] ?? '',
        activatedAt: DateTime.now(),
      );
      await saveLicense(license);

      return LicenseActivationResult.success(license);
    } catch (e) {
      return LicenseActivationResult.error('Could not verify license. Check internet connection. ($e)');
    }
  }

  bool _isValidKeyFormat(String key) {
    final regex = RegExp(r'^DARZI-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    return regex.hasMatch(key);
  }

  Future<void> deactivateLicense() async {
    await saveLicense(LicenseModel.free());
  }
}

class LicenseActivationResult {
  final bool success;
  final String? errorMessage;
  final LicenseModel? license;

  const LicenseActivationResult.success(this.license)
    : success = true, errorMessage = null;
  const LicenseActivationResult.error(this.errorMessage)
    : success = false, license = null;
}
