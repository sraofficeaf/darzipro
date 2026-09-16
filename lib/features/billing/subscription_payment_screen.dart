import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/services/subscription_service.dart';
import '../../core/utils/image_compressor.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/providers/subscription_provider.dart';

/// Manual payment submission screen.
/// Structure: swappable — this is the ManualPaymentProvider.
/// Replace with PayFast/PayPro integration without changing UI code.
class SubscriptionPaymentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? planData;
  const SubscriptionPaymentScreen({super.key, this.planData});

  @override
  ConsumerState<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState
    extends ConsumerState<SubscriptionPaymentScreen> {
  final _txIdCtrl = TextEditingController();
  String _selectedMethod = 'Easypaisa';
  Uint8List? _screenshotBytes;
  String _screenshotFilename = '';
  bool _isSubmitting = false;
  String? _error;
  bool _submitted = false;

  static const List<String> _methods = [
    'Easypaisa',
    'JazzCash',
    'Bank Transfer',
    'HBL',
    'UBL',
    'Other',
  ];

  @override
  void dispose() {
    _txIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final compressed = await ImageCompressor.compressImageBytes(bytes);
      setState(() {
        _screenshotBytes = compressed ?? bytes;
        _screenshotFilename = picked.name;
      });
    } catch (e) {
      setState(() => _error = 'Could not pick image: $e');
    }
  }

  Future<void> _submit() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;

    final sub = ref.read(subscriptionStateProvider).valueOrNull;
    final plan = widget.planData;
    if (plan == null && sub == null) return;

    final planCode = (plan?['code'] as String?) ?? sub!.planCode;
    final price = (plan?['price_pkr'] as int?) ?? sub!.planPricePkr;

    if (_screenshotBytes == null) {
      setState(() => _error = 'Please attach a payment screenshot');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // 1. Upload screenshot
      final screenshotUrl =
          await SubscriptionService.instance.uploadPaymentScreenshot(
        shopId: shopId,
        bytes: _screenshotBytes!,
        filename: _screenshotFilename.isNotEmpty
            ? _screenshotFilename
            : 'screenshot.jpg',
      );

      // 2. Submit payment record
      final result = await SubscriptionService.instance.submitPayment(
        shopId: shopId,
        planCode: planCode,
        amountPkr: price,
        paymentMethod: _selectedMethod,
        transactionId: _txIdCtrl.text.trim(),
        screenshotUrl: screenshotUrl,
      );

      if (result['success'] == true) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      } else {
        setState(() {
          _isSubmitting = false;
          _error = result['error'] as String? ?? 'Submission failed';
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final isDark = context.isDark;

    final bg = context.bg;
    final surface = isDark ? const Color(0x0DFFFFFF) : Colors.white;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final plan = widget.planData;
    final subAsync = ref.watch(subscriptionStateProvider);
    final planName = plan != null
        ? (isUrdu ? plan['name_ur'] as String : plan['name_en'] as String)
        : (subAsync.valueOrNull?.let((s) => isUrdu ? s.planNameUr : s.planNameEn) ?? '');
    final planPrice = (plan?['price_pkr'] as int?) ??
        subAsync.valueOrNull?.planPricePkr ??
        0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _submitted
            ? _SuccessView(isUrdu: isUrdu, text1: text1, text2: text2)
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0x0DFFFFFF)
                                      : surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: border),
                                ),
                                child: Icon(Icons.arrow_back_rounded,
                                    color: text2, size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isUrdu ? 'Subscription Payment' : 'Subscription Payment',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: text1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Plan summary card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accent.withValues(alpha: 0.1),
                                AppColors.blue.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Text('📋',
                                  style: TextStyle(fontSize: 28)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    Text(
                                      isUrdu
                                          ? 'Monthly subscription'
                                          : 'Monthly subscription',
                                      style: GoogleFonts.inter(
                                          fontSize: 12, color: text2),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Rs ${NumberFormat('#,###').format(planPrice)}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Payment instructions
                        _SectionLabel(
                            label: isUrdu
                                ? 'Payment kaise karein'
                                : 'How to pay',
                            text2: text2),
                        const SizedBox(height: 10),
                        _InstructionsCard(isDark: isDark, surface: surface, border: border, text1: text1, text2: text2),
                        const SizedBox(height: 24),

                        // Payment method
                        _SectionLabel(
                            label: isUrdu
                                ? 'Payment method'
                                : 'Payment Method',
                            text2: text2),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedMethod,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: text1),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: surface,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: border),
                            ),
                          ),
                          items: _methods
                              .map((m) => DropdownMenuItem(
                                  value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedMethod = v);
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Transaction ID
                        _SectionLabel(
                            label: isUrdu
                                ? 'Transaction ID (optional)'
                                : 'Transaction ID (optional)',
                            text2: text2),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _txIdCtrl,
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 13, color: text1),
                          decoration: InputDecoration(
                            hintText: isUrdu
                                ? 'TID ya reference number'
                                : 'TID or reference number',
                            hintStyle: GoogleFonts.inter(
                                color: text2.withValues(alpha: 0.6)),
                            filled: true,
                            fillColor: surface,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Screenshot
                        _SectionLabel(
                            label: isUrdu
                                ? 'Payment screenshot *'
                                : 'Payment screenshot *',
                            text2: text2),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _pickScreenshot,
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _screenshotBytes != null
                                  ? AppColors.teal.withValues(alpha: 0.06)
                                  : surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _screenshotBytes != null
                                    ? AppColors.teal.withValues(alpha: 0.4)
                                    : AppColors.accent.withValues(alpha: 0.3),
                                style: _screenshotBytes != null
                                    ? BorderStyle.solid
                                    : BorderStyle.solid,
                              ),
                            ),
                            child: _screenshotBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _screenshotBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_upload_outlined,
                                          color: AppColors.accent, size: 32),
                                      const SizedBox(height: 6),
                                      Text(
                                        isUrdu
                                            ? 'Screenshot attach karein'
                                            : 'Attach screenshot',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        // Error
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.red),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: const Color(0xFF1A0A00),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1A0A00),
                                    ),
                                  )
                                : Text(
                                    isUrdu
                                        ? 'Payment Submit Karein'
                                        : 'Submit Payment',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isUrdu
                              ? 'Admin 1-2 business days mein approve karega.'
                              : 'Admin will review and approve within 1-2 business days.',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: text2),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color text2;
  const _SectionLabel({required this.label, required this.text2});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: text2,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  final bool isDark;
  final Color surface;
  final Color border;
  final Color text1;
  final Color text2;

  const _InstructionsCard({
    required this.isDark,
    required this.surface,
    required this.border,
    required this.text1,
    required this.text2,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      '1. Apne bank app ya Easypaisa/JazzCash se payment karein',
      '2. Screenshot ya receipt lein',
      '3. Neeche screenshot attach karein aur Submit karein',
      '4. Admin 1-2 din mein approve karega',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x08FFFFFF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  s,
                  style: GoogleFonts.inter(fontSize: 12, color: text2),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final bool isUrdu;
  final Color text1;
  final Color text2;
  const _SuccessView(
      {required this.isUrdu, required this.text1, required this.text2});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              isUrdu ? 'Payment Submit Ho Gayi!' : 'Payment Submitted!',
              style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w800, color: text1),
            ),
            const SizedBox(height: 10),
            Text(
              isUrdu
                  ? 'Admin jaldi review karega. Tab tak aapka kaam jari hai.'
                  : 'Admin will review shortly. Your work continues in the meantime.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: text2, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: Text(
                isUrdu ? 'Dashboard par jaaein' : 'Go to Dashboard',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper extension
extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
