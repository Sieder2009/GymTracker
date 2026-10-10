import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/analytics_engine.dart';
import 'package:ironpeak_mobile/models/big_lift.dart';
import 'package:ironpeak_mobile/models/body_weight_entry.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';
import 'package:ironpeak_mobile/models/workout_session.dart';

void main() {
  final now = DateTime(2026, 8, 7); // a Friday

  group('computeWeekSummary', () {
    test('insufficient quality when no workout has ever been logged', () {
      final summary = computeWeekSummary([], now: now);
      expect(summary.quality, DataQuality.insufficient);
      expect(summary.workoutCount, 0);
    });

    test('sums volume/sets for the trailing 7-day window only', () {
      final sessions = [
        WorkoutSession(date: '2026-08-07', durationMinutes: 40, planName: 'A', totalVolumeKg: 1000, totalSets: 10),
        WorkoutSession(date: '2026-08-05', durationMinutes: 40, planName: 'A', totalVolumeKg: 500, totalSets: 5),
        // outside the 7-day window (>6 days before "today")
        WorkoutSession(date: '2026-07-20', durationMinutes: 40, planName: 'A', totalVolumeKg: 9999, totalSets: 99),
      ];
      final summary = computeWeekSummary(sessions, now: now);
      expect(summary.workoutCount, 2);
      expect(summary.totalVolumeKg, 1500);
      expect(summary.totalSets, 15);
      expect(summary.quality, DataQuality.good);
    });

    test('volumeChangePercent compares against the prior 7-day window', () {
      final sessions = [
        WorkoutSession(date: '2026-08-07', durationMinutes: 40, planName: 'A', totalVolumeKg: 2000, totalSets: 10),
        // previous week window
        WorkoutSession(date: '2026-07-31', durationMinutes: 40, planName: 'A', totalVolumeKg: 1000, totalSets: 10),
      ];
      final summary = computeWeekSummary(sessions, now: now);
      expect(summary.volumeChangePercent, 100); // doubled
    });

    test('no previous-week baseline -> null change, not a fake 0%', () {
      final sessions = [
        WorkoutSession(date: '2026-08-07', durationMinutes: 40, planName: 'A', totalVolumeKg: 500, totalSets: 5),
      ];
      final summary = computeWeekSummary(sessions, now: now);
      expect(summary.volumeChangePercent, isNull);
    });
  });

  group('computeConsistency', () {
    test('current streak counts back-to-back days ending today', () {
      final sessions = [
        WorkoutSession(date: '2026-08-07', durationMinutes: 1, planName: 'A'),
        WorkoutSession(date: '2026-08-06', durationMinutes: 1, planName: 'A'),
        WorkoutSession(date: '2026-08-05', durationMinutes: 1, planName: 'A'),
      ];
      final stats = computeConsistency(sessions, now: now);
      expect(stats.currentStreakDays, 3);
      expect(stats.bestStreakDays, 3);
    });

    test('a gap of more than 1 day resets the current streak to 0', () {
      final sessions = [
        WorkoutSession(date: '2026-08-01', durationMinutes: 1, planName: 'A'),
        WorkoutSession(date: '2026-08-02', durationMinutes: 1, planName: 'A'),
      ];
      final stats = computeConsistency(sessions, now: now); // now is 2026-08-07
      expect(stats.currentStreakDays, 0);
      expect(stats.bestStreakDays, 2); // best streak is still recorded
    });

    test('workoutsThisMonth only counts sessions in the reference month', () {
      final sessions = [
        WorkoutSession(date: '2026-08-01', durationMinutes: 1, planName: 'A'),
        WorkoutSession(date: '2026-08-07', durationMinutes: 1, planName: 'A'),
        WorkoutSession(date: '2026-07-31', durationMinutes: 1, planName: 'A'),
      ];
      final stats = computeConsistency(sessions, now: now);
      expect(stats.workoutsThisMonth, 2);
    });

    test('a streak survives the spring-forward DST night (23-hour day in CET/CEST)', () {
      final sessions = [
        WorkoutSession(date: '2026-03-28', durationMinutes: 1, planName: 'A'),
        WorkoutSession(date: '2026-03-29', durationMinutes: 1, planName: 'A'),
        WorkoutSession(date: '2026-03-30', durationMinutes: 1, planName: 'A'),
      ];
      final stats = computeConsistency(sessions, now: DateTime(2026, 3, 30, 12));
      expect(stats.bestStreakDays, 3);
      expect(stats.currentStreakDays, 3);
    });
  });

  group('computeLiftTrend', () {
    test('insufficient with fewer than 2 dated points in the window', () {
      final lift = BigLift(pr: 100, prDate: '2026-08-01');
      final trend = computeLiftTrend(lift, now: now);
      expect(trend.quality, DataQuality.insufficient);
      expect(trend.delta, isNull);
    });

    test('computes % change from earliest to latest dated point in window', () {
      final lift = BigLift(
        pr: 110,
        prDate: '2026-08-01',
        history: [BigLiftPoint(l: '10.7', v: 100, isoDate: '2026-07-10')],
      );
      final trend = computeLiftTrend(lift, windowDays: 30, now: now);
      expect(trend.delta, closeTo(10, 0.01)); // 100 -> 110 = +10%
    });

    test('undated legacy history points are excluded, not mis-ordered', () {
      final lift = BigLift(
        pr: 110,
        prDate: '2026-08-01',
        history: [
          BigLiftPoint(l: '1.1', v: 500), // no isoDate — must be ignored
          BigLiftPoint(l: '10.7', v: 100, isoDate: '2026-07-10'),
        ],
      );
      final trend = computeLiftTrend(lift, windowDays: 30, now: now);
      expect(trend.sampleCount, 2); // the 500 outlier never enters the calc
      expect(trend.delta, closeTo(10, 0.01));
    });
  });

  group('computeBodyWeightTrend', () {
    test('insufficient with fewer than 2 entries in window', () {
      final trend = computeBodyWeightTrend([BodyWeightEntry(date: '2026-08-01', weight: 80)], now: now);
      expect(trend.quality, DataQuality.insufficient);
    });

    test('delta is an absolute kg difference, not a percent', () {
      final entries = [
        BodyWeightEntry(date: '2026-07-10', weight: 84.2),
        BodyWeightEntry(date: '2026-08-07', weight: 82.4),
      ];
      final trend = computeBodyWeightTrend(entries, now: now);
      expect(trend.delta, closeTo(-1.8, 0.01));
    });
  });

  group('isLiftPlateaued', () {
    test('null when there is not enough data to trust a trend', () {
      final lift = BigLift(pr: 100, prDate: '2026-08-01');
      expect(isLiftPlateaued(lift, now: now), isNull);
    });

    test('true when the trend is essentially flat', () {
      final lift = BigLift(
        pr: 100.5,
        prDate: '2026-08-01',
        history: [BigLiftPoint(l: '10.7', v: 100, isoDate: '2026-07-10')],
      );
      expect(isLiftPlateaued(lift, windowDays: 30, now: now), isTrue);
    });

    test('false when the trend clearly moved', () {
      final lift = BigLift(
        pr: 110,
        prDate: '2026-08-01',
        history: [BigLiftPoint(l: '10.7', v: 100, isoDate: '2026-07-10')],
      );
      expect(isLiftPlateaued(lift, windowDays: 30, now: now), isFalse);
    });
  });

  group('countRecentLiftPrs', () {
    test('only counts lifts whose prDate falls within the window', () {
      final lifts = BigLifts(
        bench: BigLift(pr: 90, prDate: '2026-08-05'),
        deadlift: BigLift(pr: 140, prDate: '2026-01-01'),
        squat: BigLift(pr: 0),
      );
      expect(countRecentLiftPrs(lifts, windowDays: 30, now: now), 1);
    });
  });

  group('exerciseHistoryPoints', () {
    Exercise exercise(List<HistoryEntry> history) => Exercise.fresh(
          'Overhead Press',
          'shoulders',
          90,
          [ExerciseSet(w: 40, r: '8')],
          history: history,
        );

    test('undated entries are excluded', () {
      final ex = exercise([
        HistoryEntry(weight: 40, reps: [8, 8, 8]), // no date
        HistoryEntry(weight: 42.5, reps: [8, 7, 6], date: '2026-07-20'),
      ]);
      final points = exerciseHistoryPoints(ex);
      expect(points, hasLength(1));
      expect(points.first.topWeight, 42.5);
    });

    test('e1rm is estimated from the max numeric rep count via Epley', () {
      final ex = exercise([
        HistoryEntry(weight: 100, reps: [5], date: '2026-07-20'),
      ]);
      final points = exerciseHistoryPoints(ex);
      expect(points.single.e1rm, closeTo(100 * (1 + 5 / 30), 0.01));
    });

    test('e1rm is null when reps only carries non-numeric markers', () {
      final ex = exercise([
        HistoryEntry(weight: 100, reps: ['✓', 'x'], date: '2026-07-20'),
      ]);
      expect(exerciseHistoryPoints(ex).single.e1rm, isNull);
    });

    test('a Timed entry with a real added weight never produces a bogus topWeight/e1RM', () {
      final ex = exercise([
        HistoryEntry(
          weight: 20, // real, nonzero added weight on a loaded carry
          reps: const [],
          date: '2026-07-20',
          mode: ExerciseLogMode.timed,
          durations: [45, 40],
        ),
      ]);
      expect(exerciseHistoryPoints(ex), isEmpty);
      expect(bestEstimatedOneRepMax(ex), isNull);
    });

    test('a Cardio entry never produces a bogus topWeight even though weight is written as 0', () {
      final ex = exercise([
        HistoryEntry(
          weight: 0,
          reps: const [],
          date: '2026-07-20',
          mode: ExerciseLogMode.cardio,
          durations: [1200],
          speeds: [8.5],
        ),
      ]);
      expect(exerciseHistoryPoints(ex), isEmpty);
    });
  });

  group('exerciseTimeHistoryPoints / bestHeldSeconds', () {
    test('only Timed-stamped, dated entries with a logged duration are included', () {
      final ex = Exercise.fresh('Plank', 'core', 60, [], history: [
        HistoryEntry(weight: 0, reps: const [], date: '2026-07-01', mode: ExerciseLogMode.timed, durations: [30, 35]),
        HistoryEntry(weight: 0, reps: const [], mode: ExerciseLogMode.timed, durations: [60]), // undated
        HistoryEntry(weight: 40, reps: const [8], date: '2026-07-05'), // Reps entry, ignored here
        HistoryEntry(weight: 0, reps: const [], date: '2026-07-10', mode: ExerciseLogMode.timed, durations: [50, 45]),
      ]);
      final points = exerciseTimeHistoryPoints(ex);
      expect(points, hasLength(2));
      expect(points.first.value, 35); // max of [30, 35]
      expect(points.last.value, 50); // max of [50, 45]
      expect(bestHeldSeconds(ex), 50);
    });

    test('bestHeldSeconds is null with no Timed history', () {
      final ex = Exercise.fresh('Plank', 'core', 60, []);
      expect(bestHeldSeconds(ex), isNull);
    });

    test('computeExerciseTimeTrend: insufficient with fewer than 2 dated points', () {
      final ex = Exercise.fresh('Plank', 'core', 60, [], history: [
        HistoryEntry(weight: 0, reps: const [], date: '2026-08-01', mode: ExerciseLogMode.timed, durations: [30]),
      ]);
      expect(computeExerciseTimeTrend(ex, now: now).quality, DataQuality.insufficient);
    });

    test('computeExerciseTimeTrend: % change from earliest to latest dated point', () {
      final ex = Exercise.fresh('Plank', 'core', 60, [], history: [
        HistoryEntry(weight: 0, reps: const [], date: '2026-07-10', mode: ExerciseLogMode.timed, durations: [30]),
        HistoryEntry(weight: 0, reps: const [], date: '2026-08-07', mode: ExerciseLogMode.timed, durations: [45]),
      ]);
      final trend = computeExerciseTimeTrend(ex, windowDays: 30, now: now);
      expect(trend.delta, closeTo(50, 0.01)); // 30 -> 45 = +50%
    });
  });

  group('exerciseSpeedHistoryPoints / bestSpeedKmh', () {
    test('only Cardio-stamped, dated entries with a logged speed are included', () {
      final ex = Exercise.fresh('Treadmill', '', 0, [], history: [
        HistoryEntry(weight: 0, reps: const [], date: '2026-07-01', mode: ExerciseLogMode.cardio, durations: [1200], speeds: [7.5]),
        HistoryEntry(weight: 0, reps: const [], date: '2026-07-10', mode: ExerciseLogMode.cardio, durations: [1200], speeds: [9.0]),
      ]);
      expect(bestSpeedKmh(ex), 9.0);
    });

    test('computeExerciseSpeedTrend computes % change across dated entries', () {
      final ex = Exercise.fresh('Treadmill', '', 0, [], history: [
        HistoryEntry(weight: 0, reps: const [], date: '2026-07-10', mode: ExerciseLogMode.cardio, durations: [1200], speeds: [8.0]),
        HistoryEntry(weight: 0, reps: const [], date: '2026-08-07', mode: ExerciseLogMode.cardio, durations: [1200], speeds: [10.0]),
      ]);
      final trend = computeExerciseSpeedTrend(ex, windowDays: 30, now: now);
      expect(trend.delta, closeTo(25, 0.01)); // 8 -> 10 = +25%
    });
  });

  group('computeExerciseTrend', () {
    test('insufficient with fewer than 2 dated points', () {
      final ex = Exercise.fresh('Curls', 'arms', 60, [], history: [
        HistoryEntry(weight: 20, reps: [10], date: '2026-08-01'),
      ]);
      expect(computeExerciseTrend(ex, now: now).quality, DataQuality.insufficient);
    });

    test('computes % change from earliest to latest dated point', () {
      final ex = Exercise.fresh('Curls', 'arms', 60, [], history: [
        HistoryEntry(weight: 20, reps: [10], date: '2026-07-10'),
        HistoryEntry(weight: 22, reps: [10], date: '2026-08-07'),
      ]);
      final trend = computeExerciseTrend(ex, windowDays: 30, now: now);
      expect(trend.delta, closeTo(10, 0.01)); // 20 -> 22 = +10%
    });
  });

  group('weeklyBuckets', () {
    test('bucket boundaries stay on calendar days across the DST fall-back', () {
      // 2026-10-25 is 25h long in CET/CEST. Duration-based stepping put the
      // current week's start at 2026-10-20 01:00, dropping that day.
      final dstNow = DateTime(2026, 10, 26);
      final buckets = weeklyBuckets([
        WorkoutSession(date: '2026-10-20', durationMinutes: 40, planName: 'A', totalVolumeKg: 100),
        WorkoutSession(date: '2026-10-19', durationMinutes: 40, planName: 'A', totalVolumeKg: 10),
      ], weeks: 2, now: dstNow);
      expect(buckets.last.weekStart, DateTime(2026, 10, 20));
      expect(buckets.last.workoutCount, 1);
      expect(buckets.last.totalVolumeKg, 100);
      expect(buckets.first.weekStart, DateTime(2026, 10, 13));
      expect(buckets.first.workoutCount, 1);
      expect(buckets.first.totalVolumeKg, 10);
    });

    test('a week with zero sessions is a real zero bucket, not skipped', () {
      final buckets = weeklyBuckets([], weeks: 4, now: now);
      expect(buckets, hasLength(4));
      expect(buckets.every((b) => b.totalVolumeKg == 0 && b.workoutCount == 0), isTrue);
    });

    test('sessions are attributed to the correct rolling 7-day bucket', () {
      final sessions = [
        WorkoutSession(date: '2026-08-07', durationMinutes: 40, planName: 'A', totalVolumeKg: 1000, totalSets: 10),
        WorkoutSession(date: '2026-07-24', durationMinutes: 40, planName: 'A', totalVolumeKg: 500, totalSets: 5),
      ];
      final buckets = weeklyBuckets(sessions, weeks: 4, now: now);
      expect(buckets.last.totalVolumeKg, 1000); // most recent bucket ends today
      expect(buckets.last.workoutCount, 1);
      final total = buckets.fold<double>(0, (sum, b) => sum + b.totalVolumeKg);
      expect(total, 1500);
    });
  });
}
