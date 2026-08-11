import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The ExerciseDetail "drag ruler" weight picker.
///
/// Dragging RIGHT increases the weight, LEFT decreases it — inverted versus
/// normal ruler intuition, intentional: it mirrors pulling the ruler's tape
/// towards you to read a higher number. The drag delta is always
/// recomputed relative to the drag's start position (not accumulated
/// per-frame), avoiding float drift on a long drag.
class WeightRuler extends StatefulWidget {
  const WeightRuler({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  static const double min = 0;
  static const double max = 300;
  static const double step = 2.5;
  static const double pxPerTick = 12;

  @override
  State<WeightRuler> createState() => _WeightRulerState();
}

class _WeightRulerState extends State<WeightRuler> {
  double _dragStartX = 0;
  double _dragStartValue = 0;

  void _onDragStart(DragStartDetails d) {
    _dragStartX = d.globalPosition.dx;
    _dragStartValue = widget.value;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dx = d.globalPosition.dx - _dragStartX;
    final raw = _dragStartValue + (dx / WeightRuler.pxPerTick) * WeightRuler.step;
    final snapped = (raw / WeightRuler.step).round() * WeightRuler.step;
    // num.clamp() returns `num` even on a double receiver — .toDouble()
    // keeps this assignable to the double-typed ValueChanged callback.
    final clamped = snapped.clamp(WeightRuler.min, WeightRuler.max).toDouble();
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      child: ClipRect(
        child: SizedBox(
          height: 64,
          width: double.infinity,
          child: CustomPaint(
            painter: _WeightRulerPainter(value: widget.value, colors: colors),
          ),
        ),
      ),
    );
  }
}

class _WeightRulerPainter extends CustomPainter {
  _WeightRulerPainter({required this.value, required this.colors});

  final double value;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final trackX = center -
        ((value - WeightRuler.min) / WeightRuler.step) * WeightRuler.pxPerTick;
    final tickCount =
        ((WeightRuler.max - WeightRuler.min) / WeightRuler.step).round();

    for (var i = 0; i <= tickCount; i++) {
      final v = WeightRuler.min + i * WeightRuler.step;
      final isMajor = v % 20 == 0;
      final x = trackX + i * WeightRuler.pxPerTick;
      if (x < -20 || x > size.width + 20) continue; // cheap offscreen cull
      final h = isMajor ? 22.0 : 12.0;
      canvas.drawRect(
        Rect.fromLTWH(x, 10 + 40 - h, 1.5, h),
        Paint()..color = isMajor ? colors.mut : colors.line,
      );
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: v.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: colors.mut,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 0.75 - tp.width / 2, 10 + 40 - h - 18));
      }
    }

    // fixed center needle
    canvas.drawRect(
      Rect.fromLTWH(center - 1, 4, 2, size.height - 8),
      Paint()..color = colors.accent,
    );

    _drawFade(canvas, size, left: true);
    _drawFade(canvas, size, left: false);
  }

  void _drawFade(Canvas canvas, Size size, {required bool left}) {
    final rect = left
        ? Rect.fromLTWH(0, 0, 50, size.height)
        : Rect.fromLTWH(size.width - 50, 0, 50, size.height);
    final shader = LinearGradient(
      begin: left ? Alignment.centerLeft : Alignment.centerRight,
      end: left ? Alignment.centerRight : Alignment.centerLeft,
      colors: [colors.card, colors.card.withValues(alpha: 0)],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _WeightRulerPainter old) {
    return old.value != value || old.colors != colors;
  }
}
