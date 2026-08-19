import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';

class AdminRevenueScreen extends ConsumerStatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  ConsumerState<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends ConsumerState<AdminRevenueScreen> {
  final _searchCtrl = TextEditingController();
  String _typeFilter = 'all'; // 'all' | 'registration' | 'upgrade' | 'storage'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final reportsAsync = ref.watch(adminReportsDataProvider);

    final reportsData = reportsAsync.valueOrNull ?? {};
    final rawTxs = List<Map<String, dynamic>>.from(reportsData['transactions'] ?? []);

    final List<Map<String, dynamic>> combinedPayments = rawTxs.where((t) => t['direction'] == 'In').map((t) {
      return {
        'type': t['type'] ?? 'Registration',
        'sub_type': t['type'] ?? 'Standard',
        'shop_name': t['shop_name'] ?? 'Shop',
        'amount': (t['amount'] as num?)?.toInt() ?? 0,
        'payment_method': t['payment_method'] ?? 'Online',
        'transaction_id': t['transaction_id'] ?? 'N/A',
        'status': (t['status'] ?? 'approved').toString(),

        'date': t['date'] ?? '',
      };
    }).toList();


    // Calculate totals
    int totalRev = 0;
    int regRev = 0;
    int upgRev = 0;
    int storageRev = 0;

    int easypaisaTotal = 0;
    int jazzcashTotal = 0;
    int bankTotal = 0;

    for (final p in combinedPayments) {
      final amt = p['amount'] as int? ?? 0;
      totalRev += amt;
      final type = p['type'] as String;
      if (type == 'Registration') {
        regRev += amt;
      } else if (type == 'Upgrade') {
        upgRev += amt;
      } else if (type == 'Storage Add-on') {
        storageRev += amt;
      }

      final method = (p['payment_method'] as String? ?? '').toLowerCase();
      if (method.contains('easy')) {
        easypaisaTotal += amt;
      } else if (method.contains('jazz')) {
        jazzcashTotal += amt;
      } else {
        bankTotal += amt;
      }
    }

    // Filter by query and type
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = combinedPayments.where((p) {
      if (_typeFilter != 'all') {
        if (_typeFilter == 'registration' && p['type'] != 'Registration') return false;
        if (_typeFilter == 'upgrade' && p['type'] != 'Upgrade') return false;
        if (_typeFilter == 'storage' && p['type'] != 'Storage Add-on') return false;
      }
      if (query.isEmpty) return true;
      final shop = (p['shop_name'] ?? '').toString().toLowerCase();
      final tx = (p['transaction_id'] ?? '').toString().toLowerCase();
      return shop.contains(query) || tx.contains(query);
    }).toList();

    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Bar ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💰 Revenue & Financials',
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: text1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Combined financials from registrations, upgrades, and storage add-ons',
                        style: GoogleFonts.inter(fontSize: 12, color: text2),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: text2,
                    onPressed: () {
                      ref.invalidate(adminAllRegistrationsProvider);
                      ref.invalidate(adminUpgradeRequestsProvider);
                      ref.invalidate(adminStorageAddonsProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Metric Cards ───────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final cardW = w >= 600 ? (w - 24) / 3 : w;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(width: cardW, child: _buildMetricCard(context, 'TOTAL REVENUE', 'Rs ${_fmt(totalRev)}', const Color(0xFF10B981))),
                      SizedBox(width: cardW, child: _buildMetricCard(context, 'REGISTRATIONS', 'Rs ${_fmt(regRev)}', const Color(0xFF3B82F6))),
                      SizedBox(width: cardW, child: _buildMetricCard(context, 'UPGRADES & STORAGE', 'Rs ${_fmt(upgRev + storageRev)}', const Color(0xFFF5A623))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Revenue Split Breakdown ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📊 Revenue Split by Type', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1)),
                    const SizedBox(height: 12),
                    _SplitRow(title: '📱 Registrations', amount: regRev, color: const Color(0xFF3B82F6)),
                    const Divider(),
                    _SplitRow(title: '⭐ Plan Upgrades', amount: upgRev, color: const Color(0xFFF5A623)),
                    const Divider(),
                    _SplitRow(title: '💾 Storage Add-ons', amount: storageRev, color: const Color(0xFF10B981)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Payment Methods Breakdown ───────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final cardW = w >= 600 ? (w - 24) / 3 : w;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(width: cardW, child: _buildMethodCard(context, 'Easypaisa', 'Rs ${_fmt(easypaisaTotal)}', const Color(0xFF10B981))),
                      SizedBox(width: cardW, child: _buildMethodCard(context, 'JazzCash', 'Rs ${_fmt(jazzcashTotal)}', const Color(0xFFF5A623))),
                      SizedBox(width: cardW, child: _buildMethodCard(context, 'Bank Transfer', 'Rs ${_fmt(bankTotal)}', const Color(0xFF3B82F6))),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Filter & Search Bar ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by shop name or tx ID...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _typeFilter,
                    dropdownColor: surface,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: text1),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Types')),
                      DropdownMenuItem(value: 'registration', child: Text('Registrations')),
                      DropdownMenuItem(value: 'upgrade', child: Text('Upgrades')),
                      DropdownMenuItem(value: 'storage', child: Text('Storage Add-ons')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _typeFilter = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Payment History List ──────────────────────────────────
              isWide ? _buildPaymentTable(context, filtered) : _buildPaymentCards(context, filtered),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: context.text2)),
          const SizedBox(height: 6),
          Text(val, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildMethodCard(BuildContext context, String method, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(method, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: context.text1)),
          const SizedBox(height: 4),
          Text(val, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildPaymentTable(BuildContext context, List<Map<String, dynamic>> items) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Container(
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Column(
        children: items.map((p) {
          final type = p['type'] as String;
          final (typeLabel, typeColor) = _getTypeBadgeInfo(type);
          final dateStr = p['date'] as String? ?? '';
          final dateFormatted = dateStr.isNotEmpty ? DateFormat('MMM dd, yyyy').format(DateTime.parse(dateStr)) : '';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
            child: Row(
              children: [
                _TypeBadge(label: typeLabel, color: typeColor),
                const SizedBox(width: 12),
                Expanded(child: Text(p['shop_name'] as String? ?? 'Shop', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: text1))),
                Expanded(child: Text('Tx: ${p['transaction_id'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2))),
                Expanded(child: Text(dateFormatted, style: GoogleFonts.inter(fontSize: 12, color: text2))),
                Text('Rs ${_fmt(p['amount'] as int? ?? 0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accent)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentCards(BuildContext context, List<Map<String, dynamic>> items) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Column(
      children: items.map((p) {
        final type = p['type'] as String;
        final (typeLabel, typeColor) = _getTypeBadgeInfo(type);

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
                  Expanded(child: Text(p['shop_name'] as String? ?? 'Shop', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1))),
                  _TypeBadge(label: typeLabel, color: typeColor),
                ],
              ),
              const SizedBox(height: 6),
              Text('Tx ID: ${p['transaction_id'] ?? 'N/A'} · Method: ${p['payment_method'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: text2)),
              const SizedBox(height: 4),
              Text('Amount: Rs ${_fmt(p['amount'] as int? ?? 0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.accent)),
            ],
          ),
        );
      }).toList(),
    );
  }

  (String, Color) _getTypeBadgeInfo(String type) => switch (type) {
        'Registration' => ('Registration', const Color(0xFF3B82F6)),
        'Upgrade' => ('Upgrade', const Color(0xFFF5A623)),
        'Storage Add-on' => ('Storage', const Color(0xFF10B981)),
        _ => (type, AppColors.accent),
      };
}

class _SplitRow extends StatelessWidget {
  final String title;
  final int amount;
  final Color color;

  const _SplitRow({required this.title, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.text1)),
        Text('Rs ${_fmt(amount)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

String _fmt(int n) => NumberFormat('#,##0').format(n);
