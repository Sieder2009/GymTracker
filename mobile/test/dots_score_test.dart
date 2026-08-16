import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/dots_score.dart';

void main() {
  group('dotsScore', () {
    test('returns 0 for missing bodyweight or total', () {
      expect(dotsScore(bodyweightKg: 0, totalKg: 500, isMale: true), 0);
      expect(dotsScore(bodyweightKg: 80, totalKg: 0, isMale: true), 0);
    });

    test('a stronger total at the same bodyweight scores higher', () {
      final lower = dotsScore(bodyweightKg: 80, totalKg: 400, isMale: true);
      final higher = dotsScore(bodyweightKg: 80, totalKg: 500, isMale: true);
      expect(higher, greaterThan(lower));
    });

    test('male and female coefficients diverge for the same inputs', () {
      final male = dotsScore(bodyweightKg: 70, totalKg: 400, isMale: true);
      final female = dotsScore(bodyweightKg: 70, totalKg: 400, isMale: false);
      expect(male, isNot(closeTo(female, 0.01)));
    });
  });

  group('estimateOneRepMax', () {
    test('a single rep returns the weight itself', () {
      expect(estimateOneRepMax(weight: 100, reps: 1), 100);
    });

    test('Epley formula for multiple reps', () {
      // 100kg x5 -> 100 * (1 + 5/30) = 116.666...
      expect(estimateOneRepMax(weight: 100, reps: 5), closeTo(116.67, 0.01));
    });

    test('returns 0 for non-positive weight or reps', () {
      expect(estimateOneRepMax(weight: 0, reps: 5), 0);
      expect(estimateOneRepMax(weight: 100, reps: 0), 0);
    });
  });

  group('weightForRepMax', () {
    test('is the inverse of estimateOneRepMax', () {
      final oneRm = estimateOneRepMax(weight: 100, reps: 5);
      final backToFive = weightForRepMax(oneRepMax: oneRm, reps: 5);
      expect(backToFive, closeTo(100, 0.001));
    });

    test('1RM returns the max itself', () {
      expect(weightForRepMax(oneRepMax: 150, reps: 1), 150);
    });

    test('a higher rep target means a lighter weight', () {
      final fiveRm = weightForRepMax(oneRepMax: 150, reps: 5);
      final tenRm = weightForRepMax(oneRepMax: 150, reps: 10);
      expect(tenRm, lessThan(fiveRm));
    });

    test('returns 0 for non-positive 1RM or reps', () {
      expect(weightForRepMax(oneRepMax: 0, reps: 5), 0);
      expect(weightForRepMax(oneRepMax: 150, reps: 0), 0);
    });
  });
}
