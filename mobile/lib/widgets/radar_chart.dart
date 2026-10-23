import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A round number of rings for [maxValue]: the step is 1, 2, 2.5 or 5 times
/// a power of ten, and the outer ring the first multiple of it that holds
/// [maxValue] -- about [rings] rings, never fewer than one.
({double max, List<double> rings}) radarScale(double maxValue, {int rings = 4}) {
  if (maxValue <= 0) return (max: 1, rings: const [1]);
  final raw = maxValue / rings;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = [1.0, 2.0, 2.5, 5.0, 10.0]
          .map((m) => m * magnitude)
          .firstWhere((s) => s >= raw - 1e-9);
  final count = math.max(1, (maxValue / step - 1e-9).ceil());
  return (max: step * count, rings: [for (var i = 1; i <= count; i++) step * i]);
}

/// One spoke of a [RadarChart].
@immutable
class RadarAxis {
  const RadarAxis({required this.label, this.value, this.start, this.detail});

  /// Name at the spoke's outer end.
  final String label;

  /// The current value (the filled shape); null = nothing logged, drawn at
  /// the centre without a dot.
  final double? value;

  /// An earlier value for the dashed comparison outline; null = none.
  final double? start;

  /// Second label line, e.g. "36.5 cm · +1.5".
  final String? detail;
}

/// A spider/radar chart on ONE shared, honest scale for every spoke (kg for
/// lifts, cm for measurements) -- the rings are labelled in that unit, so the
/// shape never says something the numbers at its corners don't.
///
/// The current values are an accent-filled shape (2 px outline, 8 px dots);
/// [RadarAxis.start] values, where any are given, a dashed outline in the
/// muted ink to compare against. Spoke labels are real [Text] widgets around
/// the web (they scale with the system text size and are read out), and the
/// web shrinks to leave them room, so long labels never clip.
class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.axes,
    required this.ringLabel,
    this.maxRadius = 110,
    this.semanticsLabel,
    this.nowLabel,
    this.startLabel,
  }) : assert(axes.length >= 3);

  final List<RadarAxis> axes;

  /// Text for a ring value, e.g. `(v) => '${v.round()} kg'`; only the
  /// outermost ring carries the unit if the caller wants it so.
  final String Function(double value, bool outermost) ringLabel;
  final double maxRadius;
  final String? semanticsLabel;

  /// Legend names for the two shapes -- the legend shows only when there is
  /// a start outline to tell apart (one shape needs none; the card's title
  /// names it).
  final String? nowLabel;
  final String? startLabel;

  static const double _labelGap = 8;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final textScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final base = DefaultTextStyle.of(context).style;
    final labelStyle = base.merge(TextStyle(color: colors.txt, fontSize: 12.5, fontWeight: FontWeight.w700));
    final detailStyle = base.merge(TextStyle(color: colors.mut, fontSize: 11.5, fontWeight: FontWeight.w600));

    final peak = axes
        .expand((a) => [a.value ?? 0, a.start ?? 0])
        .fold(0.0, math.max);
    final scale = radarScale(peak);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final n = axes.length;
      final directions = [
        for (var i = 0; i < n; i++)
          Offset(math.cos(-math.pi / 2 + 2 * math.pi * i / n), math.sin(-math.pi / 2 + 2 * math.pi * i / n)),
      ];
      final sizes = [
        for (final a in axes) _measure(a, labelStyle, detailStyle, textScaler, width),
      ];

      // The biggest radius that keeps every side label inside the width.
      var radius = maxRadius;
      for (var i = 0; i < n; i++) {
        final dx = directions[i].dx;
        if (dx.abs() < 0.3) continue;
        radius = math.min(radius, (width / 2 - sizes[i].width) / dx.abs() - _labelGap);
      }
      radius = math.max(radius, 40);

      // Label boxes relative to the centre, then the height they all need.
      final boxes = <Rect>[];
      for (var i = 0; i < n; i++) {
        final d = directions[i];
        final anchor = d * (radius + _labelGap);
        final size = sizes[i];
        final left = d.dx.abs() < 0.3
            ? anchor.dx - size.width / 2
            : (d.dx > 0 ? anchor.dx : anchor.dx - size.width);
        final top = d.dy < -0.3
            ? anchor.dy - size.height
            : (d.dy > 0.3 ? anchor.dy : anchor.dy - size.height / 2);
        boxes.add(Rect.fromLTWH(left, top, size.width, size.height));
      }
      final top = boxes.fold(-radius, (v, b) => math.min(v, b.top));
      final bottom = boxes.fold(radius, (v, b) => math.max(v, b.bottom));
      final center = Offset(width / 2, -top);
      final nowLabel = this.nowLabel;
      final startLabel = this.startLabel;
      final showLegend = nowLabel != null && startLabel != null && axes.any((a) => a.start != null);

      final chart = Semantics(
        label: semanticsLabel,
        child: SizedBox(
          width: width,
          height: bottom - top,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _RadarPainter(
                      axes: axes,
                      center: center,
                      radius: radius,
                      scale: scale,
                      ringLabel: ringLabel,
                      ringStyle: base.merge(TextStyle(color: colors.mut, fontSize: 9.5, fontWeight: FontWeight.w600)),
                      textScaler: textScaler,
                      grid: colors.line,
                      accent: colors.accent,
                      startColor: colors.mut,
                      surface: colors.card,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < n; i++)
                Positioned(
                  left: center.dx + boxes[i].left,
                  top: center.dy + boxes[i].top,
                  width: boxes[i].width,
                  child: _AxisLabel(
                    axis: axes[i],
                    align: directions[i].dx.abs() < 0.3
                        ? TextAlign.center
                        : (directions[i].dx > 0 ? TextAlign.left : TextAlign.right),
                    labelStyle: labelStyle,
                    detailStyle: detailStyle,
                    textScaler: textScaler,
                  ),
                ),
            ],
          ),
        ),
      );
      if (!showLegend) return chart;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          chart,
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              _LegendEntry(label: nowLabel, color: colors.accent, dashed: false, style: detailStyle, textScaler: textScaler),
              _LegendEntry(label: startLabel, color: colors.mut, dashed: true, style: detailStyle, textScaler: textScaler),
            ],
          ),
        ],
      );
    });
  }

  Size _measure(RadarAxis axis, TextStyle label, TextStyle detail, TextScaler scaler, double width) {
    // Side labels may take up to ~40 % of the width before they wrap.
    final maxWidth = width * 0.4;
    Size measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: maxWidth);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final a = measure(axis.label, label);
    final detailText = axis.detail;
    final b = detailText == null ? Size.zero : measure(detailText, detail);
    return Size(math.max(a.width, b.width).ceilToDouble() + 1, a.height + (detailText == null ? 0 : b.height + 1));
  }
}

/// A line sample (solid or dashed, like the shape it names) and its name.
class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.label,
    required this.color,
    required this.dashed,
    required this.style,
    required this.textScaler,
  });

  final String label;
  final Color color;
  final bool dashed;
  final TextStyle style;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(18, 8), painter: _LegendLinePainter(color: color, dashed: dashed)),
        const SizedBox(width: 6),
        Text(label, style: style, textScaler: textScaler),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  _LegendLinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dashed ? 1.5 : 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter old) => old.color != color || old.dashed != dashed;
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({
    required this.axis,
    required this.align,
    required this.labelStyle,
    required this.detailStyle,
    required this.textScaler,
  });

  final RadarAxis axis;
  final TextAlign align;
  final TextStyle labelStyle;
  final TextStyle detailStyle;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    final cross = switch (align) {
      TextAlign.left => CrossAxisAlignment.start,
      TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
    final detail = axis.detail;
    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(axis.label, style: labelStyle, textAlign: align, textScaler: textScaler),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(detail, style: detailStyle, textAlign: align, textScaler: textScaler),
          ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.center,
    required this.radius,
    required this.scale,
    required this.ringLabel,
    required this.ringStyle,
    required this.textScaler,
    required this.grid,
    required this.accent,
    required this.startColor,
    required this.surface,
  });

  final List<RadarAxis> axes;
  final Offset center;
  final double radius;
  final ({double max, List<double> rings}) scale;
  final String Function(double value, bool outermost) ringLabel;
  final TextStyle ringStyle;
  final TextScaler textScaler;
  final Color grid;
  final Color accent;
  final Color startColor;
  final Color surface;

  Offset _point(int i, double value) {
    final angle = -math.pi / 2 + 2 * math.pi * i / axes.length;
    final r = radius * (value / scale.max).clamp(0.0, 1.0);
    return center + Offset(math.cos(angle), math.sin(angle)) * r;
  }

  Path _polygon(double Function(int i) valueAt) {
    final path = Path();
    for (var i = 0; i < axes.length; i++) {
      final p = _point(i, valueAt(i));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // The web: one ring per scale step, spokes to the outer ring.
    for (final ring in scale.rings) {
      canvas.drawPath(_polygon((_) => ring), gridPaint);
    }
    for (var i = 0; i < axes.length; i++) {
      canvas.drawLine(center, _point(i, scale.max), gridPaint);
    }

    final hasStart = axes.any((a) => a.start != null);
    if (hasStart) {
      final dashed = _dash(_polygon((i) => axes[i].start ?? axes[i].value ?? 0), 5, 4);
      canvas.drawPath(
        dashed,
        Paint()
          ..color = startColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final now = _polygon((i) => axes[i].value ?? 0);
    canvas.drawPath(now, Paint()..color = accent.withValues(alpha: 0.16));
    canvas.drawPath(
      now,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < axes.length; i++) {
      final value = axes[i].value;
      if (value == null) continue;
      final p = _point(i, value);
      // A surface ring keeps a dot readable where it sits on a line.
      canvas.drawCircle(p, 6, Paint()..color = surface);
      canvas.drawCircle(p, 4, Paint()..color = accent);
    }

    // Ring values last, beside the top spoke clear of its dot, each on a
    // small patch of the card colour so lines running through stay behind.
    for (var r = 0; r < scale.rings.length; r++) {
      final ring = scale.rings[r];
      final painter = TextPainter(
        text: TextSpan(text: ringLabel(ring, r == scale.rings.length - 1), style: ringStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final at = _point(0, ring) + Offset(9, -painter.height / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx - 2, at.dy, painter.width + 4, painter.height),
          const Radius.circular(3),
        ),
        Paint()..color = surface.withValues(alpha: 0.85),
      );
      painter.paint(canvas, at);
      painter.dispose();
    }
  }

  static Path _dash(Path source, double dash, double gap) {
    final out = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        out.addPath(metric.extractPath(d, math.min(d + dash, metric.length)), Offset.zero);
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.axes != axes ||
      old.center != center ||
      old.radius != radius ||
      old.scale != scale ||
      old.grid != grid ||
      old.accent != accent ||
      old.startColor != startColor ||
      old.surface != surface ||
      old.ringStyle != ringStyle ||
      old.textScaler != textScaler;
}
