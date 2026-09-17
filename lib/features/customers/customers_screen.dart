import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_enums.dart';
import '../../core/router/app_router.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../orders/new_order_modal.dart';
import 'add_customer_modal.dart';

// ── COLOR SYSTEM & TOKENS (MATCHING HTML MOCKUP) ─────────────────────────────
class _ClientColors {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const faint = Color(0xFFAAB2BF);
  static const line = Color(0xFFE8EAF0);
  static const paper = Color(0xFFF5F6F8);
  static const dark = Color(0xFF151922);
  static const darkCard = Color(0xFF181D27);
  static const darkSurface = Color(0xFF1D222D);
  static const darkLine = Color(0xFF333946);

  static const gold = Color(0xFFE9A227);
  static const gold2 = Color(0xFFFFC65A);
  static const goldBg = Color(0xFFFFF6E5);
  static const goldLine = Color(0xFFF3DDA8);

  static const green = Color(0xFF18B887);
  static const greenBg = Color(0xFFEAFBF5);

  static const rose = Color(0xFFEF5261);

  static const blue = Color(0xFF5478E8);
  static const blueBg = Color(0xFFEEF2FF);

  static const violet = Color(0xFF8764E8);

  static const whatsapp = Color(0xFF25D366);
}

// ── TYPOGRAPHY STYLES (CACHED FOR ZERO RUNTIME ALLOCATIONS) ───────────────────
class _ClientStyles {
  static final heroTitle = GoogleFonts.manrope(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.6,
  );
  static final heroSubtitle = GoogleFonts.dmSans(
    fontSize: 12,
    color: const Color(0xFFAEB5C2),
  );
  static final sectionTitle = GoogleFonts.manrope(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: _ClientColors.ink,
    letterSpacing: -0.7,
  );
  static final sectionSubtitle = GoogleFonts.dmSans(
    fontSize: 11.5,
    color: _ClientColors.muted,
  );
  static final cardTag = GoogleFonts.dmSans(
    fontSize: 9.5,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.6,
    color: _ClientColors.muted,
  );
}

// ── FAST IN-MEMORY STATS COMPUTATION ──────────────────────────────────────────
class _CustomerStats {
  final int total;
  final int active;
  final int men;
  final int women;
  final int child;
  final int newThisWeek;

  const _CustomerStats({
    required this.total,
    required this.active,
    required this.men,
    required this.women,
    required this.child,
    required this.newThisWeek,
  });

  factory _CustomerStats.fromList(List<CustomerModel> list) {
    int total = list.length;
    int active = 0;
    int men = 0;
    int women = 0;
    int child = 0;
    int newThisWeek = 0;
    final now = DateTime.now();

    for (final c in list) {
      if (c.totalOrders > 0) active++;
      if (c.gender == CustomerGender.male) {
        men++;
      } else if (c.gender == CustomerGender.female) {
        women++;
      } else if (c.gender == CustomerGender.child) {
        child++;
      }
      if (now.difference(c.createdAt).inDays <= 7) newThisWeek++;
    }

    return _CustomerStats(
      total: total,
      active: active,
      men: men,
      women: women,
      child: child,
      newThisWeek: newThisWeek,
    );
  }
}

// ── CUSTOMERS SCREEN ─────────────────────────────────────────────────────────
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(customerSearchProvider);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(customerSearchProvider.notifier).state = val;
      }
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    ref.read(customerSearchProvider.notifier).state = '';
  }

  void _onFilterChanged(CustomerGender? gender) {
    final current = ref.read(customerGenderFilterProvider);
    ref.read(customerGenderFilterProvider.notifier).state = current == gender ? null : gender;
  }

  Future<void> _exportClientsCSV(List<CustomerModel> list) async {
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clients to export')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Name,Phone,Gender,Address,Total Orders,Created At');
    for (final c in list) {
      final genderStr = c.gender == CustomerGender.male
          ? 'Men'
          : (c.gender == CustomerGender.female ? 'Women' : 'Children');
      buffer.writeln(
        '"${c.name.replaceAll('"', '""')}",'
        '"${c.phone.replaceAll('"', '""')}",'
        '$genderStr,'
        '"${c.address.replaceAll('"', '""')}",'
        '${c.totalOrders},'
        '${c.createdAt.toIso8601String().substring(0, 10)}',
      );
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: 'darzi_pro_clients.csv')],
        text: 'Darzi Pro Clients Export',
      );
    } catch (_) {
      await Share.share(buffer.toString(), subject: 'Darzi Pro Clients Export');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCustomersAsync = ref.watch(customersProvider);
    final filteredAsync = ref.watch(filteredCustomersProvider);
    final genderFilter = ref.watch(customerGenderFilterProvider);

    final allCustomers = allCustomersAsync.valueOrNull ?? const [];
    final stats = _CustomerStats.fromList(allCustomers);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Scaffold(
      backgroundColor: _ClientColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top Hero Header matching HTML
            RepaintBoundary(
              child: _buildHeroHeader(stats, allCustomers, isDesktop),
            ),

            // Main Body: Responsive Desktop vs Mobile
            Expanded(
              child: isDesktop
                  ? _buildDesktopLayout(stats, filteredAsync, genderFilter, allCustomers)
                  : _buildMobileLayout(stats, filteredAsync, genderFilter, allCustomers),
            ),
          ],
        ),
      ),
    );
  }

  // ── HERO HEADER (MATCHING HTML: DARK ROUNDED BANNER + GOLD BRAND MARK) ──────
  Widget _buildHeroHeader(_CustomerStats stats, List<CustomerModel> allCustomers, bool isDesktop) {
    return Container(
      margin: EdgeInsets.fromLTRB(isDesktop ? 16 : 10, isDesktop ? 16 : 6, isDesktop ? 16 : 10, isDesktop ? 12 : 8),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 22 : 10, vertical: isDesktop ? 16 : 10),
      decoration: BoxDecoration(
        color: _ClientColors.dark,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28151922),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          // Brand Mark: Gold Gradient 'D' (Only on desktop to save mobile width)
          if (isDesktop) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_ClientColors.gold2, _ClientColors.gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'D',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF241605),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
          ],

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Clients', style: _ClientStyles.heroTitle.copyWith(fontSize: isDesktop ? 21 : 16)),
                if (isDesktop) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Manage your shop customers · اپنے گاہکوں کا انتظام',
                    style: _ClientStyles.heroSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Action Buttons: Search, Export, Add Client
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeroButton(
                icon: Icons.search_rounded,
                label: 'Search',
                isPrimary: false,
                isDesktop: isDesktop,
                onTap: () => _searchFocusNode.requestFocus(),
              ),
              SizedBox(width: isDesktop ? 8 : 5),
              _buildHeroButton(
                icon: Icons.download_rounded,
                label: 'Export',
                isPrimary: false,
                isDesktop: isDesktop,
                onTap: () => _exportClientsCSV(allCustomers),
              ),
              SizedBox(width: isDesktop ? 8 : 5),
              _buildHeroButton(
                icon: Icons.add_rounded,
                label: 'Add Client',
                isPrimary: true,
                isDesktop: isDesktop,
                onTap: () => AddCustomerModal.show(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required bool isDesktop,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: isDesktop ? 38 : 34,
          width: isDesktop ? null : 34,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 13 : 0),
          decoration: BoxDecoration(
            color: isPrimary ? _ClientColors.gold : _ClientColors.darkSurface,
            border: Border.all(
              color: isPrimary ? _ClientColors.gold : _ClientColors.darkLine,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isDesktop ? 15 : 16,
                  color: isPrimary ? const Color(0xFF211500) : const Color(0xFFE9ECF2),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPrimary ? const Color(0xFF211500) : const Color(0xFFE9ECF2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── DESKTOP LAYOUT (2 COLUMNS: STICKY SIDEBAR + MAIN CONTENT) ────────────────
  Widget _buildDesktopLayout(
    _CustomerStats stats,
    AsyncValue<List<CustomerModel>> filteredAsync,
    CustomerGender? genderFilter,
    List<CustomerModel> allCustomers,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDEBAR (WIDTH 300PX)
          SizedBox(
            width: 300,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: RepaintBoundary(
                child: _buildDesktopSidebar(stats, genderFilter, allCustomers),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // RIGHT MAIN VIEW
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RepaintBoundary(child: _buildDesktopNavbar(stats)),
                const SizedBox(height: 14),

                // Overview Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Client Directory', style: _ClientStyles.sectionTitle),
                        const SizedBox(height: 2),
                        Text('Browse, search, and manage all your shop customers.', style: _ClientStyles.sectionSubtitle),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: _ClientColors.greenBg,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _ClientColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${stats.active} active records',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _ClientColors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar
                _buildSearchBar(),
                const SizedBox(height: 12),

                // Filter Chips Row
                _buildFilterChipsRow(stats, genderFilter),
                const SizedBox(height: 12),

                // Virtualized Client List
                Expanded(
                  child: _buildClientList(filteredAsync),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DESKTOP SIDEBAR WIDGET ──────────────────────────────────────────────────
  Widget _buildDesktopSidebar(
    _CustomerStats stats,
    CustomerGender? genderFilter,
    List<CustomerModel> allCustomers,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _ClientColors.line),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E111827),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cover Card with Golden People Icon
          Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_ClientColors.darkCard, Color(0xFF1F2633)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_ClientColors.gold2, _ClientColors.gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _ClientColors.gold.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.people_alt_rounded, color: Color(0xFF241505), size: 26),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Client Directory',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stats.total} total clients',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFAEB5C2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Sidebar Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2x2 Stats Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.65,
                  children: [
                    _buildSidebarStatCard('${stats.total}', 'TOTAL', _ClientColors.gold),
                    _buildSidebarStatCard('${stats.active}', 'ACTIVE', _ClientColors.green),
                    _buildSidebarStatCard('${stats.men}', 'MEN', _ClientColors.ink),
                    _buildSidebarStatCard('${stats.newThisWeek}', 'NEW THIS WEEK', _ClientColors.rose),
                  ],
                ),
                const SizedBox(height: 18),

                // Quick Filters Header
                Text('QUICK FILTERS', style: _ClientStyles.cardTag),
                const SizedBox(height: 9),

                // Filters List
                _buildSidebarFilterOption(
                  emoji: '👥',
                  title: 'All Clients',
                  count: stats.total,
                  isActive: genderFilter == null,
                  onTap: () => _onFilterChanged(null),
                ),
                const SizedBox(height: 5),
                _buildSidebarFilterOption(
                  emoji: '👔',
                  title: 'Men',
                  count: stats.men,
                  isActive: genderFilter == CustomerGender.male,
                  onTap: () => _onFilterChanged(CustomerGender.male),
                ),
                const SizedBox(height: 5),
                _buildSidebarFilterOption(
                  emoji: '👗',
                  title: 'Women',
                  count: stats.women,
                  isActive: genderFilter == CustomerGender.female,
                  onTap: () => _onFilterChanged(CustomerGender.female),
                ),
                const SizedBox(height: 5),
                _buildSidebarFilterOption(
                  emoji: '👕',
                  title: 'Children',
                  count: stats.child,
                  isActive: genderFilter == CustomerGender.child,
                  onTap: () => _onFilterChanged(CustomerGender.child),
                ),
                const SizedBox(height: 18),

                // Quick Action Buttons
                Container(
                  padding: const EdgeInsets.only(top: 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _ClientColors.line)),
                  ),
                  child: Column(
                    children: [
                      _buildSidebarActionButton(
                        icon: Icons.add_rounded,
                        label: 'Add New Client',
                        isGold: true,
                        onTap: () => AddCustomerModal.show(context),
                      ),
                      const SizedBox(height: 7),
                      _buildSidebarActionButton(
                        icon: Icons.download_rounded,
                        label: 'Export Clients',
                        isGold: false,
                        onTap: () => _exportClientsCSV(allCustomers),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarStatCard(String count, String label, Color numColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        border: Border.all(color: _ClientColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: numColor,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: _ClientColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFilterOption({
    required String emoji,
    required String title,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? _ClientColors.dark : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? _ClientColors.dark : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 13))),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : _ClientColors.ink,
                  ),
                ),
              ),
              Text(
                '$count',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isActive ? const Color(0xFFAEB5C2) : _ClientColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarActionButton({
    required IconData icon,
    required String label,
    required bool isGold,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isGold ? _ClientColors.gold : const Color(0xFFFAFAFB),
            border: Border.all(
              color: isGold ? _ClientColors.gold : _ClientColors.line,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isGold ? const Color(0xFF211500) : _ClientColors.ink,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isGold ? const Color(0xFF211500) : _ClientColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DESKTOP NAVBAR WIDGET ───────────────────────────────────────────────────
  Widget _buildDesktopNavbar(_CustomerStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _ClientColors.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildNavTab(
                title: 'Clients',
                icon: Icons.people_alt_rounded,
                isActive: true,
                badgeCount: stats.total,
                onTap: () {},
              ),
              const SizedBox(width: 6),
              _buildNavTab(
                title: 'Orders',
                icon: Icons.inventory_2_outlined,
                isActive: false,
                onTap: () => context.go(AppRoutes.orders),
              ),
              const SizedBox(width: 6),
              _buildNavTab(
                title: 'Naap',
                icon: Icons.straighten_rounded,
                isActive: false,
                onTap: () => context.go(AppRoutes.measurements),
              ),
              const SizedBox(width: 6),
              _buildNavTab(
                title: 'Reports',
                icon: Icons.analytics_outlined,
                isActive: false,
                onTap: () => context.go(AppRoutes.reports),
              ),
            ],
          ),
          Row(
            children: [
              _buildNavSquare(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh list',
                onTap: () => ref.invalidate(customersProvider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required String title,
    required IconData icon,
    required bool isActive,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? _ClientColors.dark : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    const BoxShadow(
                      color: Color(0x18151922),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? Colors.white : _ClientColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : _ClientColors.muted,
                ),
              ),
              if (badgeCount != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$badgeCount',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isActive ? _ClientColors.gold2 : _ClientColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavSquare({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: _ClientColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _ClientColors.muted),
          ),
        ),
      ),
    );
  }

  // ── SEARCH BAR WIDGET (DEBOUNCED, HIGH PERFORMANCE) ──────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _ClientColors.line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: _ClientColors.faint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ClientColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or address...',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _ClientColors.faint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _ClientColors.paper,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.close_rounded, size: 14, color: _ClientColors.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── FILTER CHIPS ROW ────────────────────────────────────────────────────────
  Widget _buildFilterChipsRow(_CustomerStats stats, CustomerGender? genderFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip(
            label: 'All',
            count: stats.total,
            isActive: genderFilter == null,
            onTap: () => _onFilterChanged(null),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: '👔 Men',
            count: stats.men,
            isActive: genderFilter == CustomerGender.male,
            onTap: () => _onFilterChanged(CustomerGender.male),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: '👗 Women',
            count: stats.women,
            isActive: genderFilter == CustomerGender.female,
            onTap: () => _onFilterChanged(CustomerGender.female),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: '👕 Children',
            count: stats.child,
            isActive: genderFilter == CustomerGender.child,
            onTap: () => _onFilterChanged(CustomerGender.child),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? _ClientColors.dark : Colors.white,
            border: Border.all(
              color: isActive ? _ClientColors.dark : _ClientColors.line,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : _ClientColors.muted,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isActive ? const Color(0xFFAEB5C2) : _ClientColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── VIRTUALIZED CLIENT LIST (EXTREME CPU EFFICIENCY) ─────────────────────────
  Widget _buildClientList(AsyncValue<List<CustomerModel>> filteredAsync) {
    return filteredAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          cacheExtent: 300,
          itemCount: list.length,
          itemBuilder: (ctx, idx) {
            return RepaintBoundary(
              key: ValueKey(list[idx].id),
              child: _ClientCard(
                customer: list[idx],
                isMobile: false,
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: _ClientColors.gold),
      ),
      error: (err, _) => Center(
        child: Text(
          'Error loading clients: $err',
          style: GoogleFonts.dmSans(color: _ClientColors.rose),
        ),
      ),
    );
  }

  // ── MOBILE LAYOUT (< 850PX) ────────────────────────────────────────────────
  Widget _buildMobileLayout(
    _CustomerStats stats,
    AsyncValue<List<CustomerModel>> filteredAsync,
    CustomerGender? genderFilter,
    List<CustomerModel> allCustomers,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mobile Hero Card matching HTML mockup
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A2110), Color(0xFF1B2436)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18151922),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client Directory',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stats.total} customers · ${stats.active} active',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFAEB5C2),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3-stat Bar
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _buildMobileStatItem('${stats.total}', 'TOTAL')),
                            Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1)),
                            Expanded(child: _buildMobileStatItem('${stats.active}', 'ACTIVE')),
                            Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1)),
                            Expanded(child: _buildMobileStatItem('${stats.newThisWeek}', 'NEW')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Full-width Add Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => AddCustomerModal.show(context),
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_ClientColors.gold2, _ClientColors.gold],
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, size: 16, color: Color(0xFF211500)),
                                const SizedBox(width: 5),
                                Text(
                                  'Add New Client',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF211500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Mobile Search Bar
                _buildSearchBar(),
                const SizedBox(height: 10),

                // Mobile Filter Chips
                _buildFilterChipsRow(stats, genderFilter),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // Virtualized Sliver List for Mobile (Zero lag / 60 FPS)
          filteredAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return SliverToBoxAdapter(child: _buildEmptyState());
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) {
                    return RepaintBoundary(
                      key: ValueKey(list[idx].id),
                      child: _ClientCard(
                        customer: list[idx],
                        isMobile: true,
                      ),
                    );
                  },
                  childCount: list.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _ClientColors.gold),
                ),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error: $err',
                    style: GoogleFonts.dmSans(color: _ClientColors.rose),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatItem(String num, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: const Color(0xFFAEB5C2),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👥', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              'No clients found',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ClientColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search term or filter,\nor add your first client to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: _ClientColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => AddCustomerModal.show(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_ClientColors.gold2, _ClientColors.gold],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _ClientColors.gold.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: Color(0xFF211500)),
                      const SizedBox(width: 6),
                      Text(
                        'Add New Client',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF211500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CLIENT CARD (HIGH PERFORMANCE, STATING ZERO TICKS) ───────────────────────
class _ClientCard extends StatelessWidget {
  final CustomerModel customer;
  final bool isMobile;

  const _ClientCard({
    required this.customer,
    required this.isMobile,
  });

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    if (diff.inDays == 1) return 'YESTERDAY';
    if (diff.inDays < 7) return '${diff.inDays}D AGO';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}W AGO';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _launchWhatsApp(String phone) async {
    var p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) {
      p = '92${p.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMale = customer.gender == CustomerGender.male;
    final isFemale = customer.gender == CustomerGender.female;

    final avatarGradient = isMale
        ? const LinearGradient(colors: [Color(0xFFFFC85E), Color(0xFFD88A13)])
        : (isFemale
            ? const LinearGradient(colors: [Color(0xFFF5A4D6), Color(0xFFC54FA0)])
            : const LinearGradient(colors: [Color(0xFF8ED4FF), Color(0xFF4A90E2)]));

    final initial = customer.name.trim().isNotEmpty
        ? customer.name.trim()[0].toUpperCase()
        : 'C';

    final naapCount = customer.totalOrders == 0
        ? 1
        : (customer.totalOrders > 5 ? 3 : 2);

    final isNew = DateTime.now().difference(customer.createdAt).inDays <= 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _ClientColors.line),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05111827),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/customers/${customer.id}');
          },
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 18,
              vertical: isMobile ? 12 : 14,
            ),
            child: Row(
              children: [
                // Avatar with online status dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: isMobile ? 44 : 50,
                      height: isMobile ? 44 : 50,
                      decoration: BoxDecoration(
                        gradient: avatarGradient,
                        borderRadius: BorderRadius.circular(isMobile ? 13 : 15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD88A13).withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.manrope(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10CBA0),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: isMobile ? 10 : 14),

                // Name, Phone & Tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: isMobile ? 13.5 : 15,
                          fontWeight: FontWeight.w800,
                          color: _ClientColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customer.phone.isNotEmpty ? customer.phone : 'No phone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: _ClientColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Tags
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _buildTag(
                            label: _formatTimeAgo(customer.createdAt),
                            bg: _ClientColors.blueBg,
                            color: _ClientColors.blue,
                          ),
                          _buildTag(
                            label: '$naapCount NAAP',
                            bg: _ClientColors.greenBg,
                            color: _ClientColors.green,
                          ),
                          _buildTag(
                            label: isNew ? 'NEW' : 'ACTIVE',
                            bg: isNew ? _ClientColors.goldBg : _ClientColors.greenBg,
                            color: isNew ? const Color(0xFF8B6C22) : _ClientColors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Action Buttons (WhatsApp, Naap, New Order) + Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconAction(
                      icon: Icons.chat_rounded,
                      tooltip: 'WhatsApp',
                      bg: const Color(0x1A25D366),
                      border: const Color(0x3325D366),
                      color: _ClientColors.whatsapp,
                      isMobile: isMobile,
                      onTap: () => _launchWhatsApp(customer.phone),
                    ),
                    const SizedBox(width: 5),
                    Consumer(
                      builder: (context, ref, child) => _buildIconAction(
                        icon: Icons.straighten_rounded,
                        tooltip: 'Naap / Measurements',
                        bg: const Color(0x1A8764E8),
                        border: const Color(0x338764E8),
                        color: _ClientColors.violet,
                        isMobile: isMobile,
                        onTap: () => _showNaapPicker(context, ref, customer),
                      ),
                    ),
                    const SizedBox(width: 5),
                    _buildIconAction(
                      icon: Icons.add_rounded,
                      tooltip: 'New Order',
                      bg: _ClientColors.goldBg,
                      border: _ClientColors.goldLine,
                      color: _ClientColors.gold,
                      isMobile: isMobile,
                      onTap: () => NewOrderModal.show(context, preSelectedCustomer: customer),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _ClientColors.faint,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color bg,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required Color bg,
    required Color border,
    required Color color,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: isMobile ? 32 : 36,
            height: isMobile ? 32 : 36,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, size: isMobile ? 15 : 17, color: color),
            ),
          ),
        ),
      ),
    );
  }

  void _showNaapPicker(BuildContext context, WidgetRef ref, CustomerModel customer) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
    final customerMeasurements = allMeasurements
        .where((m) => m.customerId == customer.id)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? _ClientColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? _ClientColors.darkLine : _ClientColors.line,
              width: 1,
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_ClientColors.gold2, _ClientColors.gold],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('📐', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${customer.name} · ناپ لسٹ',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : _ClientColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select a profile to view, print & share',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: _ClientColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : _ClientColors.muted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (customerMeasurements.isEmpty) ...[
                // Empty state
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? _ClientColors.dark : _ClientColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? _ClientColors.darkLine : _ClientColors.line,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text('📏', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 10),
                      Text(
                        'No measurement profiles found',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : _ClientColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Is customer ka abhi tak koi naap record nahi hai.',
                        style: GoogleFonts.dmSans(fontSize: 11.5, color: _ClientColors.muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(selectedMeasurementCustomerIdProvider.notifier).state = customer.id;
                          ctx.push('/measurements/${customer.id}/${Uri.encodeComponent(customer.name)}');
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text('＋ Add Naap (نیا ناپ لیں)', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ClientColors.gold,
                          foregroundColor: const Color(0xFF211500),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // List of measurement profiles
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: customerMeasurements.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final m = customerMeasurements[i];
                      final catEmoji = m.category == MeasurementCategory.women
                          ? '👗'
                          : (m.category == MeasurementCategory.children ? '👕' : '👔');

                      // Key measurements summary from sections
                      final List<String> previewChips = [];
                      for (final sec in m.sections) {
                        for (final f in sec.fields) {
                          if (f.value.trim().isNotEmpty && previewChips.length < 3) {
                            previewChips.add('${f.label}: ${f.value}');
                          }
                        }
                      }

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push(
                              '/print?customerId=${customer.id}&measurementId=${m.id}',
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1D222D) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? _ClientColors.darkLine : _ClientColors.line,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0x268764E8) : const Color(0xFFF3F0FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(catEmoji, style: const TextStyle(fontSize: 16)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.profileName.isNotEmpty ? m.profileName : m.title,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : _ClientColors.ink,
                                        ),
                                      ),
                                      if (previewChips.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          previewChips.join(' · '),
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _ClientColors.muted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_ClientColors.gold2, _ClientColors.gold],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🖨️', style: TextStyle(fontSize: 11)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'View & Print',
                                        style: GoogleFonts.manrope(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF211500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Footer button to manage/add naap in studio
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(selectedMeasurementCustomerIdProvider.notifier).state = customer.id;
                    ctx.push('/measurements/${customer.id}/${Uri.encodeComponent(customer.name)}');
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: Text('Open Naap Studio (ناپ سٹوڈیو کھولیں)', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : _ClientColors.ink,
                    side: BorderSide(color: isDark ? _ClientColors.darkLine : _ClientColors.line),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
