import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/exercise_archetype.dart';
import '../theme/app_colors.dart';

/// One joint-angle pose for the shared figure rig -- all angles are
/// radians in a "hangs down, rotates" convention (0 = pointing straight
/// down/up along the limb's resting direction; see [_ArchetypeAnimationPainter]
/// for how each is turned into a point). [elbowBend]/[kneeBend] are
/// relative to [shoulderAngle]/[hipAngle] respectively, not absolute --
/// that keeps the forearm/shin always visually "attached" to the joint
/// above it regardless of how the upper limb itself is posed.
class _Pose {
  const _Pose({
    this.lean = 0,
    this.shoulderAngle = 0.15,
    this.elbowBend = 0,
    this.hipAngle = 0.1,
    this.kneeBend = 0,
    this.verticalShift = 0,
  });

  final double lean;
  final double shoulderAngle;
  final double elbowBend;
  final double hipAngle;
  final double kneeBend;
  final double verticalShift; // fraction of canvas height, +down

  static double _lerpD(double a, double b, double t) => a + (b - a) * t;

  _Pose lerpTo(_Pose other, double t) => _Pose(
        lean: _lerpD(lean, other.lean, t),
        shoulderAngle: _lerpD(shoulderAngle, other.shoulderAngle, t),
        elbowBend: _lerpD(elbowBend, other.elbowBend, t),
        hipAngle: _lerpD(hipAngle, other.hipAngle, t),
        kneeBend: _lerpD(kneeBend, other.kneeBend, t),
        verticalShift: _lerpD(verticalShift, other.verticalShift, t),
      );
}

/// Which rig part is drawn in the accent color -- the part actually doing
/// the work for that archetype, so the eye is drawn to the right thing
/// (e.g. only the forearm for curl/extension, the whole leg for squat).
enum _Emphasis { arm, leg, torso }

class _ArchetypeSpec {
  const _ArchetypeSpec(this.rest, this.peak, this.emphasis);
  final _Pose rest;
  final _Pose peak;
  final _Emphasis emphasis;
}

const Map<ExerciseArchetype, _ArchetypeSpec> _kSpecs = {
  ExerciseArchetype.verticalPush: _ArchetypeSpec(
    _Pose(shoulderAngle: 1.3, elbowBend: -2.0),
    _Pose(shoulderAngle: 3.05, elbowBend: -0.15),
    _Emphasis.arm,
  ),
  ExerciseArchetype.horizontalPush: _ArchetypeSpec(
    _Pose(shoulderAngle: 1.6, elbowBend: -2.2),
    _Pose(shoulderAngle: 1.57, elbowBend: -0.1),
    _Emphasis.arm,
  ),
  ExerciseArchetype.verticalPull: _ArchetypeSpec(
    _Pose(shoulderAngle: 3.05, elbowBend: -0.1),
    _Pose(shoulderAngle: 1.6, elbowBend: -1.9),
    _Emphasis.arm,
  ),
  ExerciseArchetype.horizontalPull: _ArchetypeSpec(
    _Pose(shoulderAngle: 1.5, elbowBend: -0.1),
    _Pose(shoulderAngle: 0.5, elbowBend: -1.8),
    _Emphasis.arm,
  ),
  ExerciseArchetype.squat: _ArchetypeSpec(
    _Pose(shoulderAngle: 0.3, elbowBend: -0.3, lean: 0.05, hipAngle: 0.1),
    _Pose(
      shoulderAngle: 0.3,
      elbowBend: -0.3,
      lean: 0.35,
      hipAngle: 0.9,
      kneeBend: 1.7,
      verticalShift: 0.07,
    ),
    _Emphasis.leg,
  ),
  ExerciseArchetype.hinge: _ArchetypeSpec(
    _Pose(shoulderAngle: 0.1, lean: 0.05, hipAngle: 0.05, kneeBend: 0.1),
    _Pose(shoulderAngle: 0.1, lean: 1.0, hipAngle: -0.15, kneeBend: 0.15),
    _Emphasis.torso,
  ),
  ExerciseArchetype.curl: _ArchetypeSpec(
    _Pose(shoulderAngle: 0.15, elbowBend: 0),
    _Pose(shoulderAngle: 0.15, elbowBend: -2.3),
    _Emphasis.arm,
  ),
  ExerciseArchetype.extension: _ArchetypeSpec(
    _Pose(shoulderAngle: 0.15, elbowBend: -2.3),
    _Pose(shoulderAngle: 0.15, elbowBend: 0),
    _Emphasis.arm,
  ),
  ExerciseArchetype.core: _ArchetypeSpec(
    _Pose(shoulderAngle: 0.15),
    _Pose(shoulderAngle: 0.15),
    _Emphasis.torso,
  ),
};

/// A small looping illustration of one [ExerciseArchetype]'s general rep
/// motion -- a filled, rounded-capsule silhouette figure (soft drop shadow,
/// highlighted head), not a bare wireframe stick figure. ORIGINAL and
/// procedurally posed/rendered by this app, never footage or a scraped
/// image of any real exercise. See `exercises_screen.dart`'s existing
/// top-of-file comment on why: this app never redistributes third-party
/// exercise media.
class ExerciseArchetypeAnimation extends StatefulWidget {
  const ExerciseArchetypeAnimation({
    super.key,
    required this.archetype,
    this.size = 120,
  });

  final ExerciseArchetype archetype;
  final double size;

  @override
  State<ExerciseArchetypeAnimation> createState() => _ExerciseArchetypeAnimationState();
}

class _ExerciseArchetypeAnimationState extends State<ExerciseArchetypeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final spec = _kSpecs[widget.archetype]!;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Smooth ease in/out both ways within one loop -- 0 at t=0/1
          // (rest pose), 1 at t=0.5 (peak pose) -- rather than a linear
          // ping-pong, which would visibly "snap" direction at the ends.
          final phase = (1 - math.cos(2 * math.pi * _controller.value)) / 2;
          final pose = spec.rest.lerpTo(spec.peak, phase);
          return CustomPaint(
            painter: _ArchetypeAnimationPainter(
              pose: pose,
              emphasis: spec.emphasis,
              // core's "different motion language" (a pulse, not a rep) --
              // driven by the same phase so it stays in sync with the loop.
              pulse: widget.archetype == ExerciseArchetype.core
                  ? 1.0 + phase * 0.04
                  : 1.0,
              bodyColor: colors.mut,
              accent: colors.accent,
              headColor: colors.txt,
            ),
          );
        },
      ),
    );
  }
}

class _ArchetypeAnimationPainter extends CustomPainter {
  _ArchetypeAnimationPainter({
    required this.pose,
    required this.emphasis,
    required this.pulse,
    required this.bodyColor,
    required this.accent,
    required this.headColor,
  });

  final _Pose pose;
  final _Emphasis emphasis;
  final double pulse;
  final Color bodyColor;
  final Color accent;
  final Color headColor;

  static Offset _limb(Offset from, double angle, double len) =>
      Offset(from.dx + math.sin(angle) * len, from.dy + math.cos(angle) * len);

  /// A filled "stadium" (rounded rectangle) between [a] and [b] -- a solid
  /// rounded-capsule limb segment rather than a bare stroked line, which is
  /// what actually gives this a designed, illustrated look instead of a
  /// wireframe stick figure.
  static void _drawCapsule(Canvas canvas, Offset a, Offset b, double radius, Paint paint) {
    final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    final length = (b - a).distance;
    canvas.save();
    canvas.translate((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: length + radius * 2, height: radius * 2),
        Radius.circular(radius),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;

    final neutral = Paint()..color = bodyColor;
    final active = Paint()..color = accent;

    final origin =
        Offset(size.width / 2, size.height / 2 + unit * 0.28 * pose.verticalShift);

    final hip = origin + Offset(0, unit * 0.08);
    final torsoLen = unit * 0.28;
    final shoulder = _limb(hip, math.pi + pose.lean, torsoLen);
    final headCenter = _limb(shoulder, math.pi + pose.lean, unit * 0.13);

    final upperArmLen = unit * 0.16;
    final forearmLen = unit * 0.15;
    final elbow = _limb(shoulder, pose.shoulderAngle, upperArmLen);
    final wrist = _limb(elbow, pose.shoulderAngle + pose.elbowBend, forearmLen);

    final thighLen = unit * 0.2;
    final shinLen = unit * 0.2;
    final knee = _limb(hip, pose.hipAngle, thighLen);
    final ankle = _limb(knee, pose.hipAngle + pose.kneeBend, shinLen);

    final headRadius = unit * 0.1;
    void drawFigure(Canvas c, {required bool asShadow}) {
      final legR = unit * 0.05;
      final thighR = unit * 0.055;
      final torsoR = unit * 0.075;
      final armR = unit * 0.04;
      if (asShadow) {
        final shadow = Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.018);
        _drawCapsule(c, hip, knee, thighR, shadow);
        _drawCapsule(c, knee, ankle, legR, shadow);
        _drawCapsule(c, hip, shoulder, torsoR, shadow);
        _drawCapsule(c, shoulder, elbow, armR, shadow);
        _drawCapsule(c, elbow, wrist, armR * 0.85, shadow);
        c.drawCircle(headCenter, headRadius, shadow);
        return;
      }
      final legPaint = emphasis == _Emphasis.leg ? active : neutral;
      final torsoPaint = emphasis == _Emphasis.torso ? active : neutral;
      final armPaint = emphasis == _Emphasis.arm ? active : neutral;
      _drawCapsule(c, hip, knee, thighR, legPaint);
      _drawCapsule(c, knee, ankle, legR, legPaint);
      _drawCapsule(c, hip, shoulder, torsoR, torsoPaint);
      _drawCapsule(c, shoulder, elbow, armR, armPaint);
      _drawCapsule(c, elbow, wrist, armR * 0.85, armPaint);
      c.drawCircle(headCenter, headRadius, Paint()..color = headColor);
      // Small offset highlight for a touch of roundness on the head,
      // cheaper and more robust than a per-shape gradient shader.
      c.drawCircle(
        headCenter + Offset(-headRadius * 0.3, -headRadius * 0.35),
        headRadius * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
    }

    canvas.save();
    if (pulse != 1.0) {
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(pulse, pulse);
      canvas.translate(-origin.dx, -origin.dy);
    }
    // Ground shadow first (soft, offset down-right), then the shadow pass
    // of the figure itself (a second, subtler blurred silhouette directly
    // beneath), then the real figure on top -- cheap depth without
    // per-limb gradients.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(origin.dx, ankle.dy + unit * 0.02),
        width: unit * 0.34,
        height: unit * 0.05,
      ),
      Paint()
        ..color = bodyColor.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.012),
    );
    canvas.save();
    canvas.translate(unit * 0.012, unit * 0.016);
    drawFigure(canvas, asShadow: true);
    canvas.restore();
    drawFigure(canvas, asShadow: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArchetypeAnimationPainter old) {
    return old.pose.lean != pose.lean ||
        old.pose.shoulderAngle != pose.shoulderAngle ||
        old.pose.elbowBend != pose.elbowBend ||
        old.pose.hipAngle != pose.hipAngle ||
        old.pose.kneeBend != pose.kneeBend ||
        old.pose.verticalShift != pose.verticalShift ||
        old.pulse != pulse ||
        old.bodyColor != bodyColor ||
        old.accent != accent;
  }
}
