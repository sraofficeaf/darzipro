import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import 'widgets/admin_ui_kit.dart';

class AdminUpgradeRequestsScreen extends ConsumerStatefulWidget {
  const AdminUpgradeRequestsScreen({super.key});

  @override
  ConsumerState<AdminUpgradeRequestsScreen> createState() => _AdminUpgradeRequestsScreenState();
}

class _AdminUpgradeRequestsScreenState extends ConsumerState<AdminUpgradeRequestsScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy · hh:mm a');
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
              backgroundColor: AdminColors.emerald,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Approval failed: ${res['error']}'),
              backgroundColor: AdminColors.rose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: AdminColors.rose),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectUpgrade(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Reject Upgrade Request',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejecting this request:',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Invalid payment screenshot...',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            AdminButton.danger(
              label: 'Reject',
              onPressed: () => Navigator.pop(context, true),
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
              backgroundColor: AdminColors.rose,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Rejection failed: ${success['error']}'),
              backgroundColor: AdminColors.rose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: AdminColors.rose),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRequests = ref.watch(adminUpgradeRequestsProvider);
    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final textPrimary = context.text1;
    final textSecondary = context.text2;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                RepaintBoundary(
                  child: AdminPageHeader(
                    title: 'Upgrade Requests',
                    subtitle: 'Pending review and license upgrades',
                    action: AdminIconBtn(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh Requests',
                      onPressed: () => ref.invalidate(adminUpgradeRequestsProvider),
                    ),
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
                              const Icon(Icons.upgrade_rounded, color: AdminColors.emerald, size: 56),
                              const SizedBox(height: 14),
                              Text(
                                'No Pending Upgrade Requests',
                                style: GoogleFonts.outfit(
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All shop upgrade requests have been processed.',
                                style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
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

                          return RepaintBoundary(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                                boxShadow: context.cardShadow,
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      AdminBadge(
                                        label: 'Rs ${NumberFormat('#,###').format(amount)}',
                                        color: AdminColors.amber,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _buildInfoRow(Icons.receipt_long_rounded, 'Tx: $transactionId', textPrimary, textSecondary),
                                  const SizedBox(height: 6),
                                  _buildInfoRow(Icons.access_time_rounded, 'Submitted: $submittedDate', textPrimary, textSecondary),
                                  if (screenshotUrl != null && screenshotUrl.toString().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            child: Image.network(screenshotUrl, fit: BoxFit.contain),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          screenshotUrl,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            height: 80,
                                            width: double.infinity,
                                            color: border.withValues(alpha: 0.2),
                                            child: Center(
                                              child: Icon(Icons.broken_image, color: textSecondary),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AdminButton.danger(
                                          label: 'Reject',
                                          icon: Icons.close_rounded,
                                          onPressed: () => _rejectUpgrade(req),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: AdminButton.success(
                                          label: 'Approve',
                                          icon: Icons.check_rounded,
                                          onPressed: () => _approveUpgrade(req),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AdminColors.indigo),
                    ),
                    error: (err, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error loading requests: $err', style: GoogleFonts.inter(color: AdminColors.rose)),
                          const SizedBox(height: 16),
                          AdminButton.primary(
                            label: 'Retry',
                            onPressed: () => ref.invalidate(adminUpgradeRequestsProvider),
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
                  child: CircularProgressIndicator(color: AdminColors.indigo),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, size: 15, color: textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
