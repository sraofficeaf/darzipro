import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/providers/invite_providers.dart';

String timeAgo(String isoDate) {
  final dt = DateTime.parse(isoDate).toLocal();
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String formatAmount(int amount) {
  final formatted = amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},'
  );
  return 'Rs $formatted';
}

class InviteDashboardScreen extends ConsumerStatefulWidget {
  const InviteDashboardScreen({super.key});

  @override
  ConsumerState<InviteDashboardScreen> createState() => _InviteDashboardScreenState();
}

class _InviteDashboardScreenState extends ConsumerState<InviteDashboardScreen> {
  void _shareOnWhatsApp(String code) async {
    final message = Uri.encodeComponent(
      'Check out Darzi Pro — professional tailor shop management software! Use my invite code $code when you register: https://darzipro.pk/join'
    );
    final url = Uri.parse('whatsapp://send?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback
      final webUrl = Uri.parse('https://wa.me/?text=$message');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    const accentColor = Color(0xFFF5A623);
    const greenColor = Color(0xFF10B981);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.white70 : Colors.black54;

    final statsAsync = ref.watch(inviteStatsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🤝 Invite & Earn', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Track your invite profits', style: GoogleFonts.inter(color: mutedTextColor, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: () {
              ref.invalidate(inviteStatsProvider);
              ref.invalidate(profitEarningsProvider);
              ref.invalidate(myInvitedShopsProvider);
              ref.invalidate(payoutHistoryProvider);
            },
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading stats: $err', style: TextStyle(color: Colors.red))),
        data: (stats) {
          final totalLifetime = stats['total_lifetime'] as int? ?? 0;
          final invitedCount = stats['invited_count'] as int? ?? 0;
          final todayTotal = stats['today_total'] as int? ?? 0;
          final monthTotal = stats['month_total'] as int? ?? 0;
          final lastPayout = stats['last_payout'] as Map<String, dynamic>?;
          final inviteCode = stats['invite_code'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Invite Code Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('Your Invite Code', style: GoogleFonts.inter(color: mutedTextColor, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          inviteCode.isEmpty ? 'LOADING...' : inviteCode,
                          style: GoogleFonts.firaCode(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              if (inviteCode.isNotEmpty) {
                                Clipboard.setData(ClipboardData(text: inviteCode));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                              }
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy Code'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _shareOnWhatsApp(inviteCode),
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share on WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '🏆 Earn Rs 5,000 for each new shop + Rs 200-750/month recurring',
                        style: GoogleFonts.inter(color: greenColor, fontSize: 12, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Grid
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatCard('Total Lifetime Earnings', formatAmount(totalLifetime), Icons.account_balance_wallet, accentColor, surfaceColor, textColor, mutedTextColor),
                    _buildStatCard('Invited Shops', '$invitedCount', Icons.storefront, Colors.blue, surfaceColor, textColor, mutedTextColor),
                    _buildStatCard('Today', formatAmount(todayTotal), Icons.today, greenColor, surfaceColor, textColor, mutedTextColor),
                    _buildMonthCard('This Month', monthTotal, surfaceColor, textColor, mutedTextColor, isDark),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last Payout', style: GoogleFonts.inter(color: mutedTextColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        lastPayout != null ? '${formatAmount(lastPayout['total_amount'] as int)} on ${lastPayout['paid_at'].toString().split('T')[0]}' : 'No payouts yet',
                        style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Activity Feed
                Text('Recent Earnings', style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildRecentEarningsFeed(surfaceColor, textColor, mutedTextColor, isDark),
                const SizedBox(height: 24),

                // My Invited Shops Table
                Text('My Invited Shops', style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildInvitedShopsTable(surfaceColor, textColor, mutedTextColor),
                const SizedBox(height: 24),

                // Payout History Table
                Text('Payout History', style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildPayoutHistoryTable(surfaceColor, textColor, mutedTextColor),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor, Color surfaceColor, Color textColor, Color mutedTextColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 300 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Container(
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: GoogleFonts.inter(color: mutedTextColor, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: GoogleFonts.inter(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMonthCard(String title, int monthTotal, Color surfaceColor, Color textColor, Color mutedTextColor, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 300 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Container(
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month, size: 16, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(title, style: GoogleFonts.inter(color: mutedTextColor, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(formatAmount(monthTotal), style: GoogleFonts.inter(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              monthTotal >= 1000
                ? Text('✅ Will be paid 21st-30th', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 10))
                : Text('Rs ${1000 - monthTotal} more for payout (min Rs 1,000)', style: GoogleFonts.inter(color: const Color(0xFFF5A623), fontSize: 10)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRecentEarningsFeed(Color surfaceColor, Color textColor, Color mutedTextColor, bool isDark) {
    return Consumer(
      builder: (context, ref, child) {
        final earningsAsync = ref.watch(profitEarningsProvider);
        return earningsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error: $err'),
          data: (earnings) {
            if (earnings.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('No earnings yet. Share your invite code to start earning!', style: GoogleFonts.inter(color: mutedTextColor))),
              );
            }
            return Container(
              decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: earnings.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                itemBuilder: (context, index) {
                  final e = earnings[index];
                  final type = e['earning_type'] as String?;
                  String icon = '💰';
                  String label = 'Profit';
                  
                  if (type == 'signup_full_access') {
                    icon = '🎉';
                    label = 'New Invite (Full Access) — Rs 5,250';
                  } else if (type == 'signup_mobile_only') {
                    icon = '📱';
                    label = 'New Invite (Mobile Only) — Rs 1,800';
                  } else if (type == 'upgrade_bonus') {
                    icon = '⭐';
                    label = 'Upgrade Bonus — Rs 3,450';
                  } else if (type == 'storage_addon_monthly') {
                    icon = '💾';
                    label = 'Storage Add-on Profit — Rs 180/month';
                  } else if (type == 'signup_bonus') {
                    icon = '🎉';
                    label = 'New Invite Profit';
                  } else if (type == 'monthly_pro' || type == 'monthly_business') {
                    icon = '📅';
                    label = 'Monthly Plan Profit';
                  }
                  return ListTile(
                    leading: Text(icon, style: const TextStyle(fontSize: 24)),
                    title: Text('${e['invited_shop']?['name'] ?? 'Unknown Shop'}', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
                    subtitle: Text('$label • ${timeAgo(e['earned_at'])}', style: GoogleFonts.inter(color: mutedTextColor, fontSize: 12)),
                    trailing: Text(formatAmount(e['amount'] as int), style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInvitedShopsTable(Color surfaceColor, Color textColor, Color mutedTextColor) {
    return Consumer(
      builder: (context, ref, child) {
        final shopsAsync = ref.watch(myInvitedShopsProvider);
        return shopsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error: $err'),
          data: (shops) {
            if (shops.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('No shops invited yet', style: GoogleFonts.inter(color: mutedTextColor))),
              );
            }
            return Container(
              decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
              child: DataTable(
                headingTextStyle: GoogleFonts.inter(color: mutedTextColor, fontWeight: FontWeight.bold),
                dataTextStyle: GoogleFonts.inter(color: textColor),
                columns: const [
                  DataColumn(label: Text('Shop Name')),
                  DataColumn(label: Text('Plan')),
                  DataColumn(label: Text('Total Earned')),
                ],
                rows: shops.map((s) {
                  final plan = s['plan'] ?? 'Active';
                  return DataRow(cells: [
                    DataCell(Text(s['name'] ?? 'Unknown')),
                    DataCell(Text(plan.toString().toUpperCase())),
                    DataCell(Text(formatAmount(s['total_earned_from'] as int), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
                  ]);
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPayoutHistoryTable(Color surfaceColor, Color textColor, Color mutedTextColor) {
    return Consumer(
      builder: (context, ref, child) {
        final historyAsync = ref.watch(payoutHistoryProvider);
        return historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error: $err'),
          data: (history) {
            if (history.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('No payouts processed yet', style: GoogleFonts.inter(color: mutedTextColor))),
              );
            }
            return Container(
              decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: GoogleFonts.inter(color: mutedTextColor, fontWeight: FontWeight.bold),
                  dataTextStyle: GoogleFonts.inter(color: textColor),
                  columns: const [
                    DataColumn(label: Text('Period')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Date')),
                  ],
                  rows: history.map((h) {
                    final status = h['status'] as String;
                    final isPaid = status == 'paid';
                    return DataRow(cells: [
                      DataCell(Text(h['period_month'] ?? '')),
                      DataCell(Text(formatAmount(h['total_amount'] as int))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFF5A623).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF5A623), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )),
                      DataCell(Text(h['paid_at'] != null ? h['paid_at'].toString().split('T')[0] : '-')),
                    ]);
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
