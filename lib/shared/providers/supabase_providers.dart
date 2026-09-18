import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'license_provider.dart';
import '../../core/services/license/license_model.dart';
import '../../core/services/license/license_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state stream
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// Current user id provider
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user.id ??
      Supabase.instance.client.auth.currentUser?.id;
});

// Fetch current user's profile
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  try {
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data;
  } catch (_) {
    return null;
  }
});

// Fetch current shop id — also syncs subscription state from shops table.
// No longer reads from the legacy `licenses` table for plan gating.
final currentShopIdProvider = Provider<String?>((ref) {
  final profileAsync = ref.watch(profileProvider);
  final shopId = profileAsync.value?['shop_id'] as String?;

  if (shopId != null) {
    // Sync shop's plan_code into LicenseModel for backward compat
    Future.microtask(() async {
      try {
        final client = Supabase.instance.client;
        final shopData = await client
            .from('shops')
            .select('plan_code, subscription_status, lifetime_access, name')
            .eq('id', shopId)
            .maybeSingle();

        if (shopData != null) {
          final planCode = shopData['plan_code'] as String? ?? 'trial';
          final isLifetime = shopData['lifetime_access'] as bool? ?? false;
          final effectivePlan = isLifetime ? 'lifetime' : planCode;

          final licenseModel = LicenseModel(
            plan: effectivePlan,
            licenseKey: '',
            isActive: true,
            shopName: shopData['name'] as String? ?? '',
            email: '',
            activatedAt: DateTime.now(),
          );
          await LicenseService().saveLicense(licenseModel);
          ref.read(licenseProvider.notifier).updateLicense(licenseModel);
        }
      } catch (e) {
        // Fail silently — offline or error
      }
    });
  } else if (profileAsync.hasValue &&
      profileAsync.value == null &&
      Supabase.instance.client.auth.currentUser == null) {
    // Clear license details when explicitly signed out
    Future.microtask(() {
      ref.read(licenseProvider.notifier).deactivate();
    });
  }

  return shopId;
});

// Fetch current shop details (full row including subscription columns)
final currentShopProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return null;

  try {
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase
        .from('shops')
        .select(
            'id, name, phone, address, owner_name, logo_url, currency, plan_code, subscription_status, billing_cycle_start, billing_cycle_end, trial_started_at, lifetime_access, lifetime_storage_limit_bytes, storage_used_bytes, storage_addon_active')
        .eq('id', shopId)
        .maybeSingle();
    return data;
  } catch (_) {
    return null;
  }
});

// Convenience provider: current plan code from shop data
final shopPlanCodeProvider = Provider<String>((ref) {
  final shopAsync = ref.watch(currentShopProvider);
  return shopAsync.value?['plan_code'] as String? ?? 'trial';
});

// Convenience provider: current subscription status
final shopSubscriptionStatusProvider = Provider<String>((ref) {
  final shopAsync = ref.watch(currentShopProvider);
  return shopAsync.value?['subscription_status'] as String? ?? 'trial';
});

// True if shop is in read-only mode (unpaid grace expired)
final isReadOnlyProvider = Provider<bool>((ref) {
  return ref.watch(shopSubscriptionStatusProvider) == 'read_only';
});

// True if shop has lifetime access
final isLifetimeProvider = Provider<bool>((ref) {
  final shopAsync = ref.watch(currentShopProvider);
  return shopAsync.value?['lifetime_access'] as bool? ?? false;
});

// Legacy plan provider — kept for backward compat, maps to new plan code
final shopPlanProvider = FutureProvider<String?>((ref) async {
  final license = ref.watch(licenseProvider);
  return license.plan;
});
