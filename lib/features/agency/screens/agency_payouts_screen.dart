import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme_extensions.dart';
import '../providers/agency_providers.dart';

class AgencyPayoutsScreen extends ConsumerStatefulWidget {
  const AgencyPayoutsScreen({super.key});

  @override
  ConsumerState<AgencyPayoutsScreen> createState() => _AgencyPayoutsScreenState();
}

class _AgencyPayoutsScreenState extends ConsumerState<AgencyPayoutsScreen> {
  bool _isRequesting = false;

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

  Future<void> _showRequestPayoutDialog(int availableMinor, int thresholdMinor) async {
    final messenger = ScaffoldMessenger.of(context);
    final methodCtrl = TextEditingController(text: 'Bank Transfer');
    final amountCtrl = TextEditingController(text: ((availableMinor / 100).round()).toString());
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request Payout', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available: ${_fmt(availableMinor)} · Minimum: ${_fmt(thresholdMinor)}',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.teal),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (PKR)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: methodCtrl,
              decoration: const InputDecoration(labelText: 'Payout Method (e.g. Bank / JazzCash)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Account Details & Notes', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            child: const Text('Submit Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final requestedPkr = int.tryParse(amountCtrl.text.trim()) ?? 0;
    final reqMinor = requestedPkr * 100;

    setState(() => _isRequesting = true);
    try {
      final client = Supabase.instance.client;
      await client.rpc('request_agency_payout', params: {
        'p_amount_minor': reqMinor,
        'p_method': methodCtrl.text.trim(),
        'p_notes': notesCtrl.text.trim(),
      });

      if (mounted) {
        ref.invalidate(agencyOverviewProvider);
        ref.invalidate(agencyPayoutsProvider);
        messenger.showSnackBar(
          const SnackBar(content: Text('✅ Payout request submitted successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('❌ Error requesting payout: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(agencyOverviewProvider);
    final payoutsAsync = ref.watch(agencyPayoutsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (overview) {
          final availableMinor = (overview['available_minor'] as num?)?.toInt() ?? 0;
          final thresholdMinor = (overview['minimum_payout_threshold_minor'] as num?)?.toInt() ?? 500000;
          final canRequest = availableMinor >= thresholdMinor;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyOverviewProvider);
              ref.invalidate(agencyPayoutsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Available Balance Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0x2EFFFFFF) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available for Payout', style: GoogleFonts.inter(fontSize: 13, color: context.text2)),
                          const SizedBox(height: 4),
                          Text(
                            _fmt(availableMinor),
                            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Minimum payout threshold: ${_fmt(thresholdMinor)}',
                            style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: _isRequesting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Request Payout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canRequest ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (canRequest && !_isRequesting)
                            ? () => _showRequestPayoutDialog(availableMinor, thresholdMinor)
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Balance (${_fmt(availableMinor)}) is below minimum threshold (${_fmt(thresholdMinor)}).'),
                                    backgroundColor: Colors.amber.shade900,
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // History
                Text('Payout History', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.text1)),
                const SizedBox(height: 12),

                payoutsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading payouts: $e')),
                  data: (payouts) {
                    if (payouts.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Text('No payout requests yet.', style: GoogleFonts.inter(color: context.text2)),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payouts.length,
                      itemBuilder: (context, index) {
                        final p = payouts[index];
                        final amount = _fmt(p['amount_minor']);
                        final status = (p['status'] ?? 'requested').toString().toUpperCase();
                        final date = _formatDate(p['requested_at']);
                        final method = p['method'] ?? 'Manual';
                        final reference = p['reference']?.toString();

                        Color statusColor = const Color(0xFFF59E0B);
                        if (status == 'PAID') statusColor = const Color(0xFF10B981);
                        if (status == 'APPROVED') statusColor = const Color(0xFF3B82F6);
                        if (status == 'REJECTED') statusColor = const Color(0xFFEF4444);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? const Color(0x2EFFFFFF) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(child: Icon(Icons.receipt_rounded, color: statusColor, size: 20)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(amount, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.text1)),
                                    const SizedBox(height: 2),
                                    Text('$method · $date', style: GoogleFonts.inter(fontSize: 12, color: context.text2)),
                                    if (reference != null && reference.isNotEmpty)
                                      Text('Ref: $reference', style: GoogleFonts.inter(fontSize: 11, color: context.text2.withValues(alpha: 0.8))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
