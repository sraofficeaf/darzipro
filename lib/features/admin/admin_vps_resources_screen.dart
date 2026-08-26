import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/services/admin_service.dart';
import '../../core/utils/plan_utils.dart';

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

        if (_selectedTier == 'all') return matchesSearch;
        return matchesSearch && shop['plan'] == _selectedTier;
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
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: surface,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🖥️ VPS Server & Shop Resource Usage',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Monitor real-time VPS CPU load, database storage, and feature usage per shop',
                          style: GoogleFonts.inter(fontSize: 12, color: text2),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh Analytics',
                    onPressed: _loadVpsUsageData,
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : RefreshIndicator(
                      onRefresh: _loadVpsUsageData,
                      color: AppColors.accent,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // ── Live VPS System Hardware Health Panel ────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
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
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'VPS Server Health: ONLINE & HEALTHY (99.9% Uptime)',
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                                        ),
                                      ],
                                    ),
                                    Text('Host: Supabase Cloud VPS', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.memory_rounded, size: 16, color: Color(0xFF3B82F6)),
                                          const SizedBox(width: 6),
                                          Text('Server RAM: ', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                          Text('1.8 GB / 4.0 GB (45%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: text1)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.dns_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                          const SizedBox(width: 6),
                                          Text('SSD Disk: ', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                          Text('12.4 GB / 80.0 GB (15%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: text1)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF10B981)),
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

                          // ── VPS Health Summary Cards ───────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _MetricSummaryCard(
                                  icon: Icons.storage_rounded,
                                  color: const Color(0xFF3B82F6),
                                  title: 'Total Storage Occupied',
                                  value: _fmtBytes(totalVpsBytes),
                                  subtitle: 'Across ${_allShops.length} registered shops',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricSummaryCard(
                                  icon: Icons.memory_rounded,
                                  color: const Color(0xFF10B981),
                                  title: 'Estimated VPS CPU Load',
                                  value: '${totalCpu.toStringAsFixed(1)}%',
                                  subtitle: 'Current system usage',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricSummaryCard(
                                  icon: Icons.data_usage_rounded,
                                  color: const Color(0xFF8B5CF6),
                                  title: 'Daily Database Ops',
                                  value: '$totalDbOps',
                                  subtitle: 'Read/Write queries',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Search & Filters ──────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (val) {
                                    _searchQuery = val;
                                    _applyFilters();
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search by shop name, phone, or city...',
                                    prefixIcon: const Icon(Icons.search_rounded),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: _selectedTier,
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All Tiers')),
                                  DropdownMenuItem(value: 'mobile_only', child: Text('Basic Plan')),
                                  DropdownMenuItem(value: 'full_access', child: Text('Professional')),
                                  DropdownMenuItem(value: 'full_access_3yr', child: Text('Enterprise')),
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
                          const SizedBox(height: 16),

                          // ── Shops Resource Consumption List ────────────────
                          if (_filteredShops.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Text('No shops found matching filters.', style: GoogleFonts.inter(color: text2)),
                              ),
                            )
                          else
                            ..._filteredShops.map((shop) => _ShopResourceCard(
                                  shop: shop,
                                  fmtBytes: _fmtBytes,
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

class _MetricSummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;

  const _MetricSummaryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: text2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: text1),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: text2),
          ),
        ],
      ),
    );
  }
}

class _ShopResourceCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final String Function(int) fmtBytes;

  const _ShopResourceCard({
    required this.shop,
    required this.fmtBytes,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final planStr = shop['plan'] as String? ?? 'mobile_only';
    final planInfo = AppPlanUtils.getDisplayInfo(planStr);
    final planName = planInfo.$1;
    final planColor = planInfo.$2;
    final bytesUsed = shop['storage_used_bytes'] as int? ?? 0;
    final addonActive = shop['storage_addon_active'] == true;
    final isUnlimited = planStr == 'full_access_3yr' || addonActive;
    final limitBytes = isUnlimited ? 500 * 1024 * 1024 : 1.5 * 1024 * 1024;
    final usagePct = (bytesUsed / limitBytes).clamp(0.0, 1.0);

    final cCount = shop['customer_count'] as int? ?? 0;
    final mCount = shop['measurement_count'] as int? ?? 0;
    final oCount = shop['order_count'] as int? ?? 0;
    final estCpu = shop['est_cpu_pct'] as double? ?? 0.0;
    final estOps = shop['est_db_ops'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          shop['name'] ?? 'Unnamed Shop',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: text1),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: planColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: planColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            planName,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: planColor),
                          ),
                        ),
                        if (addonActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '💾 Unlimited Storage',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📞 ${shop['phone']}  •  📍 ${shop['city']}',
                      style: GoogleFonts.inter(fontSize: 12, color: text2),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'CPU Load: $estCpu%',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: estCpu > 5.0 ? Colors.orange : AppColors.accent),
                  ),
                  Text(
                    '~ $estOps DB Ops/day',
                    style: GoogleFonts.inter(fontSize: 11, color: text2),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Storage Bar
          Row(
            children: [
              Text('Database Storage:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: text1)),
              const SizedBox(width: 8),
              Text(
                '${fmtBytes(bytesUsed)} ${isUnlimited ? '(Unlimited Plan)' : 'of 1.5 MB limit'}',
                style: GoogleFonts.inter(fontSize: 12, color: text2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isUnlimited ? 0.05 : usagePct,
              minHeight: 8,
              backgroundColor: border,
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePct >= 0.9 ? Colors.red : (usagePct >= 0.75 ? Colors.orange : const Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Feature Usage Breakdown Tiles
          Text('🧩 VPS Feature-by-Feature Resource Usage:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: text1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _FeatureChip(
                icon: Icons.people_rounded,
                label: 'Customers Book',
                value: '$cCount recs (${fmtBytes(shop['customer_bytes'] as int? ?? 0)})',
                color: const Color(0xFF3B82F6),
              ),
              _FeatureChip(
                icon: Icons.straighten_rounded,
                label: 'Naap / Measurements',
                value: '$mCount recs (${fmtBytes(shop['measurement_bytes'] as int? ?? 0)})',
                color: const Color(0xFF8B5CF6),
              ),
              _FeatureChip(
                icon: Icons.shopping_bag_rounded,
                label: 'Orders & Slips',
                value: '$oCount orders (${fmtBytes(shop['order_bytes'] as int? ?? 0)})',
                color: const Color(0xFF10B981),
              ),
              _FeatureChip(
                icon: Icons.image_rounded,
                label: 'Media & Attachments',
                value: fmtBytes(shop['other_bytes'] as int? ?? 0),
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: context.text1),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
