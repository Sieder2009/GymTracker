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
  expect(a.barScale, closeTo(b.barScale, tolerance));
  expect(a.plateScale, closeTo(b.plateScale, tolerance));
  expect(a.peakDy, closeTo(b.peakDy, tolerance));
}

/// Outline points of [data], sampled every [step] logo units.
List<Offset> _outline(String data, {double step = 0.25}) {
  final points = <Offset>[];
  for (final metric in parseSvgPathData(data).computeMetrics()) {
    for (var d = 0.0; d <= metric.length; d += step) {
      points.add(metric.getTangentForOffset(d)!.position);
    }
  }
  return points;
}

/// Farthest visible outline point from the logo's center (50, 50) in
/// [pose]: the bar scaled around its center, the plates around the bar's
/// center line, the summit shifted down and clipped at the horizon.
double _farthestInPose(LogoPose pose) {
  const center = Offset(50, 50);
  const cy = IronpeakMark.barCenterY;
  var farthest = 0.0;
  for (final p in _outline(IronpeakMark.bar)) {
    final q = Offset(50 + (p.dx - 50) * pose.barScale, p.dy);
    if (pose.barScale > 0.001) farthest = math.max(farthest, (q - center).distance);
  }
  for (final p in _outline(IronpeakMark.plates)) {
    final q = Offset(p.dx, cy + (p.dy - cy) * pose.plateScale);
    if (pose.plateScale > 0.001) farthest = math.max(farthest, (q - center).distance);
  }
  for (final p in _outline(IronpeakMark.peak)) {
    final q = p.translate(0, pose.peakDy);
    if (q.dy <= IronpeakMark.horizonY) farthest = math.max(farthest, (q - center).distance);
  }
  return farthest;
}

void main() {
  const intro = IronpeakMark.introSeconds;
  const loop = IronpeakMark.loopSeconds;

  group('IronpeakMark.poseAt', () {
    test('starts with nothing visible: no bar, no plates, summit behind the bar', () {
      final start = IronpeakMark.poseAt(0);
      expect(start.barScale, 0);
      expect(start.plateScale, closeTo(0, 1e-12));
      expect(start.peakDy, IronpeakMark.peakRise);
      final peakTop = parseSvgPathData(IronpeakMark.peak).getBounds().top;
      expect(peakTop + start.peakDy, greaterThanOrEqualTo(IronpeakMark.horizonY));
    });

    test('the intro ends at rest and hands over to the loop without a jump', () {
      _expectSame(IronpeakMark.poseAt(intro - 1e-6), IronpeakMark.poseAt(intro),
          tolerance: 0.01);
      _expectSame(IronpeakMark.poseAt(intro), LogoPose.rest);
    });

    test('the summit never rises above its resting place', () {
      for (var t = 0.0; t <= intro + loop; t += 0.005) {
        expect(IronpeakMark.poseAt(t).peakDy, greaterThanOrEqualTo(-1e-9), reason: 't=$t');
      }
    });

    test('the plates overshoot a little while they snap open, then settle', () {
      var most = 0.0;
      for (var t = 0.0; t <= intro; t += 0.002) {
        most = math.max(most, IronpeakMark.poseAt(t).plateScale);
      }
      // Android's OvershootInterpolator (tension 2) peaks at 1 + 32/243.
      expect(most, closeTo(1 + 32 / 243, 0.002));
    });

    test('the loop repeats exactly', () {
      for (var x = 0.0; x < loop; x += 0.05) {
        _expectSame(IronpeakMark.poseAt(intro + x), IronpeakMark.poseAt(intro + x + loop));
        _expectSame(IronpeakMark.poseAt(intro + x), IronpeakMark.poseAt(intro + x + 7 * loop));
      }
    });

    test('a breath sinks the summit by breathDepth and nothing else moves', () {
      var deepest = 0.0;
      for (var u = 0.0; u < loop; u += 0.01) {
        final pose = IronpeakMark.poseAt(intro + u);
        expect(pose.barScale, 1);
        expect(pose.plateScale, 1);
        deepest = math.max(deepest, pose.peakDy);
      }
      expect(deepest, closeTo(IronpeakMark.breathDepth, 1e-9));
    });

    test('the Android interpolator ports start at 0 and end at 1', () {
      for (final curve in [
        IronpeakMark.overshoot,
        IronpeakMark.accelerateDecelerate,
        IronpeakMark.decelerate,
      ]) {
        expect(curve(0), closeTo(0, 1e-12));
        expect(curve(1), closeTo(1, 1e-12));
      }
      expect(IronpeakMark.accelerateDecelerate(0.5), closeTo(0.5, 1e-12));
    });
  });

  group('IronpeakMark geometry', () {
    // The circle of radius 50 around (50, 50) is what maps onto the 66dp
    // safe zone of an Android adaptive icon -- the part no launcher mask can
    // crop. Every frame of the motion has to stay inside it.
    test('every frame of the intro and the loop stays inside the safe zone', () {
      for (var t = 0.0; t <= intro + loop; t += 0.01) {
        expect(_farthestInPose(IronpeakMark.poseAt(t)), lessThanOrEqualTo(50),
            reason: 't=$t');
      }
    });

    test('the resting glyph keeps some breathing room inside the masks', () {
      expect(_farthestInPose(LogoPose.rest), lessThanOrEqualTo(46));
    });

    test('path data uses only absolute commands both parsers read alike', () {
      // VectorDrawable pathData and path_drawing get the very same strings.
      for (final data in [IronpeakMark.bar, IronpeakMark.plates, IronpeakMark.peak]) {
        expect(data, matches(RegExp(r'^[MLHVCQAZ0-9., -]+$')));
        expect(parseSvgPathData(data).getBounds().isEmpty, isFalse);
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
        // Above the summit: backdrop. On the bar left of the summit: glyph.
        expect(await pixel(tester, image, px(50), px(8)), variant.background,
            reason: variant.id);
        expect(await pixel(tester, image, px(30), px(57)), variant.glyph,
            reason: variant.id);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
