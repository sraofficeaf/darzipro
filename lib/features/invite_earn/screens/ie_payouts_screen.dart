import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../shared/providers/invite_providers.dart';
import '../widgets/ie_earning_card.dart';
import '../widgets/ie_payout_row.dart';

class IePayoutsScreen extends ConsumerWidget {
  const IePayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(inviteStatsProvider);
    final historyAsync = ref.watch(payoutHistoryProvider);
    final text1 = context.text1;
    final text2 = context.text2;
    final surface = context.surface;
    final border = context.border;

    return Scaffold(
      backgroundColor: context.bg,
      body: RefreshIndicator(
        color: ieAccent,
        onRefresh: () async {
          ref.invalidate(inviteStatsProvider);
          ref.invalidate(payoutHistoryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Payouts',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: text1,
                ),
              ),
              const SizedBox(height: 16),

              // ── Status Card ───────────────────────────────────────
              statsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: ieAccent)),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) {
                  final availableBalance = stats['available_balance'] as int? ?? 0;
                  final agingAmount = stats['aging_amount'] as int? ?? 0;
                  final threshold = stats['payout_threshold'] as int? ?? 1000;
                  final meets = availableBalance >= threshold;

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: meets
                            ? [
                                ieAccent.withValues(alpha: 0.15),
                                ieAccent.withValues(alpha: 0.05),
                              ]
                            : [
                                const Color(0xFFF5A623).withValues(alpha: 0.10),
                                const Color(0xFFF5A623).withValues(alpha: 0.04),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: meets
                            ? ieAccentBorder
                            : const Color(0xFFF5A623).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              meets
                                  ? Icons.check_circle_rounded
                                  : Icons.schedule_rounded,
                              color: meets
                                  ? ieAccent
                                  : const Color(0xFFF5A623),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              meets
                                  ? '✅ Payout Ready!'
                                  : 'Pending Balance',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: meets
                                    ? ieAccent
                                    : const Color(0xFFF5A623),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Rs ${_fmt(availableBalance)}',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: meets ? ieAccent : text1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          meets
                              ? (agingAmount > 0
                                  ? '✅ Ready for payout · Rs ${_fmt(agingAmount)} will be ready soon'
                                  : '✅ Ready for payout')
                              : (agingAmount > 0
                                  ? 'Rs ${_fmt(threshold - availableBalance)} more needed (min. Rs ${_fmt(threshold)}) · Rs ${_fmt(agingAmount)} aging'
                                  : 'Rs ${_fmt(threshold - availableBalance)} more needed (min. Rs ${_fmt(threshold)})'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: meets ? ieAccent : text2,
                          ),
                        ),
                      ],
                    ),
                  );
                },

              ),
              const SizedBox(height: 24),

              // ── Payout History ─────────────────────────────────────────
              Text(
                'Payout History',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: text1,
                ),
              ),
              const SizedBox(height: 12),
              historyAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: ieAccent)),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: GoogleFonts.inter(color: text2)),
                ),
                data: (history) {
                  final threshold = statsAsync.value?['payout_threshold'] as int? ?? 1000;
                  if (history.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          const Text('💸', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            'No payouts yet',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: text1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Payouts are processed once your balance reaches Rs ${_fmt(threshold)}.',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: text2),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        IePayoutRow(payout: history[i]),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
