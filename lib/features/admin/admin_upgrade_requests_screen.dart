import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/services/admin_service.dart';
import '../../shared/providers/admin_providers.dart';

class AdminUpgradeRequestsScreen extends ConsumerStatefulWidget {
  const AdminUpgradeRequestsScreen({super.key});

  @override
  ConsumerState<AdminUpgradeRequestsScreen> createState() => _AdminUpgradeRequestsScreenState();
}

class _AdminUpgradeRequestsScreenState extends ConsumerState<AdminUpgradeRequestsScreen> {
  static const Color _amber = Color(0xFFF5A623);
  static const Color _red = Color(0xFFFF3A58);
  static const Color _green = Color(0xFF10B981);
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isProcessing = false;

  Future<void> _approveUpgrade(Map<String, dynamic> request) async {
    setState(() => _isProcessing = true);
    try {
      final shopData = request['shop'] as Map<String, dynamic>?;
      final shopId = request['shop_id'] as String;
      final invitedByCode = shopData?['invited_by_code'] as String?;

      final res = await AdminService.instance.approveUpgradeRequest(
        upgradeRequestId: request['id'],
        shopId: shopId,
        invitedByCode: invitedByCode,
      );

      if (mounted) {
        if (res['success'] == true) {
          ref.invalidate(adminUpgradeRequestsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Upgrade approved! Shop upgraded to Full Access.'),
              backgroundColor: _green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Approval failed: ${res['error']}'),
              backgroundColor: _red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectUpgrade(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Reject Upgrade Request',
            style: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejecting this request:',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: GoogleFonts.inter(color: textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Invalid payment screenshot...',
                  hintStyle: GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Reject',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final success = await AdminService.instance.rejectUpgradeRequest(
        upgradeRequestId: request['id'],
        reason: reasonController.text.isEmpty ? 'Upgrade rejected by admin.' : reasonController.text,
      );
      if (mounted) {
        if (success['success'] == true) {
          ref.invalidate(adminUpgradeRequestsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Upgrade request rejected.'),
              backgroundColor: _red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Rejection failed: ${success['error']}'),
              backgroundColor: _red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRequests = ref.watch(adminUpgradeRequestsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upgrade Requests',
                          style: GoogleFonts.outfit(
                            color: textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pending approval',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: textSecondary),
                      onPressed: () => ref.invalidate(adminUpgradeRequestsProvider),
                    ),
                  ],
                ),
              ),

              // Content List
              Expanded(
                child: asyncRequests.when(
                  data: (requests) {
                    if (requests.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, color: _green, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              '🎉 No pending upgrade requests!',
                              style: GoogleFonts.outfit(
                                color: textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final shopName = req['shop']?['name'] ?? 'Unknown Shop';
                        final createdAt = req['created_at'] != null
                            ? DateTime.parse(req['created_at'])
                            : DateTime.now();
                        final submittedDate = _dateFormat.format(createdAt);
                        final amount = req['amount'] ?? 23000;
                        final transactionId = req['transaction_id'] ?? 'N/A';
                        final screenshotUrl = (req['payment_screenshot_url'] ?? req['payment_screenshot']) as String?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      shopName,
                                      style: GoogleFonts.outfit(
                                        color: textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Rs ${NumberFormat('#,###').format(amount)}',
                                      style: GoogleFonts.inter(
                                        color: _amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(Icons.receipt, 'Tx: $transactionId', textPrimary, textSecondary),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.calendar_today, 'Submitted: $submittedDate', textPrimary, textSecondary),
                              if (screenshotUrl != null && screenshotUrl.toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Payment Screenshot:',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    screenshotUrl,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 150,
                                      width: double.infinity,
                                      color: bg,
                                      child: Center(
                                        child: Icon(Icons.broken_image, color: textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _red.withValues(alpha: 0.1),
                                        foregroundColor: _red,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _rejectUpgrade(req),
                                      child: Text(
                                        'Reject',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _green,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _approveUpgrade(req),
                                      child: Text(
                                        'Approve',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: _amber),
                  ),
                  error: (err, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Text('Error loading requests: $err', style: GoogleFonts.inter(color: _red)),
                         const SizedBox(height: 16),
                         ElevatedButton(
                           onPressed: () => ref.invalidate(adminUpgradeRequestsProvider),
                           style: ElevatedButton.styleFrom(backgroundColor: _amber),
                           child: Text('Retry', style: GoogleFonts.inter(color: bg)),
                         ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: _amber),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
