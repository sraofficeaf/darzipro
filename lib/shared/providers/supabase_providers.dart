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
  return authState?.session?.user.id ?? Supabase.instance.client.auth.currentUser?.id;
});

// Fetch current user's profile
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  try {
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase.from('profiles').select().eq('id', userId).maybeSingle();
    return data;
  } catch (_) {
    return null;
  }
});

// Fetch current shop id and auto-sync active license from database
final currentShopIdProvider = Provider<String?>((ref) {
  final profileAsync = ref.watch(profileProvider);
  final shopId = profileAsync.value?['shop_id'] as String?;
  
  if (shopId != null) {
    // Run async sync task in microtask to prevent side-effects in provider evaluation
    Future.microtask(() async {
      try {
        final client = Supabase.instance.client;
        final response = await client
            .from('licenses')
            .select()
            .eq('shop_id', shopId)
            .eq('status', 'active')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          final expiresAtStr = response['expires_at'];
          final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
          final licenseModel = LicenseModel(
            plan: response['plan'] ?? 'pro',
            licenseKey: response['license_key'] ?? '',
            isActive: true,
            expiresAt: expiresAt,
            shopName: response['shop_name'] ?? '',
            email: response['email'] ?? '',
            activatedAt: DateTime.now(),
          );
          
          await LicenseService().saveLicense(licenseModel);
          ref.read(licenseProvider.notifier).updateLicense(licenseModel);
        }
      } catch (e) {
        // Fail silently if offline/error
      }
    });
  } else if (profileAsync.hasValue && profileAsync.value == null && Supabase.instance.client.auth.currentUser == null) {
    // Only clear license details locally when explicitly signed out (auth user is null)
    Future.microtask(() {
      ref.read(licenseProvider.notifier).deactivate();
    });
  }
  
  return shopId;
});

// Fetch current shop details
final currentShopProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return null;

  try {
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase.from('shops').select().eq('id', shopId).maybeSingle();
    return data;
  } catch (_) {
    return null;
  }
});

final shopPlanProvider = FutureProvider<String?>((ref) async {
  final license = ref.watch(licenseProvider);
  return license.plan;
});
