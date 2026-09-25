import 'package:intl/intl.dart';

/// Single formatter for subscription plan prices.
///
/// The DB table [subscription_plans] carries two columns:
///   - billing_period: 'monthly' | 'one_time' | 'free'
///   - price_note: optional human-readable note (e.g. "6 months free · then Rs 500/mo")
///
/// All UI code calls these methods instead of branching on plan['code'].
/// The founding plan's billing_period = 'one_time' is the only place that knows
/// the activation fee is not monthly.
class PlanPriceFormatter {
  PlanPriceFormatter._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Short suffix shown next to the price (e.g. "/mo", "one-time (activation)").
  /// [plan] is a raw DB row from subscription_plans.
  static String priceSuffix(
    Map<String, dynamic> plan, {
    bool isUrdu = false,
  }) {
    final period = _billingPeriod(plan);
    switch (period) {
      case 'one_time':
        return isUrdu ? 'ek martaba (activation)' : 'one-time (activation)';
      case 'free':
        return isUrdu ? 'muft' : 'free';
      case 'monthly':
      default:
        return isUrdu ? '/mahina' : '/mo';
    }
  }

  /// Formatted "Rs NNN /mo" or "Rs NNN one-time (activation)" string.
  static String formatFull(
    Map<String, dynamic> plan, {
    bool isUrdu = false,
  }) {
    final price = (plan['price_pkr'] as num?)?.toInt() ?? 0;
    final formatted = NumberFormat('#,###').format(price);
    final suffix = priceSuffix(plan, isUrdu: isUrdu);
    return 'Rs $formatted $suffix';
  }

  /// Descriptive sub-line shown below the plan name.
  /// Prefers price_note from DB if set; otherwise builds from order/customer limits.
  static String description(
    Map<String, dynamic> plan, {
    bool isUrdu = false,
  }) {
    final note = plan['price_note'] as String?;
    if (note != null && note.isNotEmpty) return note;

    final maxOrders = plan['max_orders_per_month'] as int?;
    final maxCustomers = plan['max_active_customers'] as int?;
    final rawBytes = (plan['storage_allowance_bytes'] as num?)?.toInt();
    final rawMb = (plan['storage_allowance_mb'] as num?)?.toInt();
    final storageBytes = rawBytes ?? (rawMb != null ? rawMb * 1024 * 1024 : null);

    String? storageStr;
    if (storageBytes != null && storageBytes > 0) {
      final mb = storageBytes ~/ (1024 * 1024);
      if (mb >= 1024 && mb % 1024 == 0) {
        storageStr = '${mb ~/ 1024} GB storage';
      } else {
        storageStr = '$mb MB storage';
      }
    }

    final parts = [
      maxOrders != null ? '$maxOrders orders' : 'Unlimited orders',
      maxCustomers != null ? '$maxCustomers customers' : 'Unlimited customers',
    ];
    if (storageStr != null) {
      parts.add(storageStr);
    }

    return parts.join(' · ');
  }

  /// True if this plan is billed as a one-time fee (activation only).
  static bool isOneTime(Map<String, dynamic> plan) =>
      _billingPeriod(plan) == 'one_time';

  /// True if this plan is free (trial).
  static bool isFree(Map<String, dynamic> plan) =>
      _billingPeriod(plan) == 'free';

  // ── Private ────────────────────────────────────────────────────────────────

  /// Reads billing_period from plan row.
  /// Falls back by inferring from plan code when column is absent (pre-migration).
  static String _billingPeriod(Map<String, dynamic> plan) {
    final period = plan['billing_period'] as String?;
    if (period != null && period.isNotEmpty) return period;
    // Graceful fallback — remove after migration is confirmed applied.
    final code = plan['code'] as String? ?? '';
    if (code == 'founding') return 'one_time';
    if (code == 'trial') return 'free';
    return 'monthly';
  }
}

