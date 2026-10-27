import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:ironpeak_mobile/theme/launcher_icons.dart';

/// Every Android launcher alias a release has shipped. A phone can have any
/// one of them enabled, and an update that removes that one leaves the app
/// without a launcher entry -- so this list may only ever grow.
const List<String> _shippedAndroidAliases = [
  '.MainActivity',
  '.LauncherIcon_light_teal',
  '.LauncherIcon_light_purple',
  '.LauncherIcon_light_amber',
  '.LauncherIcon_light_green',
  '.LauncherIcon_light_red',
  '.LauncherIcon_light_pink',
  '.LauncherIcon_light_graphite',
  '.LauncherIcon_dark_blue',
  '.LauncherIcon_dark_teal',
  '.LauncherIcon_dark_purple',
  '.LauncherIcon_dark_amber',
  '.LauncherIcon_dark_green',
  '.LauncherIcon_dark_red',
  '.LauncherIcon_dark_pink',
  '.LauncherIcon_dark_graphite',
];

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('LauncherIcons.all', () {
    test('ids, aliases and icon resources are unique', () {
      final all = LauncherIcons.all;
      expect(all, hasLength(IconBackdrop.values.length * IconHue.values.length));
      expect(all.map((v) => v.id).toSet(), hasLength(all.length));
      expect(all.map((v) => v.androidAlias).toSet(), hasLength(all.length));
      expect(all.map((v) => v.androidIcon).toSet(), hasLength(all.length));
    });

    test('never drops a launcher alias that has shipped', () {
      expect(
        LauncherIcons.all.map((v) => v.androidAlias),
        containsAll(_shippedAndroidAliases),
      );
    });

    test('the default variant keeps the pre-alias launcher name', () {
      expect(LauncherIcons.defaultVariant.id, 'light_blue');
      expect(LauncherIcons.defaultVariant.androidAlias, '.MainActivity');
      for (final v in LauncherIcons.all) {
        if (v == LauncherIcons.defaultVariant) continue;
        expect(v.androidAlias, '.LauncherIcon_${v.id}');
      }
    });

    test('names are valid Android resource and component names', () {
      for (final v in LauncherIcons.all) {
        expect(v.androidIcon, matches(RegExp(r'^[a-z][a-z0-9_]*$')));
        expect(v.androidAlias, matches(RegExp(r'^\.[A-Za-z][A-Za-z0-9_]*$')));
      }
    });

    test('byId and byAndroidAlias find every variant', () {
      for (final v in LauncherIcons.all) {
        expect(LauncherIcons.byId(v.id), v);
        expect(LauncherIcons.byAndroidAlias(v.androidAlias), v);
      }
      expect(LauncherIcons.byId('nope'), isNull);
      expect(LauncherIcons.byAndroidAlias('.IronpeakActivity'), isNull);
    });

    test('every glyph keeps at least 3:1 contrast against its backdrop', () {
      for (final v in LauncherIcons.all) {
        expect(_contrast(v.glyph, v.background), greaterThanOrEqualTo(3.0),
            reason: v.id);
      }
    });

    test('the backdrops match the app backgrounds', () {
      expect(LauncherIcons.lightBackdrop, AppColors.light.bg);
      // Not the exact dark bg (see darkBackdrop), but just as black.
      expect(LauncherIcons.darkBackdrop.computeLuminance(), lessThan(0.01));
      expect(AppColors.dark.bg.computeLuminance(), lessThan(0.01));
    });

    test('light icons are accent tiles, dark icons accent glyphs on black', () {
      for (final v in LauncherIcons.all) {
        final accent = LauncherIcons.accentColor(v.hue, v.backdrop);
        if (v.backdrop == IconBackdrop.dark) {
          expect(v.background, LauncherIcons.darkBackdrop, reason: v.id);
          expect(v.glyph, accent, reason: v.id);
        } else if (v.hue == IconHue.graphite) {
          expect(v.glyph, accent, reason: v.id);
        } else {
          expect(v.background, accent, reason: v.id);
          expect(v.glyph, const Color(0xFFFFFFFF), reason: v.id);
        }
      }
    });
  });

  group('LauncherIcons.nearestHue', () {
    test('maps every accent shade back to its own hue', () {
      for (final v in LauncherIcons.all) {
        expect(LauncherIcons.nearestHue(LauncherIcons.accentColor(v.hue, v.backdrop)), v.hue,
            reason: v.id);
      }
    });

    test('maps the Settings accent presets to the matching hue', () {
      const presets = {
        0xFF2F6FEB: IconHue.blue,
        0xFF5588FF: IconHue.blue,
        0xFF0EA884: IconHue.teal,
        0xFF1FD6A8: IconHue.teal,
        0xFF6D5CE8: IconHue.purple,
        0xFF9585FF: IconHue.purple,
        0xFFC98A10: IconHue.amber,
        0xFFE0A83A: IconHue.amber,
        0xFF1FA76A: IconHue.green,
        0xFF35C98A: IconHue.green,
        0xFFE24B4A: IconHue.red,
        0xFFD4537E: IconHue.pink,
      };
      presets.forEach((argb, hue) {
        expect(LauncherIcons.nearestHue(Color(argb)), hue,
            reason: argb.toRadixString(16));
      });
    });

    test('snaps free picks to the closest hue', () {
      const picks = {
        0xFF3F51B5: IconHue.blue, // indigo
        0xFF1A237E: IconHue.blue, // navy
        0xFF00BCD4: IconHue.teal, // cyan
        0xFF9C27B0: IconHue.purple,
        0xFFFF9800: IconHue.amber, // orange
        0xFFFFEB3B: IconHue.amber, // yellow
        0xFF8BC34A: IconHue.green, // light green
        0xFFF44336: IconHue.red,
        0xFFE91E63: IconHue.pink,
      };
      picks.forEach((argb, hue) {
        expect(LauncherIcons.nearestHue(Color(argb)), hue,
            reason: argb.toRadixString(16));
      });
    });

    test('treats greys and barely saturated colors as graphite', () {
      for (final color in const [
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0xFF84848C),
        Color(0xFF9E9E9E),
        Color(0xFF607D8B), // blue grey
        Color(0xFF795548), // brown
      ]) {
        expect(LauncherIcons.nearestHue(color), IconHue.graphite, reason: '$color');
      }
    });
  });

  group('LauncherIcons.forAppearance', () {
    test('the default accent is blue in light mode and green in dark mode', () {
      expect(LauncherIcons.forAppearance(themeMode: 'light').id, 'light_blue');
      expect(LauncherIcons.forAppearance(themeMode: 'dark').id, 'dark_green');
    });

    test('custom mode takes the default accent from its base, not its background', () {
      expect(
        LauncherIcons.forAppearance(themeMode: 'custom', background: const Color(0xFF101114)).id,
        'dark_blue',
      );
      expect(
        LauncherIcons.forAppearance(
                themeMode: 'custom', customBase: 'dark', background: const Color(0xFF101114))
            .id,
        'dark_green',
      );
    });

    test('the glyph follows a custom accent', () {
      expect(
        LauncherIcons.forAppearance(themeMode: 'light', accent: const Color(0xFFE24B4A)).id,
        'light_red',
      );
      expect(
        LauncherIcons.forAppearance(themeMode: 'dark', accent: const Color(0xFF9585FF)).id,
        'dark_purple',
      );
    });

    test('custom mode picks the backdrop from its background', () {
      expect(
        LauncherIcons.forAppearance(themeMode: 'custom', background: const Color(0xFF101114))
            .backdrop,
        IconBackdrop.dark,
      );
      expect(
        LauncherIcons.forAppearance(themeMode: 'custom', background: const Color(0xFF44444A))
            .backdrop,
        IconBackdrop.dark,
      );
      expect(
        LauncherIcons.forAppearance(themeMode: 'custom', background: const Color(0xFF84848C))
            .backdrop,
        IconBackdrop.light,
      );
      expect(
        LauncherIcons.forAppearance(themeMode: 'custom', background: const Color(0xFFFFFFFF))
            .backdrop,
        IconBackdrop.light,
      );
    });

    test('custom mode without a background follows its base', () {
      expect(
        LauncherIcons.forAppearance(themeMode: 'custom', customBase: 'dark').id,
        'dark_green',
      );
      expect(
        LauncherIcons.forAppearance(themeMode: 'custom', customBase: 'light').id,
        'light_blue',
      );
    });
  });
}
