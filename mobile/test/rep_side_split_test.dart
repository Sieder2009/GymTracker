import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/rep_side_split.dart';

void main() {
  group('repsPerSide', () {
    test('splits an even total cleanly', () {
      expect(repsPerSide(8), 4.0);
    });

    test('shows an odd total as it falls, not rounded away', () {
      expect(repsPerSide(7), 3.5);
    });

    test('zero reps splits to zero', () {
      expect(repsPerSide(0), 0.0);
    });
  });

  group('repStepFor', () {
    test('unilateral steps by 2', () {
      expect(repStepFor(unilateral: true), 2);
    });

    test('bilateral steps by 1', () {
      expect(repStepFor(unilateral: false), 1);
    });
  });

  group('nextEvenReps', () {
    test('an already-even value is unchanged', () {
      expect(nextEvenReps(8), 8);
    });

    test('an odd value snaps up to the next even number', () {
      expect(nextEvenReps(7), 8);
    });

    test('the exact "odd total" case the feature exists to prevent', () {
      expect(nextEvenReps(15), 16);
    });
  });
}
