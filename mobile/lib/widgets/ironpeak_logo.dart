import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../theme/app_colors.dart';
import '../theme/launcher_icons.dart';

/// The Kilo mark -- a loaded barbell, flat and in one color -- and its motion,
/// in one place. This file is the single source of truth:
/// [AnimatedIronpeakLogo] draws it live, and `tool/generate_icons.dart`
/// renders every static asset (the 16 Android launcher variants, the themed
/// monochrome layer, the animated launch icon, web/Windows/iOS/macOS icons)
/// from the very same path strings and timing, so the launcher icon, the
/// splash animation and the in-app logo can never drift apart. (The class
/// names still carry the app's former name, Ironpeak; only the user-facing
/// name changed.)
///
/// The glyph lives in a 100x100 "logo unit" box and every shape stays inside
/// the circle of radius 50 around (50, 50) once the barbell has landed, the
/// rep included -- that circle is what maps onto the 66dp safe zone of
/// Android's 108dp adaptive-icon canvas, i.e. what no launcher mask can ever
/// crop.
///
/// One color only, so the same shapes double as the Android 13+ themed icon
/// and can take any accent: the tile/glyph colors come from
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

  /// The bar: the grip shaft in the middle and the thicker sleeves the
  /// plates sit on, out past the lock collars on both ends -- an Olympic
  /// bar, seen from the front. Sleeve ends are flat with a small chamfer
  /// like a real one, and the inner ends of shaft and sleeves hide under
  /// the shoulders, so no rounded end shows where they meet.
  static const String bar =
      'M33,47H67A1,1 0 0 1 68,48V52A1,1 0 0 1 67,53H33A1,1 0 0 1 32,52V48A1,1 0 0 1 33,47Z'
      'M4,46H32A1.5,1.5 0 0 1 33.5,47.5V52.5A1.5,1.5 0 0 1 32,54H4A1.5,1.5 0 0 1 2.5,52.5V47.5A1.5,1.5 0 0 1 4,46Z'
      'M68,46H96A1.5,1.5 0 0 1 97.5,47.5V52.5A1.5,1.5 0 0 1 96,54H68A1.5,1.5 0 0 1 66.5,52.5V47.5A1.5,1.5 0 0 1 68,46Z';

  /// The load, mirrored on both sides, from the middle out: the inner
  /// shoulder, two big plates, one smaller plate, the lock collar -- few,
  /// solid pieces with even gaps, so the stack still reads at launcher
  /// size. Real plates have barely rounded edges, so the corners stay tight.
  static const String plates =
      'M32.5,42H33.5A1,1 0 0 1 34.5,43V57A1,1 0 0 1 33.5,58H32.5A1,1 0 0 1 31.5,57V43A1,1 0 0 1 32.5,42Z'
      'M66.5,42H67.5A1,1 0 0 1 68.5,43V57A1,1 0 0 1 67.5,58H66.5A1,1 0 0 1 65.5,57V43A1,1 0 0 1 66.5,42Z'
      'M24.3,21H28.8A1.5,1.5 0 0 1 30.3,22.5V77.5A1.5,1.5 0 0 1 28.8,79H24.3A1.5,1.5 0 0 1 22.8,77.5V22.5A1.5,1.5 0 0 1 24.3,21Z'
      'M71.2,21H75.7A1.5,1.5 0 0 1 77.2,22.5V77.5A1.5,1.5 0 0 1 75.7,79H71.2A1.5,1.5 0 0 1 69.7,77.5V22.5A1.5,1.5 0 0 1 71.2,21Z'
      'M15.6,21H20.1A1.5,1.5 0 0 1 21.6,22.5V77.5A1.5,1.5 0 0 1 20.1,79H15.6A1.5,1.5 0 0 1 14.1,77.5V22.5A1.5,1.5 0 0 1 15.6,21Z'
      'M79.9,21H84.4A1.5,1.5 0 0 1 85.9,22.5V77.5A1.5,1.5 0 0 1 84.4,79H79.9A1.5,1.5 0 0 1 78.4,77.5V22.5A1.5,1.5 0 0 1 79.9,21Z'
      'M9.6,31H11.7A1.2,1.2 0 0 1 12.9,32.2V67.8A1.2,1.2 0 0 1 11.7,69H9.6A1.2,1.2 0 0 1 8.4,67.8V32.2A1.2,1.2 0 0 1 9.6,31Z'
      'M88.3,31H90.4A1.2,1.2 0 0 1 91.6,32.2V67.8A1.2,1.2 0 0 1 90.4,69H88.3A1.2,1.2 0 0 1 87.1,67.8V32.2A1.2,1.2 0 0 1 88.3,31Z'
      'M5.6,42.5H6.2A1,1 0 0 1 7.2,43.5V56.5A1,1 0 0 1 6.2,57.5H5.6A1,1 0 0 1 4.6,56.5V43.5A1,1 0 0 1 5.6,42.5Z'
      'M93.8,42.5H94.4A1,1 0 0 1 95.4,43.5V56.5A1,1 0 0 1 94.4,57.5H93.8A1,1 0 0 1 92.8,56.5V43.5A1,1 0 0 1 93.8,42.5Z';

  /// Every shape of the mark, in drawing order, with the names the launch
  /// animation targets them by.
  static const List<(String, String)> parts = [('bar', bar), ('plates', plates)];

  /// Bottom middle of the big plates: the barbell squashes into the floor
  /// around it when it lands.
  static const Offset foot = Offset(50, 79);

  // Parsed once; paths are only ever drawn, never mutated.
  static final List<Path> _paths = [for (final (_, data) in parts) parseSvgPathData(data)];

  // --- motion ----------------------------------------------------------
  //
  // A pure function of time, so the live widget, the preview sheet and the
  // Android launch animation (res/drawable*/ic_splash_animated.xml, which
  // generate_icons.dart writes from these same numbers and Android's own
  // interpolators) all play one script:
  //
  //  * intro -- the barbell is dropped: it falls in, bounces on the floor
  //             (Android's BounceInterpolator curve, so the launch
  //             animation matches exactly) and squashes a little on the
  //             first impact.
  //  * loop  -- one calm rep: lift, short hold, controlled lowering, rest.
  //             In-app only; a launch animation plays once.

  static const double introSeconds = 0.72;
  static const double loopSeconds = 3.6;

  /// How far above its resting place the barbell starts falling.
  static const double dropHeight = 60;

  /// The fall: (start, duration) in seconds, bounce_interpolator.
  static const (double, double) dropTiming = (0.08, 0.6);

  /// The fade-in at the start of the fall, linear.
  static const (double, double) fadeTiming = (0.08, 0.1);

  /// How far the bell squashes into the floor on the first impact.
  static const double squashDepth = 0.06;
  static const double squashDownSeconds = 0.07;
  static const double squashUpSeconds = 0.12;

  /// The BounceInterpolator's first impact: where the falling barbell first
  /// reaches the floor and squashes.
  static final double impactSeconds =
      dropTiming.$1 + dropTiming.$2 * (0.3535 / 1.1226);

  /// The rep: how high the barbell is lifted, and (start, duration) in
  /// seconds after the intro of the lift (fast_out_slow_in) and of the
  /// lowering (accelerate_decelerate).
  static const double repHeight = 6;
  static const (double, double) repUp = (1.2, 0.55);
  static const (double, double) repDown = (2.05, 0.75);

  /// The pose at [seconds] since the logo appeared. Past the intro it
  /// repeats every [loopSeconds].
  static LogoPose poseAt(double seconds) {
    if (seconds < introSeconds) return _intro(seconds);
    return _loop((seconds - introSeconds) % loopSeconds);
  }

  static LogoPose _intro(double t) {
    final down = decelerate(_seg(t, (impactSeconds, squashDownSeconds)));
    final up = decelerate(_seg(t, (impactSeconds + squashDownSeconds, squashUpSeconds)));
    return LogoPose(
      dropDy: -dropHeight * (1 - bounce(_seg(t, dropTiming))),
      alpha: _seg(t, fadeTiming),
      squash: 1 - squashDepth * down * (1 - up),
    );
  }

  static LogoPose _loop(double u) {
    final up = Curves.fastOutSlowIn.transform(_seg(u, repUp));
    final down = accelerateDecelerate(_seg(u, repDown));
    return LogoPose(dropDy: -repHeight * (up - down));
  }

  static double _seg(double t, (double, double) timing) {
    final (start, seconds) = timing;
    return math.min(1.0, math.max(0.0, (t - start) / seconds));
  }

  // Android's interpolators, verbatim, so the in-app motion matches the
  // launch animation exactly.

  /// android.view.animation.BounceInterpolator.
  static double bounce(double t) {
    double b(double x) => x * x * 8;
    final x = t * 1.1226;
    if (x < 0.3535) return b(x);
    if (x < 0.7408) return b(x - 0.54719) + 0.7;
    if (x < 0.9644) return b(x - 0.8526) + 0.9;
    return b(x - 1.0435) + 0.95;
  }

  /// android.view.animation.DecelerateInterpolator, factor 1.
  static double decelerate(double t) => 1 - (1 - t) * (1 - t);

  /// android.view.animation.AccelerateDecelerateInterpolator.
  static double accelerateDecelerate(double t) =>
      math.cos((t + 1) * math.pi) / 2 + 0.5;

  // --- painting --------------------------------------------------------

  /// Paints the badge (per [shape], filled with [background]) and the glyph
  /// in [glyph] color and [pose], centered in the biggest square that fits
  /// [size].
  ///
  /// [border] adds a hairline around a rounded badge (a dark badge on a
  /// dark page needs one). [monochrome] draws the glyph alone in black, no
  /// badge -- the layer a themed Android icon is tinted from.
  static void paint(
    Canvas canvas,
    Size size, {
    LogoPose pose = LogoPose.rest,
    LogoShape shape = LogoShape.roundedSquare,
    Color background = const Color(0xFF2F6FEB),
    Color glyph = const Color(0xFFFFFFFF),
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
    canvas.save();
    // The falling barbell enters from above the badge, not from outside it.
    canvas.clipRect(Offset.zero & Size.square(side));
    canvas.translate(inset, inset);
    canvas.scale(side * glyphFraction / unit);
    _paintGlyph(canvas, pose, monochrome ? const Color(0xFF000000) : glyph);
    canvas.restore();
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
    if (pose.alpha <= 0.001) return;
    final fill = Paint()
      ..isAntiAlias = true
      ..color = color.withValues(alpha: color.a * pose.alpha.clamp(0.0, 1.0));

    canvas.save();
    // Falling in, or lifted in a rep: the whole barbell moves.
    canvas.translate(0, pose.dropDy);
    // Landing: squashed into the floor around the foot.
    if (pose.squash != 1) {
      canvas.translate(foot.dx, foot.dy);
      canvas.scale(1, pose.squash);
      canvas.translate(-foot.dx, -foot.dy);
    }
    for (final path in _paths) {
      canvas.drawPath(path, fill);
    }
    canvas.restore();
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
    this.dropDy = 0,
    this.alpha = 1,
    this.squash = 1,
  });

  /// The resting logo: what a static icon shows.
  static const LogoPose rest = LogoPose();

  /// Offset of the barbell from its resting place, in logo units
  /// (negative = above it: still falling in, or lifted in a rep).
  final double dropDy;

  /// Opacity of the whole glyph (0 = not there yet).
  final double alpha;

  /// Vertical scale around the foot (1 = none, < 1 = squashed on impact).
  final double squash;
}

/// The app's palette for [context], or the stock light/dark one when a
/// theme without the [AppColors] extension is in charge (tests, previews).
AppColors _colorsOf(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<AppColors>() ??
      (theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light);
}

/// The Kilo badge, alive: the barbell drops in once, then does a calm rep
/// now and then, forever -- the closest an app can get to a
/// moving icon, since neither Android nor iOS lets a third-party launcher
/// icon animate.
///
/// Follows the theme: in a light theme an accent-colored tile with the
/// glyph in the accent's text color, like the launcher icon; in a dark one
/// a card-colored tile (hairline border) with the glyph in the text color
/// (white), like the dark launch screen -- the user's exact colors in
/// light, dark and custom mode ([background]/[glyph] override them).
/// Honors the OS
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget logo = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _LogoPainter(
          _controller,
          background: widget.background ?? (dark ? colors.card : colors.accent),
          glyph: widget.glyph ?? (dark ? colors.txt : colors.onAccent),
          border: dark ? colors.line : null,
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
  final Color? border;

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
