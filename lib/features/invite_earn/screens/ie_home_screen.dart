import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../shared/providers/invite_providers.dart';
import '../widgets/ie_earning_card.dart';
import 'ie_guide_screen.dart';


class IeHomeScreen extends ConsumerWidget {
  /// Called by shell to switch to Payouts tab (index 2)
  final VoidCallback? onViewPayouts;
  /// Called by shell to switch to Invite Tools tab (index 3)
  final VoidCallback? onInviteNow;
  /// Generic tab switcher used by clickable cards
  final ValueChanged<int>? onSwitchTab;

  const IeHomeScreen({super.key, this.onViewPayouts, this.onInviteNow, this.onSwitchTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(inviteStatsProvider);
    final earningsAsync = ref.watch(profitEarningsProvider);
    final text1 = context.text1;
    final text2 = context.text2;

    return Scaffold(
      backgroundColor: context.bg,
      body: RefreshIndicator(
        color: ieAccent,
        onRefresh: () async {
          ref.invalidate(inviteStatsProvider);
          ref.invalidate(profitEarningsProvider);
        },
        child: statsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: ieAccent)),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFFF3A58), size: 40),
                const SizedBox(height: 12),
                Text('Error loading stats', style: GoogleFonts.inter(color: text2)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(inviteStatsProvider),
                  child: Text('Retry', style: GoogleFonts.inter(color: ieAccent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          data: (stats) {
            final totalLifetime = stats['total_lifetime'] as int? ?? 0;
            final todayTotal = stats['today_total'] as int? ?? 0;
            final monthTotal = stats['month_total'] as int? ?? 0;
            final availableBalance = stats['available_balance'] as int? ?? 0;
            final _ = stats['last_payout']; // unused but kept for future use

            final inviteCode = stats['invite_code'] as String? ?? '';
            final invitedCount = stats['invited_count'] as int? ?? 0;
            final activeCount = stats['active_count'] as int? ?? 0;
            final pendingCount = stats['pending_count'] as int? ?? 0;
            final inactiveCount = stats['inactive_count'] as int? ?? 0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header greeting & How Earning Works Button ─────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💰 Invite & Earn',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: text1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Share your invite code and earn every month!',
                              style: GoogleFonts.inter(fontSize: 12, color: text2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const IeGuideScreen()),
                          );
                        },
                        icon: const Icon(Icons.info_outline_rounded, size: 16),
                        label: const Text('How It Works'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ieAccent.withValues(alpha: 0.14),
                          foregroundColor: ieAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: ieAccent.withValues(alpha: 0.5)),

                          ),
                          textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 5 Stat Cards (Responsive: Mobile 1+2+2, Desktop 5-col) ──
                  LayoutBuilder(builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final breakdown = '$activeCount Active · $pendingCount Pending · $inactiveCount Inactive';

                    if (w < 700) {
                      // 📱 Mobile layout: 1 full-width Registered Users card + 2 side-by-side equal-height rows
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Top Full-Width Card: Registered Users (bigger, breakdown at bottom)
                          IeEarningCard(
                            title: 'Registered Users',
                            value: '$invitedCount',
                            subtitle: breakdown,
                            icon: Icons.storefront_rounded,
                            large: true,
                            onTap: () => onSwitchTab?.call(1),
                          ),
                          const SizedBox(height: 12),

                          // 2. Row 2: Today's Earnings & This Month
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: IeEarningCard(
                                    title: "Today's Earnings",
                                    value: 'Rs ${_fmt(todayTotal)}',
                                    icon: Icons.today_rounded,
                                    onTap: () => onSwitchTab?.call(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: IeEarningCard(
                                    title: 'This Month',
                                    value: 'Rs ${_fmt(monthTotal)}',
                                    icon: Icons.calendar_month_rounded,
                                    onTap: () => onSwitchTab?.call(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3. Row 3: Total Lifetime & Balance
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: IeEarningCard(
                                    title: 'Total Lifetime',
                                    value: 'Rs ${_fmt(totalLifetime)}',
                                    icon: Icons.account_balance_wallet_rounded,
                                    onTap: () => onSwitchTab?.call(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: IeEarningCard(
                                    title: 'Balance',
                                    value: 'Rs ${_fmt(availableBalance)}',
                                    icon: Icons.payments_rounded,
                                    onTap: () => onSwitchTab?.call(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // 🖥️ Desktop / Tablet layout
                    final cols = w >= 900 ? 5 : 3;
                    final cardW = (w - (cols - 1) * 12.0) / cols;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardW,
                          child: IeEarningCard(
                            title: 'Total Lifetime',
                            value: 'Rs ${_fmt(totalLifetime)}',
                            icon: Icons.account_balance_wallet_rounded,
                            onTap: () => onSwitchTab?.call(2),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: IeEarningCard(
                            title: 'Registered Users',
                            value: '$invitedCount',
                            subtitle: breakdown,
                            icon: Icons.storefront_rounded,
                            onTap: () => onSwitchTab?.call(1),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: IeEarningCard(
                            title: "Today's Earnings",
                            value: 'Rs ${_fmt(todayTotal)}',
                            icon: Icons.today_rounded,
                            onTap: () => onSwitchTab?.call(2),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: IeEarningCard(
                            title: 'This Month',
                            value: 'Rs ${_fmt(monthTotal)}',
                            icon: Icons.calendar_month_rounded,
                            onTap: () => onSwitchTab?.call(2),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: IeEarningCard(
                            title: 'Balance',
                            value: 'Rs ${_fmt(availableBalance)}',
                            icon: Icons.payments_rounded,
                            onTap: () => onSwitchTab?.call(2),
                          ),
                        ),
                      ],
                    );
                  }),




                  const SizedBox(height: 24),

                  // ── Invite Now Button ──────────────────────────────────
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _shareInvite(context, inviteCode),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        'Invite Now & Earn',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ieAccent,
                        foregroundColor: const Color(0xFF0A1428),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Activity Feed ──────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Recent Earnings',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: text1,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: ieAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: ieAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  earningsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(color: ieAccent)),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (earnings) => _buildActivityFeed(context, earnings),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActivityFeed(
      BuildContext context, List<Map<String, dynamic>> earnings) {
    final surface = context.surface;
    final text1 = context.text1;
    final text2 = context.text2;
    final border = context.border;

    if (earnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text(
              'No earnings yet',
              style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w700, color: text1),
            ),
            const SizedBox(height: 6),
            Text(
              'Share your invite code to start earning!',
              style: GoogleFonts.inter(fontSize: 13, color: text2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: earnings.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: border),
        itemBuilder: (context, index) {
          final e = earnings[index];
          final type = e['earning_type'] as String? ?? '';
          final (icon, label) = _earningLabel(type);
          final shopName =
              e['invited_shop']?['name'] as String? ?? 'Unknown Shop';
          final amount = e['amount'] as int? ?? 0;
          final date = e['earned_at'] as String? ?? '';
          final level = (e['level'] as int?) ?? 1;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ieAccentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    shopName,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: text1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ieAccentBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ieAccentBorder),
                  ),
                  child: Text(
                    'Level $level',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ieAccent,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '$label · ${date.isNotEmpty ? ieTimeAgo(date) : ''}',
              style: GoogleFonts.inter(fontSize: 11, color: text2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              'Rs ${_fmt(amount)}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ieAccent,
              ),
            ),
          );
        },
      ),
    );
  }

  (String, String) _earningLabel(String type) => switch (type) {
        'signup_mobile_only' => ('📱', 'Basic Plan Signup'),
        'signup_full_access' => ('🎉', 'Professional Plan Signup'),
        'signup_full_access_3yr' => ('💎', 'Enterprise Plan Signup'),
        'upgrade_to_full_access' => ('⭐', 'Upgrade to Professional Plan'),
        'upgrade_to_3yr' => ('⭐', 'Upgrade to Enterprise Plan'),
        'upgrade_mobile_to_3yr' => ('⭐', 'Direct Jump to Enterprise'),
        'storage_addon_monthly' => ('💾', 'Monthly Storage Add-on'),
        'storage_addon_annual' => ('💾', 'Annual Storage Add-on'),
        _ => ('💰', 'Profit Earned'),
      };


  void _shareInvite(BuildContext context, String inviteCode) async {
    if (inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code not available yet')),
      );
      return;
    }
    final msg =
        'Check out Darzi Pro — professional tailor shop management software! '
        'Use my invite code $inviteCode when you register: '
        'https://darzipro.pk/join?ref=$inviteCode';
    await Share.share(msg, subject: 'Join Darzi Pro with my invite code!');
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
