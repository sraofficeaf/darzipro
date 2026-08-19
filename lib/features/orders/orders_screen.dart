import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/models.dart';
import 'new_order_modal.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _isLoading = false;

  void _onFilter(OrderStatus? status) {
    setState(() => _isLoading = true);
    ref.read(orderStatusFilterProvider.notifier).state = status;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(filteredOrdersProvider);
    final statusFilter = ref.watch(orderStatusFilterProvider);
    final allOrders = ref.watch(ordersProvider).valueOrNull ?? [];
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final text2 = isDark ? const Color(0xFF5A7090) : const Color(0xFF4A5568);
    final text3 = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);
    final accent = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: accent,
          backgroundColor: isDark ? const Color(0xFF0B1525) : const Color(0xFFFFFFFF),
          onRefresh: () async {
            ref.invalidate(ordersProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              // HEADER ROW
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORDER MANAGEMENT',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: text3,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Orders',
                          style: GoogleFonts.outfit(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ordersAsync.when(
                            data: (list) {
                              final urgentCount = list.where((o) => o.isUrgent).length;
                              return '${list.length} active · $urgentCount urgent today';
                            },
                            loading: () => 'Loading orders...',
                            error: (_, _) => 'Error loading orders',
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _GoldButton(
                    label: '＋ New Order',
                    onPressed: () {
                      NewOrderModal.show(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // FILTER CHIPS
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip(
                      label: 'All (${allOrders.length})',
                      isActive: statusFilter == null,
                      onTap: () => _onFilter(null),
                    ),
                    _buildFilterChip(
                      label: '⏳ Pending',
                      isActive: statusFilter == OrderStatus.pending,
                      onTap: () => _onFilter(OrderStatus.pending),
                    ),
                    _buildFilterChip(
                      label: '✂️ Cutting',
                      isActive: statusFilter == OrderStatus.cutting,
                      onTap: () => _onFilter(OrderStatus.cutting),
                    ),
                    _buildFilterChip(
                      label: '🧵 Stitching',
                      isActive: statusFilter == OrderStatus.stitching,
                      onTap: () => _onFilter(OrderStatus.stitching),
                    ),
                    _buildFilterChip(
                      label: '✅ Ready',
                      isActive: statusFilter == OrderStatus.ready,
                      onTap: () => _onFilter(OrderStatus.ready),
                    ),
                    _buildFilterChip(
                      label: '📦 Delivered',
                      isActive: statusFilter == OrderStatus.delivered,
                      onTap: () => _onFilter(OrderStatus.delivered),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ORDERS LIST / CARDS
              ordersAsync.when(
                data: (list) {
                  if (_isLoading) {
                    return const _ListSkeleton(count: 3);
                  }
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '📋',
                              style: TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Orders Found',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: text1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _GoldButton(
                              label: '＋ Create First Order',
                              onPressed: () {
                                NewOrderModal.show(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: list.map((o) => _OrderCard(order: o)).toList(),
                  );
                },
                loading: () => const _ListSkeleton(count: 3),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: Color(0xFFFF3A58)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bg = isActive 
        ? (isDark ? const Color(0x1FF5A623) : const Color(0xFFFFF8EE))
        : (isDark ? const Color(0x08FFFFFF) : const Color(0xFFFFFFFF));
    final borderCol = isActive
        ? (isDark ? const Color(0x59F5A623) : const Color(0xFFD97706).withValues(alpha: 0.3))
        : (isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000));
    final textCol = isActive
        ? (isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706))
        : (isDark ? const Color(0xFF3D5470) : const Color(0xFF4A5568));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
              color: borderCol,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? null
                : (isDark ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))]),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: textCol,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isHovered = false;
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isOverdue = widget.order.deliveryDate != null &&
        widget.order.deliveryDate!.isBefore(today) &&
        widget.order.status != OrderStatus.delivered;

    final isUrgentOrLate = widget.order.isUrgent || isOverdue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final text2 = isDark ? const Color(0xFF4A6080) : const Color(0xFF4A5568);
    final text3 = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    // Decoration based on state
    BoxDecoration decoration;
    if (isDark) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x0AFFFFFF), Color(0x05FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgentOrLate
              ? const Color(0x33FF3A58)
              : const Color(0x12FFFFFF),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: isUrgentOrLate ? const Color(0xFFFEF2F2) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgentOrLate
              ? const Color(0xFFDC2626).withValues(alpha: 0.3)
              : const Color(0x1A000000),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _scale = 0.97),
          onTapCancel: () => setState(() => _scale = 1.0),
          onTapUp: (_) {
            setState(() => _scale = 1.0);
            HapticFeedback.lightImpact();
            context.push('/orders/${widget.order.id}');
          },
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(_isHovered ? 3 : 0, 0, 0),
              decoration: decoration,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // CARD BODY
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // LEFT: Token badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x1AF5A623) : const Color(0xFFFFF8EE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0x33F5A623) : const Color(0xFFD97706).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                             widget.order.tokenNumber,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // CENTER: Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.order.customerName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: text1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.order.itemsSummary,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: text2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildStatusPill(widget.order.status),
                                  if (isOverdue) ...[
                                    const SizedBox(width: 6),
                                    _buildOverduePill(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // RIGHT: Financials & Date
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatMoney(widget.order.totalAmount),
                              style: GoogleFonts.jetBrainsMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: text1,
                                ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.order.isFullyPaid
                                  ? 'Fully Paid ✓'
                                  : 'Rs ${widget.order.remainingAmount.toInt()} due',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: widget.order.isFullyPaid
                                    ? (isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669))
                                    : (isDark ? const Color(0xFFFF3A58) : const Color(0xFFDC2626)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.order.deliveryDate != null
                                  ? 'Due: ${formatDateShort(widget.order.deliveryDate!)}'
                                  : 'No Date',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: text3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // LEFT Accent Line on Hover
                  if (_isHovered)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isUrgentOrLate
                                ? (isDark
                                    ? [const Color(0xFFFF3A58), const Color(0xFFD91F45)]
                                    : [const Color(0xFFDC2626), const Color(0xFFB91C1C)])
                                : (isDark
                                    ? [const Color(0xFFF5A623), const Color(0xFFD97706)]
                                    : [const Color(0xFFD97706), const Color(0xFFB45309)]),
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(OrderStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color text;
    Color border;

    switch (status) {
      case OrderStatus.pending:
        bg = isDark ? const Color(0x1FF5A623) : const Color(0xFFFFF8EE);
        text = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
        border = isDark ? const Color(0x40F5A623) : const Color(0xFFD97706).withValues(alpha: 0.3);
        break;
      case OrderStatus.cutting:
        bg = isDark ? const Color(0x1F9B5CF5) : const Color(0xFFF5F3FF);
        text = isDark ? const Color(0xFF9B5CF5) : const Color(0xFF7C3AED);
        border = isDark ? const Color(0x409B5CF5) : const Color(0xFF7C3AED).withValues(alpha: 0.3);
        break;
      case OrderStatus.stitching:
        bg = isDark ? const Color(0x1F5B72F5) : const Color(0xFFEFF6FF);
        text = isDark ? const Color(0xFF5B72F5) : const Color(0xFF2563EB);
        border = isDark ? const Color(0x405B72F5) : const Color(0xFF2563EB).withValues(alpha: 0.3);
        break;
      case OrderStatus.ready:
        bg = isDark ? const Color(0x1F10CBA0) : const Color(0xFFECFDF5);
        text = isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669);
        border = isDark ? const Color(0x4010CBA0) : const Color(0xFF059669).withValues(alpha: 0.3);
        break;
      case OrderStatus.delivered:
      default:
        bg = isDark ? const Color(0x0FFFFFFF) : const Color(0xFFF8FAFF);
        text = isDark ? const Color(0xFF5A7090) : const Color(0xFF94A3B8);
        border = isDark ? const Color(0x1AFFFFFF) : const Color(0xFF94A3B8).withValues(alpha: 0.3);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOverduePill() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1FFF3A58) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0x40FF3A58) : const Color(0xFFDC2626).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        'OVERDUE',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFFF3A58) : const Color(0xFFDC2626),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// PREMIUM BUTTONS
class _GoldButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _GoldButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
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
                blurRadius: 20,
                offset: Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A0A00),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SKELETON LOADER
class _ListSkeleton extends StatelessWidget {
  final int count;
  const _ListSkeleton({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x05FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x0DFFFFFF)),
          ),
          child: Row(
            children: [
              const PulsingSkeleton(width: 48, height: 24, borderRadius: 6),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    PulsingSkeleton(width: 120, height: 14),
                    SizedBox(height: 6),
                    PulsingSkeleton(width: 80, height: 10),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  PulsingSkeleton(width: 60, height: 14),
                  SizedBox(height: 6),
                  PulsingSkeleton(width: 40, height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
