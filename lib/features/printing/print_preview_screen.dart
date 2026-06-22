import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import 'pdf_builder.dart';

class PrintPreviewScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PrintPreviewScreen({super.key, required this.orderId});

  @override
  ConsumerState<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends ConsumerState<PrintPreviewScreen> {
  PrintLayout _layout = PrintLayout.a4;
  bool _isGenerating = false;

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

  Future<void> _shareAsPdf(OrderModel order, CustomerModel? customer, bool isUrdu) async {
    setState(() => _isGenerating = true);
    try {
      final List<int> bytes;
      if (_layout == PrintLayout.a4) {
        bytes = await DarziPdfBuilder.buildA4(order, customer, isUrdu: isUrdu);
      } else if (_layout == PrintLayout.traditional) {
        final customerMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
        final measurement = customerMeasurements
            .where((m) => m.customerId == order.customerId && m.category == MeasurementCategory.men)
            .firstOrNull;
        bytes = await DarziPdfBuilder.buildTraditionalNaapCard(order, customer, measurement);
      } else {
        bytes = await DarziPdfBuilder.buildThermal(order, customer, isUrdu: isUrdu);
      }
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'application/pdf',
        name: 'Order_${order.tokenNumber}.pdf',
      );
      await Share.shareXFiles([file],
          text: '📋 Darzi Pro — ${order.customerName} ka order card');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
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
    
    // Check if app language is Urdu
    final isUrdu = ref.watch(localeProvider) == 'ur';

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
            Text(isUrdu ? 'پرنٹ اور شیئر' : 'Print & Share',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w900, color: t1)),
            Text('${order.tokenNumber} · ${order.customerName}',
                style: GoogleFonts.inter(fontSize: 12, color: t2)),
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
                  onTap: () => setState(() => _layout = PrintLayout.a4),
                ),
                const SizedBox(width: 8),
                _LayoutBtn(
                  emoji: '🧾',
                  label: isUrdu ? 'تھرمل 80mm' : 'Thermal 80mm',
                  isActive: _layout == PrintLayout.thermal,
                  onTap: () => setState(() => _layout = PrintLayout.thermal),
                ),
                const SizedBox(width: 8),
                _LayoutBtn(
                  emoji: '📜',
                  label: isUrdu ? 'روایتی کارڈ' : 'Traditional Card',
                  isActive: _layout == PrintLayout.traditional,
                  onTap: () => setState(() => _layout = PrintLayout.traditional),
                ),
              ],
            ),
          ),

          // PDF Preview
          Expanded(
            child: PdfPreview(
              key: ValueKey('${_layout.name}_$isUrdu'),
              build: (format) async {
                if (_layout == PrintLayout.a4) {
                  final bytes = await DarziPdfBuilder.buildA4(order, customer, isUrdu: isUrdu);
                  return Uint8List.fromList(bytes);
                } else if (_layout == PrintLayout.traditional) {
                  final customerMeasurements = ref.watch(measurementsProvider).valueOrNull ?? [];
                  final measurement = customerMeasurements
                      .where((m) => m.customerId == order.customerId && m.category == MeasurementCategory.men)
                      .firstOrNull;
                  final bytes = await DarziPdfBuilder.buildTraditionalNaapCard(order, customer, measurement);
                  return Uint8List.fromList(bytes);
                } else {
                  final bytes = await DarziPdfBuilder.buildThermal(order, customer, isUrdu: isUrdu);
                  return Uint8List.fromList(bytes);
                }
              },
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName: 'Darzi_${order.tokenNumber}.pdf',
              actions: const [],
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
                    onTap: () async {
                      final List<int> bytes;
                      if (_layout == PrintLayout.a4) {
                        bytes = await DarziPdfBuilder.buildA4(order, customer, isUrdu: isUrdu);
                      } else if (_layout == PrintLayout.traditional) {
                        final customerMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
                        final measurement = customerMeasurements
                            .where((m) => m.customerId == order.customerId && m.category == MeasurementCategory.men)
                            .firstOrNull;
                        bytes = await DarziPdfBuilder.buildTraditionalNaapCard(order, customer, measurement);
                      } else {
                        bytes = await DarziPdfBuilder.buildThermal(order, customer, isUrdu: isUrdu);
                      }
                      await Printing.layoutPdf(
                          onLayout: (_) async => Uint8List.fromList(bytes));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    emoji: '📥',
                    label: isUrdu ? 'شیئر پی ڈی ایف' : 'Share PDF',
                    color: AppColors.blue,
                    onTap: _isGenerating ? null : () => _shareAsPdf(order, customer, isUrdu),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    emoji: '📱',
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _sendWhatsApp(order, customer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf2 = isDark ? AppColors.surf2Dark : AppColors.surf2Light;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentS : surf2,
            border: Border.all(
              color: isActive ? (isDark ? AppColors.accent : AppColors.accentL) : border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? (isDark ? AppColors.accent : AppColors.accentL) : t2,
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
  final VoidCallback? onTap;

  const _ActionButton({
    required this.emoji,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
