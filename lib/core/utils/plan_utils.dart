import 'package:flutter/material.dart';

/// Central plan naming and display utility for Darzi Pro.
/// Tiers (new subscription model):
///   trial     → Free Trial (14 days / 20 orders)
///   basic     → Basic Plan (Rs 500/month)
///   standard  → Standard Plan (Rs 1,500/month)
///   unlimited → Unlimited Plan (Rs 2,500/month)
///   lifetime  → Lifetime Access (grandfathered / admin-granted)
///
/// Old codes (mobile_only, full_access, full_access_3yr) are retired.
/// All old shops are grandfathered to lifetime via DB migration.
class AppPlanUtils {
  // ── Plan code constants ──────────────────────────────────────────
  static const String trial     = 'trial';
  static const String basic     = 'basic';
  static const String standard  = 'standard';
  static const String unlimited = 'unlimited';
  static const String lifetime  = 'lifetime'; // virtual code for lifetime shops
  static const String founding  = 'founding'; // Founding Member lifetime plan

  // ── Display info ─────────────────────────────────────────────────

  static (String label, Color color) getDisplayInfo(
    String? plan, {
    bool isUrdu = false,
  }) {
    final p = (plan ?? '').toLowerCase().trim();

    switch (p) {
      case 'founding':
        return (
          isUrdu ? '👑 بانی ممبر' : '👑 Founding Member',
          const Color(0xFFE8A020), // gold
        );
      case 'unlimited':
        return (
          isUrdu ? '♾️ ان لمیٹڈ پلان' : '♾️ Unlimited Plan',
          const Color(0xFF10B981),
        );
      case 'standard':
        return (
          isUrdu ? '⭐ سٹینڈرڈ پلان' : '⭐ Standard Plan',
          const Color(0xFFF5A623),
        );
      case 'basic':
        return (
          isUrdu ? '🚀 بیسک پلان' : '🚀 Basic Plan',
          const Color(0xFF5B72F5),
        );
      case 'trial':
        return (
          isUrdu ? '🆓 مفت ٹرائل' : '🆓 Free Trial',
          const Color(0xFF6880A0),
        );
      // Legacy / grandfathered codes → show as Lifetime
      case 'lifetime':
      case 'full_access_3yr':
      case 'mobile_only':
      case 'full_access':
      default:
        if (p == 'lifetime' || p.contains('3yr') || p.contains('full')) {
          return (
            isUrdu ? '👑 لائف ٹائم ایکسس' : '👑 Lifetime Access',
            const Color(0xFF10B981),
          );
        }
        return (
          isUrdu ? '🆓 مفت ٹرائل' : '🆓 Free Trial',
          const Color(0xFF6880A0),
        );
    }
  }

  static String getLabel(String? plan, {bool isUrdu = false}) {
    return getDisplayInfo(plan, isUrdu: isUrdu).$1;
  }

  static Color getColor(String? plan) {
    return getDisplayInfo(plan).$2;
  }

  /// Returns the sort order for a plan code (higher = more premium).
  static int getSortOrder(String? plan) {
    switch ((plan ?? '').toLowerCase().trim()) {
      case 'trial':
        return 0;
      case 'basic':
        return 1;
      case 'standard':
        return 2;
      case 'unlimited':
        return 3;
      case 'founding':
        return 5; // above unlimited, special tier
      case 'lifetime':
      case 'full_access_3yr':
      case 'full_access':
      case 'mobile_only':
        return 99; // lifetime is effectively highest
      default:
        return 0;
    }
  }

  /// Returns the "next" plan code for upgrade suggestion.
  static String? getNextPlanCode(String? current) {
    switch ((current ?? '').toLowerCase().trim()) {
      case 'trial':
        return 'basic';
      case 'basic':
        return 'standard';
      case 'standard':
        return 'unlimited';
      default:
        return null; // already at top or lifetime
    }
  }

  /// True if plan allows unlimited orders/customers (no tracking needed).
  static bool isUnlimited(String? plan, {bool isLifetime = false}) {
    if (isLifetime) return true;
    final p = (plan ?? '').toLowerCase().trim();
    // founding always has unlimited orders and customers (but storage is capped)
    return p == 'unlimited' || p == 'founding' || p == 'lifetime' || p.contains('full');
  }

  /// True if shop can create new data (not in read_only mode).
  static bool canCreate(String subscriptionStatus) {
    return subscriptionStatus != 'read_only';
  }

  /// Returns storage quota in MB based on plan.
  /// NOTE: Founding shops have a separate founding_storage_limit_bytes column
  /// in the shops table (default 5 GB). This method returns a default in MB
  /// for display purposes when the DB value is not yet available.
  static int getStorageQuotaMb(String? plan) {
    final p = (plan ?? '').toLowerCase().trim();
    if (p == 'founding') {
      return 5 * 1024; // 5 GB default — actual limit from DB
    } else if (p == 'unlimited' || p == 'lifetime' || p.contains('3yr') || p.contains('full')) {
      return 100;
    } else if (p == 'standard') {
      return 50;
    } else if (p == 'basic') {
      return 20;
    }
    return 10;
  }

  /// True if this plan is a founding member plan.
  static bool isFounding(String? plan) =>
      (plan ?? '').toLowerCase().trim() == 'founding';
}

typedef PlanUtils = AppPlanUtils;
