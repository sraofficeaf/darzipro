import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/models/models.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTimeRange? _customDateRange;

  // Formatter for short k-based amounts (e.g. Rs 850k)
  String _formatK(double value) {
    if (value >= 1000000) {
      return 'Rs ${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (value >= 1000) {
      return 'Rs ${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    } else {
      return 'Rs ${value.toStringAsFixed(0)}';
    }
  }

  // Get active date range based on period selection
  DateTimeRange _getDateRange(ReportPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case ReportPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case ReportPeriod.lastMonth:
        final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final lastMonthMonth = now.month == 1 ? 12 : now.month - 1;
        final start = DateTime(lastMonthYear, lastMonthMonth, 1);
        final daysInLastMonth = DateTime(lastMonthYear, lastMonthMonth + 1, 0).day;
        final end = DateTime(lastMonthYear, lastMonthMonth, daysInLastMonth, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case ReportPeriod.custom:
        if (_customDateRange != null) return _customDateRange!;
        final start = now.subtract(const Duration(days: 30));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
    }
  }

  // Get previous date range of the same duration for trends comparison
  DateTimeRange _getPrevDateRange(DateTimeRange currentRange) {
    final duration = currentRange.end.difference(currentRange.start);
    final prevStart = currentRange.start.subtract(duration);
    final prevEnd = currentRange.start.subtract(const Duration(milliseconds: 1));
    return DateTimeRange(start: prevStart, end: prevEnd);
  }

  // Compute stats dynamically for a given range
  _PeriodStats _calculateStats(
    DateTimeRange range,
    List<OrderModel> orders,
    List<CustomerModel> customers,
  ) {
    double revenue = 0;
    int newOrders = 0;
    int deliveredOrders = 0;
    int newClients = 0;

    for (final order in orders) {
      // 1. Revenue: sum of all payments made in this date range
      for (final p in order.payments) {
        if ((p.paidAt.isAfter(range.start) || p.paidAt.isAtSameMomentAs(range.start)) &&
            (p.paidAt.isBefore(range.end) || p.paidAt.isAtSameMomentAs(range.end))) {
          revenue += p.amount;
        }
      }

      // 2. New orders: orders placed in this date range
      if ((order.orderDate.isAfter(range.start) || order.orderDate.isAtSameMomentAs(range.start)) &&
          (order.orderDate.isBefore(range.end) || order.orderDate.isAtSameMomentAs(range.end))) {
        newOrders++;
      }

      // 3. Delivered orders: delivered in this range
      if (order.status == OrderStatus.delivered) {
        final checkDate = order.deliveryDate ?? order.orderDate;
        if ((checkDate.isAfter(range.start) || checkDate.isAtSameMomentAs(range.start)) &&
            (checkDate.isBefore(range.end) || checkDate.isAtSameMomentAs(range.end))) {
          deliveredOrders++;
        }
      }
    }

    // 4. New clients: clients created in this date range
    for (final c in customers) {
      if ((c.createdAt.isAfter(range.start) || c.createdAt.isAtSameMomentAs(range.start)) &&
          (c.createdAt.isBefore(range.end) || c.createdAt.isAtSameMomentAs(range.end))) {
        newClients++;
      }
    }

    return _PeriodStats(
      revenue: revenue,
      newOrders: newOrders,
      deliveredOrders: deliveredOrders,
      newClients: newClients,
    );
  }

  // Export CSV logic using standard system share
  Future<void> _exportCSV(List<OrderModel> orders) async {
    final buffer = StringBuffer();
    buffer.writeln('Order Date,Token Number,Customer Name,Items,Total Amount,Discount,Paid Amount,Status');
    for (final order in orders) {
      buffer.writeln(
        '${order.orderDate.toIso8601String().substring(0, 10)},'
        '${order.tokenNumber},'
        '"${order.customerName.replaceAll('"', '""')}",'
        '"${order.itemsSummary.replaceAll('"', '""')}",'
        '${order.totalAmount},'
        '${order.discount},'
        '${order.paidAmount},'
        '${order.status.name}'
      );
    }

    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/darzi_pro_report.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Darzi Pro Report Export');
    } catch (e) {
      await Share.share(buffer.toString(), subject: 'Darzi Pro Report Export');
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(reportPeriodProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final customersAsync = ref.watch(customersProvider);
    final shopAsync = ref.watch(currentShopProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shopName = shopAsync.value?['name'] as String? ?? 'SaifurRahman Tailors';
    final orders = ordersAsync.valueOrNull ?? [];
    final customers = customersAsync.valueOrNull ?? [];

    // Calculate active and previous date ranges
    final currentRange = _getDateRange(period);
    final prevRange = _getPrevDateRange(currentRange);

    // Compute stats dynamically
    final currentStats = _calculateStats(currentRange, orders, customers);
    final prevStats = _calculateStats(prevRange, orders, customers);

    // Format subtitle date string
    String dateSubtitle;
    if (period == ReportPeriod.today) {
      dateSubtitle = DateFormat('MMMM dd, yyyy').format(currentRange.start);
    } else if (period == ReportPeriod.thisMonth || period == ReportPeriod.lastMonth) {
      dateSubtitle = DateFormat('MMMM yyyy').format(currentRange.start);
    } else {
      dateSubtitle = '${DateFormat('MMM dd').format(currentRange.start)} - ${DateFormat('MMM dd, yyyy').format(currentRange.end)}';
    }

    // Dynamic trend calculations
    String revTrend = '—';
    if (prevStats.revenue > 0 && currentStats.revenue > 0) {
      final t = ((currentStats.revenue - prevStats.revenue) / prevStats.revenue) * 100;
      revTrend = '${t >= 0 ? '▲' : '▼'} ${t.abs().toStringAsFixed(0)}%';
    } else if (currentStats.revenue > 0) {
      revTrend = '▲ 100%';
    }

    String ordTrend = '—';
    if (prevStats.newOrders > 0 && currentStats.newOrders > 0) {
      final t = ((currentStats.newOrders - prevStats.newOrders) / prevStats.newOrders) * 100;
      ordTrend = '${t >= 0 ? '▲' : '▼'} ${t.abs().toStringAsFixed(0)}%';
    } else if (currentStats.newOrders > 0) {
      ordTrend = '▲ 100%';
    }

    String delTrend = '—';
    if (prevStats.deliveredOrders > 0 && currentStats.deliveredOrders > 0) {
      final t = ((currentStats.deliveredOrders - prevStats.deliveredOrders) / prevStats.deliveredOrders) * 100;
      delTrend = '${t >= 0 ? '▲' : '▼'} ${t.abs().toStringAsFixed(0)}%';
    } else if (currentStats.deliveredOrders > 0) {
      delTrend = '▲ 100%';
    }

    String cliTrend = '—';
    if (currentStats.newClients > 0) {
      final diff = currentStats.newClients - prevStats.newClients;
      cliTrend = '${diff >= 0 ? '▲' : '▼'} ${diff.abs()}';
    }

    // Chart Data calculations from dashboard stats provider
    final stats = statsAsync.valueOrNull;
    final weeklyRevenue = stats?.weeklyRevenue ?? [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final weekLabels = stats?.weekLabels ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    double peakVal = weeklyRevenue.isNotEmpty ? weeklyRevenue.reduce((a, b) => a > b ? a : b) : 0.0;
    int peakIndex = weeklyRevenue.indexOf(peakVal);
    final peakDayName = peakVal > 0 && peakIndex >= 0 && peakIndex < weekLabels.length ? weekLabels[peakIndex] : '—';

    // Dress type data calculation
    final filteredOrders = orders.where((o) =>
        (o.orderDate.isAfter(currentRange.start) || o.orderDate.isAtSameMomentAs(currentRange.start)) &&
        (o.orderDate.isBefore(currentRange.end) || o.orderDate.isAtSameMomentAs(currentRange.end))
    ).toList();

    Map<String, int> dressCounts = {};
    Map<String, double> dressRevenues = {};
    double maxDressRevenue = 0;

    for (final order in filteredOrders) {
      for (final item in order.items) {
        final type = item.dressType.trim();
        if (type.isEmpty) continue;
        dressCounts[type] = (dressCounts[type] ?? 0) + item.quantity;
        dressRevenues[type] = (dressRevenues[type] ?? 0.0) + item.total;
      }
    }

    final sortedDressTypes = dressRevenues.keys.toList()
      ..sort((a, b) => dressRevenues[b]!.compareTo(dressRevenues[a]!));

    if (dressRevenues.isNotEmpty) {
      final highest = dressRevenues[sortedDressTypes.first]!;
      if (highest > 0) maxDressRevenue = highest;
    }

    List<_DressTypeAgg> dressAggList = [];
    for (final type in sortedDressTypes) {
      final count = dressCounts[type] ?? 0;
      final rev = dressRevenues[type] ?? 0.0;
      final percent = maxDressRevenue > 0 ? (rev / maxDressRevenue) : 0.0;
      dressAggList.add(_DressTypeAgg(
        name: type,
        count: count,
        revenue: rev,
        percent: percent,
      ));
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

    // KPI Cards Build
    final card1 = _KpiCard(
      iconBox: _buildIconBox(
        bg: isDark ? const Color(0x1AF5A623) : AppColors.lightAccentBg,
        border: isDark ? const Color(0x33F5A623) : AppColors.lightAccentBorder,
        icon: Icons.payments_rounded,
        iconColor: isDark ? const Color(0xFFF5A623) : AppColors.lightAccent,
      ),
      trendBadge: _buildTrendBadge(revTrend, isDark ? const Color(0x1A10CBA0) : AppColors.lightTealBg, isDark ? const Color(0xFF10CBA0) : AppColors.lightTeal),
      value: currentStats.revenue,
      label: 'REVENUE',
      valueColor: isDark ? const Color(0xFFF5A623) : AppColors.lightAccent,
      bottomAccentGradient: const [Color(0xFFF5A623), Color(0xFFD97706)],
      formatValue: (v) => _formatK(v.toDouble()),
    );

    final card2 = _KpiCard(
      iconBox: _buildIconBox(
        bg: isDark ? const Color(0x1A5B72F5) : AppColors.lightBlueBg,
        border: isDark ? const Color(0x335B72F5) : AppColors.lightBlueBorder,
        icon: Icons.receipt_long_rounded,
        iconColor: isDark ? const Color(0xFF5B72F5) : AppColors.lightBlue,
      ),
      trendBadge: _buildTrendBadge(ordTrend, isDark ? const Color(0x1A10CBA0) : AppColors.lightTealBg, isDark ? const Color(0xFF10CBA0) : AppColors.lightTeal),
      value: currentStats.newOrders,
      label: 'NEW ORDERS',
      valueColor: isDark ? const Color(0xFF5B72F5) : AppColors.lightBlue,
      bottomAccentColor: const Color(0xFF5B72F5),
      formatValue: (v) => v.toInt().toString(),
    );

    final card3 = _KpiCard(
      iconBox: _buildIconBox(
        bg: isDark ? const Color(0x1A10CBA0) : AppColors.lightTealBg,
        border: isDark ? const Color(0x3310CBA0) : AppColors.lightTealBorder,
        icon: Icons.check_circle_rounded,
        iconColor: isDark ? const Color(0xFF10CBA0) : AppColors.lightTeal,
      ),
      trendBadge: _buildTrendBadge(delTrend, isDark ? const Color(0x1A10CBA0) : AppColors.lightTealBg, isDark ? const Color(0xFF10CBA0) : AppColors.lightTeal),
      value: currentStats.deliveredOrders,
      label: 'DELIVERED',
      valueColor: isDark ? const Color(0xFF10CBA0) : AppColors.lightTeal,
      bottomAccentColor: const Color(0xFF10CBA0),
      formatValue: (v) => v.toInt().toString(),
    );

    final card4 = _KpiCard(
      iconBox: _buildIconBox(
        bg: isDark ? const Color(0x1A9B5CF5) : AppColors.lightPurpleBg,
        border: isDark ? const Color(0x339B5CF5) : AppColors.lightPurpleBorder,
        icon: Icons.people_rounded,
        iconColor: isDark ? const Color(0xFF9B5CF5) : AppColors.lightPurple,
      ),
      trendBadge: _buildTrendBadge(cliTrend, isDark ? const Color(0x1A9B5CF5) : AppColors.lightPurpleBg, isDark ? const Color(0xFF9B5CF5) : AppColors.lightPurple),
      value: currentStats.newClients,
      label: 'NEW CLIENTS',
      valueColor: isDark ? const Color(0xFF9B5CF5) : AppColors.lightPurple,
      bottomAccentColor: const Color(0xFF9B5CF5),
      formatValue: (v) => v.toInt().toString(),
    );

    // X-axis spots preparation
    final spots = List.generate(
      weeklyRevenue.length,
      (i) => FlSpot(i.toDouble(), weeklyRevenue[i]),
    );

    final lineChartBarData = LineChartBarData(
      spots: spots,
      isCurved: true,
      color: const Color(0xFFF5A623),
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF5A623).withValues(alpha: 0.25),
            const Color(0xFFF5A623).withValues(alpha: 0.0),
          ],
        ),
      ),
    );

    // Returned as simple background container to avoid nested Scaffold issues (such as hiding bottom navigation bar)
    return Container(
      color: isDark ? const Color(0xFF070D1A) : context.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // PART 1 — HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ANALYTICS & INSIGHTS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.text2,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reports',
                        style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: context.text1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateSubtitle · $shopName',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: context.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _exportCSV(filteredOrders);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59F5A623),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.download_rounded,
                          color: Color(0xFF1A0A00),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Export',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF1A0A00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // PART 2 — PERIOD FILTER CHIPS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip(
                    label: 'Today',
                    isActive: period == ReportPeriod.today,
                    onTap: () => ref.read(reportPeriodProvider.notifier).state = ReportPeriod.today,
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodChip(
                    label: 'This Month',
                    isActive: period == ReportPeriod.thisMonth,
                    onTap: () => ref.read(reportPeriodProvider.notifier).state = ReportPeriod.thisMonth,
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodChip(
                    label: 'Last Month',
                    isActive: period == ReportPeriod.lastMonth,
                    onTap: () => ref.read(reportPeriodProvider.notifier).state = ReportPeriod.lastMonth,
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodChip(
                    label: 'Custom',
                    isActive: period == ReportPeriod.custom,
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDateRange: _customDateRange,
                        builder: (context, child) {
                          final pickerIsDark = Theme.of(context).brightness == Brightness.dark;
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: pickerIsDark
                                  ? const ColorScheme.dark(
                                      primary: Color(0xFFF5A623),
                                      onPrimary: Color(0xFF1A0A00),
                                      surface: Color(0xFF070D1A),
                                      onSurface: Color(0xFFEDF4FF),
                                    )
                                  : const ColorScheme.light(
                                      primary: Color(0xFFD97706),
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Color(0xFF0A0F1C),
                                    ),
                              dialogTheme: DialogThemeData(
                                backgroundColor: pickerIsDark ? const Color(0xFF070D1A) : Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _customDateRange = picked;
                        });
                        ref.read(reportPeriodProvider.notifier).state = ReportPeriod.custom;
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

             // PART 3 — KPI GRID
            isDesktop
                ? SizedBox(
                    height: 125,
                    child: Row(
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 12),
                        Expanded(child: card2),
                        const SizedBox(width: 12),
                        Expanded(child: card3),
                        const SizedBox(width: 12),
                        Expanded(child: card4),
                      ],
                    ),
                  )
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [card1, card2, card3, card4],
                  ),
            const SizedBox(height: 20),

            // PART 4 — REVENUE TREND CHART
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Revenue Trend',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.text1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Last 7 days',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: context.text2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x1AF5A623) : context.accentBg,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: isDark ? const Color(0x33F5A623) : AppColors.lightAccentBorder, width: 1),
                          ),
                          child: Text(
                            '+118% peak $peakDayName',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF5A623) : context.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 140,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: peakVal > 0 ? peakVal / 3 : 1.0,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: isDark ? const Color(0x08FFFFFF) : context.border,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= weekLabels.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final label = weekLabels[idx];
                                  final isActive = idx == peakIndex;
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 6,
                                    child: Text(
                                      label,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                        color: isActive ? const Color(0xFFF5A623) : context.text2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: peakVal > 0 ? peakVal * 1.2 : 10.0,
                          lineTouchData: LineTouchData(
                            enabled: true,
                            handleBuiltInTouches: false,
                            getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                              return spotIndexes.map((index) {
                                return TouchedSpotIndicatorData(
                                  const FlLine(color: Colors.transparent),
                                  FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        color: const Color(0xFFF5A623),
                                        radius: 4,
                                        strokeWidth: 4,
                                        strokeColor: const Color(0xFFF5A623).withValues(alpha: 0.3),
                                      );
                                    },
                                  ),
                                );
                              }).toList();
                            },
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (spot) => Colors.transparent,
                              tooltipPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              tooltipMargin: 2,
                              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    '+118%',
                                    GoogleFonts.jetBrainsMono(
                                      color: const Color(0xFFF5A623),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          showingTooltipIndicators: [
                            ShowingTooltipIndicators([
                              LineBarSpot(
                                lineChartBarData,
                                0,
                                lineChartBarData.spots[peakIndex],
                              ),
                            ]),
                          ],
                          lineBarsData: [lineChartBarData],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // PART 5 — TOP DRESS TYPES TABLE
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Top Dress Types',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.text1,
                        ),
                      ),
                      Text(
                        'This Month',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(dressAggList.length, (index) {
                    final item = dressAggList[index];
                    final isLast = index == dressAggList.length - 1;

                    // Pick Gradient based on Rank
                    List<Color> gradientColors;
                    switch (index + 1) {
                      case 1:
                        gradientColors = const [Color(0xFFF5A623), Color(0xFFD97706)];
                        break;
                      case 2:
                        gradientColors = const [Color(0xFF9B5CF5), Color(0xFF7C3AED)];
                        break;
                      case 3:
                        gradientColors = const [Color(0xFF10CBA0), Color(0xFF059669)];
                        break;
                      case 4:
                        gradientColors = const [Color(0xFF5B72F5), Color(0xFF3B4ED8)];
                        break;
                      default:
                        gradientColors = const [Color(0xFFEC4899), Color(0xFFBE185D)];
                        break;
                    }

                    return Column(
                      children: [
                        _DressTypeRow(
                          rank: index + 1,
                          name: item.name,
                          percent: item.percent,
                          revenue: item.revenue,
                          gradientColors: gradientColors,
                        ),
                        if (!isLast)
                          Container(
                            height: 1,
                            color: isDark ? const Color(0x08FFFFFF) : context.border,
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Icon box generator for KPIs
  Widget _buildIconBox({
    required Color bg,
    required Color border,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border, width: 1),
      ),
      child: Center(
        child: Icon(
          icon,
          color: iconColor,
          size: 18,
        ),
      ),
    );
  }

  // Trend Badge generator for KPIs
  Widget _buildTrendBadge(String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // Period Selector Chip Build helper
  Widget _buildPeriodChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0x1AF5A623) : context.accentBg)
              : (isDark ? const Color(0x08FFFFFF) : context.surface2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? (isDark ? const Color(0x59F5A623) : AppColors.lightAccentBorder)
                : context.border,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? (isDark ? const Color(0xFFF5A623) : context.accent) : context.text2,
          ),
        ),
      ),
    );
  }
}

// ── KPI Card Component with Hover state & Tween animation ──────────────
class _KpiCard extends StatefulWidget {
  final Widget iconBox;
  final Widget? trendBadge;
  final num value;
  final String label;
  final Color valueColor;
  final List<Color>? bottomAccentGradient;
  final Color? bottomAccentColor;
  final String Function(num) formatValue;

  const _KpiCard({
    required this.iconBox,
    this.trendBadge,
    required this.value,
    required this.label,
    required this.valueColor,
    this.bottomAccentGradient,
    this.bottomAccentColor,
    required this.formatValue,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bottomDecoration = widget.bottomAccentGradient != null
        ? BoxDecoration(
            gradient: LinearGradient(colors: widget.bottomAccentGradient!),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          )
        : BoxDecoration(
            color: widget.bottomAccentColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, _isHovered ? -2.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark ? const Color(0x0FFFFFFF) : context.surfaceHover)
              : (isDark ? const Color(0x09FFFFFF) : context.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0x12FFFFFF) : context.border,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Top rim
            Positioned(
              top: 0,
              left: 1,
              right: 1,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x1AFFFFFF) : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
            ),
            // Bottom accent
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2.5,
                decoration: bottomDecoration,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 12,
                vertical: isDesktop ? 14 : 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      widget.iconBox,
                      if (widget.trendBadge != null) widget.trendBadge!,
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: widget.value.toDouble()),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, val, child) {
                          return Text(
                            widget.formatValue(val),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: isDesktop ? 28 : 20,
                              fontWeight: FontWeight.w900,
                              color: widget.valueColor,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: context.text2,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
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

// ── Dress Type Row Component with Staggered entry animation ───────────
class _DressTypeRow extends StatefulWidget {
  final int rank;
  final String name;
  final double percent;
  final double revenue;
  final List<Color> gradientColors;

  const _DressTypeRow({
    required this.rank,
    required this.name,
    required this.percent,
    required this.revenue,
    required this.gradientColors,
  });

  @override
  State<_DressTypeRow> createState() => _DressTypeRowState();
}

class _DressTypeRowState extends State<_DressTypeRow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.percent).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Stagger delay: 100ms per row rank
    Future.delayed(Duration(milliseconds: (widget.rank - 1) * 100), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(_DressTypeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.percent,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 16,
            child: Text(
              widget.rank.toString().padLeft(2, '0'),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.text2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            flex: 1,
            child: Text(
              widget.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.text1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Progress bar
          Expanded(
            flex: 2,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x0FFFFFFF) : context.surface2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth * _animation.value;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: width,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // Amount
          SizedBox(
            width: 80,
            child: Text(
              formatMoney(widget.revenue),
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.gradientColors.first,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private Helper Models ────────────────────────────────────────────────
class _PeriodStats {
  final double revenue;
  final int newOrders;
  final int deliveredOrders;
  final int newClients;

  const _PeriodStats({
    required this.revenue,
    required this.newOrders,
    required this.deliveredOrders,
    required this.newClients,
  });
}

class _DressTypeAgg {
  final String name;
  final int count;
  final double revenue;
  final double percent;

  const _DressTypeAgg({
    required this.name,
    required this.count,
    required this.revenue,
    required this.percent,
  });
}
