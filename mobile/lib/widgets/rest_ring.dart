import 'dart:math';

import 'package:flutter/material.dart';

/// Rest-timer countdown ring for [WorkoutOverlayScreen]. Uses
/// `Canvas.drawArc` directly — simple and cheap to redraw every tick.
class RestRing extends StatelessWidget {
  const RestRing({
    super.key,
    required this.progress, // restLeft / restTotal, 0..1
    required this.trackColor,
    required this.progressColor,
    this.size = 220,
    this.strokeWidth = 10,
    this.child,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RestRingPainter(
              progress: progress,
              trackColor: trackColor,
              progressColor: progressColor,
              strokeWidth: strokeWidth,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RestRingPainter extends CustomPainter {
  _RestRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 2 * pi, false, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress.clamp(0, 1),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RestRingPainter old) {
    return old.progress != progress ||
        old.trackColor != trackColor ||
        old.progressColor != progressColor;
  }
}
