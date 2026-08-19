import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';

class AdminApprovalsScreen extends ConsumerStatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  ConsumerState<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends ConsumerState<AdminApprovalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(adminRegistrationsProvider);
    ref.invalidate(adminUpgradeRequestsProvider);
    ref.invalidate(adminStorageAddonsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final regsAsync = ref.watch(adminRegistrationsProvider);
    final upgAsync = ref.watch(adminUpgradeRequestsProvider);
    final storageAsync = ref.watch(adminStorageAddonsProvider);

    final regCount = regsAsync.valueOrNull?.length ?? 0;
    final upgCount = upgAsync.valueOrNull?.length ?? 0;
    final storageCount = storageAsync.valueOrNull?.length ?? 0;

    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar / Header ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: surface,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✅ Approval Queues',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Review and approve pending registrations, upgrades, and storage add-ons',
                          style: GoogleFonts.inter(fontSize: 12, color: text2),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: text2,
                    tooltip: 'Refresh Queues',
                    onPressed: _refreshAll,
                  ),
                ],
              ),
            ),

            // ── Tab Bar with Count Badges ────────────────────────────────
            Container(
              color: surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: text2,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(child: _buildTabHeader('Registrations', regCount, const Color(0xFF3B82F6))),
                  Tab(child: _buildTabHeader('Upgrades', upgCount, const Color(0xFFF5A623))),
                  Tab(child: _buildTabHeader('Storage Add-ons', storageCount, const Color(0xFF10B981))),
                ],
              ),
            ),

            // ── Tab Views ────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RegistrationsQueueTab(regsAsync: regsAsync, onRefresh: _refreshAll),
                  _UpgradesQueueTab(upgAsync: upgAsync, onRefresh: _refreshAll),
                  _StorageAddonsQueueTab(storageAsync: storageAsync, onRefresh: _refreshAll),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader(String label, int count, Color badgeColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// TAB 1: REGISTRATIONS QUEUE
// =============================================================================
class _RegistrationsQueueTab extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> regsAsync;
  final VoidCallback onRefresh;

  const _RegistrationsQueueTab({required this.regsAsync, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return regsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading registrations: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'No Pending Registrations',
            subtitle: 'All self-registration requests have been reviewed!',
          );
        }

        final isWide = MediaQuery.of(context).size.width >= 720;
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final reg = items[index];
              return isWide
                  ? _buildWideRegCard(context, ref, reg)
                  : _buildMobileRegCard(context, ref, reg);
            },
          ),
        );
      },
    );
  }

  Widget _buildWideRegCard(BuildContext context, WidgetRef ref, Map<String, dynamic> reg) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final plan = reg['plan_selected'] as String? ?? 'mobile_only';
    final (planLabel, planPrice, planColor) = _getPlanDetails(plan);
    final dateStr = reg['created_at'] as String? ?? '';
    final formattedDate = dateStr.isNotEmpty ? DateFormat('MMM dd, yyyy · hh:mm a').format(DateTime.parse(dateStr)) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScreenshotThumb(context, reg['payment_screenshot_url'] as String?),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reg['shop_name'] as String? ?? 'Unnamed Shop',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1),
                    ),
                    const SizedBox(width: 8),
                    _PlanBadge(label: '$planLabel ($planPrice)', color: planColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Owner: ${reg['owner_name'] ?? 'N/A'} · Email: ${reg['email'] ?? 'N/A'} · Phone: ${reg['phone'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                const SizedBox(height: 4),
                Text('Address: ${reg['address'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                const SizedBox(height: 4),
                Text('Tx ID: ${reg['transaction_id'] ?? 'N/A'} · Method: ${reg['payment_method'] ?? 'N/A'} · Code Used: ${reg['invite_code_used'] ?? 'None'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                const SizedBox(height: 4),
                Text('Submitted: $formattedDate', style: GoogleFonts.inter(fontSize: 11, color: text2.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _handleApproveReg(context, ref, reg),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _handleRejectReg(context, ref, reg),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3A58),
                  side: const BorderSide(color: Color(0xFFFF3A58)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRegCard(BuildContext context, WidgetRef ref, Map<String, dynamic> reg) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final plan = reg['plan_selected'] as String? ?? 'mobile_only';
    final (planLabel, planPrice, planColor) = _getPlanDetails(plan);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
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
                  reg['shop_name'] as String? ?? 'Unnamed Shop',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1),
                ),
              ),
              _PlanBadge(label: planLabel, color: planColor),
            ],
          ),
          const SizedBox(height: 6),
          Text('Owner: ${reg['owner_name'] ?? 'N/A'} (${reg['phone'] ?? 'N/A'})', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          Text('Address: ${reg['address'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          Text('Tx ID: ${reg['transaction_id'] ?? 'N/A'} · Amount: $planPrice', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildScreenshotThumb(context, reg['payment_screenshot_url'] as String?, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleApproveReg(context, ref, reg),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Approve', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleRejectReg(context, ref, reg),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF3A58),
                          side: const BorderSide(color: Color(0xFFFF3A58)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Reject', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, String, Color) _getPlanDetails(String plan) => switch (plan) {
        'mobile_only' => ('📱 Basic Plan', 'Rs 12,000', const Color(0xFF3B82F6)),
        'full_access' => ('🚀 Professional Plan', 'Rs 35,000', const Color(0xFFF5A623)),
        'full_access_3yr' => ('👑 Enterprise Plan', 'Rs 70,000', const Color(0xFF10B981)),
        _ => ('📱 Basic Plan', 'Rs 12,000', const Color(0xFF3B82F6)),
      };

  void _handleApproveReg(BuildContext context, WidgetRef ref, Map<String, dynamic> reg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Registration?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('This will create Shop & User accounts, activate the license, and calculate multi-level invite profits for upline inviter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Approve Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = reg['id'] as String;
    final shopName = reg['shop_name'] as String? ?? 'Shop';
    final ownerName = reg['owner_name'] as String? ?? 'Owner';
    final email = reg['email'] as String? ?? '';
    final plan = reg['plan_selected'] as String? ?? 'mobile_only';
    final inviteCodeUsed = reg['invite_code_used'] as String?;

    final res = await AdminService.instance.approveRegistration(
      id: id,
      shopName: shopName,
      ownerName: ownerName,
      email: email,
      plan: plan,
      inviteCodeUsed: inviteCodeUsed,
    );

    if (res['success'] == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration approved successfully!')));
      }
      onRefresh();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error approving: ${res['error']}'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleRejectReg(BuildContext context, WidgetRef ref, Map<String, dynamic> reg) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Registration', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Enter rejection reason...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3A58)),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = reg['id'] as String;
    final ok = await AdminService.instance.rejectRegistration(id: id, reason: reasonCtrl.text.trim());
    if (ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration rejected.')));
      }
      onRefresh();
    }
  }
}

// =============================================================================
// TAB 2: UPGRADES QUEUE
// =============================================================================
class _UpgradesQueueTab extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> upgAsync;
  final VoidCallback onRefresh;

  const _UpgradesQueueTab({required this.upgAsync, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return upgAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading upgrade requests: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.upgrade_rounded,
            title: 'No Pending Upgrades',
            subtitle: 'No shop upgrade requests are awaiting review.',
          );
        }

        final isWide = MediaQuery.of(context).size.width >= 720;
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final upg = items[index];
              return isWide
                  ? _buildWideUpgCard(context, ref, upg)
                  : _buildMobileUpgCard(context, ref, upg);
            },
          ),
        );
      },
    );
  }

  Widget _buildWideUpgCard(BuildContext context, WidgetRef ref, Map<String, dynamic> upg) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final shopName = upg['shops']?['name'] as String? ?? 'Shop';
    final currentPlan = upg['current_plan'] as String? ?? 'mobile_only';
    final targetPlan = upg['target_plan'] as String? ?? 'full_access';
    final upgradeType = upg['upgrade_type'] as String? ?? '';
    final amount = upg['amount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScreenshotThumb(context, upg['payment_screenshot_url'] as String?),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(shopName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1)),
                    const SizedBox(width: 8),
                    _PlanBadge(label: '$currentPlan ➔ $targetPlan', color: const Color(0xFFF5A623)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Upgrade Type: ${_formatUpgType(upgradeType)} · Amount Paid: Rs ${_fmt(amount)}', style: GoogleFonts.inter(fontSize: 12, color: text2, fontWeight: FontWeight.w600)),
                Text('Tx ID: ${upg['transaction_id'] ?? 'N/A'} · Method: ${upg['payment_method'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _handleApproveUpg(context, ref, upg),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve Upgrade'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _handleRejectUpg(context, ref, upg),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3A58), side: const BorderSide(color: Color(0xFFFF3A58))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileUpgCard(BuildContext context, WidgetRef ref, Map<String, dynamic> upg) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final shopName = upg['shops']?['name'] as String? ?? 'Shop';
    final targetPlan = upg['target_plan'] as String? ?? 'full_access';
    final amount = upg['amount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(shopName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1))),
              _PlanBadge(label: '➔ $targetPlan (Rs ${_fmt(amount)})', color: const Color(0xFFF5A623)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Tx ID: ${upg['transaction_id'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildScreenshotThumb(context, upg['payment_screenshot_url'] as String?, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleApproveUpg(context, ref, upg),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                        child: const Text('Approve', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleRejectUpg(context, ref, upg),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3A58), side: const BorderSide(color: Color(0xFFFF3A58))),
                        child: const Text('Reject', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatUpgType(String t) => switch (t) {
        'to_full_access' => 'Full Access (Rs 23,000)',
        'to_3yr' => 'Full Access + 3Yr Storage (Rs 35,000)',
        'mobile_to_3yr' => 'Direct Jump to 3Yr Storage (Rs 58,000)',
        _ => t,
      };

  void _handleApproveUpg(BuildContext context, WidgetRef ref, Map<String, dynamic> upg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Upgrade Request?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('This will upgrade the shop plan, unlock permanent invite levels, and calculate multi-level profit.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), child: const Text('Approve')),
        ],
      ),
    );

    if (confirm != true) return;
    final id = upg['id'] as String;
    final shopId = upg['shop_id'] as String? ?? '';
    final invitedByCode = upg['shops']?['invited_by_code'] as String?;

    final res = await AdminService.instance.approveUpgradeRequest(
      upgradeRequestId: id,
      shopId: shopId,
      invitedByCode: invitedByCode,
    );

    if (res['success'] == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade approved successfully!')));
      }
      onRefresh();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['error']}'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleRejectUpg(BuildContext context, WidgetRef ref, Map<String, dynamic> upg) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Upgrade Request', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'Rejection reason...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3A58)), child: const Text('Reject')),
        ],
      ),
    );

    if (confirm != true) return;
    final id = upg['id'] as String;
    final res = await AdminService.instance.rejectUpgradeRequest(upgradeRequestId: id, reason: reasonCtrl.text.trim());
    if (res['success'] == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade rejected.')));
      }
      onRefresh();
    }
  }
}

// =============================================================================
// TAB 3: STORAGE ADD-ONS QUEUE
// =============================================================================
class _StorageAddonsQueueTab extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> storageAsync;
  final VoidCallback onRefresh;

  const _StorageAddonsQueueTab({required this.storageAsync, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return storageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading storage add-on payments: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.storage_rounded,
            title: 'No Pending Storage Add-ons',
            subtitle: 'No storage add-on payments are pending approval.',
          );
        }

        final isWide = MediaQuery.of(context).size.width >= 720;
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final s = items[index];
              return isWide
                  ? _buildWideStorageCard(context, ref, s)
                  : _buildMobileStorageCard(context, ref, s);
            },
          ),
        );
      },
    );
  }

  Widget _buildWideStorageCard(BuildContext context, WidgetRef ref, Map<String, dynamic> s) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final shopName = s['shops']?['name'] as String? ?? 'Shop';
    final addonType = s['addon_type'] as String? ?? 'monthly';
    final amount = s['amount'] as int? ?? 1200;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScreenshotThumb(context, s['payment_screenshot_url'] as String?),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(shopName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1)),
                    const SizedBox(width: 8),
                    _PlanBadge(
                      label: addonType == 'annual' ? 'Annual Storage (Rs 10,000)' : 'Monthly Storage (Rs 1,200)',
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Tx ID: ${s['transaction_id'] ?? 'N/A'} · Method: ${s['payment_method'] ?? 'N/A'} · Amount: Rs ${_fmt(amount)}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _handleApproveStorage(context, ref, s),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve Add-on'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _handleRejectStorage(context, ref, s),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3A58), side: const BorderSide(color: Color(0xFFFF3A58))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStorageCard(BuildContext context, WidgetRef ref, Map<String, dynamic> s) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final shopName = s['shops']?['name'] as String? ?? 'Shop';
    final addonType = s['addon_type'] as String? ?? 'monthly';
    final amount = s['amount'] as int? ?? 1200;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(shopName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1))),
              _PlanBadge(label: addonType == 'annual' ? 'Annual (10k)' : 'Monthly (1.2k)', color: const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Tx ID: ${s['transaction_id'] ?? 'N/A'} · Amount: Rs ${_fmt(amount)}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildScreenshotThumb(context, s['payment_screenshot_url'] as String?, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleApproveStorage(context, ref, s),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                        child: const Text('Approve', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleRejectStorage(context, ref, s),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3A58), side: const BorderSide(color: Color(0xFFFF3A58))),
                        child: const Text('Reject', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleApproveStorage(BuildContext context, WidgetRef ref, Map<String, dynamic> s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Storage Add-on?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('This will activate unlimited storage for this shop and trigger multi-level profit calculation for the upline.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), child: const Text('Approve')),
        ],
      ),
    );

    if (confirm != true) return;
    final id = s['id'] as String;
    final shopId = s['shop_id'] as String? ?? '';
    final invitedByCode = s['shops']?['invited_by_code'] as String?;

    final res = await AdminService.instance.approveStorageAddon(
      paymentId: id,
      shopId: shopId,
      invitedByCode: invitedByCode,
    );

    if (res['success'] == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage Add-on approved!')));
      }
      onRefresh();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['error']}'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleRejectStorage(BuildContext context, WidgetRef ref, Map<String, dynamic> s) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Storage Add-on', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'Rejection reason...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3A58)), child: const Text('Reject')),
        ],
      ),
    );

    if (confirm != true) return;
    final id = s['id'] as String;
    final res = await AdminService.instance.rejectStorageAddon(paymentId: id, reason: reasonCtrl.text.trim());
    if (res['success'] == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage Add-on rejected.')));
      }
      onRefresh();
    }
  }
}

// =============================================================================
// SHARED HELPER WIDGETS
// =============================================================================
Widget _buildScreenshotThumb(BuildContext context, String? url, {double size = 64}) {
  if (url == null || url.isEmpty) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: context.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.image_not_supported_rounded, size: 20, color: Colors.grey),
    );
  }

  return GestureDetector(
    onTap: () {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(url, fit: BoxFit.contain),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        ),
      );
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade800,
          child: const Icon(Icons.broken_image, size: 18, color: Colors.white54),
        ),

      ),
    ),
  );
}

class _PlanBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PlanBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: context.text2.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: context.text1)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: context.text2), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _fmt(int n) => NumberFormat('#,##0').format(n);
