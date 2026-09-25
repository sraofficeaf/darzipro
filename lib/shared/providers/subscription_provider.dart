import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/license/license_model.dart';
import '../../core/services/license/license_service.dart';
import '../../core/services/subscription_service.dart';
import 'license_provider.dart';
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
  final bool isOffline;
  final DateTime? lastVerifiedAt;

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
    this.isOffline = false,
    this.lastVerifiedAt,
  });

  /// Days since the subscription plan was last verified with the server.
  int get offlineDaysAgo {
    final baseParam = Uri.base.queryParameters['offline_days'];
    if (baseParam != null) {
      final parsed = int.tryParse(baseParam);
      if (parsed != null) return parsed;
    }
    if (Uri.base.fragment.contains('?')) {
      final fragmentUri = Uri.tryParse(Uri.base.fragment);
      final fragParam = fragmentUri?.queryParameters['offline_days'];
      if (fragParam != null) {
        final parsed = int.tryParse(fragParam);
        if (parsed != null) return parsed;
      }
    }
    if (lastVerifiedAt == null) return 0;
    return DateTime.now().difference(lastVerifiedAt!).inDays.clamp(0, 99999);
  }

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
    final isLifetime = (json['is_lifetime'] as bool? ?? false) ||
        json['subscription_status'] == 'lifetime';
    return SubscriptionState(
        planCode: json['plan_code'] as String? ?? 'trial',
        planNameEn: json['plan_name_en'] as String? ?? 'Free Trial',
        planNameUr: json['plan_name_ur'] as String? ?? 'مفت ٹرائل',
        planPricePkr: isLifetime ? 0 : ((json['plan_price_pkr'] as int?) ?? 0),
        maxOrders: json['max_orders'] as int?,
        maxCustomers: json['max_customers'] as int?,
        ordersUsed: (json['orders_used'] as int?) ?? 0,
        activeCustomers: (json['active_customers'] as int?) ?? 0,
        cycleEnd: isLifetime
            ? null
            : (json['cycle_end'] != null
                ? DateTime.tryParse(json['cycle_end'] as String)
                : null),
        amountDuePkr: isLifetime ? 0 : ((json['amount_due_pkr'] as int?) ?? 0),
        paymentStatus: isLifetime
            ? 'waived'
            : (json['payment_status'] as String? ?? 'pending'),
        subscriptionStatus: isLifetime
            ? 'lifetime'
            : (json['subscription_status'] as String? ?? 'trial'),
        isLifetime: isLifetime,
      trialStartedAt: json['trial_started_at'] != null
          ? DateTime.tryParse(json['trial_started_at'] as String)
          : null,
      foundingActivatedAt: json['founding_activated_at'] != null
          ? DateTime.tryParse(json['founding_activated_at'] as String)
          : null,
      foundingFreeUntil: json['founding_free_until'] != null
          ? DateTime.tryParse(json['founding_free_until'] as String)
          : null,
      isOffline: json['is_offline'] as bool? ?? false,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'] as String)
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
  (ref) {
    final notifier = SubscriptionNotifier(ref);

    // Actively watch currentShopIdProvider: whenever shopId resolves or changes,
    // fresh subscription state is fetched from the server immediately.
    ref.listen<String?>(currentShopIdProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        notifier.fetchForShop(next);
      } else if (next == null) {
        notifier.clear();
      }
    }, fireImmediately: true);

    ref.onDispose(() {
      notifier.clear();
    });

    return notifier;
  },
);

class SubscriptionNotifier
    extends StateNotifier<AsyncValue<SubscriptionState>> {
  final Ref _ref;
  String? _currentShopId;
  RealtimeChannel? _realtimeChannel;

  AppLifecycleListener? _lifecycleListener;

  SubscriptionNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        final sId = _currentShopId ?? _ref.read(currentShopIdProvider);
        if (sId != null && sId.isNotEmpty) {
          debugPrint('App resumed: refreshing subscription state for shop $sId');
          fetchForShop(sId, forceRefresh: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void clear() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _currentShopId = null;
    state = const AsyncValue.loading();
  }

  /// Fetches fresh subscription state for the given shopId.
  /// Server is always queried first when online.
  /// If offline/unreachable, falls back to Hive cache for this specific shop.
  Future<SubscriptionState?> fetchForShop(String shopId, {bool forceRefresh = false}) async {
    if (_currentShopId != shopId || forceRefresh) {
      _currentShopId = shopId;
      _setupRealtime(shopId);
    }

    try {
      final data = await SubscriptionService.instance
          .getShopSubscriptionState(shopId);

      if (data != null && data['error'] == null) {
        final cacheData = Map<String, dynamic>.from(data);
        cacheData['last_verified_at'] = DateTime.now().toIso8601String();
        cacheData['is_offline'] = false;

        final subState = SubscriptionState.fromJson(cacheData);
        state = AsyncValue.data(subState);

        // Cache fresh data to Hive keyed specifically to this shopId
        try {
          final box = Hive.box('license_box');
          await box.put('sub_cache_$shopId', cacheData);
        } catch (_) {}

        // Keep legacy LicenseModel in exact sync
        _syncLicenseModel(subState);

        return subState;
      } else if (data != null && data['error'] == 'shop_not_found') {
        state = AsyncValue.data(SubscriptionState.loading());
        return null;
      }
    } catch (e, st) {
      debugPrint('Subscription fetch network error: $e');

      // Offline fallback: ONLY if network is unavailable, read cached plan for this shopId
      try {
        final box = Hive.box('license_box');
        final cached = box.get('sub_cache_$shopId');
        if (cached != null) {
          final cachedMap = Map<String, dynamic>.from(cached);
          cachedMap['is_offline'] = true;
          // Stale cache rule: keep usable offline, NEVER lock, NEVER downgrade features
          final cachedState = SubscriptionState.fromJson(cachedMap);
          state = AsyncValue.data(cachedState);
          _syncLicenseModel(cachedState);
          return cachedState;
        }
      } catch (_) {}

      state = AsyncValue.error(e, st);
      return null;
    }

    return null;
  }

  void _syncLicenseModel(SubscriptionState subState) {
    try {
      final licenseModel = LicenseModel(
        plan: subState.planCode,
        licenseKey: '',
        isActive: subState.isActive,
        shopName: subState.planNameEn,
        email: '',
        activatedAt: DateTime.now(),
      );
      LicenseService().saveLicense(licenseModel);
      _ref.read(licenseProvider.notifier).updateLicense(licenseModel);
    } catch (_) {}
  }

  void _setupRealtime(String shopId) {
    _realtimeChannel?.unsubscribe();
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('public:shops:realtime:$shopId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shops',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: shopId,
            ),
            callback: (payload) {
              debugPrint('Realtime change on shop $shopId detected: refreshing plan state');
              refresh();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime setup error: $e');
    }
  }

  Future<void> refresh() async {
    final shopId = _currentShopId ?? _ref.read(currentShopIdProvider);
    if (shopId != null) {
      await fetchForShop(shopId, forceRefresh: true);
    }
  }

  /// Called after each order creation.
  Future<void> onOrderCreated() async {
    final shopId = _currentShopId ?? _ref.read(currentShopIdProvider);
    if (shopId == null) return;

    Future.microtask(() async {
      await SubscriptionService.instance.incrementCycleOrders(shopId);
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

      await refresh();
    });
  }

  /// Called after each customer creation.
  Future<void> onCustomerCreated() async {
    final shopId = _currentShopId ?? _ref.read(currentShopIdProvider);
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

      await refresh();
    });
  }
}

/// All active subscription plans from the DB.
final subscriptionPlansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SubscriptionService.instance.fetchPlans();
});
