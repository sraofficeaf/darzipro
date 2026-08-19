import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_service.dart';
import '../../shared/providers/admin_providers.dart';

class AdminRegistrationsScreen extends ConsumerStatefulWidget {
  const AdminRegistrationsScreen({super.key});

  @override
  ConsumerState<AdminRegistrationsScreen> createState() => _AdminRegistrationsScreenState();
}

class _AdminRegistrationsScreenState extends ConsumerState<AdminRegistrationsScreen> {
  static const Color _amber = Color(0xFFF5A623);
  static const Color _red = Color(0xFFFF3A58);
  static const Color _green = Color(0xFF10B981);

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
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
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectRegistration(Map<String, dynamic> reg) async {
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
            'Reject Registration',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejecting ${reg['shop_name']}:',
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
              backgroundColor: _red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Rejection failed.'),
              backgroundColor: _red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: _red,
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
                          'Registration Queue',
                          style: GoogleFonts.outfit(
                            color: textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pending admin approval for public signups',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: textSecondary),
                      onPressed: () => ref.invalidate(adminRegistrationsProvider),
                    ),
                  ],
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
                            const Icon(Icons.check_circle_outline, color: _green, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              '🎉 No pending registrations!',
                              style: GoogleFonts.outfit(
                                color: textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All public registration requests have been reviewed.',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: registrations.length,
                      itemBuilder: (context, index) {
                        final reg = registrations[index];
                        final inviteCode = reg['invite_code_used'];
                        final createdAt = reg['created_at'] != null
                            ? DateTime.parse(reg['created_at'])
                            : DateTime.now();
                        final submittedDate = _dateFormat.format(createdAt);
                        final planSelected = reg['plan_selected'];

                        String planBadgeText = 'Plan Not Set';
                        Color planBadgeColor = Colors.grey;
                        if (planSelected == 'full_access') {
                          planBadgeText = 'Full Access · Rs 35,000';
                          planBadgeColor = _amber;
                        } else if (planSelected == 'mobile_only') {
                          planBadgeText = 'Mobile Only · Rs 12,000';
                          planBadgeColor = const Color(0xFF0EA5E9); // Teal/Blue
                        }

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
                                      reg['shop_name'] ?? 'Unnamed Shop',
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
                                      color: planBadgeColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      planBadgeText,
                                      style: GoogleFonts.inter(
                                        color: planBadgeColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (inviteCode != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        inviteCode.toString(),
                                        style: GoogleFonts.inter(
                                          color: _amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(Icons.person, reg['owner_name'] ?? 'Unknown Owner', textPrimary, textSecondary),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.email, reg['email'] ?? 'No email', textPrimary, textSecondary),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.receipt, 'Tx: ${reg['transaction_id'] ?? 'N/A'}', textPrimary, textSecondary),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.calendar_today, 'Submitted: $submittedDate', textPrimary, textSecondary),
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
                                      onPressed: () => _rejectRegistration(reg),
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
                                      onPressed: () => _approveRegistration(reg),
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
                        Text('Error loading registrations: $err', style: GoogleFonts.inter(color: _red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(adminRegistrationsProvider),
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
