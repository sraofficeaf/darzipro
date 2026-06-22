import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final customersAsync = ref.watch(customersProvider);
    final shopAsync = ref.watch(currentShopProvider);
    final shopName = shopAsync.value?['name'] as String? ?? 'SaifurRahman Tailors';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final isDesktop = Responsive.isDesktop(context);

    Widget newClientButton() {
      return Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? const Color(0x1F10CBA0) : const Color(0xFFCBEFF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.teal.withValues(alpha: 0.3) : const Color(0xFFB0E2EC),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ref.read(navSectionProvider.notifier).state = NavSection.clients;
              context.go('/customers');
            },
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: isDark ? AppColors.teal : const Color(0xFF056475),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'New Client',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.teal : const Color(0xFF056475),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget newOrderButton() {
      return Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFAE34), Color(0xFFFF7C2B)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7C2B).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ref.read(navSectionProvider.notifier).state = NavSection.orders;
              context.go('/orders/new');
            },
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add,
                    size: 16,
                    color: Color(0xFF381A00),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'New Order',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF381A00),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Error: $err', style: const TextStyle(color: AppColors.red)),
      ),
      data: (stats) {
        final recentCustomers = customersAsync.valueOrNull?.take(4).toList() ?? [];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Header ─────────────────────────────────────────────
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WELCOME BACK',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: t2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shopName,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                letterSpacing: -0.3,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 140,
                            child: newClientButton(),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 140,
                            child: newOrderButton(),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WELCOME BACK,',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: t2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shopName,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: newClientButton()),
                          const SizedBox(width: 12),
                          Expanded(child: newOrderButton()),
                        ],
                      ),
                    ],
                  ),
            const SizedBox(height: 18),

            // ── Daily Revenue ───────────────────────────────────────
            _RevenueCard(
              icon: '💵',
              iconBg: AppColors.tealS,
              label: 'Daily Revenue',
              amount: formatMoney(stats.dailyRevenue),
              badge: '↗ +12% vs yesterday',
              badgeColor: AppColors.teal,
            ),
            const SizedBox(height: 14),

            // ── Monthly Revenue + Chart ─────────────────────────────
            _MonthlyRevenueCard(stats: stats),
            const SizedBox(height: 18),

            // ── KPI Grid ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Overview',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                Text(
                  'Today, Jun 11',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                KpiCard(
                  emoji: '📋',
                  value: '${stats.totalOrders}',
                  label: 'Total Orders',
                  change: '↑8',
                  gradientColors: isDark
                      ? [const Color(0xFFEDF4FF), const Color(0xB2EDF4FF)]
                      : [const Color(0xFF071020), const Color(0xB2071020)],
                  onTap: () {
                    ref.read(navSectionProvider.notifier).state = NavSection.orders;
                    context.go('/orders');
                  },
                ),
                KpiCard(
                  emoji: '⏳',
                  value: '0${stats.pendingOrders}',
                  label: 'Pending',
                  change: '+3',
                  accentColor: isDark ? AppColors.accent : AppColors.accentL,
                  gradientColors: isDark
                      ? [const Color(0xFFF5A623), const Color(0xFFFFD080)]
                      : [const Color(0xFFD97706), const Color(0xFFF59E0B)],
                  onTap: () {
                    ref.read(navSectionProvider.notifier).state = NavSection.orders;
                    context.go('/orders');
                  },
                ),
                KpiCard(
                  emoji: '✅',
                  value: '${stats.readyOrders}',
                  label: 'Ready',
                  change: '↑2',
                  accentColor: AppColors.teal,
                  gradientColors: isDark
                      ? [const Color(0xFF10CBA0), const Color(0xFF5EECD2)]
                      : [const Color(0xFF059669), const Color(0xFF34D399)],
                  onTap: () {
                    ref.read(navSectionProvider.notifier).state = NavSection.orders;
                    context.go('/orders');
                  },
                ),
                KpiCard(
                  emoji: '💰',
                  value: '42k',
                  label: 'Income',
                  change: '▲12%',
                  accentColor: isDark ? AppColors.accent : AppColors.accentL,
                  gradientColors: isDark
                      ? [const Color(0xFFF5A623), const Color(0xFFFFD080)]
                      : [const Color(0xFFD97706), const Color(0xFFF59E0B)],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Urgent Banner ───────────────────────────────────────
            GestureDetector(
              onTap: () {
                ref.read(navSectionProvider.notifier).state = NavSection.orders;
                context.go('/orders');
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.red.withValues(alpha: 0.18),
                      AppColors.red.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.redS,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('⚠️', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '0${stats.urgentOrders} Urgent Orders',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.red,
                          ),
                        ),
                        Text(
                          'DELIVERY DUE TODAY',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.red.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '›',
                      style: TextStyle(fontSize: 20, color: AppColors.red),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Recent Clients ──────────────────────────────────────
            SectionHeader(
              title: 'Recent Clients',
              action: 'VIEW ALL',
              onAction: () {
                ref.read(navSectionProvider.notifier).state = NavSection.clients;
                context.go('/customers');
              },
            ),
            const SizedBox(height: 12),
            ...recentCustomers.map((c) => _CustomerRow(customer: c)),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

// ── Revenue Card ───────────────────────────────────────────────────────
class _RevenueCard extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String label;
  final String amount;
  final String badge;
  final Color badgeColor;

  const _RevenueCard({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.amount,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'vs yesterday',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: t2,
                ),
              ),
              SparklineWidget(
                color: isDark ? AppColors.accent : AppColors.accentL,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sparkline Widget & Painter ─────────────────────────────────────────
class SparklineWidget extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const SparklineWidget({
    super.key,
    required this.color,
    this.width = 90,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: SparklinePainter(color: color),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final Color color;

  SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(0, h * 24 / 30);
    path.cubicTo(w * 12 / 100, h * 22 / 30, w * 20 / 100, h * 16 / 30, w * 32 / 100, h * 12 / 30);
    path.cubicTo(w * 44 / 100, h * 8 / 30, w * 52 / 100, h * 18 / 30, w * 64 / 100, h * 14 / 30);
    path.cubicTo(w * 74 / 100, h * 11 / 30, w * 84 / 100, h * 4 / 30, w, h * 6 / 30);

    final fillPath = Path.from(path);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w, h * 6 / 30), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Monthly Revenue + Bar Chart ────────────────────────────────────────
class _MonthlyRevenueCard extends StatelessWidget {
  final dynamic stats;

  const _MonthlyRevenueCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final List<double> weeklyRevenue = (stats.weeklyRevenue as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final List<String> weekLabels = (stats.weekLabels as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.accentS,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('💼', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Monthly Revenue',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surf2Dark : AppColors.surf2Light,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This Month',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GoldGradientText(
            formatMoney(stats.monthlyRevenue),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          CustomBarChart(
            values: weeklyRevenue,
            labels: weekLabels,
          ),
        ],
      ),
    );
  }
}

// ── Custom Bar Chart ───────────────────────────────────────────────────
class CustomBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const CustomBarChart({
    super.key,
    required this.values,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentCol = isDark ? AppColors.accent : AppColors.accentL;

    return Column(
      children: [
        SizedBox(
          height: 90,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (i) {
              final val = values[i];
              final isToday = i == 3 || i == values.length - 1;
              final heightPct = maxVal > 0 ? (val / maxVal).clamp(0.1, 1.0) : 0.1;

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FractionallySizedBox(
                        heightFactor: heightPct,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            gradient: isToday
                                ? const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Color(0xFFFFAE34), Color(0xFFFF7C2B)],
                                  )
                                : LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: isDark
                                        ? [const Color(0x11EDF4FF), const Color(0x26EDF4FF)]
                                        : [const Color(0x0F071020), const Color(0x21071020)],
                                  ),
                            boxShadow: isToday ? [
                              BoxShadow(
                                color: const Color(0xFFFF8B3D).withValues(alpha: 0.45),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ] : null,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(values.length, (i) {
            final label = i < labels.length ? labels[i] : '';
            final isToday = i == 3 || i == values.length - 1;
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isToday
                        ? accentCol
                        : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Customer Row ───────────────────────────────────────────────────────
class _CustomerRow extends StatelessWidget {
  final dynamic customer;

  const _CustomerRow({required this.customer});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: AppCard(
        onTap: () => context.go('/customers/${customer.id}'),
        child: Row(
          children: [
            CustomerAvatar(name: customer.name, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.phone,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: t2,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'ID: ${customer.id.toString().toUpperCase().substring(0, 4)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.accent : AppColors.accentL,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeAgo(customer.createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: t3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
