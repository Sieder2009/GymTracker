import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/plate_calculator.dart';

void main() {
  group('calculatePlates', () {
    test('returns null when the target is lighter than the bar', () {
      expect(calculatePlates(targetKg: 15, barWeightKg: 20), isNull);
    });

    test('returns null for a zero/negative bar weight', () {
      expect(calculatePlates(targetKg: 100, barWeightKg: 0), isNull);
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

    test('greedy picks the largest plates first', () {
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
  });
}
