import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import 'reports/reports_pdf_builder.dart';
import 'widgets/admin_ui_kit.dart';

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
                  primary: AdminColors.indigo,
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
      if (_txFilterType == 'Subscription') return type.contains('subscription') || type.contains('founding');
      if (_txFilterType == 'Storage') return type.contains('storage');
      if (_txFilterType == 'Legacy') return type.contains('legacy') || type.contains('registration') || type.contains('upgrade');
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
            // Top Header Bar (RepaintBoundary for zero scroll cost)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'Reports & Financial Analytics',
                subtitle: 'Period: $dateRangeText',
                action: AdminButton.primary(
                  label: _isGeneratingPdf ? 'Generating...' : 'Download Report (PDF)',
                  icon: _isGeneratingPdf ? null : Icons.download_rounded,
                  onPressed: _isGeneratingPdf ? null : _generateFullPdf,
                ),
              ),
            ),

            // Main Content Scroll Area
            Expanded(
              child: RefreshIndicator(
                color: AdminColors.indigo,
                onRefresh: _loadReportData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date Range Presets Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: DateRangePreset.values.map((preset) {
                            final isSelected = _selectedPreset == preset;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AdminChip(
                                label: preset.label,
                                isSelected: isSelected,
                                color: AdminColors.indigo,
                                onTap: () {
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
                      const SizedBox(height: 16),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator(color: AdminColors.indigo)),
                        )
                      else ...[
                        // 1. SUMMARY CARDS (4-Grid)
                        RepaintBoundary(
                          child: LayoutBuilder(
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
                                  AdminStatCard(
                                    title: 'Total Revenue',
                                    value: _fmt(_summaryData['total_revenue'] ?? 0),
                                    icon: Icons.account_balance_wallet_rounded,
                                    color: AdminColors.amber,
                                    subtitle: 'Subscriptions + Add-ons + Legacy History',
                                  ),
                                  AdminStatCard(
                                    title: 'Agency Profit Payouts',
                                    value: _fmt(_summaryData['total_payouts'] ?? 0),
                                    icon: Icons.payments_rounded,
                                    color: AdminColors.rose,
                                    subtitle: 'Money sent out to agencies (Paid)',
                                  ),
                                  AdminStatCard(
                                    title: 'Net Revenue',
                                    value: _fmt(_summaryData['net_revenue'] ?? 0),
                                    icon: Icons.trending_up_rounded,
                                    color: AdminColors.blue,
                                    subtitle: 'Total Revenue - Agency Payouts',
                                  ),
                                  AdminStatCard(
                                    title: 'Transaction Count',
                                    value: '${_summaryData['transaction_count'] ?? 0}',
                                    icon: Icons.receipt_long_rounded,
                                    color: AdminColors.violet,
                                    subtitle: 'Successful payments in range',
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. REVENUE BREAKDOWN
                        Text('Revenue Breakdown', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: text1)),
                        const SizedBox(height: 12),
                        RepaintBoundary(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final byType = _breakdownData['by_type'] as Map<String, dynamic>? ?? {};
                              final byTier = _breakdownData['by_tier'] as Map<String, dynamic>? ?? {};

                              final recTotal = (byType['subscription_monthly']?['amount'] ?? 0) +
                                  (byType['founding_monthly']?['amount'] ?? 0) +
                                  (byType['storage_monthly']?['amount'] ?? 0);
                              final oneTotal = (byType['founding_activation']?['amount'] ?? 0) +
                                  (byType['storage_annual']?['amount'] ?? 0) +
                                  ((byType['legacy_registrations']?['amount'] ?? byType['registrations']?['amount']) ?? 0) +
                                  ((byType['legacy_upgrades']?['amount'] ?? byType['upgrades']?['amount']) ?? 0);

                              final typeWidget = _buildBreakdownCard(
                                title: 'By Category / Type',
                                icon: Icons.category_rounded,
                                children: [
                                  _BreakdownGroupHeader(
                                    title: 'RECURRING',
                                    subtotal: _fmt(recTotal),
                                    color: AdminColors.blue,
                                  ),
                                  _BreakdownRow('Subscription (Monthly)', _fmt(byType['subscription_monthly']?['amount'] ?? 0), '${byType['subscription_monthly']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Founding Monthly', _fmt(byType['founding_monthly']?['amount'] ?? 0), '${byType['founding_monthly']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Storage (Monthly)', _fmt(byType['storage_monthly']?['amount'] ?? 0), '${byType['storage_monthly']?['count'] ?? 0} txs'),
                                  const SizedBox(height: 10),
                                  _BreakdownGroupHeader(
                                    title: 'ONE-TIME',
                                    subtotal: _fmt(oneTotal),
                                    color: AdminColors.amber,
                                  ),
                                  _BreakdownRow('Founding Activation', _fmt(byType['founding_activation']?['amount'] ?? 0), '${byType['founding_activation']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Storage (Annual)', _fmt(byType['storage_annual']?['amount'] ?? 0), '${byType['storage_annual']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Legacy Registrations (history only)', _fmt(byType['legacy_registrations']?['amount'] ?? byType['registrations']?['amount'] ?? 0), '${byType['legacy_registrations']?['count'] ?? byType['registrations']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Legacy Upgrades (history only)', _fmt(byType['legacy_upgrades']?['amount'] ?? byType['upgrades']?['amount'] ?? 0), '${byType['legacy_upgrades']?['count'] ?? byType['upgrades']?['count'] ?? 0} txs'),
                                ],
                              );

                              final tierWidget = _buildBreakdownCard(
                                title: 'By Plan Tier',
                                icon: Icons.layers_rounded,
                                children: [
                                  _BreakdownRow('Basic Plan', _fmt(byTier['basic']?['amount'] ?? 0), '${byTier['basic']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Standard Plan', _fmt(byTier['standard']?['amount'] ?? 0), '${byTier['standard']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Unlimited Plan', _fmt(byTier['unlimited']?['amount'] ?? 0), '${byTier['unlimited']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Founding Member', _fmt(byTier['founding']?['amount'] ?? 0), '${byTier['founding']?['count'] ?? 0} txs'),
                                  _BreakdownRow('Lifetime (Legacy)', _fmt(byTier['lifetime']?['amount'] ?? 0), '${byTier['lifetime']?['count'] ?? 0} txs'),
                                ],
                              );

                              final byProvider = _breakdownData['by_provider'] as Map<String, dynamic>? ?? {};
                              final stripeData = byProvider['stripe'] as Map<String, dynamic>? ?? {};
                              final manualData = byProvider['manual'] as Map<String, dynamic>? ?? {};

                              final providerWidget = _buildBreakdownCard(
                                title: 'By Payment Provider',
                                icon: Icons.payment_rounded,
                                children: [
                                  _BreakdownRow(
                                    'Stripe / Cards',
                                    _fmt(stripeData['amount'] ?? 0),
                                    '${stripeData['count'] ?? 0} txs',
                                  ),
                                  _BreakdownRow(
                                    'Manual (Bank/Wallets)',
                                    _fmt(manualData['amount'] ?? 0),
                                    '${manualData['count'] ?? 0} txs',
                                  ),
                                ],
                              );

                              if (constraints.maxWidth >= 960) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: typeWidget),
                                    const SizedBox(width: 14),
                                    Expanded(flex: 2, child: tierWidget),
                                    const SizedBox(width: 14),
                                    Expanded(flex: 2, child: providerWidget),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    typeWidget,
                                    const SizedBox(height: 14),
                                    tierWidget,
                                    const SizedBox(height: 14),
                                    providerWidget,
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3. TOP EARNERS TABLE
                        Text('Top Agency Earners', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: text1)),
                        const SizedBox(height: 12),
                        RepaintBoundary(
                          child: Container(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(14),
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
                                            DataCell(Text(_fmt(row['total_earned'] ?? 0), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AdminColors.amber))),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 4. PAYOUT RECIPIENTS SECTION
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

                            final exportBtn = AdminButton.ghost(
                              label: _isGeneratingPayoutPdf ? 'Exporting...' : 'Export History (PDF)',
                              icon: _isGeneratingPayoutPdf ? null : Icons.picture_as_pdf_rounded,
                              onPressed: _isGeneratingPayoutPdf ? null : _exportPayoutHistoryPdf,
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
                              borderSide: const BorderSide(color: AdminColors.indigo),
                            ),
                          ),
                          style: GoogleFonts.inter(fontSize: 13, color: text1),
                        ),
                        const SizedBox(height: 12),

                        // Interactive Payout Recipients Table
                        RepaintBoundary(
                          child: Container(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(14),
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
                                            DataCell(Text(_fmt(r['this_month_paid'] ?? 0), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AdminColors.amber))),
                                            DataCell(Text(_fmt(r['last_month_paid'] ?? 0), style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
                                            DataCell(Text(_fmt(r['total_paid_lifetime'] ?? 0), style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
                                            DataCell(Text(lastDateStr, style: GoogleFonts.inter(fontSize: 12, color: text2))),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 5. FULL TRANSACTION LIST
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
                            children: ['All', 'Subscription', 'Storage', 'Legacy', 'Payout'].map((filter) {
                              final isSelected = _txFilterType == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: AdminChip(
                                  label: filter,
                                  isSelected: isSelected,
                                  color: AdminColors.indigo,
                                  onTap: () => setState(() => _txFilterType = filter),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Transaction Ledger Table
                        RepaintBoundary(
                          child: Container(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(14),
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
                                            DataCell(AdminDirectionPill(isOut: isOut)),
                                            DataCell(Text(_fmt(tx['amount'] ?? 0), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold))),
                                            DataCell(Text('${tx['status'] ?? 'completed'}', style: GoogleFonts.inter(fontSize: 11, color: text2))),
                                            DataCell(
                                              AdminIconBtn(
                                                icon: Icons.receipt_long_rounded,
                                                size: 32,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AdminColors.indigo),
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
            Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AdminColors.amber)),
          ],
        ),
      ),
    );
  }
}

class _BreakdownGroupHeader extends StatelessWidget {
  final String title;
  final String subtotal;
  final Color color;

  const _BreakdownGroupHeader({
    required this.title,
    required this.subtotal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  title.contains('RECURRING') ? Icons.autorenew_rounded : Icons.bolt_rounded,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Text(
            subtotal,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

