import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import 'widgets/admin_ui_kit.dart';

class AdminRevenueScreen extends ConsumerStatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  ConsumerState<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends ConsumerState<AdminRevenueScreen> {
  final _searchCtrl = TextEditingController();
  String _typeFilter = 'all'; // 'all' | 'registration' | 'upgrade' | 'storage'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(adminReportsDataProvider);
    final reportsData = reportsAsync.valueOrNull ?? {};
    final rawTxs = List<Map<String, dynamic>>.from(reportsData['transactions'] ?? []);

    final List<Map<String, dynamic>> combinedPayments = rawTxs.where((t) => t['direction'] == 'In').map((t) {
      return {
        'type': t['type'] ?? 'Registration',
        'sub_type': t['type'] ?? 'Standard',
        'shop_name': t['shop_name'] ?? 'Shop',
        'amount': (t['amount'] as num?)?.toInt() ?? 0,
        'payment_method': t['payment_method'] ?? 'Online',
        'transaction_id': t['transaction_id'] ?? 'N/A',
        'status': (t['status'] ?? 'approved').toString(),
        'date': t['date'] ?? '',
      };
    }).toList();

    // Calculate totals
    int totalRev = 0;
    int regRev = 0;
    int upgRev = 0;
    int storageRev = 0;

    int easypaisaTotal = 0;
    int jazzcashTotal = 0;
    int bankTotal = 0;

    for (final p in combinedPayments) {
      final amt = p['amount'] as int? ?? 0;
      totalRev += amt;
      final type = p['type'] as String;
      if (type == 'Registration') {
        regRev += amt;
      } else if (type == 'Upgrade') {
        upgRev += amt;
      } else if (type == 'Storage Add-on') {
        storageRev += amt;
      }

      final method = (p['payment_method'] as String? ?? '').toLowerCase();
      if (method.contains('easy')) {
        easypaisaTotal += amt;
      } else if (method.contains('jazz')) {
        jazzcashTotal += amt;
      } else {
        bankTotal += amt;
      }
    }

    // Filter by query and type
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = combinedPayments.where((p) {
      if (_typeFilter != 'all') {
        if (_typeFilter == 'registration' && p['type'] != 'Registration') return false;
        if (_typeFilter == 'upgrade' && p['type'] != 'Upgrade') return false;
        if (_typeFilter == 'storage' && p['type'] != 'Storage Add-on') return false;
      }
      if (query.isEmpty) return true;
      final shop = (p['shop_name'] ?? '').toString().toLowerCase();
      final tx = (p['transaction_id'] ?? '').toString().toLowerCase();
      return shop.contains(query) || tx.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ─────────────────────────────────────────────
            AdminPageHeader(
              title: 'Revenue & Financials',
              subtitle: 'Combined financials from registrations, upgrades, and storage add-ons',
              action: AdminButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                isOutlined: true,
                onPressed: () {
                  ref.invalidate(adminAllRegistrationsProvider);
                  ref.invalidate(adminUpgradeRequestsProvider);
                  ref.invalidate(adminStorageAddonsProvider);
                  ref.invalidate(adminReportsDataProvider);
                },
              ),
            ),

            // ── Content Scrollable ──────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Metric Cards ───────────────────────────────────────────
                  RepaintBoundary(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final cardW = w >= 800 ? (w - 32) / 3 : (w >= 540 ? (w - 16) / 2 : w);
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: cardW,
                              child: AdminStatCard(
                                title: 'Total Revenue',
                                value: 'Rs ${_fmt(totalRev)}',
                                icon: Icons.account_balance_wallet_rounded,
                                color: AdminColors.emerald,
                                subtext: '${combinedPayments.length} verified payments',
                              ),
                            ),
                            SizedBox(
                              width: cardW,
                              child: AdminStatCard(
                                title: 'Registrations',
                                value: 'Rs ${_fmt(regRev)}',
                                icon: Icons.how_to_reg_rounded,
                                color: AdminColors.blue,
                                subtext: 'Base shop license fees',
                              ),
                            ),
                            SizedBox(
                              width: cardW,
                              child: AdminStatCard(
                                title: 'Upgrades & Storage',
                                value: 'Rs ${_fmt(upgRev + storageRev)}',
                                icon: Icons.upgrade_rounded,
                                color: AdminColors.amber,
                                subtext: 'Plan diffs & storage renewals',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Revenue Split & Payment Gateway Summary ───────────────
                  RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.border),
                        boxShadow: context.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📊 Revenue Breakdown by Category',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.text1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SplitRow(
                            title: '📱 Registrations',
                            amount: regRev,
                            total: totalRev,
                            color: AdminColors.blue,
                          ),
                          const Divider(height: 20),
                          _SplitRow(
                            title: '⭐ Plan Upgrades',
                            amount: upgRev,
                            total: totalRev,
                            color: AdminColors.amber,
                          ),
                          const Divider(height: 20),
                          _SplitRow(
                            title: '💾 Storage Add-ons',
                            amount: storageRev,
                            total: totalRev,
                            color: AdminColors.emerald,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Payment Methods Breakdown ───────────────────────────────
                  RepaintBoundary(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final cardW = w >= 600 ? (w - 24) / 3 : w;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardW,
                              child: AdminMiniStat(
                                label: 'Easypaisa',
                                value: 'Rs ${_fmt(easypaisaTotal)}',
                                color: AdminColors.emerald,
                              ),
                            ),
                            SizedBox(
                              width: cardW,
                              child: AdminMiniStat(
                                label: 'JazzCash',
                                value: 'Rs ${_fmt(jazzcashTotal)}',
                                color: AdminColors.amber,
                              ),
                            ),
                            SizedBox(
                              width: cardW,
                              child: AdminMiniStat(
                                label: 'Bank Transfer',
                                value: 'Rs ${_fmt(bankTotal)}',
                                color: AdminColors.blue,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Filter & Search Bar ────────────────────────────────────
                  RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.inter(fontSize: 13, color: context.text1),
                            decoration: InputDecoration(
                              hintText: 'Search by shop name or tx ID...',
                              hintStyle: GoogleFonts.inter(fontSize: 13, color: context.text3),
                              prefixIcon: Icon(Icons.search_rounded, size: 18, color: context.text2),
                              isDense: true,
                              filled: true,
                              fillColor: context.surface2,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: context.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: context.border),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                AdminChip(
                                  label: 'All (${combinedPayments.length})',
                                  isSelected: _typeFilter == 'all',
                                  onSelected: () => setState(() => _typeFilter = 'all'),
                                ),
                                const SizedBox(width: 8),
                                AdminChip(
                                  label: 'Registrations',
                                  isSelected: _typeFilter == 'registration',
                                  onSelected: () => setState(() => _typeFilter = 'registration'),
                                ),
                                const SizedBox(width: 8),
                                AdminChip(
                                  label: 'Upgrades',
                                  isSelected: _typeFilter == 'upgrade',
                                  onSelected: () => setState(() => _typeFilter = 'upgrade'),
                                ),
                                const SizedBox(width: 8),
                                AdminChip(
                                  label: 'Storage Add-ons',
                                  isSelected: _typeFilter == 'storage',
                                  onSelected: () => setState(() => _typeFilter = 'storage'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Payment History List ──────────────────────────────────
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.border),
                      ),
                      child: Text(
                        'No transactions match the selected criteria',
                        style: GoogleFonts.inter(fontSize: 13, color: context.text3),
                      ),
                    )
                  else
                    ...filtered.map((p) => _buildPaymentCard(context, p)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, Map<String, dynamic> p) {
    final type = p['type'] as String;
    final (badgeType, badgeLabel) = switch (type) {
      'Registration' => (AdminBadgeType.blue, 'Registration'),
      'Upgrade' => (AdminBadgeType.amber, 'Upgrade'),
      'Storage Add-on' => (AdminBadgeType.emerald, 'Storage'),
      _ => (AdminBadgeType.gray, type),
    };

    final dateStr = p['date'] as String? ?? '';
    final dateFormatted = dateStr.isNotEmpty ? DateFormat('MMM dd, yyyy').format(DateTime.parse(dateStr)) : '';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.border),
          boxShadow: context.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AdminBadge(label: badgeLabel, type: badgeType),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p['shop_name'] as String? ?? 'Shop',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.text1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tx ID: ${p['transaction_id'] ?? 'N/A'} · Method: ${p['payment_method'] ?? 'N/A'} ${dateFormatted.isNotEmpty ? '· $dateFormatted' : ''}',
                    style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Rs ${_fmt(p['amount'] as int? ?? 0)}',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AdminColors.emerald,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final String title;
  final int amount;
  final int total;
  final Color color;

  const _SplitRow({
    required this.title,
    required this.amount,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.text1,
              ),
            ),
            Row(
              children: [
                Text(
                  '${(pct * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.text2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rs ${_fmt(amount)}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: context.surface2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

String _fmt(int n) => NumberFormat('#,##0').format(n);
