import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/payments/currency_utils.dart';
import '../../core/payments/payment_provider.dart';
import '../../core/payments/payment_registry.dart';
import '../../core/services/subscription_service.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/image_compressor.dart';
import '../../shared/providers/subscription_provider.dart';
import '../../shared/providers/supabase_providers.dart';

/// Provider-driven Unified Payment Screen.
/// Follows the 5-step wizard:
///   Step 1 — Amount & Plan Summary
///   Step 2 — Provider Selection (with Instant vs Review badges)
///   Step 3 — Provider-Specific Flow (Stripe Sheet or Manual Receipt Form)
///   Step 4 — Waiting / Polling (web & desktop Checkout path only)
///   Step 5 — Result Screen (Instant Succeeded vs Awaiting Review)
class SubscriptionPaymentScreen extends ConsumerStatefulWidget {
  final PaymentPurpose purpose;
  final Map<String, dynamic>? planData;
  final Map<String, dynamic>? extraData;

  const SubscriptionPaymentScreen({
    super.key,
    this.purpose = PaymentPurpose.subscriptionMonthly,
    this.planData,
    this.extraData,
  });

  @override
  ConsumerState<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState
    extends ConsumerState<SubscriptionPaymentScreen> {
  // Wizard step: 0 = Summary, 1 = Provider Selection, 2 = Provider Flow,
  //             3 = Waiting (web/desktop Checkout), 4 = Result
  int _currentStep = 0;

  // Amount & Locale
  int _amountMinor = 0;
  String _currency = 'PKR';
  String _countryCode = 'PK';
  String _targetPlanCode = 'basic';
  bool _isLoadingPrice = true;

  // Providers from Registry
  List<PaymentProvider> _availableProviders = [];
  PaymentProvider? _selectedProvider;

  // Manual payment state
  final _txIdCtrl = TextEditingController();
  String _selectedManualMethod = 'Easypaisa';
  Uint8List? _screenshotBytes;
  String _screenshotFilename = '';

  // Execution state
  bool _isProcessing = false;
  String? _errorMessage;
  PaymentSession? _resultSession;

  // Checkout Session polling state (web & desktop)
  // _checkoutSession is set once and never replaced — double-tap guard.
  PaymentSession? _checkoutSession;
  Timer? _pollingTimer;
  int _pollCount = 0;
  bool _pollTimedOut = false;
  static const int _maxPollCount = 200; // 200 × 3 s = 10 min

  static const List<String> _manualMethods = [
    'Easypaisa',
    'JazzCash',
    'Bank Transfer',
    'HBL',
    'Meezan Bank',
    'UBL',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadPricingAndProviders();
  }

  @override
  void dispose() {
    _txIdCtrl.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPricingAndProviders() async {
    setState(() {
      _isLoadingPrice = true;
      _errorMessage = null;
    });

    try {
      final shopId = ref.read(currentShopIdProvider);
      final client = Supabase.instance.client;

      // 1. Fetch shop locale preferences
      if (shopId != null) {
        final shopRes = await client
            .from('shops')
            .select('country_code, preferred_currency, plan_code')
            .eq('id', shopId)
            .maybeSingle();

        if (shopRes != null) {
          _countryCode = (shopRes['country_code'] as String?) ?? 'PK';
          _currency = (shopRes['preferred_currency'] as String?) ?? 'PKR';
        }
      }

      // 2. Resolve target plan code / pricing
      String targetPlanCode = 'basic';
      if (widget.purpose == PaymentPurpose.foundingActivation) {
        targetPlanCode = 'founding';
      } else if (widget.purpose == PaymentPurpose.storageMonthly) {
        targetPlanCode = 'storage_monthly';
      } else if (widget.purpose == PaymentPurpose.storageAnnual) {
        targetPlanCode = 'storage_annual';
      } else {
        targetPlanCode = widget.planData?['code'] as String? ??
            ref.read(subscriptionStateProvider).valueOrNull?.planCode ??
            'basic';
      }
      _targetPlanCode = targetPlanCode;

      // 3. Lookup price in minor units from plan_prices
      final priceRow = await client
          .from('plan_prices')
          .select('amount_minor')
          .eq('plan_code', targetPlanCode)
          .eq('currency', _currency.toUpperCase())
          .maybeSingle();

      if (priceRow != null && priceRow['amount_minor'] != null) {
        _amountMinor = (priceRow['amount_minor'] as num).toInt();
      } else {
        // Fallback: PKR default
        if (widget.purpose == PaymentPurpose.foundingActivation) {
          final setting = await client
              .from('app_settings')
              .select('value')
              .eq('key', 'founding_activation_fee')
              .maybeSingle();
          final feeMajor = int.tryParse(setting?['value']?.toString() ?? '35000') ?? 35000;
          _amountMinor = feeMajor * 100;
        } else if (widget.purpose == PaymentPurpose.storageMonthly) {
          final pkr = (widget.planData?['price_pkr'] as int?) ?? 250;
          _amountMinor = pkr * 100;
        } else if (widget.purpose == PaymentPurpose.storageAnnual) {
          final pkr = (widget.planData?['price_pkr'] as int?) ?? 2500;
          _amountMinor = pkr * 100;
        } else {
          final planPkr = (widget.planData?['price_pkr'] as int?) ??
              ref.read(subscriptionStateProvider).valueOrNull?.planPricePkr ??
              500;
          _amountMinor = planPkr * 100;
        }
      }

      // 4. Fetch available providers from registry
      _availableProviders = await PaymentRegistry.availableFor(
        countryCode: _countryCode,
        currency: _currency,
      );

      if (_availableProviders.length == 1) {
        _selectedProvider = _availableProviders.first;
      }
    } catch (e) {
      debugPrint('Error loading payment configuration: $e');
      _amountMinor = 50000; // default 500 PKR
      _availableProviders = await PaymentRegistry.availableFor(
        countryCode: 'PK',
        currency: 'PKR',
      );
      if (_availableProviders.isNotEmpty) {
        _selectedProvider = _availableProviders.first;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrice = false;
        });
      }
    }
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
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not pick image: $e');
    }
  }

  Future<void> _executePayment() async {
    // Double-tap guard: if a checkout session already exists, do not create a second one.
    if (_checkoutSession != null) return;

    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) {
      setState(() => _errorMessage = 'Shop not identified. Please log in.');
      return;
    }

    final provider = _selectedProvider;
    if (provider == null) {
      setState(() => _errorMessage = 'Please select a payment provider.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (provider.code == 'stripe') {
        final session = await provider.createPayment(
          shopId: shopId,
          amountMinor: _amountMinor,
          currency: _currency,
          purpose: widget.purpose,
          metadata: {
            'plan_code': _targetPlanCode,
            'extra_data': widget.extraData,
          },
        );

        if (session.status == PaymentStatus.pending && session.redirectUrl != null) {
          // Web / Desktop: URL was already launched by the provider.
          // Move to the waiting/polling step.
          setState(() {
            _isProcessing = false;
            _checkoutSession = session;
            _currentStep = 3; // Waiting step
            _pollCount = 0;
            _pollTimedOut = false;
          });
          _startPolling(session.providerReference);
          return;
        }

        if (session.status == PaymentStatus.succeeded) {
          // Mobile Payment Sheet: succeeded synchronously
          ref.invalidate(currentShopProvider);
          ref.invalidate(profileProvider);
          ref.read(subscriptionStateProvider.notifier).refresh();
          setState(() {
            _isProcessing = false;
            _resultSession = session;
            _currentStep = 4; // Result step
          });
        } else if (session.status == PaymentStatus.cancelled) {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Payment was cancelled.';
          });
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = session.metadata?['error']?.toString() ??
                'Payment could not be completed. Please try again or choose another method.';
          });
        }
      } else {
        // Manual Provider flow
        if (_screenshotBytes == null) {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Please attach a payment receipt screenshot.';
          });
          return;
        }

        final screenshotUrl =
            await SubscriptionService.instance.uploadPaymentScreenshot(
          shopId: shopId,
          bytes: _screenshotBytes!,
          filename: _screenshotFilename.isNotEmpty
              ? _screenshotFilename
              : 'manual_receipt.jpg',
        );

        final session = await provider.createPayment(
          shopId: shopId,
          amountMinor: _amountMinor,
          currency: _currency,
          purpose: widget.purpose,
          metadata: {
            'receipt_url': screenshotUrl,
            'manual_transaction_id': _txIdCtrl.text.trim(),
            'payment_method': _selectedManualMethod,
            'plan_code': _targetPlanCode,
            if (widget.extraData != null) 'extra_data': widget.extraData,
          },
        );

        setState(() {
          _isProcessing = false;
          _resultSession = session;
          _currentStep = 4; // Result step
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Polls the payment status every 3 seconds until succeeded, failed,
  /// cancelled, or [_maxPollCount] polls elapsed (10 minutes).
  /// [paymentId] is the unified_payments UUID.
  void _startPolling(String paymentId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _pollCount++;

      if (_pollCount >= _maxPollCount) {
        timer.cancel();
        if (mounted) setState(() => _pollTimedOut = true);
        return;
      }

      try {
        final provider = _selectedProvider;
        if (provider == null) return;
        final status = await provider.checkStatus(paymentId);

        if (!mounted) return;

        if (status == PaymentStatus.succeeded) {
          timer.cancel();
          ref.invalidate(currentShopProvider);
          ref.invalidate(profileProvider);
          ref.read(subscriptionStateProvider.notifier).refresh();
          setState(() {
            _resultSession =
                _checkoutSession?.copyWith(status: PaymentStatus.succeeded);
            _currentStep = 4; // Result step
          });
        } else if (status == PaymentStatus.failed ||
            status == PaymentStatus.cancelled) {
          timer.cancel();
          setState(() {
            _errorMessage = 'Payment ${status.name}. Please try again.';
            _checkoutSession = null;
            _currentStep = 2; // Back to provider flow step
          });
        }
        // pending / processing → keep polling
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: text1,
          onPressed: () {
            if (_currentStep == 3) {
              // Waiting step: cancel polling and return to provider flow
              _pollingTimer?.cancel();
              setState(() {
                _checkoutSession = null;
                _pollTimedOut = false;
                _currentStep = 2;
              });
            } else if (_currentStep > 0 && _currentStep < 4) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          isUrdu ? 'ادائیگی مکمل کریں' : 'Complete Payment',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: text1,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoadingPrice
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step Indicator — only show for steps 0-2
                        if (_currentStep < 3)
                          _StepProgressIndicator(
                            currentStep: _currentStep,
                            totalSteps: 3,
                            isUrdu: isUrdu,
                          ),
                        const SizedBox(height: 20),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.red, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Step Content
                        if (_currentStep == 0)
                          _buildStep1Summary(isUrdu, surface, border, text1, text2)
                        else if (_currentStep == 1)
                          _buildStep2ProviderSelection(isUrdu, surface, border, text1, text2)
                        else if (_currentStep == 2)
                          _buildStep3ProviderFlow(isUrdu, surface, border, text1, text2)
                        else if (_currentStep == 3)
                          _buildStep4Waiting(isUrdu, surface, border, text1, text2)
                        else
                          _buildStep5Result(isUrdu, surface, border, text1, text2),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── STEP 1: AMOUNT SUMMARY ────────────────────────────────────────────────
  Widget _buildStep1Summary(
      bool isUrdu, Color surface, Color border, Color text1, Color text2) {
    final title = isUrdu ? widget.purpose.displayTitleUr : widget.purpose.displayTitleEn;
    final planName = widget.planData != null
        ? (isUrdu
            ? (widget.planData!['name_ur']?.toString() ?? '')
            : (widget.planData!['name_en']?.toString() ?? ''))
        : '';

    final priceFormatted = CurrencyUtils.formatMinor(_amountMinor, _currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isUrdu ? 'خلاصہ آرڈر' : 'Order Summary',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _currency.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: text2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: text1,
                ),
              ),
              if (planName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Plan: $planName',
                  style: GoogleFonts.inter(fontSize: 13, color: text2),
                ),
              ],
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isUrdu ? 'کل رقم' : 'Total Amount Due',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: text2,
                    ),
                  ),
                  Text(
                    priceFormatted,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emerald,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              // If only 1 provider exists, auto select and advance to Step 3
              if (_availableProviders.length == 1) {
                setState(() {
                  _selectedProvider = _availableProviders.first;
                  _currentStep = 2;
                });
              } else {
                setState(() => _currentStep = 1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF1A0A00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              isUrdu ? 'ادائیگی کا طریقہ منتخب کریں' : 'Choose Payment Method',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 2: PROVIDER SELECTION ────────────────────────────────────────────
  Widget _buildStep2ProviderSelection(
      bool isUrdu, Color surface, Color border, Color text1, Color text2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isUrdu ? 'ادائیگی کا ذریعہ منتخب کریں' : 'Select Payment Provider',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: text1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isUrdu
              ? 'اپنے لیے سب سے آسان آپشن منتخب کریں۔ کارڈ یا آن لائن ٹرانسفر۔'
              : 'Choose the most convenient option for your business.',
          style: GoogleFonts.inter(fontSize: 13, color: text2),
        ),
        const SizedBox(height: 20),

        // Providers List
        ..._availableProviders.map((provider) {
          final isSelected = _selectedProvider?.code == provider.code;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedProvider = provider);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        provider.isInstant
                            ? Icons.credit_card_rounded
                            : Icons.account_balance_rounded,
                        color: isSelected ? AppColors.accent : text2,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.displayName,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: text1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: provider.isInstant
                                  ? AppColors.emerald.withValues(alpha: 0.12)
                                  : AppColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              provider.isInstant
                                  ? (isUrdu ? '⚡ فوری ایکٹیویشن' : '⚡ Instant Activation')
                                  : (isUrdu
                                      ? '🕒 ریویو کے بعد ایکٹیویٹ ہوگا'
                                      : '🕒 Review Required (1–2 hrs)'),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: provider.isInstant
                                    ? AppColors.emerald
                                    : AppColors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.accent : border,
                          width: isSelected ? 6 : 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedProvider == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    setState(() => _currentStep = 2);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF1A0A00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              isUrdu ? 'جاری رکھیں' : 'Continue to Payment',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 3: PROVIDER SPECIFIC FLOW ────────────────────────────────────────
  Widget _buildStep3ProviderFlow(
      bool isUrdu, Color surface, Color border, Color text1, Color text2) {
    final provider = _selectedProvider!;
    final priceFormatted = CurrencyUtils.formatMinor(_amountMinor, _currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provider info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(
                provider.isInstant
                    ? Icons.credit_card_rounded
                    : Icons.account_balance_rounded,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                provider.displayName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: text1,
                ),
              ),
              const Spacer(),
              if (_availableProviders.length > 1)
                TextButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  child: Text(
                    isUrdu ? 'تبدیل کریں' : 'Change',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Stripe Card Flow ──
        if (provider.code == 'stripe') ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    color: AppColors.emerald, size: 40),
                const SizedBox(height: 12),
                Text(
                  isUrdu ? 'محفوظ کارڈ پیمنٹ' : 'Secure Card Checkout',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: text1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isUrdu
                      ? 'سٹرائپ کے ذریعے ویزا، ماسٹر کارڈ، اور ڈیبٹ کارڈ سے فوری ادائیگی کریں۔'
                      : 'Pay instantly with Visa, Mastercard, or debit card via Stripe.',
                  style: GoogleFonts.inter(fontSize: 13, color: text2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      priceFormatted,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _executePayment,
              icon: _isProcessing
                  ? const SizedBox.shrink()
                  : const Icon(Icons.payment_rounded, size: 20),
              label: _isProcessing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A0A00),
                      ),
                    )
                  : Text(
                      isUrdu
                          ? '$priceFormatted ادا کریں'
                          : 'Pay $priceFormatted via Card',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ]

        // ── Manual Provider Flow ──
        else ...[
          _InstructionsCard(
            surface: surface,
            border: border,
            text1: text1,
            text2: text2,
            isUrdu: isUrdu,
          ),
          const SizedBox(height: 20),

          // Payment Method Selector
          Text(
            (isUrdu ? 'ادائیگی کا ذریعہ' : 'Transfer Method').toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text2,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedManualMethod,
            style: GoogleFonts.inter(fontSize: 13, color: text1),
            decoration: InputDecoration(
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
            ),
            items: _manualMethods
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedManualMethod = v);
            },
          ),
          const SizedBox(height: 16),

          // Transaction ID / Reference
          Text(
            (isUrdu ? 'ٹرانزیکشن ID یا حوالہ نمبر' : 'Transaction ID / Reference')
                .toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text2,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _txIdCtrl,
            style: GoogleFonts.jetBrainsMono(fontSize: 13, color: text1),
            decoration: InputDecoration(
              hintText: isUrdu ? 'مثلاً TID 123456789' : 'e.g. TID 123456789',
              hintStyle: GoogleFonts.inter(color: text2.withValues(alpha: 0.6)),
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Screenshot Upload
          Text(
            (isUrdu ? 'ادائیگی کا سکرین شاٹ / رسید *' : 'Payment Screenshot *')
                .toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text2,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickScreenshot,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _screenshotBytes != null
                    ? AppColors.emerald.withValues(alpha: 0.08)
                    : surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _screenshotBytes != null
                      ? AppColors.emerald.withValues(alpha: 0.5)
                      : border,
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
                          isUrdu ? 'رسید کی تصویر اپلوڈ کریں' : 'Upload Receipt Screenshot',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: text1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _executePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: const Color(0xFF1A0A00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A0A00),
                      ),
                    )
                  : Text(
                      isUrdu ? 'ادائیگی جمع کروائیں' : 'Submit for Review',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  // ── STEP 4: WAITING / POLLING (WEB & DESKTOP CHECKOUT) ──────────────────────
  Widget _buildStep4Waiting(
      bool isUrdu, Color surface, Color border, Color text1, Color text2) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isUrdu ? 'ادائیگی کا انتظار ہے…' : 'Waiting for payment…',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: text1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isUrdu
                  ? 'ہم نے آپ کے براؤزر میں سٹرائپ پیمنٹ پیج کھول دیا ہے۔ وہاں ادائیگی مکمل کر کے یہاں واپس آئیں۔'
                  : 'We opened the Stripe payment page in your browser. Complete payment there, then return here.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: text2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.emerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUrdu
                        ? 'خودکار تصدیق جاری ہے (ہر 3 سیکنڈ بعد)'
                        : 'Checking payment status every 3 seconds…',
                    style: GoogleFonts.inter(fontSize: 12, color: text2),
                  ),
                ],
              ),
            ),
            if (_pollTimedOut) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isUrdu
                            ? 'کافی وقت گزر چکا ہے۔ اگر آپ ادائیگی کر چکے ہیں تو تھوڑا انتظار فرمائیں، یا دوبارہ لنک کھولیں۔'
                            : 'Still waiting? If you already completed payment, it may take a moment to sync. You can re-open the page or cancel.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: text1,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Re-open checkout button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final url = _checkoutSession?.redirectUrl;
                  if (url != null) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  isUrdu ? 'پیمنٹ پیج دوبارہ کھولیں' : 'Open payment page again',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: const Color(0xFF1A0A00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  _pollingTimer?.cancel();
                  setState(() {
                    _checkoutSession = null;
                    _pollTimedOut = false;
                    _currentStep = 2; // Return to provider flow
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isUrdu ? 'منسوخ کریں' : 'Cancel & Return',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: text2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 5: RESULT SCREEN ─────────────────────────────────────────────────
  Widget _buildStep5Result(
      bool isUrdu, Color surface, Color border, Color text1, Color text2) {
    final isInstantSuccess = _resultSession?.status == PaymentStatus.succeeded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isInstantSuccess
                    ? AppColors.emerald.withValues(alpha: 0.15)
                    : AppColors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isInstantSuccess ? Icons.check_circle_rounded : Icons.schedule_rounded,
                color: isInstantSuccess ? AppColors.emerald : AppColors.blue,
                size: 46,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isInstantSuccess
                  ? (isUrdu ? 'ادائیگی کامیاب! سبسکرپشن ایکٹیو ہوگئی' : 'Payment Successful!')
                  : (isUrdu
                      ? 'ادائیگی ریویو کے لیے بھیج دی گئی ہے'
                      : 'Payment Submitted for Review'),
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: text1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isInstantSuccess
                  ? (isUrdu
                      ? 'آپ کی سبسکرپشن فوراً ایکٹیویٹ کر دی گئی ہے۔ آپ بلا تعطل کام جاری رکھ سکتے ہیں۔'
                      : 'Your plan has been activated immediately. Thank you for using Darzi Pro!')
                  : (isUrdu
                      ? 'ہماری ٹیم جلد آپ کی رسید کی تصدیق کر کے اکاؤنٹ ایکٹیویٹ کر دے گی (عام طور پر 1 سے 2 گھنٹوں میں)۔'
                      : 'Our team will review and approve your submission within 1–2 hours. Your work continues uninterrupted.'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: text2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (_resultSession?.providerReference != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ref: ${_resultSession!.providerReference}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: text2),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: _resultSession!.providerReference));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reference ID copied!')),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 14),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: const Color(0xFF1A0A00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isUrdu ? 'ڈیش بورڈ پر جائیں' : 'Back to Dashboard',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

// ── Step Progress Indicator ─────────────────────────────────────────────────
class _StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isUrdu;

  const _StepProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.isUrdu,
  });

  @override
  Widget build(BuildContext context) {
    final labels = isUrdu
        ? ['خلاصہ', 'طریقہ کار', 'ادائیگی']
        : ['Summary', 'Method', 'Payment'];

    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.emerald
                            : (isActive ? AppColors.accent : Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? AppColors.accent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < totalSteps - 1) const SizedBox(width: 8),
            ],
          ),
        );
      }),
    );
  }
}

// ── Manual Payment Instructions Card ────────────────────────────────────────
class _InstructionsCard extends StatelessWidget {
  final Color surface;
  final Color border;
  final Color text1;
  final Color text2;
  final bool isUrdu;

  const _InstructionsCard({
    required this.surface,
    required this.border,
    required this.text1,
    required this.text2,
    required this.isUrdu,
  });

  @override
  Widget build(BuildContext context) {
    final steps = isUrdu
        ? [
            '1. نیچے دیے گئے اکاؤنٹ پر مطلوبہ رقم ٹرانسفر کریں۔',
            '2. ٹرانزیکشن کی رسید یا سکرین شاٹ محفوظ کریں۔',
            '3. سکرین شاٹ اپلوڈ کر کے TID درج کریں۔',
            '4. سبمٹ کرنے پر ایڈمن کی طرف سے تصدیق کر دی جائے گی۔',
          ]
        : [
            '1. Transfer the amount via Easypaisa, JazzCash, or Bank.',
            '2. Save your transaction receipt or screenshot.',
            '3. Upload the screenshot and enter the TID below.',
            '4. Admin verifies and activates your account within 1–2 hours.',
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'ہدایات برائے ادائیگی' : 'Bank Transfer Details',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: text1,
            ),
          ),
          const SizedBox(height: 10),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                s,
                style: GoogleFonts.inter(fontSize: 12, color: text2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
