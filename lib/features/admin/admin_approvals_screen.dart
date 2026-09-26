import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import 'widgets/admin_ui_kit.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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
    ref.invalidate(adminSubscriptionPaymentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final regsAsync = ref.watch(adminRegistrationsProvider);
    final upgAsync = ref.watch(adminUpgradeRequestsProvider);
    final storageAsync = ref.watch(adminStorageAddonsProvider);
    final subPaymentsAsync = ref.watch(adminSubscriptionPaymentsProvider);

    final regCount = regsAsync.valueOrNull?.length ?? 0;
    final upgCount = upgAsync.valueOrNull?.length ?? 0;
    final storageCount = storageAsync.valueOrNull?.length ?? 0;
    final subPayCount = subPaymentsAsync.valueOrNull?.length ?? 0;

    final bg = context.bg;
    final surface = context.surface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header (RepaintBoundary for zero scroll cost) ──────────
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'Approvals Queue',
                subtitle: 'Review and approve pending registrations, upgrades, and storage add-ons',
                action: AdminIconBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh Queues',
                  onPressed: _refreshAll,
                ),
              ),
            ),

            // ── Tab Bar with Live Count Badges ───────────────────────────
            Container(
              color: surface,
              child: AdminTabBar(
                controller: _tabController,
                tabs: [
                  Tab(child: AdminCountBadge(label: 'Registrations', count: regCount, color: AdminColors.blue)),
                  Tab(child: AdminCountBadge(label: 'Upgrades', count: upgCount, color: AdminColors.amber)),
                  Tab(child: AdminCountBadge(label: 'Storage Add-ons', count: storageCount, color: AdminColors.emerald)),
                  Tab(child: AdminCountBadge(label: 'Subscriptions', count: subPayCount, color: AdminColors.violet)),
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
                  _SubscriptionsQueueTab(paymentsAsync: subPaymentsAsync, onRefresh: _refreshAll),
                ],
              ),
            ),
          ],
        ),
      ),
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
              return RepaintBoundary(
                child: isWide
                    ? _buildWideRegCard(context, ref, reg)
                    : _buildMobileRegCard(context, ref, reg),
              );
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

    final plan = reg['plan_selected'] as String? ?? 'trial';
    final (planLabel, planColor) = _getPlanBadge(plan);
    final dateStr = reg['created_at'] as String? ?? '';
    final formattedDate = dateStr.isNotEmpty ? DateFormat('MMM dd, yyyy · hh:mm a').format(DateTime.parse(dateStr)) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
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
                    AdminBadge(label: planLabel, color: planColor),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Owner: ${reg['owner_name'] ?? 'N/A'}  ·  Email: ${reg['email'] ?? 'N/A'}  ·  Phone: ${reg['phone'] ?? 'N/A'}',
                  style: GoogleFonts.inter(fontSize: 12, color: text2),
                ),
                const SizedBox(height: 3),
                Text(
                  'Address: ${reg['address'] ?? 'N/A'}',
                  style: GoogleFonts.inter(fontSize: 12, color: text2),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tx ID: ${reg['transaction_id'] ?? 'N/A'}  ·  Method: ${reg['payment_method'] ?? 'N/A'}  ·  Code: ${reg['invite_code_used'] ?? 'None'}',
                  style: GoogleFonts.inter(fontSize: 12, color: text2),
                ),
                const SizedBox(height: 5),
                Text(
                  'Submitted: $formattedDate',
                  style: GoogleFonts.inter(fontSize: 11, color: text2.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              AdminButton.success(
                label: 'Approve',
                icon: Icons.check_rounded,
                onPressed: () => _handleApproveReg(context, ref, reg),
              ),
              const SizedBox(height: 8),
              AdminButton.danger(
                label: 'Reject',
                icon: Icons.close_rounded,
                onPressed: () => _handleRejectReg(context, ref, reg),
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

    final plan = reg['plan_selected'] as String? ?? 'trial';
    final (planLabel, planColor) = _getPlanBadge(plan);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                  reg['shop_name'] as String? ?? 'Unnamed Shop',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1),
                ),
              ),
              AdminBadge(label: planLabel, color: planColor),
            ],
          ),
          const SizedBox(height: 6),
          Text('Owner: ${reg['owner_name'] ?? 'N/A'} (${reg['phone'] ?? 'N/A'})', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          Text('Address: ${reg['address'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          Text('Tx ID: ${reg['transaction_id'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildScreenshotThumb(context, reg['payment_screenshot_url'] as String?, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AdminButton.success(
                        label: 'Approve',
                        icon: Icons.check_rounded,
                        onPressed: () => _handleApproveReg(context, ref, reg),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminButton.danger(
                        label: 'Reject',
                        icon: Icons.close_rounded,
                        onPressed: () => _handleRejectReg(context, ref, reg),
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

  (String, Color) _getPlanBadge(String plan) => switch (plan.toLowerCase()) {
        'trial' => ('⏳ Free Trial', AdminColors.blue),
        'basic' => ('⚡ Basic Plan', AdminColors.blue),
        'standard' => ('🚀 Standard Plan', AdminColors.violet),
        'unlimited' => ('💎 Unlimited Plan', AdminColors.emerald),
        'founding' => ('👑 Founding Member', AdminColors.amber),
        _ => ('⚡ $plan Plan', AdminColors.blue),
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
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emerald),
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
    final plan = reg['plan_selected'] as String? ?? 'trial';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error approving: ${res['error']}'), backgroundColor: AdminColors.rose));
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
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.rose),
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
              return RepaintBoundary(
                child: isWide
                    ? _buildWideUpgCard(context, ref, upg)
                    : _buildMobileUpgCard(context, ref, upg),
              );
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
    final currentPlan = upg['current_plan'] as String? ?? 'basic';
    final targetPlan = upg['target_plan'] as String? ?? 'standard';
    final upgradeType = upg['upgrade_type'] as String? ?? '';
    final amount = upg['amount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
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
                    AdminBadge(label: '$currentPlan ➔ $targetPlan', color: AdminColors.amber),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Upgrade Type: ${_formatUpgType(upgradeType)}  ·  Amount: Rs ${_fmt(amount)}',
                  style: GoogleFonts.inter(fontSize: 12, color: text2, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Tx ID: ${upg['transaction_id'] ?? 'N/A'}  ·  Method: ${upg['payment_method'] ?? 'N/A'}',
                  style: GoogleFonts.inter(fontSize: 12, color: text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              AdminButton.success(
                label: 'Approve',
                icon: Icons.check_rounded,
                onPressed: () => _handleApproveUpg(context, ref, upg),
              ),
              const SizedBox(height: 8),
              AdminButton.danger(
                label: 'Reject',
                icon: Icons.close_rounded,
                onPressed: () => _handleRejectUpg(context, ref, upg),
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
    final targetPlan = upg['target_plan'] as String? ?? 'standard';
    final amount = upg['amount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              Expanded(child: Text(shopName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1))),
              AdminBadge(label: '➔ $targetPlan (Rs ${_fmt(amount)})', color: AdminColors.amber),
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
                      child: AdminButton.success(
                        label: 'Approve',
                        icon: Icons.check_rounded,
                        onPressed: () => _handleApproveUpg(context, ref, upg),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminButton.danger(
                        label: 'Reject',
                        icon: Icons.close_rounded,
                        onPressed: () => _handleRejectUpg(context, ref, upg),
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
        'basic' => 'Basic Plan',
        'standard' => 'Standard Plan',
        'unlimited' => 'Unlimited Plan',
        'founding' => 'Founding Member',
        _ => t.replaceAll('_', ' ').toUpperCase(),
      };

  void _handleApproveUpg(BuildContext context, WidgetRef ref, Map<String, dynamic> upg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Upgrade Request?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('This will upgrade the shop plan, unlock permanent invite levels, and calculate multi-level profit.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emerald), child: const Text('Approve')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['error']}'), backgroundColor: AdminColors.rose));
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
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AdminColors.rose), child: const Text('Reject')),
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
              return RepaintBoundary(
                child: isWide
                    ? _buildWideStorageCard(context, ref, s)
                    : _buildMobileStorageCard(context, ref, s),
              );
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
    final amount = s['amount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
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
                    AdminBadge(
                      label: addonType == 'annual' ? 'Annual Storage Add-on' : 'Monthly Storage Add-on',
                      color: AdminColors.emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Tx ID: ${s['transaction_id'] ?? 'N/A'}  ·  Method: ${s['payment_method'] ?? 'N/A'}  ·  Amount: Rs ${_fmt(amount)}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              AdminButton.success(
                label: 'Approve Add-on',
                icon: Icons.check_rounded,
                onPressed: () => _handleApproveStorage(context, ref, s),
              ),
              const SizedBox(height: 8),
              AdminButton.danger(
                label: 'Reject',
                icon: Icons.close_rounded,
                onPressed: () => _handleRejectStorage(context, ref, s),
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
    final amount = s['amount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              Expanded(child: Text(shopName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1))),
              AdminBadge(label: addonType == 'annual' ? 'Annual Add-on' : 'Monthly Add-on', color: AdminColors.emerald),
            ],
          ),
          const SizedBox(height: 6),
          Text('Tx ID: ${s['transaction_id'] ?? 'N/A'}  ·  Amount: Rs ${_fmt(amount)}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildScreenshotThumb(context, s['payment_screenshot_url'] as String?, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AdminButton.success(
                        label: 'Approve',
                        icon: Icons.check_rounded,
                        onPressed: () => _handleApproveStorage(context, ref, s),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminButton.danger(
                        label: 'Reject',
                        icon: Icons.close_rounded,
                        onPressed: () => _handleRejectStorage(context, ref, s),
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
        content: const Text('This will activate unlimited storage for this shop. (Note: Storage add-ons carry 0% profit share).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emerald), child: const Text('Approve')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['error']}'), backgroundColor: AdminColors.rose));
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
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AdminColors.rose), child: const Text('Reject')),
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
// TAB 4: SUBSCRIPTION PAYMENTS QUEUE
// =============================================================================
class _SubscriptionsQueueTab extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> paymentsAsync;
  final VoidCallback onRefresh;

  const _SubscriptionsQueueTab({required this.paymentsAsync, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No Pending Subscription Payments',
            subtitle: 'All subscription payment submissions have been reviewed!',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                child: _SubPaymentCard(
                  payment: items[index],
                  onApprove: () => _approvePayment(context, ref, items[index]),
                  onReject: () => _showRejectDialog(context, ref, items[index]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _approvePayment(BuildContext context, WidgetRef ref, Map<String, dynamic> payment) async {
    final purpose = (payment['purpose'] as String?) ??
        (payment['payment_type'] == 'founding_activation' ? 'foundingActivation' : 'subscriptionMonthly');
    final isFoundingActivation = purpose == 'foundingActivation';

    if (isFoundingActivation) {
      await _approveFoundingPayment(context, ref, payment);
      return;
    }

    final rawMinor = payment['amount_minor'];
    final amount = rawMinor != null
        ? ((rawMinor as num).toInt() / 100.0).round()
        : ((payment['amount_pkr'] as int?) ?? 0);
    final planCode = (payment['metadata'] is Map ? payment['metadata']['plan_code'] : null) ??
        payment['plan_code'] ??
        purpose;

    // Regular subscription or storage approval
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve Payment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Approve Rs $amount for "$planCode"?\nThis will fulfill and activate the shop subscription.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emerald),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await AdminService.instance.approveSubscriptionPayment(
      paymentId: payment['id'] as String,
      shopId: payment['shop_id'] as String,
      cycleId: payment['usage_cycle_id'] as String?,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✅ Payment approved & fulfilled!' : '❌ Approval failed'),
        backgroundColor: success ? AdminColors.emerald : AdminColors.rose,
      ));
      if (success) ref.invalidate(adminSubscriptionPaymentsProvider);
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> payment) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reject Payment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: 'e.g., Screenshot unclear', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.rose),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await AdminService.instance.rejectSubscriptionPayment(
      paymentId: payment['id'] as String,
      reason: reasonCtrl.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✅ Rejected' : '❌ Failed'),
        backgroundColor: success ? AdminColors.amber : AdminColors.rose,
      ));
      if (success) ref.invalidate(adminSubscriptionPaymentsProvider);
    }
  }

  Future<void> _approveFoundingPayment(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> payment,
  ) async {
    final settings = await AdminService.instance.fetchAppSettings(prefix: 'founding');
    final freeMonths = int.tryParse(settings['founding_free_months'] ?? '6') ?? 6;
    final storageGb  = double.tryParse(settings['founding_storage_limit_gb'] ?? '5') ?? 5.0;

    final rawMinor = payment['amount_minor'];
    final amount = rawMinor != null
        ? ((rawMinor as num).toInt() / 100.0).round()
        : ((payment['amount_pkr'] as int?) ?? 0);

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Text('👑 ', style: TextStyle(fontSize: 20)),
            Text('Approve Founding Activation', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: Rs $amount'),
            const SizedBox(height: 4),
            const Text('This will:'),
            const SizedBox(height: 4),
            Text('• Set plan to Founding Member'),
            Text('• Grant $freeMonths months FREE (no billing)'),
            Text('• Set storage limit to ${storageGb.toStringAsFixed(0)} GB'),
            Text('• Start recurring billing after free period'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminColors.amber.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Fulfills via shared fulfill_payment() function — atomic and idempotent.',
                style: GoogleFonts.inter(fontSize: 11, color: AdminColors.amber),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.amber),
            child: const Text('Activate Founding'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await AdminService.instance.approveFoundingActivationPayment(
      paymentId: payment['id'] as String,
      shopId: payment['shop_id'] as String,
      freeMonths: freeMonths,
      storageGb: storageGb,
    );
    if (context.mounted) {
      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
          ? '👑 Founding membership activated successfully!'
          : '❌ Failed: ${result['error'] ?? 'Unknown error'}'),
        backgroundColor: ok ? AdminColors.amber : AdminColors.rose,
        duration: const Duration(seconds: 5),
      ));
      if (ok) ref.invalidate(adminSubscriptionPaymentsProvider);
    }
  }
}

class _SubPaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _SubPaymentCard({required this.payment, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final rawMinor = payment['amount_minor'];
    final amount = rawMinor != null
        ? ((rawMinor as num).toInt() / 100.0).round()
        : ((payment['amount_pkr'] as int?) ?? 0);
    final currency = (payment['currency'] as String?) ?? 'PKR';
    final purpose = (payment['purpose'] as String?) ??
        (payment['payment_type'] == 'founding_activation' ? 'foundingActivation' : 'subscriptionMonthly');
    final isFoundingActivation = purpose == 'foundingActivation';
    final isStorage = purpose == 'storageMonthly' || purpose == 'storageAnnual';

    final planCode = (payment['metadata'] is Map ? payment['metadata']['plan_code'] : null) ??
        payment['plan_code'] ??
        purpose;
    final method = (payment['metadata'] is Map ? payment['metadata']['payment_method'] : null) ??
        payment['payment_method'] ??
        'Manual';
    final txId = (payment['manual_transaction_id'] as String?) ?? (payment['transaction_id'] as String?) ?? '';
    final receiptUrl = (payment['receipt_url'] as String?) ?? (payment['payment_screenshot_url'] as String?);
    final createdAt = payment['created_at'] as String?;
    final shopName = (payment['shops'] as Map?)?['name']?.toString() ?? 'Shop';
    final formattedDate = createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(createdAt).toLocal())
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFoundingActivation
            ? AdminColors.amber.withValues(alpha: 0.04)
            : context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFoundingActivation
              ? AdminColors.amber.withValues(alpha: 0.35)
              : context.border,
          width: isFoundingActivation ? 1.5 : 1,
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isFoundingActivation) ...[
                const AdminBadge(label: '👑 FOUNDING', color: AdminColors.amber),
                const SizedBox(width: 8),
              ] else if (isStorage) ...[
                const AdminBadge(label: '💾 STORAGE', color: AdminColors.emerald),
                const SizedBox(width: 8),
              ],
              AdminBadge(
                label: planCode.toString().toUpperCase(),
                color: isFoundingActivation
                    ? AdminColors.amber
                    : (isStorage ? AdminColors.emerald : AdminColors.violet),
              ),
              const Spacer(),
              Text(
                currency == 'PKR' ? 'Rs ${NumberFormat('#,###').format(amount)}' : '$currency $amount',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: context.text1),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text('Shop: $shopName', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.text1)),
          Text('Via: $method${txId.isNotEmpty ? " · TID: $txId" : ""}',
              style: GoogleFonts.inter(fontSize: 12, color: context.text2)),
          Text('Submitted: $formattedDate', style: GoogleFonts.inter(fontSize: 11, color: context.text2)),
          if (receiptUrl != null && receiptUrl.startsWith('http')) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => showDialog(context: context, builder: (_) => Dialog(child: Image.network(receiptUrl, fit: BoxFit.contain))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  receiptUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminButton.success(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  onPressed: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      decoration: BoxDecoration(
        color: context.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
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
