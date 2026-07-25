import 'package:flutter/material.dart';

// ================= 🎨 ACCURATE CHARACTER VECTOR PAINTER =================
class AccurateAnimeCharacterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shirtPaint = Paint()
      ..color = const Color(0xFF558B2F)
      ..style = PaintingStyle.fill;
    final collarPaint = Paint()
      ..color = const Color(0xFF33691E)
      ..style = PaintingStyle.fill;
    final skinPaint = Paint()
      ..color = const Color(0xFFFCD4B0)
      ..style = PaintingStyle.fill;
    final hairPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..style = PaintingStyle.fill;
    final faceDetailPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final tabletPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..style = PaintingStyle.fill;
    final leafPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.4),
      4,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.2),
      5,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.3),
      4,
      leafPaint,
    );

    var torsoPath = Path()
      ..moveTo(size.width * 0.15, size.height)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.55,
        size.width * 0.5,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.55,
        size.width * 0.85,
        size.height,
      )
      ..close();
    canvas.drawPath(torsoPath, shirtPaint);

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.43,
        size.height * 0.44,
        size.width * 0.14,
        size.height * 0.12,
      ),
      skinPaint,
    );

    var collarPath = Path()
      ..moveTo(size.width * 0.38, size.height * 0.55)
      ..lineTo(size.width * 0.5, size.height * 0.65)
      ..lineTo(size.width * 0.62, size.height * 0.55)
      ..close();
    canvas.drawPath(collarPath, collarPaint);

    Rect faceRect = Rect.fromLTWH(
      size.width * 0.34,
      size.height * 0.20,
      size.width * 0.32,
      size.height * 0.32,
    );
    canvas.drawOval(faceRect, skinPaint);

    canvas.drawLine(
      Offset(size.width * 0.44, size.height * 0.34),
      Offset(size.width * 0.46, size.height * 0.34),
      faceDetailPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.54, size.height * 0.34),
      Offset(size.width * 0.56, size.height * 0.34),
      faceDetailPaint,
    );

    var smilePath = Path()
      ..moveTo(size.width * 0.46, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.46,
        size.width * 0.54,
        size.height * 0.42,
      );
    canvas.drawPath(smilePath, faceDetailPaint);

    var hairPath = Path()
      ..moveTo(size.width * 0.32, size.height * 0.26)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.08,
        size.width * 0.68,
        size.height * 0.26,
      )
      ..lineTo(size.width * 0.66, size.height * 0.20)
      ..lineTo(size.width * 0.58, size.height * 0.22)
      ..lineTo(size.width * 0.50, size.height * 0.16)
      ..lineTo(size.width * 0.44, size.height * 0.22)
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    Rect greyTablet = Rect.fromLTWH(
      size.width * 0.38,
      size.height * 0.66,
      size.width * 0.24,
      size.height * 0.18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(greyTablet, const Radius.circular(5)),
      tabletPaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.74),
      6,
      skinPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.74),
      6,
      skinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= 📊 THICK DONUT CHART PAINTER =================
class ThickDonutChartPainter extends CustomPainter {
  final List<dynamic> data;
  ThickDonutChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32
      ..strokeCap = StrokeCap.butt;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;

    if (data.isEmpty) {
      paint.color = Colors.grey.shade200;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // Map data to colors
    Map<String, double> values = {};
    double total = 0;
    for (var item in data) {
      String method = item['payment_method'].toString().toLowerCase();
      double count = double.tryParse(item['count'].toString()) ?? 0;
      values[method] = count;
      total += count;
    }

    if (total == 0) return;

    double startAngle = -1.57;
    final Map<String, Color> colors = {
      'gcash': const Color(0xFF4DB6AC),
      'cash': const Color(0xFF81C784),
      'maya': const Color(0xFFFFB74D),
      'card': const Color(0xFF64B5F6),
    };

    colors.forEach((method, color) {
      double value = values[method] ?? 0;
      if (value > 0) {
        double sweepAngle = (value / total) * 6.28;
        paint.color = color;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
        startAngle += sweepAngle;
      }
    });
  }

  @override
  bool shouldRepaint(covariant ThickDonutChartPainter oldDelegate) => oldDelegate.data != data;
}

class AdvancedBarChartPainter extends CustomPainter {
  final List<dynamic> data;
  AdvancedBarChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final barPaint = Paint()..style = PaintingStyle.fill;

    // Use actual data or empty bars if no data
    List<double> values = List.filled(12, 0.0);
    List<String> labels = List.filled(12, '');

    if (data.isNotEmpty) {
      // Find max for scaling
      double maxVal = 0;
      for (var item in data) {
        double total = double.tryParse(item['total'].toString()) ?? 0;
        if (total > maxVal) maxVal = total;
      }
      
      // Map to 12 slots (e.g., last 12 hours)
      // For simplicity, let's just use what's in 'data' up to 12
      for (int i = 0; i < data.length && i < 12; i++) {
        double total = double.tryParse(data[i]['total'].toString()) ?? 0;
        values[i] = maxVal > 0 ? total / maxVal : 0;
        labels[i] = "${data[i]['h']}:00";
      }
    } else {
      // Placeholder dummy values if no sales today yet
      values = [0.1, 0.15, 0.1, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1];
    }

    // Ibaba ng bahagya ang taas ng chart para sa grid alignment
    double chartHeight = size.height - 20;

    // Gumuhit ng grid lines
    for (int i = 0; i <= 5; i++) {
      double y = (chartHeight / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Dynamic width calculation base sa lapad ng gadget screen
    double widthSpace = size.width / 12;
    double barWidth = widthSpace * 0.6;

    for (int i = 0; i < 12; i++) {
      barPaint.color = const Color(0xFF48BB78);

      double barHeight = chartHeight * values[i];
      if (barHeight < 2) barHeight = 2; // Minimal visible bar
      
      double barX = (i * widthSpace) + (widthSpace - barWidth) / 2;

      Rect rect = Rect.fromLTWH(
        barX,
        chartHeight - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        barPaint,
      );

      // Labels every 2 hours if data exists
      if (labels[i].isNotEmpty && i % 2 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Colors.grey, fontSize: 8),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(barX, size.height - 10));
      }
    }
  }

  @override
  bool shouldRepaint(covariant AdvancedBarChartPainter oldDelegate) => oldDelegate.data != data;
}
