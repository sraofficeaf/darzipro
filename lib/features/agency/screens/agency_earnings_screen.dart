import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/theme_extensions.dart';
import '../providers/agency_providers.dart';

class AgencyEarningsScreen extends ConsumerStatefulWidget {
  const AgencyEarningsScreen({super.key});

  @override
  ConsumerState<AgencyEarningsScreen> createState() => _AgencyEarningsScreenState();
}

class _AgencyEarningsScreenState extends ConsumerState<AgencyEarningsScreen> {
  String? _selectedMonth; // null = all, or e.g. '2026-09'

  String _fmt(dynamic minor) {
    final int val = minor is num ? (minor / 100).round() : 0;
    return 'Rs ${NumberFormat('#,##0').format(val)}';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(agencyEarningsProvider(_selectedMonth));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Earnings Breakdown',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.text1),
                ),
                DropdownButton<String?>(
                  value: _selectedMonth,
                  hint: Text('All Months', style: GoogleFonts.inter(fontSize: 13, color: context.text1)),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Months', style: GoogleFonts.inter(fontSize: 13, color: context.text1)),
                    ),
                    DropdownMenuItem<String?>(
                      value: DateFormat('yyyy-MM').format(DateTime.now()),
                      child: Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: GoogleFonts.inter(fontSize: 13, color: context.text1)),
                    ),
                    DropdownMenuItem<String?>(
                      value: DateFormat('yyyy-MM').format(DateTime.now().subtract(const Duration(days: 30))),
                      child: Text(DateFormat('MMMM yyyy').format(DateTime.now().subtract(const Duration(days: 30))), style: GoogleFonts.inter(fontSize: 13, color: context.text1)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedMonth = val);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: earningsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading earnings: $e', style: GoogleFonts.inter(color: context.text1))),
              data: (earnings) {
                if (earnings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: context.text2.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No Earnings Found',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.text1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When attributed shops pay their subscription, profit rows appear here.',
                          style: GoogleFonts.inter(fontSize: 14, color: context.text2),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(agencyEarningsProvider(_selectedMonth)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: earnings.length,
                    itemBuilder: (context, index) {
                      final item = earnings[index];
                      final date = _formatDate(item['earned_at']);
                      final shopName = item['source_shop_name'] ?? 'Unknown Shop';
                      final plan = (item['plan_code'] ?? 'standard').toString().toUpperCase();
                      final paymentAmount = _fmt(item['payment_amount_minor']);
                      final percentApplied = item['percent_applied']?.toString() ?? '0';
                      final profitEarned = _fmt(item['earning_minor']);
                      final status = (item['status'] ?? 'pending').toString().toUpperCase();

                      Color statusColor = const Color(0xFFF59E0B);
                      if (status == 'AVAILABLE') statusColor = const Color(0xFF10B981);
                      if (status == 'PAID') statusColor = const Color(0xFF6366F1);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0x2EFFFFFF) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '$percentApplied%',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        shopName,
                                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: context.text1),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0x2EFFFFFF) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          plan,
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: context.text2),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Paid: $paymentAmount · Rate: $percentApplied% applied',
                                    style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    date,
                                    style: GoogleFonts.inter(fontSize: 11, color: context.text2.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  profitEarned,
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
