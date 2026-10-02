import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/effort_scale.dart';

void main() {
  group('effortScaleFromStorage', () {
    test('returns EffortScale.rpe for a null/absent value', () {
      expect(effortScaleFromStorage(null), EffortScale.rpe);
    });

    test('returns EffortScale.rpe for a garbage/unknown value', () {
      expect(effortScaleFromStorage('nonsense'), EffortScale.rpe);
      expect(effortScaleFromStorage(''), EffortScale.rpe);
    });

    test('returns EffortScale.rpe for the exact string "rpe"', () {
      expect(effortScaleFromStorage('rpe'), EffortScale.rpe);
    });

    test('returns EffortScale.rir only for the exact string "rir"', () {
      expect(effortScaleFromStorage('rir'), EffortScale.rir);
      expect(effortScaleFromStorage('RIR'), EffortScale.rpe);
    });
  });

  group('effortValuesFor', () {
    test('rpe scale offers 5..10 (six values)', () {
      expect(effortValuesFor(EffortScale.rpe), [5, 6, 7, 8, 9, 10]);
    });

    test('rir scale offers 0..5 (six values)', () {
      expect(effortValuesFor(EffortScale.rir), [0, 1, 2, 3, 4, 5]);
    });
  });
}
