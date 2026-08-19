import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_enums.dart';
import '../../core/config/supabase_config.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/models.dart';
import 'widgets/add_payment_modal.dart';
import 'widgets/update_status_modal.dart';
import 'widgets/delivery_date_modal.dart';
import '../../shared/providers/supabase_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  void _pickImage(BuildContext context, WidgetRef ref, String orderId) async {
    final picker = ImagePicker();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0B1525) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('📷', style: TextStyle(fontSize: 20)),
                title: Text(
                  'Camera se photo lein',
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C),
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
                title: Text(
                  'Gallery se select karein',
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C),
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        ref.read(ordersProvider.notifier).addOrderImage(orderId, picked.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Design image add ho gayi!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFF10CBA0),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final text2 = isDark ? const Color(0xFF4A6080) : const Color(0xFF4A5568);
    final text3 = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);
    final accent = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leadingWidth: 56,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Center(
              child: _BackButton(
                onPressed: () => context.pop(),
              ),
            ),
          ),
          titleSpacing: 16,
          title: Text(
            'Order Detail',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: text1,
            ),
          ),
          actions: [
            ordersAsync.when(
              data: (orders) {
                final order = orders.where((o) => o.id == orderId).firstOrNull;
                if (order == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Center(
                    child: _OutlineButton(
                      label: '🪪 Card',
                      onPressed: () {
                        context.push('/token-card/${order.id}');
                      },
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
            ),
          ],
        ),
        body: ordersAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: accent)),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          data: (orders) {
            final order = orders.where((o) => o.id == orderId).firstOrNull;

            if (order == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔍', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      'Order Not Found',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: text1,
                      ),
                    ),
                  ],
                ),
              );
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final isOverdue = order.deliveryDate != null &&
                order.deliveryDate!.isBefore(today) &&
                order.status != OrderStatus.delivered;

            final cardBg = isDark ? const Color(0x08FFFFFF) : const Color(0xFFFFFFFF);
            final cardBorder = isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // CLIENT ROW CARD
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(color: cardBorder, width: 1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CustomerAvatar(name: order.customerName, size: 42, borderRadius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: text1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    context.push('/customers/${order.customerId}');
                                  },
                                  child: Text(
                                    'Client Details',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: text2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: text3,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    context.push('/measurements/${order.customerId}/${Uri.encodeComponent(order.customerName)}');
                                  },
                                  child: Text(
                                    'View Naap 📏',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildStatusPill(context, order.status),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // STATUS STEPPER CARD
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ORDER STATUS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: text3,
                              letterSpacing: 1.8,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => UpdateStatusModal.show(context, order: order),
                            child: Text(
                              'Tap to Update',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _StatusStepper(order: order),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // DATES ROW
                Row(
                  children: [
                    Expanded(
                      child: _DateCard(
                        label: 'Ordered',
                        value: formatDateShort(order.orderDate),
                        isOverdue: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => DeliveryDateModal.show(context, order: order),
                        child: _DateCard(
                          label: 'Delivery',
                          value: order.deliveryDate != null
                              ? formatDateShort(order.deliveryDate!)
                              : 'Not set',
                          isOverdue: isOverdue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ORDER ITEMS CARD
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x06FFFFFF) : const Color(0xFFFFFFFF),
                    border: Border.all(
                      color: isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                        child: Text(
                          'ORDER ITEMS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: text3,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      Divider(
                        color: isDark ? const Color(0x08FFFFFF) : const Color(0x1A000000),
                        height: 1,
                      ),
                      ...order.items.map(
                        (item) => Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.dressType} × ${item.quantity}',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: text1,
                                          ),
                                        ),
                                        if (item.clothDetails.isNotEmpty)
                                          Text(
                                            item.clothDetails,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: text2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatMoney(item.total),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: text1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              color: isDark ? const Color(0x08FFFFFF) : const Color(0x1A000000),
                              height: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // PAYMENT SUMMARY CARD
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF060E1E), Color(0xFF0D1E3A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: const Color(0x12FFFFFF), width: 1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYMENT SUMMARY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3D5470),
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MoneyRow(label: 'Total Amount', value: formatMoney(order.totalAmount)),
                      _MoneyRow(label: 'Advance Paid', value: formatMoney(order.paidAmount)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Outstanding',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF5A7090),
                            ),
                          ),
                          order.isFullyPaid
                              ? Text(
                                  'Fully Paid ✓',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF10CBA0),
                                  ),
                                )
                              : Text(
                                  formatMoney(order.remainingAmount),
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFF5A623),
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // DESIGN REFERENCE IMAGES
                Text(
                  'DESIGN REFERENCE IMAGES',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: text3,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(context, ref, order.id),
                        child: Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x05FFFFFF) : const Color(0xFFFFFFFF),
                            border: Border.all(
                              color: isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('📷', style: TextStyle(fontSize: 20)),
                                const SizedBox(height: 4),
                                Text(
                                  'Add Image',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (order.images.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              'No images added',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: text2,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      else
                        ...order.images.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final path = entry.value;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => _GalleryViewer(
                                    images: order.images,
                                    initialIndex: idx,
                                    onDelete: (index) {
                                      ref.read(ordersProvider.notifier).deleteOrderImage(order.id, order.images[index]);
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 90,
                              height: 90,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000),
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                path.startsWith('http') || path.startsWith('assets')
                                    ? path
                                    : '${SupabaseConfig.designImagesUrl}/$path',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ACTION BUTTONS GRID
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final shopPlan = ref.watch(shopPlanProvider).value;
                          final isLocked = shopPlan == 'mobile_only';
                          return _PrintLockedButton(
                            label: '🪪 Print Card',
                            isLocked: isLocked,
                            onUnlocked: () {
                              context.push('/print/${order.id}');
                            },
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TealButton(
                        label: '＋ Add Payment',
                        onPressed: () {
                          AddPaymentModal.show(context, order: order);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, OrderStatus status) {
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
}

class _DateCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isOverdue;

  const _DateCard({
    required this.label,
    required this.value,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final text3 = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    final bg = isDark ? const Color(0x08FFFFFF) : const Color(0xFFFFFFFF);
    final border = isOverdue
        ? (isDark ? const Color(0x33FF3A58) : const Color(0xFFDC2626).withValues(alpha: 0.3))
        : (isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000));

    final labelColor = isOverdue
        ? (isDark ? const Color(0xFFFF3A58) : const Color(0xFFDC2626))
        : text3;

    final valueColor = isOverdue
        ? (isDark ? const Color(0xFFFF3A58) : const Color(0xFFDC2626))
        : text1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(
          color: border,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;

  const _MoneyRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF5A7090),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFEDF4FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final OrderModel order;
  const _StatusStepper({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = [
      OrderStatus.pending,
      OrderStatus.cutting,
      OrderStatus.stitching,
      OrderStatus.ready,
      OrderStatus.delivered,
    ];
    final currentIdx = steps.indexOf(order.status);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < currentIdx;
          return Expanded(
            child: Container(
              height: 2,
              color: isDone 
                  ? (isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669)) 
                  : (isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000)),
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final isDone = stepIdx < currentIdx;
        final isCurrent = stepIdx == currentIdx;
        final step = steps[stepIdx];

        BoxDecoration boxDeco;
        if (isCurrent) {
          boxDeco = BoxDecoration(
            color: isDark ? const Color(0x26F5A623) : const Color(0x1AF5A623),
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x4DF5A623) : const Color(0x26D97706),
                blurRadius: 16,
              ),
            ],
          );
        } else if (isDone) {
          boxDeco = BoxDecoration(
            color: isDark ? const Color(0x1A10CBA0) : const Color(0xFFECFDF5),
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? const Color(0x3310CBA0) : const Color(0xFF059669).withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x3310CBA0) : const Color(0x1F059669),
                blurRadius: 12,
              ),
            ],
          );
        } else {
          boxDeco = BoxDecoration(
            color: isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF4F6FA),
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000), width: 1),
          );
        }

        Color textColor;
        if (isCurrent) {
          textColor = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
        } else if (isDone) {
          textColor = isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669);
        } else {
          textColor = isDark ? const Color(0xFF2D4060) : const Color(0xFF94A3B8);
        }

        return GestureDetector(
          onTap: () {
            UpdateStatusModal.show(context, order: order);
          },
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: boxDeco,
                child: Center(
                  child: Text(
                    step.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// GALLERY VIEWER CLASS
class _GalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final ValueChanged<int> onDelete;

  const _GalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Text('✕', style: TextStyle(color: Colors.white, fontSize: 18)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Image ${_currentIndex + 1} of ${widget.images.length}',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Text('🗑️', style: TextStyle(fontSize: 18, color: Colors.red)),
            onPressed: () {
              widget.onDelete(_currentIndex);
              if (widget.images.length <= 1) {
                Navigator.pop(context);
              } else {
                setState(() {
                  if (_currentIndex >= widget.images.length) {
                    _currentIndex = widget.images.length - 1;
                  }
                });
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemBuilder: (context, idx) {
          final path = widget.images[idx];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: Image.network(
                path.startsWith('http') || path.startsWith('assets')
                    ? path
                    : '${SupabaseConfig.designImagesUrl}/$path',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// PREMIUM BUTTONS IN DETAIL
class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0x0DFFFFFF) : const Color(0x0D000000),
          border: Border.all(
            color: isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? const Color(0xFF5A7090) : const Color(0xFF4A5568),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _GoldButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _GoldButton({
    required this.label,
    required this.icon,
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
          height: 46,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: const Color(0xFF1A0A00)),
                const SizedBox(width: 7),
              ],
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

class _TealButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _TealButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_TealButton> createState() => _TealButtonState();
}

class _TealButtonState extends State<_TealButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0x1A10CBA0) : const Color(0xFFECFDF5);
    final border = isDark ? const Color(0x4010CBA0) : const Color(0xFF059669).withValues(alpha: 0.3);
    final text = isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669);

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
          height: 46,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 16, color: text),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _OutlineButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0x0AFFFFFF) : const Color(0xFFFFF8EE);
    final border = isDark ? const Color(0x14FFFFFF) : const Color(0xFFD97706).withValues(alpha: 0.3);
    final text = isDark ? const Color(0xFF8AA0B8) : const Color(0xFFD97706);

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
            color: bg,
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrintLockedButton extends StatelessWidget {
  final String label;
  final VoidCallback onUnlocked;
  final bool isLocked;
  
  const _PrintLockedButton({required this.label, required this.onUnlocked, required this.isLocked});
  
  @override
  Widget build(BuildContext context) {
    if (!isLocked) {
      // Show original button - call onUnlocked
      return ElevatedButton.icon(
        onPressed: onUnlocked,
        icon: const Icon(Icons.print_rounded),
        label: Text(label),
      );
    }
    return Stack(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showUpgradeDialog(context),
          icon: const Icon(Icons.lock_rounded, color: Colors.grey),
          label: Text(label, style: const TextStyle(color: Colors.grey)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            foregroundColor: Colors.grey,
          ),
        ),
      ],
    );
  }
  
  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [Icon(Icons.lock_rounded, color: Color(0xFFF5A623)), SizedBox(width: 8), Text('Print Locked')]),
        content: const Text('Print feature is available on the Full Access plan.\n\nUpgrade for Rs 23,000 to unlock printing.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); context.go('/upgrade-plan'); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5A623), foregroundColor: Colors.black),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
}
