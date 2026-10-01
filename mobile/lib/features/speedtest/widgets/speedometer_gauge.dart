import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/speed_test_service.dart';

class SpeedometerGauge extends StatelessWidget {
  final double speedMbps;
  final double maxSpeed;
  final SpeedTestStage stage;

  const SpeedometerGauge({
    super.key,
    required this.speedMbps,
    this.maxSpeed = 100.0,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(260, 260),
            painter: _SpeedometerPainter(
              speed: speedMbps,
              maxSpeed: maxSpeed,
              stage: stage,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speedMbps.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
              ),
              const Text(
                'Mbps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStageColor().withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStageColor().withOpacity(0.4)),
                ),
                child: Text(
                  _getStageLabel(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getStageColor(),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStageColor() {
    switch (stage) {
      case SpeedTestStage.pinging:
        return AppTheme.warningYellow;
      case SpeedTestStage.downloading:
        return AppTheme.connectedGreen;
      case SpeedTestStage.uploading:
        return AppTheme.primary;
      case SpeedTestStage.complete:
        return AppTheme.connectedGreen;
      case SpeedTestStage.error:
        return AppTheme.disconnectedRed;
      case SpeedTestStage.idle:
        return AppTheme.textSecondary;
    }
  }

  String _getStageLabel() {
    switch (stage) {
      case SpeedTestStage.pinging:
        return 'TESTING LATENCY...';
      case SpeedTestStage.downloading:
        return 'TESTING DOWNLOAD...';
      case SpeedTestStage.uploading:
        return 'TESTING UPLOAD...';
      case SpeedTestStage.complete:
        return 'BENCHMARK COMPLETE';
      case SpeedTestStage.error:
        return 'ERROR';
      case SpeedTestStage.idle:
        return 'READY TO BENCHMARK';
    }
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final SpeedTestStage stage;

  _SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
    required this.stage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    // 1. Background Track Arc
    final trackPaint = Paint()
      ..color = AppTheme.surfaceLight.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // 2. Active Speed Sweep Arc
    final normalized = (speed / maxSpeed).clamp(0.0, 1.0);
    final activeSweep = sweepAngle * normalized;

    if (activeSweep > 0.01) {
      final activePaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.connectedGreen,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }

    // 3. Tick Marks
    final tickPaint = Paint()
      ..color = AppTheme.textSecondary.withOpacity(0.3)
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 10; i++) {
      final tickAngle = startAngle + (sweepAngle / 10) * i;
      final innerOffset = Offset(
        center.dx + (radius - 18) * math.cos(tickAngle),
        center.dy + (radius - 18) * math.sin(tickAngle),
      );
      final outerOffset = Offset(
        center.dx + (radius - 10) * math.cos(tickAngle),
        center.dy + (radius - 10) * math.sin(tickAngle),
      );
      canvas.drawLine(innerOffset, outerOffset, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.stage != stage ||
        oldDelegate.maxSpeed != maxSpeed;
  }
}
