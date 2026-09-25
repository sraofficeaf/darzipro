import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extensions.dart';
import 'providers/agency_providers.dart';
import 'screens/agency_earnings_screen.dart';
import 'screens/agency_overview_screen.dart';
import 'screens/agency_payouts_screen.dart';
import 'screens/agency_shops_screen.dart';

class AgencyShell extends ConsumerStatefulWidget {
  const AgencyShell({super.key});

  @override
  ConsumerState<AgencyShell> createState() => _AgencyShellState();
}

class _AgencyShellState extends ConsumerState<AgencyShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AgencyOverviewScreen(),
    AgencyShopsScreen(),
    AgencyEarningsScreen(),
    AgencyPayoutsScreen(),
  ];

  final List<String> _titles = const [
    'Agency Overview',
    'My Attributed Shops',
    'Profit Earnings',
    'Agency Payouts',
  ];

  @override
  Widget build(BuildContext context) {
    final agencyProfileAsync = ref.watch(currentAgencyProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return agencyProfileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error loading agency profile: $e')),
      ),
      data: (profile) {
        final isAgency = profile['is_agency'] == true;
        if (!isAgency) {
          // If not an agency, immediately redirect out to /dashboard
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/dashboard');
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            elevation: 0.5,
            title: Text(
              _titles[_currentIndex],
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.text1,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.dashboard_rounded),
                tooltip: 'Return to Tailor Shop',
                onPressed: () => context.go('/dashboard'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _screens[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (idx) => setState(() => _currentIndex = idx),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF0D9488),
            unselectedItemColor: context.text2,
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Overview',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.storefront_rounded),
                label: 'My Shops',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_rounded),
                label: 'Earnings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.payments_rounded),
                label: 'Payouts',
              ),
            ],
          ),
        );
      },
    );
  }
}
