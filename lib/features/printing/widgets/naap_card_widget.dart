import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../shared/models/models.dart';

/// Naap Card Widget — Matching Tailor's Exact Shapes & Simple Print Layout
///
/// Features:
///   1. Header: Token No., Shop info ("SaifurRahman Tailors"), Scissors icon.
///   2. Date bar: Booking Date, Delivery Date (red), Qty, Customer No.
///   3. Customer bar: Phone & large Urdu customer name.
///   4. Main Content (Pure white background, no card frames around shapes):
///      - Right Column: ناپ / سائز (ONLY entered fields printed).
///      - Left Area: Exact tailoring shapes from tailor's print master:
///          • ہاف گول (Curved collar band with measurement)
///          • گول (Horizontal cuff + vertical sleeve placket)
///          • فلاپ / نوک پٹی (Pointed arch placket)
///          • سنگل پیس شلوار (Shalwar cut with waistband notch, inner & inseam numbers)
///          • زنجیری سلائی / کف پلیٹ نہیں / چاک پٹی کاج (Clean text silai notes)
///          • ( S ) Bold circle size mark
///          • بٹن پٹی (Vertical button placket with 3 eyelets & 3.4 / 13 numbers)
///          • Hatched base shape (پانچہ / دامن)
///   5. Clean Footer: "Powered by Darzi Pro", "شکریہ! دوبارہ تشریف لائیں", shop contact.
class NaapCardWidget extends StatelessWidget {
  final OrderModel order;
  final CustomerModel? customer;
  final MeasurementModel? measurement;

  const NaapCardWidget({
    super.key,
    required this.order,
    required this.customer,
    required this.measurement,
  });

  // ── Build Map of entered measurements ────────────────────────────────────
  Map<String, String> _buildMeasurementsMap() {
    final m = <String, String>{};
    if (measurement == null) return m;
    for (final section in measurement!.sections) {
      for (final field in section.fields) {
        final val = field.value.trim();
        if (val.isNotEmpty && val != '0' && val != '-') {
          m[field.key] = val;
        }
      }
    }
    return m;
  }

  // ── Format value with inch symbol if purely numeric ───────────────────────
  static String _fmtVal(String raw) {
    if (RegExp(r'^[0-9.]+$').hasMatch(raw)) {
      return '$raw"';
    }
    return raw;
  }

  // ── Helper to get value matching multiple keys ───────────────────────────
  static String _getVal(Map<String, String> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.trim().isNotEmpty && v.trim() != '0' && v.trim() != '-') {
        return v.trim();
      }
    }
    return '';
  }

  // ── Standard 15 measurement definitions ──────────────────────────────────
  static const List<Map<String, dynamic>> _kAllMeasurementDefs = [
    {'eng': 'Length', 'ur': 'لمبائی', 'keys': ['lambai', 'length']},
    {'eng': 'Shoulder', 'ur': 'تیرو', 'keys': ['teerwa', 'shoulder', 'teera']},
    {'eng': 'Sleeve', 'ur': 'بازو', 'keys': ['bazo', 'sleeve', 'aasteen']},
    {'eng': 'Chest', 'ur': 'چھاتی', 'keys': ['chaati', 'chest', 'bust']},
    {'eng': 'Arm Hole', 'ur': 'بغل', 'keys': ['baghal', 'arm_hole', 'armhole']},
    {'eng': 'Waist', 'ur': 'کمر', 'keys': ['kamar', 'waist']},
    {'eng': 'Hem', 'ur': 'دامن', 'keys': ['daman', 'hem', 'hem_circle']},
    {'eng': 'Collar', 'ur': 'کالر', 'keys': ['collar', 'neck', 'neck_depth']},
    {'eng': 'Trouser L.', 'ur': 'شلوار', 'keys': ['shalwar', 'shalwar_length', 'trouser']},
    {'eng': 'Bottom', 'ur': 'پانچے', 'keys': ['panche', 'pancha', 'bottom']},
    {'eng': 'Cuff', 'ur': 'کف', 'keys': ['kaf', 'cuff']},
    {'eng': 'Pocket', 'ur': 'جیب', 'keys': ['jeb', 'pocket']},
    {'eng': 'Gol/Hip', 'ur': 'گول', 'keys': ['gol', 'hip']},
    {'eng': 'Asan', 'ur': 'آسن', 'keys': ['asan']},
    {'eng': 'Gareban', 'ur': 'گریبان', 'keys': ['gareban']},
  ];

  @override
  Widget build(BuildContext context) {
    final m = _buildMeasurementsMap();

    // Filter ONLY fields that the user actually entered
    final enteredFields = <Map<String, String>>[];
    for (final def in _kAllMeasurementDefs) {
      final val = _getVal(m, (def['keys'] as List).cast<String>());
      if (val.isNotEmpty) {
        enteredFields.add({
          'eng': def['eng'] as String,
          'ur': def['ur'] as String,
          'val': _fmtVal(val),
        });
      }
    }

    // Add custom fields
    if (measurement != null) {
      for (final section in measurement!.sections) {
        if (section.title == 'Custom Fields') {
          for (final f in section.fields) {
            final val = f.value.trim();
            if (val.isNotEmpty && val != '0' && val != '-') {
              enteredFields.add({
                'eng': f.label,
                'ur': f.label,
                'val': _fmtVal(val),
              });
            }
          }
        }
      }
    }

    return Container(
      width: 700,
      height: 990,
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFB8A080), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header (Token | Shop | Scissors)
            _buildHeader(),

            // 2. Gold Accent Divider
            _buildGoldDivider(),

            // 3. Date Row (Booking, Delivery, Qty, Customer No.)
            _buildDateRow(),

            // 4. Customer Row
            _buildCustomerRow(),

            // 5. Body (RTL: Measurements Table on Right | Simple Shapes Canvas on Left)
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Right: Measurements Table (ONLY entered fields!)
                    Expanded(
                      flex: 32,
                      child: _buildMeasurementsColumn(enteredFields),
                    ),

                    // Left/Middle: Tailor Shapes Canvas (Simple print, no cards!)
                    Expanded(
                      flex: 68,
                      child: _buildTailorShapesCanvas(m),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── 1. HEADER (TOKEN | SHOP | SCISSORS ICON) ─────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFB8A080), width: 1.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Token Box
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFB8A080), width: 1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOKEN NO.',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB8860B),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.tokenNumber.isNotEmpty ? order.tokenNumber : '#${order.orderNumber}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB8860B),
                  ),
                ),
              ],
            ),
          ),

          // Center: Shop info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SaifurRahman Tailors',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF12213A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📍 Saddar, Peshawar   |   📞 0300-1234567',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right: Scissors Icon Box
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFB8A080), width: 1.5),
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF5C842), Color(0xFFB8860B)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4DB8860B),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.content_cut_rounded,
                size: 26,
                color: Color(0xFF12213A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. GOLD ACCENT DIVIDER ───────────────────────────────────────────────
  Widget _buildGoldDivider() {
    return Container(
      height: 3,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B6914), Color(0xFFF5C842), Color(0xFF8B6914)],
        ),
      ),
    );
  }

  // ── 3. DATE ROW (BOOKING, DELIVERY, QTY, CUSTOMER NO) ────────────────────
  Widget _buildDateRow() {
    final totalQty = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final shortId = order.customerId.isNotEmpty
        ? (order.customerId.length >= 8 ? order.customerId.substring(0, 8).toUpperCase() : order.customerId.toUpperCase())
        : '${order.orderNumber}';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F0E8),
        border: Border(
          bottom: BorderSide(color: Color(0xFFB8A080), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          _buildDateBox('تاریخ بکنگ', formatDateShort(order.orderDate)),
          _buildDateBox(
            'تاریخ ڈیلیوری',
            order.deliveryDate != null ? formatDateShort(order.deliveryDate!) : '-',
            isRed: true,
          ),
          _buildDateBox('تعداد', '${totalQty > 0 ? totalQty : 1}'),
          _buildDateBox('.Customer No', '#$shortId', isEngLabel: true, isLast: true),
        ],
      ),
    );
  }

  Widget _buildDateBox(String label, String value, {bool isRed = false, bool isEngLabel = false, bool isLast = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(right: BorderSide(color: Color(0xFFC8B890), width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: isEngLabel
                  ? GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF8B7355), fontWeight: FontWeight.w600)
                  : GoogleFonts.notoNaskhArabic(fontSize: 9.5, color: const Color(0xFF8B7355), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isRed ? const Color(0xFFDC2626) : const Color(0xFF12213A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. CUSTOMER ROW ──────────────────────────────────────────────────────
  Widget _buildCustomerRow() {
    final phone = customer?.phone ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFB8860B), width: 2.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Phone
          Row(
            children: [
              const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                phone.isNotEmpty ? phone : '0312-3456789',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),

          // Right: Customer Name in large Urdu
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              order.customerName,
              style: GoogleFonts.notoNaskhArabic(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF12213A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5A. MEASUREMENTS TABLE (RIGHT COLUMN) ────────────────────────────────
  Widget _buildMeasurementsColumn(List<Map<String, String>> enteredFields) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xFFB8A080), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            color: const Color(0xFF12213A),
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            child: Text(
              'ناپ / سائز',
              style: GoogleFonts.notoNaskhArabic(
                color: const Color(0xFFF5C842),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Items (ONLY entered measurements!)
          Expanded(
            child: enteredFields.isEmpty
                ? Center(
                    child: Text(
                      'کوئی ناپ درج نہیں',
                      style: GoogleFonts.notoNaskhArabic(color: const Color(0xFF9CA3AF), fontSize: 11),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: enteredFields.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isEven = idx % 2 == 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isEven ? const Color(0xFFF9F4EC) : Colors.white,
                            border: const Border(bottom: BorderSide(color: Color(0xFFE8DDD0), width: 1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['ur']!,
                                    style: GoogleFonts.notoNaskhArabic(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF12213A),
                                    ),
                                  ),
                                  Text(
                                    item['val']!,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFB8860B),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                item['eng']!,
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── 5B. TAILOR SHAPES CANVAS (SIMPLE PRINT — ONLY ENTERED SHAPES) ─────────
  Widget _buildTailorShapesCanvas(Map<String, String> m) {
    // Dynamic values from entered measurements
    final collarVal = _getVal(m, ['collar', 'neck', 'neck_depth']);
    final cuffVal = _getVal(m, ['kaf', 'cuff']);
    final bazoVal = _getVal(m, ['bazo', 'sleeve', 'aasteen']);
    final shalwarVal = _getVal(m, ['shalwar', 'shalwar_length', 'trouser']);
    final asanVal = _getVal(m, ['asan']);
    final pancheVal = _getVal(m, ['panche', 'pancha', 'bottom']);
    final kamarVal = _getVal(m, ['kamar', 'waist']);
    final garebanVal = _getVal(m, ['gareban']);
    final damanVal = _getVal(m, ['daman', 'hem', 'hem_circle']);

    // Conditions: ONLY show shapes for fields that the user actually entered!
    final hasCollar = collarVal.isNotEmpty;
    final hasCuffOrBazo = cuffVal.isNotEmpty || bazoVal.isNotEmpty;
    final hasGareban = garebanVal.isNotEmpty;
    final hasShalwar = shalwarVal.isNotEmpty || asanVal.isNotEmpty || pancheVal.isNotEmpty;
    final hasKamar = kamarVal.isNotEmpty;
    final hasButtonPlacket = _getVal(m, ['button_patti', 'patti', 'front_patti']).isNotEmpty;
    final hasBase = damanVal.isNotEmpty || pancheVal.isNotEmpty;

    // Silai checked items ONLY (no dummy/unselected options!)
    final rawSilai = measurement?.silaiOptions ?? [];
    final silaiItems = <String>[];
    for (final opt in rawSilai) {
      if (opt['checked'] == true) {
        silaiItems.add((opt['label'] ?? opt['urdu'] ?? '').toString());
      }
    }

    final hasAnyLeftShape = hasCollar || hasCuffOrBazo || hasGareban || hasShalwar;
    final hasAnyRightShape = silaiItems.isNotEmpty || hasKamar || hasButtonPlacket || hasBase;

    if (!hasAnyLeftShape && !hasAnyRightShape) {
      return Center(
        child: Text(
          'کوئی شیپ منتخب نہیں',
          style: GoogleFonts.notoNaskhArabic(fontSize: 12, color: const Color(0xFF9CA3AF)),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── LEFT COLUMN OF SHAPES ─────────────────────────────────────────
          Expanded(
            flex: 52,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ہاف گول (Curved collar band — ONLY if collar is entered!)
                  if (hasCollar) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmtVal(collarVal),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 2),
                            CustomPaint(
                              size: const Size(82, 22),
                              painter: _HalfGolCollarPainter(),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ہاف گول',
                          style: GoogleFonts.notoNaskhArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 2. گول (Cuff + Sleeve Placket — ONLY if cuff or bazo is entered!)
                  if (hasCuffOrBazo) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            CustomPaint(
                              size: const Size(76, 72),
                              painter: _CuffPlacketPainter(),
                            ),
                            // Number inside horizontal cuff
                            if (cuffVal.isNotEmpty)
                              Positioned(
                                top: 2,
                                left: 6,
                                child: Text(
                                  _fmtVal(cuffVal),
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                            // Number next to vertical placket
                            if (bazoVal.isNotEmpty)
                              Positioned(
                                top: 28,
                                left: 28,
                                child: Text(
                                  _fmtVal(bazoVal),
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 36),
                          child: Text(
                            'گول',
                            style: GoogleFonts.notoNaskhArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 3. فلاپ / نوک پٹی (Pointed arch placket — ONLY if gareban is entered!)
                  if (hasGareban) ...[
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(54, 68),
                          painter: _PointedFlapPainter(),
                        ),
                        Positioned(
                          top: 14,
                          child: Text(
                            _fmtVal(garebanVal),
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 4. سنگل پیس شلوار (ONLY if shalwar, asan, or pancha is entered!)
                  if (hasShalwar) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            CustomPaint(
                              size: const Size(78, 88),
                              painter: _ShalwarPiecePainter(),
                            ),
                            // Value inside shalwar body
                            if (shalwarVal.isNotEmpty)
                              Positioned(
                                top: 42,
                                left: 14,
                                child: Text(
                                  _fmtVal(shalwarVal),
                                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                            // Value along curved inseam
                            if (asanVal.isNotEmpty || pancheVal.isNotEmpty)
                              Positioned(
                                bottom: 16,
                                right: 2,
                                child: Text(
                                  asanVal.isNotEmpty ? _fmtVal(asanVal) : _fmtVal(pancheVal),
                                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'سنگل پیس شلوار',
                          style: GoogleFonts.notoNaskhArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── RIGHT COLUMN OF SHAPES ────────────────────────────────────────
          Expanded(
            flex: 48,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Silai notes list (clean simple text, ONLY checked items!)
                  if (silaiItems.isNotEmpty)
                    Align(
                      alignment: Alignment.topRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: silaiItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Text(
                              item,
                              style: GoogleFonts.notoNaskhArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // 2. Bold Circle with S or waist (ONLY if kamar is entered!)
                  if (hasKamar) ...[
                    const SizedBox(height: 18),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(58, 58),
                          painter: _CircleSizePainter(),
                        ),
                        Text(
                          _fmtVal(kamarVal),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 3. بٹن پٹی (Vertical button strip — ONLY if patti is entered!)
                  if (hasButtonPlacket) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(26, 78),
                          painter: _ButtonPlacketPainter(),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '3.4',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '13',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],

                  // 4. Hatched U-shaped Base (ONLY if daman or pancha is entered!)
                  if (hasBase) ...[
                    const SizedBox(height: 18),
                    CustomPaint(
                      size: const Size(82, 28),
                      painter: _HatchedUBasePainter(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. FOOTER ────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F0E8),
        border: Border(
          top: BorderSide(color: Color(0xFFB8A080), width: 1.5),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                text: 'Powered by ',
                style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF9CA3AF)),
                children: [
                  TextSpan(
                    text: 'Darzi Pro',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFB8860B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40),
            Text(
              'شکریہ! دوبارہ تشریف لائیں',
              style: GoogleFonts.notoNaskhArabic(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFB8860B),
              ),
            ),
            const SizedBox(width: 40),
            Text(
              'Saddar, Peshawar 📞 0300-1234567',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM VECTOR PAINTERS (Matching Tailor's Exact Shapes) ────────────────

/// 1. ہاف گول (Curved collar band)
class _HalfGolCollarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(2, h * 0.25)
      ..quadraticBezierTo(w / 2, h * 0.7, w - 2, h * 0.25)
      ..lineTo(w - 2, h * 0.7)
      ..quadraticBezierTo(w / 2, h * 1.15, 2, h * 0.7)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 2. گول (Cuff + Vertical Sleeve Placket with square end)
class _CuffPlacketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Horizontal top cuff
    canvas.drawRect(const Rect.fromLTWH(0, 0, 72, 20), paint);

    // Vertical sleeve placket attached below left
    canvas.drawRect(const Rect.fromLTWH(8, 20, 16, 48), paint);

    // Line dividing bottom square
    canvas.drawLine(const Offset(8, 54), const Offset(24, 54), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3. فلاپ / نوک پٹی (Pointed arch placket with lower base)
class _PointedFlapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final w = size.width;
    final h = size.height;

    // Pointed top dome arch
    final topArch = Path()
      ..moveTo(2, h * 0.65)
      ..lineTo(2, h * 0.35)
      ..quadraticBezierTo(w * 0.15, 2, w * 0.5, 2)
      ..quadraticBezierTo(w * 0.85, 2, w - 2, h * 0.35)
      ..lineTo(w - 2, h * 0.65)
      ..close();
    canvas.drawPath(topArch, paint);

    // Divider line
    canvas.drawLine(Offset(2, h * 0.65), Offset(w - 2, h * 0.65), paint);

    // Lower base trapezoid
    final basePath = Path()
      ..moveTo(2, h * 0.65)
      ..lineTo(4, h - 2)
      ..lineTo(w - 4, h - 2)
      ..lineTo(w - 2, h * 0.65)
      ..close();
    canvas.drawPath(basePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 4. سنگل پیس شلوار (Shalwar cut with notch and inseam curve)
class _ShalwarPiecePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final w = size.width;
    final h = size.height;

    // Main shalwar cut outline
    final path = Path()
      ..moveTo(2, 2)
      ..lineTo(w - 2, 2)
      ..lineTo(w - 2, h * 0.32)
      ..quadraticBezierTo(w * 0.45, h * 0.42, w * 0.28, h - 2)
      ..lineTo(2, h - 2)
      ..close();
    canvas.drawPath(path, paint);

    // Waistband pocket notch at top left
    canvas.drawRect(const Rect.fromLTWH(8, 2, 14, 12), paint);
    canvas.drawLine(const Offset(8, 8), const Offset(22, 8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 5. ( S ) Bold Circle Size Mark
class _CircleSizePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), (size.width - 4) / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 6. بٹن پٹی (Vertical button strip with 3 eyelets & square end)
class _ButtonPlacketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final w = size.width;
    final h = size.height;

    // Main strip rectangle
    canvas.drawRect(Rect.fromLTWH(2, 2, w - 4, h - 14), paint);

    // 3 Button eyelets
    final eyeletPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, 16), width: 7, height: 11), eyeletPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, 32), width: 7, height: 11), eyeletPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, 48), width: 7, height: 11), eyeletPaint);

    // Square end box at bottom
    canvas.drawRect(Rect.fromLTWH(2, h - 12, w - 4, 10), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 7. Hatched U-shaped Base (پانچہ / دامن)
class _HatchedUBasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final w = size.width;
    final h = size.height;

    // U-shaped cut with bottom bar
    final uPath = Path()
      ..moveTo(2, 2)
      ..lineTo(14, 2)
      ..lineTo(14, h * 0.45)
      ..lineTo(w - 14, h * 0.45)
      ..lineTo(w - 14, 2)
      ..lineTo(w - 2, 2)
      ..lineTo(w - 2, h - 2)
      ..lineTo(2, h - 2)
      ..close();

    // Fill with diagonal hatch lines
    canvas.save();
    canvas.clipPath(uPath);
    final hatchPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double x = -h * 2; x < w + h * 2; x += 4.5) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), hatchPaint);
    }
    canvas.restore();

    canvas.drawPath(uPath, strokePaint);
    canvas.drawLine(Offset(2, h * 0.45), Offset(w - 2, h * 0.45), strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
