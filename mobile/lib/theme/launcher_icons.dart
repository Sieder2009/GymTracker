import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// The home-screen icon's color system, and the single source of truth for
/// which launcher icons exist, what they are called on each platform, and
/// which one fits the app's current appearance.
///
/// An icon is a flat tile plus the Ironpeak glyph, both in the app's accent
/// family ([IconHue]) and following its mode ([IconBackdrop]): light = an
/// accent-colored tile with a white glyph, dark = a near-black tile with the
/// glyph in the accent -- the same pair iOS 18 uses for its default and
/// dark icons. Android can only switch between icons that are declared ahead of
/// time -- one `<activity-alias>` per variant in
/// `android/app/src/release/AndroidManifest.xml`, which
/// `tool/generate_icons.dart` writes from [LauncherIcons.all] -- so an
/// arbitrary accent picked in Settings is snapped to the nearest [IconHue].
enum IconBackdrop { light, dark }

/// The accent color family. [graphite] is the neutral one (a white tile
/// with a near-black glyph in light mode, a near-white glyph in dark mode)
/// for grey or barely saturated accents.
enum IconHue { blue, teal, purple, amber, green, red, pink, graphite }

@immutable
class LauncherIconVariant {
  const LauncherIconVariant(this.backdrop, this.hue);

  final IconBackdrop backdrop;
  final IconHue hue;

  /// Stable id such as `dark_teal`. It is part of resource and component
  /// names on every platform, so it must never change once shipped.
  String get id => '${backdrop.name}_${hue.name}';

  /// The tile behind the glyph.
  Color get background => LauncherIcons.backgroundColor(hue, backdrop);

  Color get glyph => LauncherIcons.glyphColor(hue, backdrop);

  /// The Android launcher component for this variant: an `<activity-alias>`
  /// targeting [LauncherIcons.androidActivity], relative to the application
  /// id. The default variant keeps the name the real launcher activity had
  /// before adaptive icons existed, so home-screen shortcuts made by older
  /// versions still resolve after the update.
  String get androidAlias =>
      this == LauncherIcons.defaultVariant ? '.MainActivity' : '.LauncherIcon_$id';

  /// The variant's adaptive icon, `@mipmap/<androidIcon>`.
  String get androidIcon => 'ic_launcher_$id';

  @override
  bool operator ==(Object other) =>
      other is LauncherIconVariant &&
      other.backdrop == backdrop &&
      other.hue == hue;

  @override
  int get hashCode => Object.hash(backdrop, hue);

  @override
  String toString() => 'LauncherIconVariant($id)';
}

abstract final class LauncherIcons {
  /// The app's own backgrounds ([AppColors.light] / [AppColors.dark] `bg`):
  /// the dark icons' tile, and what the launch animation plays on.
  static const Color lightBackdrop = Color(0xFFF5F5F7);
  static const Color darkBackdrop = Color(0xFF101114);

  /// The light graphite tile: white, so a near-black glyph can sit on it.
  static const Color _graphiteLightTile = Color(0xFFFFFFFF);

  /// The real Flutter activity every launcher alias targets, relative to the
  /// application id. Release builds hide its own launcher entry and show
  /// exactly one alias instead; debug/profile builds keep it as the plain
  /// launcher activity because `flutter run` only launches `<activity>`
  /// elements.
  static const String androidActivity = '.IronpeakActivity';

  /// What a fresh install shows before the app has ever run, and what the
  /// icon falls back to when adaptive icons are switched off.
  static const LauncherIconVariant defaultVariant =
      LauncherIconVariant(IconBackdrop.light, IconHue.blue);

  // Accent per hue: (light mode, dark mode). The Settings accent presets,
  // except that teal/amber/green get a slightly deeper light-mode shade so
  // a white glyph keeps at least 3:1 contrast on that tile (and the shade
  // on the app's light background, where the launch animation plays).
  static const Map<IconHue, (Color, Color)> _accents = {
    IconHue.blue: (Color(0xFF2F6FEB), Color(0xFF5588FF)),
    IconHue.teal: (Color(0xFF009B78), Color(0xFF1FD6A8)),
    IconHue.purple: (Color(0xFF6D5CE8), Color(0xFF9585FF)),
    IconHue.amber: (Color(0xFFBA7C00), Color(0xFFE0A83A)),
    IconHue.green: (Color(0xFF009C60), Color(0xFF35C98A)),
    IconHue.red: (Color(0xFFE24B4A), Color(0xFFE24B4A)),
    IconHue.pink: (Color(0xFFD4537E), Color(0xFFD4537E)),
    IconHue.graphite: (Color(0xFF16171B), Color(0xFFF2F2F4)),
  };

  /// The hue's accent shade for [backdrop]'s mode.
  static Color accentColor(IconHue hue, IconBackdrop backdrop) {
    final (light, dark) = _accents[hue]!;
    return backdrop == IconBackdrop.dark ? dark : light;
  }

  static Color backgroundColor(IconHue hue, IconBackdrop backdrop) {
    if (backdrop == IconBackdrop.dark) return darkBackdrop;
    return hue == IconHue.graphite ? _graphiteLightTile : accentColor(hue, backdrop);
  }

  static Color glyphColor(IconHue hue, IconBackdrop backdrop) {
    if (backdrop == IconBackdrop.dark || hue == IconHue.graphite) {
      return accentColor(hue, backdrop);
    }
    return const Color(0xFFFFFFFF);
  }

  /// Every variant, light backdrop first. Each one becomes a launcher alias
  /// on Android, so variants may be added but never removed or renamed: an
  /// update that drops the alias a phone currently has enabled leaves the
  /// app without any launcher entry (test/launcher_icons_test.dart pins the
  /// shipped names).
  static final List<LauncherIconVariant> all = List.unmodifiable([
    for (final backdrop in IconBackdrop.values)
      for (final hue in IconHue.values) LauncherIconVariant(backdrop, hue),
  ]);

  static LauncherIconVariant? byId(String id) {
    for (final variant in all) {
      if (variant.id == id) return variant;
    }
    return null;
  }

  static LauncherIconVariant? byAndroidAlias(String alias) {
    for (final variant in all) {
      if (variant.androidAlias == alias) return variant;
    }
    return null;
  }

  /// A custom background darker than this (relative luminance, ~L* 50)
  /// gets the dark backdrop.
  static const double _darkBackgroundLuminance = 0.18;

  /// The variant matching the app's appearance: the backdrop follows the
  /// theme mode, the glyph the accent color. Arguments mirror
  /// ThemeProvider (`mode`, `customBase`) and AppearanceProvider (`accent`,
  /// `bg`); a null accent means the theme's default accent.
  static LauncherIconVariant forAppearance({
    required String themeMode,
    String customBase = 'light',
    Color? accent,
    Color? background,
  }) {
    final backdrop = backdropFor(
        themeMode: themeMode, customBase: customBase, background: background);
    final color = accent ??
        (backdrop == IconBackdrop.dark
            ? AppColors.dark.accent
            : AppColors.light.accent);
    return LauncherIconVariant(backdrop, nearestHue(color));
  }

  /// Whether the app currently looks light or dark: the theme mode, or in
  /// custom mode the brightness of its background. Also decides the
  /// Android launch screen's day/night copy (LaunchScreenService).
  static IconBackdrop backdropFor({
    required String themeMode,
    String customBase = 'light',
    Color? background,
  }) {
    if (themeMode == 'dark') return IconBackdrop.dark;
    if (themeMode != 'custom') return IconBackdrop.light;
    if (background != null) {
      return background.computeLuminance() < _darkBackgroundLuminance
          ? IconBackdrop.dark
          : IconBackdrop.light;
    }
    return customBase == 'dark' ? IconBackdrop.dark : IconBackdrop.light;
  }

  /// Below this OKLCH chroma a color counts as grey and maps to
  /// [IconHue.graphite] (blue-grey and brown included; the least saturated
  /// accent preset is at ~0.13).
  static const double _neutralChroma = 0.06;

  /// The [IconHue] whose accent colors are closest in hue (OKLCH hue angle,
  /// lightness ignored) to [color], or [IconHue.graphite] for greys.
  static IconHue nearestHue(Color color) {
    final (chroma, hueAngle) = _oklchChromaHue(color);
    if (chroma < _neutralChroma) return IconHue.graphite;
    var best = IconHue.blue;
    var bestDistance = double.infinity;
    for (final hue in IconHue.values) {
      if (hue == IconHue.graphite) continue;
      final distance = _angleDistance(hueAngle, _anchorAngles[hue]!);
      if (distance < bestDistance) {
        best = hue;
        bestDistance = distance;
      }
    }
    return best;
  }

  // Each hue's anchor angle: the circular mean of its two accent shades.
  static final Map<IconHue, double> _anchorAngles = {
    for (final hue in IconHue.values)
      if (hue != IconHue.graphite)
        hue: _circularMean([
          _oklchChromaHue(accentColor(hue, IconBackdrop.light)).$2,
          _oklchChromaHue(accentColor(hue, IconBackdrop.dark)).$2,
        ]),
  };

  static double _angleDistance(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  static double _circularMean(List<double> degrees) {
    var x = 0.0;
    var y = 0.0;
    for (final d in degrees) {
      x += math.cos(d * math.pi / 180);
      y += math.sin(d * math.pi / 180);
    }
    final mean = math.atan2(y, x) * 180 / math.pi;
    return mean < 0 ? mean + 360 : mean;
  }

  /// OKLCH chroma and hue angle (degrees, 0..360) of an sRGB color.
  static (double, double) _oklchChromaHue(Color color) {
    final argb = color.toARGB32();
    double linear(int channel) {
      final c = channel / 255;
      return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linear((argb >> 16) & 0xFF);
    final g = linear((argb >> 8) & 0xFF);
    final b = linear(argb & 0xFF);
    double cbrt(double v) => math.pow(v, 1 / 3).toDouble();
    final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    final labA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final labB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    final chroma = math.sqrt(labA * labA + labB * labB);
    var hue = math.atan2(labB, labA) * 180 / math.pi;
    if (hue < 0) hue += 360;
    return (chroma, hue);
  }
}
