import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/admin_service.dart';
import 'supabase_providers.dart';

// Authentication State
class AdminAuthState {
  final bool isAuthenticated;
  final String? adminName;
  final String? adminEmail;
  final String? error;

  AdminAuthState({
    this.isAuthenticated = false,
    this.adminName,
    this.adminEmail,
    this.error,
  });
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  AdminAuthNotifier() : super(AdminAuthState()) {
    _rehydrateFromSession();
  }

  Future<void> _rehydrateFromSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final email = session?.user.email;
      if (email != null && email.isNotEmpty && !session!.isExpired) {
        final adminUser = await Supabase.instance.client
            .from('admin_users')
            .select('id, name, email, role')
            .eq('email', email)
            .maybeSingle();

        if (adminUser != null) {
          final name = (adminUser['name'] as String?) ?? 'Super Admin';
          state = AdminAuthState(
            isAuthenticated: true,
            adminEmail: email,
            adminName: name,
          );
        }
      }
    } catch (e) {
      debugPrint('AdminAuthNotifier session rehydration error: $e');
    }
  }

  void setLoggedInAdmin({required String email, required String name}) {
    state = AdminAuthState(
      isAuthenticated: true,
      adminEmail: email,
      adminName: name,
    );
  }

  Future<bool> login(String email, String password) async {
    final admin = await AdminService.instance.loginAdmin(email, password);
    if (admin != null) {
      final name = admin['name'] ?? 'Super Admin';
      state = AdminAuthState(
        isAuthenticated: true,
        adminEmail: email,
        adminName: name,
      );
      return true;
    } else {
      state = AdminAuthState(error: 'Invalid credentials');
      return false;
    }
  }

  void logout() {
    state = AdminAuthState();
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) => AdminAuthNotifier());

/// Provider to check if the current user is an authenticated Admin (Dynamic check)
final isUserAdminProvider = Provider<bool>((ref) {
  final authState = ref.watch(adminAuthProvider);
  if (authState.isAuthenticated) return true;

  // 1. Check profile role if available
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile != null) {
    final role = profile['role'] as String?;
    if (role == 'super_admin' || role == 'admin') {
      return true;
    }
  }

  // 2. Check active Supabase session
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null && !session.isExpired) {
    final email = session.user.email?.toLowerCase();
    if (email != null && email.isNotEmpty) {
      if (email == 'sraoffice.af@gmail.com') {
        return true;
      }
    }
  }

  return false;
});

// Licenses AsyncNotifier
final adminLicensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchLicenses();
});

// Payments AsyncNotifier
final adminPaymentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchPayments();
});

// Versions AsyncNotifier
final adminVersionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchAppVersions();
});

// Public Registrations (pending_admin_review)
final adminRegistrationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchRegistrations('pending_admin_review');
});

// All Registrations (any status)
final adminAllRegistrationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchRegistrations();
});

// Pending earnings grouped by inviter shop
final adminPendingEarningsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchAdminPendingEarnings();
});

// All payouts (admin view)
final adminPayoutsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchAdminPayouts();
});

// Upgrade requests (pending admin review)
final adminUpgradeRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchUpgradeRequests();
});

// Storage addon payments (pending admin review)
final adminStorageAddonsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchPendingStorageAddonPayments();
});

// Unified Financial & Reports Data Provider (All-time or default this month)
final adminReportsDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final now = DateTime.now();
  final start = DateTime(2020, 1, 1); // Lifetime / All-time for unified overview
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return await AdminService.instance.fetchReportsData(startDate: start, endDate: end);
});

// Subscription payments pending admin review
final adminSubscriptionPaymentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchSubscriptionPayments();
});

// Subscription plan definitions (admin CRUD)
final adminSubscriptionPlansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchSubscriptionPlans();
});

// Subscription stats: MRR, plan breakdown, grace/read-only counts, upcoming renewals
final adminSubscriptionStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await AdminService.instance.fetchSubscriptionStats();
});

// Unresolved critical audit alerts (e.g. test payment bypassed on live shop)
final adminAuditAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AdminService.instance.fetchAuditAlerts();
});

