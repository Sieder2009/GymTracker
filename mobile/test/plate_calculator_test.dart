import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/plate_calculator.dart';

void main() {
  group('calculatePlates', () {
    test('returns null when the target is lighter than the bar', () {
      expect(calculatePlates(targetKg: 15, barWeightKg: 20), isNull);
    });

    test('returns null for a negative empty weight', () {
      expect(calculatePlates(targetKg: 100, barWeightKg: -1), isNull);
    });

    test('an empty weight of 0 (a leg press) loads everything as plates', () {
      final r = calculatePlates(targetKg: 100, barWeightKg: 0)!;
      expect(r.perSide, [25, 25]);
      expect(r.achievedTotal, 100);
    });

    test('an empty bar needs no plates', () {
      final r = calculatePlates(targetKg: 20, barWeightKg: 20)!;
      expect(r.perSide, isEmpty);
      expect(r.achievedTotal, 20);
      expect(r.isApproximate, isFalse);
    });

    test('a clean, evenly-loadable target', () {
      // 100kg bar 20kg -> 40kg each side -> 25+15
      final r = calculatePlates(targetKg: 100, barWeightKg: 20)!;
      expect(r.perSide, [25, 15]);
      expect(r.achievedTotal, 100);
      expect(r.isApproximate, isFalse);
    });

    test('the fewest plates win, ties going to the larger ones', () {
      // 140kg bar 20kg -> 60kg each side -> 25+25+10
      final r = calculatePlates(targetKg: 140, barWeightKg: 20)!;
      expect(r.perSide, [25, 25, 10]);
    });

    test('a target that cannot be hit exactly gets the closest total below it', () {
      // 20kg bar + 0.3kg/side isn't reachable with a 0.5kg smallest plate.
      final r = calculatePlates(targetKg: 20.6, barWeightKg: 20)!;
      expect(r.isApproximate, isTrue);
      expect(r.achievedTotal, lessThan(r.targetTotal));
    });

    test('a custom (lb) plate set is respected', () {
      final r = calculatePlates(targetKg: 135, barWeightKg: 45, availablePlates: kStandardPlatesLb)!;
      expect(r.perSide, [45]);
      expect(r.achievedTotal, 135);
    });

    test('a 260kg leg press in a gym without 20s', () {
      // 130kg a side from 25/15/10/5/2.5/1.25.
      final r = calculatePlates(targetKg: 260, barWeightKg: 0, availablePlates: [25, 15, 10, 5, 2.5, 1.25])!;
      expect(r.perSide, [25, 25, 25, 25, 25, 5]);
      expect(r.achievedTotal, 260);
      expect(r.isApproximate, isFalse);
    });

    test('finds an exact load that largest-first would miss', () {
      // 30kg a side from 25s and 15s only: 15+15, not 25 and stuck.
      final r = calculatePlates(targetKg: 80, barWeightKg: 20, availablePlates: [25, 15])!;
      expect(r.perSide, [15, 15]);
      expect(r.isApproximate, isFalse);
    });

    test('falls back to the heaviest load below the target', () {
      // 22kg a side from 10s and 5s: 20 is the most that fits.
      final r = calculatePlates(targetKg: 54, barWeightKg: 10, availablePlates: [10, 5])!;
      expect(r.perSide, [10, 10]);
      expect(r.achievedTotal, 50);
      expect(r.isApproximate, isTrue);
    });

    test('a typo-sized target stays fast and capped', () {
      final r = calculatePlates(targetKg: 99999, barWeightKg: 20)!;
      expect(r.perSide.fold<double>(0, (sum, p) => sum + p), 1000);
    });
  });
}
