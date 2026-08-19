import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../shared/models/models.dart';

/// Standard Flutter Widget for Traditional Naap Card.
/// Rendered natively by Flutter's engine (Skia/Impeller) for 100% pixel-perfect
/// Urdu shaping, RTL text joining, and crisp diagrams before export to PDF image.
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

  @override
  Widget build(BuildContext context) {
    final category = measurement?.category ?? MeasurementCategory.men;

    final Map<String, String> measurements = {};
    if (measurement != null) {
      for (final section in measurement!.sections) {
        for (final field in section.fields) {
          measurements[field.key] = field.value;
        }
      }
    }

    // Fixed A5 print proportion container (700 x 990)
    return Container(
      width: 700,
      height: 990,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            _buildHeader(),
            const SizedBox(height: 10),

            // 2. Info Bar
            _buildInfoBar(),
            const SizedBox(height: 10),

            // 3. Customer Row
            _buildCustomerRow(),
            const SizedBox(height: 10),

            // 4. Main Body Content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Diagrams (28% width)
                  Expanded(
                    flex: 28,
                    child: Column(
                      children: [
                        Expanded(
                          child: category == MeasurementCategory.women
                              ? _buildFrockDiagram()
                              : _buildKameezDiagram(isKids: category == MeasurementCategory.children),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildShalwarDiagram(category: category),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Center Column: Measurements Table (44% width)
                  Expanded(
                    flex: 44,
                    child: _buildMeasurementsTable(measurements),
                  ),
                  const SizedBox(width: 10),

                  // Right Column: Sewing options & Instructions (28% width)
                  Expanded(
                    flex: 28,
                    child: _buildSewingAndInstructions(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 5. Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── 1. HEADER ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Token Box
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOKEN NO.',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              order.tokenNumber,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD97706),
              ),
            ),
          ],
        ),

        // Center: Shop info
        Column(
          children: [
            Text(
              'SaifurRahman Tailors',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Saddar, Peshawar',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '0300-1234567',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        ),

        // Right: Payment Summary Card (Dark Header + White Body + Border)
        Container(
          width: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                child: Text(
                  'PAYMENT SUMMARY',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildSummaryRow('Total Amount', formatMoney(order.totalAmount)),
              _buildSummaryRow('Advance', formatMoney(order.paidAmount)),
              _buildSummaryRow('Balance', formatMoney(order.remainingAmount), isBoldRed: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBoldRed = false}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 8, color: Colors.black87),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isBoldRed ? const Color(0xFFDC2626) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. INFO BAR ──────────────────────────────────────────────────────────
  Widget _buildInfoBar() {
    final totalQty = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final shortId = order.customerId.isNotEmpty == true
        ? (order.customerId.length >= 8 ? order.customerId.substring(0, 8).toUpperCase() : order.customerId.toUpperCase())
        : '';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildInfoBox('تاریخ درج بکنگ', formatDateShort(order.orderDate)),
          _buildInfoDivider(),
          _buildInfoBox(
            'تاریخ ڈیلیوری',
            order.deliveryDate != null ? formatDateShort(order.deliveryDate!) : '-',
            isRed: true,
          ),
          _buildInfoDivider(),
          _buildInfoBox('تعداد', '$totalQty'),
          _buildInfoDivider(),
          _buildInfoBox('Customer No.', '#$shortId', isEngLabel: true),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, {bool isRed = false, bool isEngLabel = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: isEngLabel
                  ? GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF475569))
                  : GoogleFonts.notoNaskhArabic(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isRed ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoDivider() {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFFE2E8F0),
    );
  }

  // ── 3. CUSTOMER ROW ──────────────────────────────────────────────────────
  Widget _buildCustomerRow() {
    final phone = customer?.phone ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Phone
          if (phone.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF0F172A)),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),

          // Right: Customer Name in Urdu/Native text
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              order.customerName,
              style: GoogleFonts.notoNaskhArabic(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. DIAGRAMS ──────────────────────────────────────────────────────────
  Widget _buildKameezDiagram({bool isKids = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            child: Text(
              'قمیض',
              style: GoogleFonts.notoNaskhArabic(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 120),
                    painter: _KameezPainter(),
                  ),
                  // Badges
                  const Positioned(bottom: 45, left: 75, child: _AnnotationBadge('1')),
                  const Positioned(bottom: 98, left: 45, child: _AnnotationBadge('2')),
                  const Positioned(bottom: 80, left: 10, child: _AnnotationBadge('3')),
                  const Positioned(bottom: 70, left: 45, child: _AnnotationBadge('4')),
                  const Positioned(bottom: 78, left: 26, child: _AnnotationBadge('5')),
                  const Positioned(bottom: 45, left: 45, child: _AnnotationBadge('6')),
                  const Positioned(bottom: 12, left: 45, child: _AnnotationBadge('7')),
                  const Positioned(bottom: 106, left: 45, child: _AnnotationBadge('8')),
                  const Positioned(bottom: 30, left: 75, child: _AnnotationBadge('11', isExtra: true)),
                  const Positioned(bottom: 48, left: 25, child: _AnnotationBadge('12', isExtra: true)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildFrockDiagram() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            child: Text(
              'قمیض / فراک',
              style: GoogleFonts.notoNaskhArabic(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 120),
                    painter: _FrockPainter(),
                  ),
                  const Positioned(bottom: 104, left: 45, child: _AnnotationBadge('1')),
                  const Positioned(bottom: 64, left: 22, child: _AnnotationBadge('2')),
                  const Positioned(bottom: 48, left: 60, child: _AnnotationBadge('3')),
                  const Positioned(bottom: 14, left: 45, child: _AnnotationBadge('4')),
                  const Positioned(bottom: 78, left: 10, child: _AnnotationBadge('5')),
                  const Positioned(bottom: 90, left: 45, child: _AnnotationBadge('6')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildShalwarDiagram({MeasurementCategory category = MeasurementCategory.men}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            child: Text(
              'شلوار',
              style: GoogleFonts.notoNaskhArabic(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 120),
                    painter: _ShalwarPainter(),
                  ),
                  if (category == MeasurementCategory.men) ...[
                    const Positioned(bottom: 55, left: 70, child: _AnnotationBadge('9')),
                    const Positioned(bottom: 16, left: 25, child: _AnnotationBadge('10')),
                    const Positioned(bottom: 42, left: 44, child: _AnnotationBadge('13', isExtra: true)),
                    const Positioned(bottom: 60, left: 22, child: _AnnotationBadge('14', isExtra: true)),
                  ] else if (category == MeasurementCategory.women) ...[
                    const Positioned(bottom: 55, left: 70, child: _AnnotationBadge('7', isExtra: true)),
                    const Positioned(bottom: 16, left: 25, child: _AnnotationBadge('8', isExtra: true)),
                  ] else ...[
                    const Positioned(bottom: 55, left: 70, child: _AnnotationBadge('5')),
                    const Positioned(bottom: 16, left: 25, child: _AnnotationBadge('6')),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  // ── 5. MEASUREMENTS TABLE ────────────────────────────────────────────────
  Widget _buildMeasurementsTable(Map<String, String> measurements) {
    final List<Map<String, dynamic>> items = [
      {'no': '1', 'eng': 'Length', 'ur': 'لمبائی', 'keys': ['lambai', 'length']},
      {'no': '2', 'eng': 'Shoulder', 'ur': 'تیرا', 'keys': ['teerwa', 'shoulder', 'teera']},
      {'no': '3', 'eng': 'Sleeve', 'ur': 'آستین / بازو', 'keys': ['bazo', 'sleeve', 'aasteen']},
      {'no': '4', 'eng': 'Chest', 'ur': 'چھاتی', 'keys': ['chaati', 'chest', 'bust']},
      {'no': '5', 'eng': 'Arm Hole', 'ur': 'بغل / کمول', 'keys': ['baghal', 'arm_hole', 'armhole']},
      {'no': '6', 'eng': 'Waist', 'ur': 'کمر', 'keys': ['kamar', 'waist']},
      {'no': '7', 'eng': 'Hem', 'ur': 'دامن', 'keys': ['daman', 'hem', 'hem_circle']},
      {'no': '8', 'eng': 'Collar', 'ur': 'کالر / گلا', 'keys': ['collar', 'neck', 'neck_depth']},
      {'no': '9', 'eng': 'Trouser', 'ur': 'شلوار لمبائی', 'keys': ['shalwar', 'shalwar_length', 'trouser']},
      {'no': '10', 'eng': 'Bottom', 'ur': 'پانچہ', 'keys': ['panche', 'pancha', 'bottom']},
      {'no': '11', 'eng': 'Cuff', 'ur': 'کف', 'keys': ['kaf', 'cuff']},
      {'no': '12', 'eng': 'Pocket', 'ur': 'جیب / پٹی', 'keys': ['jeb', 'pocket']},
      {'no': '13', 'eng': 'Gol/Hip', 'ur': 'گول / ہپ', 'keys': ['gol', 'hip']},
      {'no': '14', 'eng': 'Asan', 'ur': 'آسن', 'keys': ['asan']},
      {'no': '15', 'eng': 'Gareban', 'ur': 'گریبان', 'keys': ['gareban']},
    ];

    if (measurement != null) {
      for (final section in measurement!.sections) {
        if (section.title == 'Custom Fields') {
          int customIdx = 16;
          for (final f in section.fields) {
            if (f.value.trim().isNotEmpty) {
              items.add({
                'no': '$customIdx',
                'eng': f.label,
                'ur': f.label,
                'keys': [f.key],
              });
              customIdx++;
            }
          }
        }
      }
    }

    String getVal(dynamic keysRef) {
      if (keysRef is List) {
        for (final k in keysRef) {
          final v = measurements[k?.toString()];
          if (v != null && v.trim().isNotEmpty) return v.trim();
        }
      } else if (keysRef != null) {
        final v = measurements[keysRef.toString()];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سائز (Size)',
                  style: GoogleFonts.notoNaskhArabic(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ناپ (Measurement)',
                  style: GoogleFonts.notoNaskhArabic(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final item = items[idx];
                final val = getVal(item['keys']);
                final isHighlight = val.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      // Badge number
                      _AnnotationBadge(item['no'] as String, isExtra: idx >= 10),
                      const SizedBox(width: 4),

                      // English + Urdu labels
                      Text(
                        '(${item['eng']}) ',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF475569)),
                      ),
                      Text(
                        item['ur'] as String,
                        style: GoogleFonts.notoNaskhArabic(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),

                      const Spacer(),

                      // Value
                      Text(
                        val.isEmpty ? '-' : val,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isHighlight ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. SEWING OPTIONS & INSTRUCTIONS ──────────────────────────────────────
  Widget _buildSewingAndInstructions() {
    final silaiOpts = measurement?.silaiOptions ?? [];

    final silaiNotes = measurement?.silaiNotes ?? '';

    final List<Map<String, String>> designItems = [];
    if (measurement != null) {
      for (final section in measurement!.sections) {
        if (section.title == 'Design Options') {
          for (final f in section.fields) {
            if (f.value.trim().isNotEmpty) {
              designItems.add({'label': f.label, 'val': f.value});
            }
          }
        }
      }
    }

    return Column(
      children: [
        // Design Choices Box (if present)
        if (designItems.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  child: Text(
                    'ڈیزائن کے اختیارات',
                    style: GoogleFonts.notoNaskhArabic(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    children: designItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['label']!,
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                            ),
                            Text(
                              item['val']!,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
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
          const SizedBox(height: 6),
        ],

        // Stitch Type Box
        if (silaiOpts.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  child: Text(
                    'سلائی کی قسم',
                    style: GoogleFonts.notoNaskhArabic(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: silaiOpts.map((opt) {
                      final label = (opt['label'] ?? opt['urdu'] ?? '').toString();
                      final checked = opt['checked'] == true;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCheckbox(checked),
                            Text(
                              label,
                              style: GoogleFonts.notoNaskhArabic(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
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
        const SizedBox(height: 6),

        // Special Instructions Box
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  child: Text(
                    'خاص ہدایات',
                    style: GoogleFonts.notoNaskhArabic(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      silaiNotes.isEmpty ? 'کوئی خاص ہدایت درج نہیں' : silaiNotes,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.notoNaskhArabic(fontSize: 10, color: const Color(0xFF334155)),
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

  Widget _buildCheckbox(bool checked) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF0F172A), width: 1),
        borderRadius: BorderRadius.circular(3),
        color: checked ? const Color(0xFFD97706) : Colors.white,
      ),
      alignment: Alignment.center,
      child: checked
          ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
          : const SizedBox.shrink(),
    );
  }

  // ── 7. FOOTER ────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1.5,
          color: const Color(0xFFD97706),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Powered by Darzi Pro',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B)),
            ),
            Text(
              'شکریہ! دوبارہ تشریف لائیں',
              style: GoogleFonts.notoNaskhArabic(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD97706),
              ),
            ),
            Text(
              'Saddar, Peshawar · 0300-1234567',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── ANNOTATION BADGE ────────────────────────────────────────────────────────
class _AnnotationBadge extends StatelessWidget {
  final String label;
  final bool isExtra;

  const _AnnotationBadge(this.label, {this.isExtra = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: isExtra ? const Color(0xFF64748B) : const Color(0xFFD97706),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── CUSTOM PAINTERS FOR DIAGRAMS ───────────────────────────────────────────
class _KameezPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(size.width * 0.42, size.height * 0.1)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.16, size.width * 0.58, size.height * 0.1)
      ..lineTo(size.width * 0.7, size.height * 0.14)
      ..lineTo(size.width * 0.9, size.height * 0.44)
      ..lineTo(size.width * 0.83, size.height * 0.46)
      ..lineTo(size.width * 0.65, size.height * 0.38)
      ..lineTo(size.width * 0.65, size.height * 0.7)
      ..lineTo(size.width * 0.68, size.height * 0.9)
      ..lineTo(size.width * 0.32, size.height * 0.9)
      ..lineTo(size.width * 0.35, size.height * 0.7)
      ..lineTo(size.width * 0.35, size.height * 0.38)
      ..lineTo(size.width * 0.17, size.height * 0.46)
      ..lineTo(size.width * 0.1, size.height * 0.44)
      ..lineTo(size.width * 0.3, size.height * 0.14)
      ..close();

    canvas.drawPath(path, paint);

    final dashPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(size.width * 0.3, size.height * 0.14), Offset(size.width * 0.7, size.height * 0.14), dashPaint);
    canvas.drawLine(Offset(size.width * 0.35, size.height * 0.38), Offset(size.width * 0.65, size.height * 0.38), dashPaint);
    canvas.drawLine(Offset(size.width * 0.35, size.height * 0.7), Offset(size.width * 0.65, size.height * 0.7), dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(size.width * 0.4, size.height * 0.1)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.18, size.width * 0.6, size.height * 0.1)
      ..lineTo(size.width * 0.74, size.height * 0.14)
      ..lineTo(size.width * 0.88, size.height * 0.44)
      ..lineTo(size.width * 0.8, size.height * 0.46)
      ..lineTo(size.width * 0.62, size.height * 0.38)
      ..lineTo(size.width * 0.65, size.height * 0.54)
      ..lineTo(size.width * 0.85, size.height * 0.9)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.96, size.width * 0.15, size.height * 0.9)
      ..lineTo(size.width * 0.35, size.height * 0.54)
      ..lineTo(size.width * 0.38, size.height * 0.38)
      ..lineTo(size.width * 0.2, size.height * 0.46)
      ..lineTo(size.width * 0.12, size.height * 0.44)
      ..lineTo(size.width * 0.26, size.height * 0.14)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShalwarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.1)
      ..lineTo(size.width * 0.76, size.height * 0.1)
      ..lineTo(size.width * 0.82, size.height * 0.5)
      ..lineTo(size.width * 0.76, size.height * 0.9)
      ..lineTo(size.width * 0.6, size.height * 0.9)
      ..lineTo(size.width * 0.5, size.height * 0.52)
      ..lineTo(size.width * 0.4, size.height * 0.9)
      ..lineTo(size.width * 0.24, size.height * 0.9)
      ..lineTo(size.width * 0.18, size.height * 0.5)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
