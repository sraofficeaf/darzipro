import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/utils/share_helper.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import 'pdf_builder.dart';
import 'widgets/card_image_capturer.dart';
import 'widgets/token_card_widget.dart';

class TokenCardScreen extends ConsumerStatefulWidget {
  final String orderId;

  const TokenCardScreen({super.key, required this.orderId});

  @override
  ConsumerState<TokenCardScreen> createState() => _TokenCardScreenState();
}

class _TokenCardScreenState extends ConsumerState<TokenCardScreen> {
  Uint8List? _cachedA4Pdf;
  Uint8List? _cachedThermalPdf;
  bool _isPrintingA4 = false;
  bool _isPrintingThermal = false;
  bool _isWhatsApping = false;
  bool _isPdfSharing = false;

  bool get _isAnyBusy => _isPrintingA4 || _isPrintingThermal || _isWhatsApping || _isPdfSharing;

  Future<Uint8List> _generateBytes(OrderModel order, CustomerModel? customer, bool isThermal) async {
    if (isThermal && _cachedThermalPdf != null) return _cachedThermalPdf!;
    if (!isThermal && _cachedA4Pdf != null) return _cachedA4Pdf!;

    final pngBytes = await CardImageCapturer.captureOnDemand(
      context,
      cardWidget: TokenCardWidget(
        order: order,
        customer: customer,
        isThermal: isThermal,
      ),
    );
    final format = isThermal
        ? PdfPageFormat(80 * PdfPageFormat.mm, double.infinity)
        : PdfPageFormat.a4;
    final pdfBytes = await DarziPdfBuilder.buildPdfFromImageBytes(pngBytes, pageFormat: format);
    final result = Uint8List.fromList(pdfBytes);
    if (isThermal) {
      _cachedThermalPdf = result;
    } else {
      _cachedA4Pdf = result;
    }
    return result;
  }

  Future<void> _shareAsPdf(OrderModel order, CustomerModel? customer) async {
    if (_isAnyBusy) return;
    setState(() => _isPdfSharing = true);
    try {
      final bytes = await _generateBytes(order, customer, false);
      if (mounted) {
        await DarziShareHelper.shareOrSavePdf(
          context,
          pdfBytes: bytes,
          fileName: 'Order_${order.tokenNumber}.pdf',
          text: '📋 Darzi Pro — ${order.customerName} ka order card',
        );
      }
    } catch (e) {
      debugPrint('TokenCardScreen: share pdf failed — $e');
    } finally {
      if (mounted) setState(() => _isPdfSharing = false);
    }
  }

  Future<void> _sendWhatsApp(OrderModel order, CustomerModel? customer) async {
    if (_isAnyBusy) return;
    setState(() => _isWhatsApping = true);
    try {
      final bytes = await _generateBytes(order, customer, true);
      final msg = '🧵 *Darzi Pro — Token ${order.tokenNumber}*\n\n'
          'Aapka order ready hone ka waqt:\n'
          '📅 Delivery: ${formatDateShort(order.deliveryDate ?? DateTime.now())}\n'
          '💰 Baqi raqam: ${formatMoney(order.remainingAmount)}\n\n'
          'Shukriya! 🙏';
      if (mounted) {
        await DarziShareHelper.shareOrSavePdf(
          context,
          pdfBytes: bytes,
          fileName: 'Order_${order.tokenNumber}.pdf',
          text: msg,
        );
      }
    } catch (e) {
      debugPrint('TokenCardScreen: whatsapp share failed — $e');
    } finally {
      if (mounted) setState(() => _isWhatsApping = false);
    }
  }

  Future<void> _printLayout(OrderModel order, CustomerModel? customer, bool isThermal) async {
    if (_isAnyBusy) return;
    if (isThermal) {
      setState(() => _isPrintingThermal = true);
    } else {
      setState(() => _isPrintingA4 = true);
    }
    try {
      final bytes = await _generateBytes(order, customer, isThermal);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      debugPrint('TokenCardScreen: print layout failed — $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingThermal = false;
          _isPrintingA4 = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final isUrdu = ref.watch(localeProvider) == 'ur';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);
    final appBarBg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final textMuted = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    final orders = ordersAsync.valueOrNull ?? [];
    final order = orders.where((o) => o.id == widget.orderId).firstOrNull;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(
            child: _BackButton(
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUrdu ? 'گاہک کا کارڈ' : 'Customer Card',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: text1,
              ),
            ),
            if (order != null)
              Text(
                'Order ${order.tokenNumber} · ${order.customerName}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: textMuted,
                ),
              ),
          ],
        ),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF5A623))),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (orders) {
          final order = orders.where((o) => o.id == widget.orderId).firstOrNull;

          if (order == null) {
            final textSecondary = isDark ? const Color(0xFF4A6080) : const Color(0xFF4A5568);
            return Center(
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
                        color: textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _GoldButton(
                      label: isUrdu ? 'آرڈرز پر جائیں' : 'Go to Orders',
                      onPressed: () {
                        ref.read(navSectionProvider.notifier).state = NavSection.orders;
                        context.go('/orders');
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          final customersAsync = ref.watch(customersProvider);
          final customer = customersAsync.whenOrNull(
            data: (customers) => customers.where((c) => c.id == order.customerId).firstOrNull,
          );

          return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
              // PREVIEW LABEL
              Center(
                child: Text(
                  isUrdu ? 'کارڈ کا پیش نظارہ' : 'CARD PREVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: textMuted,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // THE CARD
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A1628), Color(0xFF0D1E3A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 40,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // CARD HEADER (dark)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF060E1E), Color(0xFF0D1E3A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Text('✂️', style: TextStyle(fontSize: 18)),
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
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x26F5A623),
                                border: Border.all(color: const Color(0x66F5A623)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ORDER NO.',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0x99F5A623),
                                    ),
                                  ),
                                  Text(
                                    order.tokenNumber,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFF5A623),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // MEASURING TAPE STRIPE
                      CustomPaint(
                        size: const Size(double.infinity, 8),
                        painter: const _TapeStripePainter(),
                      ),

                      // CARD BODY
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        child: Column(
                          children: [
                            // Customer Row
                            Row(
                              children: [
                                CustomerAvatar(
                                  name: order.customerName,
                                  size: 40,
                                  borderRadius: 10,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.customerName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF060E1C),
                                        ),
                                      ),
                                      if (customer != null)
                                        Text(
                                          '📱 ${customer.phone}',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            color: const Color(0xFF6B7E96),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Dates 2-column
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ORDER DATE',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF8AA0C0),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          formatDateShort(order.orderDate),
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF060E1C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF5F5),
                                      border: Border.all(color: const Color(0xFFFFE0E0)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DELIVERY DATE',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFE08080),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          order.deliveryDate != null
                                              ? formatDateShort(order.deliveryDate!)
                                              : 'Not Set',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Items Box
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF8AA0C0),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...order.items.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${item.dressType} × ${item.quantity}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF1A2A40),
                                                  ),
                                                ),
                                                if (item.clothDetails.isNotEmpty)
                                                  Text(
                                                    item.clothDetails,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: const Color(0xFF6B7E96),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            formatMoney(item.total),
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1A2A40),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Money section
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF060E1E), Color(0xFF0D1E3A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total Amount',
                                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                                      ),
                                      Text(
                                        formatMoney(order.totalAmount),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Advance Paid',
                                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                                      ),
                                      Text(
                                        formatMoney(order.paidAmount),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Color(0x1AFFFFFF), height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Remaining',
                                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                                      ),
                                      order.isFullyPaid
                                          ? const Text(
                                              'Fully Paid ✓',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF10CBA0),
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
                            const SizedBox(height: 14),

                            // Footer
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Generated by Darzi Pro · SaifurRahman Tailors · ${formatDateShort(DateTime.now())}',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        color: const Color(0xFF8AA0C0),
                                      ),
                                      maxLines: 2,
                                    ),
                                  ),
                                  // QR Code
                                  Container(
                                    width: 32,
                                    height: 32,
                                    color: Colors.white,
                                    child: QrImageView(
                                      data: order.id,
                                      version: QrVersions.auto,
                                      size: 32,
                                      padding: EdgeInsets.zero,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF060E1C),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF060E1C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ACTION BUTTONS GRID (2x2)
              Row(
                children: [
                  Expanded(
                    child: _OutlineActionButton(
                      label: isUrdu ? 'A4 پرنٹ' : 'A4 Print',
                      icon: Icons.print_rounded,
                      isLoading: _isPrintingA4,
                      onPressed: () => _printLayout(order, customer, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OutlineActionButton(
                      label: isUrdu ? 'تھرمل' : 'Thermal',
                      icon: Icons.receipt_rounded,
                      isLoading: _isPrintingThermal,
                      onPressed: () => _printLayout(order, customer, true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _WhatsAppActionButton(
                      label: 'WhatsApp',
                      icon: Icons.chat_rounded,
                      isLoading: _isWhatsApping,
                      onPressed: () => _sendWhatsApp(order, customer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PdfActionButton(
                      label: isUrdu ? 'پی ڈی ایف' : 'PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      isLoading: _isPdfSharing,
                      onPressed: () => _shareAsPdf(order, customer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    },
  ),
);
  }
}

class _TapeStripePainter extends CustomPainter {
  const _TapeStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.fill;
    final darkPaint = Paint()
      ..color = const Color(0xFF1A0A00)
      ..style = PaintingStyle.fill;

    const double blockWidth = 10.0;
    const double gapWidth = 2.0;
    double x = 0;
    bool isGold = true;

    while (x < size.width) {
      final width = isGold ? blockWidth : gapWidth;
      final rect = Rect.fromLTWH(x, 0, width, size.height);
      canvas.drawRect(rect, isGold ? goldPaint : darkPaint);
      x += width;
      isGold = !isGold;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// BACK BUTTON
class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0x0DFFFFFF) : const Color(0x0D000000);
    final btnBorder = isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000);
    final iconColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF4A5568);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: btnBg,
          border: Border.all(color: btnBorder, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back_rounded,
            color: iconColor,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ACTION BUTTON WIDGETS
class _OutlineActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  const _OutlineActionButton({
    required this.label,
    required this.icon,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  State<_OutlineActionButton> createState() => _OutlineActionButtonState();
}

class _OutlineActionButtonState extends State<_OutlineActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000);
    final btnBorder = isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000);
    final btnText = isDark ? const Color(0xFF8AA0C8) : const Color(0xFF4A5568);
    final iconColor = isDark ? const Color(0xFF8AA0B8) : const Color(0xFF4A5568);

    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: widget.isLoading ? null : (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      onTapCancel: widget.isLoading ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: btnBg,
            border: Border.all(color: btnBorder, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(btnText),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 16, color: iconColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: btnText,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _WhatsAppActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  const _WhatsAppActionButton({
    required this.label,
    required this.icon,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  State<_WhatsAppActionButton> createState() => _WhatsAppActionButtonState();
}

class _WhatsAppActionButtonState extends State<_WhatsAppActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: widget.isLoading ? null : (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      onTapCancel: widget.isLoading ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0x1425D366),
            border: Border.all(color: const Color(0x3325D366), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 16, color: const Color(0xFF25D366)),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF25D366),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PdfActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PdfActionButton({
    required this.label,
    required this.icon,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  State<_PdfActionButton> createState() => _PdfActionButtonState();
}

class _PdfActionButtonState extends State<_PdfActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: widget.isLoading ? null : (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      onTapCancel: widget.isLoading ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0x1A5B72F5),
            border: Border.all(color: const Color(0x335B72F5), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B72F5)),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 16, color: const Color(0xFF5B72F5)),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5B72F5),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A0A00),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
