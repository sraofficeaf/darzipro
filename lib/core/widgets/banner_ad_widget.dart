import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ads_service.dart';

/// Shows a banner ad at the bottom of a screen (mobile_only plan only)
/// Usage: Add at bottom of Scaffold body or as a Column child at bottom
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = AdsService.instance.createBannerAd();
    if (ad == null) return;
    ad.load().then((_) {
      if (mounted) setState(() { _bannerAd = ad; _isLoaded = true; });
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (!AdsService.instance.shouldShowAds) return const SizedBox.shrink();
    if (!_isLoaded || _bannerAd == null) return const SizedBox(height: 50);
    return SizedBox(
      height: _bannerAd!.size.height.toDouble(),
      width: _bannerAd!.size.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
