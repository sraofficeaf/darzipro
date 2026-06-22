import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/models.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      floatingActionButton: SizedBox(
        width: 52,
        height: 52,
        child: GoldButton(
          borderRadius: 26,
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push('/orders/new');
          },
          child: const Icon(
            Icons.add_rounded,
            size: 26,
            color: Color(0xFF1A0F00),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orders',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: t1,
                      ),
                    ),
                    Text(
                      ordersAsync.when(
                        data: (list) {
                          final urgentCount = list.where((o) => o.isUrgent).length;
                          return '${list.length} active · $urgentCount urgent today';
                        },
                        loading: () => 'Loading orders...',
                        error: (_, _) => 'Error loading orders',
                      ),
                      style: GoogleFonts.inter(fontSize: 12, color: t2),
                    ),
                  ],
                ),
              ),
              GoldButton(
                height: 46,
                borderRadius: 16,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/orders/new');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_rounded, size: 18, color: Color(0xFF1A0F00)),
                      SizedBox(width: 4),
                      Text('NEW ORDER', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A0F00))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status chips (horizontal scroll)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: 'All (${ref.watch(ordersProvider).value?.length ?? 0})',
                  isActive: statusFilter == null,
                  onTap: () => _onFilter(null),
                  isDark: isDark,
                  text2: t2,
                ),
                _buildFilterChip(
                  label: '⏳ Pending',
                  isActive: statusFilter == OrderStatus.pending,
                  onTap: () => _onFilter(OrderStatus.pending),
                  isDark: isDark,
                  text2: t2,
                ),
                _buildFilterChip(
                  label: '✂ Cutting',
                  isActive: statusFilter == OrderStatus.cutting,
                  onTap: () => _onFilter(OrderStatus.cutting),
                  isDark: isDark,
                  text2: t2,
                ),
                _buildFilterChip(
                  label: '🧵 Stitching',
                  isActive: statusFilter == OrderStatus.stitching,
                  onTap: () => _onFilter(OrderStatus.stitching),
                  isDark: isDark,
                  text2: t2,
                ),
                _buildFilterChip(
                  label: '✅ Ready',
                  isActive: statusFilter == OrderStatus.ready,
                  onTap: () => _onFilter(OrderStatus.ready),
                  isDark: isDark,
                  text2: t2,
                ),
                _buildFilterChip(
                  label: '📦 Delivered',
                  isActive: statusFilter == OrderStatus.delivered,
                  onTap: () => _onFilter(OrderStatus.delivered),
                  isDark: isDark,
                  text2: t2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Order cards
          ordersAsync.when(
            data: (list) {
              if (_isLoading) return const ListSkeleton(count: 3);
              if (list.isEmpty) {
                return const EmptyState(emoji: '📋', title: 'No Orders Found');
              }
              return Column(
                children: list.map((o) => _OrderCard(order: o)).toList(),
              );
            },
            loading: () => const ListSkeleton(count: 3),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Error: $err', style: const TextStyle(color: AppColors.red)),
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
    required Color text2,
  }) {
    final activeGradient = const LinearGradient(
      colors: [Color(0xFFF5A623), Color(0xFFD4791A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final bg = isDark ? const Color(0x09FFFFFF) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A);

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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      margin: const EdgeInsets.only(right: 8),
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

class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isOverdue = order.deliveryDate != null && 
        order.deliveryDate!.isBefore(today) && 
        order.status != OrderStatus.delivered;

    final bg = isDark ? const Color(0x09FFFFFF) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A);

    BoxDecoration decoration;
    if (order.isUrgent) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x0AFF3A58), Color(0x00FF3A58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF3A58).withValues(alpha: 0.2),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1FFF3A58),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    Widget container = Container(
      decoration: decoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.tokenNumber,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.accent : AppColors.accentL,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.customerName,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: t1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.itemsSummary,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: t2,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1, 
            color: order.isUrgent 
                ? const Color(0xFFFF3A58).withValues(alpha: 0.15) 
                : border,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                order.deliveryDate != null
                    ? '${order.isUrgent ? '⚠️ ' : '📅 '}${formatDateShort(order.deliveryDate!)}'
                    : '📅 No date',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isOverdue 
                      ? const Color(0xFFFF3A58) 
                      : (order.isUrgent ? AppColors.red : t2),
                  fontWeight: (isOverdue || order.isUrgent) ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(order.totalAmount),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: t1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.isFullyPaid
                        ? 'Fully Paid ✓'
                        : '${formatMoney(order.remainingAmount)} left',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: order.isFullyPaid ? AppColors.teal : AppColors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    if (isDark) {
      container = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: container,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/orders/${order.id}');
        },
        child: Stack(
          children: [
            container,
            if (order.isUrgent)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3A58),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
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
