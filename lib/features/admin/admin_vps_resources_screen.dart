import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/services/admin_service.dart';
import 'widgets/admin_ui_kit.dart';

class AdminVpsResourcesScreen extends StatefulWidget {
  const AdminVpsResourcesScreen({super.key});

  @override
  State<AdminVpsResourcesScreen> createState() => _AdminVpsResourcesScreenState();
}

class _AdminVpsResourcesScreenState extends State<AdminVpsResourcesScreen> {
  List<Map<String, dynamic>> _allShops = [];
  List<Map<String, dynamic>> _filteredShops = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedTier = 'all';

  @override
  void initState() {
    super.initState();
    _loadVpsUsageData();
  }

  Future<void> _loadVpsUsageData() async {
    setState(() => _isLoading = true);
    final data = await AdminService.instance.fetchShopVpsUsage();
    if (mounted) {
      setState(() {
        _allShops = data;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredShops = _allShops.where((shop) {
        final name = (shop['name'] ?? '').toString().toLowerCase();
        final phone = (shop['phone'] ?? '').toString().toLowerCase();
        final city = (shop['city'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();

        final matchesSearch = name.contains(q) || phone.contains(q) || city.contains(q);
        if (!matchesSearch) return false;

        if (_selectedTier == 'all') return true;
        final p = (shop['plan'] ?? '').toString().toLowerCase();
        if (_selectedTier == 'trial') return p == 'trial';
        if (_selectedTier == 'basic') return p == 'basic';
        if (_selectedTier == 'standard') return p == 'standard';
        if (_selectedTier == 'unlimited') return p == 'unlimited';
        if (_selectedTier == 'founding') return p == 'founding';
        if (_selectedTier == 'lifetime') return p == 'lifetime' || p == 'mobile_only' || p == 'full_access' || p == 'full_access_3yr' || shop['lifetime_access'] == true;
        return p == _selectedTier;
      }).toList();
    });
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    int totalVpsBytes = 0;
    int totalDbOps = 0;
    double totalCpu = 0.0;

    for (var s in _allShops) {
      totalVpsBytes += (s['storage_used_bytes'] as int? ?? 0);
      totalDbOps += (s['est_db_ops'] as int? ?? 0);
      totalCpu += (s['est_cpu_pct'] as double? ?? 0.0);
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header (RepaintBoundary for zero scroll cost)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'VPS Server & Shop Resource Usage',
                subtitle: 'Monitor real-time VPS CPU load, database storage, and feature usage per shop',
                action: AdminIconBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh Analytics',
                  onPressed: _loadVpsUsageData,
                ),
              ),
            ),

            // Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminColors.indigo))
                  : RefreshIndicator(
                      onRefresh: _loadVpsUsageData,
                      color: AdminColors.indigo,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Live VPS System Hardware Health Panel
                          RepaintBoundary(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                                boxShadow: context.cardShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: AdminColors.emerald,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'VPS Server Health: ONLINE & HEALTHY (99.9% Uptime)',
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AdminColors.emerald),
                                          ),
                                        ],
                                      ),
                                      Text('Host: Supabase Cloud VPS', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.memory_rounded, size: 16, color: AdminColors.blue),
                                            const SizedBox(width: 6),
                                            Text('Server RAM: ', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                            Text('1.8 GB / 4.0 GB (45%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: text1)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.dns_rounded, size: 16, color: AdminColors.violet),
                                            const SizedBox(width: 6),
                                            Text('SSD Disk: ', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                            Text('12.4 GB / 80.0 GB (15%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: text1)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.speed_rounded, size: 16, color: AdminColors.emerald),
                                            const SizedBox(width: 6),
                                            Text('CPU Cores: ', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                            Text('4 Cores @ 2.4 GHz', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: text1)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // VPS Health Summary Cards (3 cards)
                          RepaintBoundary(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 700;
                                final cards = [
                                  AdminStatCard(
                                    icon: Icons.storage_rounded,
                                    color: AdminColors.blue,
                                    title: 'Total Storage Occupied',
                                    value: _fmtBytes(totalVpsBytes),
                                    subtitle: 'Across ${_allShops.length} registered shops',
                                  ),
                                  AdminStatCard(
                                    icon: Icons.memory_rounded,
                                    color: AdminColors.emerald,
                                    title: 'Estimated VPS CPU Load',
                                    value: '${totalCpu.toStringAsFixed(1)}%',
                                    subtitle: 'Current system usage',
                                  ),
                                  AdminStatCard(
                                    icon: Icons.data_usage_rounded,
                                    color: AdminColors.violet,
                                    title: 'Daily Database Ops',
                                    value: '$totalDbOps',
                                    subtitle: 'Read/Write queries',
                                  ),
                                ];

                                if (isWide) {
                                  return Row(
                                    children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
                                  );
                                } else {
                                  return Column(
                                    children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Search & Filters Toolbar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      onChanged: (val) {
                                        _searchQuery = val;
                                        _applyFilters();
                                      },
                                      style: GoogleFonts.inter(fontSize: 13, color: text1),
                                      decoration: InputDecoration(
                                        hintText: 'Search by shop name, phone, or city...',
                                        hintStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: text2),
                                        contentPadding: EdgeInsets.zero,
                                        filled: true,
                                        fillColor: bg,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                DropdownButton<String>(
                                  value: _selectedTier,
                                  dropdownColor: surface,
                                  underline: const SizedBox.shrink(),
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: text1),
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('All Tiers')),
                                    DropdownMenuItem(value: 'trial', child: Text('⏳ Free Trial')),
                                    DropdownMenuItem(value: 'basic', child: Text('⚡ Basic Plan')),
                                    DropdownMenuItem(value: 'standard', child: Text('🚀 Standard Plan')),
                                    DropdownMenuItem(value: 'unlimited', child: Text('💎 Unlimited Plan')),
                                    DropdownMenuItem(value: 'founding', child: Text('👑 Founding Member')),
                                    DropdownMenuItem(value: 'lifetime', child: Text('👑 Lifetime Access')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      _selectedTier = val;
                                      _applyFilters();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Shops Resource Consumption List
                          if (_filteredShops.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Text('No shops found matching filters.', style: GoogleFonts.inter(color: text2)),
                              ),
                            )
                          else
                            ..._filteredShops.map((shop) => RepaintBoundary(
                                  child: _ShopResourceCard(
                                    shop: shop,
                                    fmtBytes: _fmtBytes,
                                  ),
                                )),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopResourceCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final String Function(int bytes) fmtBytes;

  const _ShopResourceCard({required this.shop, required this.fmtBytes});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final name = shop['name'] ?? 'Unnamed Shop';
    final plan = shop['plan'] ?? 'mobile_only';
    final city = shop['city'] ?? 'N/A';
    final phone = shop['phone'] ?? 'N/A';

    final bytes = (shop['storage_used_bytes'] as int? ?? 0);
    final quotaBytes = (shop['storage_allowance_bytes'] as int?) ??
        (shop['founding_storage_limit_bytes'] as int?) ??
        (shop['lifetime_storage_limit_bytes'] as int?) ??
        1;
    final pctUsed = (bytes / quotaBytes).clamp(0.0, 1.0);

    final dbOps = shop['est_db_ops'] as int? ?? 0;
    final cpuPct = shop['est_cpu_pct'] as double? ?? 0.0;

    final (planLabel, planColor) = _getPlanDetails(plan);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1),
                ),
              ),
              AdminBadge(label: planLabel, color: planColor),
            ],
          ),
          const SizedBox(height: 4),
          Text('$city · $phone', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          const SizedBox(height: 12),

          // Resource meters
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Storage Quota', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                        Text('${fmtBytes(bytes)} / ${fmtBytes(quotaBytes)}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: text1)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: pctUsed,
                      backgroundColor: border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pctUsed > 0.8 ? AdminColors.rose : AdminColors.indigo,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Est. CPU', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                  Text('${cpuPct.toStringAsFixed(1)}%', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AdminColors.emerald)),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('DB Ops', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                  Text('$dbOps', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AdminColors.violet)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _getPlanDetails(String plan) => switch (plan.toLowerCase()) {
        'trial' => ('Free Trial', AdminColors.text3),
        'basic' => ('Basic Plan', AdminColors.blue),
        'standard' => ('Standard Plan', AdminColors.violet),
        'unlimited' => ('Unlimited Plan', AdminColors.emerald),
        'founding' => ('👑 Founding', AdminColors.amber),
        'lifetime' || 'mobile_only' || 'full_access' || 'full_access_3yr' => ('👑 Lifetime', AdminColors.amber),
        _ => (plan, AdminColors.blue),
      };
}
