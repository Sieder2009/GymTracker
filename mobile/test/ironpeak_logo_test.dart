import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/widgets/ironpeak_logo.dart';
import 'package:path_drawing/path_drawing.dart';

void _expectSame(LogoPose a, LogoPose b, {double tolerance = 1e-9}) {
  expect(a.mountainAlpha, closeTo(b.mountainAlpha, tolerance));
  expect(a.mountainScale, closeTo(b.mountainScale, tolerance));
  expect(a.mountainSquash, closeTo(b.mountainSquash, tolerance));
  expect(a.barbellDy, closeTo(b.barbellDy, tolerance));
  expect(a.barbellAlpha, closeTo(b.barbellAlpha, tolerance));
  expect(a.sparkScale, closeTo(b.sparkScale, tolerance));
  // The glint's rotation only matters while it is visible.
  if (a.sparkScale > 0.001) {
    expect(a.sparkTurn, closeTo(b.sparkTurn, tolerance));
  }
}

/// Largest distance from the logo's center (50, 50) over every point on the
/// outline of [data], shifted down by [dy] units.
double _farthestFromCenter(String data, {double dy = 0}) {
  var farthest = 0.0;
  for (final metric in parseSvgPathData(data).computeMetrics()) {
    for (var d = 0.0; d <= metric.length; d += 0.25) {
      final p = metric.getTangentForOffset(d)!.position.translate(0, dy);
      farthest = math.max(farthest, (p - const Offset(50, 50)).distance);
    }
  }
  return farthest;
}

void main() {
  const intro = IronpeakMark.introSeconds;
  const loop = IronpeakMark.loopSeconds;

  group('IronpeakMark.poseAt', () {
    test('starts hidden, with the barbell held above the mountain', () {
      final start = IronpeakMark.poseAt(0);
      expect(start.mountainAlpha, 0);
      expect(start.barbellAlpha, 0);
      expect(start.barbellDy, lessThan(-40));
      expect(start.sparkScale, 0);
    });

    test('the intro hands over to the loop without a jump', () {
      _expectSame(
        IronpeakMark.poseAt(intro - 1e-6),
        IronpeakMark.poseAt(intro),
        tolerance: 0.01,
      );
      final rest = IronpeakMark.poseAt(intro);
      expect(rest.mountainAlpha, 1);
      expect(rest.barbellAlpha, 1);
      expect(rest.barbellDy, closeTo(0, 1e-9));
    });

    test('the barbell drops from above and never ends up below its rest', () {
      for (var t = 0.0; t <= intro; t += 0.005) {
        final dy = IronpeakMark.poseAt(t).barbellDy;
        expect(dy, lessThanOrEqualTo(0.01), reason: 'at t=$t');
        expect(dy, greaterThanOrEqualTo(-44.01), reason: 'at t=$t');
      }
    });

    test('the loop repeats exactly every loopSeconds', () {
      for (final x in [0.0, 0.3, 0.9, 1.4, 2.2, 2.9]) {
        _expectSame(
          IronpeakMark.poseAt(intro + x),
          IronpeakMark.poseAt(intro + x + loop),
        );
        _expectSame(
          IronpeakMark.poseAt(intro + x),
          IronpeakMark.poseAt(intro + x + 7 * loop),
          tolerance: 1e-6,
        );
      }
    });

    test('a rep lifts the bar by repHeight and glints at the top', () {
      var highest = 0.0;
      for (var u = 0.0; u < loop; u += 0.01) {
        highest = math.min(highest, IronpeakMark.poseAt(intro + u).barbellDy);
      }
      expect(highest, closeTo(-IronpeakMark.repHeight, 1e-6));

      // Middle of the hold: bar at the top, glint at full size.
      final top = IronpeakMark.poseAt(intro + 1.45);
      expect(top.barbellDy, closeTo(-IronpeakMark.repHeight, 1e-9));
      expect(top.sparkScale, closeTo(1, 1e-9));

      // Resting between reps: bar down, no glint.
      final rest = IronpeakMark.poseAt(intro + 0.2);
      expect(rest.barbellDy, 0);
      expect(rest.sparkScale, 0);
    });
  });

  group('IronpeakMark geometry', () {
    // The circle of radius 50 around (50, 50) is what maps onto the 66dp
    // safe zone of an Android adaptive icon -- the part no launcher mask can
    // crop. Everything that is visible when the logo is at rest (and at the
    // top of a rep) has to stay inside it.
    const safeRadius = 50.0;

    test('the resting glyph stays inside the adaptive-icon safe zone', () {
      for (final entry in {
        'backPeak': IronpeakMark.backPeak,
        'frontPeak': IronpeakMark.frontPeak,
        'backSnow': IronpeakMark.backSnow,
        'frontSnow': IronpeakMark.frontSnow,
        'barbell': IronpeakMark.barbell,
        'barbellShadow': IronpeakMark.barbellShadow,
      }.entries) {
        expect(_farthestFromCenter(entry.value), lessThanOrEqualTo(safeRadius),
            reason: entry.key);
      }
    });

    test('so does the barbell at the top of a rep', () {
      for (final data in [IronpeakMark.barbell, IronpeakMark.barbellShadow]) {
        expect(
          _farthestFromCenter(data, dy: -IronpeakMark.repHeight),
          lessThanOrEqualTo(safeRadius),
        );
      }
    });

    test('the glint at full size stays inside as well', () {
      final reach = (IronpeakMark.sparkAnchor - const Offset(50, 50)).distance +
          _farthestFromCenterOfOrigin(IronpeakMark.spark) * 1.15;
      expect(reach, lessThanOrEqualTo(safeRadius));
    });

    test('every path parses to something drawable', () {
      for (final data in [
        IronpeakMark.backPeak,
        IronpeakMark.frontPeak,
        IronpeakMark.backSnow,
        IronpeakMark.frontSnow,
        IronpeakMark.barbell,
        IronpeakMark.barbellShadow,
        IronpeakMark.spark,
      ]) {
        expect(parseSvgPathData(data).getBounds().isEmpty, isFalse);
      }
    });
  });

  group('AnimatedIronpeakLogo', () {
    Widget host() => const MaterialApp(
          home: Scaffold(body: Center(child: AnimatedIronpeakLogo(replayOnTap: true))),
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
      await tester.pumpWidget(host());
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
}

/// Farthest outline point of a path that is centered on the origin.
double _farthestFromCenterOfOrigin(String data) {
  var farthest = 0.0;
  for (final metric in parseSvgPathData(data).computeMetrics()) {
    for (var d = 0.0; d <= metric.length; d += 0.1) {
      farthest = math.max(
          farthest, metric.getTangentForOffset(d)!.position.distance);
    }
  }
  return farthest;
}
