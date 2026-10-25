import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The training streak as a living flame: the longer the run of training
/// days, the bigger it burns -- small and grey at zero, full size from
/// about two months on. Layered like real fire (deep red outside, orange
/// body, a white-hot core) with two side licks flickering out of step,
/// sparks rising off it once the streak reaches three days (more the
/// longer it runs) and a blue-hot base from 30 days. Stands still when the
/// platform asks for reduced motion.
class StreakFlame extends StatefulWidget {
  const StreakFlame({super.key, required this.days});

  final int days;

  /// Height in logical pixels: 18 at no streak, growing on a log curve
  /// (each extra day matters most early on) to 40 at 60 days and beyond.
  static double sizeFor(int days) {
    if (days <= 0) return 18;
    return 18 + 22 * math.min(1.0, math.log(1 + days) / math.log(61));
  }

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame> with SingleTickerProviderStateMixin {
  late final AnimationController _flicker =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  /// An unlit flame (no streak) and reduced motion both stand still.
  void _syncFlicker() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still || widget.days <= 0) {
      _flicker.stop();
    } else if (!_flicker.isAnimating) {
      _flicker.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFlicker();
  }

  @override
  void didUpdateWidget(StreakFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFlicker();
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = StreakFlame.sizeFor(widget.days);
    return TweenAnimationBuilder<double>(
      // Grows smoothly when the streak goes up instead of jumping.
      tween: Tween(end: size),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, height, _) => CustomPaint(
        size: Size(height * 0.8, height),
        painter: _FlamePainter(
          flicker: _flicker,
          days: widget.days,
          muted: Theme.of(context).disabledColor,
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.flicker, required this.days, required this.muted}) : super(repaint: flicker);

  final Animation<double> flicker;
  final int days;
  final Color muted;

  /// A tongue of fire inside [r]: round at the bottom, drawn up into a tip
  /// that leans sideways by [lean].
  static Path _tongue(Rect r, {double lean = 0}) {
    final w = r.width;
    final h = r.height;
    double x(double f) => r.left + w * f;
    double y(double f) => r.top + h * f;
    return Path()
      ..moveTo(x(0.5), y(1))
      ..cubicTo(x(0.08), y(1), x(-0.02), y(0.64), x(0.2), y(0.42))
      ..cubicTo(x(0.3), y(0.3), x(0.42) + lean * 0.6, y(0.2), x(0.5) + lean, y(0))
      ..cubicTo(x(0.6) + lean * 0.6, y(0.24), x(1.02), y(0.42), x(0.93), y(0.7))
      ..cubicTo(x(0.86), y(0.92), x(0.7), y(1), x(0.5), y(1))
      ..close();
  }

  /// The flame's body: like [_tongue], but the right flank dips into a
  /// notch and rises again into a smaller second tip, the way real fire
  /// splits -- [lean] moves the main tip, [lean2] the second one.
  static Path _body(Rect r, {double lean = 0, double lean2 = 0}) {
    final w = r.width;
    final h = r.height;
    double x(double f) => r.left + w * f;
    double y(double f) => r.top + h * f;
    return Path()
      ..moveTo(x(0.5), y(1))
      ..cubicTo(x(0.08), y(1), x(-0.03), y(0.66), x(0.17), y(0.44))
      ..cubicTo(x(0.29), y(0.31), x(0.36) + lean * 0.5, y(0.2), x(0.46) + lean, y(0))
      ..cubicTo(x(0.57) + lean * 0.5, y(0.16), x(0.62), y(0.3), x(0.66), y(0.42))
      ..cubicTo(x(0.69), y(0.37), x(0.74) + lean2 * 0.5, y(0.32), x(0.8) + lean2, y(0.22))
      ..cubicTo(x(0.88), y(0.36), x(1.03), y(0.5), x(0.94), y(0.72))
      ..cubicTo(x(0.87), y(0.92), x(0.7), y(1), x(0.5), y(1))
      ..close();
  }

  static Shader _upward(Rect r, List<Color> colors, [List<double>? stops]) => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: colors,
        stops: stops,
      ).createShader(r);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (days <= 0) {
      canvas.drawPath(_body(Rect.fromLTRB(w * 0.06, 0, w * 0.96, h)), Paint()..color = muted.withValues(alpha: 0.45));
      return;
    }

    final heat = math.min(1.0, math.log(1 + days) / math.log(61));
    final t = flicker.value * 2 * math.pi;
    // Whole-number frequencies only, so the loop has no seam where the
    // controller wraps around.
    double wave(double a, double b, double c) => 0.5 * math.sin(t + a) + 0.3 * math.sin(2 * t + b) + 0.2 * math.sin(3 * t + c);
    final sway = wave(0, 1, 2) * w * (0.04 + 0.03 * heat);
    final sway2 = wave(3, 4, 1) * w * 0.05;
    final rise = (wave(2, 0, 1) + 1) / 2; // 0..1, how high the main tip reaches
    final lick = (wave(1, 3, 0) + 1) / 2;
    final top = h * 0.06 * (1 - rise);

    // Soft glow, wider and warmer the longer the streak.
    final glowRect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.72), width: w * 2.0, height: h * 1.4);
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF9100).withValues(alpha: 0.22 + 0.28 * heat),
            const Color(0xFFFF6D00).withValues(alpha: 0),
          ],
        ).createShader(glowRect),
    );

    // A slim lick on the left, flickering out of step with the body.
    final left = Rect.fromLTRB(w * 0.0, h * (0.26 + 0.12 * (1 - lick)), w * 0.44, h * 0.96);
    canvas.drawPath(
      _tongue(left, lean: -w * 0.08 + sway * 0.5),
      Paint()..shader = _upward(left, const [Color(0xFFFF6D00), Color(0xFFD84315), Color(0xFFB71C1C)]),
    );

    // The body: deep red at the tips, orange at the base.
    final body = Rect.fromLTRB(w * 0.06, top, w * 0.96, h);
    canvas.drawPath(
      _body(body, lean: sway, lean2: sway2),
      Paint()
        ..shader = _upward(body, const [
          Color(0xFFFFA000),
          Color(0xFFFF6D00),
          Color(0xFFE64A19),
          Color(0xFFC62828),
        ], const [0.0, 0.4, 0.75, 1.0]),
    );

    // Inner flame: yellow into orange.
    final middle = Rect.fromLTRB(w * 0.22, h * 0.3 + top * 0.6, w * 0.78, h * 0.99);
    canvas.drawPath(
      _tongue(middle, lean: sway * 0.7),
      Paint()..shader = _upward(middle, const [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFFF8F00)], const [0.0, 0.6, 1.0]),
    );

    // White-hot core -- bigger, with a blue base, from 30 days.
    final hot = days >= 30;
    final core = hot
        ? Rect.fromLTRB(w * 0.3, h * 0.5, w * 0.7, h * 0.97)
        : Rect.fromLTRB(w * 0.34, h * 0.58, w * 0.66, h * 0.97);
    canvas.drawPath(
      _tongue(core, lean: sway * 0.4),
      Paint()
        ..shader = _upward(
          core,
          hot
              ? const [Color(0xFFB3E5FC), Color(0xFFFFFFFF), Color(0xFFFFF9C4)]
              : const [Color(0xFFFFFFFF), Color(0xFFFFF59D)],
          hot ? const [0.0, 0.2, 1.0] : null,
        ),
    );

    // Sparks rising off the tips: one at three days, up to six.
    if (days >= 3) {
      final count = math.min(6, 1 + days ~/ 7);
      for (var i = 0; i < count; i++) {
        // Twice per loop, spread over the loop -- still seamless.
        final life = (flicker.value * 2 + i / count) % 1.0;
        final drift = math.sin(t * 2 + i * 2.1) * w * 0.14 * life;
        final x = w * (0.32 + 0.4 * ((i * 0.37) % 1.0)) + drift;
        final y = h * (0.12 - 0.55 * life);
        final fade = 1 - life;
        canvas.drawCircle(
          Offset(x, y),
          w * 0.03 * (0.4 + fade),
          Paint()..color = Color.lerp(const Color(0xFFFFE082), const Color(0xFFFF6D00), life)!.withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => oldDelegate.days != days || oldDelegate.muted != muted;
}
