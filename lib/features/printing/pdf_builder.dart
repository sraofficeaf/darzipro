import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:arabic_reshaper/arabic_reshaper.dart';
import '../../shared/models/models.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/constants/app_enums.dart';

class _PdfIsolateArgs {
  final Uint8List pngBytes;
  final PdfPageFormat pageFormat;

  _PdfIsolateArgs({required this.pngBytes, required this.pageFormat});
}

Future<Uint8List> _buildPdfIsolate(_PdfIsolateArgs args) async {
  final pdf = pw.Document();
  final pdfImage = pw.MemoryImage(args.pngBytes);
  pdf.addPage(
    pw.Page(
      pageFormat: args.pageFormat,
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

/// Builds printable PDFs for Darzi Pro
/// – A4 branded layout
/// – 80mm thermal layout
class DarziPdfBuilder {
  DarziPdfBuilder._();

  /// Builds a PDF Document directly from PNG image bytes captured from a Flutter Widget.
  /// Guarantees 100% pixel-perfect Urdu script, RTL shaping, diagrams, and formatting.
  static Future<List<int>> buildPdfFromImageBytes(
    Uint8List pngBytes, {
    PdfPageFormat pageFormat = PdfPageFormat.a5,
  }) async {
    return await compute(
      _buildPdfIsolate,
      _PdfIsolateArgs(pngBytes: pngBytes, pageFormat: pageFormat),
    );
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
      debugPrint('DarziPdfBuilder: Failed to load local font — $e');
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

  // ── A4 LAYOUT ──────────────────────────────────────────────────────
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

  // ── THERMAL 80MM LAYOUT ────────────────────────────────────────────
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
                      isUrdu ? 'سیف الرحمن ٹیلرز' : 'SAIFURRAHMAN TAILORS',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                    pw.Text(
                      isUrdu ? 'صدر، پشاور · 0300-1234567' : 'Saddar, Peshawar · 0300-1234567',
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
                      isUrdu ? 'آرڈر نمبر #${order.orderNumber}' : 'Order #${order.orderNumber}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              _thermalDivider(),

              // Customer
              pw.Text(
                isUrdu ? 'گاہک' : 'CUSTOMER',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 8),
              ),
              pw.Text(order.customerName,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 13)),
              if (customer != null)
                pw.Text('📱 ${customer.phone}',
                    style: const pw.TextStyle(fontSize: 9)),
              _thermalDivider(),

              // Dates
              _thermalRow(
                isUrdu ? 'آرڈر کی تاریخ:' : 'Order Date:',
                formatDateShort(order.orderDate),
                bold: false,
              ),
              if (order.deliveryDate != null)
                _thermalRow(
                  isUrdu ? 'ڈیلیوری کی تاریخ:' : 'Delivery Date:',
                  formatDateShort(order.deliveryDate!),
                  bold: true,
                  highlight: order.isUrgent,
                ),
              _thermalDivider(),

              // Items
              pw.Text(
                isUrdu ? 'آئٹمز' : 'ITEMS',
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
                isUrdu ? 'کل رقم:' : 'Total:',
                _pdfMoney(order.totalAmount),
              ),
              _thermalRow(
                isUrdu ? 'ایڈوانس ادا کیا:' : 'Advance Paid:',
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
                          ? (isUrdu ? 'مکمل ادائیگی ✓' : 'FULLY PAID ✓')
                          : (isUrdu ? 'باقی رقم:' : 'BAQI:'),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.Text(
                      order.isFullyPaid
                          ? (isUrdu ? 'بے باق' : 'CLEAR')
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
                  isUrdu ? 'نوٹس:' : 'NOTES:',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 8),
                ),
                pw.Text(order.notes!,
                    style: const pw.TextStyle(fontSize: 9)),
              ],

              _thermalDivider(),
              pw.Center(
                child: pw.Text(
                  isUrdu ? '-- درزی پرو کے ذریعے تیار کردہ --' : '-- Generated by Darzi Pro --',
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

  // ── A4 WIDGET BUILDERS ─────────────────────────────────────────────

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
                    isUrdu ? 'سیف الرحمن ٹیلرز' : 'SaifurRahman Tailors',
                    style: pw.TextStyle(
                        color: _white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16),
                  ),
                  pw.Text(
                    isUrdu ? 'صدر، پشاور · 0300-1234567' : 'Saddar, Peshawar · 0300-1234567',
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
                  isUrdu ? 'ٹوکن' : 'TOKEN',
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
              isUrdu ? 'گاہک' : 'CUSTOMER',
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
              isUrdu ? 'آرڈر نمبر' : 'ORDER NO.',
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
          isUrdu ? 'آرڈر کی تاریخ' : 'ORDER DATE',
          formatDateShort(order.orderDate),
          urgent: false,
        ),
        pw.SizedBox(width: 12),
        _dateBox(
          isUrdu ? 'ڈیلیوری کی تاریخ' : 'DELIVERY DATE',
          order.deliveryDate != null
              ? formatDateShort(order.deliveryDate!)
              : (isUrdu ? 'طے نہیں ہے' : 'Not Set'),
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
                      isUrdu ? 'آئٹم / کپڑا' : 'ITEM / CLOTH',
                      style: pw.TextStyle(
                          color: _grey,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8),
                    )),
                pw.Text(
                  isUrdu ? 'تعداد' : 'QTY',
                  style: pw.TextStyle(
                      color: _grey, fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 40),
                pw.Text(
                  isUrdu ? 'قیمت' : 'PRICE',
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
                  pw.Text('× ${item.quantity}',
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
            isUrdu ? 'کل رقم' : 'Total Amount',
            _pdfMoney(order.totalAmount),
          ),
          if (order.discount > 0)
            _pdfMoneyRow(
              isUrdu ? 'ڈسکاؤنٹ' : 'Discount',
              '- ${_pdfMoney(order.discount)}',
              valueColor: _teal,
            ),
          _pdfMoneyRow(
            isUrdu ? 'ایڈوانس ادا کیا' : 'Advance Paid',
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
                    ? (isUrdu ? 'مکمل ادا شدہ' : 'Fully Paid') 
                    : (isUrdu ? 'باقی رقم' : 'Remaining'),
                style: pw.TextStyle(
                    color: _gold, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                order.isFullyPaid
                    ? (isUrdu ? 'بے باق' : 'CLEAR')
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
            isUrdu ? '📌 نوٹس' : '📌 NOTES',
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
              isUrdu ? 'درزی پرو کے ذریعے تیار کردہ' : 'Generated by Darzi Pro',
              style: pw.TextStyle(color: _grey, fontSize: 8),
            ),
            pw.Text(
              'SaifurRahman Tailors · ${formatDateShort(DateTime.now())}',
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

  // ── THERMAL HELPERS ──────────────────────────────────────────────

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

  // ── TRADITIONAL NAAP CARD A5 LAYOUT ─────────────────────────────────
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

    final category = measurement?.category ?? MeasurementCategory.men;

    final pdf = pw.Document();
    final format = PdfPageFormat.a5;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFF0F172A), width: 1),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Header
                _buildNewHeader(order, customer, urduFont),
                pw.SizedBox(height: 8),

                // 2. Info Bar
                _buildNewInfoBar(order, urduFont),
                pw.SizedBox(height: 8),

                // 3. Customer Row
                _buildNewCustomerRow(order, customer, urduFont),
                pw.SizedBox(height: 8),

                // 4. Main Body
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Left Column: Diagrams (28% width)
                      pw.Expanded(
                        flex: 28,
                        child: pw.Column(
                          children: [
                            pw.Expanded(
                              child: category == MeasurementCategory.women
                                  ? _buildFrockDiagram(urduFont)
                                  : _buildKameezDiagram(urduFont, isKids: category == MeasurementCategory.children),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Expanded(
                              child: _buildShalwarDiagram(urduFont, category: category),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),

                      // Center Column: Measurements Table (44% width)
                      pw.Expanded(
                        flex: 44,
                        child: _buildNewMeasurementsTable(measurements, measurement, urduFont),
                      ),
                      pw.SizedBox(width: 8),

                      // Right Column: Sewing options & Instructions (28% width)
                      pw.Expanded(
                        flex: 28,
                        child: _buildSewingAndInstructions(measurement, urduFont),
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

  static pw.Widget _buildNewHeader(OrderModel order, CustomerModel? customer, pw.Font urduFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Token Box
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TOKEN NO.',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey500,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              order.tokenNumber,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFFD97706),
              ),
            ),
          ],
        ),

        // Center: Shop info
        pw.Column(
          children: [
            pw.Text(
              'SaifurRahman Tailors',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF0F172A),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Saddar, Peshawar',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              '0300-1234567',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),

        // Right: Payment Summary
        pw.Container(
          width: 100,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromInt(0xFF0F172A), width: 0.8),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: double.infinity,
                color: PdfColor.fromInt(0xFF0F172A),
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'PAYMENT SUMMARY',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              _buildSummaryRow('Total Amount', _pdfMoney(order.totalAmount)),
              _buildSummaryRow('Advance', _pdfMoney(order.paidAmount)),
              _buildSummaryRow('Balance', _pdfMoney(order.remainingAmount), isBoldRed: true),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBoldRed = false}) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.black),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
              color: isBoldRed ? PdfColor.fromInt(0xFFDC2626) : PdfColors.black,
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
          _buildInfoBox('', 'تاریخ درج بکنگ', formatDateShort(order.orderDate), urduFont),
          _buildInfoDivider(),
          _buildInfoBox(
            '',
            'تاریخ ڈیلیوری',
            order.deliveryDate != null ? formatDateShort(order.deliveryDate!) : '-',
            urduFont,
            isRed: true,
          ),
          _buildInfoDivider(),
          _buildInfoBox('', 'تعداد', '$totalQty', urduFont),
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

  static pw.Widget _buildKameezDiagram(pw.Font urduFont, {bool isKids = false}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            color: PdfColors.grey200,
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            alignment: pw.Alignment.center,
            child: pw.Text(
              _ur('قمیض'),
              style: pw.TextStyle(font: urduFont, fontSize: 7, color: PdfColors.black, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.CustomPaint(
                    size: const PdfPoint(75, 90),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      canvas.setStrokeColor(PdfColors.grey700);
                      canvas.setLineWidth(0.6);

                      // Neck left
                      canvas.moveTo(31.5, 81);
                      // Collar curve
                      canvas.curveTo(32.5, 77.4, 42.5, 77.4, 43.5, 81);
                      // Right shoulder
                      canvas.lineTo(52.5, 77.4);
                      // Right sleeve outer
                      canvas.lineTo(67.5, 54);
                      // Right sleeve opening
                      canvas.lineTo(62.4, 52.6);
                      // Right armhole
                      canvas.lineTo(48.9, 58.5);
                      // Right waist
                      canvas.lineTo(48.9, 33.7);
                      // Right daman
                      canvas.lineTo(51, 11.2);
                      // Bottom daman
                      canvas.lineTo(24, 11.2);
                      // Left daman
                      canvas.lineTo(26.1, 33.7);
                      // Left waist / armhole
                      canvas.lineTo(26.1, 58.5);
                      canvas.lineTo(12.6, 52.6);
                      canvas.lineTo(7.5, 54);
                      canvas.lineTo(22.5, 77.4);
                      canvas.lineTo(31.5, 81);
                      canvas.strokePath();

                      // Draw indicator lines
                      canvas.setStrokeColor(PdfColors.grey400);
                      canvas.setLineWidth(0.3);
                      canvas.drawLine(22.5, 77.4, 52.5, 77.4); // Shoulder
                      canvas.drawLine(22.5, 77.4, 7.5, 54); // Sleeve
                      canvas.drawLine(26.1, 58.5, 48.9, 58.5); // Chest
                      canvas.drawLine(26.1, 33.7, 48.9, 33.7); // Waist
                      canvas.drawLine(24, 11.2, 51, 11.2); // Bottom daman
                      canvas.drawLine(57, 77.4, 57, 11.2); // Length
                    },
                  ),
                  // Annotation Badges for Mard/Kids
                  // 1. Length (Standard)
                  pw.Positioned(bottom: 35, left: 54, child: _buildAnnotationBadge('1')),
                  // 2. Shoulder (Standard)
                  pw.Positioned(bottom: 74, left: 33, child: _buildAnnotationBadge('2')),
                  // 3. Sleeve (Standard)
                  pw.Positioned(bottom: 60, left: 8, child: _buildAnnotationBadge('3')),
                  // 4. Chest (Standard)
                  pw.Positioned(bottom: 54, left: 33, child: _buildAnnotationBadge('4')),
                  // 5. Arm Hole / Baghal (Standard)
                  pw.Positioned(bottom: 58, left: 20, child: _buildAnnotationBadge('5')),
                  
                  if (!isKids) ...[
                    // 6. Waist (Standard)
                    pw.Positioned(bottom: 32, left: 33, child: _buildAnnotationBadge('6')),
                    // 7. Hem / Daman (Standard)
                    pw.Positioned(bottom: 12, left: 33, child: _buildAnnotationBadge('7')),
                    // 8. Collar (Standard)
                    pw.Positioned(bottom: 70, left: 50, child: _buildAnnotationBadge('8')),
                    
                    // Extra fields (Grey)
                    // 11. Cuff (Grey)
                    pw.Positioned(bottom: 46, left: 63, child: _buildAnnotationBadge('11', isExtra: true)),
                    // 12. Pocket (Grey)
                    pw.Positioned(bottom: 40, left: 45, child: _buildAnnotationBadge('12', isExtra: true)),
                    // 15. Gareban (Grey)
                    pw.Positioned(bottom: 78, left: 19, child: _buildAnnotationBadge('15', isExtra: true)),
                  ],
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 2),
        ],
      ),
    );
  }

  static pw.Widget _buildFrockDiagram(pw.Font urduFont) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            color: PdfColors.grey200,
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            alignment: pw.Alignment.center,
            child: pw.Text(
              _ur('فراک / میکسی'),
              style: pw.TextStyle(font: urduFont, fontSize: 7, color: PdfColors.black, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.CustomPaint(
                    size: const PdfPoint(75, 90),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      canvas.setStrokeColor(PdfColors.grey700);
                      canvas.setLineWidth(0.6);

                      // Neckline round U
                      canvas.moveTo(30, 78);
                      canvas.curveTo(33, 72, 42, 72, 45, 78);

                      // Left shoulder
                      canvas.lineTo(20, 75);
                      // Left sleeve
                      canvas.lineTo(10, 50);
                      // Left cuff
                      canvas.lineTo(16, 48);
                      // Left armhole / waist
                      canvas.lineTo(26, 56);
                      canvas.lineTo(28, 40);
                      // Left flare to daman
                      canvas.lineTo(12, 10);
                      // Daman bottom line curve
                      canvas.curveTo(30, 6, 45, 6, 63, 10);
                      // Right flare to waist
                      canvas.lineTo(47, 40);
                      canvas.lineTo(49, 56);
                      // Right armhole / sleeve
                      canvas.lineTo(59, 48);
                      canvas.lineTo(65, 50);
                      // Right shoulder
                      canvas.lineTo(55, 75);
                      canvas.lineTo(45, 78);
                      canvas.strokePath();

                      // Dotted indicators
                      canvas.setStrokeColor(PdfColors.grey400);
                      canvas.setLineWidth(0.3);
                      canvas.drawLine(24, 52, 51, 52); // Bust line (2)
                      canvas.drawLine(28, 40, 47, 40); // Waist line (3)
                      canvas.drawLine(12, 10, 63, 10); // Hem/daman line (4)
                    },
                  ),
                  // Annotation Badges for Women
                  // 1. Length (Standard - Gold)
                  pw.Positioned(bottom: 78, left: 33, child: _buildAnnotationBadge('1')),
                  // 2. Bust (Standard - Gold)
                  pw.Positioned(bottom: 48, left: 16, child: _buildAnnotationBadge('2')),
                  // 3. Waist (Standard - Gold)
                  pw.Positioned(bottom: 36, left: 45, child: _buildAnnotationBadge('3')),
                  // 4. Hem Circle (Standard - Gold)
                  pw.Positioned(bottom: 10, left: 33, child: _buildAnnotationBadge('4')),
                  // 5. Sleeve (Standard - Gold)
                  pw.Positioned(bottom: 58, left: 8, child: _buildAnnotationBadge('5')),
                  // 6. Neck Depth (Standard - Gold)
                  pw.Positioned(bottom: 68, left: 33, child: _buildAnnotationBadge('6')),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 2),
        ],
      ),
    );
  }

  static pw.Widget _buildShalwarDiagram(pw.Font urduFont, {MeasurementCategory category = MeasurementCategory.men}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            color: PdfColors.grey200,
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            alignment: pw.Alignment.center,
            child: pw.Text(
              _ur('شلوار'),
              style: pw.TextStyle(font: urduFont, fontSize: 7, color: PdfColors.black, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.CustomPaint(
                    size: const PdfPoint(75, 90),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      canvas.setStrokeColor(PdfColors.grey700);
                      canvas.setLineWidth(0.6);

                      // Waist
                      canvas.moveTo(18, 81);
                      canvas.lineTo(57, 81);
                      // Right leg outer
                      canvas.lineTo(61.8, 45);
                      canvas.lineTo(57, 13.5);
                      // Right bottom cuff
                      canvas.lineTo(45.6, 13.5);
                      // Crotch
                      canvas.lineTo(38, 43.2);
                      // Left bottom cuff
                      canvas.lineTo(30.4, 13.5);
                      // Left leg outer
                      canvas.lineTo(19, 13.5);
                      canvas.lineTo(14.2, 45);
                      canvas.lineTo(18, 81);
                      canvas.strokePath();

                      // Dotted indicators
                      canvas.setStrokeColor(PdfColors.grey400);
                      canvas.setLineWidth(0.3);
                      canvas.drawLine(57, 81, 57, 13.5); // Length line
                      canvas.drawLine(14.2, 45, 61.8, 45); // Hip/thigh line
                    },
                  ),
                  // Annotation Badges based on Category
                  if (category == MeasurementCategory.men) ...[
                    // 9. Shalwar Length (Gold)
                    pw.Positioned(bottom: 40, left: 52, child: _buildAnnotationBadge('9')),
                    // 10. Panche (Gold)
                    pw.Positioned(bottom: 12, left: 18, child: _buildAnnotationBadge('10')),
                    // 13. Gol/Hip (Grey)
                    pw.Positioned(bottom: 32, left: 32, child: _buildAnnotationBadge('13', isExtra: true)),
                    // 14. Asan (Grey)
                    pw.Positioned(bottom: 45, left: 16, child: _buildAnnotationBadge('14', isExtra: true)),
                  ] else if (category == MeasurementCategory.women) ...[
                    // 7. Trouser Length (Grey)
                    pw.Positioned(bottom: 40, left: 52, child: _buildAnnotationBadge('7', isExtra: true)),
                    // 8. Panche (Grey)
                    pw.Positioned(bottom: 12, left: 18, child: _buildAnnotationBadge('8', isExtra: true)),
                  ] else ...[
                    // Children
                    // 5. Shalwar Length (Gold)
                    pw.Positioned(bottom: 40, left: 52, child: _buildAnnotationBadge('5')),
                    // 6. Panche (Gold)
                    pw.Positioned(bottom: 12, left: 18, child: _buildAnnotationBadge('6')),
                  ]
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 2),
        ],
      ),
    );
  }

  static pw.Widget _buildAnnotationBadge(String label, {bool isExtra = false}) {
    final intColor = isExtra ? 0xFF6B7280 : 0xFFD97706;
    return pw.Container(
      width: 9,
      height: 9,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(intColor),
        shape: pw.BoxShape.circle,
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 5.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildCheckbox(bool checked) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFF0F172A), width: 0.8),
        borderRadius: pw.BorderRadius.circular(2),
        color: checked ? PdfColor.fromInt(0xFFD97706) : PdfColors.white,
      ),
      alignment: pw.Alignment.center,
      child: checked
          ? pw.Text(
              '✓',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            )
          : pw.SizedBox(),
    );
  }

  static pw.Widget _buildNewMeasurementsTable(
      Map<String, String> measurements, MeasurementModel? measurement, pw.Font urduFont) {
    
    final category = measurement?.category ?? MeasurementCategory.men;
    final List<(String, String, String, bool)> rowsData = [];

    if (category == MeasurementCategory.men) {
      rowsData.addAll([
        ('1', 'لمبائی (Length)', measurements['lambai'] ?? '', false),
        ('2', 'تیرا (Shoulder)', measurements['teerwa'] ?? '', false),
        ('3', 'بازو (Sleeve)', measurements['bazo'] ?? '', false),
        ('4', 'چھاتی (Chest)', measurements['chaati'] ?? '', false),
        ('5', 'بغل (Arm Hole)', measurements['baghal'] ?? '', false),
        ('6', 'کمر (Waist)', measurements['kamar'] ?? '', false),
        ('7', 'دامن (Hem)', measurements['daman'] ?? '', false),
        ('8', 'کالر (Collar)', measurements['collar'] ?? '', false),
        ('9', 'شلوار لمبائی (Trouser)', measurements['shalwar'] ?? '', false),
        ('10', 'پانچہ (Bottom)', measurements['panche'] ?? '', false),
        ('11', 'کف (Cuff)', measurements['kaf'] ?? '', true),
        ('12', 'جیب (Pocket)', measurements['jeb'] ?? '', true),
        ('13', 'گول (Gol/Hip)', measurements['gol'] ?? '', true),
        ('14', 'آسن (Asan)', measurements['asan'] ?? '', true),
        ('15', 'گریبان (Gareban)', measurements['gareban'] ?? '', true),
      ]);
    } else if (category == MeasurementCategory.women) {
      rowsData.addAll([
        ('1', 'لمبائی (Length)', measurements['lambai'] ?? '', false),
        ('2', 'چھاتی (Bust)', measurements['bust'] ?? '', false),
        ('3', 'کمر (Waist)', measurements['waist'] ?? '', false),
        ('4', 'دامن گھیرا (Hem Circle)', measurements['hem_circle'] ?? '', false),
        ('5', 'آستین (Sleeve)', measurements['sleeve'] ?? '', false),
        ('6', 'گلا گہرائی (Neck Depth)', measurements['neck_depth'] ?? '', false),
        ('7', 'شلوار/پاجامہ (Trouser)', measurements['shalwar'] ?? '', true),
        ('8', 'پانچے (Bottom)', measurements['panche'] ?? '', true),
      ]);
    } else {
      rowsData.addAll([
        ('1', 'لمبائی (Length)', measurements['lambai'] ?? '', false),
        ('2', 'چھاتی (Chest)', measurements['chaati'] ?? '', false),
        ('3', 'کمر (Waist)', measurements['kamar'] ?? '', false),
        ('4', 'بازو (Sleeve)', measurements['bazo'] ?? '', false),
        ('5', 'شلوار لمبائی (Trouser)', measurements['shalwar'] ?? '', false),
        ('6', 'پانچہ (Bottom)', measurements['panche'] ?? '', false),
      ]);
    }

    if (measurement != null) {
      final customSection = measurement.sections.where((s) => s.title == 'Custom Fields').firstOrNull;
      if (customSection != null) {
        int idx = category == MeasurementCategory.men ? 16 : (category == MeasurementCategory.women ? 9 : 7);
        for (final field in customSection.fields) {
          rowsData.add((idx.toString(), field.label, field.value, true));
          idx++;
        }
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          height: 16,
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0F172A),
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              topRight: pw.Radius.circular(4),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('سائز (Size)', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(_ur('ناپ (Measurement)'), style: pw.TextStyle(font: urduFont, color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        ...rowsData.map((data) => _buildNewMeasurementRow(data.$1, data.$2, data.$3, urduFont, data.$4)),
      ],
    );
  }

  static pw.Widget _buildNewMeasurementRow(String index, String label, String value, pw.Font urduFont, bool isExtra) {
    return pw.Container(
      height: 18,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Row(
        children: [
          _buildAnnotationBadge(index, isExtra: isExtra),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.centerLeft,
              child: pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Text(
                  _ur(label),
                  style: pw.TextStyle(font: urduFont, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSewingAndInstructions(MeasurementModel? measurement, pw.Font urduFont) {
    final Map<String, String> designOptions = {};
    if (measurement != null) {
      for (final section in measurement.sections) {
        if (section.title == 'Design Options') {
          for (final f in section.fields) {
            designOptions[f.key] = f.value;
          }
        }
      }
    }

    String translateOptionVal(String key, String engVal) {
      final map = {
        'round': 'گول کالر',
        'mandarin': 'چینی کالر',
        'peshawari': 'پشاوری کالر',
        'standard': 'سٹینڈرڈ',
        'standard/spread': 'سٹینڈرڈ',
        'round_neck': 'گول گلا',
        'v-neck': 'وی گلا',
        'boat_neck': 'بوٹ نیک',
        'high_neck': 'ہائی نیک',
        'open': 'اوپن',
        'closed': 'بند',
        'standard_cuff': 'سادہ کف',
        'embroidery': 'کڑھائی',
        'button_cuff': 'بٹن کف',
        'double_cuff': 'ڈبل کف',
        'standard_patti': 'سادہ پٹی',
        'covered': 'چھپی پٹی',
        'none': 'بغیر پٹی',
        'chest': 'سینے جیب',
        'side': 'پہلو جیب',
        'straight': 'سیدھی',
        'fitting': 'فٹنگ',
        'loose': 'ڈھیلی',
        'straight_shalwar': 'سیدھی',
        'churidar': 'چوڑی دار',
        'patiala': 'پٹیالہ',
        'full': 'فل آستین',
        'half': 'ہاف آستین',
        'three_quarter': 'تین چوتھائی',
        'sleeveless': 'بغیر آستین',
        'gheradar': 'گھیرا دار',
        'a-line': 'اے لائن',
        'pencil': 'پینسل',
      };
      
      final normalized = engVal.toLowerCase().trim().replaceAll(' ', '_');
      if (map.containsKey(normalized)) {
        return map[normalized]!;
      }
      return engVal;
    }

    final List<(String, String)> optionsToPrint = [];
    if (measurement?.category == MeasurementCategory.women) {
      if (designOptions.containsKey('gala_type') && designOptions['gala_type']!.isNotEmpty) {
        optionsToPrint.add(('گلا کی قسم', translateOptionVal('gala_type', designOptions['gala_type']!)));
      }
      if (designOptions.containsKey('aasteen_type') && designOptions['aasteen_type']!.isNotEmpty) {
        optionsToPrint.add(('آستین کی قسم', translateOptionVal('aasteen_type', designOptions['aasteen_type']!)));
      }
      if (designOptions.containsKey('daman_type') && designOptions['daman_type']!.isNotEmpty) {
        optionsToPrint.add(('دامن کی قسم', translateOptionVal('daman_type', designOptions['daman_type']!)));
      }
    } else {
      if (designOptions.containsKey('collar_type') && designOptions['collar_type']!.isNotEmpty) {
        optionsToPrint.add(('کالر', translateOptionVal('collar_type', designOptions['collar_type']!)));
      }
      if (designOptions.containsKey('neck_style') && designOptions['neck_style']!.isNotEmpty) {
        optionsToPrint.add(('گلا', translateOptionVal('neck_style', designOptions['neck_style']!)));
      }
      if (designOptions.containsKey('kaf_style') && designOptions['kaf_style']!.isNotEmpty) {
        optionsToPrint.add(('کف', translateOptionVal('kaf_style', designOptions['kaf_style']!)));
      }
      if (designOptions.containsKey('front_style') && designOptions['front_style']!.isNotEmpty) {
        optionsToPrint.add(('پٹی', translateOptionVal('front_style', designOptions['front_style']!)));
      }
      if (designOptions.containsKey('pocket_type') && designOptions['pocket_type']!.isNotEmpty) {
        optionsToPrint.add(('جیب', translateOptionVal('pocket_type', designOptions['pocket_type']!)));
      }
      if (designOptions.containsKey('shape') && designOptions['shape']!.isNotEmpty) {
        optionsToPrint.add(('شیپ', translateOptionVal('shape', designOptions['shape']!)));
      }
      if (designOptions.containsKey('shalwar_style') && designOptions['shalwar_style']!.isNotEmpty) {
        optionsToPrint.add(('شلوار', translateOptionVal('shalwar_style', designOptions['shalwar_style']!)));
      }
    }

    final List<Map<String, dynamic>> defaultOptions = [
      {'label': 'زنجیر سلائی', 'checked': false},
      {'label': 'ٹانکہ پہ ٹانکہ', 'checked': false},
      {'label': 'ریشمی تار', 'checked': false},
      {'label': 'جوکہ سلائی', 'checked': false},
      {'label': 'ڈبل سلائی', 'checked': false},
      {'label': 'سٹیل بٹن', 'checked': false},
      {'label': 'کپڑا بٹن', 'checked': false},
    ];

    if (measurement != null && measurement.silaiOptions != null) {
      for (final opt in measurement.silaiOptions!) {
        final label = opt['label'] as String?;
        final checked = opt['checked'] as bool? ?? false;
        if (label != null) {
          final target = defaultOptions.where((o) => o['label'] == label).firstOrNull;
          if (target != null) {
            target['checked'] = checked;
          }
        }
      }
    }

    final silaiNotes = measurement?.silaiNotes ?? '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (optionsToPrint.isNotEmpty) ...[
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  color: PdfColor.fromInt(0xFF0F172A),
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    _ur('ڈیزائن و قسم'),
                    style: pw.TextStyle(font: urduFont, color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: pw.Column(
                    children: optionsToPrint.map((opt) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Directionality(
                              textDirection: pw.TextDirection.rtl,
                              child: pw.Text(
                                _ur(opt.$2),
                                style: pw.TextStyle(font: urduFont, fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFFD97706)),
                              ),
                            ),
                            pw.Directionality(
                              textDirection: pw.TextDirection.rtl,
                              child: pw.Text(
                                _ur(opt.$1),
                                style: pw.TextStyle(font: urduFont, fontSize: 7, color: PdfColors.grey700),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
        ],
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                color: PdfColor.fromInt(0xFF0F172A),
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  _ur('سلائی کی قسم'),
                  style: pw.TextStyle(font: urduFont, color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: pw.Column(
                  children: defaultOptions.map((opt) {
                    final label = opt['label'] as String;
                    final checked = opt['checked'] as bool;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCheckbox(checked),
                          pw.Directionality(
                            textDirection: pw.TextDirection.rtl,
                            child: pw.Text(
                              _ur(label),
                              style: pw.TextStyle(font: urduFont, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  color: PdfColor.fromInt(0xFF0F172A),
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    _ur('خاص ہدایات'),
                    style: pw.TextStyle(font: urduFont, color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Directionality(
                      textDirection: pw.TextDirection.rtl,
                      child: pw.Text(
                        _ur(silaiNotes),
                        style: pw.TextStyle(font: urduFont, fontSize: 7.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
                _ur('شکریہ! دوبارہ تشریف لائیں'),
                style: pw.TextStyle(
                  font: urduFont,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFD97706),
                ),
              ),
            ),
            pw.Text(
              'Saddar, Peshawar · 0300-1234567',
              style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }
}
