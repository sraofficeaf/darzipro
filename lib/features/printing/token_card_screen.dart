import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_enums.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import 'pdf_builder.dart';

class TokenCardScreen extends ConsumerWidget {
  final String orderId;

  const TokenCardScreen({super.key, required this.orderId});

  Future<void> _shareAsPdf(OrderModel order, CustomerModel? customer, bool isUrdu) async {
    try {
      final bytes = await DarziPdfBuilder.buildA4(order, customer, isUrdu: isUrdu);
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'application/pdf',
        name: 'Order_${order.tokenNumber}.pdf',
      );
      await Share.shareXFiles([file],
          text: '📋 Darzi Pro — ${order.customerName} ka order card');
    } catch (_) {}
  }

  Future<void> _sendWhatsApp(OrderModel order, CustomerModel? customer) async {
    final phone = customer?.phone.replaceAll(RegExp(r'\D'), '') ?? '';
    final msg = Uri.encodeComponent(
      '🧵 *Darzi Pro — ${order.tokenNumber}*\n\n'
      'Aapka order ready hone ka waqt:\n'
      '📅 Delivery: ${formatDateShort(order.deliveryDate ?? DateTime.now())}\n'
      '💰 Baqi raqam: ${formatMoney(order.remainingAmount)}\n\n'
      'Shukriya! 🙏',
    );
    final url = Uri.parse('https://wa.me/92$phone?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _printLayout(OrderModel order, CustomerModel? customer, bool isThermal, bool isUrdu) async {
    try {
      final bytes = isThermal
          ? await DarziPdfBuilder.buildThermal(order, customer, isUrdu: isUrdu)
          : await DarziPdfBuilder.buildA4(order, customer, isUrdu: isUrdu);
      await Printing.layoutPdf(
          onLayout: (_) async => Uint8List.fromList(bytes));
    } catch (_) {}
  }

  Future<void> _printTraditionalCard(BuildContext context, WidgetRef ref, OrderModel order, CustomerModel? customer) async {
    try {
      final customerMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
      final measurement = customerMeasurements
          .where((m) => m.customerId == order.customerId && m.category == MeasurementCategory.men)
          .firstOrNull;

      final bytes = await DarziPdfBuilder.buildTraditionalNaapCard(order, customer, measurement);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final isUrdu = ref.watch(localeProvider) == 'ur';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return ordersAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: Text(isUrdu ? 'ٹوکن کارڈ' : 'Customer Card')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (orders) {
        OrderModel? order;
        if (orderId.isNotEmpty && orderId != ':orderId') {
          try {
            order = orders.firstWhere((o) => o.id == orderId);
          } catch (_) {}
        }

        if (order == null) {
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: surf,
              title: Text(
                isUrdu ? 'ٹوکن کارڈ' : 'Token Card',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: t1,
                ),
              ),
              leading: context.canPop()
                  ? IconButton(
                      icon: const Text('←', style: TextStyle(fontSize: 20)),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎫', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      isUrdu
                          ? 'ٹوکن کارڈ پرنٹ کرنے کے لیے آرڈرز اسکرین سے ایک آرڈر منتخب کریں۔'
                          : 'Select an order from Orders screen to print its token card',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: t2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    GoldButton(
                      height: 46,
                      width: 200,
                      borderRadius: 16,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(navSectionProvider.notifier).state = NavSection.orders;
                        context.go('/orders');
                      },
                      child: Text(
                        isUrdu ? 'آرڈرز پر جائیں' : 'Go to Orders',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A0F00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final customersAsync = ref.watch(customersProvider);
        final customer = customersAsync.whenOrNull(
          data: (customers) {
            try {
              return customers.firstWhere((c) => c.id == order!.customerId);
            } catch (_) {
              return null;
            }
          },
        );

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: surf,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrdu ? 'گاہک کا کارڈ' : 'Customer Card',
                  style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w900, color: t1),
                ),
                Text(
                  'Order ${order.tokenNumber} · ${order.customerName}',
                  style: GoogleFonts.inter(fontSize: 12, color: t2),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Text('←', style: TextStyle(fontSize: 20)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Preview label: GoogleFonts.inter size 9, w800, letterSpacing 1.5, UPPERCASE, color text3, centered
              Center(
                child: Text(
                  isUrdu ? 'کارڈ کا پیش نظارہ' : 'CARD PREVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: t3,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // The Token Card Dark Container Wrapper
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF06101E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 40,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: _TokenCardWidget(order: order, customer: customer),
              ),
              // Traditional Card Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _printTraditionalCard(context, ref, order!, customer),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF1A0F00),
                    elevation: 4,
                    shadowColor: AppColors.accent.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long),
                      const SizedBox(width: 8),
                      Text(
                        isUrdu ? 'روایتی کارڈ' : 'Traditional Card',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4 Action Buttons Grid
              Row(
                children: [
                  Expanded(
                    child: _ActionCardBtn(
                      emoji: '📄',
                      label: isUrdu ? 'A4 پرنٹ' : 'A4 Print',
                      onTap: () => _printLayout(order!, customer, false, isUrdu),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCardBtn(
                      emoji: '🧾',
                      label: isUrdu ? 'تھرمل' : 'Thermal',
                      onTap: () => _printLayout(order!, customer, true, isUrdu),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ActionCardBtn(
                      emoji: '📱',
                      label: 'WhatsApp',
                      onTap: () => _sendWhatsApp(order!, customer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCardBtn(
                      emoji: '📥',
                      label: isUrdu ? 'پی ڈی ایف' : 'PDF',
                      onTap: () => _shareAsPdf(order!, customer, isUrdu),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _TokenCardWidget extends StatelessWidget {
  final OrderModel order;
  final CustomerModel? customer;

  const _TokenCardWidget({required this.order, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Card Header: gradient [Color(0xFF060E1E), Color(0xFF112040)]
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF060E1E), Color(0xFF112040)],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo box gradient [Color(0xFFC8841A), Color(0xFFF5A623)] radius 10 with glow shadow
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFC8841A), Color(0xFFF5A623)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x59F5A623),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('✂️', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SaifurRahman Tailors',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Saddar, Peshawar · 0300-1234567',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF5A623).withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                // Token badge: bg Color(0x25F5A623), border Color(0xFFF5A623).withValues(alpha:0.4)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x25F5A623),
                    border: Border.all(
                      color: const Color(0xFFF5A623).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.tokenNumber,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF5A623),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Measuring tape stripe: height 8
          CustomPaint(
            size: const Size(double.infinity, 8),
            painter: const TapeStripePainter(),
          ),

          // White body
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Customer avatar radius 9, name outfit 15, w900, color 0xFF060E1C
                Row(
                  children: [
                    CustomerAvatar(
                      name: order.customerName,
                      size: 38,
                      borderRadius: 9,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF060E1C),
                            ),
                          ),
                          if (customer != null)
                            Text(
                              '📱 ${customer!.phone}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ORDER NO.',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          '#${order.orderNumber}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF060E1C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Date boxes: bg 0xFFF1F5FF, radius 7.
                Row(
                  children: [
                    Expanded(
                      child: _DateBox(
                        label: 'Order Date',
                        value: formatDateShort(order.orderDate),
                        isDue: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateBox(
                        label: 'Delivery Date',
                        value: order.deliveryDate != null
                            ? formatDateShort(order.deliveryDate!)
                            : 'Not set',
                        isDue: order.isUrgent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Items box: bg 0xFFF5F8FF, radius 8, dashed dividers
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORDER ITEMS',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: const Color(0xFF8AA0C0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isLast = idx == order.items.length - 1;

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.dressType} × ${item.quantity}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF1A2A40),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatMoney(item.total),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1A2A40),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast) const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: DashedDivider(),
                            ),
                          ],
                        );
                      }),
                      if (order.items.isNotEmpty &&
                          order.items.first.clothDetails.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: DashedDivider(),
                        ),
                        Text(
                          order.items.first.clothDetails,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: const Color(0xFF8AA0C0),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Money section: gradient [Color(0xFF060E1E), Color(0xFF112040)], radius 9, padding 13
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF060E1E), Color(0xFF112040)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    children: [
                      _MoneyLine('Total Amount', formatMoney(order.totalAmount)),
                      _MoneyLine('Advance Paid', formatMoney(order.paidAmount)),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remaining',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0x80FFFFFF),
                            ),
                          ),
                          Text(
                            order.isFullyPaid
                                ? 'Fully Paid ✓'
                                : formatMoney(order.remainingAmount),
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: order.isFullyPaid ? AppColors.teal : const Color(0xFFF5A623),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Notes box: bg 0xFFFFFBEB, border dashed gold, radius 8
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  CustomPaint(
                    painter: const DashedBorderPainter(color: Color(0xFFF5A623), strokeWidth: 1.5),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📌 NOTES',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.notes!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF78350F),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5FF),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generated by Darzi Pro',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        color: const Color(0xFF8AA0C0),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      'SaifurRahman Tailors · ${formatDateShort(DateTime.now())}',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        color: const Color(0xFF8AA0C0),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // QR placeholder
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text('⬛', style: TextStyle(fontSize: 20)),
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

class TapeStripePainter extends CustomPainter {
  const TapeStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const double blockWidth = 12.0;
    double x = 0;
    bool isGold = true;

    while (x < size.width) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + blockWidth, 0)
        ..lineTo(x + blockWidth - 4, size.height)
        ..lineTo(x - 4, size.height)
        ..close();

      canvas.drawPath(path, isGold ? goldPaint : whitePaint);
      x += blockWidth - 2;
      isGold = !isGold;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedDivider extends StatelessWidget {
  final Color color;
  final double height;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.color = const Color(0xFFDCE8FF),
    this.height = 1,
    this.dashWidth = 5,
    this.dashSpace = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;

  const DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 3.0,
    this.dash = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ));

    final dashPath = Path();
    double distance = 0.0;
    bool draw = true;

    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final len = draw ? dash : gap;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.dash != dash;
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isDue;

  const _DateBox({
    required this.label,
    required this.value,
    required this.isDue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FF),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: const Color(0xFF8AA0C0),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isDue ? const Color(0xFFDC2626) : const Color(0xFF060E1C),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  final String label;
  final String value;

  const _MoneyLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: const Color(0x80FFFFFF),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xD9FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCardBtn extends StatefulWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _ActionCardBtn({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionCardBtn> createState() => _ActionCardBtnState();
}

class _ActionCardBtnState extends State<_ActionCardBtn> {
  double _scale = 1.0;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalBg = isDark ? const Color(0x09FFFFFF) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A);
    final goldGradient = const LinearGradient(
      colors: [Color(0xFFF5A623), Color(0xFFD4791A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTapDown: (_) => setState(() {
        _scale = 0.95;
        _isPressed = true;
      }),
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
          _isPressed = false;
        });
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() {
        _scale = 1.0;
        _isPressed = false;
      }),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: _isPressed ? null : normalBg,
            gradient: _isPressed ? goldGradient : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPressed ? Colors.transparent : borderCol,
              width: 1.5,
            ),
            boxShadow: _isPressed
                ? const [
                    BoxShadow(
                      color: Color(0x59F5A623),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _isPressed ? const Color(0xFF1A0F00) : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
