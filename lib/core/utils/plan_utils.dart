import 'package:flutter/material.dart';

/// Central plan naming and display utility for Darzi Pro.
/// Tiers:
/// - mobile_only: Basic Plan (📱)
/// - full_access / pro: Professional Plan (🚀)
/// - full_access_3yr: Enterprise Plan (👑)
class AppPlanUtils {
  static const String mobileOnly = 'mobile_only';
  static const String fullAccess = 'full_access';
  static const String fullAccess3Yr = 'full_access_3yr';

  static (String label, Color color) getDisplayInfo(String? plan, {bool isUrdu = false}) {
    final p = (plan ?? '').toLowerCase();
    if (p.contains('3yr') || p.contains('three_year') || p == fullAccess3Yr) {
      return (isUrdu ? '👑 اینٹرپرائز پلان' : '👑 Enterprise Plan', const Color(0xFF10B981));
    } else if (p == fullAccess || p == 'pro' || p.contains('full')) {
      return (isUrdu ? '🚀 پروفیشنل پلان' : '🚀 Professional Plan', const Color(0xFFF5A623));
    } else {
      return (isUrdu ? '📱 بیسک پلان' : '📱 Basic Plan', const Color(0xFF3B82F6));
    }
  }

  static String getLabel(String? plan, {bool isUrdu = false}) {
    return getDisplayInfo(plan, isUrdu: isUrdu).$1;
  }
}
