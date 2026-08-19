import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/measurements/measurements_screen.dart';
import '../../features/printing/token_card_screen.dart';
import '../../features/printing/print_preview_screen.dart';

import '../../features/reports/reports_screen.dart';
import '../../features/settings/upgrade_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_approvals_screen.dart';
import '../../features/admin/admin_shops_screen.dart';
import '../../features/admin/admin_revenue_screen.dart';
import '../../features/admin/admin_notifications_screen.dart';
import '../../features/admin/admin_versions_screen.dart';
import '../../features/admin/admin_invites_screen.dart';
import '../../features/admin/admin_support_screen.dart';
import '../../features/admin/admin_reports_screen.dart';
import '../../features/admin/admin_settings_screen.dart';

import '../../features/invite_earn/invite_earn_shell.dart';
import '../../features/registration/registration_flow_screen.dart';
import '../../features/auth/platform_blocked_screen.dart';
import '../../features/upgrade/upgrade_request_screen.dart';
import '../responsive/app_shell.dart';

import '../constants/app_enums.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const customers = '/customers';
  static const customerDetail = '/customers/:id';

  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const measurements = '/measurements';
  static const tokenCard = '/token-card/:orderId';
  static const printPreview = '/print/:orderId';

  static const reports = '/reports';
  static const adminReports = '/admin/reports';
  static const settings = '/settings';

  static const profile = '/profile';
  static const reminders = '/reminders';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  // ── SECURITY: Global auth redirect guard ─────────────────────────────────
  // Runs on every navigation. Protects user + admin routes.
  redirect: (context, state) {
    final location = state.matchedLocation;

    // Public routes — always accessible
    final publicRoutes = ['/', '/login', '/forgot-password', '/join', '/register'];
    final isPublic = publicRoutes.any((r) => location == r || location.startsWith(r));
    if (isPublic) return null;

    // Check Supabase session for user routes
    final session = Supabase.instance.client.auth.currentSession;
    final isUserLoggedIn = session != null && !session.isExpired;

    // Admin routes: require admin auth state (checked in AdminShell too)
    if (location.startsWith('/admin')) {
      // AdminShell handles the admin auth check via adminAuthProvider.
      // We still require a valid Supabase session as base requirement.
      if (!isUserLoggedIn) return '/login';
      return null; // AdminShell will handle admin-specific check
    }

    // All other protected routes: require Supabase session
    if (!isUserLoggedIn) return '/login';
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    // ── Public registration (no auth required) ────────────────────────
    GoRoute(
      path: '/join',
      builder: (context, state) => const RegistrationFlowScreen(),
    ),
    GoRoute(
      path: '/register',
      redirect: (context, state) => '/join',
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.customers,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CustomersScreen()),
          routes: [

            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return CustomerDetailScreen(customerId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.orders,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: OrdersScreen()),
          routes: [

            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return OrderDetailScreen(orderId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.measurements,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MeasurementsScreen()),
          routes: [
            GoRoute(
              path: ':customerId/:customerName',
              builder: (context, state) {
                final customerId = state.pathParameters['customerId']!;
                final customerName = state.pathParameters['customerName']!;
                final categoryStr = state.uri.queryParameters['category'];
                MeasurementCategory? category;
                if (categoryStr != null) {
                  try {
                    category = MeasurementCategory.values.firstWhere(
                      (c) => c.name == categoryStr || c.label == categoryStr,
                    );
                  } catch (_) {}
                }
                return MeasurementsScreen(
                  customerId: customerId,
                  customerName: customerName,
                  category: category,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/token-card',
          builder: (context, state) => const TokenCardScreen(orderId: ''),
        ),
        GoRoute(
          path: '/token-card/:orderId',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId'] ?? '';
            return TokenCardScreen(orderId: orderId);
          },
        ),
        GoRoute(
          path: '/print/:orderId',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId']!;
            return PrintPreviewScreen(orderId: orderId);
          },
        ),

        GoRoute(
          path: AppRoutes.reports,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ReportsScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          redirect: (context, state) => AppRoutes.profile,
        ),
        GoRoute(
          path: '/upgrade',
          builder: (context, state) => const UpgradeScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfileScreen()),
        ),
        GoRoute(
          path: AppRoutes.reminders,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: RemindersScreen()),
        ),
        GoRoute(
          path: '/platform-blocked',
          builder: (context, state) => const PlatformBlockedScreen(),
        ),
        GoRoute(
          path: '/upgrade-plan',
          builder: (context, state) => const UpgradeRequestScreen(),
        ),
        // ── Invite Dashboard (legacy redirect) ────────────────────────
        GoRoute(
          path: '/invites',
          redirect: (context, state) => '/invite-earn',
        ),
      ],
    ),
    // ── Invite & Earn standalone shell ──────────────────────────────────
    GoRoute(
      path: '/invite-earn',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const InviteEarnShell(),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/admin',
          redirect: (context, state) => '/admin/dashboard',
        ),
        GoRoute(
          path: '/admin/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminDashboardScreen()),
        ),
        GoRoute(
          path: '/admin/approvals',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminApprovalsScreen()),
        ),

        GoRoute(
          path: '/admin/shops',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminShopsScreen()),
        ),
        GoRoute(
          path: '/admin/revenue',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminRevenueScreen()),
        ),
        GoRoute(
          path: '/admin/invites',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminInvitesScreen()),
        ),
        GoRoute(
          path: '/admin/notifications',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminNotificationsScreen()),
        ),
        GoRoute(
          path: '/admin/versions',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminVersionsScreen()),
        ),
        GoRoute(
          path: AppRoutes.adminReports,
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminReportsScreen()),
        ),

        GoRoute(
          path: '/admin/support',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminSupportScreen()),
        ),

        GoRoute(
          path: '/admin/settings',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminSettingsScreen()),
        ),
        // Legacy redirects to Approvals
        GoRoute(path: '/admin/registrations', redirect: (context, state) => '/admin/approvals'),
        GoRoute(path: '/admin/upgrades', redirect: (context, state) => '/admin/approvals'),
        GoRoute(path: '/admin/licenses', redirect: (context, state) => '/admin/approvals'),
        GoRoute(path: '/admin/users', redirect: (context, state) => '/admin/approvals'),
      ],
    ),

  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
);

class GoRouterModalWrapper extends ConsumerStatefulWidget {
  final Future<void> Function(BuildContext context, WidgetRef ref) showModal;

  const GoRouterModalWrapper({super.key, required this.showModal});

  @override
  ConsumerState<GoRouterModalWrapper> createState() => _GoRouterModalWrapperState();
}

class _GoRouterModalWrapperState extends ConsumerState<GoRouterModalWrapper> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await widget.showModal(context, ref);
        if (mounted && context.mounted) {
          context.pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}
