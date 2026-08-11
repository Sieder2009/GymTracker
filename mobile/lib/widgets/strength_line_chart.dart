import 'package:flutter/material.dart';

/// Mini line chart for a Strength-tab lift card: last ≤8 history points +
/// an optional dashed PR reference line. Scaling formula:
/// `min = min(pr>0?pr:first, ...points) - 2`, `max = max(pr??0, ...points) +
/// 2`. Uses fixed screen-space stroke widths rather than `canvas.scale()`,
/// so the line stays crisp regardless of the chart's aspect ratio.
class StrengthLineChart extends StatelessWidget {
  const StrengthLineChart({
    super.key,
    required this.points,
    required this.pr,
    required this.color,
    required this.lineColor,
  });

  final List<double> points; // already trimmed to the last 8 by the caller
  final double pr; // 0 = no PR set
  final Color color;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.4,
      child: CustomPaint(
        painter: _StrengthLineChartPainter(
          points: points,
          pr: pr,
          color: color,
          lineColor: lineColor,
        ),
      ),
    );
  }
}

class _StrengthLineChartPainter extends CustomPainter {
  _StrengthLineChartPainter({
    required this.points,
    required this.pr,
    required this.color,
    required this.lineColor,
  });

  final List<double> points;
  final double pr;
  final Color color;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final values = [if (pr > 0) pr else points.first, ...points];
    final min = values.reduce((a, b) => a < b ? a : b) - 2;
    final max = values.reduce((a, b) => a > b ? a : b) + 2;
    final range = (max - min) == 0 ? 1 : (max - min);

    double yOf(double v) => size.height * (1 - (v - min) / range);
    double xOf(int i) =>
        points.length == 1 ? size.width / 2 : size.width * (i / (points.length - 1));

    if (pr > 0) {
      final prY = yOf(pr);
      final dashPaint = Paint()
        ..color = lineColor
        ..strokeWidth = 1.5;
      const dashWidth = 5.0;
      const gapWidth = 4.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, prY), Offset(x + dashWidth, prY), dashPaint);
        x += dashWidth + gapWidth;
      }
    }

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(xOf(i), yOf(points[i]));
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(points[i])), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _StrengthLineChartPainter old) {
    return old.points != points || old.pr != pr || old.color != color;
  }
}
