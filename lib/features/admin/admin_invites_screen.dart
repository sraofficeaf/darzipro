import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import '../../core/services/admin_service.dart';
import 'widgets/admin_ui_kit.dart';

class AdminInvitesScreen extends ConsumerStatefulWidget {
  const AdminInvitesScreen({super.key});

  @override
  ConsumerState<AdminInvitesScreen> createState() => _AdminInvitesScreenState();
}

class _AdminInvitesScreenState extends ConsumerState<AdminInvitesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(adminPendingEarningsProvider);
    ref.invalidate(adminPayoutsProvider);
  }

  String _getCurrentMonthDisplay() => DateFormat('MMMM yyyy').format(DateTime.now());
  String _getCurrentMonthKey() => DateFormat('yyyy-MM').format(DateTime.now());

  Future<void> _handleProcessPayouts() async {
    final displayMonth = _getCurrentMonthDisplay();
    final monthKey = _getCurrentMonthKey();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Process Payout Batch ($displayMonth)?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('This will calculate all eligible pending earnings meeting the minimum payout threshold and create payout records for inviter shops. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          AdminButton.primary(
            label: 'Process Payouts',
            icon: Icons.bolt_rounded,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await AdminService.instance.processPayout(monthKey);
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Payouts processed for $displayMonth')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AdminColors.rose));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(adminPendingEarningsProvider);
    final payoutsAsync = ref.watch(adminPayoutsProvider);
    final bg = context.bg;
    final surface = context.surface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header (RepaintBoundary for zero scroll cost)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'Invites & Profit Payouts',
                subtitle: 'Track multi-level profit earnings (Level 1-4) and process monthly inviter payouts',
                action: AdminIconBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh All',
                  onPressed: _refreshAll,
                ),
              ),
            ),

            // Tab Bar
            Container(
              color: surface,
              child: AdminTabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '💰 Multi-Level Earnings'),
                  Tab(text: '💳 Monthly Payout Queue'),
                ],
              ),
            ),

            // Tab Bar Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _EarningsTab(earningsAsync: earningsAsync, onRefresh: _refreshAll),
                  _PayoutsTab(
                    payoutsAsync: payoutsAsync,
                    isProcessing: _isProcessing,
                    onProcess: _handleProcessPayouts,
                    onRefresh: _refreshAll,
                  ),
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
// TAB 1: MULTI-LEVEL EARNINGS
// =============================================================================
class _EarningsTab extends ConsumerStatefulWidget {
  final AsyncValue<List<Map<String, dynamic>>> earningsAsync;
  final VoidCallback onRefresh;

  const _EarningsTab({required this.earningsAsync, required this.onRefresh});

  @override
  ConsumerState<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends ConsumerState<_EarningsTab> {
  int _selectedLevel = 0; // 0 = all, 1..4

  @override
  Widget build(BuildContext context) {
    return widget.earningsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading profit earnings: $e')),
      data: (items) {
        final filtered = items.where((e) {
          if (_selectedLevel != 0) {
            final level = (e['level'] as int?) ?? 1;
            if (level != _selectedLevel) return false;
          }
          return true;
        }).toList();

        int pendingTotal = 0;
        for (final e in items) {
          if (e['status'] == 'pending') {
            pendingTotal += (e['amount'] as int? ?? 0);
          }
        }

        final isWide = MediaQuery.of(context).size.width >= 720;

        return RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Bar matching HTML Section 3
                RepaintBoundary(
                  child: AdminSummaryBar(
                    icon: Icons.stars_rounded,
                    label: 'TOTAL PENDING PROFIT EARNINGS',
                    value: 'Rs ${_fmt(pendingTotal)}',
                    color: AdminColors.amber,
                    trailing: DropdownButton<int>(
                      value: _selectedLevel,
                      dropdownColor: context.surface,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.text1),
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('All Levels')),
                        DropdownMenuItem(value: 1, child: Text('Level 1 (15%)')),
                        DropdownMenuItem(value: 2, child: Text('Level 2 (2.5%)')),
                        DropdownMenuItem(value: 3, child: Text('Level 3 (1.5%)')),
                        DropdownMenuItem(value: 4, child: Text('Level 4 (1.0%)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedLevel = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Earnings List / Table
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('No profit earnings match criteria.', style: GoogleFonts.inter(color: context.text2)),
                    ),
                  )
                else
                  isWide ? _buildWideEarningsTable(context, filtered) : _buildMobileEarningsCards(context, filtered),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideEarningsTable(BuildContext context, List<Map<String, dynamic>> items) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: items.map((e) {
          final level = (e['level'] as int?) ?? 1;
          final inviterName = e['inviter_shop']?['name'] as String? ?? 'Inviter';
          final invitedName = e['invited_shop']?['name'] as String? ?? 'Invitee';
          final dateStr = e['earned_at'] as String? ?? '';
          final dateFormatted = dateStr.isNotEmpty ? DateFormat('MMM dd, yyyy').format(DateTime.parse(dateStr)) : '';

          return RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
              child: Row(
                children: [
                  AdminBadge(label: 'Level $level', color: AdminColors.violet),
                  const SizedBox(width: 12),
                  Expanded(child: Text('$inviterName (Inviter)', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: text1))),
                  Expanded(child: Text('From: $invitedName', style: GoogleFonts.inter(fontSize: 12, color: text2))),
                  Text(dateFormatted, style: GoogleFonts.inter(fontSize: 12, color: text2)),
                  const SizedBox(width: 16),
                  Text('Rs ${_fmt(e['amount'] as int? ?? 0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AdminColors.amber)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileEarningsCards(BuildContext context, List<Map<String, dynamic>> items) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Column(
      children: items.map((e) {
        final level = (e['level'] as int?) ?? 1;
        final inviterName = e['inviter_shop']?['name'] as String? ?? 'Inviter';
        final invitedName = e['invited_shop']?['name'] as String? ?? 'Invitee';

        return RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
              boxShadow: context.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(inviterName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1))),
                    AdminBadge(label: 'Level $level', color: AdminColors.violet),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Invited Shop: $invitedName', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                const SizedBox(height: 6),
                Text('Rs ${_fmt(e['amount'] as int? ?? 0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AdminColors.amber)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// =============================================================================
// TAB 2: MONTHLY PAYOUT QUEUE
// =============================================================================
class _PayoutsTab extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> payoutsAsync;
  final bool isProcessing;
  final VoidCallback onProcess;
  final VoidCallback onRefresh;

  const _PayoutsTab({
    required this.payoutsAsync,
    required this.isProcessing,
    required this.onProcess,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return payoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading payouts: $e')),
      data: (payouts) {
        final isWide = MediaQuery.of(context).size.width >= 720;

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Process Payouts Bar
                RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.border),
                      boxShadow: context.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Batch Monthly Payout Run', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.text1)),
                              const SizedBox(height: 2),
                              Text('Scans all shops with pending earnings ≥ Rs 1,000 and creates payout records.', style: GoogleFonts.inter(fontSize: 12, color: context.text2)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AdminButton.primary(
                          label: isProcessing ? 'Processing...' : 'Process Payouts',
                          icon: isProcessing ? null : Icons.bolt_rounded,
                          onPressed: isProcessing ? null : onProcess,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (payouts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No payouts created yet. Click "Process Payouts" above to batch eligible earnings.',
                        style: GoogleFonts.inter(color: context.text2),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  isWide ? _buildWidePayoutTable(context, ref, payouts) : _buildMobilePayoutCards(context, ref, payouts),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWidePayoutTable(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> payouts) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: payouts.map((p) {
          final shop = p['shops'] as Map<String, dynamic>?;
          final shopName = shop?['name'] as String? ?? 'Shop';
          final status = p['status'] as String? ?? 'pending';
          final amount = p['amount'] as int? ?? 0;

          final payoutMethod = shop?['payout_method'] as String?;
          final accountNum = shop?['payout_account_number'] as String?;
          final accountName = shop?['payout_account_name'] as String?;

          final bool hasPayoutDetails = payoutMethod != null && payoutMethod.isNotEmpty && accountNum != null && accountNum.isNotEmpty;

          return RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shopName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1)),
                        const SizedBox(height: 2),
                        if (hasPayoutDetails)
                          Text('$payoutMethod: $accountNum ($accountName)', style: GoogleFonts.inter(fontSize: 11, color: text2))
                        else
                          Text('⚠️ No payout method set in Invite & Earn settings!', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.rose)),
                      ],
                    ),
                  ),
                  Text('Rs ${_fmt(amount)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AdminColors.amber)),
                  const SizedBox(width: 16),
                  if (status == 'paid')
                    const AdminBadge(label: 'PAID', color: AdminColors.emerald)
                  else
                    AdminButton.success(
                      label: 'Mark Paid',
                      icon: Icons.check_rounded,
                      onPressed: () => _handleMarkPaid(context, ref, p),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobilePayoutCards(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> payouts) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Column(
      children: payouts.map((p) {
        final shop = p['shops'] as Map<String, dynamic>?;
        final shopName = shop?['name'] as String? ?? 'Shop';
        final status = p['status'] as String? ?? 'pending';
        final amount = p['amount'] as int? ?? 0;

        final payoutMethod = shop?['payout_method'] as String?;
        final accountNum = shop?['payout_account_number'] as String?;
        final accountName = shop?['payout_account_name'] as String?;
        final bool hasPayoutDetails = payoutMethod != null && payoutMethod.isNotEmpty && accountNum != null && accountNum.isNotEmpty;

        return RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
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
                    Text('Rs ${_fmt(amount)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AdminColors.amber)),
                  ],
                ),
                const SizedBox(height: 6),
                if (hasPayoutDetails)
                  Text('Method: $payoutMethod · Acc: $accountNum ($accountName)', style: GoogleFonts.inter(fontSize: 11, color: text2))
                else
                  Text('⚠️ No payout method set in settings!', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.rose)),
                const SizedBox(height: 10),
                if (status == 'paid')
                  const AdminBadge(label: 'PAID', color: AdminColors.emerald)
                else
                  AdminButton.success(
                    label: 'Mark as Paid',
                    icon: Icons.check_rounded,
                    onPressed: () => _handleMarkPaid(context, ref, p),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _handleMarkPaid(BuildContext context, WidgetRef ref, Map<String, dynamic> payout) async {
    final txCtrl = TextEditingController();
    final shop = payout['shops'] as Map<String, dynamic>?;
    final method = shop?['payout_method'] as String? ?? 'Easypaisa';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark Payout as Paid', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: txCtrl,
          decoration: const InputDecoration(hintText: 'Transaction reference / Ref ID...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          AdminButton.success(
            label: 'Confirm Paid',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final payoutId = payout['id'] as String;
    final ok = await AdminService.instance.markPayoutPaid(
      payoutId: payoutId,
      method: method,
      txRef: txCtrl.text.trim(),
    );
    if (ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout marked as paid!')));
      }
      onRefresh();
    }
  }
}

String _fmt(int n) => NumberFormat('#,##0').format(n);
