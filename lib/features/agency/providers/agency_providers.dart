import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/supabase_providers.dart';

/// Provider returning the current shop's agency profile status
final currentAgencyProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return {'is_agency': false};

  try {
    final client = Supabase.instance.client;
    final res = await client.rpc('get_current_agency_profile');
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
  } catch (_) {}
  return {'is_agency': false};
});

/// Convenience boolean provider indicating whether the active shop is an agency
final isCurrentShopAgencyProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentAgencyProfileProvider);
  return profileAsync.valueOrNull?['is_agency'] == true;
});

/// Agency Overview provider
final agencyOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(currentShopIdProvider);
  final client = Supabase.instance.client;
  final res = await client.rpc('get_agency_overview');
  return Map<String, dynamic>.from(res as Map);
});

/// Agency Attributed Shops provider (strict privacy isolation)
final agencyShopsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentShopIdProvider);
  final client = Supabase.instance.client;
  final res = await client.rpc('get_agency_shops');
  if (res is List) {
    return List<Map<String, dynamic>>.from(res);
  }
  return [];
});

/// Agency Earnings provider (filterable by month e.g. '2026-09')
final agencyEarningsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, month) async {
  ref.watch(currentShopIdProvider);
  final client = Supabase.instance.client;
  final res = await client.rpc('get_agency_earnings', params: {'p_month': month});
  if (res is List) {
    return List<Map<String, dynamic>>.from(res);
  }
  return [];
});

/// Agency Payouts history provider
final agencyPayoutsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentShopIdProvider);
  final client = Supabase.instance.client;
  final res = await client.rpc('get_agency_payouts');
  if (res is List) {
    return List<Map<String, dynamic>>.from(res);
  }
  return [];
});

