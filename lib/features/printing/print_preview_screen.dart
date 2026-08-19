import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/utils/share_helper.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import 'pdf_builder.dart';
import 'widgets/card_image_capturer.dart';
import 'widgets/naap_card_widget.dart';
import 'widgets/token_card_widget.dart';

class PrintPreviewScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PrintPreviewScreen({super.key, required this.orderId});

  @override
  ConsumerState<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends ConsumerState<PrintPreviewScreen> {
  PrintLayout _layout = PrintLayout.a4;

  // ── Pre-captured image cache ─────────────────────────────────────────────
  Uint8List? _naapCardPng;
  Uint8List? _tokenThermalPng;
  Uint8List? _tokenA4Png;
  bool _imageCaptureFailed = false;
  bool _isCapturing = false;

  bool _isPrinting = false;
  bool _isSharing = false;
  bool _isWhatsApping = false;
  final Map<PrintLayout, Uint8List> _pdfCache = {};

  Uint8List? get _currentImage {
    switch (_layout) {
      case PrintLayout.traditional:
        return _naapCardPng;
      case PrintLayout.thermal:
        return _tokenThermalPng;
      case PrintLayout.a4:
        return _tokenA4Png;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureActiveLayout());
  }

  void _switchLayout(PrintLayout layout) {
    if (_layout == layout) return;
    setState(() => _layout = layout);
    _captureActiveLayout();
  }

  Future<void> _captureActiveLayout() async {
    if (_currentImage != null || _isCapturing) return;
    final order = _getOrder();
    if (order == null) return;
    final customer = _getCustomer(order.customerId);
    final customerMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
    final measurement = customerMeasurements.where((m) => m.customerId == order.customerId).firstOrNull;

    final targetLayout = _layout;
    setState(() => _isCapturing = true);

    try {
      Uint8List? bytes;
      if (targetLayout == PrintLayout.traditional) {
        bytes = await CardImageCapturer.captureOnDemand(
          context,
          cardWidget: NaapCardWidget(
            order: order,
            customer: customer,
            measurement: measurement,
          ),
        );
      } else if (targetLayout == PrintLayout.thermal) {
        bytes = await CardImageCapturer.captureOnDemand(
          context,
          cardWidget: TokenCardWidget(
            order: order,
            customer: customer,
            isThermal: true,
          ),
        );
      } else {
        bytes = await CardImageCapturer.captureOnDemand(
          context,
          cardWidget: TokenCardWidget(
            order: order,
            customer: customer,
            isThermal: false,
          ),
        );
      }

      if (mounted) {
        setState(() {
          if (targetLayout == PrintLayout.traditional) _naapCardPng = bytes;
          if (targetLayout == PrintLayout.thermal) _tokenThermalPng = bytes;
          if (targetLayout == PrintLayout.a4) _tokenA4Png = bytes;
        });
      }
    } catch (e) {
      debugPrint('PrintPreviewScreen: image capture failed for $targetLayout — $e');
      if (mounted) setState(() => _imageCaptureFailed = true);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  OrderModel? _getOrder() {
    final ordersAsync = ref.watch(ordersProvider);
    return ordersAsync.whenOrNull(
      data: (orders) {
        try {
          return orders.firstWhere((o) => o.id == widget.orderId);
        } catch (_) {
          return null;
        }
      },
    );
  }

  CustomerModel? _getCustomer(String customerId) {
    final customersAsync = ref.watch(customersProvider);
    return customersAsync.whenOrNull(
      data: (customers) {
        try {
          return customers.firstWhere((c) => c.id == customerId);
        } catch (_) {
          return null;
        }
      },
    );
  }

  /// Builds PDF bytes purely from pre-captured images — cached per layout for instant response.
  Future<Uint8List> _generatePdfBytes(OrderModel order, CustomerModel? customer) async {
    if (_pdfCache.containsKey(_layout)) {
      return _pdfCache[_layout]!;
    }

    if (_currentImage == null) {
      await _captureActiveLayout();
    }
    if (_currentImage == null) {
      throw Exception('Preview image not ready. Please try again.');
    }

    final PdfPageFormat format;
    if (_layout == PrintLayout.traditional) {
      format = PdfPageFormat.a5;
    } else if (_layout == PrintLayout.thermal) {
      format = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity);
    } else {
      format = PdfPageFormat.a4;
    }

    final pdfBytes = await DarziPdfBuilder.buildPdfFromImageBytes(_currentImage!, pageFormat: format);
    final result = Uint8List.fromList(pdfBytes);
    _pdfCache[_layout] = result;
    return result;
  }

  Future<void> _handlePrint(OrderModel order, CustomerModel? customer) async {
    setState(() => _isPrinting = true);
    try {
      final bytes = await _generatePdfBytes(order, customer);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      debugPrint('PrintPreviewScreen: print layout failed — $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _shareAsPdf(OrderModel order, CustomerModel? customer) async {
    setState(() => _isSharing = true);
    try {
      final bytes = await _generatePdfBytes(order, customer);
      if (mounted) {
        await DarziShareHelper.shareOrSavePdf(
          context,
          pdfBytes: bytes,
          fileName: 'Order_${order.tokenNumber}.pdf',
          text: '📋 Darzi Pro — ${order.customerName} ka order card',
        );
      }
    } catch (e) {
      debugPrint('PrintPreviewScreen: share pdf failed — $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _sendWhatsApp(OrderModel order, CustomerModel? customer) async {
    setState(() => _isWhatsApping = true);
    try {
      final bytes = await _generatePdfBytes(order, customer);
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
      debugPrint('PrintPreviewScreen: whatsapp share failed — $e');
    } finally {
      if (mounted) setState(() => _isWhatsApping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _getOrder();
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Print Preview')),
        body: const EmptyState(emoji: '🔍', title: 'Order Not Found'),
      );
    }

    final customer = _getCustomer(order.customerId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final isUrdu = ref.watch(localeProvider) == 'ur';
    final bool isAnyBusy = _isPrinting || _isSharing || _isWhatsApping;

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
          backgroundColor: surf,
          leading: IconButton(
            icon: const Text('←', style: TextStyle(fontSize: 20)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isUrdu ? 'پرنٹ اور شیئر' : 'Print & Share', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: t1)),
              Text('${order.tokenNumber} · ${order.customerName}', style: GoogleFonts.inter(fontSize: 12, color: t2)),
            ],
          ),
        ),
        body: Column(
          children: [
                // Layout toggle
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _LayoutBtn(
                        emoji: '📄',
                        label: isUrdu ? 'A4 لے آؤٹ' : 'A4 Layout',
                        isActive: _layout == PrintLayout.a4,
                        onTap: () => _switchLayout(PrintLayout.a4),
                      ),
                      const SizedBox(width: 8),
                      _LayoutBtn(
                        emoji: '🧾',
                        label: isUrdu ? 'تھرمل 80mm' : 'Thermal 80mm',
                        isActive: _layout == PrintLayout.thermal,
                        onTap: () => _switchLayout(PrintLayout.thermal),
                      ),
                      const SizedBox(width: 8),
                      _LayoutBtn(
                        emoji: '📜',
                        label: isUrdu ? 'روایتی کارڈ' : 'Traditional Card',
                        isActive: _layout == PrintLayout.traditional,
                        onTap: () => _switchLayout(PrintLayout.traditional),
                      ),
                    ],
                  ),
                ),

                // Loading indicator while current layout is being captured
                if (_currentImage == null && _isCapturing)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFF5A623)),
                          SizedBox(height: 16),
                          Text('Preparing print preview…', style: TextStyle(color: Colors.white60)),
                        ],
                      ),
                    ),
                  )
                else if (_currentImage == null && _imageCaptureFailed)
                  const Expanded(
                    child: Center(
                      child: EmptyState(
                        emoji: '⚠️',
                        title: 'Preview failed',
                        subtitle: 'Could not render card. Please go back and try again.',
                      ),
                    ),
                  )
                else ...[
                  // Direct High-Performance Native Image Preview
                  Expanded(
                    child: InteractiveViewer(
                      maxScale: 3.0,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _currentImage!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Action bar
                  Container(
                    color: surf,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            emoji: '🖨️',
                            label: isUrdu ? 'پرنٹ' : 'Print',
                            color: AppColors.accent,
                            isLoading: _isPrinting,
                            onTap: _currentImage == null || isAnyBusy ? null : () => _handlePrint(order, customer),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            emoji: '📥',
                            label: isUrdu ? 'شیئر پی ڈی ایف' : 'Share PDF',
                            color: AppColors.blue,
                            isLoading: _isSharing,
                            onTap: _currentImage == null || isAnyBusy ? null : () => _shareAsPdf(order, customer),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            emoji: '📱',
                            label: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            isLoading: _isWhatsApping,
                            onTap: _currentImage == null || isAnyBusy ? null : () => _sendWhatsApp(order, customer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
  }
}

enum PrintLayout { a4, thermal, traditional }

class _LayoutBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LayoutBtn({
    required this.emoji,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF5A623) : const Color(0x12FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? const Color(0xFFF5A623) : const Color(0x22FFFFFF),
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.emoji,
    required this.label,
    required this.color,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
    );
  }
}
