import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/subscription_provider.dart';

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
                // Only show paid plans (not trial)
                final paidPlans =
                    plans.where((p) => p['code'] != 'trial').toList();
                return Column(
                  children: paidPlans.map((plan) {
                    return _PlanOptionTile(
                      plan: plan,
                      isUrdu: isUrdu,
                      isDark: isDark,
                      border: border,
                      text1: text1,
                      text2: text2,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed(
                          '/subscription/pay',
                          arguments: plan,
                        );
                      },
                    );
                  }).toList(),
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
    final maxOrders = plan['max_orders_per_month'] as int?;
    final maxCustomers = plan['max_active_customers'] as int?;
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
                    [
                      if (maxOrders != null) '$maxOrders orders/cycle',
                      if (maxCustomers != null) '$maxCustomers customers',
                    ].join(' · '),
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
                  '/mahina',
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
