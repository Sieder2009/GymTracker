import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/progression_engine.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';

void main() {
  Exercise exercise(
    String reps,
    List<HistoryEntry> history, {
    String muscle = 'chest',
    double weight = 50,
    bool unilateral = false,
  }) =>
      Exercise.fresh('Bench Press', muscle, 90, [ExerciseSet(w: weight, r: reps)],
          history: history, unilateral: unilateral);

  group('suggestNextSession', () {
    test('no suggestion without any logged history', () {
      expect(suggestNextSession(exercise('8-10', [])), isNull);
    });

    test('no suggestion when the rep field has no numeric target', () {
      final ex = exercise('AMRAP', [HistoryEntry(weight: 50, reps: [10, 10])]);
      expect(suggestNextSession(ex), isNull);
    });

    test('no suggestion when the last session logged only markers', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: ['✓', 'x'])]);
      expect(suggestNextSession(ex), isNull);
    });

    test('every set at or above the top of the range -> increase weight by 2.5kg', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [10, 10, 10])]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseWeight);
      expect(s.weightKg, 52.5);
    });

    test('leg exercises get a 5kg jump on a clean clear', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 100, reps: [10, 10])], muscle: 'legs', weight: 100);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseWeight);
      expect(s.weightKg, 105);
    });

    test('a fixed (non-range) rep target of "5" also clears at 5', () {
      final ex = exercise('5', [HistoryEntry(weight: 50, reps: [5, 5, 5])]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseWeight);
    });

    test('inside the range but short of the top -> same weight, chase a rep', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [9, 8, 8])]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseReps);
      expect(s.weightKg, 50);
    });

    test('a single missed-floor session stays quiet, not a deload yet', () {
      final ex = exercise('8-10', [
        HistoryEntry(weight: 50, reps: [10, 10]),
        HistoryEntry(weight: 50, reps: [5, 5]),
      ]);
      expect(suggestNextSession(ex), isNull);
    });

    test('two missed-floor sessions in a row -> deload to ~90%, rounded to 2.5kg', () {
      final ex = exercise('8-10', [
        HistoryEntry(weight: 50, reps: [5, 5]),
        HistoryEntry(weight: 50, reps: [4, 4]),
      ]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.deload);
      expect(s.weightKg, 45);
    });

    test('a prior session that only has markers does not count toward a deload', () {
      final ex = exercise('8-10', [
        HistoryEntry(weight: 50, reps: ['✓']),
        HistoryEntry(weight: 50, reps: [5, 5]),
      ]);
      expect(suggestNextSession(ex), isNull);
    });

    test('a bilateral exercise inside the range never carries a concrete nextReps', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [9, 8, 8])]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseReps);
      expect(s.weightKg, 50);
      expect(s.nextReps, isNull);
    });

    test('a unilateral exercise short of the top gets a concrete even nextReps', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [9, 8, 8])], unilateral: true);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseReps);
      expect(s.weightKg, 50);
      expect(s.nextReps, 10); // max logged (9) + 1 -> already even, no snap needed
      expect(s.nextReps!.isEven, isTrue);
    });

    test('a unilateral exercise whose last logged max was odd snaps up to even, not just +1', () {
      final ex = exercise('8-16', [HistoryEntry(weight: 50, reps: [15, 14, 12])], unilateral: true);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseReps);
      expect(s.nextReps, 16); // 15 + 1 = 16, already even
    });

    test('a unilateral exercise whose last logged max plus one is odd still snaps to even', () {
      final ex = exercise('8-20', [HistoryEntry(weight: 50, reps: [16, 14, 12])], unilateral: true);
      final s = suggestNextSession(ex)!;
      // 16 + 1 = 17 (odd) -> snapped up to 18, proving the round-up-to-even
      // snap runs, not just a plain "+1".
      expect(s.nextReps, 18);
    });

    test('a unilateral exercise increaseWeight suggestion is unaffected (no nextReps, same math)', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [10, 10, 10])], unilateral: true);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseWeight);
      expect(s.weightKg, 52.5);
      expect(s.nextReps, isNull);
    });

    test('a unilateral exercise deload suggestion is unaffected (no nextReps, same math)', () {
      final ex = exercise('8-10', [
        HistoryEntry(weight: 50, reps: [5, 5]),
        HistoryEntry(weight: 50, reps: [4, 4]),
      ], unilateral: true);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.deload);
      expect(s.weightKg, 45);
      expect(s.nextReps, isNull);
    });

    test('returns null for a Timed exercise even with rich, clearly-clearing history', () {
      final ex = Exercise.fresh(
        'Plank',
        'core',
        60,
        [ExerciseSet(w: 20, r: '8-10')],
        history: [
          HistoryEntry(weight: 20, reps: [10, 10, 10]),
        ],
        logMode: ExerciseLogMode.timed,
      );
      expect(suggestNextSession(ex), isNull);
    });

    test('returns null for a Cardio exercise even with rich, clearly-clearing history', () {
      final ex = Exercise.fresh(
        'Treadmill',
        '',
        0,
        [ExerciseSet(w: 0, r: '8-10')],
        history: [
          HistoryEntry(weight: 0, reps: [10, 10, 10]),
        ],
        logMode: ExerciseLogMode.cardio,
      );
      expect(suggestNextSession(ex), isNull);
    });
  });
}
