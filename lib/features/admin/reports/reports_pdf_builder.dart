import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsPdfBuilder {
  static final _currencyFmt = NumberFormat('#,##0', 'en_US');
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static String _fmtRs(dynamic amount) {
    final num val = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
    return 'Rs ${_currencyFmt.format(val)}';
  }

  /// 1. Builds multi-page A4 Financial Report PDF
  static Future<Uint8List> buildPeriodReport({
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> summary,
    required Map<String, dynamic> breakdown,
    required List<Map<String, dynamic>> topEarners,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdf = pw.Document();

    final dateRangeStr = '${_dateFmt.format(startDate)} – ${_dateFmt.format(endDate)}';
    final generatedOnStr = _dateTimeFmt.format(DateTime.now());

    final primaryColor = PdfColor.fromHex('#0F172A');
    final accentColor = PdfColor.fromHex('#0D9488');
    final lightBgColor = PdfColor.fromHex('#F8FAFC');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final textDark = PdfColor.fromHex('#1E293B');
    final textMuted = PdfColor.fromHex('#64748B');

    final byType = breakdown['by_type'] as Map<String, dynamic>? ?? {};
    final byTier = breakdown['by_tier'] as Map<String, dynamic>? ?? {};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DARZI PRO',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      'Financial & Revenue Report',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: accentColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Period: $dateRangeStr',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark),
                    ),
                    pw.Text(
                      'Generated: $generatedOnStr',
                      style: pw.TextStyle(fontSize: 9, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Darzi Pro Admin System · Confidential',
                  style: pw.TextStyle(fontSize: 9, color: textMuted),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 9, color: textMuted, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // ── 1. SUMMARY METRICS ──────────────────────────────────────────
            pw.Text(
              '1. Executive Financial Summary',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 1),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBgColor),
                  children: [
                    _cellHeader('Total Revenue'),
                    _cellHeader('Invite Payouts (Paid)'),
                    _cellHeader('Net Revenue'),
                    _cellHeader('Transactions'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _cellData(_fmtRs(summary['total_revenue'] ?? 0), bold: true, color: accentColor),
                    _cellData(_fmtRs(summary['total_payouts'] ?? 0), bold: true, color: PdfColor.fromHex('#E11D48')),
                    _cellData(_fmtRs(summary['net_revenue'] ?? 0), bold: true, color: primaryColor),
                    _cellData('${summary['transaction_count'] ?? 0}', bold: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── 2. REVENUE BREAKDOWN ────────────────────────────────────────
            pw.Text(
              '2. Revenue Breakdown',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // By Type
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('By Transaction Type', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textDark)),
                      pw.SizedBox(height: 4),
                      pw.Table(
                        border: pw.TableBorder.all(color: borderColor, width: 1),
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: lightBgColor),
                            children: [
                              _cellHeader('Type'),
                              _cellHeader('Txs'),
                              _cellHeader('Total Amount'),
                            ],
                          ),
                          _buildTypeRow('Registrations', byType['registrations']),
                          _buildTypeRow('Upgrades', byType['upgrades']),
                          _buildTypeRow('Storage (Monthly)', byType['storage_monthly']),
                          _buildTypeRow('Storage (Annual)', byType['storage_annual']),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                // By Tier
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('By Plan Tier', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textDark)),
                      pw.SizedBox(height: 4),
                      pw.Table(
                        border: pw.TableBorder.all(color: borderColor, width: 1),
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: lightBgColor),
                            children: [
                              _cellHeader('Plan Tier'),
                              _cellHeader('Total Revenue'),
                            ],
                          ),
                          _buildTierRow('Mobile Only', byTier['mobile_only']),
                          _buildTierRow('Full Access', byTier['full_access']),
                          _buildTierRow('Full Access + 3yr', byTier['full_access_3yr']),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── 3. TOP EARNERS ─────────────────────────────────────────────
            pw.Text(
              '3. Top Inviter Earners',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 8),
            if (topEarners.isEmpty)
              pw.Text('No earning events recorded for this date range.', style: pw.TextStyle(fontSize: 10, color: textMuted))
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 1),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBgColor),
                    children: [
                      _cellHeader('#'),
                      _cellHeader('Shop Name'),
                      _cellHeader('Earning Events'),
                      _cellHeader('Total Earned'),
                    ],
                  ),
                  ...topEarners.take(10).toList().asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final row = entry.value;
                    return pw.TableRow(
                      children: [
                        _cellData('$idx'),
                        _cellData('${row['shop_name'] ?? 'Unknown'}', bold: true),
                        _cellData('${row['events_count'] ?? 0}'),
                        _cellData(_fmtRs(row['total_earned'] ?? 0), bold: true, color: accentColor),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 20),

            // ── 4. FULL TRANSACTION LIST ───────────────────────────────────
            pw.Text(
              '4. Full Transaction Ledger (${transactions.length} items)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 8),
            if (transactions.isEmpty)
              pw.Text('No transactions found in this date range.', style: pw.TextStyle(fontSize: 10, color: textMuted))
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 1),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBgColor),
                    children: [
                      _cellHeader('Date'),
                      _cellHeader('Type'),
                      _cellHeader('Shop Name'),
                      _cellHeader('Dir'),
                      _cellHeader('Amount'),
                      _cellHeader('Status'),
                    ],
                  ),
                  ...transactions.map((tx) {
                    final isOut = tx['direction'] == 'Out';
                    final dateStr = tx['date'] != null ? _dateFmt.format(DateTime.parse(tx['date'].toString())) : '-';
                    return pw.TableRow(
                      children: [
                        _cellData(dateStr),
                        _cellData('${tx['type'] ?? 'Payment'}'),
                        _cellData('${tx['shop_name'] ?? '-'}', bold: true),
                        _cellData(isOut ? 'OUT' : 'IN', bold: true, color: isOut ? PdfColor.fromHex('#E11D48') : accentColor),
                        _cellData(_fmtRs(tx['amount'] ?? 0), bold: true),
                        _cellData('${tx['status'] ?? 'completed'}'),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// 2. Builds single-page A5 Receipt / Invoice PDF
  static Future<Uint8List> buildTransactionInvoice(Map<String, dynamic> tx) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#0F172A');
    final accentColor = PdfColor.fromHex('#0D9488');
    final lightBgColor = PdfColor.fromHex('#F8FAFC');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final textMuted = PdfColor.fromHex('#64748B');

    final isOut = tx['direction'] == 'Out';
    final dateStr = tx['date'] != null
        ? _dateTimeFmt.format(DateTime.parse(tx['date'].toString()))
        : _dateTimeFmt.format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DARZI PRO', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('Official Payment Receipt', style: pw.TextStyle(fontSize: 12, color: accentColor, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: isOut ? PdfColor.fromHex('#FFE4E6') : PdfColor.fromHex('#CCFBF1'),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      isOut ? 'PAYOUT OUT' : 'PAYMENT IN',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: isOut ? PdfColor.fromHex('#E11D48') : accentColor),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: borderColor, thickness: 1),
              pw.SizedBox(height: 12),

              // Details Card
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  children: [
                    _receiptRow('Transaction ID:', '${tx['transaction_id'] ?? tx['id'] ?? 'N/A'}'),
                    pw.SizedBox(height: 8),
                    _receiptRow('Date & Time:', dateStr),
                    pw.SizedBox(height: 8),
                    _receiptRow('Shop Name:', '${tx['shop_name'] ?? 'N/A'}', bold: true),
                    pw.SizedBox(height: 8),
                    _receiptRow('Category / Type:', '${tx['type'] ?? 'Registration'}'),
                    pw.SizedBox(height: 8),
                    _receiptRow('Payment Method:', '${tx['payment_method'] ?? 'Online / Cash'}'),
                    pw.SizedBox(height: 8),
                    _receiptRow('Status:', '${tx['status'] ?? 'Confirmed'}', bold: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Amount Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount:', style: pw.TextStyle(fontSize: 14, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      _fmtRs(tx['amount'] ?? 0),
                      style: pw.TextStyle(fontSize: 20, color: accentColor, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Divider(color: borderColor, thickness: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Darzi Pro System Generated Receipt · Thank you for your business!',
                  style: pw.TextStyle(fontSize: 9, color: textMuted),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// 3. Builds Payout History & Recipients PDF Report
  static Future<Uint8List> buildPayoutHistoryReport(List<Map<String, dynamic>> recipients) async {
    final pdf = pw.Document();

    final generatedOnStr = _dateTimeFmt.format(DateTime.now());

    final primaryColor = PdfColor.fromHex('#0F172A');
    final accentColor = PdfColor.fromHex('#0D9488');
    final lightBgColor = PdfColor.fromHex('#F8FAFC');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final textMuted = PdfColor.fromHex('#64748B');

    int totalThisMonth = 0;
    int totalLastMonth = 0;
    int totalLifetime = 0;

    for (final r in recipients) {
      totalThisMonth += (r['this_month_paid'] as num?)?.toInt() ?? 0;
      totalLastMonth += (r['last_month_paid'] as num?)?.toInt() ?? 0;
      totalLifetime += (r['total_paid_lifetime'] as num?)?.toInt() ?? 0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DARZI PRO',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                    pw.Text(
                      'Payout History & Recipients Ledger',
                      style: pw.TextStyle(fontSize: 14, color: accentColor, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: $generatedOnStr',
                      style: pw.TextStyle(fontSize: 9, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Darzi Pro Admin System · Confidential Payout History', style: pw.TextStyle(fontSize: 9, color: textMuted)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: textMuted, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Text(
              'Payout Recipients Summary (${recipients.length} shops)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 1),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBgColor),
                  children: [
                    _cellHeader('This Month Paid'),
                    _cellHeader('Last Month Paid'),
                    _cellHeader('Total Lifetime Paid'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _cellData(_fmtRs(totalThisMonth), bold: true, color: accentColor),
                    _cellData(_fmtRs(totalLastMonth), bold: true),
                    _cellData(_fmtRs(totalLifetime), bold: true, color: primaryColor),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            if (recipients.isEmpty)
              pw.Text('No payout recipients recorded yet.', style: pw.TextStyle(fontSize: 10, color: textMuted))
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 1),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBgColor),
                    children: [
                      _cellHeader('#'),
                      _cellHeader('Shop Name'),
                      _cellHeader('This Month Paid'),
                      _cellHeader('Last Month Paid'),
                      _cellHeader('Total Paid Lifetime'),
                      _cellHeader('Last Payout Date'),
                    ],
                  ),
                  ...recipients.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final r = entry.value;
                    final lastDateStr = r['last_payout_date'] != null
                        ? _dateFmt.format(DateTime.parse(r['last_payout_date'].toString()))
                        : '-';
                    return pw.TableRow(
                      children: [
                        _cellData('$idx'),
                        _cellData('${r['shop_name'] ?? 'Unknown'}', bold: true),
                        _cellData(_fmtRs(r['this_month_paid'] ?? 0), bold: true, color: accentColor),
                        _cellData(_fmtRs(r['last_month_paid'] ?? 0)),
                        _cellData(_fmtRs(r['total_paid_lifetime'] ?? 0), bold: true),
                        _cellData(lastDateStr),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Prints or opens OS Share / Save dialog for generated PDF bytes
  static Future<void> printOrSharePdf(Uint8List bytes, String filename) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: filename,
    );
  }

  // ── Helper Table Cell Builders ────────────────────────────────────────────
  static pw.Widget _cellHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
      ),
    );
  }

  static pw.Widget _cellData(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColor.fromHex('#1E293B'),
        ),
      ),
    );
  }

  static pw.TableRow _buildTypeRow(String label, dynamic item) {
    final Map<String, dynamic> data = item is Map<String, dynamic> ? item : {'amount': 0, 'count': 0};
    return pw.TableRow(
      children: [
        _cellData(label),
        _cellData('${data['count'] ?? 0}'),
        _cellData(_fmtRs(data['amount'] ?? 0), bold: true),
      ],
    );
  }

  static pw.TableRow _buildTierRow(String label, dynamic item) {
    final Map<String, dynamic> data = item is Map<String, dynamic> ? item : {'amount': 0};
    return pw.TableRow(
      children: [
        _cellData(label),
        _cellData(_fmtRs(data['amount'] ?? 0), bold: true),
      ],
    );
  }

  static pw.Widget _receiptRow(String label, String value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColor.fromHex('#1E293B'),
          ),
        ),
      ],
    );
  }
}
