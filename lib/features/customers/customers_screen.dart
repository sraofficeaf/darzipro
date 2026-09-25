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
import '../../core/theme/theme_extensions.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import 'add_customer_modal.dart';
import 'edit_customer_modal.dart';

// ── COLOR SYSTEM & DESIGN TOKENS (EXACT MATCH WITH USER MOCKUP) ──────────────
class _Colors {
  _Colors._();

  static const Color darkBanner = Color(0xFF111726);
  static const Color gold = Color(0xFFE9A227);
  static const Color goldLight = Color(0xFFFFC65A);

  static const Color cardBg = Colors.white;
  static const Color cardBgDark = Color(0xFF111726);
  static const Color borderLight = Color(0xFFE8ECF2);
  static const Color borderDark = Color(0xFF1F293D);

  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color faint = Color(0xFF94A3B8);

  // Soft KPI accents
  static const Color blueBg = Color(0xFFEFF6FF);
  static const Color blue = Color(0xFF2563EB);

  static const Color cyanBg = Color(0xFFECFEFF);
  static const Color cyan = Color(0xFF0891B2);

  static const Color pinkBg = Color(0xFFFDF2F8);
  static const Color pink = Color(0xFFDB2777);

  static const Color greenBg = Color(0xFFF0FDF4);
  static const Color green = Color(0xFF16A34A);

  // Initials Avatar deterministic color palette
  static const List<Color> avatarColors = [
    Color(0xFFE9A227), // Gold/Amber (e.g. AK)
    Color(0xFF8B5CF6), // Purple (e.g. SB)
    Color(0xFF0D9488), // Teal (e.g. MR)
    Color(0xFFEC4899), // Pink (e.g. ZF)
    Color(0xFF6366F1), // Indigo (e.g. AS)
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
  ];
}

// ── FAST IN-MEMORY STATS COMPUTATION (Zero runtime allocations during frame) ──
class _CustomerStats {
  final int total;
  final int active;
  final int men;
  final int women;
  final int child;
  final int newThisMonth;

  const _CustomerStats({
    required this.total,
    required this.active,
    required this.men,
    required this.women,
    required this.child,
    required this.newThisMonth,
  });

  factory _CustomerStats.fromList(List<CustomerModel> list) {
    int total = list.length;
    int active = 0;
    int men = 0;
    int women = 0;
    int child = 0;
    int newThisMonth = 0;
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
      if (now.difference(c.createdAt).inDays <= 30) newThisMonth++;
    }

    return _CustomerStats(
      total: total,
      active: active,
      men: men,
      women: women,
      child: child,
      newThisMonth: newThisMonth,
    );
  }
}

enum _ClientSortBy {
  newest,
  oldest,
  nameAsc,
  mostOrders,
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

  // View state
  bool _isGridView = false;
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'
  CustomerGender? _selectedGender;
  _ClientSortBy _sortBy = _ClientSortBy.newest;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = ref.read(customerSearchProvider);
    _searchController.text = _searchQuery;
    _selectedGender = ref.read(customerGenderFilterProvider);
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
        setState(() => _searchQuery = val);
        ref.read(customerSearchProvider.notifier).state = val;
      }
    });
  }

  void _clearFilters() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = 'all';
      _selectedGender = null;
      _sortBy = _ClientSortBy.newest;
    });
    ref.read(customerSearchProvider.notifier).state = '';
    ref.read(customerGenderFilterProvider.notifier).state = null;
  }

  List<CustomerModel> _filterAndSort(List<CustomerModel> list) {
    var result = List<CustomerModel>.from(list);

    // Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q);
      }).toList();
    }

    // Gender filter
    if (_selectedGender != null) {
      result = result.where((c) => c.gender == _selectedGender).toList();
    }

    // Status filter
    if (_statusFilter == 'active') {
      result = result.where((c) => c.totalOrders > 0).toList();
    } else if (_statusFilter == 'inactive') {
      result = result.where((c) => c.totalOrders == 0).toList();
    }

    // Sorting
    switch (_sortBy) {
      case _ClientSortBy.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _ClientSortBy.oldest:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _ClientSortBy.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _ClientSortBy.mostOrders:
        result.sort((a, b) => b.totalOrders.compareTo(a.totalOrders));
        break;
    }

    return result;
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return _Colors.avatarColors[0];
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return _Colors.avatarColors[hash % _Colors.avatarColors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'C';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
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
    final isDark = context.isDark;
    final allCustomers = allCustomersAsync.valueOrNull ?? const [];
    final stats = _CustomerStats.fromList(allCustomers);
    final filteredClients = _filterAndSort(allCustomers);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF4F6F9);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Hero Banner with Mannequin Tailor Motif
            RepaintBoundary(
              child: _buildHeroBanner(isDesktop, isDark, allCustomers),
            ),

            // 4 KPI Cards (Total Clients, Men, Women, Children)
            RepaintBoundary(
              child: _buildKpiRow(stats, isDesktop, isDark),
            ),

            const SizedBox(height: 12),

            // Main Body: Desktop 2-Column (Filters + Directory) vs Mobile Stacked
            Expanded(
              child: isDesktop
                  ? _buildDesktopMainLayout(filteredClients, isDark)
                  : _buildMobileMainLayout(filteredClients, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. HERO BANNER (MATCHING USER SCREENSHOT EXACTLY) ───────────────────────
  Widget _buildHeroBanner(bool isDesktop, bool isDark, List<CustomerModel> allCustomers) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 20 : 12,
        isDesktop ? 16 : 8,
        isDesktop ? 20 : 12,
        12,
      ),
      height: isDesktop ? 96 : 82,
      decoration: BoxDecoration(
        color: _Colors.darkBanner,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background subtle tailor mannequin/gold curve gradient
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: isDesktop ? 360 : 180,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0x1AE9A227),
                      Color(0x38E9A227),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ),

          // Content Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12),
            child: Row(
              children: [
                // Gold Icon Badge
                Container(
                  width: isDesktop ? 46 : 38,
                  height: isDesktop ? 46 : 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_Colors.goldLight, _Colors.gold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33E9A227),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.people_alt_rounded,
                      size: isDesktop ? 24 : 20,
                      color: const Color(0xFF1E1402),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Clients',
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 22 : 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDesktop
                            ? 'Manage your shop customers, track orders and keep your business organized.'
                            : 'Manage your shop customers and orders.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isDesktop ? 12 : 11,
                          color: const Color(0xFFA0ABBA),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Export CSV Icon Button
                IconButton(
                  tooltip: 'Export CSV',
                  icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 20),
                  onPressed: () => _exportClientsCSV(allCustomers),
                ),

                const SizedBox(width: 6),

                // + Add New Client Button (Solid Gold)
                InkWell(
                  onTap: () => AddCustomerModal.show(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: isDesktop ? 40 : 36,
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_Colors.goldLight, _Colors.gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33E9A227),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Color(0xFF1B1300),
                        ),
                        if (isDesktop) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Add New Client',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B1300),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. 4 STAT KPI CARDS (MATCHING USER SCREENSHOT) ──────────────────────────
  Widget _buildKpiRow(_CustomerStats stats, bool isDesktop, bool isDark) {
    final menPercent = stats.total > 0 ? ((stats.men / stats.total) * 100).round() : 0;
    final womenPercent = stats.total > 0 ? ((stats.women / stats.total) * 100).round() : 0;
    final childPercent = stats.total > 0 ? ((stats.child / stats.total) * 100).round() : 0;

    final cards = [
      _buildKpiCard(
        title: 'Total Clients',
        count: '${stats.total}',
        badgeText: '↑ ${stats.newThisMonth} new this month',
        badgeColor: _Colors.green,
        badgeBg: _Colors.greenBg,
        icon: Icons.people_alt_outlined,
        iconColor: _Colors.blue,
        iconBg: _Colors.blueBg,
        chevronColor: _Colors.blue,
        isDark: isDark,
        onTap: () {
          setState(() {
            _selectedGender = null;
            _statusFilter = 'all';
          });
        },
      ),
      _buildKpiCard(
        title: 'Men',
        count: '${stats.men}',
        badgeText: '$menPercent% of total',
        badgeColor: _Colors.muted,
        badgeBg: Colors.transparent,
        icon: Icons.man_rounded,
        iconColor: _Colors.cyan,
        iconBg: _Colors.cyanBg,
        chevronColor: _Colors.cyan,
        isDark: isDark,
        onTap: () {
          setState(() {
            _selectedGender = _selectedGender == CustomerGender.male ? null : CustomerGender.male;
          });
        },
      ),
      _buildKpiCard(
        title: 'Women',
        count: '${stats.women}',
        badgeText: '$womenPercent% of total',
        badgeColor: _Colors.muted,
        badgeBg: Colors.transparent,
        icon: Icons.woman_rounded,
        iconColor: _Colors.pink,
        iconBg: _Colors.pinkBg,
        chevronColor: _Colors.pink,
        isDark: isDark,
        onTap: () {
          setState(() {
            _selectedGender = _selectedGender == CustomerGender.female ? null : CustomerGender.female;
          });
        },
      ),
      _buildKpiCard(
        title: 'Children',
        count: '${stats.child}',
        badgeText: '$childPercent% of total',
        badgeColor: _Colors.muted,
        badgeBg: Colors.transparent,
        icon: Icons.child_care_rounded,
        iconColor: _Colors.green,
        iconBg: _Colors.greenBg,
        chevronColor: _Colors.green,
        isDark: isDark,
        onTap: () {
          setState(() {
            _selectedGender = _selectedGender == CustomerGender.child ? null : CustomerGender.child;
          });
        },
      ),
    ];

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: cards
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: c,
                    ),
                  ))
              .toList(),
        ),
      );
    }

    // Mobile: Horizontal scrolling strip
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(width: 175, child: cards[i]),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String count,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color chevronColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cardBg = isDark ? _Colors.cardBgDark : _Colors.cardBg;
    final borderColor = isDark ? _Colors.borderDark : _Colors.borderLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.transparent : const Color(0x06000000),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Soft Circle Icon + Title + Chevron Right
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(icon, size: 17, color: iconColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : _Colors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: chevronColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Bottom Row: Large Number + Subtitle / Trend
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    count,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _Colors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: badgeBg != Colors.transparent
                          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                          : EdgeInsets.zero,
                      decoration: badgeBg != Colors.transparent
                          ? BoxDecoration(
                              color: isDark ? badgeColor.withValues(alpha: 0.15) : badgeBg,
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      child: Text(
                        badgeText,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. DESKTOP MAIN LAYOUT: FILTERS PANEL (LEFT) + DIRECTORY (RIGHT) ───────
  Widget _buildDesktopMainLayout(List<CustomerModel> clients, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Filters Card (Width: 260px)
          SizedBox(
            width: 260,
            child: RepaintBoundary(
              child: _buildFilterCard(isDark),
            ),
          ),
          const SizedBox(width: 14),

          // Right: Clients Directory Card
          Expanded(
            child: _buildClientsDirectoryCard(clients, isDark),
          ),
        ],
      ),
    );
  }

  // ── 4. MOBILE MAIN LAYOUT: STACKED WITH COLLAPSIBLE FILTER ──────────────────
  Widget _buildMobileMainLayout(List<CustomerModel> clients, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Quick Search & Filter bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? _Colors.cardBgDark : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? _Colors.borderDark : _Colors.borderLight),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : _Colors.ink),
                    decoration: InputDecoration(
                      hintText: 'Search clients, phone...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: _Colors.faint),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _Colors.faint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? _Colors.cardBgDark : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isDark ? _Colors.borderDark : _Colors.borderLight),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded, size: 18),
                onPressed: () => _showMobileFilterModal(context, isDark),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Client Directory
          Expanded(
            child: _buildClientsDirectoryCard(clients, isDark),
          ),
        ],
      ),
    );
  }

  // ── 5. LEFT FILTERS CARD (EXACT MOCKUP DESIGN) ──────────────────────────────
  Widget _buildFilterCard(bool isDark) {
    final cardBg = isDark ? _Colors.cardBgDark : _Colors.cardBg;
    final borderColor = isDark ? _Colors.borderDark : _Colors.borderLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : const Color(0x05000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title Row: Funnel Icon + Filters + Clear All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: _Colors.gold),
                  const SizedBox(width: 6),
                  Text(
                    'Filters',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : _Colors.ink,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _clearFilters,
                child: Text(
                  'Clear All',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _Colors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white : _Colors.ink,
              ),
              decoration: const InputDecoration(
                hintText: 'Search by name, phone or address...',
                hintStyle: TextStyle(fontSize: 11, color: _Colors.faint),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: _Colors.faint),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 1: Status
          Text(
            'Status',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : _Colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFilterChip(
                label: 'All',
                isSelected: _statusFilter == 'all',
                isDark: isDark,
                onTap: () => setState(() => _statusFilter = 'all'),
              ),
              _buildFilterChip(
                label: 'Active',
                isSelected: _statusFilter == 'active',
                dotColor: _Colors.green,
                isDark: isDark,
                onTap: () => setState(() => _statusFilter = 'active'),
              ),
              _buildFilterChip(
                label: 'Inactive',
                isSelected: _statusFilter == 'inactive',
                dotColor: _Colors.faint,
                isDark: isDark,
                onTap: () => setState(() => _statusFilter = 'inactive'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Gender
          Text(
            'Gender',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : _Colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFilterChip(
                label: 'All',
                isSelected: _selectedGender == null,
                isDark: isDark,
                onTap: () => setState(() => _selectedGender = null),
              ),
              _buildFilterChip(
                label: 'Men',
                isSelected: _selectedGender == CustomerGender.male,
                dotColor: _Colors.blue,
                isDark: isDark,
                onTap: () => setState(() => _selectedGender = CustomerGender.male),
              ),
              _buildFilterChip(
                label: 'Women',
                isSelected: _selectedGender == CustomerGender.female,
                dotColor: _Colors.pink,
                isDark: isDark,
                onTap: () => setState(() => _selectedGender = CustomerGender.female),
              ),
              _buildFilterChip(
                label: 'Children',
                isSelected: _selectedGender == CustomerGender.child,
                dotColor: _Colors.green,
                isDark: isDark,
                onTap: () => setState(() => _selectedGender = CustomerGender.child),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 3: Sort By
          Text(
            'Sort By',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : _Colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_ClientSortBy>(
                value: _sortBy,
                isExpanded: true,
                dropdownColor: isDark ? _Colors.darkBanner : Colors.white,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _Colors.muted),
                style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : _Colors.ink),
                items: const [
                  DropdownMenuItem(value: _ClientSortBy.newest, child: Text('Newest First')),
                  DropdownMenuItem(value: _ClientSortBy.oldest, child: Text('Oldest First')),
                  DropdownMenuItem(value: _ClientSortBy.nameAsc, child: Text('Name (A-Z)')),
                  DropdownMenuItem(value: _ClientSortBy.mostOrders, child: Text('Most Orders')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? dotColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? _Colors.gold
              : (isDark ? const Color(0x0FFFFFFF) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? _Colors.gold
                : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1B1300) : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1B1300)
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. RIGHT CLIENT DIRECTORY CARD (TABLE / LIST & GRID TOGGLE) ─────────────
  Widget _buildClientsDirectoryCard(List<CustomerModel> clients, bool isDark) {
    final cardBg = isDark ? _Colors.cardBgDark : _Colors.cardBg;
    final borderColor = isDark ? _Colors.borderDark : _Colors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : const Color(0x05000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: "All Clients (X)" + Grid/List View Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Clients (${clients.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _Colors.ink,
                  ),
                ),

                // View Toggle (⊞ Grid / ≡ List)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      // Grid icon
                      _buildViewToggleButton(
                        icon: Icons.grid_view_rounded,
                        isActive: _isGridView,
                        isDark: isDark,
                        onTap: () => setState(() => _isGridView = true),
                      ),
                      // List icon
                      _buildViewToggleButton(
                        icon: Icons.view_headline_rounded,
                        isActive: !_isGridView,
                        isDark: isDark,
                        onTap: () => setState(() => _isGridView = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Clients Content Area
          Expanded(
            child: clients.isEmpty
                ? _buildEmptyState(isDark)
                : _isGridView
                    ? _buildGridView(clients, isDark)
                    : _buildListView(clients, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 15,
          color: isActive ? Colors.white : _Colors.faint,
        ),
      ),
    );
  }

  // ── 7. LIST VIEW (ITEM EXTENT = 68PX FOR MAXIMUM CPU EFFICIENCY) ───────────
  Widget _buildListView(List<CustomerModel> clients, bool isDark) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemExtent: 68.0, // Fixed height avoids expensive layout recalculations!
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        return _buildClientListRow(client, isDark, index == clients.length - 1);
      },
    );
  }

  Widget _buildClientListRow(CustomerModel client, bool isDark, bool isLast) {
    final avatarColor = _getAvatarColor(client.name);
    final initials = _getInitials(client.name);
    final borderColor = isDark ? _Colors.borderDark : _Colors.borderLight;
    final isActive = client.totalOrders > 0;

    return Container(
      height: 68.0,
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Colored Initials Avatar
          CircleAvatar(
            radius: 19,
            backgroundColor: avatarColor,
            child: Text(
              initials,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name, Phone & City
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  client.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _Colors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 12, color: _Colors.faint),
                    const SizedBox(width: 4),
                    Text(
                      client.phone.isNotEmpty ? client.phone : 'No phone',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: _Colors.muted,
                      ),
                    ),
                    if (client.address.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.location_on_outlined, size: 12, color: _Colors.faint),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          client.address,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _Colors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Gender Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: client.gender == CustomerGender.male
                  ? (isDark ? const Color(0x202563EB) : _Colors.blueBg)
                  : (client.gender == CustomerGender.female
                      ? (isDark ? const Color(0x20DB2777) : _Colors.pinkBg)
                      : (isDark ? const Color(0x2016A34A) : _Colors.greenBg)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: client.gender == CustomerGender.male
                        ? _Colors.blue
                        : (client.gender == CustomerGender.female ? _Colors.pink : _Colors.green),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  client.gender == CustomerGender.male
                      ? 'Men'
                      : (client.gender == CustomerGender.female ? 'Women' : 'Children'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: client.gender == CustomerGender.male
                        ? _Colors.blue
                        : (client.gender == CustomerGender.female ? _Colors.pink : _Colors.green),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? const Color(0x2016A34A) : _Colors.greenBg)
                  : (isDark ? const Color(0x10FFFFFF) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isActive ? _Colors.green : _Colors.faint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? _Colors.green : _Colors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // "View Details" Action Button
          OutlinedButton.icon(
            onPressed: () => context.push('/customers/${client.id}'),
            icon: const Icon(Icons.visibility_outlined, size: 14),
            label: const Text('View Details'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
              foregroundColor: isDark ? Colors.white70 : _Colors.ink,
              side: BorderSide(color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          const SizedBox(width: 4),

          // More Options Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, size: 18, color: _Colors.muted),
            tooltip: 'Actions',
            color: isDark ? _Colors.darkBanner : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (action) {
              if (action == 'view') {
                context.push('/customers/${client.id}');
              } else if (action == 'edit') {
                EditCustomerModal.show(context, customer: client);
              } else if (action == 'call') {
                launchUrl(Uri.parse('tel:${client.phone}'));
              } else if (action == 'whatsapp') {
                final cleanPhone = client.phone.replaceAll(RegExp(r'[^0-9]'), '');
                launchUrl(Uri.parse('https://wa.me/$cleanPhone'), mode: LaunchMode.externalApplication);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'view', child: Text('View Profile')),
              const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
              const PopupMenuItem(value: 'call', child: Text('Call Client')),
              const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
            ],
          ),

          // Chevron Right
          InkWell(
            onTap: () => context.push('/customers/${client.id}'),
            child: const Icon(Icons.chevron_right_rounded, size: 18, color: _Colors.faint),
          ),
        ],
      ),
    );
  }

  // ── 8. GRID VIEW MODE ───────────────────────────────────────────────────────
  Widget _buildGridView(List<CustomerModel> clients, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final avatarColor = _getAvatarColor(client.name);
        final initials = _getInitials(client.name);
        final borderColor = isDark ? _Colors.borderDark : _Colors.borderLight;
        final isActive = client.totalOrders > 0;

        return InkWell(
          onTap: () => context.push('/customers/${client.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: avatarColor,
                      child: Text(
                        initials,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        client.name,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : _Colors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive ? _Colors.green : _Colors.faint,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  client.phone.isNotEmpty ? client.phone : 'No phone',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _Colors.muted),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${client.totalOrders} Orders',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _Colors.gold,
                      ),
                    ),
                    Text(
                      'View Details →',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 9. EMPTY STATE ─────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded, size: 42, color: _Colors.faint),
            const SizedBox(height: 10),
            Text(
              'No clients found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : _Colors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or filters.',
              style: GoogleFonts.inter(fontSize: 12, color: _Colors.muted),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _Colors.gold,
                foregroundColor: const Color(0xFF1B1300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 10. MOBILE FILTER BOTTOM SHEET ─────────────────────────────────────────
  void _showMobileFilterModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? _Colors.darkBanner : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFilterCard(isDark),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Colors.gold,
                      foregroundColor: const Color(0xFF1B1300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
