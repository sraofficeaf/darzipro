import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// Fetch current shop id
final currentShopIdProvider = Provider<String?>((ref) {
  final profileAsync = ref.watch(profileProvider);
  return profileAsync.value?['shop_id'] as String?;
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
