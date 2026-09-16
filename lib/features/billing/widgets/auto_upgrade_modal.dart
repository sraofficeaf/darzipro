import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/subscription_provider.dart';

/// Non-blocking modal shown immediately after an order/customer is
/// successfully created and the auto-upgrade engine fires.
/// The shop owner sees this notification AFTER their work succeeded.
class AutoUpgradeModal extends StatelessWidget {
  final UpgradeNotification notification;
  const AutoUpgradeModal({super.key, required this.notification});

  static void showIfPending(BuildContext context, WidgetRef ref) {
    final notification = ref.read(pendingUpgradeNotificationProvider);
    if (notification == null) return;

    // Clear immediately so it doesn't show again
    ref.read(pendingUpgradeNotificationProvider.notifier).state = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AutoUpgradeModal(notification: notification),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';

    final bg = isDark ? const Color(0xFF0E1A2E) : Colors.white;
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final text2 = isDark ? const Color(0xFF6880A0) : const Color(0xFF475569);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon glow
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFFFFD080)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text('📈', style: TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              isUrdu ? 'Aapka Plan Upgrade Ho Gaya' : 'Plan Upgraded!',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: text1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Old plan → new plan
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PlanChip(
                  name: isUrdu
                      ? notification.newPlanNameUr
                      : notification.oldPlan,
                  color: AppColors.blue.withValues(alpha: 0.6),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.accent),
                ),
                _PlanChip(
                  name: isUrdu
                      ? notification.newPlanNameUr
                      : notification.newPlanNameEn,
                  color: AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              isUrdu
                  ? 'Aapne pichle plan ki limit poori kar li.\nAb aapka plan ${notification.newPlanNameEn} hai — Rs ${notification.newPlanPricePkr}/mahina.\n\nAapka kaam jari hai, koi rukawat nahi.'
                  : 'You\'ve exceeded your previous plan\'s limit.\nYour new plan is ${notification.newPlanNameEn} — Rs ${notification.newPlanPricePkr}/month.\n\nYour work continues uninterrupted.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: text2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: text2,
                      side: BorderSide(
                          color: AppColors.accent.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isUrdu ? 'Theek Hai' : 'Got it',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to subscription screen
                      Navigator.of(context).pushNamed('/subscription');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: const Color(0xFF1A0A00),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isUrdu ? 'Tafseel Dekhein' : 'View Details',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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

class _PlanChip extends StatelessWidget {
  final String name;
  final Color color;
  const _PlanChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        name,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
