import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:darzi_pro/core/services/license/license_model.dart';
import 'package:darzi_pro/core/services/license/license_service.dart';
// NOTE: AdsService removed in Phase 6 — google_mobile_ads package deleted.

final licenseProvider = StateNotifierProvider<LicenseNotifier, LicenseModel>((ref) {
  return LicenseNotifier();
});

class LicenseNotifier extends StateNotifier<LicenseModel> {
  LicenseNotifier() : super(LicenseModel.free()) {
    _load();
  }

  void _load() {
    state = LicenseService().loadLicense();
  }

  void updateLicense(LicenseModel license) {
    state = license;
  }

  Future<LicenseActivationResult> activate(String key) async {
    final result = await LicenseService().activateLicense(key);
    if (result.success && result.license != null) {
      state = result.license!;
    }
    return result;
  }

  Future<void> deactivate() async {
    await LicenseService().deactivateLicense();
    state = LicenseModel.free();
  }

  void refresh() => _load();
}
