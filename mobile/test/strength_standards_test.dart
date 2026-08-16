import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/strength_standards.dart';

void main() {
  group('classifyLift', () {
    test('returns null for missing lift or bodyweight', () {
      expect(classifyLift(liftKey: 'bench', liftKg: 0, bodyweightKg: 80, isMale: true), isNull);
      expect(classifyLift(liftKey: 'bench', liftKg: 100, bodyweightKg: 0, isMale: true), isNull);
    });

    test('returns null for an unknown lift key', () {
      expect(classifyLift(liftKey: 'overhead', liftKg: 100, bodyweightKg: 80, isMale: true), isNull);
    });

    test('a below-beginner ratio still classifies as beginner with 0 progress', () {
      final r = classifyLift(liftKey: 'bench', liftKg: 20, bodyweightKg: 80, isMale: true)!;
      expect(r.level, StrengthLevel.beginner);
      expect(r.progressToNext, 0);
      expect(r.nextLevel, StrengthLevel.novice);
    });

    test('a ratio right at a threshold lands exactly on that level', () {
      // Male bench: novice threshold is 0.75x bodyweight.
      final r = classifyLift(liftKey: 'bench', liftKg: 60, bodyweightKg: 80, isMale: true)!;
      expect(r.level, StrengthLevel.novice);
      expect(r.progressToNext, 0);
    });

    test('progress climbs smoothly toward the next level', () {
      // Male bench: novice=0.75x, intermediate=1.0x -> 0.875x is halfway.
      final r = classifyLift(liftKey: 'bench', liftKg: 70, bodyweightKg: 80, isMale: true)!;
      expect(r.level, StrengthLevel.novice);
      expect(r.nextLevel, StrengthLevel.intermediate);
      expect(r.progressToNext, closeTo(0.5, 0.01));
    });

    test('elite has no next level and full progress', () {
      final r = classifyLift(liftKey: 'deadlift', liftKg: 300, bodyweightKg: 80, isMale: true)!;
      expect(r.level, StrengthLevel.elite);
      expect(r.nextLevel, isNull);
      expect(r.progressToNext, 1.0);
    });

    test('male and female thresholds diverge for the same absolute lift', () {
      final male = classifyLift(liftKey: 'squat', liftKg: 100, bodyweightKg: 70, isMale: true)!;
      final female = classifyLift(liftKey: 'squat', liftKg: 100, bodyweightKg: 70, isMale: false)!;
      expect(female.level.index, greaterThanOrEqualTo(male.level.index));
    });
  });
}
