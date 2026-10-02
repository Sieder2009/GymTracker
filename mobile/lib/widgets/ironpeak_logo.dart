import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

/// The Ironpeak mark -- a two-peak mountain with a barbell across it ("iron"
/// + "peak") -- and its motion, in one place. This file is the single source
/// of truth: [AnimatedIronpeakLogo] draws it live, and
/// `tool/generate_icons.dart` renders every static asset (Android adaptive
/// icon + animated launch icon, legacy PNGs, web icons, Windows .ico) from the
/// very same path strings, so the launcher icon, the splash animation and the
/// in-app logo can never drift apart.
///
/// The glyph lives in a 100x100 "logo unit" box and every shape stays inside
/// the circle of radius 50 around (50, 50) -- that circle is what maps onto
/// the 66dp safe zone of Android's 108dp adaptive-icon canvas, i.e. what no
/// launcher mask (circle, squircle, teardrop...) can ever crop.
abstract final class IronpeakMark {
  static const double unit = 100;

  /// Glyph box as a fraction of the badge: 66dp of the 108dp adaptive canvas.
  static const double launcherGlyphFraction = 66 / 108;

  /// Where there is no launcher mask (in-app badge, web, .ico) the glyph can
  /// be a bit bigger.
  static const double badgeGlyphFraction = 0.7;

  // --- colors ----------------------------------------------------------

  // Brand green is the README mountain's #1FA76A (AppColors.green) -- lit
  // from the top-left, deeper toward the bottom-right.
  static const Color gradientStart = Color(0xFF38D08F);
  static const Color gradientMid = Color(0xFF1FA76A);
  static const Color gradientEnd = Color(0xFF0B6644);
  static const double gradientMidStop = 0.55;

  static const Color rock = Color(0xFF04382A);
  static const double backPeakAlpha = 0.3;
  static const double frontPeakAlpha = 0.42;
  static const double shadowAlpha = 0.25;
  static const Color snow = Color(0xFFFFFFFF);
  static const Color iron = Color(0xFFFFFFFF);

  /// Themed (monochrome) Android icons: the system tints this layer with a
  /// single color, so the mountain gets partial coverage to stay readable
  /// behind the bar.
  static const double monoBackPeakAlpha = 0.35;
  static const double monoFrontPeakAlpha = 0.6;

  // --- geometry (SVG path syntax, logo units) --------------------------
  //
  // Plain SVG path data on purpose: Android's VectorDrawable `pathData`
  // parses the identical syntax, so the generator pastes these strings
  // straight into the XML.

  static const String backPeak = 'M74,24L88,82L34,82Z';
  static const String frontPeak = 'M42,8L66,82L14,82Z';
  static const String backSnow =
      'M74,24L77.4,38L74.2,34.6L71,39L67.6,34.8L64.3,38Z';
  static const String frontSnow =
      'M42,8L49.1,30L44.5,35L41,29.8L37.5,34L33.7,30Z';

  /// Where the bar rests (center line) and how far a rep lifts it.
  static const double barbellRestY = 60;
  static const double repHeight = 14;
  static const double shadowOffset = 1.6;

  static final String barbell = _barbell(barbellRestY);
  static final String barbellShadow = _barbell(barbellRestY + shadowOffset);

  /// Four-point glint, centered on the origin -- the glint group places it.
  static const String spark =
      'M0,-6.5Q0.9,-0.9 6.5,0Q0.9,0.9 0,6.5Q-0.9,0.9 -6.5,0Q-0.9,-0.9 0,-6.5Z';
  static const Offset sparkAnchor = Offset(51, 13);

  /// Pivot for the mountain's pop-in and landing squash: the middle of its
  /// base, so it squashes downward into the ground rather than around its
  /// center.
  static const Offset mountainPivot = Offset(50, 82);

  static String _barbell(double cy) {
    return [
      _rrect(20, cy - 2.7, 60, 5.4, 1.6), // bar
      _rrect(15.5, cy - 19, 8, 38, 3), // big plates
      _rrect(76.5, cy - 19, 8, 38, 3),
      _rrect(9, cy - 12.5, 5.5, 25, 2.4), // small plates
      _rrect(85.5, cy - 12.5, 5.5, 25, 2.4),
      _rrect(5, cy - 3.4, 4.6, 6.8, 1.6), // sleeve ends
      _rrect(90.4, cy - 3.4, 4.6, 6.8, 1.6),
    ].join();
  }

  static String _rrect(double x, double y, double w, double h, double r) {
    final x2 = x + w;
    final y2 = y + h;
    final arc = 'A${_n(r)},${_n(r)} 0 0 1 ';
    return 'M${_n(x + r)},${_n(y)}'
        'H${_n(x2 - r)}$arc${_n(x2)},${_n(y + r)}'
        'V${_n(y2 - r)}$arc${_n(x2 - r)},${_n(y2)}'
        'H${_n(x + r)}$arc${_n(x)},${_n(y2 - r)}'
        'V${_n(y + r)}$arc${_n(x + r)},${_n(y)}Z';
  }

  /// Compact number for path data: no trailing zeros, no "-0".
  static String _n(double v) {
    var s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s == '-0' ? '0' : s;
  }

  // Parsed once; paths are only ever drawn, never mutated.
  static final Path _backPeakPath = parseSvgPathData(backPeak);
  static final Path _frontPeakPath = parseSvgPathData(frontPeak);
  static final Path _backSnowPath = parseSvgPathData(backSnow);
  static final Path _frontSnowPath = parseSvgPathData(frontSnow);
  static final Path _barbellPath = parseSvgPathData(barbell);
  static final Path _barbellShadowPath = parseSvgPathData(barbellShadow);
  static final Path _sparkPath = parseSvgPathData(spark);

  // --- motion ----------------------------------------------------------
  //
  // A pure function of time, so the live widget, the preview sheet and the
  // Android launch animation (res/drawable/ic_splash_animated.xml, which
  // generate_icons.dart writes with these same numbers) all play one script:
  //
  //  * intro  -- the mountain pops in, the barbell drops onto it and
  //              bounces (Android's own BounceInterpolator curve, so the
  //              launch animation matches exactly), the peak squashes on the
  //              first impact and a glint flashes.
  //  * loop   -- one rep forever: lift, hold (glint at the top), controlled
  //              lowering, a small landing squash, short rest.

  static const double introSeconds = 0.64;
  static const double loopSeconds = 3.0;

  static const double _dropFrom = 44;
  static const double _dropStart = 0.08;
  static const double _dropSeconds = 0.52;

  /// The BounceInterpolator's first impact: where the barbell first reaches
  /// its rest position and the mountain should squash.
  static const double impactSeconds =
      _dropStart + _dropSeconds * (0.3535 / 1.1226);

  /// The pose at [seconds] since the logo appeared. Past the intro it
  /// repeats every [loopSeconds].
  static LogoPose poseAt(double seconds) {
    if (seconds < introSeconds) return _intro(seconds);
    return _loop((seconds - introSeconds) % loopSeconds);
  }

  static LogoPose _intro(double t) {
    final pop = _seg(t, 0, 0.24);
    final fade = _seg(t, 0, 0.18);
    final drop = _seg(t, _dropStart, _dropSeconds);

    final squashDown = _seg(t, impactSeconds, 0.07);
    final squashUp = _seg(t, impactSeconds + 0.07, 0.12);
    final squash =
        1 - 0.045 * _decel(squashDown) * (1 - _decel(squashUp));

    final glintUp = _seg(t, 0.26, 0.14);
    final glintDown = _seg(t, 0.40, 0.24);

    return LogoPose(
      mountainAlpha: Curves.fastOutSlowIn.transform(fade),
      mountainScale: 0.86 + 0.14 * Curves.fastOutSlowIn.transform(pop),
      mountainSquash: squash,
      barbellDy: -_dropFrom * (1 - _androidBounce(drop)),
      barbellAlpha: _seg(t, _dropStart, 0.08),
      sparkScale: 1.15 * _decel(glintUp) * (1 - _accel(glintDown)),
      sparkTurn: _seg(t, 0.26, 0.38) * math.pi / 2,
    );
  }

  static LogoPose _loop(double u) {
    final up = Curves.easeInOutCubic.transform(_seg(u, 0.55, 0.70));
    final down = Curves.easeInOutCubic.transform(_seg(u, 1.65, 0.65));
    final land = _seg(u, 2.30, 0.30);
    final glint = _seg(u, 1.20, 0.50);
    return LogoPose(
      barbellDy: -repHeight * (up - down),
      mountainSquash: 1 - 0.02 * math.sin(math.pi * land),
      sparkScale: math.sin(math.pi * glint),
      sparkTurn: glint * math.pi / 2,
    );
  }

  static double _seg(double t, double start, double seconds) =>
      math.min(1.0, math.max(0.0, (t - start) / seconds));

  static double _decel(double x) => 1 - (1 - x) * (1 - x);
  static double _accel(double x) => x * x;

  /// android.view.animation.BounceInterpolator, verbatim.
  static double _androidBounce(double t) {
    double bounce(double x) => x * x * 8;
    final x = t * 1.1226;
    if (x < 0.3535) return bounce(x);
    if (x < 0.7408) return bounce(x - 0.54719) + 0.7;
    if (x < 0.9644) return bounce(x - 0.8526) + 0.9;
    return bounce(x - 1.0435) + 0.95;
  }

  // --- painting --------------------------------------------------------

  /// Paints the badge (per [shape]) and the glyph in [pose], centered in the
  /// biggest square that fits [size].
  ///
  /// [monochrome] draws the glyph in black with partial alpha only, no badge
  /// and no shadow -- the layer a themed Android icon is tinted from.
  static void paint(
    Canvas canvas,
    Size size, {
    LogoPose pose = LogoPose.rest,
    LogoShape shape = LogoShape.roundedSquare,
    bool monochrome = false,
    double glyphFraction = badgeGlyphFraction,
  }) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    if (!monochrome) _paintBadge(canvas, side, shape);
    final inset = side * (1 - glyphFraction) / 2;
    canvas.translate(inset, inset);
    canvas.scale(side * glyphFraction / unit);
    _paintGlyph(canvas, pose, monochrome);
    canvas.restore();
  }

  static void _paintBadge(Canvas canvas, double side, LogoShape shape) {
    if (shape == LogoShape.none) return;
    final rect = Offset.zero & Size.square(side);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientMid, gradientEnd],
        stops: [0, gradientMidStop, 1],
      ).createShader(rect);
    if (shape == LogoShape.roundedSquare) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(side * 0.22)), paint);
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  static void _paintGlyph(Canvas canvas, LogoPose pose, bool mono) {
    Paint fill(Color color, double alpha) => Paint()
      ..isAntiAlias = true
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));

    final ink = mono ? const Color(0xFF000000) : null;

    // Mountain: pops in from the base and squashes into it on impact.
    canvas.save();
    canvas.translate(mountainPivot.dx, mountainPivot.dy);
    canvas.scale(
        pose.mountainScale, pose.mountainScale * pose.mountainSquash);
    canvas.translate(-mountainPivot.dx, -mountainPivot.dy);
    final ma = pose.mountainAlpha;
    canvas.drawPath(
        _backPeakPath,
        fill(ink ?? rock, (mono ? monoBackPeakAlpha : backPeakAlpha) * ma));
    canvas.drawPath(
        _frontPeakPath,
        fill(ink ?? rock, (mono ? monoFrontPeakAlpha : frontPeakAlpha) * ma));
    canvas.drawPath(_backSnowPath, fill(ink ?? snow, 0.9 * ma));
    canvas.drawPath(_frontSnowPath, fill(ink ?? snow, ma));
    canvas.restore();

    // Barbell, with a soft drop shadow so it lifts off the mountain.
    canvas.save();
    canvas.translate(0, pose.barbellDy);
    final ba = pose.barbellAlpha;
    if (!mono) {
      canvas.drawPath(
          _barbellShadowPath, fill(const Color(0xFF000000), shadowAlpha * ba));
    }
    canvas.drawPath(_barbellPath, fill(ink ?? iron, ba));
    canvas.restore();

    // Glint beside the summit.
    if (pose.sparkScale > 0.001) {
      canvas.save();
      canvas.translate(sparkAnchor.dx, sparkAnchor.dy);
      canvas.rotate(pose.sparkTurn);
      canvas.scale(pose.sparkScale);
      canvas.drawPath(_sparkPath, fill(ink ?? snow, 1));
      canvas.restore();
    }
  }
}

/// The badge behind the glyph.
enum LogoShape {
  /// Glyph only, transparent background.
  none,

  /// Full-bleed square (Android adaptive background, iOS, maskable web icons
  /// -- the platform applies its own mask).
  square,

  /// Rounded square (in-app badge, legacy Android PNGs, favicon, .ico).
  roundedSquare,
}

/// One frame of the logo's motion; see [IronpeakMark.poseAt].
@immutable
class LogoPose {
  const LogoPose({
    this.mountainAlpha = 1,
    this.mountainScale = 1,
    this.mountainSquash = 1,
    this.barbellDy = 0,
    this.barbellAlpha = 1,
    this.sparkScale = 0,
    this.sparkTurn = 0,
  });

  /// The resting logo: what a static icon shows.
  static const LogoPose rest = LogoPose();

  final double mountainAlpha;
  final double mountainScale;

  /// Extra vertical scale of the mountain around its base (1 = none).
  final double mountainSquash;

  /// Barbell offset from its resting height, in logo units (negative = up).
  final double barbellDy;
  final double barbellAlpha;

  /// 0 hides the glint; ~1 is full size.
  final double sparkScale;

  /// Glint rotation, radians.
  final double sparkTurn;
}

/// The Ironpeak badge, alive: pops in and drops its barbell once, then does a
/// rep forever -- the closest an app can get to the iOS Clock icon's moving
/// hands, since neither Android nor iOS lets a third-party launcher icon
/// animate.
///
/// Honors the OS "remove animations" setting (shows the resting pose), only
/// repaints its own tiny canvas, and pauses with its route/tab like any other
/// ticker. With [replayOnTap] a tap restarts the intro.
class AnimatedIronpeakLogo extends StatefulWidget {
  const AnimatedIronpeakLogo({
    super.key,
    this.size = 96,
    this.replayOnTap = false,
  });

  final double size;
  final bool replayOnTap;

  @override
  State<AnimatedIronpeakLogo> createState() => _AnimatedIronpeakLogoState();
}

class _AnimatedIronpeakLogoState extends State<AnimatedIronpeakLogo>
    with SingleTickerProviderStateMixin {
  static const double _total =
      IronpeakMark.introSeconds + IronpeakMark.loopSeconds;

  // The controller's value *is* the timeline position, in seconds.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    upperBound: _total,
    duration: _seconds(_total),
  );

  bool _reduceMotion = false;

  static Duration _seconds(double s) =>
      Duration(microseconds: (s * Duration.microsecondsPerSecond).round());

  void _play() {
    if (_reduceMotion) {
      _controller.value = IronpeakMark.introSeconds; // resting pose
      return;
    }
    _controller.forward(from: 0).then((_) {
      if (!mounted || _reduceMotion) return;
      _controller.repeat(
        min: IronpeakMark.introSeconds,
        max: _total,
        period: _seconds(IronpeakMark.loopSeconds),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion || !_controller.isAnimating) {
      _reduceMotion = reduce;
      _controller.stop();
      _play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget logo = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _LogoPainter(_controller),
      ),
    );
    if (widget.replayOnTap) {
      logo = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _controller.stop();
          _play();
        },
        child: logo,
      );
    }
    // Decorative -- the app name always sits next to it as text.
    return ExcludeSemantics(child: logo);
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    IronpeakMark.paint(canvas, size, pose: IronpeakMark.poseAt(clock.value));
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.clock != clock;
}
