import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:darzi_pro/core/services/license/license_model.dart';
import 'package:darzi_pro/core/services/license/license_service.dart';
import 'package:darzi_pro/core/services/ads_service.dart';

final licenseProvider = StateNotifierProvider<LicenseNotifier, LicenseModel>((ref) {
  return LicenseNotifier();
});

class LicenseNotifier extends StateNotifier<LicenseModel> {
  LicenseNotifier() : super(LicenseModel.free()) {
    _load();
  }

  void _load() {
    state = LicenseService().loadLicense();
    _initAds();
  }

  void updateLicense(LicenseModel license) {
    state = license;
    _initAds();
  }

  Future<LicenseActivationResult> activate(String key) async {
    final result = await LicenseService().activateLicense(key);
    if (result.success && result.license != null) {
      state = result.license!;
      _initAds();
    }
    return result;
  }

  Future<void> deactivate() async {
    await LicenseService().deactivateLicense();
    state = LicenseModel.free();
    _initAds();
  }

  void _initAds() {
    Future.microtask(() => AdsService.instance.initialize(plan: state.plan));
  }

  void refresh() => _load();
}
