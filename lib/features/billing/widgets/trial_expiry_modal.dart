import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/payments/payment_provider.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/utils/plan_price_formatter.dart';
import '../../../shared/providers/subscription_provider.dart';

/// FutureProvider: loads founding offer settings from app_settings.
final _foundingSettingsProvider = FutureProvider.autoDispose<Map<String, String>>((ref) {
  return SubscriptionService.instance.fetchFoundingSettings();
});

/// FutureProvider: live count of founding shops (for slots).
final _foundingShopsCountProvider = FutureProvider.autoDispose<int>((ref) {
  return SubscriptionService.instance.countFoundingShops();
});

/// Shown when trial expires (by orders or by days).
/// Lets the shop pick a plan and go to payment.
/// Non-dismissable — must pick a plan or stay blocked in read-only after grace.
class TrialExpiryModal extends ConsumerWidget {
  const TrialExpiryModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TrialExpiryModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final plansAsync = ref.watch(subscriptionPlansProvider);

    final bg = isDark ? const Color(0xFF0E1A2E) : Colors.white;
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final text2 = isDark ? const Color(0xFF6880A0) : const Color(0xFF475569);
    final border = isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.blue.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Text('⏰', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 16),

            Text(
              isUrdu ? 'Trial Khatam Ho Gayi' : 'Your Trial Has Ended',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: text1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isUrdu
                  ? 'Subscription lein toh kaam jari rahega. Ek plan chunein:'
                  : 'Subscribe to continue. Choose a plan below:',
              style: GoogleFonts.inter(fontSize: 13, color: text2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Plans list (dynamic from DB)
            plansAsync.when(
              loading: () => const CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2),
              error: (_, _) => Text(
                'Could not load plans',
                style: GoogleFonts.inter(color: AppColors.red),
              ),
              data: (plans) {
                // Filter: show paid plans only (exclude trial and founding — founding has its own card)
                final paidPlans = plans
                    .where((p) => p['code'] != 'trial' && p['code'] != 'founding')
                    .toList();

                // Founding offer card (shown above regular plans if enabled)
                final foundingAsync  = ref.watch(_foundingSettingsProvider);
                final fCountAsync    = ref.watch(_foundingShopsCountProvider);

                return Column(
                  children: [
                    // Founding offer card (only if enabled and slots available)
                    foundingAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (settings) {
                        final enabled = settings['founding_offer_enabled'] == 'true';
                        if (!enabled) return const SizedBox.shrink();

                        // Check offer end date
                        final endDateStr = settings['founding_offer_end_date'] ?? '';
                        if (endDateStr.isNotEmpty) {
                          final endDate = DateTime.tryParse(endDateStr);
                          if (endDate != null && DateTime.now().isAfter(endDate)) {
                            return const SizedBox.shrink();
                          }
                        }

                        // Check slots
                        final totalSlots = int.tryParse(settings['founding_slots_total'] ?? '0') ?? 0;
                        final usedSlots  = fCountAsync.value ?? 0;
                        if (totalSlots > 0 && usedSlots >= totalSlots) {
                          return const SizedBox.shrink(); // sold out
                        }

                        final fee         = int.tryParse(settings['founding_activation_fee']   ?? '35000') ?? 35000;
                        final freeMonths  = int.tryParse(settings['founding_free_months']      ?? '6')     ?? 6;
                        final remaining   = totalSlots > 0 ? totalSlots - usedSlots : null;

                        return _FoundingOfferCard(
                          activationFee: fee,
                          freeMonths: freeMonths,
                          slotsRemaining: remaining,
                          isUrdu: isUrdu,
                          isDark: isDark,
                          text1: text1,
                          text2: text2,
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/subscription/pay', extra: {
                              'purpose': PaymentPurpose.foundingActivation,
                              'planData': {'code': 'founding', 'name_en': 'Founding Member'},
                              'extraData': settings,
                            });
                          },
                        );
                      },
                    ),
                    if (paidPlans.isNotEmpty) const SizedBox(height: 8),
                    // Regular plans
                    ...paidPlans.map((plan) {
                      return _PlanOptionTile(
                        plan: plan,
                        isUrdu: isUrdu,
                        isDark: isDark,
                        border: border,
                        text1: text1,
                        text2: text2,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/subscription/pay', extra: {
                            'purpose': PaymentPurpose.subscriptionMonthly,
                            'planData': plan,
                          });
                        },
                      );
                    }),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
            Text(
              isUrdu
                  ? 'Aapka sara data mehfooz hai — kuch delete nahi hoga.'
                  : 'All your data is safe — nothing will be deleted.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: text2,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanOptionTile extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isUrdu;
  final bool isDark;
  final Color border;
  final Color text1;
  final Color text2;
  final VoidCallback onTap;

  const _PlanOptionTile({
    required this.plan,
    required this.isUrdu,
    required this.isDark,
    required this.border,
    required this.text1,
    required this.text2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = plan['code'] == 'standard';
    final price = (plan['price_pkr'] as int?) ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPopular
              ? AppColors.accent.withValues(alpha: 0.06)
              : (isDark ? const Color(0x08FFFFFF) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPopular
                ? AppColors.accent.withValues(alpha: 0.4)
                : border,
            width: isPopular ? 1.5 : 1,
          ),
        ),
        child: Row(
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isPopular ? AppColors.accent : text1,
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'POPULAR',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: const Color(0xFF1A0A00),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    PlanPriceFormatter.description(plan, isUrdu: isUrdu),
                    style: GoogleFonts.inter(fontSize: 11, color: text2),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ${NumberFormat('#,###').format(price)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isPopular ? AppColors.accent : text1,
                  ),
                ),
                Text(
                  PlanPriceFormatter.priceSuffix(plan, isUrdu: isUrdu),
                  style: GoogleFonts.inter(fontSize: 10, color: text2),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isPopular ? AppColors.accent : text2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Founding Offer Card ──────────────────────────────────────────────────────

class _FoundingOfferCard extends StatelessWidget {
  final int activationFee;
  final int freeMonths;
  final int? slotsRemaining;
  final bool isUrdu;
  final bool isDark;
  final Color text1;
  final Color text2;
  final VoidCallback onTap;

  const _FoundingOfferCard({
    required this.activationFee,
    required this.freeMonths,
    required this.slotsRemaining,
    required this.isUrdu,
    required this.isDark,
    required this.text1,
    required this.text2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8A020);
    const goldLight = Color(0xFFFFF3DC);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2D1E00), const Color(0xFF1C1400)]
                : [goldLight, const Color(0xFFFEF9EE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'بانی ممبر آفر' : 'Founding Member Offer',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: gold,
                        ),
                      ),
                      if (slotsRemaining != null)
                        Text(
                          isUrdu
                              ? 'صرف $slotsRemaining جگہیں باقی!'
                              : 'Only $slotsRemaining slots left!',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: gold,
                          ),
                        ),
                    ],
                  ),
                ),
                // EXCLUSIVE badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUrdu ? 'خاص آفر' : 'EXCLUSIVE',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Features
            _FoundingFeature(
              icon: '💰',
              text: isUrdu
                  ? 'Rs ${NumberFormat('#,###').format(activationFee)} — ایک بار کی فیس'
                  : 'Rs ${NumberFormat('#,###').format(activationFee)} — one-time activation',
              color: gold,
            ),
            const SizedBox(height: 4),
            _FoundingFeature(
              icon: '🆓',
              text: isUrdu
                  ? '$freeMonths مہینے بالکل مفت — کوئی بل نہیں'
                  : '$freeMonths months completely FREE — no billing',
              color: gold,
            ),
            const SizedBox(height: 4),
            _FoundingFeature(
              icon: '♾️',
              text: isUrdu
                  ? 'لامحدود آرڈرز اور کسٹمرز — ہمیشہ کے لیے'
                  : 'Unlimited orders & customers — forever',
              color: gold,
            ),

            const SizedBox(height: 12),

            // CTA
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isUrdu ? 'ابھی Apply کریں →' : 'Apply Now →',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FoundingFeature extends StatelessWidget {
  final String icon;
  final String text;
  final Color color;
  const _FoundingFeature({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ),
      ],
    );
  }
}
