import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:arabic_reshaper/arabic_reshaper.dart';
import '../../shared/models/models.dart';
import '../../core/widgets/shared_widgets.dart';




/// Builds printable PDFs for Darzi Pro
/// â€“ A4 branded layout
/// â€“ 80mm thermal layout
class DarziPdfBuilder {
  DarziPdfBuilder._();

  /// Builds a PDF Document directly from PNG image bytes captured from a Flutter Widget.
  /// Guarantees 100% pixel-perfect Urdu script, RTL shaping, diagrams, and formatting.
  static Future<List<int>> buildPdfFromImageBytes(
    Uint8List pngBytes, {
    PdfPageFormat pageFormat = PdfPageFormat.a5,
  }) async {
    final pdf = pw.Document();
    final pdfImage = pw.MemoryImage(pngBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Center(
            child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
          ),
        ),
      ),
    );
    return await pdf.save();
  }

  static pw.Font? _cachedUrduFont;

  static Future<pw.Font> _loadUrduFont() async {
    if (_cachedUrduFont != null) return _cachedUrduFont!;

    try {
      final fontData = await rootBundle.load('fonts/NotoNaskhArabic-Regular.ttf');
      if (fontData.lengthInBytes > 1000) {
        _cachedUrduFont = pw.Font.ttf(fontData);
        return _cachedUrduFont!;
      }
    } catch (e) {
      debugPrint('DarziPdfBuilder: Failed to load local font â€” $e');
    }

    try {
      final response = await http.get(Uri.parse(
          'https://fonts.gstatic.com/s/notonaskharabic/v32/Ung24zO0MDRlhv6RZrACZ1W01I2206LDEsVnE8Bpt7nZ6w.ttf'));
      if (response.statusCode == 200 && response.bodyBytes.lengthInBytes > 5000) {
        if (response.bodyBytes[0] != 0x3C) { // Ensure not HTML
          _cachedUrduFont = pw.Font.ttf(ByteData.sublistView(response.bodyBytes));
          return _cachedUrduFont!;
        }
      }
    } on Object catch (_) {}

    _cachedUrduFont = pw.Font.helvetica();
    return _cachedUrduFont!;
  }

  static String _pdfMoney(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return 'Rs. ${formatter.format(amount)}';
  }

  // Brand colors as PdfColor
  static const _gold = PdfColor.fromInt(0xFFF5A623);
  static const _dark = PdfColor.fromInt(0xFF0D1525);
  static const _dark2 = PdfColor.fromInt(0xFF1A2540);
  static const _teal = PdfColor.fromInt(0xFF10CBA0);
  static const _white = PdfColor.fromInt(0xFFFFFFFF);
  static const _grey = PdfColor.fromInt(0xFF8B9BB8);
  static const _lightBg = PdfColor.fromInt(0xFFF5F8FF);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _text = PdfColor.fromInt(0xFF0F1623);
  static const _textSub = PdfColor.fromInt(0xFF5A6478);

  // â”€â”€ A4 LAYOUT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<List<int>> buildA4(
      OrderModel order, CustomerModel? customer, {bool isUrdu = false}) async {
    final arabicFont = await _loadUrduFont();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: arabicFont,
        bold: arabicFont,
        italic: arabicFont,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context ctx) => pw.Directionality(
          textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildA4Header(order, isUrdu),
              _goldStripe(),
              pw.Padding(
                padding: const pw.EdgeInsets.all(28),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _buildCustomerBlock(order, customer, isUrdu),
                    pw.SizedBox(height: 18),
                    _buildDatesRow(order, isUrdu),
                    pw.SizedBox(height: 18),
                    _buildItemsTable(order, isUrdu),
                    pw.SizedBox(height: 18),
                    _buildMoneyBlock(order, isUrdu),
                    if (order.notes != null) ...[
                      pw.SizedBox(height: 18),
                      _buildNotesBox(order.notes!, isUrdu),
                    ],
                    pw.SizedBox(height: 28),
                    _buildA4Footer(order, isUrdu),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  // â”€â”€ THERMAL 80MM LAYOUT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<List<int>> buildThermal(
      OrderModel order, CustomerModel? customer, {bool isUrdu = false}) async {
    final arabicFont = await _loadUrduFont();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: arabicFont,
        bold: arabicFont,
        italic: arabicFont,
      ),
    );

    // 80mm thermal width
    final format = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
        marginAll: 4 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context ctx) => pw.Directionality(
          textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Shop header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      isUrdu ? 'Ø³ÛŒÙ Ø§Ù„Ø±Ø­Ù…Ù† Ù¹ÛŒÙ„Ø±Ø²' : 'SAIFURRAHMAN TAILORS',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                    pw.Text(
                      isUrdu ? 'ØµØ¯Ø±ØŒ Ù¾Ø´Ø§ÙˆØ± Â· 0300-1234567' : 'Saddar, Peshawar Â· 0300-1234567',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
              _thermalDivider(),

              // Token + Order
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(order.tokenNumber,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 22)),
                    pw.Text(
                      isUrdu ? 'Ø¢Ø±ÚˆØ± Ù†Ù…Ø¨Ø± #${order.orderNumber}' : 'Order #${order.orderNumber}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              _thermalDivider(),

              // Customer
              pw.Text(
                isUrdu ? 'Ú¯Ø§ÛÚ©' : 'CUSTOMER',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 8),
              ),
              pw.Text(order.customerName,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 13)),
              if (customer != null)
                pw.Text('ðŸ“± ${customer.phone}',
                    style: const pw.TextStyle(fontSize: 9)),
              _thermalDivider(),

              // Dates
              _thermalRow(
                isUrdu ? 'Ø¢Ø±ÚˆØ± Ú©ÛŒ ØªØ§Ø±ÛŒØ®:' : 'Order Date:',
                formatDateShort(order.orderDate),
                bold: false,
              ),
              if (order.deliveryDate != null)
                _thermalRow(
                  isUrdu ? 'ÚˆÛŒÙ„ÛŒÙˆØ±ÛŒ Ú©ÛŒ ØªØ§Ø±ÛŒØ®:' : 'Delivery Date:',
                  formatDateShort(order.deliveryDate!),
                  bold: true,
                  highlight: order.isUrgent,
                ),
              _thermalDivider(),

              // Items
              pw.Text(
                isUrdu ? 'Ø¢Ø¦Ù¹Ù…Ø²' : 'ITEMS',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 8),
              ),
              pw.SizedBox(height: 3),
              ...order.items.map((item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          '${item.dressType} x${item.quantity}  ${item.clothDetails}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(_pdfMoney(item.total),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ],
                  )),
              _thermalDivider(),

              // Payment block
              _thermalRow(
                isUrdu ? 'Ú©Ù„ Ø±Ù‚Ù…:' : 'Total:',
                _pdfMoney(order.totalAmount),
              ),
              _thermalRow(
                isUrdu ? 'Ø§ÛŒÚˆÙˆØ§Ù†Ø³ Ø§Ø¯Ø§ Ú©ÛŒØ§:' : 'Advance Paid:',
                _pdfMoney(order.paidAmount),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      order.isFullyPaid 
                          ? (isUrdu ? 'Ù…Ú©Ù…Ù„ Ø§Ø¯Ø§Ø¦ÛŒÚ¯ÛŒ âœ“' : 'FULLY PAID âœ“')
                          : (isUrdu ? 'Ø¨Ø§Ù‚ÛŒ Ø±Ù‚Ù…:' : 'BAQI:'),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.Text(
                      order.isFullyPaid
                          ? (isUrdu ? 'Ø¨Û’ Ø¨Ø§Ù‚' : 'CLEAR')
                          : _pdfMoney(order.remainingAmount),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),

              if (order.notes != null) ...[
                _thermalDivider(),
                pw.Text(
                  isUrdu ? 'Ù†ÙˆÙ¹Ø³:' : 'NOTES:',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 8),
                ),
                pw.Text(order.notes!,
                    style: const pw.TextStyle(fontSize: 9)),
              ],

              _thermalDivider(),
              pw.Center(
                child: pw.Text(
                  isUrdu ? '-- Ø¯Ø±Ø²ÛŒ Ù¾Ø±Ùˆ Ú©Û’ Ø°Ø±ÛŒØ¹Û’ ØªÛŒØ§Ø± Ú©Ø±Ø¯Û --' : '-- Generated by Darzi Pro --',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  // â”€â”€ A4 WIDGET BUILDERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static pw.Widget _buildA4Header(OrderModel order, bool isUrdu) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [_dark, _dark2],
        ),
      ),
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Logo + shop name
          pw.Row(
            children: [
              pw.Container(
                width: 44,
                height: 44,
                decoration: pw.BoxDecoration(
                  color: _gold,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Center(
                  child: pw.Text('DP',
                      style: pw.TextStyle(
                          color: _dark,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 18)),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isUrdu ? 'Ø³ÛŒÙ Ø§Ù„Ø±Ø­Ù…Ù† Ù¹ÛŒÙ„Ø±Ø²' : 'SaifurRahman Tailors',
                    style: pw.TextStyle(
                        color: _white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16),
                  ),
                  pw.Text(
                    isUrdu ? 'ØµØ¯Ø±ØŒ Ù¾Ø´Ø§ÙˆØ± Â· 0300-1234567' : 'Saddar, Peshawar Â· 0300-1234567',
                    style: pw.TextStyle(color: _gold, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          // Token badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _gold),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  isUrdu ? 'Ù¹ÙˆÚ©Ù†' : 'TOKEN',
                  style: pw.TextStyle(
                      color: _gold, fontSize: 8, letterSpacing: 1.0),
                ),
                pw.Text(order.tokenNumber,
                    style: pw.TextStyle(
                        color: _gold,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _goldStripe() {
    return pw.Container(
      height: 8,
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_gold, PdfColor.fromInt(0xFFFFC850), _gold],
        ),
      ),
    );
  }

  static pw.Widget _buildCustomerBlock(
      OrderModel order, CustomerModel? customer, bool isUrdu) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              isUrdu ? 'Ú¯Ø§ÛÚ©' : 'CUSTOMER',
              style: pw.TextStyle(
                  color: _grey,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            pw.Text(order.customerName,
                style: pw.TextStyle(
                    color: _text,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18)),
            if (customer != null)
              pw.Text('Ph: ${customer.phone}',
                  style: pw.TextStyle(color: _textSub, fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              isUrdu ? 'Ø¢Ø±ÚˆØ± Ù†Ù…Ø¨Ø±' : 'ORDER NO.',
              style: pw.TextStyle(
                  color: _grey,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            pw.Text('#${order.orderNumber}',
                style: pw.TextStyle(
                    color: _text,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDatesRow(OrderModel order, bool isUrdu) {
    return pw.Row(
      children: [
        _dateBox(
          isUrdu ? 'Ø¢Ø±ÚˆØ± Ú©ÛŒ ØªØ§Ø±ÛŒØ®' : 'ORDER DATE',
          formatDateShort(order.orderDate),
          urgent: false,
        ),
        pw.SizedBox(width: 12),
        _dateBox(
          isUrdu ? 'ÚˆÛŒÙ„ÛŒÙˆØ±ÛŒ Ú©ÛŒ ØªØ§Ø±ÛŒØ®' : 'DELIVERY DATE',
          order.deliveryDate != null
              ? formatDateShort(order.deliveryDate!)
              : (isUrdu ? 'Ø·Û’ Ù†ÛÛŒÚº ÛÛ’' : 'Not Set'),
          urgent: order.isUrgent,
        ),
      ],
    );
  }

  static pw.Widget _dateBox(String label, String value,
      {required bool urgent}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _lightBg,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    color: _grey, fontSize: 8, letterSpacing: 0.8)),
            pw.SizedBox(height: 3),
            pw.Text(value,
                style: pw.TextStyle(
                    color: urgent
                        ? const PdfColor.fromInt(0xFFDC2626)
                        : _text,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildItemsTable(OrderModel order, bool isUrdu) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: _lightBg,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      isUrdu ? 'Ø¢Ø¦Ù¹Ù… / Ú©Ù¾Ú‘Ø§' : 'ITEM / CLOTH',
                      style: pw.TextStyle(
                          color: _grey,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8),
                    )),
                pw.Text(
                  isUrdu ? 'ØªØ¹Ø¯Ø§Ø¯' : 'QTY',
                  style: pw.TextStyle(
                      color: _grey, fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 40),
                pw.Text(
                  isUrdu ? 'Ù‚ÛŒÙ…Øª' : 'PRICE',
                  style: pw.TextStyle(
                      color: _grey, fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          // Items
          ...order.items.map(
            (item) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(color: _border)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.dressType,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11)),
                        if (item.clothDetails.isNotEmpty)
                          pw.Text(item.clothDetails,
                              style: pw.TextStyle(
                                  color: _textSub, fontSize: 9)),
                      ],
                    ),
                  ),
                  pw.Text('Ã— ${item.quantity}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11)),
                  pw.SizedBox(width: 28),
                  pw.Text(_pdfMoney(item.total),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMoneyBlock(OrderModel order, bool isUrdu) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [_dark, _dark2],
        ),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Column(
        children: [
          _pdfMoneyRow(
            isUrdu ? 'Ú©Ù„ Ø±Ù‚Ù…' : 'Total Amount',
            _pdfMoney(order.totalAmount),
          ),
          if (order.discount > 0)
            _pdfMoneyRow(
              isUrdu ? 'ÚˆØ³Ú©Ø§Ø¤Ù†Ù¹' : 'Discount',
              '- ${_pdfMoney(order.discount)}',
              valueColor: _teal,
            ),
          _pdfMoneyRow(
            isUrdu ? 'Ø§ÛŒÚˆÙˆØ§Ù†Ø³ Ø§Ø¯Ø§ Ú©ÛŒØ§' : 'Advance Paid',
            _pdfMoney(order.paidAmount),
          ),
          pw.Container(
              height: 1,
              margin: const pw.EdgeInsets.symmetric(vertical: 8),
              color: const PdfColor(1, 1, 1, 0.1)),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                order.isFullyPaid 
                    ? (isUrdu ? 'Ù…Ú©Ù…Ù„ Ø§Ø¯Ø§ Ø´Ø¯Û' : 'Fully Paid') 
                    : (isUrdu ? 'Ø¨Ø§Ù‚ÛŒ Ø±Ù‚Ù…' : 'Remaining'),
                style: pw.TextStyle(
                    color: _gold, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                order.isFullyPaid
                    ? (isUrdu ? 'Ø¨Û’ Ø¨Ø§Ù‚' : 'CLEAR')
                    : _pdfMoney(order.remainingAmount),
                style: pw.TextStyle(
                    color: order.isFullyPaid ? _teal : _gold,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: order.isFullyPaid ? 13 : 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfMoneyRow(String label, String value,
      {PdfColor valueColor = _white}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  color: PdfColor(1, 1, 1, 0.5), fontSize: 11)),
          pw.Text(value,
              style: pw.TextStyle(
                  color: valueColor,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildNotesBox(String notes, bool isUrdu) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFFBEB),
        border: pw.Border.all(color: _gold),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            isUrdu ? 'ðŸ“Œ Ù†ÙˆÙ¹Ø³' : 'ðŸ“Œ NOTES',
            style: pw.TextStyle(
                color: const PdfColor.fromInt(0xFF92400E),
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
                letterSpacing: 0.8),
          ),
          pw.SizedBox(height: 4),
          pw.Text(notes,
              style: pw.TextStyle(
                  color: const PdfColor.fromInt(0xFF78350F),
                  fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildA4Footer(OrderModel order, bool isUrdu) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              isUrdu ? 'Ø¯Ø±Ø²ÛŒ Ù¾Ø±Ùˆ Ú©Û’ Ø°Ø±ÛŒØ¹Û’ ØªÛŒØ§Ø± Ú©Ø±Ø¯Û' : 'Generated by Darzi Pro',
              style: pw.TextStyle(color: _grey, fontSize: 8),
            ),
            pw.Text(
              'SaifurRahman Tailors Â· ${formatDateShort(DateTime.now())}',
              style: pw.TextStyle(color: _grey, fontSize: 8),
            ),
          ],
        ),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: 'darzi-order:${order.id}',
          width: 50,
          height: 50,
          color: _dark,
        ),
      ],
    );
  }

  // â”€â”€ THERMAL HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static pw.Widget _thermalDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Text(
        '- ' * 30,
        style: const pw.TextStyle(fontSize: 7),
      ),
    );
  }

  static pw.Widget _thermalRow(String label, String value,
      {bool bold = true, bool highlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: highlight ? 11 : 9,
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ TRADITIONAL NAAP CARD A5 LAYOUT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static String _ur(String text) {
    if (text.isEmpty) return '';
    try {
      return ArabicReshaper.instance.reshape(text);
    } catch (_) {
      return text;
    }
  }

  static Future<List<int>> buildTraditionalNaapCard(
      OrderModel order, CustomerModel? customer, MeasurementModel? measurement) async {
    final urduFont = await _loadUrduFont();

    final Map<String, String> measurements = {};
    if (measurement != null) {
      for (final section in measurement.sections) {
        for (final field in section.fields) {
          measurements[field.key] = field.value;
        }
      }
    }

    final pdf = pw.Document();
    final format = PdfPageFormat.a5;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context ctx) {
          return pw.Container(
            height: format.availableHeight,
            width: format.availableWidth,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFB8A080), width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Header
                _buildNewHeader(order, customer, urduFont),
                // Gold divider
                pw.Container(
                  height: 2,
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [PdfColor.fromInt(0xFF8B6914), PdfColor.fromInt(0xFFF5C842), PdfColor.fromInt(0xFF8B6914)],
                    ),
                  ),
                ),
                // 2. Info Bar
                _buildNewInfoBar(order, urduFont),

                // 3. Customer Row
                _buildNewCustomerRow(order, customer, urduFont),

                // 4. Main Body â€” RTL visual order: Silai | Pattern Pieces | Measurements
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // LEFT: Silai options (22%)
                      pw.Expanded(
                        flex: 22,
                        child: _buildNaapSilaiColumnPdf(measurement, urduFont),
                      ),
                      _pdfVertDiv(),

                      // MIDDLE: Pattern Pieces (56%)
                      pw.Expanded(
                        flex: 56,
                        child: _buildPatternPiecesPdf(measurements, urduFont),
                      ),
                      _pdfVertDiv(),

                      // RIGHT: Measurements (22%)
                      pw.Expanded(
                        flex: 22,
                        child: _buildNaapMeasurementsColumnPdf(measurements, urduFont),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // 5. Footer
                _buildNewFooter(urduFont),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // â”€â”€ Shared helpers for the PDF Naap Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static pw.Widget _pdfVertDiv() =>
      pw.Container(width: 1.2, color: PdfColor.fromInt(0xFFB8A080));

  static pw.Widget _pdfColHdr(String text, pw.Font urduFont, {bool small = false}) {
    return pw.Container(
      width: double.infinity,
      color: PdfColor.fromInt(0xFF12213A),
      padding: pw.EdgeInsets.symmetric(vertical: small ? 3 : 5),
      alignment: pw.Alignment.center,
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(
          _ur(text),
          style: pw.TextStyle(
            font: urduFont,
            color: PdfColor.fromInt(0xFFF5C842),
            fontSize: small ? 6.5 : 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildNewHeader(OrderModel order, CustomerModel? customer, pw.Font urduFont) {
    return pw.Container(
      height: 56,
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [PdfColors.white, PdfColor.fromInt(0xFFFBF6EC)],
        ),
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFB8A080), width: 1.2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Col 1 â€” Token No.
          pw.Container(
            width: 100,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(color: PdfColor.fromInt(0xFFB8A080), width: 1.2)),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Token No.',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFFB8860B),
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  order.tokenNumber,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFFB8860B),
                  ),
                ),
              ],
            ),
          ),

          // Col 2 â€” Shop name + address centred
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'SaifurRahman Tailors',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF12213A),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Saddar, Peshawar  |  0300-1234567',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Col 3 â€” Gold scissor mark
          pw.Container(
            width: 100,
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: PdfColor.fromInt(0xFFB8A080), width: 1.2)),
            ),
            child: pw.Center(
              child: pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                    colors: [PdfColor.fromInt(0xFFF5C842), PdfColor.fromInt(0xFFB8860B)],
                  ),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'NAAP',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNewInfoBar(OrderModel order, pw.Font urduFont) {
    final totalQty = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final shortId = order.customerId.isNotEmpty == true
        ? (order.customerId.length >= 8 ? order.customerId.substring(0, 8).toUpperCase() : order.customerId.toUpperCase())
        : '';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          _buildInfoBox('', 'ØªØ§Ø±ÛŒØ® Ø¯Ø±Ø¬ Ø¨Ú©Ù†Ú¯', formatDateShort(order.orderDate), urduFont),
          _buildInfoDivider(),
          _buildInfoBox(
            '',
            'ØªØ§Ø±ÛŒØ® ÚˆÛŒÙ„ÛŒÙˆØ±ÛŒ',
            order.deliveryDate != null ? formatDateShort(order.deliveryDate!) : '-',
            urduFont,
            isRed: true,
          ),
          _buildInfoDivider(),
          _buildInfoBox('', 'ØªØ¹Ø¯Ø§Ø¯', '$totalQty', urduFont),
          _buildInfoDivider(),
          _buildInfoBox('', 'Customer No.', '#$shortId', urduFont, isEngLabel: true),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoBox(
    String icon,
    String label,
    String value,
    pw.Font urduFont, {
    bool isRed = false,
    bool isEngLabel = false,
  }) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (icon.isNotEmpty) ...[
                  pw.Text(icon, style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(width: 3),
                ],
                isEngLabel
                    ? pw.Text(
                        label,
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      )
                    : pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Text(
                          _ur(label),
                          style: pw.TextStyle(
                            font: urduFont,
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: isRed ? PdfColor.fromInt(0xFFDC2626) : PdfColor.fromInt(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildInfoDivider() {
    return pw.Container(
      width: 0.8,
      height: 24,
      color: PdfColor.fromInt(0xFFE2E8F0),
    );
  }

  static pw.Widget _buildNewCustomerRow(OrderModel order, CustomerModel? customer, pw.Font urduFont) {
    final phone = customer?.phone ?? '';

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Left: Phone
          if (phone.isNotEmpty)
            pw.Row(
              children: [
                pw.Text(
                  'Ph: $phone',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
              ],
            )
          else
            pw.SizedBox(),

          // Right: Customer Name
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(
              _ur(order.customerName),
              style: pw.TextStyle(
                font: urduFont,
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // PATTERN PIECES â€” PDF version
  // Uses pw.CustomPaint with Y-flipped SVG coordinates (PDF Y-axis is up).
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  static pw.Widget _buildPatternPiecesPdf(Map<String, String> m, pw.Font urduFont) {
    String mv(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return '-';
    }

    final collarV  = mv(['collar']);
    final garebanV = mv(['gareban']);
    final kafV     = mv(['kaf', 'cuff']);
    final bazoV    = mv(['bazo', 'sleeve', 'aasteen']);
    final jebV     = mv(['jeb', 'pocket']);
    final lambaiV  = mv(['lambai', 'length']);
    final chaatiV  = mv(['chaati', 'chest', 'bust']);
    final shalwarV = mv(['shalwar', 'shalwar_length', 'trouser']);
    final pancheV  = mv(['panche', 'pancha', 'bottom']);
    final kamarV   = mv(['kamar', 'waist']);

    return pw.Container(
      color: PdfColor.fromInt(0xFFFAF5EE),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _pdfColHdr('Ù¾ÛŒÙ¹Ø±Ù† Ù¾ÛŒØ³Ø²', urduFont),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                children: [
                  // Row 1
                  pw.Expanded(
                    child: pw.Row(children: [
                      pw.Expanded(child: _pdfPieceCard('Ú©Ø§Ù„Ø±',   collarV,  urduFont, _pdfCollarPainter)),
                      pw.SizedBox(width: 4),
                      pw.Expanded(child: _pdfPieceCard('Ú¯Ø±ÛŒØ¨Ø§Ù†', garebanV, urduFont, _pdfGarebanPainter)),
                      pw.SizedBox(width: 4),
                      pw.Expanded(child: _pdfPieceCard('Ú©Ù',     kafV,     urduFont, _pdfKafPainter)),
                    ]),
                  ),
                  pw.SizedBox(height: 4),
                  // Row 2
                  pw.Expanded(
                    child: pw.Row(children: [
                      pw.Expanded(child: _pdfPieceCard('Ø¨Ø§Ø²Ùˆ',  bazoV,  urduFont, _pdfBazoPainter)),
                      pw.SizedBox(width: 4),
                      pw.Expanded(child: _pdfPieceCard('Ø¬ÛŒØ¨',   jebV,   urduFont, _pdfJebPainter)),
                      pw.SizedBox(width: 4),
                      pw.Expanded(child: _pdfPieceCard('Ø¢Ú¯Ø§',   '$lambaiV/$chaatiV', urduFont, _pdfAagaPainter)),
                    ]),
                  ),
                  pw.SizedBox(height: 4),
                  // Row 3: Shalwar (2-wide) + Kamar
                  pw.Expanded(
                    child: pw.Row(children: [
                      pw.Expanded(
                        flex: 2,
                        child: _pdfPieceCard('Ø³Ù†Ú¯Ù„ Ù¾ÛŒØ³ Ø´Ù„ÙˆØ§Ø±', '$shalwarV / $pancheV"', urduFont, _pdfShalwarPainter),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Expanded(child: _pdfPieceCard('Ú©Ù…Ø±', kamarV, urduFont, _pdfKamarPainter)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfPieceCard(
      String label, String value, pw.Font urduFont,
      void Function(PdfGraphics, PdfPoint) painter) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE8DDD0), width: 0.7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.Center(
                  child: pw.CustomPaint(
                    size: const PdfPoint(44, 24),
                    painter: painter,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                  color: PdfColors.white,
                  child: pw.Text(
                    value,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF12213A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(
              _ur(label),
              style: pw.TextStyle(
                font: urduFont,
                fontSize: 6.5,
                color: PdfColor.fromInt(0xFF8B7355),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PDF painters â€” Y-flipped (PDF Y-axis is up; SVG/HTML Y-axis is down)
  // For a canvas of PdfPoint(44, 24), coordinates use: pdfY = canvasH - svgY

  /// 1. Collar â€” SVG: M4 20 Q29 2 54 20, viewBox 58Ã—28
  static void _pdfCollarPainter(PdfGraphics canvas, PdfPoint size) {
    canvas.setStrokeColor(PdfColor.fromInt(0xFF374151));
    canvas.setLineWidth(1.2);
    // Normalize from viewBox 58Ã—28 to canvas 44Ã—24, Y-flipped
    final sx = size.x / 58;
    final sy = size.y / 28;
    // quadratic bezier â†’ cubic: cp1=start+2/3*(cp-start), cp2=end+2/3*(cp-end)
    // start=(4,20)â†’pdf(4*sx,(28-20)*sy), cp=(29,2)â†’pdf(29*sx,(28-2)*sy), end=(54,20)
    final x0 = 4 * sx;    final y0 = (28 - 20) * sy;
    final xc = 29 * sx;   final yc = (28 - 2) * sy;
    final x1 = 54 * sx;   final y1 = (28 - 20) * sy;
    canvas.moveTo(x0, y0);
    canvas.curveTo(
      x0 + 2 / 3 * (xc - x0), y0 + 2 / 3 * (yc - y0),
      x1 + 2 / 3 * (xc - x1), y1 + 2 / 3 * (yc - y1),
      x1, y1,
    );
    canvas.strokePath();
  }

  /// 2. Gareban â€” SVG: M4 28 L4 13 Q4 2 19 2 Q34 2 34 13 L34 28 Z, viewBox 38Ã—32
  static void _pdfGarebanPainter(PdfGraphics canvas, PdfPoint size) {
    canvas.setStrokeColor(PdfColor.fromInt(0xFF374151));
    canvas.setLineWidth(1.2);
    final sx = size.x / 38;
    final sy = size.y / 32;
    canvas.moveTo(4 * sx, (32 - 28) * sy);
    canvas.lineTo(4 * sx, (32 - 13) * sy);
    // Q4 2 19 2 â†’ cubic from (4,13) cp=(4,2) end=(19,2), Y-flipped
    final ax = 4 * sx;   final ay = (32 - 13) * sy;
    final ac = 4 * sx;   final acy = (32 - 2) * sy;
    final ae = 19 * sx;  final aey = (32 - 2) * sy;
    canvas.curveTo(ax + 2/3*(ac-ax), ay + 2/3*(acy-ay), ae + 2/3*(ac-ae), aey + 2/3*(acy-aey), ae, aey);
    // Q34 2 34 13 â†’ cubic from (19,2) cp=(34,2) end=(34,13)
    final bx = 19 * sx;  final by = (32 - 2) * sy;
    final bc = 34 * sx;  final bcy = (32 - 2) * sy;
    final be = 34 * sx;  final bey = (32 - 13) * sy;
    canvas.curveTo(bx + 2/3*(bc-bx), by + 2/3*(bcy-by), be + 2/3*(bc-be), bey + 2/3*(bcy-bey), be, bey);
    canvas.lineTo(34 * sx, (32 - 28) * sy);
    canvas.closePath();
    canvas.strokePath();
  }

  /// 3. Kaf â€” SVG: rect x3 y3 w38 h16, viewBox 44Ã—22
  static void _pdfKafPainter(PdfGraphics canvas, PdfPoint size) {
    canvas.setStrokeColor(PdfColor.fromInt(0xFF374151));
    canvas.setLineWidth(1.2);
    final sx = size.x / 44;
    final sy = size.y / 22;
    // rect bottom-left in Y-up: y_pdf = canvasH - (svgY + svgH)
    canvas.drawRect(3 * sx, (22 - 3 - 16) * sy, 38 * sx, 16 * sy);
    canvas.strokePath();
  }

  /// 4. Bazo â€” SVG: M4 20 L13 4 L37 4 L46 20 Z, viewBox 50Ã—24
  static void _pdfBazoPainter(PdfGraphics canvas, PdfPoint size) {
    canvas.setStrokeColor(PdfColor.fromInt(0xFF374151));
    canvas.setLineWidth(1.2);
    final sx = size.x / 50;
    final sy = size.y / 24;
    canvas.moveTo(4 * sx,  (24 - 20) * sy);
    canvas.lineTo(13 * sx, (24 - 4)  * sy);
    canvas.lineTo(37 * sx, (24 - 4)  * sy);
    canvas.lineTo(46 * sx, (24 - 20) * sy);
    canvas.closePath();
    canvas.strokePath();
  }

  /// 5. Jeb â€” SVG: rect x4 y4 w26 h20, viewBox 34Ã—28
  static void _pdfJebPainter(PdfGraphics canvas, PdfPoint size) {
    canvas.setStrokeColor(PdfColor.fromInt(0xFF374151));
    canvas.setLineWidth(1.2);
    final sx = size.x / 34;
    final sy = size.y / 28;
    canvas.drawRect(4 * sx, (28 - 4 - 20) * sy, 26 * sx, 20 * sy);
    canvas.strokePath();
  }

  /// 6. Aaga â€” SVG: rect x5 y3 w28 h26 + dash at y=15, viewBox 38Ã—32
  static void _pdfAagaPainter(PdfGraphics canvas, PdfPoint size) {
    canvas.setStrokeColor(PdfColor.fromInt(0xFF374151));
    canvas.setLineWidth(1.2);
    final sx = size.x / 38;
    final sy = size.y / 32;
    canvas.drawRect(5 * sx, (32 - 3 - 26) * sy, 28 * sx, 26 * sy);
    canvas.strokePath();
    // Dashed centerline in gold
    canvas.setStrokeColor(PdfColor.fromInt(0xFFB8860B));
    canvas.setLineWidth(0.8);
    canvas.drawLine(5 * sx, (32 - 15) * sy, 33 * sx, (32 - 15) * sy);
    canvas.strokePath();
  }

  /// 7. Shalwar â€” SVG: M6 4 L36 4 L36 16 Q36 20 41 20 L54 20 L76 32 L58 32 L44 24 L18 24 L6 32 Z, viewBox 82Ã—36
  static void _pdfShalwarPainter(PdfGraphics canvas, PdfPoint size) {
    canvas.setStrokeColor(PdfColor.fromInt(0xFF374151));
    canvas.setLineWidth(1.2);
    final sx = size.x / 82;
    final sy = size.y / 36;
    canvas.moveTo(6 * sx,  (36 - 4)  * sy);
    canvas.lineTo(36 * sx, (36 - 4)  * sy);
    canvas.lineTo(36 * sx, (36 - 16) * sy);
    // Q36 20 41 20 â†’ cubic, start=(36,16) cp=(36,20) end=(41,20)
    final qx0 = 36 * sx; final qy0 = (36 - 16) * sy;
    final qxc = 36 * sx; final qyc = (36 - 20) * sy;
    final qx1 = 41 * sx; final qy1 = (36 - 20) * sy;
    canvas.curveTo(qx0+2/3*(qxc-qx0), qy0+2/3*(qyc-qy0), qx1+2/3*(qxc-qx1), qy1+2/3*(qyc-qy1), qx1, qy1);
    canvas.lineTo(54 * sx, (36 - 20) * sy);
    canvas.lineTo(76 * sx, (36 - 32) * sy);
    canvas.lineTo(58 * sx, (36 - 32) * sy);
    canvas.lineTo(44 * sx, (36 - 24) * sy);
    canvas.lineTo(18 * sx, (36 - 24) * sy);
    canvas.lineTo(6 * sx,  (36 - 32) * sy);
    canvas.closePath();
    canvas.strokePath();
  }

  /// 8. Kamar â€” SVG: circle cx16 cy16 r13, viewBox 32Ã—32
  static void _pdfKamarPainter(PdfGraphics canvas, PdfPoint size) {
    canvas.setStrokeColor(PdfColor.fromInt(0xFF374151));
    canvas.setLineWidth(1.5);
    final cx = size.x / 2;
    final cy = size.y / 2;
    final rx = (13 / 16) * cx;
    final ry = (13 / 16) * cy;
    canvas.drawEllipse(cx, cy, rx, ry);
    canvas.strokePath();
  }

  // â”€â”€ Naap PDF: Measurements column (no numbered badges) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static pw.Widget _buildNaapMeasurementsColumnPdf(
      Map<String, String> m, pw.Font urduFont) {
    String mv(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return '-';
    }

    final rows = [
      ('Ù„Ù…Ø¨Ø§Ø¦ÛŒ',  'Length',     mv(['lambai', 'length'])),
      ('ØªÛŒØ±Ø§',    'Shoulder',   mv(['teerwa', 'shoulder', 'teera'])),
      ('Ø¨Ø§Ø²Ùˆ',    'Sleeve',     mv(['bazo', 'sleeve', 'aasteen'])),
      ('Ú†Ú¾Ø§ØªÛŒ',  'Chest',      mv(['chaati', 'chest', 'bust'])),
      ('Ø¨ØºÙ„',    'Arm Hole',   mv(['baghal', 'arm_hole', 'armhole'])),
      ('Ú©Ù…Ø±',    'Waist',      mv(['kamar', 'waist'])),
      ('Ø¯Ø§Ù…Ù†',   'Hem',        mv(['daman', 'hem', 'hem_circle'])),
      ('Ú©Ø§Ù„Ø±',   'Collar',     mv(['collar'])),
      ('Ø´Ù„ÙˆØ§Ø±',  'Trouser L.', mv(['shalwar', 'shalwar_length', 'trouser'])),
      ('Ù¾Ø§Ù†Ú†Û’',  'Bottom',     mv(['panche', 'pancha', 'bottom'])),
      ('Ú©Ù',     'Cuff',       mv(['kaf', 'cuff'])),
      ('Ø¬ÛŒØ¨',    'Pocket',     mv(['jeb', 'pocket'])),
      ('Ú¯ÙˆÙ„',    'Gol/Hip',    mv(['gol', 'hip'])),
      ('Ø¢Ø³Ù†',    'Asan',       mv(['asan'])),
      ('Ú¯Ø±ÛŒØ¨Ø§Ù†', 'Gareban',    mv(['gareban'])),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _pdfColHdr('Ù†Ø§Ù¾ / Ø³Ø§Ø¦Ø²', urduFont),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: rows.asMap().entries.map((e) {
              final idx = e.key;
              final row = e.value;
              return pw.Expanded(
                child: pw.Container(
                  color: idx % 2 == 0
                      ? PdfColors.white
                      : PdfColor.fromInt(0xFFF9F4EC),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        row.$3,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFFB8860B),
                        ),
                      ),
                      pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Text(
                          _ur(row.$1),
                          style: pw.TextStyle(
                            font: urduFont,
                            fontSize: 7.5,
                            color: PdfColor.fromInt(0xFF12213A),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Naap PDF: Silai (sewing) column â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static pw.Widget _buildNaapSilaiColumnPdf(
      MeasurementModel? measurement, pw.Font urduFont) {
    final silaiOpts = measurement?.silaiOptions ?? [];
    final silaiNotes = measurement?.silaiNotes ?? '';

    final defaultOpts = [
      {'label': 'Ø²Ù†Ø¬ÛŒØ± Ø³Ù„Ø§Ø¦ÛŒ', 'checked': false},
      {'label': 'Ù¹Ø§Ù†Ú©Û Ù¾Û Ù¹Ø§Ù†Ú©Û', 'checked': false},
      {'label': 'Ø±ÛŒØ´Ù…ÛŒ ØªØ§Ø±', 'checked': false},
      {'label': 'Ø¬ÙˆÚ©Û Ø³Ù„Ø§Ø¦ÛŒ', 'checked': false},
      {'label': 'ÚˆØ¨Ù„ Ø³Ù„Ø§Ø¦ÛŒ', 'checked': false},
      {'label': 'Ø³Ù¹ÛŒÙ„ Ø¨Ù¹Ù†', 'checked': false},
      {'label': 'Ú©Ù¾Ú‘Ø§ Ø¨Ù¹Ù†', 'checked': false},
    ];
    for (final opt in silaiOpts) {
      final lbl = (opt['label'] ?? opt['urdu'] ?? '').toString();
      final checked = opt['checked'] == true;
      for (final d in defaultOpts) {
        if (d['label'] == lbl) d['checked'] = checked;
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _pdfColHdr('Ø³Ù„Ø§Ø¦ÛŒ Ú©ÛŒ Ù‚Ø³Ù…', urduFont),
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: defaultOpts.map((opt) {
              final label = opt['label'] as String;
              final checked = opt['checked'] as bool;
              return pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE8DDD0), width: 0.7),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Text(
                          _ur(label),
                          style: pw.TextStyle(
                            font: urduFont,
                            fontSize: 7,
                            color: PdfColor.fromInt(0xFF374151),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      _buildCheckbox(checked),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        _pdfColHdr('Ø®Ø§Øµ ÛØ¯Ø§ÛŒØ§Øª', urduFont, small: true),
        pw.Expanded(
          flex: 2,
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(
                _ur(silaiNotes.isEmpty ? 'Ú©ÙˆØ¦ÛŒ ÛØ¯Ø§ÛŒØª Ù†ÛÛŒÚº' : silaiNotes),
                style: pw.TextStyle(
                  font: urduFont,
                  fontSize: 7,
                  color: PdfColor.fromInt(0xFF4B5563),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // â”€â”€ _buildCheckbox (still used by _buildNaapSilaiColumnPdf) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static pw.Widget _buildCheckbox(bool checked) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFF12213A), width: 0.8),
        borderRadius: pw.BorderRadius.circular(2),
        color: checked ? PdfColor.fromInt(0xFFB8860B) : PdfColors.white,
      ),
      alignment: pw.Alignment.center,
      child: checked
          ? pw.Text(
              'âœ“',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            )
          : pw.SizedBox(),
    );
  }

  static pw.Widget _buildNewFooter(pw.Font urduFont) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          height: 0.8,
          color: PdfColor.fromInt(0xFFD97706),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Powered by Darzi Pro',
              style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
            ),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(
                _ur('Ø´Ú©Ø±ÛŒÛ! Ø¯ÙˆØ¨Ø§Ø±Û ØªØ´Ø±ÛŒÙ Ù„Ø§Ø¦ÛŒÚº'),
                style: pw.TextStyle(
                  font: urduFont,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFD97706),
                ),
              ),
            ),
            pw.Text(
              'Saddar, Peshawar Â· 0300-1234567',
              style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }
}
