import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../printing/pdf_builder.dart';
import '../printing/widgets/card_image_capturer.dart';
import '../printing/widgets/naap_card_widget.dart';
import '../../core/utils/share_helper.dart';
import 'package:pdf/pdf.dart';
import '../customers/add_customer_modal.dart';
import '../orders/new_order_modal.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/supabase_providers.dart';

// ── DIAGRAM SHIRT PAINTER ─────────────────────────────────────────────────
class ShirtPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  final Color goldColor;
  ShirtPainter({
    this.strokeColor = const Color(0xFF3D5470),
    this.fillColor = const Color(0x06FFFFFF),
    this.goldColor = const Color(0xFFF5A623),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 126;
    final double sy = size.height / 160;

    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final bodyPath = Path()
      ..moveTo(28 * sx, 22 * sy)
      ..quadraticBezierTo(33 * sx, 14 * sy, 41 * sx, 17 * sy)
      ..quadraticBezierTo(46 * sx, 9 * sy, 63 * sx, 12 * sy)
      ..quadraticBezierTo(80 * sx, 9 * sy, 85 * sx, 17 * sy)
      ..quadraticBezierTo(93 * sx, 14 * sy, 98 * sx, 22 * sy)
      ..lineTo(109 * sx, 49 * sy)
      ..lineTo(88 * sx, 53 * sy)
      ..lineTo(88 * sx, 148 * sy)
      ..lineTo(38 * sx, 148 * sy)
      ..lineTo(38 * sx, 53 * sy)
      ..lineTo(17 * sx, 49 * sy)
      ..close();

    canvas.drawPath(bodyPath, paintFill);
    canvas.drawPath(bodyPath, paintStroke);

    final leftSleeve = Path()
      ..moveTo(17 * sx, 49 * sy)
      ..quadraticBezierTo(4 * sx, 57 * sy, 7 * sx, 74 * sy)
      ..lineTo(21 * sx, 74 * sy)
      ..close();
    canvas.drawPath(leftSleeve, paintFill);
    canvas.drawPath(leftSleeve, paintStroke);

    final rightSleeve = Path()
      ..moveTo(109 * sx, 49 * sy)
      ..quadraticBezierTo(122 * sx, 57 * sy, 118 * sx, 74 * sy)
      ..lineTo(104 * sx, 74 * sy)
      ..close();
    canvas.drawPath(rightSleeve, paintFill);
    canvas.drawPath(rightSleeve, paintStroke);

    // Neck opening
    final neck = Path()
      ..moveTo(52 * sx, 12 * sy)
      ..quadraticBezierTo(57 * sx, 6 * sy, 63 * sx, 8 * sy)
      ..quadraticBezierTo(69 * sx, 6 * sy, 74 * sx, 12 * sy);
    canvas.drawPath(neck, paintStroke);

    // Pocket outline
    final pocket = Path()
      ..addRect(Rect.fromLTWH(46 * sx, 80 * sy, 16 * sx, 12 * sy));
    canvas.drawPath(pocket, Paint()
      ..color = goldColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    final goldPaint = Paint()
      ..color = goldColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    _drawDashedLine(canvas, Offset(38 * sx, 78 * sy), Offset(88 * sx, 78 * sy), goldPaint, 2.5 * sx);
    _drawDashedLine(canvas, Offset(38 * sx, 96 * sy), Offset(88 * sx, 96 * sy), goldPaint, 2.5 * sx);
    _drawDashedLine(canvas, Offset(38 * sx, 114 * sy), Offset(88 * sx, 114 * sy), goldPaint, 2.5 * sx);
    _drawDashedLine(canvas, Offset(38 * sx, 132 * sy), Offset(88 * sx, 132 * sy), goldPaint, 2.5 * sx);
    _drawDashedLine(canvas, Offset(98 * sx, 66 * sy), Offset(112 * sx, 70 * sy), goldPaint, 2.0 * sx);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = Offset(dx, dy).distance;
    final int count = (distance / (dashWidth * 2)).floor();

    for (int i = 0; i < count; i++) {
      final double startPct = (i * 2 * dashWidth) / distance;
      final double endPct = ((i * 2 + 1) * dashWidth) / distance;
      canvas.drawLine(
        Offset(p1.dx + dx * startPct, p1.dy + dy * startPct),
        Offset(p1.dx + dx * endPct, p1.dy + dy * endPct),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── DIAGRAM TROUSER PAINTER ───────────────────────────────────────────────
class TrouserPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  final Color goldColor;
  TrouserPainter({
    this.strokeColor = const Color(0xFF3D5470),
    this.fillColor = const Color(0x06FFFFFF),
    this.goldColor = const Color(0xFFF5A623),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 102;
    final double sy = size.height / 102;

    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final bodyPath = Path()
      ..moveTo(14 * sx, 6 * sy)
      ..lineTo(88 * sx, 6 * sy)
      ..lineTo(86 * sx, 47 * sy)
      ..lineTo(69 * sx, 98 * sy)
      ..lineTo(52 * sx, 98 * sy)
      ..lineTo(50 * sx, 63 * sy)
      ..lineTo(48 * sx, 98 * sy)
      ..lineTo(31 * sx, 98 * sy)
      ..lineTo(14 * sx, 47 * sy)
      ..close();

    canvas.drawPath(bodyPath, paintFill);
    canvas.drawPath(bodyPath, paintStroke);

    final goldPaint = Paint()
      ..color = goldColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    _drawDashedLine(canvas, Offset(14 * sx, 20 * sy), Offset(88 * sx, 20 * sy), goldPaint, 2.5 * sx);
    _drawDashedLine(canvas, Offset(15 * sx, 35 * sy), Offset(80 * sx, 35 * sy), goldPaint, 2.5 * sx);
    _drawDashedLine(canvas, Offset(16 * sx, 50 * sy), Offset(65 * sx, 50 * sy), goldPaint, 2.5 * sx);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = Offset(dx, dy).distance;
    final int count = (distance / (dashWidth * 2)).floor();

    for (int i = 0; i < count; i++) {
      final double startPct = (i * 2 * dashWidth) / distance;
      final double endPct = ((i * 2 + 1) * dashWidth) / distance;
      canvas.drawLine(
        Offset(p1.dx + dx * startPct, p1.dy + dy * startPct),
        Offset(p1.dx + dx * endPct, p1.dy + dy * endPct),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── DIAGRAM FROCK PAINTER ─────────────────────────────────────────────────
class FrockPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  final Color goldColor;
  FrockPainter({
    this.strokeColor = const Color(0xFF3D5470),
    this.fillColor = const Color(0x06FFFFFF),
    this.goldColor = const Color(0xFFF5A623),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 110;
    final double sy = size.height / 155;

    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(30 * sx, 18 * sy)
      ..quadraticBezierTo(40 * sx, 8 * sy, 55 * sx, 10 * sy)
      ..quadraticBezierTo(70 * sx, 8 * sy, 80 * sx, 18 * sy)
      ..lineTo(90 * sx, 40 * sy)
      ..lineTo(78 * sx, 44 * sy)
      ..lineTo(88 * sx, 145 * sy)
      ..lineTo(22 * sx, 145 * sy)
      ..lineTo(32 * sx, 44 * sy)
      ..lineTo(20 * sx, 40 * sy)
      ..close();

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintStroke);

    // Neckline round U
    final neckPath = Path()
      ..moveTo(42 * sx, 10 * sy)
      ..quadraticBezierTo(48 * sx, 4 * sy, 55 * sx, 6 * sy)
      ..quadraticBezierTo(62 * sx, 4 * sy, 68 * sx, 10 * sy);
    canvas.drawPath(neckPath, paintStroke);

    final goldPaint = Paint()
      ..color = goldColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    _drawDashedLine(canvas, Offset(30 * sx, 55 * sy), Offset(80 * sx, 55 * sy), goldPaint, 2.5 * sx);
    _drawDashedLine(canvas, Offset(28 * sx, 70 * sy), Offset(82 * sx, 70 * sy), goldPaint, 2.5 * sx);
    _drawDashedLine(canvas, Offset(22 * sx, 140 * sy), Offset(88 * sx, 140 * sy), goldPaint, 2.5 * sx);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = Offset(dx, dy).distance;
    final int count = (distance / (dashWidth * 2)).floor();

    for (int i = 0; i < count; i++) {
      final double startPct = (i * 2 * dashWidth) / distance;
      final double endPct = ((i * 2 + 1) * dashWidth) / distance;
      canvas.drawLine(
        Offset(p1.dx + dx * startPct, p1.dy + dy * startPct),
        Offset(p1.dx + dx * endPct, p1.dy + dy * endPct),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── FIELD CONFIGURATION DEFINITIONS ───────────────────────────────────────
class MeasurementFieldDef {
  final String key;
  final String labelEng;
  final String labelUrdu;
  final int circleNum;
  final bool isExtra;

  const MeasurementFieldDef({
    required this.key,
    required this.labelEng,
    required this.labelUrdu,
    required this.circleNum,
    this.isExtra = false,
  });
}

final Map<MeasurementCategory, List<MeasurementFieldDef>> categoryFields = {
  MeasurementCategory.men: const [
    MeasurementFieldDef(key: 'lambai', labelEng: 'Length', labelUrdu: 'لمبائی', circleNum: 1),
    MeasurementFieldDef(key: 'teerwa', labelEng: 'Shoulder', labelUrdu: 'تیرا', circleNum: 2),
    MeasurementFieldDef(key: 'bazo', labelEng: 'Sleeve', labelUrdu: 'بازو', circleNum: 3),
    MeasurementFieldDef(key: 'chaati', labelEng: 'Chest', labelUrdu: 'چھاتی', circleNum: 4),
    MeasurementFieldDef(key: 'baghal', labelEng: 'Arm Hole', labelUrdu: 'بغل', circleNum: 5),
    MeasurementFieldDef(key: 'kamar', labelEng: 'Waist', labelUrdu: 'کمر', circleNum: 6),
    MeasurementFieldDef(key: 'daman', labelEng: 'Hem', labelUrdu: 'دامن', circleNum: 7),
    MeasurementFieldDef(key: 'collar', labelEng: 'Collar', labelUrdu: 'کالر', circleNum: 8),
    MeasurementFieldDef(key: 'shalwar', labelEng: 'Trouser L.', labelUrdu: 'شلوار', circleNum: 9),
    MeasurementFieldDef(key: 'panche', labelEng: 'Bottom', labelUrdu: 'پانچے', circleNum: 10),
    MeasurementFieldDef(key: 'kaf', labelEng: 'Cuff', labelUrdu: 'کف', circleNum: 11, isExtra: true),
    MeasurementFieldDef(key: 'jeb', labelEng: 'Pocket', labelUrdu: 'جیب', circleNum: 12, isExtra: true),
    MeasurementFieldDef(key: 'gol', labelEng: 'Gol/Hip', labelUrdu: 'گول', circleNum: 13, isExtra: true),
    MeasurementFieldDef(key: 'asan', labelEng: 'Asan', labelUrdu: 'آسن', circleNum: 14, isExtra: true),
    MeasurementFieldDef(key: 'gareban', labelEng: 'Gareban', labelUrdu: 'گریبان', circleNum: 15, isExtra: true),
  ],
  MeasurementCategory.women: const [
    MeasurementFieldDef(key: 'lambai', labelEng: 'Length', labelUrdu: 'لمبائی', circleNum: 1),
    MeasurementFieldDef(key: 'bust', labelEng: 'Bust', labelUrdu: 'چھاتی', circleNum: 2),
    MeasurementFieldDef(key: 'waist', labelEng: 'Waist', labelUrdu: 'کمر', circleNum: 3),
    MeasurementFieldDef(key: 'hem_circle', labelEng: 'Hem Circle', labelUrdu: 'دامن گھیرا', circleNum: 4),
    MeasurementFieldDef(key: 'sleeve', labelEng: 'Sleeve', labelUrdu: 'آستین', circleNum: 5),
    MeasurementFieldDef(key: 'neck_depth', labelEng: 'Neck Depth', labelUrdu: 'گلا گہرائی', circleNum: 6),
    MeasurementFieldDef(key: 'shalwar', labelEng: 'Trouser', labelUrdu: 'شلوار/پاجامہ', circleNum: 7, isExtra: true),
    MeasurementFieldDef(key: 'panche', labelEng: 'Bottom', labelUrdu: 'پانچے', circleNum: 8, isExtra: true),
  ],
  MeasurementCategory.children: const [
    MeasurementFieldDef(key: 'lambai', labelEng: 'Length', labelUrdu: 'لمبائی', circleNum: 1),
    MeasurementFieldDef(key: 'chaati', labelEng: 'Chest', labelUrdu: 'چھاتی', circleNum: 2),
    MeasurementFieldDef(key: 'kamar', labelEng: 'Waist', labelUrdu: 'کمر', circleNum: 3),
    MeasurementFieldDef(key: 'bazo', labelEng: 'Sleeve', labelUrdu: 'بازو', circleNum: 4),
    MeasurementFieldDef(key: 'shalwar', labelEng: 'Trouser L.', labelUrdu: 'شلوار', circleNum: 5),
    MeasurementFieldDef(key: 'panche', labelEng: 'Bottom', labelUrdu: 'پانچے', circleNum: 6),
  ],
};

// ── CUSTOM INTERACTIVE DIAGRAMS ───────────────────────────────────────────
class InteractiveDiagram extends StatelessWidget {
  final MeasurementCategory category;
  final Function(int) onCircleTap;
  final int? activeCircle;

  const InteractiveDiagram({
    super.key,
    required this.category,
    required this.onCircleTap,
    this.activeCircle,
  });

  Widget _buildCircle(int num, double left, double top, bool isExtra) {
    final isActive = activeCircle == num;
    final bg = isExtra ? const Color(0xFF6B7280) : const Color(0xFFD97706);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onCircleTap(num);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isActive ? 22 : 18,
          height: isActive ? 22 : 18,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.white, width: 1.5) : null,
            boxShadow: isActive
                ? [const BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$num',
            style: GoogleFonts.inter(
              fontSize: isActive ? 9.5 : 8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strokeColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);
    final fillColor = isDark ? const Color(0x06FFFFFF) : const Color(0x0D000000);
    final goldColor = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);

    return Column(
      children: [
        if (category == MeasurementCategory.women) ...[
          // Women top frock
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Text('فراک / میکسی', style: GoogleFonts.inter(fontSize: 11, color: goldColor, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 110,
            height: 155,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(110, 155),
                  painter: FrockPainter(strokeColor: strokeColor, fillColor: fillColor, goldColor: goldColor),
                ),
                _buildCircle(1, 55 - 9, 8 - 9, false),
                _buildCircle(2, 30 - 9, 55 - 9, false),
                _buildCircle(3, 82 - 9, 70 - 9, false),
                _buildCircle(4, 55 - 9, 140 - 9, false),
                _buildCircle(5, 18 - 9, 38 - 9, false),
                _buildCircle(6, 55 - 9, 22 - 9, false),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Women trouser
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Text('شلوار', style: GoogleFonts.inter(fontSize: 11, color: goldColor, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 102,
            height: 100,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(102, 100),
                  painter: TrouserPainter(strokeColor: strokeColor, fillColor: fillColor, goldColor: goldColor),
                ),
                _buildCircle(7, 51 - 9, 6 - 9, true),
                _buildCircle(8, 14 - 9, 20 - 9, true),
              ],
            ),
          ),
        ] else ...[
          // Men or kids top shirt
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Text('قمیض', style: GoogleFonts.inter(fontSize: 11, color: goldColor, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 126,
            height: 160,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(126, 160),
                  painter: ShirtPainter(strokeColor: strokeColor, fillColor: fillColor, goldColor: goldColor),
                ),
                _buildCircle(1, 63 - 9, 12 - 9, false),
                _buildCircle(2, 94 - 9, 49 - 9, false),
                _buildCircle(3, 8 - 9, 63 - 9, false),
                _buildCircle(4, 38 - 9, 78 - 9, false),
                _buildCircle(5, 21 - 9, 96 - 9, false),
                if (category == MeasurementCategory.men) ...[
                  _buildCircle(6, 38 - 9, 114 - 9, false),
                  _buildCircle(7, 38 - 9, 132 - 9, false),
                  _buildCircle(8, 63 - 9, 22 - 9, false),
                  _buildCircle(11, 112 - 9, 68 - 9, true),
                  _buildCircle(12, 54 - 9, 86 - 9, true),
                  _buildCircle(15, 63 - 9, 8 - 9, true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Men or kids trouser
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Text('شلوار', style: GoogleFonts.inter(fontSize: 11, color: goldColor, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 102,
            height: 100,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(102, 100),
                  painter: TrouserPainter(strokeColor: strokeColor, fillColor: fillColor, goldColor: goldColor),
                ),
                if (category == MeasurementCategory.men) ...[
                  _buildCircle(9, 51 - 9, 6 - 9, false),
                  _buildCircle(10, 14 - 9, 20 - 9, false),
                  _buildCircle(13, 80 - 9, 35 - 9, true),
                  _buildCircle(14, 16 - 9, 50 - 9, true),
                ] else ...[
                  // Kids trouser
                  _buildCircle(5, 51 - 9, 6 - 9, false),
                  _buildCircle(6, 14 - 9, 20 - 9, false),
                ]
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('Standard', style: GoogleFonts.inter(fontSize: 9, color: isDark ? Colors.white60 : Colors.black54)),
            const SizedBox(width: 12),
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6B7280), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('Extra fields', style: GoogleFonts.inter(fontSize: 9, color: isDark ? Colors.white60 : Colors.black54)),
          ],
        ),
      ],
    );
  }
}

// ── MAIN MEASUREMENTS EDITOR SCREEN ───────────────────────────────────────
class MeasurementsScreen extends ConsumerStatefulWidget {
  final String? customerId;
  final String? customerName;
  final MeasurementCategory? category;
  const MeasurementsScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.category,
  });

  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen>
    with SingleTickerProviderStateMixin {
  bool _isMetric = false;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _silaiNotesCtrl = TextEditingController();

  // Accordion Expand/Collapse Map
  final Map<String, bool> _accordionOpenMap = {
    'collar': true,
    'neck': false,
    'kaf': false,
    'front': false,
    'pocket': false,
    'shape': false,
    'shalwar': false,
    'gala_type': true,
    'aasteen_type': false,
    'daman_type': false,
  };

  // Design option selections (saved inside 'Design Options' section)
  String _collarType = 'Standard';
  String _neckStyle = 'Round';
  String _kafStyle = 'Standard';
  String _frontStyle = 'Standard';
  String _pocketType = 'Chest';
  String _shape = 'Straight';
  String _shalwarStyle = 'Straight';

  // Women specific design options
  String _galaType = 'Round';
  String _aasteenType = 'Full';
  String _damanType = 'Straight';

  // ── Silai style checkboxes ───────────────────────────────────────────────
  List<Map<String, dynamic>> _silaiOptions = [
    {'label': 'ڈبل سلائی', 'urdu': 'Double stitch', 'checked': true},
    {'label': 'زنجیر سلائی', 'urdu': 'Chain stitch', 'checked': false},
    {'label': 'ٹانکہ پہ ٹانکہ', 'urdu': 'Lock stitch', 'checked': false},
    {'label': 'ریشمی تار', 'urdu': 'Silk thread', 'checked': false},
    {'label': 'جوکہ سلائی', 'urdu': 'Flat stitch', 'checked': false},
    {'label': 'سٹیل بٹن', 'urdu': 'Steel buttons', 'checked': false},
    {'label': 'کپڑا بٹن', 'urdu': 'Fabric buttons', 'checked': false},
    {'label': 'پلاسٹک بٹن', 'urdu': 'Plastic buttons', 'checked': false},
    {'label': 'ایمبرائیڈری', 'urdu': 'Embroidery', 'checked': false},
  ];

  // ── Customer wishes (customer-side preferences) ──────────────────────────
  List<Map<String, dynamic>> _customerWishes = [
    {'label': 'ڈھیلا', 'urdu': 'Loose fit', 'checked': false},
    {'label': 'فٹنگ', 'urdu': 'Fitted', 'checked': false},
    {'label': 'لمبا دامن', 'urdu': 'Long hem', 'checked': false},
    {'label': 'چھوٹا دامن', 'urdu': 'Short hem', 'checked': false},
    {'label': 'لمبی آستین', 'urdu': 'Long sleeves', 'checked': false},
    {'label': 'چھوٹی آستین', 'urdu': 'Short sleeves', 'checked': false},
    {'label': 'چوڑی گردن', 'urdu': 'Wide neck', 'checked': false},
    {'label': 'تنگ گردن', 'urdu': 'Narrow neck', 'checked': false},
    {'label': 'جیب چاہیے', 'urdu': 'Pocket needed', 'checked': false},
    {'label': 'بغیر جیب', 'urdu': 'No pocket', 'checked': false},
  ];

  bool _initialized = false;
  bool _isSaving = false;
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  final List<_CustomFieldData> _customFieldsList = [];

  // Active highlighted circle (if any)
  int? _activeCircle;

  // Auto-fill & auto-save draft states
  MeasurementCategory _selectedCategory = MeasurementCategory.men;
  bool _isSavingDraft = false;
  DateTime? _draftSavedAt;
  DateTime? _lastSavedAt;
  bool _isDraftLoaded = false;
  bool _isAutoFilled = false;
  Timer? _debounceTimer;
  // ignore: unused_field
  bool _isPrinting = false;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() => setState(() {}));
    _initControllers();
    if (widget.customerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedMeasurementCustomerIdProvider.notifier).state = widget.customerId;
        }
      });
    }
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  void _initControllers() {
    final keys = [
      'lambai', 'teerwa', 'bazo', 'chaati', 'baghal', 'kamar', 'daman', 'collar', 'shalwar', 'panche',
      'kaf', 'jeb', 'gol', 'asan', 'gareban', // Men
      'bust', 'waist', 'hem_circle', 'sleeve', 'neck_depth', // Women
    ];
    for (final k in keys) {
      _controllers[k] = TextEditingController(text: '');
      _focusNodes[k] = FocusNode();
    }
    _notesCtrl.text = '';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _notesCtrl.dispose();
    _silaiNotesCtrl.dispose();
    _searchFocusNode.dispose();
    _fadeController.dispose();
    for (final cf in _customFieldsList) {
      cf.controller.dispose();
    }
    super.dispose();
  }

  double? _parseValue(String text) {
    text = text.trim();
    if (text.isEmpty) return null;
    text = text.replaceAll('½', '.5');
    text = text.replaceAll('¼', '.25');
    text = text.replaceAll('¾', '.75');
    return double.tryParse(text);
  }

  String _formatDouble(double val) {
    if (val == val.toInt().toDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  void _convertValues(bool toMetric) {
    for (final ctrl in _controllers.values) {
      final text = ctrl.text.trim();
      if (text.isNotEmpty) {
        final val = _parseValue(text);
        if (val != null) {
          ctrl.text = toMetric
              ? _formatDouble(val * 2.54)
              : _formatDouble(val / 2.54);
        }
      }
    }
    _onFieldChanged();
  }

  // ── AUTO-SAVE DRAFTS DEBOUNCE ───────────────────────────────────────────
  void _onFieldChanged() {
    if (!_isSavingDraft && mounted) {
      setState(() {
        _isSavingDraft = true;
      });
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _saveDraft();
    });
  }

  void _saveDraft() async {
    final customerId = ref.read(selectedMeasurementCustomerIdProvider);
    if (customerId == null) return;

    final draftData = {
      'category': _selectedCategory.name,
      'values': {
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      },
      'designOptions': {
        'collar_type': _collarType,
        'neck_style': _neckStyle,
        'kaf_style': _kafStyle,
        'front_style': _frontStyle,
        'pocket_type': _pocketType,
        'shape': _shape,
        'shalwar_style': _shalwarStyle,
        'gala_type': _galaType,
        'aasteen_type': _aasteenType,
        'daman_type': _damanType,
      },
      'silaiOptions': _silaiOptions,
      'customerWishes': _customerWishes,
      'silaiNotes': _silaiNotesCtrl.text,
      'notes': _notesCtrl.text,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final Box draftBox = Hive.box('naap_drafts_box');
      await draftBox.put('draft_$customerId', draftData);
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _draftSavedAt = DateTime.now();
          _isDraftLoaded = true;
        });
      }
    } catch (_) {}
  }

  void _loadCustomerData(String customerId) {
    for (final ctrl in _controllers.values) {
      ctrl.clear();
    }
    _notesCtrl.clear();
    _silaiNotesCtrl.clear();
    _customFieldsList.clear();

    // Reset design options to defaults
    _collarType = 'Standard';
    _neckStyle = 'Round';
    _kafStyle = 'Standard';
    _frontStyle = 'Standard';
    _pocketType = 'Chest';
    _shape = 'Straight';
    _shalwarStyle = 'Straight';
    _galaType = 'Round';
    _aasteenType = 'Full';
    _damanType = 'Straight';

    for (final w in _customerWishes) {
      w['checked'] = false;
    }

    _isDraftLoaded = false;
    _isAutoFilled = false;
    _draftSavedAt = null;
    _lastSavedAt = null;

    final Box draftBox = Hive.box('naap_drafts_box');
    dynamic draft;
    try {
      draft = draftBox.get('draft_$customerId');
    } catch (e) {
      debugPrint('Error reading draft from Hive: $e');
    }

    bool draftLoaded = false;
    if (draft is Map) {
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(draft);
        _selectedCategory = MeasurementCategory.values.firstWhere(
          (c) => c.name == data['category'],
          orElse: () => MeasurementCategory.men,
        );

        final Map<dynamic, dynamic>? rawValues = data['values'] is Map ? data['values'] as Map : null;
        if (rawValues != null) {
          final values = Map<String, String>.from(rawValues);
          values.forEach((k, v) {
            if (_controllers.containsKey(k)) _controllers[k]!.text = v;
          });
        }

        final Map<dynamic, dynamic>? rawOptions = data['designOptions'] is Map ? data['designOptions'] as Map : null;
        if (rawOptions != null) {
          final options = Map<String, String>.from(rawOptions);
          if (options.containsKey('collar_type')) _collarType = options['collar_type']!;
          if (options.containsKey('neck_style')) _neckStyle = options['neck_style']!;
          if (options.containsKey('kaf_style')) _kafStyle = options['kaf_style']!;
          if (options.containsKey('front_style')) _frontStyle = options['front_style']!;
          if (options.containsKey('pocket_type')) _pocketType = options['pocket_type']!;
          if (options.containsKey('shape')) _shape = options['shape']!;
          if (options.containsKey('shalwar_style')) _shalwarStyle = options['shalwar_style']!;
          if (options.containsKey('gala_type')) _galaType = options['gala_type']!;
          if (options.containsKey('aasteen_type')) _aasteenType = options['aasteen_type']!;
          if (options.containsKey('daman_type')) _damanType = options['daman_type']!;
        }

        if (data.containsKey('silaiOptions')) {
          final rawOpts = data['silaiOptions'] as List<dynamic>? ?? [];
          _silaiOptions = rawOpts.map((o) => Map<String, dynamic>.from(o as Map)).toList();
        }
        if (data.containsKey('customerWishes')) {
          final rawWishes = data['customerWishes'] as List<dynamic>? ?? [];
          _customerWishes = rawWishes.map((w) => Map<String, dynamic>.from(w as Map)).toList();
        }
        _silaiNotesCtrl.text = data['silaiNotes'] ?? '';
        _notesCtrl.text = data['notes'] ?? '';
        _isDraftLoaded = true;
        if (data.containsKey('updated_at') && data['updated_at'] != null) {
          _draftSavedAt = DateTime.tryParse(data['updated_at'] as String);
        }
        draftLoaded = true;
      } catch (e) {
        debugPrint('Error parsing draft data: $e. Falling back to saved measurements.');
      }
    }

    if (!draftLoaded) {
      // Load from saved measurements
      try {
        final existingMeasurements = ref.read(customerMeasurementsProvider).valueOrNull ?? [];
        final existing = existingMeasurements
            .where((m) => m.customerId == customerId)
            .firstOrNull;

        if (existing != null) {
          _selectedCategory = existing.category;
          for (final section in existing.sections) {
            if (section.title == 'Custom Fields') {
              for (final field in section.fields) {
                _customFieldsList.add(_CustomFieldData(
                  key: field.key,
                  label: field.label,
                  controller: TextEditingController(text: field.value),
                ));
              }
            } else if (section.title == 'Design Options') {
              for (final f in section.fields) {
                if (f.key == 'collar_type') _collarType = f.value;
                if (f.key == 'neck_style') _neckStyle = f.value;
                if (f.key == 'kaf_style') _kafStyle = f.value;
                if (f.key == 'front_style') _frontStyle = f.value;
                if (f.key == 'pocket_type') _pocketType = f.value;
                if (f.key == 'shape') _shape = f.value;
                if (f.key == 'shalwar_style') _shalwarStyle = f.value;
                if (f.key == 'gala_type') _galaType = f.value;
                if (f.key == 'aasteen_type') _aasteenType = f.value;
                if (f.key == 'daman_type') _damanType = f.value;
              }
            } else {
              for (final field in section.fields) {
                if (_controllers.containsKey(field.key)) {
                  _controllers[field.key]!.text = field.value;
                }
              }
            }
          }
          if (existing.silaiOptions != null) {
            _silaiOptions = existing.silaiOptions!.map((o) => Map<String, dynamic>.from(o)).toList();
          }
          _silaiNotesCtrl.text = existing.silaiNotes ?? '';
          _notesCtrl.text = existing.sections
              .expand((s) => s.fields)
              .where((f) => f.key == 'trouser_notes')
              .firstOrNull?.value ?? '';

          _isAutoFilled = true;
          _lastSavedAt = existing.updatedAt;
        } else {
          // Fallback to customer gender
          final customers = ref.read(customersProvider).valueOrNull ?? [];
          final c = customers.where((cu) => cu.id == customerId).firstOrNull;
          if (c != null) {
            _selectedCategory = c.gender == CustomerGender.female
                ? MeasurementCategory.women
                : MeasurementCategory.men;
          }
        }
      } catch (e) {
        debugPrint('Error loading saved measurements in _loadCustomerData: $e');
      }
    }

    _initialized = true;
  }

  Future<void> _saveMeasurements(String customerId, String customerName) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final List<MeasurementFieldModel> fields = [];
      final activeFields = categoryFields[_selectedCategory]!;
      for (final f in activeFields) {
        fields.add(MeasurementFieldModel(
          key: f.key,
          label: f.labelEng,
          unit: _isMetric ? 'cm' : 'in',
          value: _controllers[f.key]?.text ?? '',
        ));
      }

      final designFields = [
        if (_selectedCategory == MeasurementCategory.women) ...[
          MeasurementFieldModel(key: 'gala_type', label: 'Gala Type', unit: '', value: _galaType),
          MeasurementFieldModel(key: 'aasteen_type', label: 'Aasteen Type', unit: '', value: _aasteenType),
          MeasurementFieldModel(key: 'daman_type', label: 'Daman Type', unit: '', value: _damanType),
        ] else ...[
          MeasurementFieldModel(key: 'collar_type', label: 'Collar Type', unit: '', value: _collarType),
          MeasurementFieldModel(key: 'neck_style', label: 'Neck Style', unit: '', value: _neckStyle),
          MeasurementFieldModel(key: 'kaf_style', label: 'Kaf Style', unit: '', value: _kafStyle),
          MeasurementFieldModel(key: 'front_style', label: 'Front Style', unit: '', value: _frontStyle),
          MeasurementFieldModel(key: 'pocket_type', label: 'Pocket Type', unit: '', value: _pocketType),
          MeasurementFieldModel(key: 'shape', label: 'Shape', unit: '', value: _shape),
          MeasurementFieldModel(key: 'shalwar_style', label: 'Shalwar Style', unit: '', value: _shalwarStyle),
        ]
      ];

      final customFields = _customFieldsList.map((f) => MeasurementFieldModel(
        key: f.key,
        label: f.label,
        unit: _isMetric ? 'cm' : 'in',
        value: f.controller.text,
      )).toList();

      final updatedSections = [
        MeasurementSectionModel(title: 'Measurements', fields: fields),
        MeasurementSectionModel(title: 'Design Options', fields: designFields),
        if (customFields.isNotEmpty)
          MeasurementSectionModel(title: 'Custom Fields', fields: customFields),
      ];

      final existingMeasurements = ref.read(customerMeasurementsProvider).valueOrNull ?? [];
      final existing = existingMeasurements
          .where((m) => m.customerId == customerId)
          .firstOrNull;
      final measurementId = existing?.id ?? const Uuid().v4();

      final wishesText = _customerWishes
          .where((w) => w['checked'] == true)
          .map((w) => (w['label'] ?? w['urdu']).toString())
          .join(' ، ');

      final combinedNotes = [
        if (wishesText.isNotEmpty) 'پسند: $wishesText',
        if (_silaiNotesCtrl.text.trim().isNotEmpty) _silaiNotesCtrl.text.trim(),
      ].join('\n');

      final measurement = MeasurementModel(
        id: measurementId,
        customerId: customerId,
        title: 'Naap - ${_selectedCategory.label}',
        category: _selectedCategory,
        sections: updatedSections,
        updatedAt: DateTime.now(),
        silaiOptions: _silaiOptions,
        silaiNotes: combinedNotes,
      );

      await ref
          .read(measurementsProvider.notifier)
          .addOrUpdateMeasurement(measurement);

      // Clear draft on successful save
      final Box draftBox = Hive.box('naap_drafts_box');
      await draftBox.delete('draft_$customerId');
      if (mounted) {
        setState(() {
          _isDraftLoaded = false;
          _draftSavedAt = null;
          _isAutoFilled = true;
          _lastSavedAt = DateTime.now();
        });
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            dismissDirection: DismissDirection.horizontal,
            content: Row(
              children: [
                Expanded(
                  child: Text(
                    '💾 Measurements saved for $customerName!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                GestureDetector(
                  onTap: () => messenger.hideCurrentSnackBar(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10CBA0),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'New Order →',
              textColor: Colors.white,
              onPressed: () {
                messenger.hideCurrentSnackBar();
                final customers = ref.read(customersProvider).valueOrNull ?? [];
                final customer = customers.firstWhere(
                  (c) => c.id == customerId,
                  orElse: () => CustomerModel(
                    id: customerId,
                    name: customerName,
                    phone: '',
                    address: '',
                    gender: CustomerGender.male,
                    createdAt: DateTime.now(),
                  ),
                );
                NewOrderModal.show(context, preSelectedCustomer: customer);
              },
            ),
          ),
        );

        // Explicit 2.2s auto-close safety timer
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (mounted) {
            messenger.hideCurrentSnackBar();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving measurements: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFFFF3A58),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── ON CIRCLE TAP: SCROLL & FOCUS FIELD ─────────────────────────────────
  void _onCircleTap(int circleNum) {
    setState(() {
      _activeCircle = circleNum;
    });

    final fields = categoryFields[_selectedCategory]!;
    final field = fields.where((f) => f.circleNum == circleNum).firstOrNull;
    if (field != null) {
      final node = _focusNodes[field.key];
      if (node != null) {
        node.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerId = ref.watch(selectedMeasurementCustomerIdProvider);
    final customersAsync = ref.watch(customersProvider);
    final customerMeasurementsAsync = ref.watch(customerMeasurementsProvider);

    // Listen to customer ID changes to trigger data loading without being inside the build call stack
    ref.listen(selectedMeasurementCustomerIdProvider, (prev, next) {
      if (prev != next) {
        _initialized = false;
        _customFieldsList.clear();
        if (next != null && customerMeasurementsAsync.hasValue) {
          _loadCustomerData(next);
        }
      }
    });

    // If customer is set but data isn't loaded yet (e.g. measurements just loaded)
    if (customerId != null && !_initialized && customerMeasurementsAsync.hasValue) {
      _loadCustomerData(customerId);
    }

    // ── Customer Selector (Empty State) ──────────────────────────────────────
    if (customerId == null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);
      final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
      final text2 = isDark ? const Color(0xFF4A6080) : const Color(0xFF4A5568);

      return Scaffold(
        backgroundColor: bg,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Naap Card (Measurements)',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: text1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a client to add or edit their measurement card',
                style: GoogleFonts.inter(fontSize: 13, color: text2),
              ),
              const SizedBox(height: 16),
              _buildSearchContainer(),
              const SizedBox(height: 16),
              Expanded(
                child: customersAsync.when(
                  loading: () => const _CustomerListSkeleton(),
                  error: (err, _) => _CustomerListError(
                    message: err.toString(),
                    onRetry: () => ref.invalidate(customersProvider),
                  ),
                  data: (customers) {
                    final filtered = customers
                        .where(
                          (c) =>
                              c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              c.phone.contains(_searchQuery),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return _EmptyClientList(
                        onAdd: () {
                          AddCustomerModal.show(context);
                        },
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final c = filtered[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _loadCustomerData(c.id);
                              ref.read(selectedMeasurementCustomerIdProvider.notifier).state = c.id;
                            },
                            child: Row(
                              children: [
                                CustomerAvatar(name: c.name, size: 40, borderRadius: 10),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: text1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.phone,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          color: text2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  c.gender.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Measurement Form ──────────────────────────────────────────────────────
    final selectedCustomer = customersAsync.valueOrNull?.firstWhere(
      (c) => c.id == customerId,
      orElse: () => CustomerModel(
        id: customerId,
        name: widget.customerName ?? 'Client',
        phone: '',
        address: '',
        gender: CustomerGender.male,
        createdAt: DateTime.now(),
      ),
    );
    final customerOrders = ref.read(ordersProvider).valueOrNull
            ?.where((o) => o.customerId == customerId)
            .toList() ?? [];
    if (customerOrders.isNotEmpty) {
      customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    }
    final latestOrder = customerOrders.firstOrNull;
    final tokenBadge = latestOrder?.tokenNumber ?? 'T-XXXX';
    final statusBadge = latestOrder?.status.label ?? 'Pending';
    final dateFmt = DateFormat('dd Jun yyyy');
    final orderDateStr = latestOrder != null
        ? dateFmt.format(latestOrder.orderDate)
        : dateFmt.format(DateTime.now());
    final latestDeliveryDate = latestOrder?.deliveryDate;
    final deliveryDateStr = latestDeliveryDate != null
        ? dateFmt.format(latestDeliveryDate)
        : 'Not set';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Top Nav
          _buildTopNav(selectedCustomer),
          // Autosave draft status bar
          _buildDraftStatusBar(),
          // Main unified card layout
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gender tabs row
                  _buildGenderTabsRow(),
                  const SizedBox(height: 10),
                  // Unified Layout Card matching naap_card_v3.html
                  _buildUnifiedCard(
                    selectedCustomer,
                    tokenBadge,
                    statusBadge,
                    orderDateStr,
                    deliveryDateStr,
                    latestOrder,
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(customerId, selectedCustomer, latestOrder),
        ],
      ),
    );
  }

  Widget _buildTopNav(CustomerModel? customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final text2 = isDark ? const Color(0xFF3D5470) : const Color(0xFF5A6478);
    final switchBg = isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000);
    final switchBorder = isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000);
    final switchActiveColor = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final switchInactiveColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1525) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(selectedMeasurementCustomerIdProvider.notifier).state = null;
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                      border: Border.all(color: isDark ? const Color(0x21FFFFFF) : const Color(0x1A000000)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text('←', style: TextStyle(color: text2, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Measurements',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: text1,
                      ),
                    ),
                    Text(
                      '${customer?.name ?? "Client"} · ${customer?.phone ?? "No phone"}',
                      style: GoogleFonts.inter(fontSize: 10, color: text2),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: switchBg,
                border: Border.all(color: switchBorder),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    'Inches',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _isMetric ? switchInactiveColor : switchActiveColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isMetric = !_isMetric;
                      _convertValues(_isMetric);
                    }),
                    child: Container(
                      width: 28,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Align(
                        alignment: _isMetric ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CM',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _isMetric ? switchActiveColor : switchInactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftStatusBar() {
    if (!_isDraftLoaded && !_isAutoFilled) return const SizedBox.shrink();

    String message = '';
    if (_isSavingDraft) {
      message = 'Saving draft...';
    } else if (_isDraftLoaded && _draftSavedAt != null) {
      message = '⚡ Draft restored (unsaved changes) · Auto-saving as you type';
    } else if (_isAutoFilled && _lastSavedAt != null) {
      final dateStr = DateFormat('dd MMM yyyy').format(_lastSavedAt!);
      message = '⚡ Auto-filled from last visit · $dateStr · Auto-saving as you type';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: const Color(0x1F10CBA0),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Color(0xFF10CBA0), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF10CBA0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderTabsRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalBorder = isDark ? const Color(0x12FFFFFF) : const Color(0x1F000000);
    final normalBg = isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF4F6FA);
    final activeBg = isDark ? const Color(0x1FF5A623) : const Color(0xFFFFF8EE);
    final activeText = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final normalText = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    Widget buildTab(MeasurementCategory cat, String icon, String label) {
      final isSelected = _selectedCategory == cat;
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedCategory = cat;
            _activeCircle = null;
            _onFieldChanged();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : normalBg,
            border: Border.all(color: isSelected ? activeText.withValues(alpha: 0.35) : normalBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeText : normalText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTab(MeasurementCategory.men, '👔', 'Mard'),
        const SizedBox(width: 8),
        buildTab(MeasurementCategory.women, '👗', 'Aurat'),
        const SizedBox(width: 8),
        buildTab(MeasurementCategory.children, '👕', 'Bachche'),
      ],
    );
  }

  Widget _buildUnifiedCard(
    CustomerModel? customer,
    String token,
    String status,
    String orderDate,
    String deliveryDate,
    OrderModel? latestOrder,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0D1628) : Colors.white;
    final cardBorder = isDark ? const Color(0x12FFFFFF) : const Color(0x1F000000);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: cardBorder, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Row (Token, Shop name, Payment Summary)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 620,
                    child: _buildCardHeader(latestOrder, token),
                  ),
                );
              }
              return _buildCardHeader(latestOrder, token);
            },
          ),

          // 2. Gold line divider
          Container(
            height: 2.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB8860B), Color(0xFFF5C842), Color(0xFFB8860B)],
              ),
            ),
          ),

          // 3. Date Row (4 columns)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 620,
                    child: _buildCardDateRow(orderDate, deliveryDate, latestOrder, customer?.id),
                  ),
                );
              }
              return _buildCardDateRow(orderDate, deliveryDate, latestOrder, customer?.id);
            },
          ),

          // 4. Customer Row
          _buildCardCustomerRow(customer),

          // 5. Body Rows (3-column layout)
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 860;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Diagrams (150px)
                    Container(
                      width: 155,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000))),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: RepaintBoundary(
                        child: InteractiveDiagram(
                          category: _selectedCategory,
                          onCircleTap: _onCircleTap,
                          activeCircle: _activeCircle,
                        ),
                      ),
                    ),
                    // Column 2: Measurements Table (flex)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000))),
                        ),
                        child: _buildMeasurementsTable(),
                      ),
                    ),
                    // Column 3: Design options, Silai & Notes (220px)
                    Container(
                      width: 230,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      child: _buildDesignOptionsColumn(),
                    ),
                  ],
                );
              } else {
                // Mobile stacked layout
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: RepaintBoundary(
                        child: InteractiveDiagram(
                          category: _selectedCategory,
                          onCircleTap: _onCircleTap,
                          activeCircle: _activeCircle,
                        ),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    _buildMeasurementsTable(),
                    const Divider(height: 1, thickness: 1),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _buildDesignOptionsColumn(),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(OrderModel? order, String token) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000);
    final tokenColor = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final textMuted = isDark ? const Color(0xFF5A7090) : const Color(0xFF8B9BB8);

    final double totalAmount = order?.totalAmount ?? 0.0;
    final double paidAmount = order?.paidAmount ?? 0.0;
    final double remainingAmount = order?.remainingAmount ?? 0.0;

    return Row(
      children: [
        // Column 1: Token No.
        Container(
          width: 130,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: dividerColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOKEN NO.',
                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: tokenColor, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                token,
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: tokenColor),
              ),
            ],
          ),
        ),

        // Column 2: Shop details
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: dividerColor)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SaifurRahman Tailors',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '📍 Saddar, Peshawar  ·  📞 0300-1234567',
                  style: GoogleFonts.inter(fontSize: 9, color: textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),

        // Column 3: Payment Summary (Dark Header + White Body + Border)
        Container(
          width: 155,
          margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1B33) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0xFF0F172A),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                child: Text(
                  'PAYMENT SUMMARY',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Column(
                  children: [
                    _buildPaymentSummaryRow('Total Amount', totalAmount, isDark: isDark),
                    _buildPaymentSummaryRow('Advance', paidAmount, isDark: isDark),
                    _buildPaymentSummaryRow('Balance', remainingAmount, isRed: remainingAmount > 0, isDark: isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummaryRow(String label, double amount, {bool isRed = false, bool isDark = false}) {
    final textMuted = isDark ? const Color(0xFF8AA0B8) : const Color(0xFF475569);
    final textVal = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final redVal = isDark ? const Color(0xFFFF6B7D) : const Color(0xFFDC2626);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 8.5, color: textMuted, fontWeight: FontWeight.w500)),
          Text(
            formatMoney(amount),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isRed ? redVal : textVal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDateRow(String orderDate, String deliveryDate, OrderModel? order, String? customerId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000);
    final textMuted = isDark ? const Color(0xFF5A7090) : const Color(0xFF8B9BB8);
    final count = order?.items.fold<int>(0, (sum, i) => sum + i.quantity) ?? 1;
    final customerNo = customerId != null && customerId.length >= 8
        ? customerId.substring(0, 8).toUpperCase()
        : customerId?.toUpperCase() ?? '';

    Widget buildCol(String urduLabel, String engLabel, String val, {bool isRed = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: dividerColor)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$urduLabel ($engLabel)',
                style: GoogleFonts.inter(fontSize: 8.5, color: textMuted, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                val,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isRed ? const Color(0xFFFF6B7D) : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0AFFFFFF) : const Color(0x03000000),
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          buildCol('تاریخ درج بکنگ', 'Booking', orderDate),
          buildCol('تاریخ ڈیلیوری', 'Delivery', deliveryDate, isRed: true),
          buildCol('تعداد', 'Qty', '$count'),
          buildCol('Customer No.', 'No.', '#$customerNo'),
        ],
      ),
    );
  }

  Widget _buildCardCustomerRow(CustomerModel? customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? const Color(0xFF5A7090) : const Color(0xFF8B9BB8);
    final textStyleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: Color(0xFFB8860B), width: 2)),
        color: isDark ? const Color(0x05FFFFFF) : const Color(0x02000000),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('📱', style: TextStyle(color: textMuted, fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                customer?.phone ?? '',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: textStyleColor),
              ),
            ],
          ),
          Text(
            customer?.name ?? '',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: textStyleColor),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fields = categoryFields[_selectedCategory]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Table Header
        Container(
          color: isDark ? const Color(0xFF0F1B33) : AppColors.lightSurface2,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ناپ (Measurement)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.lightText1)),
              Text('سائز (Size)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.lightText1)),
            ],
          ),
        ),
        // Rows
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fields.length,
          itemBuilder: (context, index) {
            final f = fields[index];
            final nextNode = index + 1 < fields.length ? _focusNodes[fields[index + 1].key] : null;

            return Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0x05FFFFFF) : const Color(0x0D000000))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  // Numbered Badge
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: f.isExtra ? const Color(0xFF6B7280) : const Color(0xFFB8860B),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${f.circleNum}',
                      style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Urdu + Eng Labels
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.labelUrdu, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(f.labelEng, style: GoogleFonts.inter(fontSize: 7.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                  // Input Box
                  SizedBox(
                    width: 150,
                    child: _NaapField(
                      label: '',
                      labelUrdu: '',
                      controller: _controllers[f.key]!,
                      focusNode: _focusNodes[f.key],
                      unit: _isMetric ? 'cm' : 'in',
                      textInputAction: nextNode != null ? TextInputAction.next : TextInputAction.done,
                      onChanged: (val) => _onFieldChanged(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Custom Fields
        if (_customFieldsList.isNotEmpty) ...[
          Container(
            color: isDark ? const Color(0xFF0F1B33) : AppColors.lightSurface2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text('اضافی ناپ (Custom Fields)', style: GoogleFonts.inter(fontSize: 9.5, color: isDark ? Colors.white : AppColors.lightText1, fontWeight: FontWeight.bold)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _customFieldsList.length,
            itemBuilder: (context, index) {
              final f = _customFieldsList[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(f.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      width: 150,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _NaapField(
                            label: '',
                            labelUrdu: '',
                            controller: f.controller,
                            unit: _isMetric ? 'cm' : 'in',
                            onChanged: (val) => _onFieldChanged(),
                          ),
                          Positioned(
                            right: -2,
                            top: -4,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  f.controller.dispose();
                                  _customFieldsList.removeAt(index);
                                  _onFieldChanged();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Color(0x33FF3A58), shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, size: 8, color: Color(0xFFFF3A58)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // Add Custom Field target
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _showAddCustomFieldDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x1A10CBA0),
                    border: Border.all(color: const Color(0x4010CBA0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 12, color: Color(0xFF10CBA0)),
                      const SizedBox(width: 4),
                      Text(
                        'Add Field',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10CBA0)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesignOptionsColumn() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF8AA0B8) : const Color(0xFF4A5568);
    final sectionHeaderBg = isDark ? const Color(0xFF0F1B33) : AppColors.lightSurface2;
    final sectionHeaderText = isDark ? Colors.white : AppColors.lightText1;

    Widget buildSectionHeader(String urdu, String eng) => Container(
      color: sectionHeaderBg,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              eng,
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: labelColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(urdu, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: sectionHeaderText), textDirection: TextDirection.rtl),
        ],
      ),
    );

    Widget buildCheckItem(String urdu, String eng, bool checked, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: checked
                ? (isDark ? const Color(0x18F5A623) : const Color(0xFFFFFBF0))
                : Colors.transparent,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0x07FFFFFF) : const Color(0x0C000000))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: checked ? const Color(0xFFD97706) : Colors.transparent,
                        border: Border.all(
                          color: checked ? const Color(0xFFD97706) : (isDark ? const Color(0xFF3D5470) : const Color(0xFFCBD5E1)),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: checked
                          ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        eng,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                          color: checked
                              ? (isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706))
                              : labelColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                urdu,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: checked ? FontWeight.w700 : FontWeight.w400,
                  color: checked
                      ? (isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706))
                      : (isDark ? const Color(0xFF8AA0B8) : const Color(0xFF4A5568)),
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Column Header
        Container(
          color: sectionHeaderBg,
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          child: Text(
            'ڈیزائن و سلائی',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: sectionHeaderText),
          ),
        ),

        // ── Design options (accordions) ────────────────────────────────
        if (_selectedCategory == MeasurementCategory.women) ...[
          _buildAccordion('gala_type', 'گلا کی قسم', _galaType, ['Round', 'V-Neck', 'Boat Neck', 'High Neck'],
              (v) => setState(() { _galaType = v; _onFieldChanged(); })),
          _buildAccordion('aasteen_type', 'آستین کی قسم', _aasteenType, ['Full', 'Half', '3/4 Sleeve', 'Sleeveless'],
              (v) => setState(() { _aasteenType = v; _onFieldChanged(); })),
          _buildAccordion('daman_type', 'دامن کی قسم', _damanType, ['Straight', 'Gheradar', 'A-Line', 'Pencil'],
              (v) => setState(() { _damanType = v; _onFieldChanged(); })),
        ] else ...[
          _buildAccordion('collar', 'کالر', _collarType, ['Standard', 'Mandarin', 'Peshawari', 'Spread'],
              (v) => setState(() { _collarType = v; _onFieldChanged(); })),
          _buildAccordion('neck', 'گلا', _neckStyle, ['Round', 'Open', 'Closed'],
              (v) => setState(() { _neckStyle = v; _onFieldChanged(); })),
          _buildAccordion('kaf', 'کف', _kafStyle, ['Standard', 'Embroidery', 'Button', 'Double'],
              (v) => setState(() { _kafStyle = v; _onFieldChanged(); })),
          _buildAccordion('front', 'پٹی', _frontStyle, ['Standard', 'Embroidery', 'Covered', 'None'],
              (v) => setState(() { _frontStyle = v; _onFieldChanged(); })),
          _buildAccordion('pocket', 'جیب', _pocketType, ['Chest', 'Side', 'None'],
              (v) => setState(() { _pocketType = v; _onFieldChanged(); })),
          _buildAccordion('shape', 'شیپ', _shape, ['Straight', 'Fitting', 'Loose'],
              (v) => setState(() { _shape = v; _onFieldChanged(); })),
          _buildAccordion('shalwar', 'شلوار', _shalwarStyle, ['Straight', 'Churidar', 'Patiala', 'Peshawari'],
              (v) => setState(() { _shalwarStyle = v; _onFieldChanged(); })),
        ],

        const SizedBox(height: 6),

        // ── Customer Wishes ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000)),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildSectionHeader('گاہک کی پسند', 'Customer Wishes'),
              ..._customerWishes.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                return buildCheckItem(
                  opt['label'] as String,
                  opt['urdu'] as String,
                  opt['checked'] as bool,
                  () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _customerWishes[idx] = {...opt, 'checked': !(opt['checked'] as bool)};
                      _onFieldChanged();
                    });
                  },
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── Silai Options ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000)),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildSectionHeader('سلائی کی قسم', 'Stitch Type'),
              ..._silaiOptions.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                return buildCheckItem(
                  opt['label'] as String,
                  opt['urdu'] as String,
                  opt['checked'] as bool,
                  () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _silaiOptions[idx] = {...opt, 'checked': !(opt['checked'] as bool)};
                      _onFieldChanged();
                    });
                  },
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── Special Instructions ───────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000)),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildSectionHeader('خاص ہدایات', 'Special Instructions'),
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _silaiNotesCtrl,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 11),
                  onChanged: (v) => _onFieldChanged(),
                  decoration: InputDecoration(
                    hintText: 'یہاں لکھیں...',
                    hintStyle: GoogleFonts.inter(fontSize: 11, color: labelColor),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAccordion(
    String key,
    String urduTitle,
    String currentValue,
    List<String> options,
    Function(String) onSelect,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOpen = _accordionOpenMap[key] ?? false;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _accordionOpenMap[key] = !isOpen;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(urduTitle, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text(currentValue, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10CBA0))),
                      const SizedBox(width: 4),
                      Icon(
                        isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: options.map((opt) {
                  final isSelected = currentValue == opt;
                  return GestureDetector(
                    onTap: () => onSelect(opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0x29F5A623)
                            : (isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF4F6FA)),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFF5A623)
                              : (isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000)),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        opt,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? (isDark ? const Color(0xFFF5A623) : AppColors.lightAccent)
                              : (isDark ? null : AppColors.lightText2),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchContainer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchBg = isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF4F6FA);
    final searchBorder = isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000);
    final textStyleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final hintStyleColor = isDark ? const Color(0xFF2D4060) : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: searchBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: searchBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: _searchFocusNode,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.inter(fontSize: 13, color: textStyleColor),
              decoration: InputDecoration(
                hintText: 'Search clients by name or phone…',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: hintStyleColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomFieldDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0D1628) : Colors.white;
    final dialogBorder = isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000);
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final labelColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);
    final inputBg = isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF4F6FA);
    final inputBorder = isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000);
    final textStyleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final hintStyleColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);
    final cancelColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF4A5568);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dialogBorder),
        ),
        title: Text(
          'Add Custom Field',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FIELD NAME',
              style: GoogleFonts.inter(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                border: Border.all(color: inputBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 13, color: textStyleColor),
                decoration: InputDecoration(
                  hintText: 'e.g., Thigh Loose, Pocket...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: hintStyleColor),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cancelColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final label = nameCtrl.text.trim();
              if (label.isNotEmpty) {
                final key = 'custom_${label.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
                setState(() {
                  _customFieldsList.add(_CustomFieldData(
                    key: key,
                    label: label,
                    controller: TextEditingController(),
                  ));
                });
                _onFieldChanged();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5A623),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A0A00),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(String customerId, CustomerModel? customer, OrderModel? latestOrder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final footerBg = isDark ? const Color(0xFF0B1228) : const Color(0xFFFFFFFF);
    final footerBorder = isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: footerBg,
        border: Border(top: BorderSide(color: footerBorder)),
      ),
      child: Row(
        children: [
          // Teal Add to Order
          _TealFooterButton(
            label: '＋ Add to Order',
            onPressed: () {
              NewOrderModal.show(context, preSelectedCustomer: customer);
            },
          ),
          const SizedBox(width: 8),

          // Print Naap Card Outline
          Builder(
            builder: (context) {
              final shopPlan = ref.watch(shopPlanProvider).value;
              final isLocked = shopPlan == 'mobile_only';
              return _PrintLockedButton(
                label: '🖨 Print Naap Card',
                isLocked: isLocked,
                onUnlocked: () async {
                    HapticFeedback.lightImpact();
                    setState(() => _isPrinting = true);
                    try {
                // Mock order if no latest order
                final dummyOrder = OrderModel(
                  id: '',
                  customerId: customerId,
                  customerName: customer?.name ?? 'Client',
                  tokenNumber: 'NEW',
                  orderNumber: 0,
                  orderDate: DateTime.now(),
                  deliveryDate: null,
                  status: OrderStatus.pending,
                  totalAmount: 0.0,
                  items: [],
                  payments: [],
                );

                // Gather current measurements & options values to show in print preview instantly
                final List<MeasurementFieldModel> fields = [];
                final activeFields = categoryFields[_selectedCategory]!;
                for (final f in activeFields) {
                  fields.add(MeasurementFieldModel(
                    key: f.key,
                    label: f.labelEng,
                    unit: _isMetric ? 'cm' : 'in',
                    value: _controllers[f.key]?.text ?? '',
                  ));
                }

                final designFields = [
                  if (_selectedCategory == MeasurementCategory.women) ...[
                    MeasurementFieldModel(key: 'gala_type', label: 'Gala Type', unit: '', value: _galaType),
                    MeasurementFieldModel(key: 'aasteen_type', label: 'Aasteen Type', unit: '', value: _aasteenType),
                    MeasurementFieldModel(key: 'daman_type', label: 'Daman Type', unit: '', value: _damanType),
                  ] else ...[
                    MeasurementFieldModel(key: 'collar_type', label: 'Collar Type', unit: '', value: _collarType),
                    MeasurementFieldModel(key: 'neck_style', label: 'Neck Style', unit: '', value: _neckStyle),
                    MeasurementFieldModel(key: 'kaf_style', label: 'Kaf Style', unit: '', value: _kafStyle),
                    MeasurementFieldModel(key: 'front_style', label: 'Front Style', unit: '', value: _frontStyle),
                    MeasurementFieldModel(key: 'pocket_type', label: 'Pocket Type', unit: '', value: _pocketType),
                    MeasurementFieldModel(key: 'shape', label: 'Shape', unit: '', value: _shape),
                    MeasurementFieldModel(key: 'shalwar_style', label: 'Shalwar Style', unit: '', value: _shalwarStyle),
                  ]
                ];

                final customFields = _customFieldsList.map((f) => MeasurementFieldModel(
                  key: f.key,
                  label: f.label,
                  unit: _isMetric ? 'cm' : 'in',
                  value: f.controller.text,
                )).toList();

                final updatedSections = [
                  MeasurementSectionModel(title: 'Measurements', fields: fields),
                  MeasurementSectionModel(title: 'Design Options', fields: designFields),
                  if (customFields.isNotEmpty)
                    MeasurementSectionModel(title: 'Custom Fields', fields: customFields),
                ];

                final wishesText = _customerWishes
                    .where((w) => w['checked'] == true)
                    .map((w) => (w['label'] ?? w['urdu']).toString())
                    .join(' ، ');

                final combinedNotes = [
                  if (wishesText.isNotEmpty) 'پسند: $wishesText',
                  if (_silaiNotesCtrl.text.trim().isNotEmpty) _silaiNotesCtrl.text.trim(),
                ].join('\n');

                final measurement = MeasurementModel(
                  id: '',
                  customerId: customerId,
                  title: 'Naap - ${_selectedCategory.label}',
                  category: _selectedCategory,
                  sections: updatedSections,
                  updatedAt: DateTime.now(),
                  silaiOptions: _silaiOptions,
                  silaiNotes: combinedNotes,
                );

                final cardWidget = NaapCardWidget(
                  order: latestOrder ?? dummyOrder,
                  customer: customer,
                  measurement: measurement,
                );

                final pngBytes = await CardImageCapturer.captureOnDemand(
                  context,
                  cardWidget: cardWidget,
                );

                if (!context.mounted) return;
                Navigator.push(
                  context,
                    MaterialPageRoute(
                      builder: (context) => _NaapPrintPreviewPage(
                        customer: customer,
                        order: latestOrder ?? dummyOrder,
                        cardPng: pngBytes,
                      ),
                    ),
                  );
              } catch (e) {
                debugPrint('_MeasurementsScreenState: print capture failed — $e');
              } finally {
                if (mounted) setState(() => _isPrinting = false);
              }
            },
          );
        },
      ),
          const SizedBox(width: 8),

          // Gold Save Measurements
          Expanded(
            flex: 2,
            child: _GoldFooterButton(
              label: '💾 Save Measurements',
              isLoading: _isSaving,
              onPressed: () => _saveMeasurements(customerId, customer?.name ?? 'Client'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PREMIUM NAAP FIELD WIDGET ─────────────────────────────────────────────
class _NaapField extends StatefulWidget {
  final String label;
  final String labelUrdu;
  final TextEditingController controller;
  final String unit;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;

  const _NaapField({
    required this.label,
    required this.labelUrdu,
    required this.controller,
    required this.unit,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
  });

  @override
  State<_NaapField> createState() => _NaapFieldState();
}

class _NaapFieldState extends State<_NaapField> with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _focused = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 6.0), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final validRegex = RegExp(r'^[0-9.\u00BD\u00BC\u00BE\s]*$');
    if (!validRegex.hasMatch(value)) {
      _shakeCtrl.forward(from: 0.0);
      setState(() {
        _hasError = true;
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _hasError = false);
      });
      final clean = value.replaceAll(RegExp(r'[^0-9.\u00BD\u00BC\u00BE\s]'), '');
      widget.controller.text = clean;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: clean.length),
      );
    } else {
      if (widget.onChanged != null) widget.onChanged!(value);
    }
  }

  Widget _buildFractionBtn(String frac) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    final btnText = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final currentText = widget.controller.text;
        final cleanText = currentText.replaceAll(RegExp(r'[\u00BD\u00BC\u00BE]'), '').trim();
        final newText = cleanText.isEmpty ? frac : '$cleanText$frac';
        widget.controller.text = newText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
        _onChanged(newText);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          frac,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: btnText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);
    final urduColor = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final fieldBg = isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF4F6FA);
    final fieldBorderColor = _hasError
        ? const Color(0xFFFF3A58)
        : (isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000));
    final focusedBorderColor = _hasError
        ? const Color(0xFFFF3A58)
        : (isDark ? const Color(0x66F5A623) : const Color(0x66D97706));
    final textColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final unitColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label.isNotEmpty || widget.labelUrdu.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: labelColor,
                  ),
                ),
                Text(
                  widget.labelUrdu,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: urduColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 34,
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _focused ? focusedBorderColor : fieldBorderColor,
                width: 1.5,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: _hasError
                            ? const Color(0x14FF3A58)
                            : (isDark ? const Color(0x14F5A623) : const Color(0x14D97706)),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    textInputAction: widget.textInputAction,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: _onChanged,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(left: 10, bottom: 12),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFractionBtn('½'),
                    const SizedBox(width: 3),
                    _buildFractionBtn('¼'),
                    const SizedBox(width: 3),
                    _buildFractionBtn('¾'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 6),
                  child: Text(
                    widget.unit,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: unitColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── CUSTOMER LIST SKELETON ────────────────────────────────────────────────
class _CustomerListSkeleton extends StatelessWidget {
  const _CustomerListSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0x05FFFFFF) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x0DFFFFFF) : const Color(0x1A000000);

    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, idx) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: cardBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: const [
              PulsingSkeleton(width: 40, height: 40, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulsingSkeleton(width: 120, height: 14),
                    SizedBox(height: 6),
                    PulsingSkeleton(width: 80, height: 10),
                  ],
                ),
              ),
              PulsingSkeleton(width: 20, height: 20, borderRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CUSTOMER LIST ERROR WIDGET ────────────────────────────────────────────
class _CustomerListError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _CustomerListError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final msgColor = isDark ? const Color(0xFF4A6080) : const Color(0xFF4A5568);
    final iconColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: iconColor),
            const SizedBox(height: 16),
            Text(
              'Could not load clients',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(fontSize: 12, color: msgColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _GoldFooterButton(
              label: 'Try Again',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── EMPTY CLIENTS STATE WIDGET ────────────────────────────────────────────
class _EmptyClientList extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyClientList({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final msgColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF4A5568);
    final iconColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_disabled_outlined, size: 40, color: iconColor),
            const SizedBox(height: 12),
            Text(
              'No clients yet',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your first client to start measuring',
              style: GoogleFonts.inter(fontSize: 11, color: msgColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _TealFooterButton(
              label: '＋ Add Client',
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM FOOTER BUTTONS ──────────────────────────────────────────────────
class _TealFooterButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _TealFooterButton({required this.label, required this.onPressed});

  @override
  State<_TealFooterButton> createState() => _TealFooterButtonState();
}

class _TealFooterButtonState extends State<_TealFooterButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x1A10CBA0),
            border: Border.all(color: const Color(0x4010CBA0), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF10CBA0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineFooterButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _OutlineFooterButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  @override
  State<_OutlineFooterButton> createState() => _OutlineFooterButtonState();
}

class _OutlineFooterButtonState extends State<_OutlineFooterButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000);
    final btnBorder = isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000);
    final btnText = isDark ? const Color(0xFF8AA0B8) : const Color(0xFF4A5568);
    final bool disabled = widget.isLoading || widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: disabled ? null : (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onPressed?.call();
      },
      onTapCancel: disabled ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: btnBg,
            border: Border.all(color: btnBorder, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(btnText),
                    ),
                  )
                : Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: btnText,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GoldFooterButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoldFooterButton({
    required this.label,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  State<_GoldFooterButton> createState() => _GoldFooterButtonState();
}

class _GoldFooterButtonState extends State<_GoldFooterButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.isLoading || widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: disabled ? null : (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onPressed?.call();
      },
      onTapCancel: disabled ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: disabled
                  ? [const Color(0xFFB8860B), const Color(0xFF8B5A2B)]
                  : [const Color(0xFFF5A623), const Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59F5A623),
                blurRadius: 20,
                offset: Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A0A00)),
                    ),
                  )
                : Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A0A00),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CustomFieldData {
  final String key;
  final String label;
  final TextEditingController controller;

  _CustomFieldData({
    required this.key,
    required this.label,
    required this.controller,
  });
}

// ── PRINT PREVIEW SUBPAGE ────────────────────────────────────────────────
class _NaapPrintPreviewPage extends ConsumerStatefulWidget {
  final CustomerModel? customer;
  final OrderModel order;
  final Uint8List cardPng;

  const _NaapPrintPreviewPage({
    required this.customer,
    required this.order,
    required this.cardPng,
  });

  @override
  ConsumerState<_NaapPrintPreviewPage> createState() => _NaapPrintPreviewPageState();
}

class _NaapPrintPreviewPageState extends ConsumerState<_NaapPrintPreviewPage> {
  bool _isPrinting = false;
  bool _isDownloading = false;
  bool _isSharing = false;
  Uint8List? _cachedPdfBytes;

  bool get _isAnyBusy => _isPrinting || _isDownloading || _isSharing;

  Future<Uint8List> _buildPdf() async {
    if (_cachedPdfBytes != null) return _cachedPdfBytes!;
    final pdfBytes = await DarziPdfBuilder.buildPdfFromImageBytes(
      widget.cardPng,
      pageFormat: PdfPageFormat.a5,
    );
    _cachedPdfBytes = Uint8List.fromList(pdfBytes);
    return _cachedPdfBytes!;
  }

  Future<void> _handlePrint() async {
    if (_isAnyBusy) return;
    setState(() => _isPrinting = true);
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      debugPrint('_NaapPrintPreviewPage: print failed — $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleDownload() async {
    if (_isAnyBusy) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await _buildPdf();
      if (!mounted) return;
      await DarziShareHelper.savePdfToDownloads(
        context,
        pdfBytes: bytes,
        fileName: 'Naap_${widget.customer?.name ?? 'Client'}.pdf',
      );
    } catch (e) {
      debugPrint('_NaapPrintPreviewPage: download failed — $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleShare() async {
    if (_isAnyBusy) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _buildPdf();
      if (!mounted) return;
      await DarziShareHelper.shareOrSavePdf(
        context,
        pdfBytes: bytes,
        fileName: 'Naap_${widget.customer?.name ?? 'Client'}.pdf',
        text: '📋 Darzi Pro — Naap Card: ${widget.customer?.name ?? 'Client'}',
      );
    } catch (e) {
      debugPrint('_NaapPrintPreviewPage: share failed — $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = ref.watch(localeProvider) == 'ur';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);
    final appBarBg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final leadingIconColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: leadingIconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Naap Card Print Preview',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 3.0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        widget.cardPng,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: isDark ? const Color(0xFF0F1B33) : const Color(0xFFF1F5F9),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: _NaapActionButton(
                    label: isUrdu ? 'پرنٹ' : 'Print',
                    icon: Icons.print_rounded,
                    color: const Color(0xFFD97706),
                    isLoading: _isPrinting,
                    onPressed: _isAnyBusy ? null : _handlePrint,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NaapActionButton(
                    label: isUrdu ? 'ڈاؤن لوڈ' : 'Download',
                    icon: Icons.download_rounded,
                    color: const Color(0xFF2563EB),
                    isLoading: _isDownloading,
                    onPressed: _isAnyBusy ? null : _handleDownload,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NaapActionButton(
                    label: isUrdu ? 'شیئر' : 'Share',
                    icon: Icons.share_rounded,
                    color: const Color(0xFF475569),
                    isLoading: _isSharing,
                    onPressed: _isAnyBusy ? null : _handleShare,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NaapActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _NaapActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  State<_NaapActionButton> createState() => _NaapActionButtonState();
}

class _NaapActionButtonState extends State<_NaapActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.isLoading || widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: disabled ? null : (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onPressed?.call();
      },
      onTapCancel: disabled ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: disabled ? widget.color.withValues(alpha: 0.5) : widget.color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, size: 15, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PrintLockedButton extends StatelessWidget {
  final String label;
  final VoidCallback onUnlocked;
  final bool isLocked;
  
  const _PrintLockedButton({required this.label, required this.onUnlocked, required this.isLocked});
  
  @override
  Widget build(BuildContext context) {
    if (!isLocked) {
      // Show original button - call onUnlocked
      return ElevatedButton.icon(
        onPressed: onUnlocked,
        icon: const Icon(Icons.print_rounded),
        label: Text(label),
      );
    }
    return Stack(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showUpgradeDialog(context),
          icon: const Icon(Icons.lock_rounded, color: Colors.grey),
          label: Text(label, style: const TextStyle(color: Colors.grey)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            foregroundColor: Colors.grey,
          ),
        ),
      ],
    );
  }
  
  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [Icon(Icons.lock_rounded, color: Color(0xFFF5A623)), SizedBox(width: 8), Text('Print Locked')]),
        content: const Text('Print feature is available on the Full Access plan.\n\nUpgrade for Rs 23,000 to unlock printing.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); context.go('/upgrade-plan'); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5A623), foregroundColor: Colors.black),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
}
