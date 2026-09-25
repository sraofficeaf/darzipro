import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/theme_extensions.dart';
import '../providers/agency_providers.dart';

class AgencyShopsScreen extends ConsumerWidget {
  const AgencyShopsScreen({super.key});

  String _fmt(dynamic minor) {
    final int val = minor is num ? (minor / 100).round() : 0;
    return 'Rs ${NumberFormat('#,##0').format(val)}';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(agencyShopsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading shops: $e', style: GoogleFonts.inter(color: context.text1))),
        data: (shops) {
          if (shops.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 64, color: context.text2.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No Attributed Shops Yet',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.text1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shops registered with your agency code will appear here.',
                    style: GoogleFonts.inter(fontSize: 14, color: context.text2),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(agencyShopsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: shops.length,
              itemBuilder: (context, index) {
                final shop = shops[index];
                final name = shop['name'] ?? 'Unnamed Shop';
                final city = shop['city']?.toString().isNotEmpty == true ? shop['city'] : 'Not specified';
                final plan = (shop['plan_code'] ?? 'standard').toString().toUpperCase();
                final status = (shop['subscription_status'] ?? 'active').toString().toUpperCase();
                final joinedAt = _formatDate(shop['joined_at']);
                final lastPaid = shop['last_payment_month'] ?? 'None';
                final totalEarned = _fmt(shop['total_earned_minor']);

                final isActive = status == 'ACTIVE' || status == 'FOUNDING' || status == 'LIFETIME';

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
                          color: (isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8)).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.storefront_rounded,
                            color: isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            size: 22,
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
                                  name,
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.text1),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? const Color(0xFF047857) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'City: $city · Plan: $plan · Joined: $joinedAt',
                              style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Last Payment: $lastPaid',
                              style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            totalEarned,
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                          ),
                          Text(
                            'Profit Earned',
                            style: GoogleFonts.inter(fontSize: 11, color: context.text2),
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
    );
  }
}
