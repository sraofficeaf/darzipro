import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/subscription_provider.dart';

/// Persistent banner shown when subscription is in read_only mode.
/// Data is still visible and print still works, but creation is blocked.
class ReadOnlyBanner extends ConsumerWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionStateProvider);
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';

    return subAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sub) {
        if (!sub.isReadOnly && !sub.isGrace) return const SizedBox.shrink();

        final isGrace = sub.isGrace;
        return _ReadOnlyBannerContent(
          isGrace: isGrace,
          isUrdu: isUrdu,
          onRenewTap: () {
            context.push('/subscription');
          },
        );
      },
    );
  }
}

class _ReadOnlyBannerContent extends StatelessWidget {
  final bool isGrace;
  final bool isUrdu;
  final VoidCallback onRenewTap;

  const _ReadOnlyBannerContent({
    required this.isGrace,
    required this.isUrdu,
    required this.onRenewTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isGrace
        ? const Color(0xFFFFF3CD)
        : const Color(0xFFFEEBEB);
    final borderColor = isGrace
        ? const Color(0xFFD97706)
        : AppColors.red;
    final textColor = isGrace
        ? const Color(0xFF92400E)
        : const Color(0xFF7F1D1D);
    final icon = isGrace ? '⏳' : '🔒';

    String message;
    String btnLabel;

    if (isGrace) {
      message = isUrdu
          ? '$icon Grace period mein hain — abhi renew karein'
          : '$icon Grace period active — please renew your subscription';
      btnLabel = isUrdu ? 'Renew Karein' : 'Renew Now';
    } else {
      message = isUrdu
          ? '$icon Subscription khatam ho gayi — data mehfooz hai, naya kaam band hai'
          : '$icon Subscription expired — your data is safe, new creation is blocked';
      btnLabel = isUrdu ? 'Renew Karein' : 'Renew Now';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bg,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRenewTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                btnLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
