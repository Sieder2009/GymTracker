import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/progression_engine.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';

void main() {
  Exercise exercise(
    String reps,
    List<HistoryEntry> history, {
    String muscle = 'chest',
    double weight = 50,
  }) =>
      Exercise.fresh('Bench Press', muscle, 90, [ExerciseSet(w: weight, r: reps)], history: history);

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
  });
}
