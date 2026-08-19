import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/admin_service.dart';

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
  AdminAuthNotifier() : super(AdminAuthState());

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
  return authState.isAuthenticated;
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

