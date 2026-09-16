import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/subscription_service.dart';
import 'supabase_providers.dart';

// ── Subscription State Model ────────────────────────────────────────────────

class SubscriptionState {
  final String planCode;
  final String planNameEn;
  final String planNameUr;
  final int planPricePkr;
  final int? maxOrders;
  final int? maxCustomers;
  final int ordersUsed;
  final int activeCustomers;
  final DateTime? cycleEnd;
  final int amountDuePkr;
  final String paymentStatus;
  final String subscriptionStatus;
  final bool isLifetime;
  final DateTime? trialStartedAt;
  // Founding Member fields
  final DateTime? foundingActivatedAt;
  final DateTime? foundingFreeUntil;

  const SubscriptionState({
    required this.planCode,
    required this.planNameEn,
    required this.planNameUr,
    required this.planPricePkr,
    this.maxOrders,
    this.maxCustomers,
    required this.ordersUsed,
    required this.activeCustomers,
    this.cycleEnd,
    required this.amountDuePkr,
    required this.paymentStatus,
    required this.subscriptionStatus,
    required this.isLifetime,
    this.trialStartedAt,
    this.foundingActivatedAt,
    this.foundingFreeUntil,
  });

  bool get isReadOnly  => subscriptionStatus == 'read_only';
  bool get isGrace     => subscriptionStatus == 'grace';
  bool get isTrial     => subscriptionStatus == 'trial';
  bool get isFounding  => planCode == 'founding' || subscriptionStatus == 'founding';
  bool get isActive    => subscriptionStatus == 'active' || isLifetime || isFounding;
  bool get isExpiring  => subscriptionStatus == 'expiring';

  /// True if the shop is in the founding FREE period (no billing yet).
  bool get isFoundingFree {
    if (!isFounding) return false;
    if (foundingFreeUntil == null) return false;
    return DateTime.now().isBefore(foundingFreeUntil!);
  }

  /// Days remaining in founding free period (null if not founding or free period over).
  int? get foundingFreeDaysRemaining {
    if (!isFoundingFree || foundingFreeUntil == null) return null;
    final diff = foundingFreeUntil!.difference(DateTime.now());
    return diff.inDays.clamp(0, 9999);
  }

  bool get isTrialExpired => SubscriptionService.isTrialExpired(
        subscriptionStatus: subscriptionStatus,
        ordersUsed: ordersUsed,
        maxOrders: maxOrders,
        trialStartedAt: trialStartedAt,
        trialDays: 14,
      );

  bool get isApproachingLimit => SubscriptionService.isApproachingLimit(
        ordersUsed: ordersUsed,
        maxOrders: maxOrders,
        activeCustomers: activeCustomers,
        maxCustomers: maxCustomers,
      );

  String? get drivingMetric => SubscriptionService.getDrivingMetric(
        ordersUsed: ordersUsed,
        maxOrders: maxOrders,
        activeCustomers: activeCustomers,
        maxCustomers: maxCustomers,
      );

  double get ordersProgress {
    if (maxOrders == null || maxOrders == 0) return 0;
    return (ordersUsed / maxOrders!).clamp(0.0, 1.0);
  }

  double get customersProgress {
    if (maxCustomers == null || maxCustomers == 0) return 0;
    return (activeCustomers / maxCustomers!).clamp(0.0, 1.0);
  }

  int? get trialOrdersRemaining => SubscriptionService.trialOrdersRemaining(
        ordersUsed: ordersUsed,
        maxOrders: maxOrders,
      );

  int? get trialDaysRemaining => SubscriptionService.trialDaysRemaining(
        trialStartedAt: trialStartedAt,
        trialDays: 14,
      );

  factory SubscriptionState.fromJson(Map<String, dynamic> json) {
    return SubscriptionState(
      planCode: json['plan_code'] as String? ?? 'trial',
      planNameEn: json['plan_name_en'] as String? ?? 'Free Trial',
      planNameUr: json['plan_name_ur'] as String? ?? 'مفت ٹرائل',
      planPricePkr: (json['plan_price_pkr'] as int?) ?? 0,
      maxOrders: json['max_orders'] as int?,
      maxCustomers: json['max_customers'] as int?,
      ordersUsed: (json['orders_used'] as int?) ?? 0,
      activeCustomers: (json['active_customers'] as int?) ?? 0,
      cycleEnd: json['cycle_end'] != null
          ? DateTime.tryParse(json['cycle_end'] as String)
          : null,
      amountDuePkr: (json['amount_due_pkr'] as int?) ?? 0,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      subscriptionStatus: json['subscription_status'] as String? ?? 'trial',
      isLifetime: json['is_lifetime'] as bool? ?? false,
      trialStartedAt: json['trial_started_at'] != null
          ? DateTime.tryParse(json['trial_started_at'] as String)
          : null,
      foundingActivatedAt: json['founding_activated_at'] != null
          ? DateTime.tryParse(json['founding_activated_at'] as String)
          : null,
      foundingFreeUntil: json['founding_free_until'] != null
          ? DateTime.tryParse(json['founding_free_until'] as String)
          : null,
    );
  }

  /// Default trial state shown while loading
  factory SubscriptionState.loading() => const SubscriptionState(
        planCode: 'trial',
        planNameEn: 'Free Trial',
        planNameUr: 'مفت ٹرائل',
        planPricePkr: 0,
        maxOrders: 20,
        maxCustomers: null,
        ordersUsed: 0,
        activeCustomers: 0,
        amountDuePkr: 0,
        paymentStatus: 'pending',
        subscriptionStatus: 'trial',
        isLifetime: false,
      );
}

// ── Auto-Upgrade Notification ───────────────────────────────────────────────

class UpgradeNotification {
  final String oldPlan;
  final String newPlan;
  final String newPlanNameEn;
  final String newPlanNameUr;
  final int newPlanPricePkr;

  const UpgradeNotification({
    required this.oldPlan,
    required this.newPlan,
    required this.newPlanNameEn,
    required this.newPlanNameUr,
    required this.newPlanPricePkr,
  });
}

// ── Providers ───────────────────────────────────────────────────────────────

/// Holds a pending auto-upgrade notification to be shown as a modal.
/// The UI reads this, shows the modal, then clears it.
final pendingUpgradeNotificationProvider =
    StateProvider<UpgradeNotification?>((ref) => null);

/// Full subscription state for the current shop.
final subscriptionStateProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<SubscriptionState>>(
  (ref) => SubscriptionNotifier(ref),
);

class SubscriptionNotifier
    extends StateNotifier<AsyncValue<SubscriptionState>> {
  final Ref _ref;

  SubscriptionNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _fetch();
  }

  Future<void> _fetch() async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) {
      state = AsyncValue.data(SubscriptionState.loading());
      return;
    }
    try {
      final data = await SubscriptionService.instance
          .getShopSubscriptionState(shopId);
      if (data != null && data['error'] == null) {
        state = AsyncValue.data(SubscriptionState.fromJson(data));
      } else {
        state = AsyncValue.data(SubscriptionState.loading());
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => _fetch();

  /// Called after each order creation.
  /// Runs check_and_apply_plan non-blocking; sets upgrade notification if needed.
  Future<void> onOrderCreated() async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;

    // Non-blocking: fire and let it run in background
    Future.microtask(() async {
      await SubscriptionService.instance.incrementCycleOrders(shopId);
      final result =
          await SubscriptionService.instance.checkAndApplyPlan(shopId);

      if (result['upgraded'] == true) {
        // Find plan display info
        final plans = await SubscriptionService.instance.fetchPlans();
        final newPlanData = plans.firstWhere(
          (p) => p['code'] == result['new_plan'],
          orElse: () => <String, dynamic>{
            'name_en': result['new_plan'],
            'name_ur': result['new_plan'],
            'price_pkr': 0,
          },
        );

        _ref.read(pendingUpgradeNotificationProvider.notifier).state =
            UpgradeNotification(
          oldPlan: result['old_plan'] as String? ?? '',
          newPlan: result['new_plan'] as String? ?? '',
          newPlanNameEn: newPlanData['name_en'] as String? ?? '',
          newPlanNameUr: newPlanData['name_ur'] as String? ?? '',
          newPlanPricePkr: (newPlanData['price_pkr'] as int?) ?? 0,
        );
      }

      // Refresh UI state
      await _fetch();
    });
  }

  /// Called after each customer creation.
  Future<void> onCustomerCreated() async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;

    Future.microtask(() async {
      final result =
          await SubscriptionService.instance.checkAndApplyPlan(shopId);

      if (result['upgraded'] == true) {
        final plans = await SubscriptionService.instance.fetchPlans();
        final newPlanData = plans.firstWhere(
          (p) => p['code'] == result['new_plan'],
          orElse: () => <String, dynamic>{
            'name_en': result['new_plan'],
            'name_ur': result['new_plan'],
            'price_pkr': 0,
          },
        );

        _ref.read(pendingUpgradeNotificationProvider.notifier).state =
            UpgradeNotification(
          oldPlan: result['old_plan'] as String? ?? '',
          newPlan: result['new_plan'] as String? ?? '',
          newPlanNameEn: newPlanData['name_en'] as String? ?? '',
          newPlanNameUr: newPlanData['name_ur'] as String? ?? '',
          newPlanPricePkr: (newPlanData['price_pkr'] as int?) ?? 0,
        );
      }

      await _fetch();
    });
  }
}

/// All active subscription plans from the DB.
final subscriptionPlansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SubscriptionService.instance.fetchPlans();
});
