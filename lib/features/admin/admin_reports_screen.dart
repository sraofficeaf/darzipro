import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import 'reports/reports_pdf_builder.dart';

enum DateRangePreset {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  thisYear('This Year'),
  custom('Custom Range');

  final String label;
  const DateRangePreset(this.label);
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateRangePreset _selectedPreset = DateRangePreset.thisMonth;
  late DateTime _startDate;
  late DateTime _endDate;

  String _txFilterType = 'All'; // 'All' | 'Registration' | 'Upgrade' | 'Storage' | 'Payout'
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  bool _isGeneratingPayoutPdf = false;

  Map<String, dynamic> _summaryData = {};
  Map<String, dynamic> _breakdownData = {};
  List<Map<String, dynamic>> _topEarners = [];
  List<Map<String, dynamic>> _allTransactions = [];

  // Payout Recipients state
  List<Map<String, dynamic>> _payoutRecipients = [];
  String _recipientSearchQuery = '';
  int _sortColumnIndex = 1; // Default: 'This Month Paid'
  bool _sortAscending = false; // Default: highest first

  final _currencyFmt = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _applyPreset(DateRangePreset.thisMonth, fetch: false);
    _loadReportData();
  }

  void _applyPreset(DateRangePreset preset, {bool fetch = true}) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (preset) {
      case DateRangePreset.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case DateRangePreset.yesterday:
        start = DateTime(now.year, now.month, now.day - 1);
        end = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        break;
      case DateRangePreset.thisWeek:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case DateRangePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case DateRangePreset.lastMonth:
        start = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0);
        end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
        break;
      case DateRangePreset.thisYear:
        start = DateTime(now.year, 1, 1);
        break;
      case DateRangePreset.custom:
        return;
    }

    setState(() {
      _selectedPreset = preset;
      _startDate = start;
      _endDate = end;
    });

    if (fetch) _loadReportData();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.accent,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = DateRangePreset.custom;
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final res = await AdminService.instance.fetchReportsData(
        startDate: _startDate,
        endDate: _endDate,
      );
      final recipients = await AdminService.instance.fetchPayoutRecipients();

      if (mounted) {
        setState(() {
          _summaryData = res['summary'] as Map<String, dynamic>? ?? {};
          _breakdownData = res['breakdown'] as Map<String, dynamic>? ?? {};
          _topEarners = List<Map<String, dynamic>>.from(res['top_earners'] ?? []);
          _allTransactions = List<Map<String, dynamic>>.from(res['transactions'] ?? []);
          _payoutRecipients = recipients;
          _sortRecipients(_sortColumnIndex, _sortAscending);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortRecipients(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      _payoutRecipients.sort((a, b) {
        dynamic aVal;
        dynamic bVal;

        switch (columnIndex) {
          case 0:
            aVal = (a['shop_name'] ?? '').toString().toLowerCase();
            bVal = (b['shop_name'] ?? '').toString().toLowerCase();
            break;
          case 1:
            aVal = a['this_month_paid'] as num? ?? 0;
            bVal = b['this_month_paid'] as num? ?? 0;
            break;
          case 2:
            aVal = a['last_month_paid'] as num? ?? 0;
            bVal = b['last_month_paid'] as num? ?? 0;
            break;
          case 3:
            aVal = a['total_paid_lifetime'] as num? ?? 0;
            bVal = b['total_paid_lifetime'] as num? ?? 0;
            break;
          case 4:
            aVal = DateTime.tryParse(a['last_payout_date']?.toString() ?? '') ?? DateTime(2000);
            bVal = DateTime.tryParse(b['last_payout_date']?.toString() ?? '') ?? DateTime(2000);
            break;
          default:
            aVal = a['this_month_paid'] as num? ?? 0;
            bVal = b['this_month_paid'] as num? ?? 0;
        }

        final int cmp = Comparable.compare(aVal, bVal);
        return ascending ? cmp : -cmp;
      });
    });
  }

  List<Map<String, dynamic>> get _filteredRecipients {
    if (_recipientSearchQuery.isEmpty) return _payoutRecipients;
    final q = _recipientSearchQuery.toLowerCase();
    return _payoutRecipients
        .where((r) => (r['shop_name'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  Future<void> _generateFullPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await ReportsPdfBuilder.buildPeriodReport(
        startDate: _startDate,
        endDate: _endDate,
        summary: _summaryData,
        breakdown: _breakdownData,
        topEarners: _topEarners,
        transactions: _filteredTransactions,
      );
      final filename = 'DarziPro_Financial_Report_${_dateFmt.format(_startDate)}_${_dateFmt.format(_endDate)}.pdf';
      await ReportsPdfBuilder.printOrSharePdf(pdfBytes, filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _exportPayoutHistoryPdf() async {
    setState(() => _isGeneratingPayoutPdf = true);
    try {
      final pdfBytes = await ReportsPdfBuilder.buildPayoutHistoryReport(_filteredRecipients);
      final filename = 'DarziPro_Payout_History_${_dateFmt.format(DateTime.now())}.pdf';
      await ReportsPdfBuilder.printOrSharePdf(pdfBytes, filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting payout history: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPayoutPdf = false);
    }
  }

  Future<void> _generateTransactionInvoicePdf(Map<String, dynamic> tx) async {
    try {
      final pdfBytes = await ReportsPdfBuilder.buildTransactionInvoice(tx);
      final filename = 'DarziPro_Receipt_${tx['id'] ?? 'tx'}.pdf';
      await ReportsPdfBuilder.printOrSharePdf(pdfBytes, filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating receipt: $e')),
        );
      }
    }
  }

  String _fmt(dynamic val) {
    final num n = val is num ? val : (num.tryParse(val.toString()) ?? 0);
    return 'Rs ${_currencyFmt.format(n)}';
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_txFilterType == 'All') return _allTransactions;
    return _allTransactions.where((t) {
      final type = t['type'].toString().toLowerCase();
      if (_txFilterType == 'Registration') return type.contains('registration');
      if (_txFilterType == 'Upgrade') return type.contains('upgrade');
      if (_txFilterType == 'Storage') return type.contains('storage');
      if (_txFilterType == 'Payout') return type.contains('payout') || t['direction'] == 'Out';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final dateRangeText = '${_dateFmt.format(_startDate)} – ${_dateFmt.format(_endDate)}';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: surface,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final titleWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 Reports & Financial Analytics',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: text1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Period: $dateRangeText',
                        style: GoogleFonts.inter(fontSize: 12, color: text2, fontWeight: FontWeight.w500),
                      ),
                    ],
                  );

                  final downloadBtn = ElevatedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _generateFullPdf,
                    icon: _isGeneratingPdf
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('📥', style: TextStyle(fontSize: 14)),
                    label: Text(_isGeneratingPdf ? 'Generating...' : 'Download Report (PDF)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  );

                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [titleWidget, downloadBtn],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: downloadBtn),
                      ],
                    );
                  }
                },
              ),
            ),

            // ── Main Content Scroll Area ─────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: _loadReportData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Date Range Presets Bar ───────────────────────────────
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: DateRangePreset.values.map((preset) {
                            final isSelected = _selectedPreset == preset;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(preset.label),
                                selected: isSelected,
                                selectedColor: AppColors.accent.withValues(alpha: 0.15),
                                backgroundColor: context.surface2,
                                side: BorderSide(
                                  color: isSelected ? AppColors.accent : border,
                                ),
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppColors.accent : text1,
                                ),
                                onSelected: (val) {
                                  if (preset == DateRangePreset.custom) {
                                    _pickCustomDateRange();
                                  } else {
                                    _applyPreset(preset);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_isLoading)
                        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
                      else ...[
                        // ── 1. SUMMARY CARDS (4-Grid) ──────────────────────────
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final crossCount = w >= 900 ? 4 : (w >= 500 ? 2 : 1);
                            return GridView.count(
                              crossAxisCount: crossCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: w >= 900 ? 1.8 : (w >= 500 ? 2.1 : 2.6),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _SummaryCard(
                                  title: 'Total Revenue',
                                  value: _fmt(_summaryData['total_revenue'] ?? 0),
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: AppColors.accent,
                                  subtitle: 'Registrations + Upgrades + Add-ons',
                                ),
                                _SummaryCard(
                                  title: 'Invite Payouts',
                                  value: _fmt(_summaryData['total_payouts'] ?? 0),
                                  icon: Icons.payments_rounded,
                                  color: const Color(0xFFE11D48),
                                  subtitle: 'Money sent out to inviters (Paid)',
                                ),
                                _SummaryCard(
                                  title: 'Net Revenue',
                                  value: _fmt(_summaryData['net_revenue'] ?? 0),
                                  icon: Icons.trending_up_rounded,
                                  color: const Color(0xFF3B82F6),
                                  subtitle: 'Total Revenue - Invite Payouts',
                                ),
                                _SummaryCard(
                                  title: 'Transaction Count',
                                  value: '${_summaryData['transaction_count'] ?? 0}',
                                  icon: Icons.receipt_long_rounded,
                                  color: const Color(0xFF8B5CF6),
                                  subtitle: 'Successful payments in range',
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── 2. REVENUE BREAKDOWN ───────────────────────────────
                        Text('Revenue Breakdown', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: text1)),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth >= 720;
                            final byType = _breakdownData['by_type'] as Map<String, dynamic>? ?? {};
                            final byTier = _breakdownData['by_tier'] as Map<String, dynamic>? ?? {};

                            final typeWidget = _buildBreakdownCard(
                              title: 'By Category / Type',
                              icon: Icons.category_rounded,
                              children: [
                                _BreakdownRow('Registrations', _fmt(byType['registrations']?['amount'] ?? 0), '${byType['registrations']?['count'] ?? 0} txs'),
                                _BreakdownRow('Upgrades', _fmt(byType['upgrades']?['amount'] ?? 0), '${byType['upgrades']?['count'] ?? 0} txs'),
                                _BreakdownRow('Storage (Monthly)', _fmt(byType['storage_monthly']?['amount'] ?? 0), '${byType['storage_monthly']?['count'] ?? 0} txs'),
                                _BreakdownRow('Storage (Annual)', _fmt(byType['storage_annual']?['amount'] ?? 0), '${byType['storage_annual']?['count'] ?? 0} txs'),
                              ],
                            );

                            final tierWidget = _buildBreakdownCard(
                              title: 'By Plan Tier',
                              icon: Icons.layers_rounded,
                              children: [
                                _BreakdownRow('Mobile Only', _fmt(byTier['mobile_only']?['amount'] ?? 0), 'Tier Revenue'),
                                _BreakdownRow('Full Access', _fmt(byTier['full_access']?['amount'] ?? 0), 'Tier Revenue'),
                                _BreakdownRow('Full Access + 3yr', _fmt(byTier['full_access_3yr']?['amount'] ?? 0), 'Tier Revenue'),
                              ],
                            );

                            if (isDesktop) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: typeWidget),
                                  const SizedBox(width: 14),
                                  Expanded(child: tierWidget),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  typeWidget,
                                  const SizedBox(height: 14),
                                  tierWidget,
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── 3. TOP EARNERS TABLE ───────────────────────────────
                        Text('Top Inviter Earners', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: text1)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                            boxShadow: context.cardShadow,
                          ),
                          child: _topEarners.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(child: Text('No earning events recorded for this range.', style: GoogleFonts.inter(color: text2))),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('#')),
                                      DataColumn(label: Text('Shop Name')),
                                      DataColumn(label: Text('Earning Events')),
                                      DataColumn(label: Text('Total Earned')),
                                    ],
                                    rows: _topEarners.take(10).toList().asMap().entries.map((entry) {
                                      final idx = entry.key + 1;
                                      final row = entry.value;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text('$idx', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                                          DataCell(Text('${row['shop_name'] ?? 'Unknown'}', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                                          DataCell(Text('${row['events_count'] ?? 0} events')),
                                          DataCell(Text(_fmt(row['total_earned'] ?? 0), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: AppColors.accent))),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // ── 4. PAYOUT RECIPIENTS SECTION ───────────────────────
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 600;
                            final headerText = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('💸 Payout Recipients', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: text1)),
                                const SizedBox(height: 2),
                                Text(
                                  'Per-shop paid amount breakdown (This Month, Last Month & Lifetime)',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: text2),
                                ),
                              ],
                            );

                            final exportBtn = OutlinedButton.icon(
                              onPressed: _isGeneratingPayoutPdf ? null : _exportPayoutHistoryPdf,
                              icon: _isGeneratingPayoutPdf
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                                  : const Text('📄', style: TextStyle(fontSize: 14)),
                              label: Text(_isGeneratingPayoutPdf ? 'Exporting...' : 'Export Payout History (PDF)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            );

                            if (isWide) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [headerText, exportBtn],
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  headerText,
                                  const SizedBox(height: 10),
                                  SizedBox(width: double.infinity, child: exportBtn),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // Search Bar for Payout Recipients
                        TextField(
                          onChanged: (val) => setState(() => _recipientSearchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search shop by name...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            filled: true,
                            fillColor: surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                          ),
                          style: GoogleFonts.inter(fontSize: 13, color: text1),
                        ),
                        const SizedBox(height: 12),

                        // Interactive Payout Recipients Table
                        Container(
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                            boxShadow: context.cardShadow,
                          ),
                          child: _filteredRecipients.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(child: Text('No payout recipients found.', style: GoogleFonts.inter(color: text2))),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    sortColumnIndex: _sortColumnIndex,
                                    sortAscending: _sortAscending,
                                    columns: [
                                      DataColumn(
                                        label: const Text('Shop Name'),
                                        onSort: (idx, asc) => _sortRecipients(idx, asc),
                                      ),
                                      DataColumn(
                                        label: const Text('This Month Paid'),
                                        numeric: true,
                                        onSort: (idx, asc) => _sortRecipients(idx, asc),
                                      ),
                                      DataColumn(
                                        label: const Text('Last Month Paid'),
                                        numeric: true,
                                        onSort: (idx, asc) => _sortRecipients(idx, asc),
                                      ),
                                      DataColumn(
                                        label: const Text('Total Paid Lifetime'),
                                        numeric: true,
                                        onSort: (idx, asc) => _sortRecipients(idx, asc),
                                      ),
                                      DataColumn(
                                        label: const Text('Last Payout Date'),
                                        onSort: (idx, asc) => _sortRecipients(idx, asc),
                                      ),
                                    ],
                                    rows: _filteredRecipients.map((r) {
                                      final lastDateStr = r['last_payout_date'] != null
                                          ? _dateFmt.format(DateTime.parse(r['last_payout_date'].toString()))
                                          : '-';
                                      return DataRow(
                                        cells: [
                                          DataCell(Text('${r['shop_name'] ?? 'Unknown'}', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                                          DataCell(Text(_fmt(r['this_month_paid'] ?? 0), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: AppColors.accent))),
                                          DataCell(Text(_fmt(r['last_month_paid'] ?? 0), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600))),
                                          DataCell(Text(_fmt(r['total_paid_lifetime'] ?? 0), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold))),
                                          DataCell(Text(lastDateStr, style: GoogleFonts.inter(fontSize: 12, color: text2))),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // ── 5. FULL TRANSACTION LIST ───────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Transaction Ledger', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: text1)),
                            Text('${_filteredTransactions.length} items', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Transaction Type Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Registration', 'Upgrade', 'Storage', 'Payout'].map((filter) {
                              final isSelected = _txFilterType == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(filter),
                                  selected: isSelected,
                                  selectedColor: AppColors.accent.withValues(alpha: 0.15),
                                  backgroundColor: context.surface2,
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.accent : text1,
                                  ),
                                  onSelected: (_) => setState(() => _txFilterType = filter),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Transaction Ledger Table
                        Container(
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                            boxShadow: context.cardShadow,
                          ),
                          child: _filteredTransactions.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(child: Text('No transactions match the selected filter.', style: GoogleFonts.inter(color: text2))),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Type')),
                                      DataColumn(label: Text('Shop Name')),
                                      DataColumn(label: Text('Dir')),
                                      DataColumn(label: Text('Amount')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Receipt')),
                                    ],
                                    rows: _filteredTransactions.map((tx) {
                                      final isOut = tx['direction'] == 'Out';
                                      final dateStr = tx['date'] != null ? _dateFmt.format(DateTime.parse(tx['date'].toString())) : '-';
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(dateStr, style: GoogleFonts.inter(fontSize: 12))),
                                          DataCell(Text('${tx['type'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                                          DataCell(Text('${tx['shop_name'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isOut ? const Color(0xFFFFE4E6) : const Color(0xFFCCFBF1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isOut ? 'OUT' : 'IN',
                                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isOut ? const Color(0xFFE11D48) : AppColors.accent),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(_fmt(tx['amount'] ?? 0), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold))),
                                          DataCell(Text('${tx['status'] ?? 'completed'}', style: GoogleFonts.inter(fontSize: 11, color: text2))),
                                          DataCell(
                                            IconButton(
                                              icon: const Text('📄', style: TextStyle(fontSize: 16)),
                                              tooltip: 'Download Invoice Receipt',
                                              onPressed: () => _generateTransactionInvoicePdf(tx),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: text1)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.text2)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: context.text1)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: context.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final String detail;

  const _BreakdownRow(this.label, this.value, this.detail);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.text1)),
                Text(detail, style: GoogleFonts.inter(fontSize: 9.5, color: context.text3)),
              ],
            ),
            Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}
