import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/models/models.dart';
import '../customers/add_customer_modal.dart';
import '../orders/new_order_modal.dart';
import '../storage/storage_addon_modal.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final customersAsync = ref.watch(customersProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final shopAsync = ref.watch(currentShopProvider);

    final shopName =
        shopAsync.value?['name'] as String? ?? 'SaifurRahman Tailors';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';

    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: context.bg,
        body: statsAsync.when(
          loading: () => const _DashboardSkeleton(),
          error: (err, _) => _DashboardError(
            message: err.toString(),
            onRetry: () => ref.invalidate(dashboardStatsProvider),
          ),
          data: (stats) {
            final customers = customersAsync.valueOrNull ?? [];
            final orders = ordersAsync.valueOrNull ?? [];

            // Sort customers by created_at descending and take 5
            final sortedCustomers = List<CustomerModel>.from(customers)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final recentCustomers = sortedCustomers.take(5).toList();

            // Calculate overdue orders: deliveryDate < today and status not delivered/cancelled
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final overdueOrdersCount = orders.where((o) =>
                o.status != OrderStatus.delivered &&
                o.status != OrderStatus.cancelled &&
                o.deliveryDate != null &&
                o.deliveryDate!.isBefore(todayStart)).length;

            final screenWidth = MediaQuery.sizeOf(context).width;
            final isCompact = screenWidth < 680;
            final isDesktop = screenWidth >= 1024;

            final dailyRevFormatted = stats.dailyRevenue.toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );

            final monthlyRevFormatted = stats.monthlyRevenue.toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );

            final double monthlyIncomeVal = stats.monthlyRevenue;
            final String formattedIncome;
            if (monthlyIncomeVal >= 1000) {
              formattedIncome = '${(monthlyIncomeVal / 1000).toStringAsFixed(0)}k';
            } else {
              formattedIncome = monthlyIncomeVal.toStringAsFixed(0);
            }

            // Action Buttons tapped
            void handleNewClient() {
              ref.read(navSectionProvider.notifier).state = NavSection.clients;
              AddCustomerModal.show(context);
            }

            void handleNewOrder() {
              ref.read(navSectionProvider.notifier).state = NavSection.orders;
              NewOrderModal.show(context);
            }

            // Top Row Header
            final headerWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact) ...[
                  Text(
                    isUrdu ? 'خوش آمدید' : 'WELCOME BACK',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.text2,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shopName,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: context.text1,
                    ),
                  ),
                  const SizedBox(height: 14),
                   Row(
                    children: [
                      Expanded(
                        child: _OutlineActionBtn(
                          icon: Icons.person_add_rounded,
                          label: isUrdu ? 'نیا گاہک' : 'New Client',
                          onTap: handleNewClient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GradientActionBtn(
                          icon: Icons.add_rounded,
                          label: isUrdu ? 'نیا آرڈر' : 'New Order',
                          onTap: handleNewOrder,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUrdu ? 'خوش آمدید' : 'WELCOME BACK',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.text2,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shopName,
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: context.text1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _OutlineActionBtn(
                            icon: Icons.person_add_rounded,
                            label: isUrdu ? 'نیا گاہک' : 'New Client',
                            onTap: handleNewClient,
                          ),
                          const SizedBox(width: 10),
                          _GradientActionBtn(
                            icon: Icons.add_rounded,
                            label: isUrdu ? 'نیا آرڈر' : 'New Order',
                            onTap: handleNewOrder,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

              ],
            );

            // Revenue Row Layout (Daily & Monthly)
            final dailyCard = Container(
              height: isDesktop ? null : 170,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x09FFFFFF) : context.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
                boxShadow: isDark ? null : context.cardShadow,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0x2610CBA0),
                                    border: Border.all(color: const Color(0x4010CBA0)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF10CBA0)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isUrdu ? 'روزانہ کی آمدنی' : 'DAILY REVENUE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.text2,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x1410CBA0),
                                border: Border.all(color: const Color(0x2810CBA0)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isUrdu ? 'کل سے 12٪ زیادہ' : '+12% vs yesterday',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF10CBA0),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text.rich(
                          TextSpan(
                            text: 'Rs ',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: context.text2,
                            ),
                            children: [
                              TextSpan(
                                text: dailyRevFormatted,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFFEDF4FF) : context.text1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUrdu ? 'کل کے مقابلے میں' : 'vs yesterday',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: context.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Opacity(
                      opacity: 0.8,
                      child: CustomPaint(
                        size: const Size(100, 36),
                        painter: _SparklinePainter(),
                      ),
                    ),
                  ),
                ],
              ),
            );

            final monthlyCard = Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0x09FFFFFF) : context.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
                boxShadow: isDark ? null : context.cardShadow,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0x1FD97706),
                              border: Border.all(color: const Color(0x33D97706)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.work_rounded, size: 18, color: Color(0xFFD97706)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isUrdu ? 'ماہانہ آمدنی' : 'MONTHLY REVENUE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.text2,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x0FFFFFFF) : context.surface2,
                          border: Border.all(color: isDark ? const Color(0x1AFFFFFF) : context.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isUrdu ? 'اس مہینے' : 'This Month ▾',
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFF8AA0B8) : context.text2,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: isDark
                          ? const [Color(0xFFF5A623), Color(0xFFFFD080)]
                          : const [Color(0xFFD97706), Color(0xFFF5A623)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text.rich(
                      TextSpan(
                        text: 'Rs ',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                            text: monthlyRevFormatted,
                            style: GoogleFonts.outfit(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _WeeklyBarChart(
                    values: stats.weeklyRevenue,
                    labels: stats.weekLabels,
                  ),
                ],
              ),
            );

            final revenueWidget = isDesktop
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 10, child: dailyCard),
                        const SizedBox(width: 14),
                        Expanded(flex: 16, child: monthlyCard),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      dailyCard,
                      const SizedBox(height: 14),
                      monthlyCard,
                    ],
                  );

            // KPI Grid
            final kpiWidget = _KpiGrid(
              stats: stats,
              formattedIncome: formattedIncome,
              isDesktop: isDesktop,
            );

            // Urgent Banner
            final urgentWidget = overdueOrdersCount > 0
                ? _UrgentBanner(
                    count: overdueOrdersCount,
                    onTap: () {
                      ref.read(navSectionProvider.notifier).state = NavSection.orders;
                      context.push('/orders');
                    },
                  )
                : const SizedBox.shrink();

            // Recent Clients
            final recentClientsWidget = _RecentClientsSection(
              customers: recentCustomers,
              orders: orders,
              onViewAll: () {
                ref.read(navSectionProvider.notifier).state = NavSection.clients;
                context.push('/customers');
              },
              onAddClient: handleNewClient,
            );

            return ListView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              children: [
                headerWidget,
                const SizedBox(height: 20),
                // Storage warning banner (shows at 80%+ usage, hidden if addon active)
                _StorageWarningBanner(shopAsync: shopAsync),
                revenueWidget,
                const SizedBox(height: 20),
                kpiWidget,
                if (overdueOrdersCount > 0) ...[
                  const SizedBox(height: 20),
                  urgentWidget,
                ],
                const SizedBox(height: 24),
                recentClientsWidget,
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ✦ TOP ROW ACTION BUTTONS
// ══════════════════════════════════════════════════════════════════════
class _OutlineActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlineActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x1F10CBA0),
          border: Border.all(color: const Color(0x4D10CBA0), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF10CBA0)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF10CBA0),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFD97706), Color(0xFFB45309)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59D97706),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ✦ SPARKLINE CUSTOM PAINTER
// ══════════════════════════════════════════════════════════════════════
class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x4DF5A623), Color(0x00F5A623)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Curved Bezier curve path matching mockup SVG
    path.moveTo(0, h * 28 / 36);
    path.quadraticBezierTo(w * 15 / 100, h * 20 / 36, w * 25 / 100, h * 22 / 36);
    path.quadraticBezierTo(w * 40 / 100, h * 24 / 36, w * 50 / 100, h * 14 / 36);
    path.quadraticBezierTo(w * 65 / 100, h * 4 / 36, w * 75 / 100, h * 8 / 36);
    path.quadraticBezierTo(w * 85 / 100, h * 12 / 36, w, h * 6 / 36);

    final fillPath = Path.from(path);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════
// ✦ WEEKLY BAR CHART
// ══════════════════════════════════════════════════════════════════════
class _WeeklyBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const _WeeklyBarChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (index) {
          final val = values[index];
          final label = index < labels.length ? labels[index] : '';
          final heightPct = maxVal > 0 ? (val / maxVal).clamp(0.1, 1.0) : 0.1;
          final isToday = index == values.length - 1;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: heightPct,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        gradient: isToday
                            ? const LinearGradient(
                                colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                        color: isToday ? null : (isDark ? const Color(0x12FFFFFF) : context.border),
                        boxShadow: isToday
                            ? [
                                const BoxShadow(
                                  color: Color(0x66F5A623),
                                  blurRadius: 12,
                                  offset: Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? const Color(0xFFF5A623) : context.text2,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ✦ KPI GRID & KPI CARD
// ══════════════════════════════════════════════════════════════════════
class _KpiGrid extends StatelessWidget {
  final DashboardStats stats;
  final String formattedIncome;
  final bool isDesktop;

  const _KpiGrid({
    required this.stats,
    required this.formattedIncome,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isDesktop ? 1.3 : 1.4,
      children: [
        _KpiCard(
          emoji: '📋',
          value: '${stats.totalOrders}',
          label: 'Total Orders',
          trend: '+8',
          trendColor: const Color(0xFF10CBA0),
          trendBg: const Color(0x1410CBA0),
          accentColor: const Color(0xFF5B72F5),
        ),
        _KpiCard(
          emoji: '⏳',
          value: '${stats.pendingOrders}',
          label: 'Pending',
          trend: '+3',
          trendColor: const Color(0xFFF5A623),
          trendBg: const Color(0x1FD97706),
          accentColor: const Color(0xFFD97706),
          valueColor: const Color(0xFFF5A623),
        ),
        _KpiCard(
          emoji: '✅',
          value: '${stats.readyOrders}',
          label: 'Ready',
          trend: '↑2',
          trendColor: const Color(0xFF10CBA0),
          trendBg: const Color(0x1410CBA0),
          accentColor: const Color(0xFF10CBA0),
          valueColor: const Color(0xFF10CBA0),
        ),
        _KpiCard(
          emoji: '💰',
          value: formattedIncome,
          label: 'Income',
          trend: '▲12%',
          trendColor: const Color(0xFF9B5CF5),
          trendBg: const Color(0x1F9B5CF5),
          accentColor: const Color(0xFF9B5CF5),
          valueColor: const Color(0xFF9B5CF5),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final String trend;
  final Color trendColor;
  final Color trendBg;
  final Color accentColor;
  final Color? valueColor;

  const _KpiCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.trend,
    required this.trendColor,
    required this.trendBg,
    required this.accentColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final double numValue = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final String suffix = value.replaceAll(RegExp(r'[0-9.]'), '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x09FFFFFF) : context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
        boxShadow: isDark ? null : context.cardShadow,
      ),
      child: Stack(
        children: [
          // Bottom Accent Line
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: trendBg,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        trend,
                        style: GoogleFonts.inter(
                          color: trendColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: numValue),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, val, child) {
                    final displayVal = val.toStringAsFixed(0);
                    return Text(
                      '$displayVal$suffix',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: valueColor ?? (isDark ? const Color(0xFFEDF4FF) : context.text1),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.text2,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ✦ URGENT ORDERS BANNER
// ══════════════════════════════════════════════════════════════════════
class _UrgentBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _UrgentBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 18, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x1FFF3A58), Color(0x0AFF3A58)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0x40FF3A58), width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0x26FF3A58),
                    border: Border.all(color: const Color(0x4DFF3A58)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('🚨', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$count Orders Past Deadline!',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF3A58),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'These orders need immediate attention',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xB3FF3A58),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x26FF3A58),
                    border: Border.all(color: const Color(0x4DFF3A58)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'View Now →',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF3A58),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3A58),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ✦ RECENT CLIENTS SECTION & ROW
// ══════════════════════════════════════════════════════════════════════
class _RecentClientsSection extends StatelessWidget {
  final List<CustomerModel> customers;
  final List<OrderModel> orders;
  final VoidCallback onViewAll;
  final VoidCallback onAddClient;

  const _RecentClientsSection({
    required this.customers,
    required this.orders,
    required this.onViewAll,
    required this.onAddClient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Clients',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.text1,
              ),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'View All →',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (customers.isNotEmpty)
          ...customers.map((c) {
            final customerOrders = orders.where((o) => o.customerId == c.id).toList();
            OrderStatus? latestStatus;
            if (customerOrders.isNotEmpty) {
              customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
              latestStatus = customerOrders.first.status;
            }
            return _ClientRow(customer: c, status: latestStatus);
          })
        else
          _EmptyRecentClients(onAdd: onAddClient),
      ],
    );
  }
}

class _ClientRow extends StatefulWidget {
  final CustomerModel customer;
  final OrderStatus? status;

  const _ClientRow({required this.customer, required this.status});

  @override
  State<_ClientRow> createState() => _ClientRowState();
}

class _ClientRowState extends State<_ClientRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = widget.status ?? OrderStatus.pending;
    final initials = widget.customer.initials;

    Color badgeBg;
    Color badgeText;
    Color badgeBorder;
    String statusStr;

    if (isDark) {
      switch (status) {
        case OrderStatus.pending:
          badgeBg = const Color(0x1FD97706);
          badgeText = const Color(0xFFF5A623);
          badgeBorder = const Color(0x33D97706);
          statusStr = 'Pending';
          break;
        case OrderStatus.cutting:
        case OrderStatus.stitching:
          badgeBg = const Color(0x1F5B72F5);
          badgeText = const Color(0xFF5B72F5);
          badgeBorder = const Color(0x335B72F5);
          statusStr = 'Stitching';
          break;
        case OrderStatus.ready:
          badgeBg = const Color(0x1F10CBA0);
          badgeText = const Color(0xFF10CBA0);
          badgeBorder = const Color(0x3310CBA0);
          statusStr = 'Ready';
          break;
        case OrderStatus.delivered:
        case OrderStatus.cancelled:
          badgeBg = const Color(0x1F2A3E58);
          badgeText = const Color(0xFF5A7090);
          badgeBorder = const Color(0x142A3E58);
          statusStr = status == OrderStatus.cancelled ? 'Cancelled' : 'Delivered';
          break;
      }
    } else {
      switch (status) {
        case OrderStatus.pending:
          badgeBg = AppColors.lightAccentBg;
          badgeText = AppColors.lightAccent;
          badgeBorder = AppColors.lightAccentBorder;
          statusStr = 'Pending';
          break;
        case OrderStatus.cutting:
        case OrderStatus.stitching:
          badgeBg = AppColors.lightBlueBg;
          badgeText = AppColors.lightBlue;
          badgeBorder = AppColors.lightBlueBorder;
          statusStr = 'Stitching';
          break;
        case OrderStatus.ready:
          badgeBg = AppColors.lightTealBg;
          badgeText = AppColors.lightTeal;
          badgeBorder = AppColors.lightTealBorder;
          statusStr = 'Ready';
          break;
        case OrderStatus.delivered:
          badgeBg = AppColors.lightSurface2;
          badgeText = AppColors.lightText2;
          badgeBorder = AppColors.lightBorder;
          statusStr = 'Delivered';
          break;
        case OrderStatus.cancelled:
          badgeBg = AppColors.lightRedBg;
          badgeText = AppColors.lightRed;
          badgeBorder = AppColors.lightRedBorder;
          statusStr = 'Cancelled';
          break;
      }
    }

    final int hash = widget.customer.name.hashCode;
    final List<Color> avatarColors = hash % 3 == 0
        ? [const Color(0xFF5B72F5), const Color(0xFF3B4ED8)]
        : hash % 3 == 1
            ? [const Color(0xFFEC4899), const Color(0xFFBE185D)]
            : [const Color(0xFF10B981), const Color(0xFF065F46)];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.go('/customers/${widget.customer.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? (isDark ? const Color(0x0FFFFFFF) : context.surfaceHover) : (isDark ? const Color(0x08FFFFFF) : context.surface),
            border: Border.all(color: isDark ? const Color(0x0FFFFFFF) : context.border, width: 1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isDark ? null : context.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: avatarColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.customer.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.customer.phone,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: context.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  border: Border.all(color: badgeBorder, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusStr,
                  style: GoogleFonts.inter(
                    color: badgeText,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeAgo(widget.customer.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: context.text3,
                ),
              ),
            ],
          ),
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

class _EmptyRecentClients extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyRecentClients({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x09FFFFFF) : context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.person_add_disabled_outlined,
              size: 40,
              color: context.text2,
            ),
            const SizedBox(height: 12),
            Text(
              'No recent clients',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.text1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your first customer to start taking orders',
              style: TextStyle(
                fontSize: 12,
                color: context.text2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0x1F10CBA0),
                  border: Border.all(color: const Color(0x4D10CBA0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add, size: 16, color: Color(0xFF10CBA0)),
                    const SizedBox(width: 6),
                    Text(
                      'Add Client',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF10CBA0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

// ══════════════════════════════════════════════════════════════════════
// ✦ FULL SKELETON LOADING
// ══════════════════════════════════════════════════════════════════════
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white10 : Colors.black12;
    final highlight = isDark ? Colors.white24 : Colors.black26;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ShimmerBox(
          width: 160,
          height: 12,
          baseColor: base,
          highlightColor: highlight,
        ),
        const SizedBox(height: 8),
        _ShimmerBox(
          width: 240,
          height: 24,
          baseColor: base,
          highlightColor: highlight,
        ),
        const SizedBox(height: 18),
        _ShimmerBox(
          width: double.infinity,
          height: 120,
          borderRadius: 16,
          baseColor: base,
          highlightColor: highlight,
        ),
        const SizedBox(height: 14),
        _ShimmerBox(
          width: double.infinity,
          height: 160,
          borderRadius: 16,
          baseColor: base,
          highlightColor: highlight,
        ),
        const SizedBox(height: 18),
        _ShimmerBox(
          width: double.infinity,
          height: 200,
          borderRadius: 16,
          baseColor: base,
          highlightColor: highlight,
        ),
      ],
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(-2.0 + _controller.value * 4.0, -0.3),
            end: Alignment(-1.0 + _controller.value * 4.0, 0.3),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ✦ ERROR STATE WITH RETRY
// ══════════════════════════════════════════════════════════════════════
class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0x09FFFFFF) : context.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: context.text3,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load dashboard',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.text1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.replaceAll('Exception: ', ''),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.text2,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFB45309)],
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

// ══════════════════════════════════════════════════════════════════════
// ✦ STORAGE WARNING BANNER
// ══════════════════════════════════════════════════════════════════════
class _StorageWarningBanner extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> shopAsync;

  const _StorageWarningBanner({required this.shopAsync});

  @override
  Widget build(BuildContext context) {
    final shop = shopAsync.valueOrNull;
    if (shop == null) return const SizedBox.shrink();

    final storageUsed = (shop['storage_used_bytes'] as int?) ?? 0;
    final addonActive = (shop['storage_addon_active'] as bool?) ?? false;
    final now = DateTime.now();

    // Check addon expiry
    bool effectiveAddon = addonActive;
    if (addonActive) {
      final expiresStr = shop['storage_addon_expires_at'] as String?;
      if (expiresStr != null) {
        final expires = DateTime.tryParse(expiresStr);
        if (expires != null && now.isAfter(expires)) {
          effectiveAddon = false;
        }
      }
    }

    // Check 3-year bundled storage expiry
    final bundledExpiresStr = shop['bundled_storage_expires_at'] as String?;
    DateTime? bundledExpires;
    if (bundledExpiresStr != null) {
      bundledExpires = DateTime.tryParse(bundledExpiresStr);
    }

    bool bundledValid = false;
    int? bundledDaysRemaining;
    if (bundledExpires != null) {
      if (now.isBefore(bundledExpires)) {
        bundledDaysRemaining = bundledExpires.difference(now).inDays;
        if (bundledDaysRemaining > 30) {
          bundledValid = true; // Fully valid, no warning needed
        }
      }
    }

    // If add-on is active OR bundled storage has > 30 days left, no banner
    if (effectiveAddon || bundledValid) return const SizedBox.shrink();

    // If bundled storage is expiring in <= 30 days
    if (bundledDaysRemaining != null && bundledDaysRemaining <= 30 && bundledDaysRemaining >= 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B00), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ Your included storage expires in $bundledDaysRemaining days — subscribe to continue unlimited storage.',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B00)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => StorageAddonModal.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Subscribe', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    const int warningThreshold = 1200000; // 1.2MB = 80%
    const int hardLimit = 1500000;        // 1.5MB = 100%

    if (storageUsed < warningThreshold) return const SizedBox.shrink();

    final bool isFull = storageUsed >= hardLimit;
    final double percent = (storageUsed / hardLimit * 100).clamp(0, 100);
    final String percentStr = percent.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isFull
              ? const Color(0xFFFF3A58).withValues(alpha: 0.12)
              : const Color(0xFFFF6B00).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFull
                ? const Color(0xFFFF3A58).withValues(alpha: 0.4)
                : const Color(0xFFFF6B00).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isFull ? Icons.storage_rounded : Icons.warning_amber_rounded,
              color: isFull ? const Color(0xFFFF3A58) : const Color(0xFFFF6B00),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isFull
                    ? '⚠️ Storage full (Limited Storage reached). Upgrade to unlimited storage.'
                    : '⚠️ You\'ve used $percentStr% of your storage (Limited Storage). Upgrade Now.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isFull ? const Color(0xFFFF3A58) : const Color(0xFFFF6B00),
                ),
              ),

            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => StorageAddonModal.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isFull ? const Color(0xFFFF3A58) : const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Upgrade',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
