import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../theme/app_colors.dart';
import '../theme/launcher_icons.dart';

/// The Ironpeak mark -- a single summit standing on a barbell ("iron" +
/// "peak"), flat and in one color -- and its motion, in one place. This file
/// is the single source of truth: [AnimatedIronpeakLogo] draws it live, and
/// `tool/generate_icons.dart` renders every static asset (the 16 Android
/// launcher variants, the themed monochrome layer, the animated launch icon,
/// web/Windows/iOS/macOS icons) from the very same path strings and timing,
/// so the launcher icon, the splash animation and the in-app logo can never
/// drift apart.
///
/// The glyph lives in a 100x100 "logo unit" box and every shape stays inside
/// the circle of radius 50 around (50, 50), in every frame of the motion too
/// -- that circle is what maps onto the 66dp safe zone of Android's 108dp
/// adaptive-icon canvas, i.e. what no launcher mask can ever crop.
///
/// One color only, so the same shapes double as the Android 13+ themed icon
/// and can take any accent: the backdrop/glyph colors come from
/// [LauncherIconVariant] (launcher) or the live theme (in-app).
abstract final class IronpeakMark {
  static const double unit = 100;

  /// Glyph box as a fraction of the full adaptive canvas: 66dp of 108dp.
  static const double launcherGlyphFraction = 66 / 108;

  /// Glyph box as a fraction of the part of the adaptive canvas a launcher
  /// actually shows (the 72dp inside every mask) -- for previews that should
  /// look exactly like the home-screen icon.
  static const double maskedGlyphFraction = 66 / 72;

  /// Where nothing masks the icon (in-app badge, favicon, .ico, iOS/macOS).
  static const double badgeGlyphFraction = 0.72;

  // --- geometry (SVG path syntax, logo units) --------------------------
  //
  // Plain absolute SVG path data on purpose: Android's VectorDrawable
  // `pathData` parses the identical syntax, so the generator pastes these
  // strings straight into the XML.

  /// The bar, a pill across the whole mark: the horizon the summit stands on.
  static const String bar =
      'M10,53H90A4,4 0 0 1 94,57V57A4,4 0 0 1 90,61H10A4,4 0 0 1 6,57V57A4,4 0 0 1 10,53Z';

  /// Both plates, one subpath each.
  static const String plates =
      'M15,38H17A4,4 0 0 1 21,42V72A4,4 0 0 1 17,76H15A4,4 0 0 1 11,72V42A4,4 0 0 1 15,38Z'
      'M83,38H85A4,4 0 0 1 89,42V72A4,4 0 0 1 85,76H83A4,4 0 0 1 79,72V42A4,4 0 0 1 83,38Z';

  /// The summit: a gentle west face up to a rounded top, a steeper east face
  /// down. Its base sits inside the bar.
  static const String peak =
      'M48.91,19.12A4,4 0 0 1 56.12,19.59L72.5,60.5L25.81,60.5Z';

  /// The bar's center line: the bar grows from (50, barCenterY) and the
  /// plates snap open from it.
  static const double barCenterY = 57;

  /// The bar's bottom edge. The summit is clipped below it, so it can rise
  /// from behind the bar (and sink back behind it) like a sunrise.
  static const double horizonY = 61;

  // Parsed once; paths are only ever drawn, never mutated.
  static final Path _barPath = parseSvgPathData(bar);
  static final Path _platesPath = parseSvgPathData(plates);
  static final Path _peakPath = parseSvgPathData(peak);

  // --- motion ----------------------------------------------------------
  //
  // A pure function of time, so the live widget, the preview sheet and the
  // Android launch animation (res/drawable*/ic_splash_animated.xml, which
  // generate_icons.dart writes from these same numbers and Android's own
  // interpolators) all play one script:
  //
  //  * intro -- the bar grows out from its center, the plates snap open
  //             with a little overshoot, and the summit rises from behind
  //             the bar.
  //  * loop  -- a calm breath: the summit sinks a few units behind the bar
  //             and rises again, then rests.

  static const double introSeconds = 0.9;
  static const double loopSeconds = 3.6;

  /// How far below its resting place the summit starts: far enough that it
  /// is entirely hidden behind the horizon at t = 0.
  static const double peakRise = 46;

  /// How deep the summit sinks in the loop.
  static const double breathDepth = 7;

  // Intro timeline, seconds: (start, duration). The splash generator turns
  // these into Android animators, so keep them in sync with the curves
  // named next to them.
  static const (double, double) barGrow = (0.0, 0.36); // fast_out_slow_in
  static const (double, double) platesSnap = (0.18, 0.42); // overshoot
  static const (double, double) peakRiseTiming = (0.32, 0.58); // fast_out_slow_in

  // Loop timeline, seconds after the intro: (start, duration).
  static const (double, double) breathDown = (1.4, 0.5); // accelerate_decelerate
  static const (double, double) breathUp = (2.1, 0.8); // decelerate

  /// The pose at [seconds] since the logo appeared. Past the intro it
  /// repeats every [loopSeconds].
  static LogoPose poseAt(double seconds) {
    if (seconds < introSeconds) return _intro(seconds);
    return _loop((seconds - introSeconds) % loopSeconds);
  }

  static LogoPose _intro(double t) {
    return LogoPose(
      barScale: Curves.fastOutSlowIn.transform(_seg(t, barGrow)),
      plateScale: overshoot(_seg(t, platesSnap)),
      peakDy: peakRise *
          (1 - Curves.fastOutSlowIn.transform(_seg(t, peakRiseTiming))),
    );
  }

  static LogoPose _loop(double u) {
    final down = accelerateDecelerate(_seg(u, breathDown));
    final up = decelerate(_seg(u, breathUp));
    return LogoPose(peakDy: breathDepth * (down - up));
  }

  static double _seg(double t, (double, double) timing) {
    final (start, seconds) = timing;
    return math.min(1.0, math.max(0.0, (t - start) / seconds));
  }

  // Android's interpolators, verbatim, so the in-app motion matches the
  // launch animation exactly (fast_out_slow_in is Curves.fastOutSlowIn).

  /// android.view.animation.OvershootInterpolator, default tension 2.
  static double overshoot(double t) {
    const tension = 2.0;
    final s = t - 1;
    return s * s * ((tension + 1) * s + tension) + 1;
  }

  /// android.view.animation.AccelerateDecelerateInterpolator.
  static double accelerateDecelerate(double t) =>
      math.cos((t + 1) * math.pi) / 2 + 0.5;

  /// android.view.animation.DecelerateInterpolator, factor 1.
  static double decelerate(double t) => 1 - (1 - t) * (1 - t);

  // --- painting --------------------------------------------------------

  /// Paints the badge (per [shape], filled with [background]) and the glyph
  /// in [glyph] color and [pose], centered in the biggest square that fits
  /// [size].
  ///
  /// [border] adds a hairline around a rounded badge (a light badge on a
  /// light page needs one). [monochrome] draws the glyph alone in black, no
  /// badge -- the layer a themed Android icon is tinted from.
  static void paint(
    Canvas canvas,
    Size size, {
    LogoPose pose = LogoPose.rest,
    LogoShape shape = LogoShape.roundedSquare,
    Color background = LauncherIcons.lightBackdrop,
    Color glyph = const Color(0xFF2F6FEB),
    Color? border,
    double cornerFraction = 0.22,
    bool monochrome = false,
    double glyphFraction = badgeGlyphFraction,
  }) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    if (!monochrome) {
      _paintBadge(canvas, side, shape, background, border, cornerFraction);
    }
    final inset = side * (1 - glyphFraction) / 2;
    canvas.translate(inset, inset);
    canvas.scale(side * glyphFraction / unit);
    _paintGlyph(canvas, pose, monochrome ? const Color(0xFF000000) : glyph);
    canvas.restore();
  }

  static void _paintBadge(
    Canvas canvas,
    double side,
    LogoShape shape,
    Color background,
    Color? border,
    double cornerFraction,
  ) {
    if (shape == LogoShape.none) return;
    final rect = Offset.zero & Size.square(side);
    final fill = Paint()..color = background;
    if (shape == LogoShape.square) {
      canvas.drawRect(rect, fill);
      return;
    }
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(side * cornerFraction));
    canvas.drawRRect(rrect, fill);
    if (border != null) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border,
      );
    }
  }

  static void _paintGlyph(Canvas canvas, LogoPose pose, Color color) {
    final fill = Paint()
      ..isAntiAlias = true
      ..color = color;

    // Summit: rises from (and sinks back) behind the bar, so it is clipped
    // at the bar's bottom edge.
    if (pose.peakDy < peakRise) {
      canvas.save();
      canvas.clipRect(const Rect.fromLTRB(-unit, -unit, 2 * unit, horizonY));
      canvas.translate(0, pose.peakDy);
      canvas.drawPath(_peakPath, fill);
      canvas.restore();
    }

    // Bar: grows out from its center.
    if (pose.barScale > 0.001) {
      canvas.save();
      canvas.translate(50, barCenterY);
      canvas.scale(pose.barScale, 1);
      canvas.translate(-50, -barCenterY);
      canvas.drawPath(_barPath, fill);
      canvas.restore();
    }

    // Plates: snap open from the bar's center line.
    if (pose.plateScale > 0.001) {
      canvas.save();
      canvas.translate(0, barCenterY);
      canvas.scale(1, pose.plateScale);
      canvas.translate(0, -barCenterY);
      canvas.drawPath(_platesPath, fill);
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

  /// Rounded square (in-app badge, launcher preview, favicon, .ico).
  roundedSquare,
}

/// One frame of the logo's motion; see [IronpeakMark.poseAt].
@immutable
class LogoPose {
  const LogoPose({
    this.barScale = 1,
    this.plateScale = 1,
    this.peakDy = 0,
  });

  /// The resting logo: what a static icon shows.
  static const LogoPose rest = LogoPose();

  /// Horizontal scale of the bar around its center (0 = not there yet).
  final double barScale;

  /// Vertical scale of the plates around the bar's center line; overshoots
  /// slightly past 1 while they snap open.
  final double plateScale;

  /// Summit offset below its resting place, in logo units (0 = rest,
  /// [IronpeakMark.peakRise] = entirely behind the bar).
  final double peakDy;
}

/// The app's palette for [context], or the stock light/dark one when a
/// theme without the [AppColors] extension is in charge (tests, previews).
AppColors _colorsOf(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<AppColors>() ??
      (theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light);
}

/// The Ironpeak badge, alive: builds itself once (bar, plates, summit
/// rising), then breathes calmly forever -- the closest an app can get to a
/// moving icon, since neither Android nor iOS lets a third-party launcher
/// icon animate.
///
/// Follows the theme: the badge takes the card color with a hairline border
/// and the glyph the accent, so it shows the user's exact colors in light,
/// dark and custom mode ([background]/[glyph] override them). Honors the OS
/// "remove animations" setting (shows the resting pose), only repaints its
/// own tiny canvas, and pauses with its route/tab like any other ticker.
/// With [replayOnTap] a tap restarts the intro.
class AnimatedIronpeakLogo extends StatefulWidget {
  const AnimatedIronpeakLogo({
    super.key,
    this.size = 96,
    this.replayOnTap = false,
    this.background,
    this.glyph,
  });

  final double size;
  final bool replayOnTap;
  final Color? background;
  final Color? glyph;

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
    final colors = _colorsOf(context);
    Widget logo = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _LogoPainter(
          _controller,
          background: widget.background ?? colors.card,
          glyph: widget.glyph ?? colors.accent,
          border: colors.line,
        ),
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
  _LogoPainter(
    this.clock, {
    required this.background,
    required this.glyph,
    required this.border,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final Color background;
  final Color glyph;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    IronpeakMark.paint(
      canvas,
      size,
      pose: IronpeakMark.poseAt(clock.value),
      background: background,
      glyph: glyph,
      border: border,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.clock != clock ||
      old.background != background ||
      old.glyph != glyph ||
      old.border != border;
}

/// What the home screen shows for [variant]: the visible part of the
/// adaptive icon under a rounded mask, glyph at its real launcher scale.
/// Static on purpose -- launcher icons can't move.
class LauncherIconPreview extends StatelessWidget {
  const LauncherIconPreview({super.key, required this.variant, this.size = 44});

  final LauncherIconVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsOf(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LauncherIconPainter(variant, border: colors.line),
      ),
    );
  }
}

class _LauncherIconPainter extends CustomPainter {
  _LauncherIconPainter(this.variant, {required this.border});

  final LauncherIconVariant variant;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    IronpeakMark.paint(
      canvas,
      size,
      background: variant.background,
      glyph: variant.glyph,
      border: border,
      cornerFraction: 0.3,
      glyphFraction: IronpeakMark.maskedGlyphFraction,
    );
  }

  @override
  bool shouldRepaint(covariant _LauncherIconPainter old) =>
      old.variant != variant || old.border != border;
}
