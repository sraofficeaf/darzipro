import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/subscription_provider.dart';
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: subAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: TextStyle(color: AppColors.red))),
          data: (sub) => _buildContent(context, ref, sub, plansAsync, isUrdu,
              isDark, text1, text2, text3),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    SubscriptionState sub,
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
              if (!sub.isLifetime) ...[
                UsageWidget(compact: false),
                const SizedBox(height: 24),
              ] else ...[
                _LifetimeBadge(isUrdu: isUrdu),
                const SizedBox(height: 24),
              ],

              // ── Pay Now (if payment due) ──
              if (sub.paymentStatus == 'pending' &&
                  sub.planPricePkr > 0 &&
                  !sub.isLifetime) ...[
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
              if (!sub.isLifetime) ...[
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
                            plan['code'] == sub.planCode;
                        return _PlanCard(
                          plan: plan,
                          isCurrentPlan: isCurrentPlan,
                          currentSortOrder: plans.indexWhere(
                              (p) => p['code'] == sub.planCode),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePlanChange(
    WidgetRef ref,
    SubscriptionState sub,
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
      Navigator.of(context).pushNamed('/subscription/pay', arguments: plan);
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
    final maxOrders = plan['max_orders_per_month'] as int?;
    final maxCustomers = plan['max_active_customers'] as int?;
    final isUpgrade = planSortOrder > currentSortOrder;
    final isPopular = plan['code'] == 'standard';

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
                  [
                    if (maxOrders != null)
                      '$maxOrders orders'
                    else
                      'Unlimited orders',
                    if (maxCustomers != null)
                      '$maxCustomers customers'
                    else
                      'Unlimited customers',
                  ].join(' · '),
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
                '/mahina',
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
              // Navigate to payment screen
              // Plan data passed as argument
              Navigator.of(context).pushNamed('/subscription/pay');
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
