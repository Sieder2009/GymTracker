import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/superset_steps.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';

Exercise _ex(int setCount, {bool supersetWithNext = false}) => Exercise(
      name: 'ex',
      muscle: '',
      rest: 90,
      sets: List.generate(setCount, (_) => ExerciseSet(w: 20, r: '8-10')),
      supersetWithNext: supersetWithNext,
    );

void main() {
  group('buildWorkoutSteps', () {
    test('empty exercise list produces no steps', () {
      expect(buildWorkoutSteps([]), isEmpty);
    });

    test('a single plain exercise walks its sets in order, resting after every one', () {
      final steps = buildWorkoutSteps([_ex(3)]);
      expect(steps, [
        const WorkoutStep(exerciseIndex: 0, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 1, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 2, restAfter: true),
      ]);
    });

    test('multiple plain (non-superset) exercises walk sequentially, exactly as before supersets existed', () {
      final steps = buildWorkoutSteps([_ex(2), _ex(3)]);
      expect(steps, [
        const WorkoutStep(exerciseIndex: 0, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 1, restAfter: true),
        const WorkoutStep(exerciseIndex: 1, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 1, setIndex: 1, restAfter: true),
        const WorkoutStep(exerciseIndex: 1, setIndex: 2, restAfter: true),
      ]);
    });

    test('an exercise with zero sets contributes no steps and does not break the walk', () {
      final steps = buildWorkoutSteps([_ex(0), _ex(1)]);
      expect(steps, [
        const WorkoutStep(exerciseIndex: 1, setIndex: 0, restAfter: true),
      ]);
    });

    test('a two-exercise superset with equal set counts interleaves round by round', () {
      final steps = buildWorkoutSteps([
        _ex(3, supersetWithNext: true),
        _ex(3),
      ]);
      expect(steps, [
        const WorkoutStep(exerciseIndex: 0, setIndex: 0, restAfter: false),
        const WorkoutStep(exerciseIndex: 1, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 1, restAfter: false),
        const WorkoutStep(exerciseIndex: 1, setIndex: 1, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 2, restAfter: false),
        const WorkoutStep(exerciseIndex: 1, setIndex: 2, restAfter: true),
      ]);
    });

    test('a superset with uneven set counts drops the shorter exercise out of later rounds', () {
      // A: 4 sets, B: 2 sets -- rounds 0-1 pair A+B, rounds 2-3 are A alone
      // (still resting after each, since it's the last/only step of that round).
      final steps = buildWorkoutSteps([
        _ex(4, supersetWithNext: true),
        _ex(2),
      ]);
      expect(steps, [
        const WorkoutStep(exerciseIndex: 0, setIndex: 0, restAfter: false),
        const WorkoutStep(exerciseIndex: 1, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 1, restAfter: false),
        const WorkoutStep(exerciseIndex: 1, setIndex: 1, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 2, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 3, restAfter: true),
      ]);
    });

    test('a three-exercise superset chain interleaves all three members per round', () {
      final steps = buildWorkoutSteps([
        _ex(2, supersetWithNext: true),
        _ex(2, supersetWithNext: true),
        _ex(2),
      ]);
      expect(steps, [
        const WorkoutStep(exerciseIndex: 0, setIndex: 0, restAfter: false),
        const WorkoutStep(exerciseIndex: 1, setIndex: 0, restAfter: false),
        const WorkoutStep(exerciseIndex: 2, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 1, restAfter: false),
        const WorkoutStep(exerciseIndex: 1, setIndex: 1, restAfter: false),
        const WorkoutStep(exerciseIndex: 2, setIndex: 1, restAfter: true),
      ]);
    });

    test('a plain exercise before and after a superset group stays outside the group', () {
      final steps = buildWorkoutSteps([
        _ex(1),
        _ex(2, supersetWithNext: true),
        _ex(2),
        _ex(1),
      ]);
      expect(steps, [
        const WorkoutStep(exerciseIndex: 0, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 1, setIndex: 0, restAfter: false),
        const WorkoutStep(exerciseIndex: 2, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 1, setIndex: 1, restAfter: false),
        const WorkoutStep(exerciseIndex: 2, setIndex: 1, restAfter: true),
        const WorkoutStep(exerciseIndex: 3, setIndex: 0, restAfter: true),
      ]);
    });

    test('supersetWithNext on the very last exercise is ignored (nothing to chain to)', () {
      final steps = buildWorkoutSteps([_ex(2, supersetWithNext: true)]);
      expect(steps, [
        const WorkoutStep(exerciseIndex: 0, setIndex: 0, restAfter: true),
        const WorkoutStep(exerciseIndex: 0, setIndex: 1, restAfter: true),
      ]);
    });
  });
}
