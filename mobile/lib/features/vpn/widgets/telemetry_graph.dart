import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TelemetryGraph extends StatelessWidget {
  final List<double> rxHistory;
  final List<double> txHistory;
  final double height;

  const TelemetryGraph({
    super.key,
    required this.rxHistory,
    required this.txHistory,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _ThroughputChartPainter(
            rxData: rxHistory,
            txData: txHistory,
          ),
        ),
      ),
    );
  }
}

class _ThroughputChartPainter extends CustomPainter {
  final List<double> rxData;
  final List<double> txData;

  _ThroughputChartPainter({required this.rxData, required this.txData});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw subtle background grid lines
    final gridPaint = Paint()
      ..color = AppTheme.surfaceLight.withOpacity(0.2)
      ..strokeWidth = 1.0;

    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (rxData.isEmpty && txData.isEmpty) return;

    // 2. Find max value for dynamic scaling
    double maxSpeed = 1024 * 100; // minimum scale 100 KB/s
    for (final v in rxData) {
      if (v > maxSpeed) maxSpeed = v;
    }
    for (final v in txData) {
      if (v > maxSpeed) maxSpeed = v;
    }

    // 3. Draw Download (Rx) curve with Cyan glow
    _drawMetricCurve(
      canvas: canvas,
      size: size,
      data: rxData,
      maxVal: maxSpeed,
      strokeColor: AppTheme.primary,
      fillColor: AppTheme.primary.withOpacity(0.15),
    );

    // 4. Draw Upload (Tx) curve with Accent glow
    _drawMetricCurve(
      canvas: canvas,
      size: size,
      data: txData,
      maxVal: maxSpeed,
      strokeColor: AppTheme.accent,
      fillColor: AppTheme.accent.withOpacity(0.12),
    );
  }

  void _drawMetricCurve({
    required Canvas canvas,
    required Size size,
    required List<double> data,
    required double maxVal,
    required Color strokeColor,
    required Color fillColor,
  }) {
    if (data.length < 2) return;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (math.max(data.length - 1, 1));

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalized = (data[i] / maxVal).clamp(0.0, 1.0);
      final y = size.height - (normalized * (size.height - 4)) - 2;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevNormalized = (data[i - 1] / maxVal).clamp(0.0, 1.0);
        final prevY = size.height - (prevNormalized * (size.height - 4)) - 2;

        final controlX1 = prevX + (x - prevX) / 2;
        final controlY1 = prevY;
        final controlX2 = prevX + (x - prevX) / 2;
        final controlY2 = y;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, fillColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Draw stroke
    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ThroughputChartPainter oldDelegate) {
    return true;
  }
}
