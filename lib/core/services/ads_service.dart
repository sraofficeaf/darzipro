import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static final AdsService instance = AdsService._();
  AdsService._();

  // TODO: Replace with real AdMob IDs from admob.google.com after account setup
  // These are Google's official TEST ad unit IDs - safe for development
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS = 'ca-app-pub-3940256099942544/4411468910';

  // PRODUCTION IDs - set these after AdMob account setup
  // static const String _prodBannerAndroid = 'YOUR-ANDROID-BANNER-ID';
  // static const String _prodBannerIOS = 'YOUR-IOS-BANNER-ID';
  // static const String _prodInterstitialAndroid = 'YOUR-ANDROID-INTERSTITIAL-ID';
  // static const String _prodInterstitialIOS = 'YOUR-IOS-INTERSTITIAL-ID';

  String get bannerAdUnitId {
    if (kIsWeb) return '';
    return defaultTargetPlatform == TargetPlatform.android ? _testBannerAndroid : _testBannerIOS;
  }

  String get interstitialAdUnitId {
    if (kIsWeb) return '';
    return defaultTargetPlatform == TargetPlatform.android ? _testInterstitialAndroid : _testInterstitialIOS;
  }

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  DateTime? _lastInterstitialShown;
  static const Duration _interstitialCooldown = Duration(minutes: 5);

  bool _shouldShowAds = false;

  /// Initialize with the shop's plan. Only shows ads for mobile_only plan.
  Future<void> initialize({required String? plan}) async {
    _shouldShowAds = plan == 'mobile_only' && !kIsWeb;
    if (!_shouldShowAds) return;
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadInterstitial();
    } catch (e) {
      debugPrint('AdsService: init error: $e');
    }
  }

  bool get shouldShowAds => _shouldShowAds && _initialized;

  BannerAd? createBannerAd() {
    if (!shouldShowAds || bannerAdUnitId.isEmpty) return null;
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed: $error');
          ad.dispose();
        },
      ),
    );
  }

  void _loadInterstitial() {
    if (!shouldShowAds) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial failed: $err');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Shows interstitial if ready and cooldown passed. Call after key actions.
  void showInterstitialIfReady() {
    if (!shouldShowAds) return;
    if (_interstitialAd == null) return;
    final now = DateTime.now();
    if (_lastInterstitialShown != null &&
        now.difference(_lastInterstitialShown!) < _interstitialCooldown) {
      return;
    }
    _lastInterstitialShown = now;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial(); // preload next
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _interstitialAd = null;
      },
    );
    _interstitialAd!.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
