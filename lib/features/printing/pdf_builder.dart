import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show fontFromAssetBundle;
import '../../shared/models/models.dart';
import '../../core/widgets/shared_widgets.dart';

/// Builds printable PDFs for Darzi Pro
/// – A4 branded layout
/// – 80mm thermal layout
class DarziPdfBuilder {
  DarziPdfBuilder._();

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
    final fontData = await rootBundle.load('fonts/NotoNaskhArabic-Regular.ttf');
    final arabicFont = pw.Font.ttf(fontData);

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
    final fontData = await rootBundle.load('fonts/NotoNaskhArabic-Regular.ttf');
    final arabicFont = pw.Font.ttf(fontData);

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
                      isUrdu ? 'سیف الرحمن ٹیلرز' : '✂ SAIFURRAHMAN TAILORS',
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
                      pw.Text(formatMoney(item.total),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ],
                  )),
              _thermalDivider(),

              // Payment block
              _thermalRow(
                isUrdu ? 'کل رقم:' : 'Total:',
                formatMoney(order.totalAmount),
              ),
              _thermalRow(
                isUrdu ? 'ایڈوانس ادا کیا:' : 'Advance Paid:',
                formatMoney(order.paidAmount),
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
                          : formatMoney(order.remainingAmount),
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
                  child: pw.Text('✂',
                      style: pw.TextStyle(
                          color: _dark,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 22)),
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
              pw.Text('📱 ${customer.phone}',
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
                  pw.Text(formatMoney(item.total),
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
            formatMoney(order.totalAmount),
          ),
          if (order.discount > 0)
            _pdfMoneyRow(
              isUrdu ? 'ڈسکاؤنٹ' : 'Discount',
              '- ${formatMoney(order.discount)}',
              valueColor: _teal,
            ),
          _pdfMoneyRow(
            isUrdu ? 'ایڈوانس ادا کیا' : 'Advance Paid',
            formatMoney(order.paidAmount),
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
                    ? (isUrdu ? '✅ مکمل ادا شدہ' : '✅ Fully Paid') 
                    : (isUrdu ? '⚡ باقی رقم' : '⚡ Remaining'),
                style: pw.TextStyle(
                    color: _gold, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                order.isFullyPaid
                    ? (isUrdu ? 'بے باق' : 'CLEAR')
                    : formatMoney(order.remainingAmount),
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
  static Future<List<int>> buildTraditionalNaapCard(
      OrderModel order, CustomerModel? customer, MeasurementModel? measurement) async {
    pw.Font urduFont;
    try {
      urduFont = await fontFromAssetBundle('fonts/NotoNaskhArabic-Regular.ttf');
    } catch (_) {
      try {
        urduFont = await fontFromAssetBundle('assets/fonts/NotoNaskhArabic-Regular.ttf');
      } catch (_) {
        final fontData = await rootBundle.load('fonts/NotoNaskhArabic-Regular.ttf');
        urduFont = pw.Font.ttf(fontData);
      }
    }

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
    final paperColor = PdfColor.fromHex('#FDF6F0');

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context ctx) {
          return pw.Container(
            color: paperColor,
            padding: const pw.EdgeInsets.all(12),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. Header row
                  _buildHeaderRow(order, urduFont),
                  pw.Container(height: 0.5, color: PdfColors.black),
                  
                  // 2. Second row
                  _buildSecondRow(order, customer, urduFont),
                  pw.Container(height: 0.5, color: PdfColors.black),
                  
                  // 3. Customer name row
                  _buildCustomerNameRow(order, urduFont),
                  pw.Container(height: 0.5, color: PdfColors.black),
                  
                  // 4. Main body (two columns)
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Left: Garment Diagram (40% width)
                        pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                            alignment: pw.Alignment.center,
                            child: _buildGarmentDiagram(measurements, urduFont),
                          ),
                        ),
                        pw.Container(width: 0.5, color: PdfColors.black),
                        // Right: Measurements Table (60% width)
                        pw.Expanded(
                          flex: 6,
                          child: pw.Container(
                            alignment: pw.Alignment.center,
                            child: _buildMeasurementsTable(measurements, urduFont),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 5. Footer row
                  _buildFooter(order, urduFont),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderRow(OrderModel order, pw.Font urduFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            'Bok No: ${order.tokenNumber}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          'سیف الرحمن ٹیلرز',
          style: pw.TextStyle(font: urduFont, fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.Row(
          children: [
            _buildHeaderBox('Total', formatMoney(order.totalAmount)),
            _buildHeaderBox('Adv', formatMoney(order.paidAmount)),
            _buildHeaderBox('Bal', formatMoney(order.remainingAmount)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderBox(String label, String value) {
    return pw.Container(
      width: 44,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            height: 12,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
              ),
            ),
            child: pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Container(
            height: 14,
            alignment: pw.Alignment.center,
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 7)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSecondRow(OrderModel order, CustomerModel? customer, pw.Font urduFont) {
    final shortId = customer?.id.isNotEmpty == true
        ? (customer!.id.length >= 8 ? customer.id.substring(0, 8).toUpperCase() : customer.id.toUpperCase())
        : '';
    final totalQty = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Text('تاریخ بکنگ:  ', style: pw.TextStyle(font: urduFont, fontSize: 8)),
                  ),
                  pw.Text(formatDateShort(order.orderDate), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                children: [
                  pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Text('تاریخ واپسی:  ', style: pw.TextStyle(font: urduFont, fontSize: 8)),
                  ),
                  pw.Text(order.deliveryDate != null ? formatDateShort(order.deliveryDate!) : '-', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('CustomerNo: $shortId', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Row(
                children: [
                  pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Text('تعداد:  ', style: pw.TextStyle(font: urduFont, fontSize: 8)),
                  ),
                  pw.Text('$totalQty', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomerNameRow(OrderModel order, pw.Font urduFont) {
    return pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        order.customerName,
        style: pw.TextStyle(font: urduFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildGarmentDiagram(Map<String, String> measurements, pw.Font urduFont) {
    return pw.Stack(
      children: [
        pw.CustomPaint(
          size: const PdfPoint(150, 200),
          painter: (PdfGraphics canvas, PdfPoint size) {
            canvas.setStrokeColor(PdfColors.black);
            canvas.setLineWidth(0.5);

            // Neck left
            canvas.moveTo(63, 180);
            // Collar curve (U shape)
            canvas.curveTo(65, 172, 85, 172, 87, 180);
            // Right shoulder
            canvas.lineTo(105, 172);
            // Right sleeve outer
            canvas.lineTo(135, 120);
            // Right sleeve opening
            canvas.lineTo(125, 117);
            // Right armhole
            canvas.lineTo(98, 130);
            // Right waist
            canvas.lineTo(98, 75);
            // Right daman
            canvas.lineTo(102, 25);
            // Bottom daman line
            canvas.lineTo(48, 25);
            // Left daman
            canvas.lineTo(52, 75);
            canvas.lineTo(52, 130);
            canvas.lineTo(25, 117);
            canvas.lineTo(15, 120);
            canvas.lineTo(45, 172);
            canvas.lineTo(63, 180);
            canvas.strokePath();

            // Draw measurement dashed/thin indicator lines (in light grey)
            canvas.setStrokeColor(PdfColors.grey);
            canvas.setLineWidth(0.3);

            // Shoulder line (Teerwa)
            canvas.drawLine(45, 172, 105, 172);
            // Sleeve line (Bazo)
            canvas.drawLine(45, 172, 15, 120);
            // Chest line (Chhaati)
            canvas.drawLine(52, 130, 98, 130);
            // Waist line (Kamar)
            canvas.drawLine(52, 75, 98, 75);
            // Daman line
            canvas.drawLine(48, 25, 102, 25);
            // Length line (Lambai)
            canvas.drawLine(115, 172, 115, 25);
          },
        ),

        // Annotations on top
        _buildAnnotatedText(measurements['collar'] ?? '', top: 8, left: 70), // Neck/Collar
        _buildAnnotatedText(measurements['teerwa'] ?? '', top: 20, left: 70), // Teerwa
        _buildAnnotatedText(measurements['bazo'] ?? '', top: 50, left: 18), // Bazo
        _buildAnnotatedText(measurements['chhaati'] ?? '', top: 62, left: 70), // Chhaati (Chest)
        _buildAnnotatedText(measurements['kamar'] ?? '', top: 115, left: 70), // Kamar
        _buildAnnotatedText(measurements['daman'] ?? '', top: 162, left: 70), // Daman
        _buildAnnotatedText(measurements['lambai'] ?? '', top: 90, left: 110), // Lambai (Length)
      ],
    );
  }

  static pw.Widget _buildAnnotatedText(String value, {required double top, required double left}) {
    if (value.isEmpty) return pw.SizedBox();
    return pw.Positioned(
      top: top,
      left: left,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFFDF6F0), // match background color to cover line
        ),
        child: pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
        ),
      ),
    );
  }

  static pw.Widget _buildMeasurementsTable(Map<String, String> measurements, pw.Font urduFont) {
    final rowsData = [
      ('لمبائی', measurements['lambai'] ?? ''),
      ('تیرو', measurements['teerwa'] ?? ''),
      ('بازو', measurements['bazo'] ?? ''),
      ('چھاتی', measurements['chhaati'] ?? ''),
      ('بغل', measurements['baghal'] ?? ''),
      ('کمر', measurements['kamar'] ?? ''),
      ('دامن', measurements['daman'] ?? ''),
      ('کالر', measurements['collar'] ?? ''),
      ('شلوار', measurements['shalwar'] ?? ''),
      ('پانچے', measurements['panche'] ?? ''),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: rowsData.map((data) => _buildMeasurementRow(data.$1, data.$2, urduFont)).toList(),
    );
  }

  static pw.Widget _buildMeasurementRow(String label, String value, pw.Font urduFont) {
    return pw.Container(
      height: 16,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.only(left: 6),
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 8.5)),
            ),
          ),
          pw.Container(width: 0.5, color: PdfColors.black),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.only(right: 6),
              child: pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(font: urduFont, fontSize: 8.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(OrderModel order, pw.Font urduFont) {
    return pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        'صدر، پشاور · 0300-1234567',
        style: pw.TextStyle(font: urduFont, fontSize: 7, color: PdfColors.grey),
      ),
    );
  }
}
