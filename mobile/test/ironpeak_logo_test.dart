import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:ironpeak_mobile/theme/launcher_icons.dart';
import 'package:ironpeak_mobile/widgets/ironpeak_logo.dart';
import 'package:path_drawing/path_drawing.dart';

void _expectSame(LogoPose a, LogoPose b, {double tolerance = 1e-9}) {
  expect(a.dropDy, closeTo(b.dropDy, tolerance));
  expect(a.alpha, closeTo(b.alpha, tolerance));
  expect(a.squash, closeTo(b.squash, tolerance));
}

/// Outline points of the whole barbell, sampled every [step] logo units.
List<Offset> _outline({double step = 0.25}) {
  final points = <Offset>[];
  for (final (_, data) in IronpeakMark.parts) {
    for (final metric in parseSvgPathData(data).computeMetrics()) {
      for (var d = 0.0; d <= metric.length; d += step) {
        points.add(metric.getTangentForOffset(d)!.position);
      }
    }
  }
  return points;
}

/// Farthest outline point from the logo's center (50, 50) in [pose], with
/// the same transforms the painter applies: squash around the foot, then
/// the vertical offset (fall or rep).
double _farthestInPose(LogoPose pose) {
  const center = Offset(50, 50);
  var farthest = 0.0;
  for (final p in _outline()) {
    final q = Offset(p.dx, IronpeakMark.foot.dy + (p.dy - IronpeakMark.foot.dy) * pose.squash)
        .translate(0, pose.dropDy);
    farthest = math.max(farthest, (q - center).distance);
  }
  return farthest;
}

void main() {
  const intro = IronpeakMark.introSeconds;
  const loop = IronpeakMark.loopSeconds;

  group('IronpeakMark.poseAt', () {
    test('starts invisible, high above its resting place', () {
      final start = IronpeakMark.poseAt(0);
      expect(start.alpha, 0);
      expect(start.dropDy, -IronpeakMark.dropHeight);
    });

    test('the intro ends at rest and hands over to the loop without a jump', () {
      _expectSame(IronpeakMark.poseAt(intro - 1e-6), IronpeakMark.poseAt(intro),
          tolerance: 0.01);
      _expectSame(IronpeakMark.poseAt(intro), LogoPose.rest);
    });

    test('the barbell falls from above and never sinks below the floor', () {
      for (var t = 0.0; t <= intro; t += 0.002) {
        // Android's BounceInterpolator itself ends a hair past 1 (1.00005).
        expect(IronpeakMark.poseAt(t).dropDy, lessThanOrEqualTo(0.01), reason: 't=$t');
      }
    });

    test('it squashes into the floor exactly on the first impact', () {
      var least = 1.0;
      var at = 0.0;
      for (var t = 0.0; t <= intro; t += 0.001) {
        final squash = IronpeakMark.poseAt(t).squash;
        if (squash < least) {
          least = squash;
          at = t;
        }
      }
      expect(least, closeTo(1 - IronpeakMark.squashDepth, 1e-3));
      expect(at, closeTo(IronpeakMark.impactSeconds + IronpeakMark.squashDownSeconds, 0.002));
      // ... where the falling barbell first touches the floor.
      expect(IronpeakMark.poseAt(IronpeakMark.impactSeconds).dropDy, closeTo(0, 0.05));
    });

    test('the launch animation stays under Android 12\'s 1000 ms', () {
      expect(IronpeakMark.dropTiming.$1 + IronpeakMark.dropTiming.$2, lessThanOrEqualTo(1.0));
      expect(intro, lessThanOrEqualTo(1.0));
    });

    test('the loop repeats exactly', () {
      for (var x = 0.0; x < loop; x += 0.05) {
        _expectSame(IronpeakMark.poseAt(intro + x), IronpeakMark.poseAt(intro + x + loop));
        _expectSame(IronpeakMark.poseAt(intro + x), IronpeakMark.poseAt(intro + x + 7 * loop));
      }
    });

    test('a rep lifts the barbell by repHeight and puts it back down', () {
      var highest = 0.0;
      for (var u = 0.0; u < loop; u += 0.01) {
        final pose = IronpeakMark.poseAt(intro + u);
        expect(pose.alpha, 1);
        expect(pose.squash, 1);
        expect(pose.dropDy, lessThanOrEqualTo(1e-9)); // never below the floor
        highest = math.min(highest, pose.dropDy);
      }
      expect(highest, closeTo(-IronpeakMark.repHeight, 1e-6));
      final (start, seconds) = IronpeakMark.repDown;
      expect(IronpeakMark.poseAt(intro + start + seconds).dropDy, closeTo(0, 1e-9));
    });

    test('the Android interpolator ports start at 0 and end at 1', () {
      for (final curve in [
        IronpeakMark.bounce,
        IronpeakMark.decelerate,
        IronpeakMark.accelerateDecelerate,
      ]) {
        expect(curve(0), closeTo(0, 1e-12));
        expect(curve(1), closeTo(1, 1e-3));
      }
    });
  });

  group('IronpeakMark geometry', () {
    // The circle of radius 50 around (50, 50) is what maps onto the 66dp
    // safe zone of an Android adaptive icon -- the part no launcher mask can
    // crop. Every frame after landing has to stay inside it (while still
    // falling the barbell is above it on purpose, and the mask hides it).
    test('every frame from the landing on, rep included, stays inside the safe zone', () {
      for (var t = IronpeakMark.impactSeconds; t <= intro + loop; t += 0.01) {
        final pose = IronpeakMark.poseAt(t);
        if (pose.dropDy < -0.5) continue; // bouncing back up, still mid-air
        expect(_farthestInPose(pose), lessThanOrEqualTo(50), reason: 't=$t');
      }
    });

    test('the resting glyph keeps some breathing room inside the masks', () {
      expect(_farthestInPose(LogoPose.rest), lessThanOrEqualTo(48));
    });

    test('path data uses only absolute commands both parsers read alike', () {
      // VectorDrawable pathData and path_drawing get the very same strings.
      for (final (_, data) in IronpeakMark.parts) {
        expect(data, matches(RegExp(r'^[MLHVCQAZ0-9., -]+$')));
        expect(parseSvgPathData(data).getBounds().isEmpty, isFalse);
      }
    });

    test('the barbell is symmetric around the middle', () {
      for (final (name, data) in IronpeakMark.parts) {
        final bounds = parseSvgPathData(data).getBounds();
        expect(bounds.left + bounds.right, closeTo(100, 1e-3), reason: name);
      }
    });
  });

  group('AnimatedIronpeakLogo', () {
    Widget host({AppColors colors = AppColors.light}) => MaterialApp(
          theme: ThemeData(extensions: [colors]),
          home: const Scaffold(body: Center(child: AnimatedIronpeakLogo(replayOnTap: true))),
        );

    testWidgets('plays the intro and then keeps looping', (tester) async {
      await tester.pumpWidget(host());
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 300)); // mid-intro
      await tester.pump(const Duration(seconds: 2)); // into the loop
      await tester.pump(const Duration(seconds: 9)); // several loops later
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap replays the intro without errors', (tester) async {
      await tester.pumpWidget(host(colors: AppColors.dark));
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.byType(AnimatedIronpeakLogo));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark: white barbell on a card tile; light: on an accent tile', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true); // resting pose
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      for (final (colors, tile, glyph) in [
        (AppColors.dark, AppColors.dark.card, AppColors.dark.txt),
        (AppColors.light, AppColors.light.accent, AppColors.light.onAccent),
      ]) {
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            brightness: colors == AppColors.dark ? Brightness.dark : Brightness.light,
            extensions: [colors],
          ),
          home: Center(
            child: RepaintBoundary(key: key, child: const AnimatedIronpeakLogo(size: 100)),
          ),
        ));
        await tester.pump(const Duration(seconds: 1)); // past MaterialApp's theme cross-fade
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final data = (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba)))!;
        // Glyph box = 72% of the badge: logo unit u -> 14 + u * 0.72.
        Color at(double ux, double uy) {
          final i = ((14 + uy * 0.72).round() * image.width + (14 + ux * 0.72).round()) * 4;
          return Color.fromARGB(
              data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
        }

        // Inside the left big plate: glyph. Above the barbell: tile.
        expect(at(25, 50), glyph);
        expect(at(50, 8), tile);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('stands still when the OS asks to remove animations',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);

      // A tap must not start anything either.
      await tester.tap(find.byType(AnimatedIronpeakLogo));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('LauncherIconPreview', () {
    Future<ui.Image> capture(WidgetTester tester, LauncherIconVariant variant) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: LauncherIconPreview(variant: variant, size: 100),
          ),
        ),
      ));
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() => boundary.toImage()))!;
    }

    Future<Color> pixel(WidgetTester tester, ui.Image image, int x, int y) async {
      final data = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba)))!;
      final i = (y * image.width + x) * 4;
      return Color.fromARGB(
          data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
    }

    testWidgets('paints each variant in its own backdrop and glyph colors', (tester) async {
      for (final variant in [
        LauncherIcons.defaultVariant,
        const LauncherIconVariant(IconBackdrop.dark, IconHue.amber),
        const LauncherIconVariant(IconBackdrop.light, IconHue.graphite),
      ]) {
        final image = await capture(tester, variant);
        // Glyph box = 66/72 of the preview: logo unit u -> 4.17 + u * 0.917.
        int px(double u) => (100 * (1 - IronpeakMark.maskedGlyphFraction) / 2 +
                u * IronpeakMark.maskedGlyphFraction)
            .round();
        // Above the barbell: backdrop. Inside the left big plate: glyph.
        expect(await pixel(tester, image, px(50), px(8)), variant.background,
            reason: variant.id);
        expect(await pixel(tester, image, px(25), px(50)), variant.glyph,
            reason: variant.id);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
