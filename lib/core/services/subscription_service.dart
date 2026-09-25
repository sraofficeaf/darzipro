import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Central service for the subscription system.
/// All limit/price checks read from the `subscription_plans` table at runtime.
/// Nothing is hardcoded — changing a plan's price in the admin panel
/// immediately affects all future charges.
///
/// Payment flow is kept in a separate, swappable module so that a payment
/// gateway (PayFast / PayPro / Simpaisa) can replace the manual screenshot
/// flow later without touching UI code.
class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  SupabaseClient get _client => Supabase.instance.client;

  Map<String, String> get _anonHeaders => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization':
            'Bearer ${_client.auth.currentSession?.accessToken ?? SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
      };

  Uri _restUri(String path) =>
      Uri.parse('${SupabaseConfig.url}/rest/v1$path');

  // ── PLAN DEFINITIONS ──────────────────────────────────────────────────────

  /// Fetches all active plans from the database.
  /// Never use hardcoded plan data — always call this.
  Future<List<Map<String, dynamic>>> fetchPlans() async {
    try {
      final res = await http.get(
        _restUri('/subscription_plans?is_active=eq.true&order=sort_order.asc'),
        headers: _anonHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('SubscriptionService.fetchPlans error: $e');
    }
    return _fallbackPlans;
  }

  /// Hardcoded fallback used ONLY when offline / DB unreachable.
  /// Storage allowances are never hardcoded here — single source of truth is subscription_plans in DB.
  static const List<Map<String, dynamic>> _fallbackPlans = [
    {
      'code': 'trial',
      'name_en': 'Free Trial',
      'name_ur': 'مفت ٹرائل',
      'price_pkr': 0,
      'billing_period': 'free',
      'price_note': null,
      'max_orders_per_month': 20,
      'max_active_customers': null,
      'trial_days': 14,
      'sort_order': 0,
    },
    {
      'code': 'basic',
      'name_en': 'Basic',
      'name_ur': 'بیسک',
      'price_pkr': 500,
      'billing_period': 'monthly',
      'price_note': null,
      'max_orders_per_month': 150,
      'max_active_customers': 300,
      'trial_days': null,
      'sort_order': 1,
    },
    {
      'code': 'standard',
      'name_en': 'Standard',
      'name_ur': 'سٹینڈرڈ',
      'price_pkr': 1500,
      'billing_period': 'monthly',
      'price_note': null,
      'max_orders_per_month': 500,
      'max_active_customers': 1000,
      'trial_days': null,
      'sort_order': 2,
    },
    {
      'code': 'unlimited',
      'name_en': 'Unlimited',
      'name_ur': 'ان لمیٹڈ',
      'price_pkr': 2500,
      'billing_period': 'monthly',
      'price_note': null,
      'max_orders_per_month': null,
      'max_active_customers': null,
      'trial_days': null,
      'sort_order': 3,
    },
    {
      'code': 'founding',
      'name_en': 'Founding Member',
      'name_ur': 'بانی ممبر',
      'price_pkr': 35000,
      'billing_period': 'one_time',
      'price_note': null,
      'max_orders_per_month': null,
      'max_active_customers': null,
      'trial_days': null,
      'sort_order': 5,
    },
  ];

  // ── CURRENT SUBSCRIPTION STATE ────────────────────────────────────────────

  /// Returns the full subscription state for a shop via the DB function.
  /// This includes live active customer count (12-month window).
  Future<Map<String, dynamic>?> getShopSubscriptionState(String shopId) async {
    try {
      final res = await http.post(
        _restUri('/rpc/get_shop_subscription_state'),
        headers: _anonHeaders,
        body: jsonEncode({'p_shop_id': shopId}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('SubscriptionService.getShopSubscriptionState error: $e');
    }
    return null;
  }

  // ── AUTO-UPGRADE ENGINE ───────────────────────────────────────────────────

  /// Calls the Postgres `check_and_apply_plan` function.
  /// Returns upgrade result: { upgraded, old_plan, new_plan, ... }
  /// NEVER throws — any error returns { upgraded: false }.
  Future<Map<String, dynamic>> checkAndApplyPlan(String shopId) async {
    try {
      final res = await http.post(
        _restUri('/rpc/check_and_apply_plan'),
        headers: _anonHeaders,
        body: jsonEncode({'p_shop_id': shopId}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('SubscriptionService.checkAndApplyPlan error: $e');
    }
    return {'upgraded': false};
  }

  /// Increments order count for current billing cycle.
  /// Called after every successful order creation.
  Future<void> incrementCycleOrders(String shopId) async {
    try {
      await http.post(
        _restUri('/rpc/increment_cycle_orders'),
        headers: _anonHeaders,
        body: jsonEncode({'p_shop_id': shopId}),
      );
    } catch (e) {
      debugPrint('SubscriptionService.incrementCycleOrders error: $e');
    }
  }

  // ── PAYMENT (Swappable Module) ────────────────────────────────────────────
  // The [IPaymentProvider] interface below allows swapping manual screenshots
  // for PayFast / PayPro / Simpaisa later without UI changes.

  /// Uploads a payment screenshot to Supabase Storage.
  /// Returns the public URL or a base64 fallback.
  Future<String?> uploadPaymentScreenshot({
    required String shopId,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final ext = filename.contains('.') ? filename.split('.').last : 'jpg';
      final path = '$shopId-${DateTime.now().millisecondsSinceEpoch}.$ext';
      try {
        await _client.storage
            .from('subscription-screenshots')
            .uploadBinary(path, bytes);
        final url = _client.storage
            .from('subscription-screenshots')
            .getPublicUrl(path);
        if (url.isNotEmpty) return url;
      } catch (storageErr) {
        debugPrint('Storage upload error, fallback to base64: $storageErr');
      }
      // Fallback: compressed base64 Data URI
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('SubscriptionService.uploadPaymentScreenshot error: $e');
      return null;
    }
  }

  /// Submits a manual payment for admin review to unified_payments.
  Future<Map<String, dynamic>> submitPayment({
    required String shopId,
    required String planCode,
    required int amountPkr,
    required String paymentMethod,
    String? transactionId,
    String? screenshotUrl,
    String? usageCycleId,
  }) async {
    try {
      final amountMinor = amountPkr * 100;
      final body = {
        'shop_id': shopId,
        'provider_code': 'manual',
        'purpose': 'subscriptionMonthly',
        'amount_minor': amountMinor,
        'currency': 'PKR',
        'status': 'awaitingReview',
        if (transactionId != null && transactionId.isNotEmpty) ...{
          'manual_transaction_id': transactionId,
          'provider_reference': transactionId,
        },
        if (screenshotUrl != null && screenshotUrl.isNotEmpty)
          'receipt_url': screenshotUrl,
        'usage_cycle_id': ?usageCycleId,
        'metadata': {
          'plan_code': planCode,
          'payment_method': paymentMethod,
        },
      };

      final res = await http.post(
        _restUri('/unified_payments'),
        headers: {
          ..._anonHeaders,
          'Prefer': 'return=representation',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': 'Server error ${res.statusCode}: ${res.body}',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetches price in minor units for a given plan and currency.
  Future<int?> fetchPlanPriceMinor({
    required String planCode,
    required String currency,
  }) async {
    try {
      final res = await _client
          .from('plan_prices')
          .select('amount_minor')
          .eq('plan_code', planCode)
          .eq('currency', currency.toUpperCase())
          .maybeSingle();

      if (res != null && res['amount_minor'] != null) {
        return (res['amount_minor'] as num).toInt();
      }
    } catch (e) {
      debugPrint('fetchPlanPriceMinor error: $e');
    }
    return null;
  }

  // ── DOWNGRADE REQUEST ─────────────────────────────────────────────────────

  /// Validates whether a shop can downgrade to a target plan.
  /// Returns { allowed: bool, reason?: string } based on live metrics.
  Future<Map<String, dynamic>> canDowngradeTo({
    required String shopId,
    required String targetPlanCode,
  }) async {
    try {
      final state = await getShopSubscriptionState(shopId);
      if (state == null) return {'allowed': false, 'reason': 'Could not fetch usage data'};

      final ordersUsed = (state['orders_used'] as int?) ?? 0;
      final activeCustomers = (state['active_customers'] as int?) ?? 0;

      // Fetch target plan limits from DB
      final plans = await fetchPlans();
      final targetPlan = plans.firstWhere(
        (p) => p['code'] == targetPlanCode,
        orElse: () => <String, dynamic>{},
      );

      if (targetPlan.isEmpty) {
        return {'allowed': false, 'reason': 'Plan not found'};
      }

      final maxOrders = targetPlan['max_orders_per_month'] as int?;
      final maxCustomers = targetPlan['max_active_customers'] as int?;

      if (maxOrders != null && ordersUsed > maxOrders) {
        return {
          'allowed': false,
          'reason':
              'Aapke is mahine $ordersUsed orders hain — ${targetPlan['name_ur']} plan mein sirf $maxOrders tak allowed hai.',
        };
      }

      if (maxCustomers != null && activeCustomers > maxCustomers) {
        return {
          'allowed': false,
          'reason':
              'Aapke $activeCustomers active customers hain — ${targetPlan['name_ur']} plan mein sirf $maxCustomers tak allowed hai.',
        };
      }

      return {'allowed': true};
    } catch (e) {
      return {'allowed': false, 'reason': e.toString()};
    }
  }

  // ── TRIAL EXPIRY CHECK ────────────────────────────────────────────────────

  /// Returns true if the trial has expired (by orders or by days).
  static bool isTrialExpired({
    required String subscriptionStatus,
    required int ordersUsed,
    required int? maxOrders,
    required DateTime? trialStartedAt,
    required int? trialDays,
  }) {
    if (subscriptionStatus != 'trial') return false;
    if (maxOrders != null && ordersUsed >= maxOrders) return true;
    if (trialStartedAt != null && trialDays != null) {
      final expiresAt = trialStartedAt.add(Duration(days: trialDays));
      return DateTime.now().isAfter(expiresAt);
    }
    return false;
  }

  /// Returns remaining trial orders (null if no limit).
  static int? trialOrdersRemaining({
    required int ordersUsed,
    required int? maxOrders,
  }) {
    if (maxOrders == null) return null;
    final remaining = maxOrders - ordersUsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// Returns remaining trial days (null if no expiry).
  static int? trialDaysRemaining({
    required DateTime? trialStartedAt,
    required int? trialDays,
  }) {
    if (trialStartedAt == null || trialDays == null) return null;
    final expiresAt = trialStartedAt.add(Duration(days: trialDays));
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  // ── 85% WARNING THRESHOLD ────────────────────────────────────────────────

  /// Returns whether any metric is at ≥85% of its limit.
  static bool isApproachingLimit({
    required int ordersUsed,
    required int? maxOrders,
    required int activeCustomers,
    required int? maxCustomers,
  }) {
    if (maxOrders != null && maxOrders > 0) {
      if (ordersUsed / maxOrders >= 0.85) return true;
    }
    if (maxCustomers != null && maxCustomers > 0) {
      if (activeCustomers / maxCustomers >= 0.85) return true;
    }
    return false;
  }

  /// Returns which metric is the "driving" metric (closer to its limit).
  /// Returns 'orders', 'customers', or null.
  static String? getDrivingMetric({
    required int ordersUsed,
    required int? maxOrders,
    required int activeCustomers,
    required int? maxCustomers,
  }) {
    double ordersPct = maxOrders != null && maxOrders > 0
        ? ordersUsed / maxOrders
        : 0;
    double customersPct = maxCustomers != null && maxCustomers > 0
        ? activeCustomers / maxCustomers
        : 0;

    if (ordersPct == 0 && customersPct == 0) return null;
    return ordersPct >= customersPct ? 'orders' : 'customers';
  }

  // ── FOUNDING MEMBER ──────────────────────────────────────────────────────────────────

  /// Fetches all founding offer settings from app_settings table.
  /// Returns a map of key->value. Falls back to defaults if fetch fails.
  Future<Map<String, String>> fetchFoundingSettings() async {
    try {
      final res = await http.get(
        _restUri('/app_settings?key=like.founding%25'),
        headers: _anonHeaders,
      );
      if (res.statusCode == 200) {
        final rows = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        return {for (final r in rows) r['key'] as String: r['value'] as String};
      }
    } catch (e) {
      debugPrint('SubscriptionService.fetchFoundingSettings error: $e');
    }
    // Defaults
    return {
      'founding_activation_fee':   '35000',
      'founding_free_months':      '6',
      'founding_monthly_mode':     'linked',
      'founding_monthly_fixed':    '500',
      'founding_storage_limit_gb': '5',
      'founding_slots_total':      '50',
      'founding_offer_end_date':   '',
      'founding_offer_enabled':    'true',
    };
  }

  /// Returns the number of shops currently on the founding plan.
  /// Used for the live slots countdown in the UI.
  Future<int> countFoundingShops() async {
    try {
      final res = await http.post(
        _restUri('/rpc/count_founding_shops'),
        headers: _anonHeaders,
        body: jsonEncode({}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is int) return data;
        if (data is Map && data.containsKey('count')) return (data['count'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('SubscriptionService.countFoundingShops error: $e');
    }
    return 0;
  }

  /// Submits a founding activation payment for admin review in unified_payments.
  Future<Map<String, dynamic>> submitFoundingActivationPayment({
    required String shopId,
    required int activationFeePkr,
    required String paymentMethod,
    String? transactionId,
    String? screenshotUrl,
  }) async {
    try {
      final amountMinor = activationFeePkr * 100;
      final body = {
        'shop_id': shopId,
        'provider_code': 'manual',
        'purpose': 'foundingActivation',
        'amount_minor': amountMinor,
        'currency': 'PKR',
        'status': 'awaitingReview',
        if (transactionId != null && transactionId.isNotEmpty) ...{
          'manual_transaction_id': transactionId,
          'provider_reference': transactionId,
        },
        if (screenshotUrl != null && screenshotUrl.isNotEmpty)
          'receipt_url': screenshotUrl,
        'metadata': {
          'plan_code': 'founding',
          'payment_method': paymentMethod,
        },
      };

      final res = await http.post(
        _restUri('/unified_payments'),
        headers: {
          ..._anonHeaders,
          'Prefer': 'return=representation',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': 'Server error ${res.statusCode}: ${res.body}',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
