import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/weight_conversion.dart';

void main() {
  group('weight_conversion', () {
    test('perSideToTotal / totalToPerSide round-trip', () {
      expect(perSideToTotal(perSideKg: 20, barWeightKg: 20), 60);
      expect(totalToPerSide(totalKg: 60, barWeightKg: 20), 20);
    });

    test('an empty bar (0 per side) is just the bar weight', () {
      expect(perSideToTotal(perSideKg: 0, barWeightKg: 20), 20);
      expect(totalToPerSide(totalKg: 20, barWeightKg: 20), 0);
    });

    test('respects a non-default bar weight', () {
      expect(perSideToTotal(perSideKg: 10, barWeightKg: 15), 35);
      expect(totalToPerSide(totalKg: 35, barWeightKg: 15), 10);
    });
  });
}
