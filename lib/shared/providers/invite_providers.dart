import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

int _toInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? double.tryParse(val)?.toInt() ?? 0;
  return 0;
}

String ieTimeAgo(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  } catch (_) {
    return 'Recently';
  }
}

String ieFormatAmount(int amount) {
  final formatted = amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return 'Rs $formatted';
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Stats for invite dashboard (home screen) — High Performance & Parallelized
// ─────────────────────────────────────────────────────────────────────────────
final inviteStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return {};
  final client = Supabase.instance.client;

  try {
    // ── Phase 1: Parallel Fetch Shop Details, All Earnings, Last Payout & Settings ──
    final fShop = client.from('shops').select('invite_code').eq('id', shopId).maybeSingle();
    final fEarnings = client.from('profit_earnings').select('amount, earned_at, status').eq('inviter_shop_id', shopId);
    final fLastPayout = client.from('profit_payouts').select('total_amount, paid_at, period_month').eq('inviter_shop_id', shopId).eq('status', 'paid').order('paid_at', ascending: false).limit(1).maybeSingle();
    final fSettings = client.from('app_settings').select('key, value').inFilter('key', ['minimum_payout_threshold', 'payout_delay_days']);

    final results = await Future.wait<dynamic>([
      fShop,
      fEarnings,
      fLastPayout,
      fSettings,
    ]);

    final shop = results[0] as Map<String, dynamic>?;
    final inviteCode = shop?['invite_code'] as String? ?? '';
    final allEarningsList = (results[1] as List?) ?? [];
    final lastPayout = results[2];
    final settingsList = (results[3] as List?) ?? [];

    // Parse App Settings
    int payoutThreshold = 1000;
    int payoutDelayDays = 0;
    for (final s in settingsList) {
      final k = s['key'];
      final v = s['value'];
      if (k == 'minimum_payout_threshold' && v != null) {
        payoutThreshold = int.tryParse(v.toString()) ?? 1000;
      } else if (k == 'payout_delay_days' && v != null) {
        payoutDelayDays = int.tryParse(v.toString()) ?? 0;
      }
    }

    // ── Phase 2: Compute All Earning Totals in-memory from the single allEarningsList ──
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final cutoff = now.subtract(Duration(days: payoutDelayDays));

    int totalLifetime = 0;
    int todayTotal = 0;
    int monthTotal = 0;
    int availableBalance = 0;
    int agingAmount = 0;

    for (final e in allEarningsList) {
      final amt = _toInt(e['amount']);
      totalLifetime += amt;

      final earnedAtStr = e['earned_at'];
      final earnedAt = earnedAtStr != null ? DateTime.tryParse(earnedAtStr.toString()) : null;
      final status = e['status'] as String? ?? 'pending';

      // Today's earnings
      if (earnedAt != null && !earnedAt.isBefore(todayStart)) {
        todayTotal += amt;
      }

      // This month's pending earnings
      if (status == 'pending') {
        if (earnedAt != null && !earnedAt.isBefore(monthStart)) {
          monthTotal += amt;
        }

        // Available balance vs aging
        if (payoutDelayDays <= 0 || earnedAt == null || !earnedAt.isAfter(cutoff)) {
          availableBalance += amt;
        } else {
          agingAmount += amt;
        }
      }
    }

    // ── Phase 3: Parallel Fetch for Invited Shops & Pending Registrations (Batch) ──
    int invitedCount = 0;
    int activeCount = 0;
    int inactiveCount = 0;
    int pendingCount = 0;

    if (inviteCode.isNotEmpty) {
      final fInvited = client.from('shops').select('id').eq('invited_by_code', inviteCode);
      final fPending = client.from('public_registrations').select('id').eq('invite_code_used', inviteCode).eq('status', 'pending_admin_review');

      final phase3 = await Future.wait<dynamic>([fInvited, fPending]);

      final invitedShopRows = (phase3[0] as List?) ?? [];
      invitedCount = invitedShopRows.length;
      final pendingRows = (phase3[1] as List?) ?? [];
      pendingCount = pendingRows.length;

      if (invitedShopRows.isNotEmpty) {
        final List<String> shopIds = invitedShopRows.map((s) => s['id'] as String).toList();
        // Batch query all licenses at once instead of looping!
        try {
          final licenses = await client
              .from('licenses')
              .select('shop_id, status, expires_at')
              .inFilter('shop_id', shopIds);

          final Map<String, Map<String, dynamic>> licenseMap = {};
          for (final lic in (licenses as List)) {
            final sId = lic['shop_id'] as String?;
            if (sId != null && !licenseMap.containsKey(sId)) {
              licenseMap[sId] = Map<String, dynamic>.from(lic);
            }
          }

          for (final sId in shopIds) {
            final lic = licenseMap[sId];
            if (lic != null && lic['status'] == 'active') {
              final exp = lic['expires_at'] != null ? DateTime.tryParse(lic['expires_at'].toString()) : null;
              if (exp == null || exp.isAfter(now)) {
                activeCount++;
              } else {
                inactiveCount++;
              }
            } else {
              inactiveCount++;
            }
          }
        } catch (_) {
          inactiveCount = invitedCount;
        }
      }
    }

    return {
      'invite_code': inviteCode,
      'total_lifetime': totalLifetime,
      'today_total': todayTotal,
      'month_total': monthTotal,
      'available_balance': availableBalance,
      'aging_amount': agingAmount,
      'payout_threshold': payoutThreshold,
      'payout_delay_days': payoutDelayDays,
      'last_payout': lastPayout,
      'invited_count': invitedCount,
      'active_count': activeCount,
      'inactive_count': inactiveCount,
      'pending_count': pendingCount,
    };
  } catch (e) {
    debugPrint('Error fetching invite stats: $e');
    return {};
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Recent earnings activity
// ─────────────────────────────────────────────────────────────────────────────
final profitEarningsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return [];
  final client = Supabase.instance.client;

  try {
    final data = await client.from('profit_earnings').select('*, invited_shop:shops!invited_shop_id(name)').eq('inviter_shop_id', shopId).order('earned_at', ascending: false).limit(20);
    return List<Map<String, dynamic>>.from(data);
  } catch (_) {
    try {
      final fallback = await client.from('profit_earnings').select('*').eq('inviter_shop_id', shopId).order('earned_at', ascending: false).limit(20);
      return List<Map<String, dynamic>>.from(fallback);
    } catch (_) {
      return [];
    }
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// My invited shops — High Performance Batch Fetch (No N+1 Loop Queries)
// ─────────────────────────────────────────────────────────────────────────────
final myInvitedShopsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return [];
  final client = Supabase.instance.client;

  try {
    final shop = await client.from('shops').select('invite_code').eq('id', shopId).maybeSingle();
    final inviteCode = shop?['invite_code'] as String? ?? '';
    if (inviteCode.isEmpty) return [];

    final shops = await client.from('shops').select('id, name, created_at').eq('invited_by_code', inviteCode);
    final List shopList = (shops as List?) ?? [];
    if (shopList.isEmpty) return [];

    final List<String> shopIds = shopList.map((s) => s['id'] as String).toList();

    // Batch fetch Earnings and Licenses for ALL invited shops in parallel!
    final fBatchEarnings = client.from('profit_earnings').select('invited_shop_id, amount').eq('inviter_shop_id', shopId).inFilter('invited_shop_id', shopIds);
    final fBatchLicenses = client.from('licenses').select('shop_id, status, expires_at, plan').inFilter('shop_id', shopIds);

    final batchResults = await Future.wait<dynamic>([fBatchEarnings, fBatchLicenses]);

    // Map Earnings per invited shop in memory
    final Map<String, int> earningsMap = {};
    for (final e in (batchResults[0] as List)) {
      final invShopId = e['invited_shop_id'] as String?;
      if (invShopId != null) {
        earningsMap[invShopId] = (earningsMap[invShopId] ?? 0) + _toInt(e['amount']);
      }
    }

    // Map Licenses per invited shop in memory
    final Map<String, Map<String, dynamic>> licenseMap = {};
    for (final lic in (batchResults[1] as List)) {
      final sId = lic['shop_id'] as String?;
      if (sId != null && !licenseMap.containsKey(sId)) {
        licenseMap[sId] = Map<String, dynamic>.from(lic);
      }
    }

    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    for (final s in shopList) {
      final sId = s['id'] as String;
      final total = earningsMap[sId] ?? 0;
      final isDeleted = s['name'] == '[Deleted Account]';

      String status = 'inactive';
      String plan = 'full_access';

      if (!isDeleted) {
        final lic = licenseMap[sId];
        if (lic != null) {
          plan = lic['plan'] ?? plan;
          if (lic['status'] == 'active') {
            final exp = lic['expires_at'] != null ? DateTime.tryParse(lic['expires_at'].toString()) : null;
            status = (exp == null || exp.isAfter(now)) ? 'active' : 'inactive';
          }
        }
      }

      result.add({
        'id': sId,
        'name': s['name'],
        'created_at': s['created_at'],
        'total_earned_from': total,
        'status': status,
        'plan': plan,
      });
    }

    return result;
  } catch (e) {
    debugPrint('Error loading invited shops: $e');
    return [];
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Payout history
// ─────────────────────────────────────────────────────────────────────────────
final payoutHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return [];
  final client = Supabase.instance.client;
  try {
    final data = await client.from('profit_payouts').select().eq('inviter_shop_id', shopId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Invite Settings
// ─────────────────────────────────────────────────────────────────────────────
final inviteSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return {};
  final client = Supabase.instance.client;
  try {
    final data = await client.from('shops').select('payout_method, payout_account_number, payout_account_name, invite_code').eq('id', shopId).maybeSingle();
    return Map<String, dynamic>.from(data ?? {});
  } catch (_) {
    return {};
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Save payout settings
// ─────────────────────────────────────────────────────────────────────────────
Future<bool> savePayoutSettings({
  required String shopId,
  required String method,
  required String accountNumber,
  required String accountName,
}) async {
  try {
    await Supabase.instance.client.from('shops').update({
      'payout_method': method,
      'payout_account_number': accountNumber,
      'payout_account_name': accountName,
    }).eq('id', shopId);
    return true;
  } catch (e) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification preferences
// ─────────────────────────────────────────────────────────────────────────────
class IeNotifPrefs {
  final bool notifyOnEarn;
  final bool notifyOnPayout;
  IeNotifPrefs({this.notifyOnEarn = true, this.notifyOnPayout = true});
  IeNotifPrefs copyWith({bool? notifyOnEarn, bool? notifyOnPayout}) => IeNotifPrefs(
        notifyOnEarn: notifyOnEarn ?? this.notifyOnEarn,
        notifyOnPayout: notifyOnPayout ?? this.notifyOnPayout,
      );
}

final ieNotifPrefsProvider = StateNotifierProvider<_IeNotifNotifier, IeNotifPrefs>((_) => _IeNotifNotifier());

class _IeNotifNotifier extends StateNotifier<IeNotifPrefs> {
  _IeNotifNotifier() : super(IeNotifPrefs());
  void toggleEarn(bool val) => state = state.copyWith(notifyOnEarn: val);
  void togglePayout(bool val) => state = state.copyWith(notifyOnPayout: val);
}
