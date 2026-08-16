import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/lift_balance.dart';

void main() {
  group('computeLiftBalance', () {
    test('returns null when any PR is missing or zero', () {
      expect(computeLiftBalance(benchPr: 0, squatPr: 100, deadliftPr: 130), isNull);
      expect(computeLiftBalance(benchPr: 80, squatPr: 0, deadliftPr: 130), isNull);
      expect(computeLiftBalance(benchPr: 80, squatPr: 100, deadliftPr: 0), isNull);
    });

    test('flags a bench that is proportionally weak relative to squat', () {
      final r = computeLiftBalance(benchPr: 50, squatPr: 100, deadliftPr: 120)!;
      expect(r.benchFlag, LiftBalanceFlag.low);
    });

    test('flags a bench that is proportionally strong relative to squat', () {
      final r = computeLiftBalance(benchPr: 95, squatPr: 100, deadliftPr: 120)!;
      expect(r.benchFlag, LiftBalanceFlag.high);
    });

    test('a typical, proportionate set of lifts comes back balanced', () {
      final r = computeLiftBalance(benchPr: 75, squatPr: 100, deadliftPr: 125)!;
      expect(r.benchFlag, LiftBalanceFlag.balanced);
      expect(r.deadliftFlag, LiftBalanceFlag.balanced);
    });

    test('ratios are computed relative to squat', () {
      final r = computeLiftBalance(benchPr: 80, squatPr: 100, deadliftPr: 120)!;
      expect(r.benchToSquat, closeTo(0.8, 0.001));
      expect(r.deadliftToSquat, closeTo(1.2, 0.001));
    });
  });
}
