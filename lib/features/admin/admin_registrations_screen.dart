import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import 'widgets/admin_ui_kit.dart';

class AdminRegistrationsScreen extends ConsumerStatefulWidget {
  const AdminRegistrationsScreen({super.key});

  @override
  ConsumerState<AdminRegistrationsScreen> createState() => _AdminRegistrationsScreenState();
}

class _AdminRegistrationsScreenState extends ConsumerState<AdminRegistrationsScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy · hh:mm a');
  bool _isProcessing = false;

  Future<void> _approveRegistration(Map<String, dynamic> reg) async {
    setState(() => _isProcessing = true);

    try {
      final planSelected = reg['plan_selected'] ?? 'full_access';

      final res = await AdminService.instance.approveRegistration(
        id: reg['id'],
        shopName: reg['shop_name'] ?? '',
        ownerName: reg['owner_name'] ?? '',
        email: reg['email'] ?? '',
        plan: planSelected,
        inviteCodeUsed: reg['invite_code_used'],
      );

      if (mounted) {
        if (res['success'] == true) {
          ref.invalidate(adminRegistrationsProvider);
          ref.invalidate(adminLicensesProvider);
          ref.invalidate(adminPaymentsProvider);
          ref.invalidate(adminAllRegistrationsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Registration approved! Shop created successfully.'),
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
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AdminColors.rose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectRegistration(Map<String, dynamic> reg) async {
    final reasonController = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Reject Registration',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejecting ${reg['shop_name']}:',
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
      final success = await AdminService.instance.rejectRegistration(
        id: reg['id'],
        reason: reasonController.text.isEmpty ? 'Registration rejected by admin.' : reasonController.text,
      );

      if (mounted) {
        if (success) {
          ref.invalidate(adminRegistrationsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Registration rejected.'),
              backgroundColor: AdminColors.rose,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Rejection failed.'),
              backgroundColor: AdminColors.rose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AdminColors.rose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRegistrations = ref.watch(adminRegistrationsProvider);
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
                    title: 'Registration Queue',
                    subtitle: 'Pending admin approval for public signups',
                    action: AdminIconBtn(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh Queue',
                      onPressed: () => ref.invalidate(adminRegistrationsProvider),
                    ),
                  ),
                ),

                // Content List
                Expanded(
                  child: asyncRegistrations.when(
                    data: (registrations) {
                      if (registrations.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, color: AdminColors.emerald, size: 56),
                              const SizedBox(height: 14),
                              Text(
                                'No Pending Registrations',
                                style: GoogleFonts.outfit(
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All public registration requests have been reviewed.',
                                style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: registrations.length,
                        itemBuilder: (context, index) {
                          final reg = registrations[index];
                          final inviteCode = reg['invite_code_used'];
                          final createdAt = reg['created_at'] != null
                              ? DateTime.parse(reg['created_at'])
                              : DateTime.now();
                          final submittedDate = _dateFormat.format(createdAt);
                          final planSelected = reg['plan_selected'];

                          String planBadgeText = 'Basic Plan';
                          Color planBadgeColor = AdminColors.blue;
                          if (planSelected == 'full_access') {
                            planBadgeText = 'Pro Plan · Rs 35k';
                            planBadgeColor = AdminColors.amber;
                          } else if (planSelected == 'mobile_only') {
                            planBadgeText = 'Basic · Rs 12k';
                            planBadgeColor = AdminColors.blue;
                          } else if (planSelected == 'full_access_3yr') {
                            planBadgeText = 'Enterprise · Rs 70k';
                            planBadgeColor = AdminColors.emerald;
                          }

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
                                          reg['shop_name'] ?? 'Unnamed Shop',
                                          style: GoogleFonts.outfit(
                                            color: textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      AdminBadge(label: planBadgeText, color: planBadgeColor),
                                      if (inviteCode != null) ...[
                                        const SizedBox(width: 8),
                                        AdminBadge(label: 'Ref: $inviteCode', color: AdminColors.indigo),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _buildInfoRow(Icons.person_rounded, reg['owner_name'] ?? 'Unknown Owner', textPrimary, textSecondary),
                                  const SizedBox(height: 6),
                                  _buildInfoRow(Icons.email_outlined, reg['email'] ?? 'No email', textPrimary, textSecondary),
                                  const SizedBox(height: 6),
                                  _buildInfoRow(Icons.receipt_long_rounded, 'Tx: ${reg['transaction_id'] ?? 'N/A'}', textPrimary, textSecondary),
                                  const SizedBox(height: 6),
                                  _buildInfoRow(Icons.access_time_rounded, 'Submitted: $submittedDate', textPrimary, textSecondary),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AdminButton.danger(
                                          label: 'Reject',
                                          icon: Icons.close_rounded,
                                          onPressed: () => _rejectRegistration(reg),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: AdminButton.success(
                                          label: 'Approve',
                                          icon: Icons.check_rounded,
                                          onPressed: () => _approveRegistration(reg),
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
                          Text('Error loading registrations: $err', style: GoogleFonts.inter(color: AdminColors.rose)),
                          const SizedBox(height: 16),
                          AdminButton.primary(
                            label: 'Retry',
                            onPressed: () => ref.invalidate(adminRegistrationsProvider),
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
