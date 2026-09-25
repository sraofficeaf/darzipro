import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_enums.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/share_helper.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/models/models.dart';
import '../printing/pdf_builder.dart';
import 'widgets/add_payment_modal.dart';
import 'widgets/update_status_modal.dart';
import 'widgets/delivery_date_modal.dart';

// ── COLOR CONSTANTS (CACHED) ────────────────────────────────────────────────
class _OdColors {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const line = Color(0xFFE8EAF0);
  static const paper = Color(0xFFF5F6F8);

  static const dark = Color(0xFF151922);
  static const darkCard = Color(0xFF181D27);
  static const darkLine = Color(0xFF333946);

  static const navy = Color(0xFF12213A);
  static const navy2 = Color(0xFF1E3A5F);

  static const gold = Color(0xFFE9A227);
  static const gold2 = Color(0xFFFFC65A);
  static const goldBg = Color(0xFFFFF6E5);

  static const green = Color(0xFF18B887);
  static const greenBg = Color(0xFFEAFBF5);
  static const greenLine = Color(0xFFCFEFE3);

  static const rose = Color(0xFFEF5261);
  static const roseBg = Color(0xFFFFF0F2);
  static const roseLine = Color(0xFFFFD9DE);

  static const blue = Color(0xFF5478E8);
  static const blueBg = Color(0xFFEEF2FF);

  static const violet = Color(0xFF8764E8);
  static const violetBg = Color(0xFFF3F0FF);

  static const wa = Color(0xFF25D366);
}

// ── ORDER DETAIL SCREEN ─────────────────────────────────────────────────────
class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  void _pickImage(BuildContext context, WidgetRef ref, String orderId) async {
    final picker = ImagePicker();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? _OdColors.darkCard : Colors.white,
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
                  'Take Photo with Camera',
                  style: GoogleFonts.manrope(
                    color: isDark ? Colors.white : _OdColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
                title: Text(
                  'Select from Gallery',
                  style: GoogleFonts.manrope(
                    color: isDark ? Colors.white : _OdColors.ink,
                    fontWeight: FontWeight.w700,
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
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        try {
          final shopId = ref.read(currentShopIdProvider);
          if (shopId == null) throw Exception('Shop ID not found');

          final rawBytes = await picked.readAsBytes();

          // 1. Upload Guard: 30 MB rejection
          if (rawBytes.length > ImageCompressor.maxUploadSizeBytes) {
            final sizeMb = (rawBytes.length / (1024 * 1024)).toStringAsFixed(1);
            messenger.showSnackBar(
              SnackBar(
                content: Text('⚠️ File too large ($sizeMb MB). Maximum allowed size is 30 MB.'),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          // 2. Client-side compression & resizing (1600px max edge, quality 80)
          final compressed = await ImageCompressor.compressGarmentPhoto(rawBytes);

          // 3. Storage quota check
          final check = await StorageService.instance.checkCanUpload(shopId, compressed.compressedBytesLength);
          if (check['canUpload'] != true) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(check['reason']?.toString() ?? 'Storage full'),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          // 4. Upload ONLY compressed bytes
          final filename = '$shopId/${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage
              .from('design-images')
              .uploadBinary(
                filename,
                compressed.bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );

          // 5. Increment storage_used_bytes by compressed size
          await StorageService.instance.incrementStorageUsed(shopId, compressed.compressedBytesLength);
          ref.invalidate(baseStorageLimitMbProvider);
          ref.invalidate(shopStorageAllowanceProvider);

          // 6. Record storage path on order
          await ref.read(ordersProvider.notifier).addOrderImage(orderId, filename);

          if (context.mounted) {
            final kb = compressed.compressedKb.toStringAsFixed(1);
            messenger.showSnackBar(
              SnackBar(
                content: Text('✅ Garment photo added ($kb KB)!'),
                backgroundColor: _OdColors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error uploading order image: $e');
          if (context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('⚠️ Failed to add image: $e'),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _shareWhatsApp(
    BuildContext context,
    OrderModel order,
    CustomerModel? customer, {
    WidgetRef? ref,
  }) async {
    try {
      final shop = ref?.read(currentShopProvider).value;
      final bytes = await DarziPdfBuilder.buildThermal(
        order,
        customer,
        isUrdu: false,
        shopName: shop?['name'] as String?,
        shopPhone: shop?['phone'] as String?,
        shopAddress: shop?['address'] as String?,
      );
      final deliveryDateStr = order.deliveryDate != null
          ? DateFormat('dd MMM yyyy').format(order.deliveryDate!)
          : 'To be confirmed';

      final msg = '🧵 *Darzi Pro — Order ${order.tokenNumber}*\n\n'
          'Customer: ${order.customerName}\n'
          'Items: ${order.itemsSummary}\n'
          '📅 Delivery Date: $deliveryDateStr\n'
          '💰 Total Amount: Rs ${order.totalAmount.toInt()}\n'
          '💵 Advance Paid: Rs ${order.paidAmount.toInt()}\n'
          '⚖️ Remaining: Rs ${order.remainingAmount.toInt()}\n\n'
          'Shukriya! 🙏';

      if (context.mounted) {
        await DarziShareHelper.shareOrSavePdf(
          context,
          pdfBytes: Uint8List.fromList(bytes),
          fileName: 'Order_${order.tokenNumber}.pdf',
          text: msg,
        );
      }
    } catch (e) {
      debugPrint('WhatsApp share error: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final customersAsync = ref.watch(customersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _OdColors.dark : _OdColors.paper;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ordersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _OdColors.gold),
          ),
          error: (err, _) => Center(
            child: Text('Error: $err', style: const TextStyle(color: _OdColors.rose)),
          ),
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
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : _OdColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            final customers = customersAsync.valueOrNull ?? const [];
            final customer = customers.where((c) => c.id == order.customerId).firstOrNull;

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final isOverdue = order.deliveryDate != null &&
                order.deliveryDate!.isBefore(today) &&
                order.status != OrderStatus.delivered &&
                order.status != OrderStatus.cancelled;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // SCREEN HEAD
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back Row & Kicker
                          Row(
                            children: [
                              InkWell(
                                onTap: () => context.pop(),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isDark ? _OdColors.darkCard : Colors.white,
                                    border: Border.all(
                                      color: isDark ? _OdColors.darkLine : _OdColors.line,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: 18,
                                    color: isDark ? Colors.white : _OdColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'ORDER #${order.tokenNumber}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                  color: _OdColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Title and Top Actions Row
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 600;

                              final titleColumn = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${order.customerName}\'s Order',
                                    style: GoogleFonts.manrope(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.7,
                                      color: isDark ? Colors.white : _OdColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Placed ${DateFormat('dd MMM yyyy').format(order.orderDate)}${order.itemsSummary.isNotEmpty ? ' · ${order.itemsSummary}' : ''}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _OdColors.muted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );

                              final actionsRow = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Token Card button
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      context.push('/token-card/${order.id}');
                                    },
                                    icon: const Text('🪪'),
                                    label: const Text('Card'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? Colors.white : _OdColors.ink,
                                      backgroundColor:
                                          isDark ? _OdColors.darkCard : Colors.white,
                                      side: BorderSide(
                                        color: isDark ? _OdColors.darkLine : _OdColors.line,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Add Payment button
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [_OdColors.gold2, _OdColors.gold],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x38E9A227),
                                          blurRadius: 14,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            AddPaymentModal.show(context, order: order),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('＋',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      color: Color(0xFF211500))),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Add Payment',
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
                                    titleColumn,
                                    const SizedBox(height: 12),
                                    actionsRow,
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(child: titleColumn),
                                  actionsRow,
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // RESPONSIVE 2-COLUMN GRID (OR STACKED ON MOBILE)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;

                        final leftCol = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Client Card
                            _buildClientCard(context, order, customer, isDark),
                            const SizedBox(height: 14),

                            // 2. Status Stepper Card
                            _buildStatusCard(context, order, isDark),
                            const SizedBox(height: 14),

                            // 3. Dates Row
                            _buildDatesRow(context, order, isOverdue, isDark),
                            const SizedBox(height: 14),

                            // 4. Order Items Card
                            _buildOrderItemsCard(order, isDark),
                            const SizedBox(height: 14),

                            // 5. Design Reference Images
                            _buildImagesCard(context, ref, order, isDark),
                          ],
                        );

                        final rightCol = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Payment Summary
                            _buildPaymentSummary(order),
                            const SizedBox(height: 14),

                            // 2. Quick Actions
                            _buildQuickActions(context, ref, order, customer, isDark),
                            const SizedBox(height: 14),

                            // 3. Notes Card
                            _buildNotesCard(order, isDark),
                          ],
                        );

                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: leftCol),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: rightCol),
                            ],
                          );
                        }

                        // Mobile Stacked Layout
                        return Column(
                          children: [
                            leftCol,
                            const SizedBox(height: 14),
                            rightCol,
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 1. CLIENT CARD ────────────────────────────────────────────────────────
  Widget _buildClientCard(
    BuildContext context,
    OrderModel order,
    CustomerModel? customer,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _OdColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark ? _OdColors.darkLine : _OdColors.line,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Initial
          Stack(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_OdColors.gold2, Color(0xFFD88A13)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    order.customerName.isNotEmpty
                        ? order.customerName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _OdColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),

          // Name, Phone & Links
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : _OdColors.ink,
                  ),
                ),
                if (customer != null && customer.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    customer.phone,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _OdColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.push('/customers/${order.customerId}'),
                      child: Text(
                        'Client Details',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _OdColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: () => context.push(
                          '/measurements/${order.customerId}/${Uri.encodeComponent(order.customerName)}'),
                      child: Text(
                        '📏 View Naap',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _OdColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status Badge Pill
          _buildStatusTag(order.status, isDark),
        ],
      ),
    );
  }

  // ── 2. STATUS STEPPER CARD ────────────────────────────────────────────────
  Widget _buildStatusCard(BuildContext context, OrderModel order, bool isDark) {
    const steps = [
      (OrderStatus.pending, 'Pending', '⏳'),
      (OrderStatus.cutting, 'Cutting', '✂️'),
      (OrderStatus.stitching, 'Stitching', '🧵'),
      (OrderStatus.ready, 'Ready', '✅'),
      (OrderStatus.delivered, 'Delivered', '📦'),
    ];

    final currentIdx = steps.indexWhere((s) => s.$1 == order.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? _OdColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark ? _OdColors.darkLine : _OdColors.line,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER STATUS',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: _OdColors.muted,
                ),
              ),
              InkWell(
                onTap: () => UpdateStatusModal.show(context, order: order),
                child: Text(
                  'Tap to Update',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _OdColors.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stepper Line & Circles
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepIdx = index ~/ 2;
                final isDone = stepIdx < currentIdx;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isDone
                        ? _OdColors.green
                        : (isDark ? _OdColors.darkLine : _OdColors.line),
                  ),
                );
              }

              final stepIdx = index ~/ 2;
              final stepData = steps[stepIdx];
              final isDone = stepIdx < currentIdx;
              final isActive = stepIdx == currentIdx;

              return InkWell(
                onTap: () => UpdateStatusModal.show(context, order: order),
                child: Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? _OdColors.greenBg
                            : (isActive
                                ? _OdColors.goldBg
                                : (isDark ? _OdColors.darkCard : _OdColors.paper)),
                        border: Border.all(
                          color: isDone
                              ? _OdColors.greenLine
                              : (isActive
                                  ? _OdColors.gold
                                  : (isDark ? _OdColors.darkLine : _OdColors.line)),
                          width: 1.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: _OdColors.gold.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          stepData.$3,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stepData.$2,
                      style: GoogleFonts.dmSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: isDone
                            ? _OdColors.green
                            : (isActive
                                ? const Color(0xFF8B6C22)
                                : _OdColors.muted),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── 3. DATES ROW ──────────────────────────────────────────────────────────
  Widget _buildDatesRow(
    BuildContext context,
    OrderModel order,
    bool isOverdue,
    bool isDark,
  ) {
    return Row(
      children: [
        // Ordered Date
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? _OdColors.darkCard : Colors.white,
              border: Border.all(
                color: isDark ? _OdColors.darkLine : _OdColors.line,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORDERED',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    color: _OdColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(order.orderDate),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : _OdColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Delivery Date
        Expanded(
          child: Material(
            color: isOverdue
                ? (isDark ? const Color(0x1AEF5261) : _OdColors.roseBg)
                : (isDark ? _OdColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => DeliveryDateModal.show(context, order: order),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isOverdue
                        ? _OdColors.roseLine
                        : (isDark ? _OdColors.darkLine : _OdColors.line),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DELIVERY',
                      style: GoogleFonts.dmSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        color: isOverdue ? _OdColors.rose : _OdColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.deliveryDate != null
                          ? DateFormat('dd MMM yyyy').format(order.deliveryDate!)
                          : 'Not set',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isOverdue
                            ? _OdColors.rose
                            : (isDark ? Colors.white : _OdColors.ink),
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
  }

  // ── 4. ORDER ITEMS CARD ───────────────────────────────────────────────────
  Widget _buildOrderItemsCard(OrderModel order, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _OdColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark ? _OdColors.darkLine : _OdColors.line,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    color: _OdColors.gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ORDER ITEMS',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: _OdColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: isDark ? _OdColors.darkLine : _OdColors.line,
            height: 1,
          ),

          // Items List
          ...order.items.map((it) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _OdColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${it.dressType} × ${it.quantity}',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : _OdColors.ink,
                              ),
                            ),
                            if (it.clothDetails.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                it.clothDetails,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: _OdColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        'Rs ${it.total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _OdColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: isDark ? _OdColors.darkLine : _OdColors.line,
                  height: 1,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── 5. DESIGN REFERENCE IMAGES ────────────────────────────────────────────
  Widget _buildImagesCard(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _OdColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark ? _OdColors.darkLine : _OdColors.line,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESIGN REFERENCE IMAGES',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: _OdColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                // Add Image Box
                InkWell(
                  onTap: () => _pickImage(context, ref, order.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: isDark ? _OdColors.dark : _OdColors.paper,
                      border: Border.all(
                        color: _OdColors.muted,
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📷', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          'Add Image',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _OdColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Existing Images
                ...order.images.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final path = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _GalleryViewer(
                              images: order.images,
                              initialIndex: idx,
                              onDelete: (delIdx) {
                                ref.read(ordersProvider.notifier).deleteOrderImage(
                                      order.id,
                                      order.images[delIdx],
                                    );
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? _OdColors.darkLine : _OdColors.line,
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          path.startsWith('http') || path.startsWith('assets')
                              ? path
                              : '${SupabaseConfig.designImagesUrl}/$path',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. PAYMENT SUMMARY ────────────────────────────────────────────────────
  Widget _buildPaymentSummary(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_OdColors.navy, _OdColors.navy2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3312213A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT SUMMARY',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: const Color(0xFFAEB5C2),
            ),
          ),
          const SizedBox(height: 14),

          _buildPaymentRow('Total Amount', 'Rs ${order.totalAmount.toInt()}'),
          const SizedBox(height: 6),
          _buildPaymentRow('Advance Paid', 'Rs ${order.paidAmount.toInt()}'),

          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(vertical: 10),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF8AA0B8),
                ),
              ),
              order.isFullyPaid
                  ? Text(
                      'Fully Paid ✓',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _OdColors.green,
                      ),
                    )
                  : Text(
                      'Rs ${order.remainingAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: _OdColors.gold2,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF8AA0B8)),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFEDF4FF),
          ),
        ),
      ],
    );
  }

  // ── 7. QUICK ACTIONS ──────────────────────────────────────────────────────
  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
    CustomerModel? customer,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _OdColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark ? _OdColors.darkLine : _OdColors.line,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _OdColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 2.8,
            children: [
              // Print Card
              _buildActionButton(
                label: '🪪 Print Card',
                onTap: () => context.push('/token-card/${order.id}'),
                isDark: isDark,
              ),

              // Add Payment
              _buildActionButton(
                label: '＋ Payment',
                onTap: () => AddPaymentModal.show(context, order: order),
                color: _OdColors.green,
                bgColor: _OdColors.greenBg,
                isDark: isDark,
              ),

              // WhatsApp
              _buildActionButton(
                label: '💬 WhatsApp',
                onTap: () => _shareWhatsApp(context, order, customer, ref: ref),
                color: _OdColors.wa,
                bgColor: const Color(0x1F25D366),
                isDark: isDark,
              ),

              // Update Status
              _buildActionButton(
                label: '🔄 Status',
                onTap: () => UpdateStatusModal.show(context, order: order),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    Color? color,
    Color? bgColor,
    required bool isDark,
  }) {
    final textCol = color ?? (isDark ? Colors.white : _OdColors.ink);
    final backgroundCol = bgColor ?? (isDark ? _OdColors.dark : _OdColors.paper);

    return Material(
      color: backgroundCol,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: color?.withValues(alpha: 0.3) ??
                  (isDark ? _OdColors.darkLine : _OdColors.line),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: textCol,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 8. NOTES CARD ─────────────────────────────────────────────────────────
  Widget _buildNotesCard(OrderModel order, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _OdColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark ? _OdColors.darkLine : _OdColors.line,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _OdColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.notes != null && order.notes!.isNotEmpty
                ? order.notes!
                : 'No special notes or instructions recorded.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: _OdColors.muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(OrderStatus status, bool isDark) {
    Color bg;
    Color color;

    switch (status) {
      case OrderStatus.pending:
        bg = _OdColors.goldBg;
        color = const Color(0xFFB45309);
        break;
      case OrderStatus.cutting:
        bg = _OdColors.violetBg;
        color = _OdColors.violet;
        break;
      case OrderStatus.stitching:
        bg = _OdColors.blueBg;
        color = _OdColors.blue;
        break;
      case OrderStatus.ready:
        bg = _OdColors.greenBg;
        color = _OdColors.green;
        break;
      case OrderStatus.delivered:
        bg = isDark ? _OdColors.darkLine : const Color(0xFFEFEFEF);
        color = _OdColors.muted;
        break;
      case OrderStatus.cancelled:
        bg = _OdColors.roseBg;
        color = _OdColors.rose;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── GALLERY VIEWER ──────────────────────────────────────────────────────────
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
          style: GoogleFonts.inter(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
