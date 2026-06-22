import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/customers/add_customer_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/orders/new_order_screen.dart';
import '../../features/measurements/measurements_screen.dart';
import '../../features/printing/token_card_screen.dart';
import '../../features/printing/print_preview_screen.dart';
import '../../features/billing/add_payment_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/upgrade_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../responsive/app_shell.dart';
import '../constants/app_enums.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const customers = '/customers';
  static const customerDetail = '/customers/:id';
  static const addCustomer = '/customers/add';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const newOrder = '/orders/new';
  static const measurements = '/measurements';
  static const tokenCard = '/token-card/:orderId';
  static const printPreview = '/print/:orderId';
  static const addPayment = '/payment/:orderId';
  static const reports = '/reports';
  static const settings = '/settings';
  static const profile = '/profile';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.customers,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CustomersScreen(),
          ),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddCustomerScreen(),
            ),
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
          pageBuilder: (context, state) => const NoTransitionPage(
            child: OrdersScreen(),
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const NewOrderScreen(),
            ),
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
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MeasurementsScreen(),
          ),
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
          path: '/payment/:orderId',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId']!;
            return AddPaymentScreen(orderId: orderId);
          },
        ),
        GoRoute(
          path: AppRoutes.reports,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ReportsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/upgrade',
          builder: (context, state) => const UpgradeScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);
