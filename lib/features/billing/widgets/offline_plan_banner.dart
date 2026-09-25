import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/providers/subscription_provider.dart';

/// Banner shown when device is operating offline using cached plan data.
/// Rules:
/// - Keep cache usable offline for up to 7 days and beyond (NEVER locks, NEVER downgrades).
/// - Up to 7 days: quiet, honest banner ("Offline — plan last verified N days ago").
/// - After 7 days: more prominent banner, but still does NOT lock.
class OfflinePlanBanner extends ConsumerWidget {
  const OfflinePlanBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionStateProvider);
    final sub = subAsync.valueOrNull;

    bool isSimulatedOffline = Uri.base.queryParameters['offline'] == 'true';
    if (!isSimulatedOffline && Uri.base.fragment.contains('?')) {
      final fragmentUri = Uri.tryParse(Uri.base.fragment);
      isSimulatedOffline = fragmentUri?.queryParameters['offline'] == 'true';
    }

    final isOffline = (sub != null && sub.isOffline) || isSimulatedOffline;

    if (sub == null || !isOffline) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = sub.offlineDaysAgo;
    final daysLabel = (days <= 1) ? '1 day ago' : '$days days ago';
    final isStalePast7Days = days > 7;

    if (isStalePast7Days) {
      // More prominent warning banner after 7 days offline — still NEVER locks
      final bg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      final borderColor = isDark ? const Color(0xFFB45309) : const Color(0xFFF59E0B);
      final textColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);

      return Container(
        key: const Key('offline_plan_banner_prominent'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1.5),
          ),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Offline — plan last verified $daysLabel. Connect to the internet to sync records and update your plan.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Quiet, honest banner while offline (1 to 7 days)
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Container(
      key: const Key('offline_plan_banner_quiet'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 15,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — plan last verified $daysLabel',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
