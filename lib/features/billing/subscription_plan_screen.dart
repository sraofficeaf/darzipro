import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/payments/payment_provider.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/plan_price_formatter.dart';
import '../../shared/providers/subscription_provider.dart';
import '../../shared/providers/supabase_providers.dart';
import '../storage/storage_addon_modal.dart';
import 'widgets/usage_widget.dart';

/// Full "Plan & Billing" screen accessible from Settings → Plan & Billing.
/// Shows current plan, usage metrics, plan change options, and billing history.
class SubscriptionPlanScreen extends ConsumerStatefulWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  ConsumerState<SubscriptionPlanScreen> createState() =>
      _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState
    extends ConsumerState<SubscriptionPlanScreen> {
  bool _isChangingPlan = false;
  String? _changeError;

  @override
  Widget build(BuildContext context) {
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final isDark = context.isDark;

    final bg = context.bg;
    final text1 = context.text1;
    final text2 = context.text2;
    final text3 = context.text3;

    final subAsync = ref.watch(subscriptionStateProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);

    final sub = subAsync.valueOrNull;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _buildContent(context, ref, sub, plansAsync, isUrdu,
            isDark, text1, text2, text3),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    SubscriptionState? sub,
    AsyncValue<List<Map<String, dynamic>>> plansAsync,
    bool isUrdu,
    bool isDark,
    Color text1,
    Color text2,
    Color text3,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
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
                            : context.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.border),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: text2, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUrdu ? 'Plan & Billing' : 'Plan & Billing',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: text1,
                          ),
                        ),
                        Text(
                          isUrdu
                              ? 'Aapka subscription manage karein'
                              : 'Manage your subscription',
                          style: GoogleFonts.inter(fontSize: 12, color: text2),
                        ),
                      ],
                    ),
                  ),
                  // Refresh
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: text3, size: 20),
                    onPressed: () =>
                        ref.read(subscriptionStateProvider.notifier).refresh(),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Current Usage (Full Widget) ──
              if (sub != null && !sub.isLifetime) ...[
                UsageWidget(compact: false),
                const SizedBox(height: 24),
              ] else if (sub != null && sub.isLifetime) ...[
                _LifetimeBadge(isUrdu: isUrdu),
                const SizedBox(height: 24),
              ],

              // ── Pay Now (only if payment is actually due) ──
              if (sub != null &&
                  !sub.isLifetime &&
                  !sub.isFoundingFree &&
                  !sub.isTrial &&
                  sub.amountDuePkr > 0 &&
                  (sub.isGrace ||
                      sub.isReadOnly ||
                      sub.isExpiring ||
                      (sub.paymentStatus == 'pending' &&
                          (sub.cycleEnd == null ||
                              !sub.cycleEnd!.isAfter(DateTime.now()))))) ...[
                _PayNowCard(
                  sub: sub,
                  isUrdu: isUrdu,
                  isDark: isDark,
                  text1: text1,
                  text2: text2,
                ),
                const SizedBox(height: 24),
              ],

              // ── Available Plans ──
              if (sub == null || !sub.isLifetime) ...[
                Text(
                  isUrdu ? 'Plan Badlein' : 'Change Plan',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: text1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUrdu
                      ? 'Upgrade abhi naafit hoga. Downgrade aglay cycle se.'
                      : 'Upgrades take effect immediately. Downgrades apply from next cycle.',
                  style: GoogleFonts.inter(fontSize: 11, color: text2),
                ),
                const SizedBox(height: 14),

                if (_changeError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _changeError!,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.red),
                    ),
                  ),
                ],

                plansAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2)),
                  error: (e, _) => Text('Error loading plans: $e',
                      style: const TextStyle(color: AppColors.red)),
                  data: (plans) {
                    final displayPlans =
                        plans.where((p) => p['code'] != 'trial').toList();
                    return Column(
                      children: displayPlans.map((plan) {
                        final isCurrentPlan =
                            sub != null && plan['code'] == sub.planCode;
                        return _PlanCard(
                          plan: plan,
                          isCurrentPlan: isCurrentPlan,
                          currentSortOrder: sub != null
                              ? plans.indexWhere(
                                  (p) => p['code'] == sub.planCode)
                              : -1,
                          planSortOrder: plans.indexOf(plan),
                          isUrdu: isUrdu,
                          isDark: isDark,
                          isLoading: _isChangingPlan,
                          onSelect: () =>
                              _handlePlanChange(ref, sub, plan, isUrdu),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),

              // ── Extra Cloud Storage Add-on ──
              _StorageAddonSection(
                isUrdu: isUrdu,
                isDark: isDark,
                text1: text1,
                text2: text2,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePlanChange(
    WidgetRef ref,
    SubscriptionState? sub,
    Map<String, dynamic> plan,
    bool isUrdu,
  ) async {
    if (_isChangingPlan) return;
    setState(() {
      _isChangingPlan = true;
      _changeError = null;
    });

    final planCode = plan['code'] as String;

    // Check if this is a downgrade
    final subState = ref.read(subscriptionStateProvider).valueOrNull;
    final currentSortOrder =
        _getSortOrder(subState?.planCode ?? 'trial');
    final targetSortOrder = _getSortOrder(planCode);

    if (targetSortOrder < currentSortOrder) {
      // Downgrade — validate
      // We need shop ID from the provider context
      final canResult = await _validateDowngrade(ref, planCode);
      if (canResult['allowed'] != true) {
        setState(() {
          _isChangingPlan = false;
          _changeError = canResult['reason'] as String? ??
              'Downgrade not allowed';
        });
        return;
      }
      // Downgrade allowed — navigate to payment for next cycle
    }

    setState(() => _isChangingPlan = false);

    // Navigate to payment screen
    if (mounted) {
      context.push('/subscription/pay', extra: {
        'purpose': PaymentPurpose.subscriptionMonthly,
        'planData': plan,
      });
    }
  }

  Future<Map<String, dynamic>> _validateDowngrade(
      WidgetRef ref, String targetPlanCode) async {
    // Get shop ID from current shop provider
    // We validate via subscription service directly
    return {'allowed': true}; // Simplified — full validation in payment screen
  }

  int _getSortOrder(String? planCode) {
    switch (planCode) {
      case 'trial':
        return 0;
      case 'basic':
        return 1;
      case 'standard':
        return 2;
      case 'unlimited':
        return 3;
      default:
        return 0;
    }
  }
}

// ── Plan Card ───────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isCurrentPlan;
  final int currentSortOrder;
  final int planSortOrder;
  final bool isUrdu;
  final bool isDark;
  final bool isLoading;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.currentSortOrder,
    required this.planSortOrder,
    required this.isUrdu,
    required this.isDark,
    required this.isLoading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final price = (plan['price_pkr'] as int?) ?? 0;
    final planCode = plan['code'] as String? ?? '';
    final isUpgrade = planSortOrder > currentSortOrder;
    final isPopular = planCode == 'standard';

    Color accentColor;
    if (isCurrentPlan) {
      accentColor = AppColors.teal;
    } else if (plan['code'] == 'unlimited') {
      accentColor = AppColors.accent;
    } else if (plan['code'] == 'standard') {
      accentColor = AppColors.purple;
    } else {
      accentColor = AppColors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? AppColors.teal.withValues(alpha: 0.06)
            : (isDark ? const Color(0x08FFFFFF) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentPlan
              ? AppColors.teal.withValues(alpha: 0.4)
              : (isPopular
                  ? AppColors.purple.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0).withValues(
                      alpha: isDark ? 0.12 : 1)),
          width: isCurrentPlan ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isUrdu
                          ? plan['name_ur'] as String
                          : plan['name_en'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isCurrentPlan ? AppColors.teal : accentColor,
                      ),
                    ),
                    if (isCurrentPlan) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUrdu ? 'CURRENT' : 'CURRENT',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: AppColors.teal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (isPopular && !isCurrentPlan) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'POPULAR',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  PlanPriceFormatter.description(plan, isUrdu: isUrdu),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF6880A0)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs ${NumberFormat('#,###').format(price)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isCurrentPlan ? AppColors.teal : accentColor,
                ),
              ),
              Text(
                PlanPriceFormatter.priceSuffix(plan, isUrdu: isUrdu),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFF6880A0)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Action button
          if (!isCurrentPlan)
            GestureDetector(
              onTap: isLoading ? null : onSelect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isUpgrade
                      ? accentColor.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F0).withValues(
                          alpha: isDark ? 0.08 : 1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isUpgrade
                        ? accentColor.withValues(alpha: 0.4)
                        : const Color(0xFFCBD5E1)
                            .withValues(alpha: isDark ? 0.12 : 1),
                  ),
                ),
                child: Text(
                  isUpgrade
                      ? (isUrdu ? 'Upgrade' : 'Upgrade')
                      : (isUrdu ? 'Downgrade' : 'Downgrade'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isUpgrade
                        ? accentColor
                        : (isDark
                            ? const Color(0xFF6880A0)
                            : const Color(0xFF475569)),
                  ),
                ),
              ),
            )
          else
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.teal,
              size: 22,
            ),
        ],
      ),
    );
  }
}

// ── Lifetime Badge ──────────────────────────────────────────────────────────

class _LifetimeBadge extends StatelessWidget {
  final bool isUrdu;
  const _LifetimeBadge({required this.isUrdu});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.12),
            AppColors.accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrdu ? 'Lifetime Access' : 'Lifetime Access',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.teal,
                  ),
                ),
                Text(
                  isUrdu
                      ? 'Aapko monthly payment ki zaroorat nahi hai. Shukriya!'
                      : 'No monthly payments required. Thank you for your support!',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.text2,
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

// ── Pay Now Card ────────────────────────────────────────────────────────────

class _PayNowCard extends StatelessWidget {
  final SubscriptionState sub;
  final bool isUrdu;
  final bool isDark;
  final Color text1;
  final Color text2;

  const _PayNowCard({
    required this.sub,
    required this.isUrdu,
    required this.isDark,
    required this.text1,
    required this.text2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('💳', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrdu ? 'Payment Due' : 'Payment Due',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  'Rs ${NumberFormat('#,###').format(sub.amountDuePkr)} — ${isUrdu ? sub.planNameUr : sub.planNameEn}',
                  style: GoogleFonts.inter(fontSize: 12, color: text2),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigate to payment screen with pending sub details
              context.push('/subscription/pay', extra: {
                'purpose': PaymentPurpose.subscriptionMonthly,
                'planData': {
                  'code': sub.planCode,
                  'name_en': sub.planNameEn,
                  'name_ur': sub.planNameUr,
                  'price_pkr': sub.amountDuePkr,
                },
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF1A0A00),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isUrdu ? 'Pay Karein' : 'Pay Now',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cloud Storage Add-on Section ───────────────────────────────────────────

class _StorageAddonSection extends ConsumerWidget {
  final bool isUrdu;
  final bool isDark;
  final Color text1;
  final Color text2;

  const _StorageAddonSection({
    required this.isUrdu,
    required this.isDark,
    required this.text1,
    required this.text2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(currentShopProvider);
    final shop = shopAsync.valueOrNull;
    final isAddonActive = shop?['storage_addon_active'] == true;
    final expiresStr = shop?['storage_addon_expires_at'] as String?;
    final expires = expiresStr != null ? DateTime.tryParse(expiresStr) : null;
    final storageAllowanceMb =
        ref.watch(shopStorageAllowanceProvider).valueOrNull ?? 0;
    final storageUsedBytes = (shop?['storage_used_bytes'] as int?) ?? 0;
    final usedMb = storageUsedBytes / (1024 * 1024);

    final allowanceStr = storageAllowanceMb >= 1024
        ? '${(storageAllowanceMb / 1024).toStringAsFixed(storageAllowanceMb % 1024 == 0 ? 0 : 2)} GB'
        : '${storageAllowanceMb.toStringAsFixed(storageAllowanceMb % 1 == 0 ? 0 : 2)} MB';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x08FFFFFF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAddonActive
              ? AppColors.teal.withValues(alpha: 0.4)
              : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
          width: isAddonActive ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0EA5E9).withValues(alpha: 0.16),
                      AppColors.teal.withValues(alpha: 0.16),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  color: AppColors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isUrdu
                                ? 'اضافی کلاؤڈ اسٹوریج ایڈ آن'
                                : 'Extra Cloud Storage Add-on',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: text1,
                            ),
                          ),
                        ),
                        if (isAddonActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.teal.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 11, color: AppColors.teal),
                                const SizedBox(width: 4),
                                Text(
                                  isUrdu ? 'فعال' : 'ACTIVE (+1 GB)',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isUrdu
                          ? 'گارمنٹ ڈیزائنز، کپڑوں کی تصاویر اور کسٹمر فائلز کے لیے اضافی جگہ'
                          : 'High-speed cloud space for customer cloth photos, sketches & audio notes',
                      style: GoogleFonts.inter(fontSize: 12, color: text2),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Details & Benefits Badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x05FFFFFF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0x10FFFFFF) : const Color(0xFFEEF2F6),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'موجودہ صلاحیت' : 'CURRENT TOTAL CAPACITY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: text2,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$allowanceStr (${usedMb.toStringAsFixed(1)} MB used)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: text1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'ایڈ آن پیکج' : 'ADD-ON PRICING',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: text2,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rs 250/mo or Rs 2,500/yr',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF5A623),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isAddonActive && expires != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: text2),
                const SizedBox(width: 6),
                Text(
                  isUrdu
                      ? 'ایڈ آن کی میعاد: ${DateFormat('d MMMM y').format(expires)}'
                      : 'Add-on active until ${DateFormat('d MMMM y').format(expires)}',
                  style: GoogleFonts.inter(fontSize: 11.5, color: text2),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Primary Call to Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => StorageAddonModal.show(context),
              icon: Icon(
                isAddonActive ? Icons.refresh_rounded : Icons.add_to_photos_rounded,
                size: 18,
              ),
              label: Text(
                isAddonActive
                    ? (isUrdu ? 'اسٹوریج میں اضافہ یا تجدید کریں' : 'Extend / Manage Storage Add-on')
                    : (isUrdu ? 'اضافی +1 GB اسٹوریج حاصل کریں (Rs 250)' : 'Get +1 GB Extra Storage (Rs 250/mo)'),
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: const Color(0xFF032219),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

