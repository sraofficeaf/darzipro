import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import '../../core/services/admin_service.dart';

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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Process Payouts'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar ───────────────────────────────────────────────
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
                          '🔗 Invites & Profit Payouts',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: text1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Track multi-level profit earnings (Level 1-4) and process monthly inviter payouts',
                          style: GoogleFonts.inter(fontSize: 12, color: text2),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: text2,
                    onPressed: _refreshAll,
                  ),
                ],
              ),
            ),

            // ── Tab Bar ──────────────────────────────────────────────────────
            Container(
              color: surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: text2,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '💰 Multi-Level Earnings'),
                  Tab(text: '💳 Monthly Payout Queue'),
                ],
              ),
            ),

            // ── Tab Bar Views ────────────────────────────────────────────────
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.stars_rounded, color: AppColors.accent, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL PENDING PROFIT EARNINGS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: context.text2)),
                            const SizedBox(height: 2),
                            Text('Rs ${_fmt(pendingTotal)}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
                          ],
                        ),
                      ),
                      DropdownButton<int>(
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Earnings List / Table
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text('No profit earnings match criteria.', style: GoogleFonts.inter(color: context.text2))),
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
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Column(
        children: items.map((e) {
          final level = (e['level'] as int?) ?? 1;
          final inviterName = e['inviter_shop']?['name'] as String? ?? 'Inviter';
          final invitedName = e['invited_shop']?['name'] as String? ?? 'Invitee';
          final dateStr = e['earned_at'] as String? ?? '';
          final dateFormatted = dateStr.isNotEmpty ? DateFormat('MMM dd, yyyy').format(DateTime.parse(dateStr)) : '';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
            child: Row(
              children: [
                _LevelBadge(level: level),
                const SizedBox(width: 12),
                Expanded(child: Text('$inviterName (Inviter)', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: text1))),
                Expanded(child: Text('From: $invitedName', style: GoogleFonts.inter(fontSize: 12, color: text2))),
                Text(dateFormatted, style: GoogleFonts.inter(fontSize: 12, color: text2)),
                const SizedBox(width: 16),
                Text('Rs ${_fmt(e['amount'] as int? ?? 0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accent)),
              ],
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

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(inviterName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1))),
                  _LevelBadge(level: level),
                ],
              ),
              const SizedBox(height: 4),
              Text('Invited Shop: $invitedName', style: GoogleFonts.inter(fontSize: 12, color: text2)),
              const SizedBox(height: 6),
              Text('Rs ${_fmt(e['amount'] as int? ?? 0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accent)),
            ],
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Process Payouts Bar
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.border),
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
                      ElevatedButton.icon(
                        onPressed: isProcessing ? null : onProcess,
                        icon: isProcessing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.bolt_rounded),
                        label: const Text('Process Payouts'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (payouts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('No payouts created yet. Click "Process Payouts" above to batch eligible earnings.', style: GoogleFonts.inter(color: context.text2), textAlign: TextAlign.center),
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
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
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

          return Container(
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
                        Text('⚠️ No payout method set in Invite & Earn settings!', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFFF3A58))),
                    ],
                  ),
                ),
                Text('Rs ${_fmt(amount)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accent)),
                const SizedBox(width: 16),
                if (status == 'paid')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
                    child: Text('PAID', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _handleMarkPaid(context, ref, p),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    child: const Text('Mark Paid'),
                  ),
              ],
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

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(shopName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1))),
                  Text('Rs ${_fmt(amount)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accent)),
                ],
              ),
              const SizedBox(height: 6),
              if (hasPayoutDetails)
                Text('Method: $payoutMethod · Acc: $accountNum ($accountName)', style: GoogleFonts.inter(fontSize: 11, color: text2))
              else
                Text('⚠️ No payout method set in settings!', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFFF3A58))),
              const SizedBox(height: 10),
              if (status == 'paid')
                Text('Status: PAID', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)))
              else
                ElevatedButton(
                  onPressed: () => _handleMarkPaid(context, ref, p),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  child: const Text('Mark as Paid'),
                ),
            ],
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Confirm Paid'),
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

class _LevelBadge extends StatelessWidget {
  final int level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
      ),
      child: Text('Level $level', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6))),
    );
  }
}

String _fmt(int n) => NumberFormat('#,##0').format(n);
