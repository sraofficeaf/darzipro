import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_enums.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/models.dart';
import 'new_order_modal.dart';

// ── COLOR CONSTANTS (CACHED) ────────────────────────────────────────────────
class _OrdersColors {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const faint = Color(0xFFAAB2BF);
  static const line = Color(0xFFE8EAF0);
  static const paper = Color(0xFFF5F6F8);
  static const white = Colors.white;

  static const dark = Color(0xFF151922);
  static const darkCard = Color(0xFF181D27);
  static const darkLine = Color(0xFF333946);

  static const gold = Color(0xFFE9A227);
  static const gold2 = Color(0xFFFFC65A);
  static const goldBg = Color(0xFFFFF6E5);
  static const goldLine = Color(0xFFF3DDA8);

  static const green = Color(0xFF18B887);
  static const greenBg = Color(0xFFEAFBF5);

  static const rose = Color(0xFFEF5261);
  static const roseBg = Color(0xFFFFF0F2);
  static const roseLine = Color(0xFFFFD9DE);

  static const blue = Color(0xFF5478E8);
  static const blueBg = Color(0xFFEEF2FF);

  static const violet = Color(0xFF8764E8);
  static const violetBg = Color(0xFFF3F0FF);
}

// ── TYPOGRAPHY CONSTANTS (CACHED) ───────────────────────────────────────────
class _OrdersStyles {
  static final kicker = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    color: _OrdersColors.muted,
    letterSpacing: 1.6,
  );

  static final title = GoogleFonts.manrope(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: _OrdersColors.ink,
    letterSpacing: -0.8,
  );

  static final subtitle = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: _OrdersColors.muted,
  );

  static final chipLabel = GoogleFonts.manrope(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
  );

  static final chipCount = GoogleFonts.ibmPlexMono(
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
  );

  static final tokenText = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: const Color(0xFFB45309),
  );

  static final customerName = GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: _OrdersColors.ink,
  );

  static final itemsSummary = GoogleFonts.dmSans(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: _OrdersColors.muted,
  );

  static final statusTag = GoogleFonts.dmSans(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );

  static final totalAmount = GoogleFonts.ibmPlexMono(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static final dueText = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );

  static final dateText = GoogleFonts.dmSans(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: _OrdersColors.faint,
  );
}

// ── SINGLE-PASS STATS AGGREGATOR ────────────────────────────────────────────
class _OrderStats {
  final int allCount;
  final int pendingCount;
  final int cuttingCount;
  final int stitchingCount;
  final int readyCount;
  final int deliveredCount;
  final int urgentCount;

  const _OrderStats({
    required this.allCount,
    required this.pendingCount,
    required this.cuttingCount,
    required this.stitchingCount,
    required this.readyCount,
    required this.deliveredCount,
    required this.urgentCount,
  });

  factory _OrderStats.fromList(List<OrderModel> orders, DateTime today) {
    int pending = 0;
    int cutting = 0;
    int stitching = 0;
    int ready = 0;
    int delivered = 0;
    int urgent = 0;

    for (final o in orders) {
      final isOverdue = o.deliveryDate != null &&
          o.deliveryDate!.isBefore(today) &&
          o.status != OrderStatus.delivered &&
          o.status != OrderStatus.cancelled;

      if (o.isUrgent || isOverdue) {
        urgent++;
      }

      switch (o.status) {
        case OrderStatus.pending:
          pending++;
          break;
        case OrderStatus.cutting:
          cutting++;
          break;
        case OrderStatus.stitching:
          stitching++;
          break;
        case OrderStatus.ready:
          ready++;
          break;
        case OrderStatus.delivered:
          delivered++;
          break;
        default:
          break;
      }
    }

    return _OrderStats(
      allCount: orders.length,
      pendingCount: pending,
      cuttingCount: cutting,
      stitchingCount: stitching,
      readyCount: ready,
      deliveredCount: delivered,
      urgentCount: urgent,
    );
  }
}

// ── ORDERS SCREEN ───────────────────────────────────────────────────────────
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  Future<void> _exportOrdersCSV(List<OrderModel> orders) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to export')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Token,Customer Name,Items,Status,Total,Advance,Remaining,Delivery Date');
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final o in orders) {
      final deliveryStr = o.deliveryDate != null ? dateFormat.format(o.deliveryDate!) : '';
      buffer.writeln(
        '"${o.tokenNumber}",'
        '"${o.customerName.replaceAll('"', '""')}",'
        '"${o.itemsSummary.replaceAll('"', '""')}",'
        '"${o.status.name}",'
        '${o.totalAmount},'
        '${o.paidAmount},'
        '${o.remainingAmount},'
        '"$deliveryStr"',
      );
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: 'darzi_pro_orders.csv')],
        text: 'Darzi Pro Orders Export',
      );
    } catch (_) {
      await Share.share(buffer.toString(), subject: 'Darzi Pro Orders Export');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allOrdersAsync = ref.watch(ordersProvider);
    final filteredOrdersAsync = ref.watch(filteredOrdersProvider);
    final currentStatusFilter = ref.watch(orderStatusFilterProvider);

    final allOrders = allOrdersAsync.valueOrNull ?? const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final stats = _OrderStats.fromList(allOrders, today);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _OrdersColors.dark : _OrdersColors.paper;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _OrdersColors.gold,
          backgroundColor: isDark ? _OrdersColors.darkCard : _OrdersColors.white,
          onRefresh: () async => ref.invalidate(ordersProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 1. SCREEN HEADER SLIVER
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kicker
                        Text('ORDER MANAGEMENT', style: _OrdersStyles.kicker),
                        const SizedBox(height: 4),

                        // Title & Actions Row
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;

                            final headerLeft = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Orders',
                                  style: _OrdersStyles.title.copyWith(
                                    color: isDark ? Colors.white : _OrdersColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${filteredOrdersAsync.valueOrNull?.length ?? stats.allCount} active',
                                      style: _OrdersStyles.subtitle.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white70 : _OrdersColors.ink,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('·', style: _OrdersStyles.subtitle),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${stats.urgentCount} urgent today',
                                      style: _OrdersStyles.subtitle.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: _OrdersColors.rose,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );

                            final headerButtons = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Export Button
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final listToExport =
                                        filteredOrdersAsync.valueOrNull ?? allOrders;
                                    _exportOrdersCSV(listToExport);
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text('Export'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : _OrdersColors.ink,
                                    backgroundColor:
                                        isDark ? _OrdersColors.darkCard : _OrdersColors.white,
                                    side: BorderSide(
                                      color: isDark ? _OrdersColors.darkLine : _OrdersColors.line,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    textStyle: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // New Order Button
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_OrdersColors.gold2, _OrdersColors.gold],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x38E9A227),
                                        blurRadius: 16,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => NewOrderModal.show(context),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              '＋',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF211500),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'New Order',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF211500),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  headerLeft,
                                  const SizedBox(height: 14),
                                  headerButtons,
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                headerLeft,
                                headerButtons,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // 2. FILTER CHIPS ROW
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _FilterChip(
                                label: 'All',
                                count: stats.allCount,
                                isActive: currentStatusFilter == null,
                                onTap: () =>
                                    ref.read(orderStatusFilterProvider.notifier).state = null,
                              ),
                              _FilterChip(
                                label: '⏳ Pending',
                                count: stats.pendingCount,
                                isActive: currentStatusFilter == OrderStatus.pending,
                                onTap: () => ref.read(orderStatusFilterProvider.notifier).state =
                                    OrderStatus.pending,
                              ),
                              _FilterChip(
                                label: '✂️ Cutting',
                                count: stats.cuttingCount,
                                isActive: currentStatusFilter == OrderStatus.cutting,
                                onTap: () => ref.read(orderStatusFilterProvider.notifier).state =
                                    OrderStatus.cutting,
                              ),
                              _FilterChip(
                                label: '🧵 Stitching',
                                count: stats.stitchingCount,
                                isActive: currentStatusFilter == OrderStatus.stitching,
                                onTap: () => ref.read(orderStatusFilterProvider.notifier).state =
                                    OrderStatus.stitching,
                              ),
                              _FilterChip(
                                label: '✅ Ready',
                                count: stats.readyCount,
                                isActive: currentStatusFilter == OrderStatus.ready,
                                onTap: () => ref.read(orderStatusFilterProvider.notifier).state =
                                    OrderStatus.ready,
                              ),
                              _FilterChip(
                                label: '📦 Delivered',
                                count: stats.deliveredCount,
                                isActive: currentStatusFilter == OrderStatus.delivered,
                                onTap: () => ref.read(orderStatusFilterProvider.notifier).state =
                                    OrderStatus.delivered,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. VIRTUALIZED ORDERS LIST
              filteredOrdersAsync.when(
                data: (orders) {
                  if (orders.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('📋', style: TextStyle(fontSize: 52)),
                              const SizedBox(height: 14),
                              Text(
                                'No orders found',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : _OrdersColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try a different filter or create a new order.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12.5,
                                  color: _OrdersColors.muted,
                                ),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () => NewOrderModal.show(context),
                                icon: const Text('＋', style: TextStyle(fontSize: 16)),
                                label: const Text('New Order'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _OrdersColors.gold,
                                  side: const BorderSide(color: _OrdersColors.gold),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final order = orders[index];
                          final isOverdue = order.deliveryDate != null &&
                              order.deliveryDate!.isBefore(today) &&
                              order.status != OrderStatus.delivered &&
                              order.status != OrderStatus.cancelled;

                          return RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OrderCard(
                                order: order,
                                isOverdue: isOverdue,
                                isDark: isDark,
                              ),
                            ),
                          );
                        },
                        childCount: orders.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: _ListSkeleton(count: 4),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Error loading orders: $err',
                        style: const TextStyle(color: _OrdersColors.rose),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Spacer
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FILTER CHIP WIDGET ───────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isActive
        ? (isDark ? _OrdersColors.gold : _OrdersColors.dark)
        : (isDark ? _OrdersColors.darkCard : _OrdersColors.white);
    final textColor = isActive
        ? (isDark ? const Color(0xFF211500) : Colors.white)
        : (isDark ? Colors.white70 : _OrdersColors.muted);
    final borderColor = isActive
        ? Colors.transparent
        : (isDark ? _OrdersColors.darkLine : _OrdersColors.line);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(11),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.circular(11),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: (isDark ? _OrdersColors.gold : _OrdersColors.dark)
                            .withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: _OrdersStyles.chipLabel.copyWith(color: textColor),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: _OrdersStyles.chipCount.copyWith(
                    color: textColor.withValues(alpha: 0.7),
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

// ── ORDER CARD (CPU OPTIMIZED) ──────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isOverdue;
  final bool isDark;

  const _OrderCard({
    required this.order,
    required this.isOverdue,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM');
    final formattedDate = order.deliveryDate != null
        ? '${dateFormat.format(order.orderDate)} · Due ${dateFormat.format(order.deliveryDate!)}'
        : dateFormat.format(order.orderDate);

    final cardBg = isOverdue
        ? (isDark
            ? const Color(0xFF241518)
            : const Color(0xFFFFF9FA))
        : (isDark ? _OrdersColors.darkCard : _OrdersColors.white);

    final borderSideColor = isOverdue
        ? _OrdersColors.roseLine
        : (isDark ? _OrdersColors.darkLine : _OrdersColors.line);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/orders/${order.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderSideColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Left Accent Line for Overdue
              if (isOverdue)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_OrdersColors.rose, Color(0xFFB91C1C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

              // CARD CONTENT (RESPONSIVE LAYOUT)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 580;

                  if (isMobile) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Token & Customer Name & Status & Token Card Action
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTokenBadge(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.customerName,
                                      style: _OrdersStyles.customerName.copyWith(
                                        color: isDark ? Colors.white : _OrdersColors.ink,
                                      ),
                                    ),
                                    if (order.itemsSummary.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        order.itemsSummary,
                                        style: _OrdersStyles.itemsSummary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildTokenCardAction(context, isDark: isDark),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Tags
                          Row(
                            children: [
                              _buildStatusTag(order.status),
                              if (isOverdue) ...[
                                const SizedBox(width: 6),
                                _buildOverdueTag(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Bottom Row (Divider + Financials)
                          Container(
                            padding: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: isDark ? _OrdersColors.darkLine : _OrdersColors.line,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formattedDate,
                                  style: _OrdersStyles.dateText,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Rs ${order.totalAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                      style: _OrdersStyles.totalAmount.copyWith(
                                        color: isDark ? Colors.white : _OrdersColors.ink,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildDueBadge(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Desktop Row Layout
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildTokenBadge(),
                        const SizedBox(width: 14),

                        // Center: Customer Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerName,
                                style: _OrdersStyles.customerName.copyWith(
                                  color: isDark ? Colors.white : _OrdersColors.ink,
                                ),
                              ),
                              if (order.itemsSummary.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  order.itemsSummary,
                                  style: _OrdersStyles.itemsSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildStatusTag(order.status),
                                  if (isOverdue) ...[
                                    const SizedBox(width: 6),
                                    _buildOverdueTag(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Right: Financials & Date
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs ${order.totalAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                              style: _OrdersStyles.totalAmount.copyWith(
                                color: isDark ? Colors.white : _OrdersColors.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildDueBadge(),
                            const SizedBox(height: 5),
                            Text(
                              formattedDate,
                              style: _OrdersStyles.dateText,
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Token Card Action
                        _buildTokenCardAction(context, isDark: isDark),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _OrdersColors.goldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _OrdersColors.goldLine, width: 1),
      ),
      child: Text(
        order.tokenNumber,
        style: _OrdersStyles.tokenText,
      ),
    );
  }

  Widget _buildTokenCardAction(BuildContext context, {required bool isDark}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/token-card/${order.id}');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF241C0F) : _OrdersColors.goldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0x66E9A227) : _OrdersColors.goldLine,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪪', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                'Token Card',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag(OrderStatus status) {
    Color bg;
    Color color;
    String label;

    switch (status) {
      case OrderStatus.pending:
        bg = _OrdersColors.goldBg;
        color = const Color(0xFFB45309);
        label = 'PENDING';
        break;
      case OrderStatus.cutting:
        bg = _OrdersColors.violetBg;
        color = _OrdersColors.violet;
        label = 'CUTTING';
        break;
      case OrderStatus.stitching:
        bg = _OrdersColors.blueBg;
        color = _OrdersColors.blue;
        label = 'STITCHING';
        break;
      case OrderStatus.ready:
        bg = _OrdersColors.greenBg;
        color = _OrdersColors.green;
        label = 'READY';
        break;
      case OrderStatus.delivered:
        bg = isDark ? _OrdersColors.darkLine : const Color(0xFFEFEFEF);
        color = _OrdersColors.muted;
        label = 'DELIVERED';
        break;
      case OrderStatus.cancelled:
        bg = _OrdersColors.roseBg;
        color = _OrdersColors.rose;
        label = 'CANCELLED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: _OrdersStyles.statusTag.copyWith(color: color),
      ),
    );
  }

  Widget _buildOverdueTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: _OrdersColors.roseBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'OVERDUE',
        style: _OrdersStyles.statusTag.copyWith(color: _OrdersColors.rose),
      ),
    );
  }

  Widget _buildDueBadge() {
    final isPaid = order.isFullyPaid || order.remainingAmount <= 0;
    final text = isPaid ? 'Paid ✓' : 'Due ${order.remainingAmount.toInt()}';
    final color = isPaid ? _OrdersColors.green : _OrdersColors.rose;

    return Text(
      text,
      style: _OrdersStyles.dueText.copyWith(color: color),
    );
  }
}

// ── SKELETON LOADER ─────────────────────────────────────────────────────────
class _ListSkeleton extends StatelessWidget {
  final int count;
  const _ListSkeleton({this.count = 3});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF1F2430) : const Color(0xFFE5E7EB);

    return Column(
      children: List.generate(
        count,
        (i) => Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
