import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';

// ──────────────────────────────────────────────────────────────────────────
// Palette
// ──────────────────────────────────────────────────────────────────────────
class _C {
  static const indigo = Color(0xFF6366F1);
  static const violet = Color(0xFF8B5CF6);
  static const blue = Color(0xFF3B82F6);
  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const rose = Color(0xFFEF4444);
  static const pink = Color(0xFFEC4899);
  static const text3 = Color(0xFF94A3B8);
}

String _fmt(int n) => NumberFormat('#,##0').format(n);

String _fmtCompact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

// ══════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(adminLicensesProvider);
    ref.invalidate(adminRegistrationsProvider);
    ref.invalidate(adminUpgradeRequestsProvider);
    ref.invalidate(adminStorageAddonsProvider);
    ref.invalidate(adminPendingEarningsProvider);
    ref.invalidate(adminAllRegistrationsProvider);
    ref.invalidate(adminSubscriptionPaymentsProvider);
    ref.invalidate(adminSubscriptionStatsProvider);
    ref.invalidate(adminReportsDataProvider);
    ref.invalidate(adminAuditAlertsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licensesAsync = ref.watch(adminLicensesProvider);
    final regsAsync = ref.watch(adminRegistrationsProvider);
    final upgAsync = ref.watch(adminUpgradeRequestsProvider);
    final storageAsync = ref.watch(adminStorageAddonsProvider);
    final earningsAsync = ref.watch(adminPendingEarningsProvider);
    final subPayAsync = ref.watch(adminSubscriptionPaymentsProvider);
    final subStatsAsync = ref.watch(adminSubscriptionStatsProvider);
    final reportsAsync = ref.watch(adminReportsDataProvider);
    final auditAlertsAsync = ref.watch(adminAuditAlertsProvider);

    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shops = licensesAsync.valueOrNull ?? [];
    final pendingRegs = regsAsync.valueOrNull ?? [];
    final pendingUpgs = upgAsync.valueOrNull ?? [];
    final pendingStorage = storageAsync.valueOrNull ?? [];
    final pendingEarnings = earningsAsync.valueOrNull ?? [];
    final subPayments = subPayAsync.valueOrNull ?? [];
    final subStats = subStatsAsync.valueOrNull ?? {};
    final auditAlerts = auditAlertsAsync.valueOrNull ?? [];

    final reportsData = reportsAsync.valueOrNull ?? {};
    final summaryData = reportsData['summary'] as Map<String, dynamic>? ?? {};
    final breakdownData =
        reportsData['breakdown'] as Map<String, dynamic>? ?? {};
    final byTier = breakdownData['by_tier'] as Map<String, dynamic>? ?? {};
    final basicTier    = byTier['basic']     as Map<String, dynamic>? ?? {};
    final standardTier = byTier['standard']  as Map<String, dynamic>? ?? {};
    final unlimitedTier= byTier['unlimited'] as Map<String, dynamic>? ?? {};
    final foundingTier = byTier['founding']  as Map<String, dynamic>? ?? {};
    final lifetimeTier = byTier['lifetime']  as Map<String, dynamic>? ?? {};

    final planCounts = (subStats['plan_counts'] as Map<String, dynamic>?) ?? {};
    final basicCount     = (planCounts['basic']     as num?)?.toInt() ?? 0;
    final standardCount  = (planCounts['standard']  as num?)?.toInt() ?? 0;
    final unlimitedCount = (planCounts['unlimited'] as num?)?.toInt() ?? 0;
    final paidTxCount =
        (summaryData['transaction_count'] as num?)?.toInt() ?? 0;
    final totalShops = shops.length;

    final pendingApprovalsCount =
        pendingRegs.length +
        pendingUpgs.length +
        pendingStorage.length +
        subPayments.length;

    final thisMonthRevenue =
        (summaryData['total_revenue'] as num?)?.toInt() ?? 0;

    int pendingPayoutsSum = 0;
    for (final e in pendingEarnings) {
      pendingPayoutsSum += (e['amount'] as int? ?? 0);
    }

    // Subscription helpers (used by purple hero + panel)
    final mrr = (subStats['mrr'] as num?)?.toInt() ?? 0;
    final planPrices = (subStats['plan_prices'] as Map<String, dynamic>?) ?? {};
    final activePayingCount =
        ((planCounts['basic']     as num?)?.toInt() ?? 0) +
        ((planCounts['standard']  as num?)?.toInt() ?? 0) +
        ((planCounts['unlimited'] as num?)?.toInt() ?? 0);

    // Storage attention
    final now = DateTime.now();
    int storageAttentionCount = 0;
    for (final s in shops) {
      final bundledStr = s['bundled_storage_expires_at'] as String?;
      if (bundledStr != null) {
        final exp = DateTime.tryParse(bundledStr);
        if (exp != null &&
            exp.difference(now).inDays <= 30 &&
            exp.difference(now).inDays >= 0) {
          storageAttentionCount++;
        }
      }
      final used = (s['storage_used_bytes'] as int?) ?? 0;
      final allowanceBytes = (s['storage_allowance_bytes'] as int?) ??
          (s['founding_storage_limit_bytes'] as int?) ??
          (s['lifetime_storage_limit_bytes'] as int?);
      if (allowanceBytes != null && allowanceBytes > 0 &&
          used >= (allowanceBytes * 0.8) &&
          (s['storage_addon_active'] != true)) {
        storageAttentionCount++;
      }
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, rootConstraints) {
            final isMobile = rootConstraints.maxWidth < 700;

            return RefreshIndicator(
              onRefresh: () async => _refreshAll(ref),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── MOBILE PURPLE HERO ────────────────────────────
                    if (isMobile)
                      _MobileHero(
                        pendingApprovalsCount: pendingApprovalsCount,
                        mrr: mrr,
                        activePayingCount: activePayingCount,
                        todayRevenue: thisMonthRevenue,
                        onBellTap: () => context.go('/admin/approvals'),
                      ),

                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        isMobile ? 16 : 20,
                        16,
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── DESKTOP/TABLET HEADER ───────────────────
                          if (!isMobile) ...[
                            _PageHeader(
                              onRefresh: () => _refreshAll(ref),
                              isDark: isDark,
                              text1: text1,
                              text2: text2,
                              surface: surface,
                              border: border,
                            ),
                            const SizedBox(height: 18),
                          ],

                          // ── ALERTS ──────────────────────────────────
                          if (auditAlerts.isNotEmpty) ...[
                            _AlertRibbon(
                              icon: Icons.warning_amber_rounded,
                              title: 'CRITICAL: ${auditAlerts.length} Payment(s) Bypassed Due to Test Mode Flag',
                              subtitle: auditAlerts.first['message'] as String? ??
                                  'A payment arrived with is_test=true for a live shop. Verify payment_providers configuration immediately.',
                              buttonLabel: isMobile ? '' : 'Inspect Providers',
                              onTap: () => context.go('/admin/payment-providers'),
                              isDark: isDark,
                              isMobile: isMobile,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (pendingApprovalsCount > 0) ...[
                            _AlertRibbon(
                              icon: Icons.error_outline_rounded,
                              title: isMobile
                                  ? '$pendingApprovalsCount pending approvals'
                                  : '$pendingApprovalsCount items are waiting for your review',
                              subtitle: isMobile
                                  ? 'Tap to review now'
                                  : '${pendingRegs.length} registrations · ${pendingUpgs.length} upgrades · ${pendingStorage.length} storage addons · ${subPayments.length} subscription payments',
                              buttonLabel: isMobile ? '' : 'Review Now',
                              onTap: () => context.go('/admin/approvals'),
                              isDark: isDark,
                              isMobile: isMobile,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (storageAttentionCount > 0) ...[
                            _AlertRibbon(
                              icon: Icons.storage_rounded,
                              title:
                                  '$storageAttentionCount shops need storage attention',
                              subtitle:
                                  'Shops approaching storage limit or with 3-year bundle expiring within 30 days.',
                              buttonLabel: isMobile ? '' : 'View Shops',
                              onTap: () => context.go('/admin/shops'),
                              isDark: isDark,
                              isMobile: isMobile,
                            ),
                            const SizedBox(height: 10),
                          ],

                          // ── KPI GRID ────────────────────────────────
                          _KpiGrid(
                            totalShops: totalShops,
                            basicCount: basicCount,
                            standardCount: standardCount,
                            unlimitedCount: unlimitedCount,
                            pendingApprovalsCount: pendingApprovalsCount,
                            pendingRegs: pendingRegs.length,
                            pendingUpgs: pendingUpgs.length,
                            pendingStorage: pendingStorage.length,
                            thisMonthRevenue: thisMonthRevenue,
                            paidTxCount: paidTxCount,
                            pendingPayoutsSum: pendingPayoutsSum,
                            pendingEarningsCount: pendingEarnings.length,
                            isDark: isDark,
                            isMobile: isMobile,
                            onShopsTap: () => context.go('/admin/shops'),
                            onApprovalsTap: () =>
                                context.go('/admin/approvals'),
                            onRevenueTap: () => context.go('/admin/revenue'),
                            onPayoutsTap: () => context.go('/admin/agencies'),
                          ),
                          const SizedBox(height: 16),

                          // ── SUBSCRIPTIONS + REVENUE ─────────────────
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1000;
                              final subsPanel = _SubscriptionsPanel(
                                subStats: subStats,
                                subPaymentsCount: subPayments.length,
                                onManagePlans: () =>
                                    context.go('/admin/subscription-plans'),
                              );
                              final revPanel = _RevenuePanel(
                                basicTier:     basicTier,
                                standardTier:  standardTier,
                                unlimitedTier: unlimitedTier,
                                foundingTier:  foundingTier,
                                lifetimeTier:  lifetimeTier,
                                planPrices:    planPrices,
                              );
                              if (wide) {
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(flex: 13, child: subsPanel),
                                      const SizedBox(width: 12),
                                      Expanded(flex: 11, child: revPanel),
                                    ],
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  subsPanel,
                                  const SizedBox(height: 12),
                                  revPanel,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── ACTIVITY ────────────────────────────────
                          _ActivityPanel(
                            pendingRegs: pendingRegs,
                            pendingUpgs: pendingUpgs,
                            onViewAll: () => context.go('/admin/approvals'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MOBILE PURPLE HERO
// ══════════════════════════════════════════════════════════════════════════
class _MobileHero extends StatelessWidget {
  final int pendingApprovalsCount;
  final int mrr;
  final int activePayingCount;
  final int todayRevenue;
  final VoidCallback onBellTap;

  const _MobileHero({
    required this.pendingApprovalsCount,
    required this.mrr,
    required this.activePayingCount,
    required this.todayRevenue,
    required this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 18,
          20,
          28,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date + Greeting on left, Notification bell on right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE · d MMM').format(DateTime.now()),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assalam, Admin 👋',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _NotificationBell(
                  count: pendingApprovalsCount,
                  onTap: onBellTap,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // MRR inline + Today
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESTIMATED MRR',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs ${_fmt(mrr)}',
                        style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFF4ADE80,
                            ).withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          '▲ 8.4% · $activePayingCount paying',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF86EFAC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Today's",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Rs ${_fmtCompact(todayRevenue)}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _C.rose,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4338CA),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PAGE HEADER (Desktop + Tablet)
// ══════════════════════════════════════════════════════════════════════════
class _PageHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isDark;
  final Color text1;
  final Color text2;
  final Color surface;
  final Color border;

  const _PageHeader({
    required this.onRefresh,
    required this.isDark,
    required this.text1,
    required this.text2,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Welcome back, ',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: text1,
                        letterSpacing: -0.7,
                      ),
                    ),
                    TextSpan(
                      text: 'Admin',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _C.indigo,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const TextSpan(text: ' 👋', style: TextStyle(fontSize: 26)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's what's happening across your platform today.",
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: text2,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
          },
          icon: const Icon(Icons.file_download_outlined, size: 16),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(
            foregroundColor: text1,
            side: BorderSide(color: border),
            backgroundColor: surface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            onRefresh();
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Generate Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        _IconButton(
          icon: Icons.refresh_rounded,
          onTap: onRefresh,
          surface: surface,
          border: border,
          text2: text2,
        ),
      ],
    ),
  );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ICON BUTTON
// ══════════════════════════════════════════════════════════════════════════
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color surface;
  final Color border;
  final Color text2;

  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.surface,
    required this.border,
    required this.text2,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: text2, size: 18),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ALERT RIBBON
// ══════════════════════════════════════════════════════════════════════════
class _AlertRibbon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;
  final bool isDark;
  final bool isMobile;

  const _AlertRibbon({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
    required this.isDark,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2A2415) : const Color(0xFFFFFBEB);
    final titleCol = isDark ? const Color(0xFFFCD34D) : const Color(0xFF78350F);
    final subtitleCol = isDark
        ? const Color(0xFFE0B655)
        : const Color(0xFF92400E);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
            left: BorderSide(color: _C.amber, width: 3),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = isMobile || c.maxWidth < 600;

            final iconBox = Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _C.amber.withValues(alpha: isDark ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _C.amber, size: 18),
            );

            final textCol = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: titleCol,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: subtitleCol,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );

            final btn = Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: (narrow && buttonLabel.isEmpty) ? 10 : 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _C.amber,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (buttonLabel.isNotEmpty) ...[
                        Text(
                          buttonLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            );

            return Row(
              children: [
                iconBox,
                const SizedBox(width: 12),
                Expanded(child: textCol),
                const SizedBox(width: 10),
                btn,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// KPI GRID
// ══════════════════════════════════════════════════════════════════════════
class _KpiGrid extends StatelessWidget {
  final int totalShops;
  final int basicCount;
  final int standardCount;
  final int unlimitedCount;
  final int pendingApprovalsCount;
  final int pendingRegs;
  final int pendingUpgs;
  final int pendingStorage;
  final int thisMonthRevenue;
  final int paidTxCount;
  final int pendingPayoutsSum;
  final int pendingEarningsCount;
  final bool isDark;
  final bool isMobile;
  final VoidCallback onShopsTap;
  final VoidCallback onApprovalsTap;
  final VoidCallback onRevenueTap;
  final VoidCallback onPayoutsTap;

  const _KpiGrid({
    required this.totalShops,
    required this.basicCount,
    required this.standardCount,
    required this.unlimitedCount,
    required this.pendingApprovalsCount,
    required this.pendingRegs,
    required this.pendingUpgs,
    required this.pendingStorage,
    required this.thisMonthRevenue,
    required this.paidTxCount,
    required this.pendingPayoutsSum,
    required this.pendingEarningsCount,
    required this.isDark,
    this.isMobile = false,
    required this.onShopsTap,
    required this.onApprovalsTap,
    required this.onRevenueTap,
    required this.onPayoutsTap,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCard(
        label: 'Total Shops',
        compactLabel: 'SHOPS',
        value: '$totalShops',
        trendType: _TrendType.up,
        trendText: isMobile ? '▲ 12%' : '▲ 12.4%',
        trendSuffix: isMobile ? '' : 'this month',
        accent: _C.blue,
        icon: Icons.storefront_rounded,
        chips: [
          _ChipData(label: 'Basic', value: '$basicCount'),
          _ChipData(label: 'Std', value: '$standardCount'),
          _ChipData(label: 'Unlim', value: '$unlimitedCount'),
        ],
        spark: const [
          0.20,
          0.30,
          0.28,
          0.45,
          0.40,
          0.55,
          0.50,
          0.70,
          0.65,
          0.80,
          0.78,
        ],
        onTap: onShopsTap,
        isDark: isDark,
        isCompact: isMobile,
      ),
      _KpiCard(
        label: 'Pending Approvals',
        compactLabel: 'PENDING',
        value: '$pendingApprovalsCount',
        trendType: _TrendType.down,
        trendText: isMobile ? '▼ 3 today' : '▼ 3',
        trendSuffix: isMobile ? '' : 'since yesterday',
        accent: _C.amber,
        icon: Icons.schedule_rounded,
        chips: [
          _ChipData(label: 'Regs', value: '$pendingRegs'),
          _ChipData(label: 'Upg', value: '$pendingUpgs'),
          _ChipData(label: 'Addon', value: '$pendingStorage'),
        ],
        spark: const [
          0.80,
          0.78,
          0.85,
          0.70,
          0.72,
          0.60,
          0.55,
          0.58,
          0.45,
          0.48,
          0.35,
        ],
        onTap: onApprovalsTap,
        isDark: isDark,
        isCompact: isMobile,
      ),
      _KpiCard(
        label: 'Total Revenue',
        compactLabel: 'REVENUE',
        value: 'Rs ${_fmtCompact(thisMonthRevenue)}',
        trendType: _TrendType.up,
        trendText: '▲ 8.4%',
        trendSuffix: isMobile ? '' : 'vs last month',
        accent: _C.emerald,
        icon: Icons.trending_up_rounded,
        chips: [_ChipData(label: 'Paid Tx', value: '$paidTxCount')],
        spark: const [
          0.25,
          0.35,
          0.30,
          0.50,
          0.60,
          0.65,
          0.55,
          0.75,
          0.82,
          0.88,
          0.92,
        ],
        onTap: onRevenueTap,
        isDark: isDark,
        isCompact: isMobile,
      ),
      _KpiCard(
        label: 'Pending Payouts',
        compactLabel: 'PAYOUTS',
        value: isMobile
            ? 'Rs ${_fmtCompact(pendingPayoutsSum)}'
            : 'Rs ${_fmt(pendingPayoutsSum)}',
        trendType: _TrendType.neutral,
        trendText: '● $pendingEarningsCount',
        trendSuffix: isMobile ? '' : '14 pending',
        accent: _C.violet,
        icon: Icons.account_balance_wallet_rounded,
        chips: [_ChipData(label: 'Earnings', value: '$pendingEarningsCount')],
        spark: const [
          0.40,
          0.50,
          0.45,
          0.35,
          0.55,
          0.45,
          0.60,
          0.50,
          0.65,
          0.55,
          0.70,
        ],
        onTap: onPayoutsTap,
        isDark: isDark,
        isCompact: isMobile,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        if (!wide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

enum _TrendType { up, down, neutral }

class _ChipData {
  final String label;
  final String value;
  const _ChipData({required this.label, required this.value});
}

// ══════════════════════════════════════════════════════════════════════════
// KPI CARD
// ══════════════════════════════════════════════════════════════════════════
class _KpiCard extends StatelessWidget {
  final String label;
  final String? compactLabel;
  final String value;
  final _TrendType trendType;
  final String trendText;
  final String trendSuffix;
  final Color accent;
  final IconData icon;
  final List<_ChipData> chips;
  final List<double> spark;
  final VoidCallback? onTap;
  final bool isDark;
  final bool isCompact;

  const _KpiCard({
    required this.label,
    this.compactLabel,
    required this.value,
    required this.trendType,
    required this.trendText,
    required this.trendSuffix,
    required this.accent,
    required this.icon,
    required this.chips,
    required this.spark,
    required this.isDark,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    Widget cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 14 : 16,
                isCompact ? 14 : 16,
                isCompact ? 14 : 16,
                isCompact ? 14 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCompact) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 36),
                      child: Text(
                        (compactLabel ?? label).toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: _C.text3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 36),
                            child: Text(
                              label.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                                color: _C.text3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: isCompact ? 10 : 12),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: isCompact ? 24 : 26,
                      fontWeight: FontWeight.w900,
                      color: text1,
                      letterSpacing: -1.0,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _TrendBadge(
                    trendType: trendType,
                    text: trendText,
                    suffix: isCompact ? '' : trendSuffix,
                    isDark: isDark,
                    text2: text2,
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: 10),
                    _Sparkline(points: spark, color: accent, height: 30),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: border)),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: chips
                            .map((c) => _Chip(label: c.label, value: c.value))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Top-right corner cutout badge
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: isCompact ? 40 : 42,
                height: isCompact ? 40 : 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Icon(icon, color: accent, size: isCompact ? 16 : 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap!();
          },
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    }

    return RepaintBoundary(child: cardContent);
  }
}

class _TrendBadge extends StatelessWidget {
  final _TrendType trendType;
  final String text;
  final String suffix;
  final bool isDark;
  final Color text2;

  const _TrendBadge({
    required this.trendType,
    required this.text,
    required this.suffix,
    required this.isDark,
    required this.text2,
  });

  Color _trendFg() {
    switch (trendType) {
      case _TrendType.up:
        return _C.emerald;
      case _TrendType.down:
        return _C.rose;
      case _TrendType.neutral:
        return _C.indigo;
    }
  }

  Color _trendBg() => _trendFg().withValues(alpha: isDark ? 0.15 : 0.10);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: _trendBg(),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _trendFg(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            suffix,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: text2,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: text2,
          ),
          children: [
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: text1,
              ),
            ),
            const TextSpan(text: ' '),
            TextSpan(text: label),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SPARKLINE
// ══════════════════════════════════════════════════════════════════════════
class _Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final double height;

  const _Sparkline({
    required this.points,
    required this.color,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparkPainter(points: points, color: color),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _SparkPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final step = size.width / (points.length - 1);
    final path = Path();
    final fill = Path();

    for (int i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height * (1 - points[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fill, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) {
    if (old.color != color || old.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (points[i] != old.points[i]) return true;
    }
    return false;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SUBSCRIPTIONS PANEL
// ══════════════════════════════════════════════════════════════════════════
class _SubscriptionsPanel extends StatelessWidget {
  final Map<String, dynamic> subStats;
  final int subPaymentsCount;
  final VoidCallback onManagePlans;

  const _SubscriptionsPanel({
    required this.subStats,
    required this.subPaymentsCount,
    required this.onManagePlans,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mrr = (subStats['mrr'] as num?)?.toInt() ?? 0;
    final planCounts = (subStats['plan_counts'] as Map<String, dynamic>?) ?? {};
    final planPrices = (subStats['plan_prices'] as Map<String, dynamic>?) ?? {};
    final graceCount = (subStats['grace_count'] as num?)?.toInt() ?? 0;
    final readOnlyCount = (subStats['read_only_count'] as num?)?.toInt() ?? 0;
    final lifetimeCount = (subStats['lifetime_count'] as num?)?.toInt() ?? 0;
    final renewals7d = (subStats['upcoming_renewals_7d'] as num?)?.toInt() ?? 0;

    final basicCount = (planCounts['basic'] as num?)?.toInt() ?? 0;
    final standardCount = (planCounts['standard'] as num?)?.toInt() ?? 0;
    final unlimitedCount = (planCounts['unlimited'] as num?)?.toInt() ?? 0;
    final trialCount = (planCounts['trial'] as num?)?.toInt() ?? 0;
    final foundingCount = (subStats['founding_count'] as num?)?.toInt() ?? 0;
    final activePaying = basicCount + standardCount + unlimitedCount;

    // Format plan prices dynamically from DB
    String formatPlanPrice(String code) {
      final price = (planPrices[code] as num?)?.toInt() ?? 0;
      if (code == 'founding') {
        return price > 0 ? 'Rs ${NumberFormat('#,###').format(price)} one-time' : '';
      }
      return price > 0 ? 'Rs $price/mo' : '';
    }

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _C.violet,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Subscriptions & MRR',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: text1,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onManagePlans,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Manage plans',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.indigo,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: _C.indigo,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // MRR hero card
          _MrrHeroCard(
            mrr: mrr,
            activePaying: activePaying,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          _PlanRow(name: 'Free Trial', dotColor: _C.text3, count: trialCount),
          _PlanRow(
            name: 'Basic',
            price: formatPlanPrice('basic'),
            dotColor: _C.blue,
            count: basicCount,
          ),
          _PlanRow(
            name: 'Standard',
            price: formatPlanPrice('standard'),
            dotColor: _C.violet,
            count: standardCount,
          ),
          _PlanRow(
            name: 'Unlimited',
            price: formatPlanPrice('unlimited'),
            dotColor: _C.emerald,
            count: unlimitedCount,
          ),
          _PlanRow(
            name: '👑 Founding',
            dotColor: const Color(0xFFE8A020),
            count: foundingCount,
          ),
          _PlanRow(
            name: '👑 Lifetime',
            dotColor: const Color(0xFFD97706),
            count: lifetimeCount,
          ),

          if (graceCount > 0 ||
              readOnlyCount > 0 ||
              renewals7d > 0 ||
              subPaymentsCount > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2415)
                    : const Color(0xFFFFFBEB),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF4A3D1A)
                      : const Color(0xFFFDE68A),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subPaymentsCount > 0)
                    _WarnLine(
                      text:
                          '$subPaymentsCount subscription payments awaiting review',
                      color: isDark
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFFB45309),
                    ),
                  if (graceCount > 0)
                    _WarnLine(
                      text: '$graceCount shops currently in 3-day grace period',
                      color: isDark
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFFB45309),
                    ),
                  if (readOnlyCount > 0)
                    _WarnLine(
                      text: '$readOnlyCount shops locked in read-only mode',
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFDC2626),
                    ),
                  if (renewals7d > 0)
                    _WarnLine(
                      text:
                          '$renewals7d subscriptions due for renewal within 7 days',
                      color: isDark
                          ? const Color(0xFFE0B655)
                          : const Color(0xFF78350F),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
}

class _MrrHeroCard extends StatelessWidget {
  final int mrr;
  final int activePaying;
  final bool isDark;

  const _MrrHeroCard({
    required this.mrr,
    required this.activePaying,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF4338CA),
              Color(0xFF7C3AED),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _C.indigo.withValues(alpha: isDark ? 0.18 : 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.7),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'ESTIMATED MRR · LIVE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Rs ${_fmt(mrr)}',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                  TextSpan(
                    text: '  / month',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '▲ 8.4% vs last month',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF86EFAC),
                    ),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$activePaying',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                        ),
                      ),
                      TextSpan(
                        text: ' paying shops',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarnLine extends StatelessWidget {
  final String text;
  final Color color;
  const _WarnLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String name;
  final String? price;
  final Color dotColor;
  final int count;

  const _PlanRow({
    required this.name,
    this.price,
    required this.dotColor,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final text1 = context.text1;
    final border = context.border;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: text1,
            ),
          ),
          if (price != null) ...[
            const SizedBox(width: 6),
            Text(
              price!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _C.text3,
              ),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border),
            ),
            child: Text(
              count.toString().padLeft(2, '0'),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: text1,
                letterSpacing: -1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// REVENUE PANEL
// ══════════════════════════════════════════════════════════════════════════
class _RevenuePanel extends StatelessWidget {
  final Map<String, dynamic> basicTier;
  final Map<String, dynamic> standardTier;
  final Map<String, dynamic> unlimitedTier;
  final Map<String, dynamic> foundingTier;
  final Map<String, dynamic> lifetimeTier;
  final Map<String, dynamic> planPrices;

  const _RevenuePanel({
    required this.basicTier,
    required this.standardTier,
    required this.unlimitedTier,
    required this.foundingTier,
    required this.lifetimeTier,
    required this.planPrices,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final basicAmt     = (basicTier['amount']     as num?)?.toInt() ?? 0;
    final standardAmt  = (standardTier['amount']  as num?)?.toInt() ?? 0;
    final unlimitedAmt = (unlimitedTier['amount'] as num?)?.toInt() ?? 0;
    final foundingAmt  = (foundingTier['amount']  as num?)?.toInt() ?? 0;
    final lifetimeAmt  = (lifetimeTier['amount']  as num?)?.toInt() ?? 0;
    final total = basicAmt + standardAmt + unlimitedAmt + foundingAmt + lifetimeAmt;

    double pct(int v) => total == 0 ? 0 : v / total;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _C.emerald,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Revenue Breakdown',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: text1,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  'Lifetime',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _C.text3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _RevenueRow(
              label: 'Basic Plan',
              dotColor: _C.blue,
              amount: basicAmt,
              pct: pct(basicAmt),
            ),
            const SizedBox(height: 10),
            _RevenueRow(
              label: 'Standard Plan',
              dotColor: _C.violet,
              amount: standardAmt,
              pct: pct(standardAmt),
            ),
            const SizedBox(height: 10),
            _RevenueRow(
              label: 'Unlimited Plan',
              dotColor: _C.emerald,
              amount: unlimitedAmt,
              pct: pct(unlimitedAmt),
            ),
            const SizedBox(height: 10),
            _RevenueRow(
              label: '👑 Founding',
              dotColor: const Color(0xFFD97706),
              amount: foundingAmt,
              pct: pct(foundingAmt),
            ),
            const SizedBox(height: 10),
            _RevenueRow(
              label: 'Lifetime (Legacy)',
              dotColor: _C.text3,
              amount: lifetimeAmt,
              pct: pct(lifetimeAmt),
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F2419) : const Color(0xFFF0FDF4),
                border: Border.all(color: _C.emerald.withValues(alpha: 0.22)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL LIFETIME',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _C.emerald,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Across all paid transactions',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _C.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rs ${_fmtCompact(total)}',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _C.emerald,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueRow extends StatelessWidget {
  final String label;
  final Color dotColor;
  final int amount;
  final double pct;

  const _RevenueRow({
    required this.label,
    required this.dotColor,
    required this.amount,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final text1 = context.text1;
    final text2 = context.text2;
    final border = context.border;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: text2,
                ),
              ),
            ),
            Text(
              'Rs ${_fmt(amount)}',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: text1,
                letterSpacing: -1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct.clamp(0.02, 1.0),
              child: Container(color: dotColor),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ACTIVITY PANEL
// ══════════════════════════════════════════════════════════════════════════
class _ActivityPanel extends StatelessWidget {
  final List<Map<String, dynamic>> pendingRegs;
  final List<Map<String, dynamic>> pendingUpgs;
  final VoidCallback onViewAll;

  const _ActivityPanel({
    required this.pendingRegs,
    required this.pendingUpgs,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final items = <Widget>[];

    for (final r in pendingRegs.take(3)) {
      items.add(
        _ActivityRow(
          icon: Icons.storefront_rounded,
          iconColor: _C.blue,
          title: 'New Registration · ${r['shop_name'] ?? 'Shop'}',
          subtitle:
              '${r['plan_selected'] ?? 'mobile_only'} · ${r['owner_name'] ?? 'N/A'}',
          time: '2 min',
          actionLabel: 'Approve',
          onAction: onViewAll,
        ),
      );
    }
    for (final u in pendingUpgs.take(3)) {
      items.add(
        _ActivityRow(
          icon: Icons.star_rounded,
          iconColor: _C.amber,
          title: 'Upgrade Request · ${u['shops']?['name'] ?? 'Shop'}',
          subtitle:
              'Target: ${u['target_plan'] ?? 'full_access'} · Rs ${u['amount'] ?? 0}',
          time: '18 min',
          actionLabel: 'Review',
          onAction: onViewAll,
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _C.pink,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Recent Activity',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: text1,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onViewAll,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View all',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.indigo,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: _C.indigo,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: border),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No recent activity to display.',
                  style: GoogleFonts.inter(fontSize: 13, color: text2),
                ),
              ),
            )
          else
            ...items,
        ],
      ),
    ),
  );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final String actionLabel;
  final VoidCallback onAction;

  const _ActivityRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final text1 = context.text1;
    final text2 = context.text2;
    final border = context.border;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: iconColor.withValues(alpha: 0.20)),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: text1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: text2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _C.text3,
            ),
          ),
          const SizedBox(width: 10),

          _ActivityActionButton(
            label: actionLabel,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _ActivityActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActivityActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _C.indigo,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
