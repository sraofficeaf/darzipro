import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/theme_extensions.dart';
import '../providers/agency_providers.dart';

class AgencyOverviewScreen extends ConsumerWidget {
  const AgencyOverviewScreen({super.key});

  String _fmt(dynamic minor) {
    final int val = minor is num ? (minor / 100).round() : 0;
    return 'Rs ${NumberFormat('#,##0').format(val)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(agencyOverviewProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading agency overview: $e', style: GoogleFonts.inter(color: context.text1))),
        data: (data) {
          final isAgency = data['is_agency'] == true;
          if (!isAgency) {
            return Center(
              child: Text(
                'You do not have access to the Agency portal.',
                style: GoogleFonts.inter(color: context.text1, fontSize: 16),
              ),
            );
          }

          final agencyCode = data['agency_code'] ?? '';
          final displayName = data['display_name'] ?? 'Agency Partner';
          final isActive = data['is_active'] == true;
          final currentPercent = data['current_percent']?.toString() ?? '0';
          final currentEffectiveFrom = data['current_rate_effective_from']?.toString() ?? '-';
          final pendingPercent = data['pending_percent']?.toString();
          final pendingEffectiveFrom = data['pending_rate_effective_from']?.toString();

          final totalEarned = _fmt(data['total_earned_minor']);
          final availableNow = _fmt(data['available_minor']);
          final pendingAmount = _fmt(data['pending_minor']);
          final paidToDate = _fmt(data['paid_minor']);

          final totalShops = data['total_shops'] ?? 0;
          final activeShops = data['active_shops'] ?? 0;
          final lapsedShops = data['lapsed_shops'] ?? 0;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(agencyOverviewProvider),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Hero Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Agency Code: $agencyCode',
                                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Copy Agency Code',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: agencyCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Agency code copied to clipboard!')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE AGENCY' : 'REVOKED (READ-ONLY)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      // Rate display
                      Row(
                        children: [
                          Icon(Icons.percent_rounded, color: Colors.amber.shade200, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Current Profit Share: ',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                          ),
                          Text(
                            '$currentPercent%',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          Text(
                            ' (effective $currentEffectiveFrom)',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                          ),
                        ],
                      ),
                      if (pendingPercent != null && pendingEffectiveFrom != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Scheduled Rate Change: $pendingPercent% starting from $pendingEffectiveFrom',
                                  style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Financial Cards
                Text(
                  'Profit Summary',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.text1),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  children: [
                    _StatCard(
                      label: 'Total Earned',
                      value: totalEarned,
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF0D9488),
                    ),
                    _StatCard(
                      label: 'Available Balance',
                      value: availableNow,
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    _StatCard(
                      label: 'Pending (In Delay)',
                      value: pendingAmount,
                      icon: Icons.timelapse_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    _StatCard(
                      label: 'Paid to Date',
                      value: paidToDate,
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF6366F1),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Shops Summary
                Text(
                  'Attributed Shops',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.text1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Total Shops',
                        count: totalShops.toString(),
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: 'Active Paying',
                        count: activeShops.toString(),
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: 'Lapsed',
                        count: lapsedShops.toString(),
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0x2EFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: context.text2)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.text1),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String count;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0x2EFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11.5, color: context.text2),
          ),
        ],
      ),
    );
  }
}
