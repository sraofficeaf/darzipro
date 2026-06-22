import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/mock_data.dart';
import '../../shared/providers/app_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reports',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: t1)),
                  Text('June 2026 · SaifurRahman Tailors',
                      style: GoogleFonts.inter(fontSize: 12, color: t2)),
                ],
              ),
            ),
            GoldButton(
              height: 46,
              borderRadius: 16,
              onPressed: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('⬇  ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('Export', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Period selector
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _PeriodBtn(
                label: 'Today',
                isActive: period == ReportPeriod.today,
                onTap: () => ref.read(reportPeriodProvider.notifier).state =
                    ReportPeriod.today,
              ),
              _PeriodBtn(
                label: 'This Month',
                isActive: period == ReportPeriod.thisMonth,
                onTap: () => ref.read(reportPeriodProvider.notifier).state =
                    ReportPeriod.thisMonth,
              ),
              _PeriodBtn(
                label: 'Last Month',
                isActive: period == ReportPeriod.lastMonth,
                onTap: () => ref.read(reportPeriodProvider.notifier).state =
                    ReportPeriod.lastMonth,
              ),
              _PeriodBtn(
                label: 'Custom',
                isActive: period == ReportPeriod.custom,
                onTap: () => ref.read(reportPeriodProvider.notifier).state =
                    ReportPeriod.custom,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // KPI grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            KpiCard(
              emoji: '💰',
              value: '₨850k',
              label: 'Revenue',
              change: '▲ 12%',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              accentColor: AppColors.teal,
              gradientColors: isDark
                  ? [const Color(0xFFF5A623), const Color(0xFFFFD080)]
                  : [const Color(0xFFD97706), const Color(0xFFF59E0B)],
            ),
            KpiCard(
              emoji: '📋',
              value: '64',
              label: 'New Orders',
              change: '▲ 9',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              accentColor: AppColors.teal,
              gradientColors: isDark
                  ? [const Color(0xFFEDF4FF), const Color(0xB2EDF4FF)]
                  : [const Color(0xFF071020), const Color(0xB2071020)],
            ),
            KpiCard(
              emoji: '✅',
              value: '51',
              label: 'Delivered',
              change: '80%',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              accentColor: AppColors.teal,
              gradientColors: isDark
                  ? [const Color(0xFF10CBA0), const Color(0xFF5EECD2)]
                  : [const Color(0xFF059669), const Color(0xFF34D399)],
            ),
            KpiCard(
              emoji: '👥',
              value: '18',
              label: 'New Clients',
              change: '▲ 3',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              accentColor: AppColors.teal,
              gradientColors: isDark
                  ? [const Color(0xFFEDF4FF), const Color(0xB2EDF4FF)]
                  : [const Color(0xFF071020), const Color(0xB2071020)],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Revenue chart
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Revenue Trend',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w800, color: t1),
              ),
              const SizedBox(height: 4),
              Text(
                'Last 7 days',
                style: GoogleFonts.inter(fontSize: 12, color: t2),
              ),
              const SizedBox(height: 14),
              const CustomLineChart(
                values: [42, 68, 55, 100, 72, 60, 48],
                labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Top dress types
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Top Dress Types',
                      style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: t1),
                    ),
                    Text(
                      'This Month',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...MockData.topDressTypes.map((item) => _DressTypeRow(
                    item: item,
                    t1: t1,
                    t2: t2,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

}

class CustomLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final int activeIndex;

  const CustomLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.activeIndex = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentCol = isDark ? AppColors.accent : AppColors.accentL;

    return Column(
      children: [
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(
            painter: LineChartPainter(
              values: values,
              isDark: isDark,
              accentColor: accentCol,
              activeIndex: activeIndex,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(values.length, (i) {
            final label = i < labels.length ? labels[i] : '';
            final isActive = i == activeIndex;
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive
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

class LineChartPainter extends CustomPainter {
  final List<double> values;
  final bool isDark;
  final Color accentColor;
  final int activeIndex;

  LineChartPainter({
    required this.values,
    required this.isDark,
    required this.accentColor,
    required this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final double width = size.width;
    final double height = size.height;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    if (values.length < 2) return;

    final double segmentWidth = width / (values.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < values.length; i++) {
      final double x = i * segmentWidth;
      final double y = height - (maxVal > 0 ? (values[i] / maxVal) * (height - 15) : 0);
      points.add(Offset(x, y));
    }

    // Gradient fill under the line
    final fillPath = Path();
    fillPath.moveTo(0, height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + segmentWidth / 2, p0.dy);
      final controlPoint2 = Offset(p1.dx - segmentWidth / 2, p1.dy);
      fillPath.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p1.dx, p1.dy,
      );
    }
    fillPath.lineTo(width, height);
    fillPath.close();

    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFF5A623).withValues(alpha: 0.25),
        const Color(0xFFF5A623).withValues(alpha: 0.0),
      ],
    );
    final fillPaint = Paint()
      ..shader = areaGradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw the line path
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + segmentWidth / 2, p0.dy);
      final controlPoint2 = Offset(p1.dx - segmentWidth / 2, p1.dy);
      linePath.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p1.dx, p1.dy,
      );
    }

    final linePaint = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // Draw points and highlighted active day
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isActive = i == activeIndex;

      if (isActive) {
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 8.0, glowPaint);

        final dotPaint = Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 4.0, dotPaint);

        // Active day value label above point
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: '₨${values[i].toInt()}k',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(p.dx - textPainter.width / 2, p.dy - 20),
        );
      } else {
        final dotPaint = Paint()
          ..color = isDark ? const Color(0xFF1E293B) : Colors.white
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(p, 3.0, dotPaint);
        canvas.drawCircle(p, 3.0, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.activeIndex != activeIndex ||
      oldDelegate.isDark != isDark ||
      oldDelegate.accentColor != accentColor;
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PeriodBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bg = isDark ? const Color(0x09FFFFFF) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A);
    final activeGradient = const LinearGradient(
      colors: [Color(0xFFF5A623), Color(0xFFD4791A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    Widget chipContent = Center(
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isActive ? const Color(0xFF1A0F00) : text2,
        ),
      ),
    );

    Widget container = Container(
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: isActive ? null : bg,
        gradient: isActive ? activeGradient : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.transparent : borderCol,
          width: 1,
        ),
        boxShadow: isActive
            ? const [
                BoxShadow(
                  color: Color(0x59F5A623),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: chipContent,
    );

    if (isDark && !isActive) {
      container = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: container,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: container,
    );
  }
}

class _DressTypeRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color t1;
  final Color t2;

  const _DressTypeRow({
    required this.item,
    required this.t1,
    required this.t2,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.accent,
      AppColors.purple,
      AppColors.teal,
      AppColors.blue,
    ];
    final idx = MockData.topDressTypes.indexOf(item);
    final color = colors[idx % colors.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'],
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: t1)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (item['percent'] as double),
                    backgroundColor: trackCol,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${item['count']}',
              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: t2)),
          const SizedBox(width: 8),
          Text(formatMoney((item['revenue'] as int).toDouble()),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
