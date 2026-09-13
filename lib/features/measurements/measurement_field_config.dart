import 'package:flutter/material.dart';

// ── 15 STANDARD MEASUREMENT FIELDS DEFINITION ─────────────────────────────
class MeasurementFieldConfig {
  final String key;
  final String nameUrdu;
  final String nameEng;

  const MeasurementFieldConfig({
    required this.key,
    required this.nameUrdu,
    required this.nameEng,
  });
}

const List<MeasurementFieldConfig> k15MeasurementFields = [
  MeasurementFieldConfig(key: 'lambai', nameUrdu: 'لمبائی', nameEng: 'Length'),
  MeasurementFieldConfig(key: 'teerwa', nameUrdu: 'تیرو', nameEng: 'Shoulder'),
  MeasurementFieldConfig(key: 'bazo', nameUrdu: 'بازو', nameEng: 'Sleeve'),
  MeasurementFieldConfig(key: 'chaati', nameUrdu: 'چھاتی', nameEng: 'Chest'),
  MeasurementFieldConfig(key: 'baghal', nameUrdu: 'بغل / کمول', nameEng: 'Arm Hole'),
  MeasurementFieldConfig(key: 'kamar', nameUrdu: 'کمر', nameEng: 'Waist'),
  MeasurementFieldConfig(key: 'daman', nameUrdu: 'دامن', nameEng: 'Hem'),
  MeasurementFieldConfig(key: 'collar', nameUrdu: 'کالر / گلا', nameEng: 'Collar'),
  MeasurementFieldConfig(key: 'shalwar', nameUrdu: 'شلوار لمبائی', nameEng: 'Trouser Length'),
  MeasurementFieldConfig(key: 'panche', nameUrdu: 'پانچے', nameEng: 'Bottom'),
  MeasurementFieldConfig(key: 'kaf', nameUrdu: 'کف', nameEng: 'Cuff'),
  MeasurementFieldConfig(key: 'jeb', nameUrdu: 'جیب / پٹی', nameEng: 'Pocket'),
  MeasurementFieldConfig(key: 'gol', nameUrdu: 'گول / ہپ', nameEng: 'Gol / Hip'),
  MeasurementFieldConfig(key: 'asan', nameUrdu: 'آسن', nameEng: 'Asan'),
  MeasurementFieldConfig(key: 'gareban', nameUrdu: 'گریبان', nameEng: 'Gareban'),
];

// ── VECTOR SHAPE PAINTER FOR BODY PART ICONS ──────────────────────────────
class MeasurementShapePainter extends CustomPainter {
  final String keyName;
  final Color color;

  const MeasurementShapePainter({
    required this.keyName,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (keyName) {
      case 'lambai':
        _scale(canvas, size, 24, 20);
        canvas.drawRect(const Rect.fromLTWH(2, 2, 20, 16), strokePaint);
        for (double x = 2; x < 22; x += 4) {
          canvas.drawLine(Offset(x, 10), Offset((x + 2).clamp(2, 22), 10), strokePaint);
        }
        break;

      case 'teerwa':
        _scale(canvas, size, 28, 16);
        final p = Path()
          ..moveTo(2, 8)
          ..lineTo(8, 2)
          ..lineTo(20, 2)
          ..lineTo(26, 8);
        canvas.drawPath(p, strokePaint);
        break;

      case 'bazo':
        _scale(canvas, size, 24, 22);
        final p = Path()
          ..moveTo(4, 18)
          ..lineTo(10, 2)
          ..lineTo(20, 2)
          ..lineTo(22, 18)
          ..close();
        canvas.drawPath(p, strokePaint);
        break;

      case 'chaati':
        _scale(canvas, size, 26, 20);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(13, 10), width: 20, height: 14),
          strokePaint,
        );
        break;

      case 'baghal':
        _scale(canvas, size, 22, 22);
        canvas.drawCircle(const Offset(11, 11), 8, strokePaint);
        break;

      case 'kamar':
        _scale(canvas, size, 22, 22);
        const rect = Rect.fromLTWH(3, 3, 16, 16);
        for (int i = 0; i < 8; i++) {
          final startAngle = (i * 45) * 3.14159 / 180;
          const sweepAngle = 26 * 3.14159 / 180;
          canvas.drawArc(rect, startAngle, sweepAngle, false, strokePaint);
        }
        break;

      case 'daman':
        _scale(canvas, size, 28, 14);
        final p = Path()
          ..moveTo(2, 2)
          ..lineTo(26, 2)
          ..lineTo(24, 12)
          ..lineTo(4, 12)
          ..close();
        canvas.drawPath(p, strokePaint);
        break;

      case 'collar':
        _scale(canvas, size, 28, 16);
        final p = Path()
          ..moveTo(2, 12)
          ..quadraticBezierTo(14, 2, 26, 12);
        canvas.drawPath(p, strokePaint);
        break;

      case 'shalwar':
        _scale(canvas, size, 24, 22);
        final p = Path()
          ..moveTo(4, 2)
          ..lineTo(20, 2)
          ..lineTo(20, 12)
          ..quadraticBezierTo(20, 16, 16, 18)
          ..lineTo(8, 18)
          ..quadraticBezierTo(4, 16, 4, 12)
          ..close();
        canvas.drawPath(p, strokePaint);
        break;

      case 'panche':
        _scale(canvas, size, 26, 14);
        final p = Path()
          ..moveTo(2, 4)
          ..lineTo(24, 4)
          ..lineTo(22, 12)
          ..lineTo(4, 12)
          ..close();
        canvas.drawPath(p, strokePaint);
        break;

      case 'kaf':
        _scale(canvas, size, 26, 16);
        canvas.drawRect(const Rect.fromLTWH(2, 3, 22, 10), strokePaint);
        break;

      case 'jeb':
        _scale(canvas, size, 22, 22);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(3, 3, 16, 16), const Radius.circular(2)),
          strokePaint,
        );
        canvas.drawCircle(const Offset(6, 6), 1.5, fillPaint);
        break;

      case 'gol':
        _scale(canvas, size, 26, 18);
        final p = Path()
          ..moveTo(2, 16)
          ..quadraticBezierTo(13, 2, 24, 16);
        canvas.drawPath(p, strokePaint);
        break;

      case 'asan':
        _scale(canvas, size, 26, 18);
        final p = Path()
          ..moveTo(4, 4)
          ..lineTo(22, 4)
          ..lineTo(22, 10)
          ..quadraticBezierTo(22, 16, 13, 16)
          ..quadraticBezierTo(4, 16, 4, 10)
          ..close();
        canvas.drawPath(p, strokePaint);
        break;

      case 'gareban':
        _scale(canvas, size, 22, 22);
        final p = Path()
          ..moveTo(4, 20)
          ..lineTo(4, 10)
          ..quadraticBezierTo(4, 2, 11, 2)
          ..quadraticBezierTo(18, 2, 18, 10)
          ..lineTo(18, 20)
          ..close();
        canvas.drawPath(p, strokePaint);
        break;

      default:
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.35, strokePaint);
        break;
    }
  }

  void _scale(Canvas canvas, Size size, double refW, double refH) {
    canvas.scale(size.width / refW, size.height / refH);
  }

  @override
  bool shouldRepaint(covariant MeasurementShapePainter oldDelegate) {
    return oldDelegate.keyName != keyName || oldDelegate.color != color;
  }
}
