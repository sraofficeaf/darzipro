import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  void _pickImage(BuildContext context, WidgetRef ref, String orderId) async {
    final picker = ImagePicker();
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfDark,
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
                title: Text('Camera se photo lein', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
                title: Text('Gallery se select karein', style: GoogleFonts.inter(color: Colors.white)),
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
              backgroundColor: AppColors.teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  void _changeStatus(BuildContext context, WidgetRef ref, String orderId, OrderStatus currentStatus) async {
    final OrderStatus? selectedStatus = await showModalBottomSheet<OrderStatus>(
      context: context,
      backgroundColor: AppColors.surfDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'CHANGE STATUS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.accent,
                  ),
                ),
              ),
              ...OrderStatus.values.map((status) {
                final isCurrent = status == currentStatus;
                return ListTile(
                  leading: Text(status.emoji, style: const TextStyle(fontSize: 18)),
                  title: Text(
                    status.label,
                    style: GoogleFonts.inter(
                      color: isCurrent ? AppColors.accent : Colors.white,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isCurrent ? const Text('✓', style: TextStyle(color: AppColors.accent, fontSize: 16)) : null,
                  onTap: () => Navigator.pop(context, status),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selectedStatus != null && selectedStatus != currentStatus) {
      ref.read(ordersProvider.notifier).updateOrderStatus(orderId, selectedStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Status updated to: ${selectedStatus.label}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        }
      },
      child: ordersAsync.when(
      loading: () => Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('Order Detail')),
        body: Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.red))),
      ),
      data: (orders) {
        OrderModel? order;
        try {
          order = orders.firstWhere((o) => o.id == orderId);
        } catch (_) {}

        if (order == null) {
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(title: const Text('Order')),
            body: const EmptyState(emoji: '🔍', title: 'Order Not Found'),
          );
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: surf,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.tokenNumber,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.accent : AppColors.accentL,
                  ),
                ),
                Text(
                  order.customerName,
                  style: GoogleFonts.inter(fontSize: 12, color: t2),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Text('←', style: TextStyle(fontSize: 20)),
              onPressed: () => context.pop(),
            ),
            actions: [
              TextButton(
                onPressed: () => context.push('/token-card/${order!.id}'),
                child: Text(
                  '🎫 Card',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.accent : AppColors.accentL,
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Customer Row: AppCard with avatar + name + phone + status pill
              AppCard(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/customers/${order!.customerId}');
                },
                child: Row(
                  children: [
                    CustomerAvatar(name: order.customerName, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            'Client Details',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: t2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(status: order.status),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Progress Stepper Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ORDER STATUS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: isDark ? AppColors.accent : AppColors.accentL,
                    ),
                  ),
                  Text(
                    'TAP TO UPDATE',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: t2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress stepper wrapped inside an AppCard
              GestureDetector(
                onTap: () => _changeStatus(context, ref, order!.id, order.status),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                  child: _StatusStepper(status: order.status),
                ),
              ),
              const SizedBox(height: 18),

              // Order dates card
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _InfoChip('📅 Ordered', formatDateShort(order.orderDate)),
                    _InfoChip(
                      '🚚 Delivery',
                      order.deliveryDate != null
                          ? formatDateShort(order.deliveryDate!)
                          : 'Not set',
                      urgent: order.isUrgent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Items Header
              Text(
                'ORDER ITEMS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: isDark ? AppColors.accent : AppColors.accentL,
                ),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => _ItemCard(item: item)),
              const SizedBox(height: 18),

              // Payment summary Header
              Text(
                'PAYMENT SUMMARY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: isDark ? AppColors.accent : AppColors.accentL,
                ),
              ),
              const SizedBox(height: 8),

              // Money Card: Gradient [Color(0xFF060E1E), Color(0xFF112040)]
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF060E1E), Color(0xFF112040)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _MoneyRow('Total Amount', formatMoney(order.totalAmount)),
                    if (order.discount > 0)
                      _MoneyRow('Discount', '- ${formatMoney(order.discount)}'),
                    _MoneyRow('Advance Paid', formatMoney(order.paidAmount)),
                    Container(
                      height: 1.0,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Outstanding',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0x80FFFFFF),
                          ),
                        ),
                        order.isFullyPaid
                            ? Text(
                                'Fully Paid ✓',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.teal,
                                ),
                              )
                            : GradientText(
                                formatMoney(order.remainingAmount),
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                                colors: const [Color(0xFFF5A623), Color(0xFFFFD080)],
                              ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Notes
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                Text(
                  'NOTES',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: isDark ? AppColors.accent : AppColors.accentL,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x1FF5A623) : const Color(0xFFFFFBEB),
                    border: Border.all(
                      color: isDark ? AppColors.accent : AppColors.accentL,
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📌 ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          order.notes!,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? AppColors.accent : const Color(0xFF78350F),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Design Reference Images Header
              Text(
                'DESIGN REFERENCE IMAGES',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: isDark ? AppColors.accent : AppColors.accentL,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: () => _pickImage(context, ref, order!.id),
                      child: Container(
                        width: 90,
                        height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surf2Dark : AppColors.surf2Light,
                          border: Border.all(color: border),
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
                                  color: t2,
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
                            style: GoogleFonts.inter(fontSize: 12, color: t2, fontStyle: FontStyle.italic),
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
                                  images: order!.images,
                                  initialIndex: idx,
                                  onDelete: (index) {
                                    ref.read(ordersProvider.notifier).deleteOrderImage(order!.id, order.images[index]);
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
                              border: Border.all(color: border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              path.startsWith('http') || path.startsWith('assets')
                                  ? path
                                  : 'https://ztxrkijwfnegvquoblne.supabase.co/storage/v1/object/public/design-images/$path',
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

              // Action buttons: Print Card (GoldButton) + Add Payment (OutlineButton) in Row
              Row(
                children: [
                  Expanded(
                    child: GoldButton(
                      height: 46,
                      borderRadius: 16,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/print/${order!.id}');
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.print_rounded, size: 16, color: Color(0xFF1A0F00)),
                          const SizedBox(width: 6),
                          Text(
                            'PRINT CARD',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A0F00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/payment/${order!.id}');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.teal,
                          backgroundColor: isDark ? const Color(0x1F10CBA0) : const Color(0xFFCBEFF5),
                          side: BorderSide(color: const Color(0xFF10CBA0).withValues(alpha: 0.3), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.payment_rounded, size: 16, color: Color(0xFF10CBA0)),
                            const SizedBox(width: 6),
                            Text(
                              'ADD PAYMENT',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF10CBA0) : const Color(0xFF056475),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    ));
  }
}

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
                    : 'https://ztxrkijwfnegvquoblne.supabase.co/storage/v1/object/public/design-images/$path',
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

class _StatusStepper extends StatelessWidget {
  final OrderStatus status;

  const _StatusStepper({required this.status});

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
    final currentIdx = steps.indexOf(status);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line: done=Color(0xFF10CBA0), pending=0x12FFFFFF, width 2.5
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < currentIdx;
          return Expanded(
            child: Container(
              height: 2.5,
              color: isDone ? const Color(0xFF10CBA0) : const Color(0x12FFFFFF),
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final isDone = stepIdx < currentIdx;
        final isCurrent = stepIdx == currentIdx;
        final step = steps[stepIdx];

        Color circleBg;
        BoxShadow? shadow;

        if (isCurrent) {
          circleBg = const Color(0xFFF5A623);
          shadow = const BoxShadow(
            color: Color(0x59F5A623),
            blurRadius: 12,
            spreadRadius: 1.5,
          );
        } else if (isDone) {
          circleBg = const Color(0xFF10CBA0);
          shadow = const BoxShadow(
            color: Color(0x4010CBA0),
            blurRadius: 8,
            spreadRadius: 1,
          );
        } else {
          circleBg = const Color(0x12FFFFFF);
        }

        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                boxShadow: shadow != null ? [shadow] : [],
              ),
              child: Center(
                child: Text(
                  step.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              step.label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isCurrent
                    ? const Color(0xFFF5A623)
                    : (isDone
                        ? const Color(0xFF10CBA0)
                        : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool urgent;

  const _InfoChip(this.label, this.value, {this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700, color: t2)),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: urgent ? AppColors.red : t1,
          ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  final OrderItemModel item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.dressType} × ${item.quantity}',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700, color: t1),
                  ),
                  if (item.clothDetails.isNotEmpty)
                    Text(item.clothDetails,
                        style: GoogleFonts.inter(fontSize: 11.5, color: t2)),
                  if (item.designDetails != null)
                    Text(item.designDetails!,
                        style: GoogleFonts.inter(fontSize: 11.5, color: t2)),
                ],
              ),
            ),
            Text(
              formatMoney(item.total),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 13, fontWeight: FontWeight.w800, color: t1),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;

  const _MoneyRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
          Text(value,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & bounds.size),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
