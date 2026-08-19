import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licensesAsync = ref.watch(adminLicensesProvider);
    final regsAsync = ref.watch(adminRegistrationsProvider);
    final upgAsync = ref.watch(adminUpgradeRequestsProvider);
    final storageAsync = ref.watch(adminStorageAddonsProvider);
    final earningsAsync = ref.watch(adminPendingEarningsProvider);

    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final shops = licensesAsync.valueOrNull ?? [];
    final pendingRegs = regsAsync.valueOrNull ?? [];
    final pendingUpgs = upgAsync.valueOrNull ?? [];
    final pendingStorage = storageAsync.valueOrNull ?? [];
    final pendingEarnings = earningsAsync.valueOrNull ?? [];



    final reportsAsync = ref.watch(adminReportsDataProvider);
    final reportsData = reportsAsync.valueOrNull ?? {};
    final summaryData = reportsData['summary'] as Map<String, dynamic>? ?? {};
    final breakdownData = reportsData['breakdown'] as Map<String, dynamic>? ?? {};
    final byTier = breakdownData['by_tier'] as Map<String, dynamic>? ?? {};
    final mobileTier = byTier['mobile_only'] as Map<String, dynamic>? ?? {};
    final fullTier = byTier['full_access'] as Map<String, dynamic>? ?? {};
    final full3yrTier = byTier['full_access_3yr'] as Map<String, dynamic>? ?? {};

    final mobileCount = (mobileTier['count'] as num?)?.toInt() ?? 0;
    final fullCount = (fullTier['count'] as num?)?.toInt() ?? 0;
    final full3yrCount = (full3yrTier['count'] as num?)?.toInt() ?? 0;
    final paidTxCount = (summaryData['transaction_count'] as num?)?.toInt() ?? 0;

    final totalShops = shops.length;

    // Combined pending approvals
    final pendingApprovalsCount = pendingRegs.length + pendingUpgs.length + pendingStorage.length;

    final thisMonthRevenue = (summaryData['total_revenue'] as num?)?.toInt() ?? 0;




    // Pending Invite Payouts sum
    int pendingPayoutsSum = 0;
    for (final e in pendingEarnings) {
      final amt = e['amount'] as int? ?? 0;
      pendingPayoutsSum += amt;
    }

    // Storage Attention check (expiring 3yr bundle or near limit)
    final now = DateTime.now();
    int storageAttentionCount = 0;
    for (final s in shops) {
      final bundledStr = s['bundled_storage_expires_at'] as String?;
      if (bundledStr != null) {
        final exp = DateTime.tryParse(bundledStr);
        if (exp != null && exp.difference(now).inDays <= 30 && exp.difference(now).inDays >= 0) {
          storageAttentionCount++;
        }
      }
      final used = (s['storage_used_bytes'] as int?) ?? 0;
      if (used >= 1200000 && (s['storage_addon_active'] != true)) {
        storageAttentionCount++;
      }
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminLicensesProvider);
            ref.invalidate(adminRegistrationsProvider);
            ref.invalidate(adminUpgradeRequestsProvider);
            ref.invalidate(adminStorageAddonsProvider);
            ref.invalidate(adminPendingEarningsProvider);
            ref.invalidate(adminAllRegistrationsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Title & Refresh ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📊 System Dashboard',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: text1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Realtime monitor for approvals, revenue & shops',
                            style: GoogleFonts.inter(fontSize: 12, color: text2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      color: text2,
                      tooltip: 'Refresh Dashboard',
                      onPressed: () {
                        ref.invalidate(adminLicensesProvider);
                        ref.invalidate(adminRegistrationsProvider);
                        ref.invalidate(adminUpgradeRequestsProvider);
                        ref.invalidate(adminStorageAddonsProvider);
                        ref.invalidate(adminPendingEarningsProvider);
                        ref.invalidate(adminAllRegistrationsProvider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── ALERT BANNERS ─────────────────────────────────────────────
                if (pendingApprovalsCount > 0) ...[
                  _AlertBanner(
                    icon: Icons.notifications_active_rounded,
                    title: '🔔 $pendingApprovalsCount Pending Approvals Need Your Review',
                    subtitle: '${pendingRegs.length} Registrations · ${pendingUpgs.length} Upgrades · ${pendingStorage.length} Storage Add-ons',
                    buttonLabel: 'Review Approvals',
                    color: const Color(0xFFF5A623),
                    onTap: () => context.go('/admin/approvals'),
                  ),
                  const SizedBox(height: 12),
                ],

                if (storageAttentionCount > 0) ...[
                  _AlertBanner(
                    icon: Icons.storage_rounded,
                    title: '⚠️ $storageAttentionCount Shops Need Storage Attention',
                    subtitle: 'Shops approaching storage limit or with 3-year bundle expiring within 30 days.',
                    buttonLabel: 'View Shops',
                    color: const Color(0xFFFF6B00),
                    onTap: () => context.go('/admin/shops'),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── 4 KPI CARDS (Mobile: 2x2 equal height grid, Desktop: 4 col) ──
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;

                    if (w < 700) {
                      // 📱 Mobile 2x2 grid layout
                      return Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _KpiCard(
                                    title: 'TOTAL SHOPS',
                                    value: '$totalShops',
                                    breakdown: '$mobileCount Mob · $fullCount Full · $full3yrCount 3Yr',
                                    icon: Icons.storefront_rounded,
                                    color: const Color(0xFF3B82F6),
                                    onTap: () => context.go('/admin/shops'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _KpiCard(
                                    title: 'PENDING APPROVALS',
                                    value: '$pendingApprovalsCount',
                                    breakdown: '${pendingRegs.length} Reg · ${pendingUpgs.length} Upg · ${pendingStorage.length} Add',
                                    icon: Icons.pending_actions_rounded,
                                    color: const Color(0xFFF5A623),
                                    onTap: () => context.go('/admin/approvals'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _KpiCard(
                                    title: 'TOTAL REVENUE',
                                    value: 'Rs ${_fmt(thisMonthRevenue)}',
                                    breakdown: '$paidTxCount Paid Transactions',

                                    icon: Icons.monetization_on_rounded,
                                    color: const Color(0xFF10B981),
                                    onTap: () => context.go('/admin/revenue'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _KpiCard(
                                    title: 'PENDING PAYOUTS',
                                    value: 'Rs ${_fmt(pendingPayoutsSum)}',
                                    breakdown: '${pendingEarnings.length} Earnings Pending',
                                    icon: Icons.account_balance_wallet_rounded,
                                    color: const Color(0xFF8B5CF6),
                                    onTap: () => context.go('/admin/invites'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // 🖥️ Desktop / Wide layout (4 columns)
                    final cardWidth = (w - 36) / 4;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _KpiCard(
                            title: 'TOTAL SHOPS',
                            value: '$totalShops',
                            breakdown: '$mobileCount Mobile · $fullCount Full · $full3yrCount 3Yr',
                            icon: Icons.storefront_rounded,
                            color: const Color(0xFF3B82F6),
                            onTap: () => context.go('/admin/shops'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _KpiCard(
                            title: 'PENDING APPROVALS',
                            value: '$pendingApprovalsCount',
                            breakdown: '${pendingRegs.length} Regs · ${pendingUpgs.length} Upg · ${pendingStorage.length} Addon',
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xFFF5A623),
                            onTap: () => context.go('/admin/approvals'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _KpiCard(
                            title: 'TOTAL REVENUE',
                            value: 'Rs ${_fmt(thisMonthRevenue)}',
                            breakdown: '$paidTxCount Paid Transactions',

                            icon: Icons.monetization_on_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () => context.go('/admin/revenue'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _KpiCard(
                            title: 'PENDING PAYOUTS',
                            value: 'Rs ${_fmt(pendingPayoutsSum)}',
                            breakdown: '${pendingEarnings.length} Profit Earnings Pending',
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF8B5CF6),
                            onTap: () => context.go('/admin/invites'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── REVENUE SPLIT BREAKDOWN ───────────────────────────────────
                Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '💰 Revenue Breakdown',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1),
                          ),
                          Text(
                            'Lifetime Total',
                            style: GoogleFonts.inter(fontSize: 11, color: text2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _RevenueSplitRow(
                        title: '📱 Mobile Only (Rs 12k)',
                        count: (mobileTier['count'] as num?)?.toInt() ?? 0,
                        total: (mobileTier['amount'] as num?)?.toInt() ?? 0,
                        color: const Color(0xFF3B82F6),
                      ),
                      const Divider(height: 16),
                      _RevenueSplitRow(
                        title: '⭐ Full Access (Rs 35k)',
                        count: (fullTier['count'] as num?)?.toInt() ?? 0,
                        total: (fullTier['amount'] as num?)?.toInt() ?? 0,
                        color: const Color(0xFFF5A623),
                      ),
                      const Divider(height: 16),
                      _RevenueSplitRow(
                        title: '💎 Full + 3Yr Storage (Rs 70k)',
                        count: (full3yrTier['count'] as num?)?.toInt() ?? 0,
                        total: (full3yrTier['amount'] as num?)?.toInt() ?? 0,
                        color: const Color(0xFF10B981),
                      ),

                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── RECENT ACTIVITY FEED ──────────────────────────────────────
                Text('⚡ Recent System Activity', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      if (pendingRegs.isNotEmpty)
                        for (final r in pendingRegs.take(3))
                          _ActivityTile(
                            icon: '📱',
                            title: 'Registration: ${r['shop_name'] ?? 'Shop'}',
                            subtitle: 'Plan: ${r['plan_selected'] ?? 'mobile_only'} · Owner: ${r['owner_name'] ?? 'N/A'}',
                          ),
                      if (pendingUpgs.isNotEmpty)
                        for (final u in pendingUpgs.take(3))
                          _ActivityTile(
                            icon: '⭐',
                            title: 'Upgrade: ${u['shops']?['name'] ?? 'Shop'}',
                            subtitle: 'Target Plan: ${u['target_plan'] ?? 'full_access'} · Rs ${u['amount'] ?? 0}',
                          ),
                      if (pendingRegs.isEmpty && pendingUpgs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No recent activity to display.',
                              style: GoogleFonts.inter(fontSize: 13, color: text2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  const _AlertBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: context.text2)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onTap();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(buttonLabel, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: context.text2)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(buttonLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final String title;
  final String value;
  final String breakdown;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.breakdown,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final text1 = context.text1;
    final text2 = context.text2;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark
        ? Color.alphaBlend(widget.color.withValues(alpha: _hovered ? 0.08 : 0.04), surface)
        : Color.alphaBlend(widget.color.withValues(alpha: _hovered ? 0.06 : 0.02), surface);

    final borderColor = widget.color.withValues(alpha: _hovered ? 0.50 : 0.22);

    Widget content = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: _hovered ? 1.5 : 1.2),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: isDark ? (_hovered ? 0.25 : 0.10) : (_hovered ? 0.15 : 0.04)),
              blurRadius: _hovered ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: text1,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x15FFFFFF) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.breakdown,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: text2,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap!();
        },
        child: content,
      );
    }
    return content;
  }
}

class _RevenueSplitRow extends StatelessWidget {
  final String title;
  final int count;
  final int total;
  final Color color;

  const _RevenueSplitRow({
    required this.title,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 450) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.text1)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '$count Shops · Rs ${_fmt(total)}',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.text1)),
              ],
            ),
            Text(
              '$count Shops · Rs ${_fmt(total)}',
              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: context.border.withValues(alpha: 0.3),
        child: Text(icon, style: const TextStyle(fontSize: 14)),
      ),
      title: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.text1)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: context.text2)),
    );
  }
}

String _fmt(int n) => NumberFormat('#,##0').format(n);
