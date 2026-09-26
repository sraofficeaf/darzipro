import 'package:flutter/material.dart';

/// Central plan naming and display utility for Darzi Pro.
/// Five valid subscription plan tiers:
///   trial     → Free Trial (14 days / 20 orders)
///   basic     → Basic Plan (Rs 500/month)
///   standard  → Standard Plan (Rs 1,500/month)
///   unlimited → Unlimited Plan (Rs 2,500/month)
///   founding  → Founding Member Plan
///
/// Lifetime access is not a plan tier; it is represented by
/// [subscription_status = 'lifetime'] and [lifetime_access = true].
class AppPlanUtils {
  // ── Plan code constants ──────────────────────────────────────────
  static const String trial     = 'trial';
  static const String basic     = 'basic';
  static const String standard  = 'standard';
  static const String unlimited = 'unlimited';
  static const String founding  = 'founding';

  // ── Display info ─────────────────────────────────────────────────

  static (String label, Color color) getDisplayInfo(
    String? plan, {
    bool isUrdu = false,
    bool isLifetime = false,
  }) {
    if (isLifetime) {
      return (
        isUrdu ? '👑 لائف ٹائم ایکسس' : '👑 Lifetime Access',
        const Color(0xFF10B981),
      );
    }

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
      default:
        return (
          isUrdu ? '🆓 مفت ٹرائل' : '🆓 Free Trial',
          const Color(0xFF6880A0),
        );
    }
  }

  static String getLabel(String? plan, {bool isUrdu = false, bool isLifetime = false}) {
    return getDisplayInfo(plan, isUrdu: isUrdu, isLifetime: isLifetime).$1;
  }

  static Color getColor(String? plan, {bool isLifetime = false}) {
    return getDisplayInfo(plan, isLifetime: isLifetime).$2;
  }

  /// Returns the sort order for a plan code (higher = more premium).
  static int getSortOrder(String? plan, {bool isLifetime = false}) {
    if (isLifetime) return 99;
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
      default:
        return 0;
    }
  }

  /// Returns the "next" plan code for upgrade suggestion.
  static String? getNextPlanCode(String? current, {bool isLifetime = false}) {
    if (isLifetime) return null;
    switch ((current ?? '').toLowerCase().trim()) {
      case 'trial':
        return 'basic';
      case 'basic':
        return 'standard';
      case 'standard':
        return 'unlimited';
      default:
        return null; // already at top or founding
    }
  }

  /// True if plan allows unlimited orders/customers (no tracking needed).
  static bool isUnlimited(String? plan, {bool isLifetime = false}) {
    if (isLifetime) return true;
    final p = (plan ?? '').toLowerCase().trim();
    // founding always has unlimited orders and customers (but storage is capped)
    return p == 'unlimited' || p == 'founding';
  }

  /// True if shop can create new data (not in read_only mode).
  static bool canCreate(String subscriptionStatus) {
    return subscriptionStatus != 'read_only';
  }

  /// True if this plan is a founding member plan.
  static bool isFounding(String? plan) =>
      (plan ?? '').toLowerCase().trim() == 'founding';
}

typedef PlanUtils = AppPlanUtils;
