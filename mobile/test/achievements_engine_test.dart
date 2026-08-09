import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/achievements_engine.dart';
import 'package:ironpeak_mobile/models/day.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';
import 'package:ironpeak_mobile/models/program.dart';
import 'package:ironpeak_mobile/models/workout_session.dart';

void main() {
  final now = DateTime(2026, 8, 7);

  group('computeAchievements', () {
    test('unlockedTierIndex is -1 below the first threshold', () {
      final paths = computeAchievements(sessions: [], programs: [], now: now);
      for (final p in paths) {
        expect(p.unlockedTierIndex, -1);
        expect(p.currentValue, 0);
      }
    });

    test('totalWorkouts path unlocks tiers as sessions accumulate', () {
      final sessions = List.generate(
        5,
        (i) => WorkoutSession(
            date: '2026-08-0${i + 1}', durationMinutes: 30, planName: 'A'),
      );
      final paths =
          computeAchievements(sessions: sessions, programs: [], now: now);
      final totalWorkouts =
          paths.firstWhere((p) => p.id == AchievementPathId.totalWorkouts);
      // kTotalWorkoutsTiers = [1, 5, 10, ...] -> 5 sessions unlocks index 1 (tier "5")
      expect(totalWorkouts.currentValue, 5);
      expect(totalWorkouts.unlockedTierIndex, 1);
      expect(totalWorkouts.nextThreshold, 10);
    });

    test('totalVolume path sums volume across every session', () {
      final sessions = [
        WorkoutSession(
            date: '2026-08-01',
            durationMinutes: 30,
            planName: 'A',
            totalVolumeKg: 600),
        WorkoutSession(
            date: '2026-08-02',
            durationMinutes: 30,
            planName: 'A',
            totalVolumeKg: 500),
      ];
      final paths =
          computeAchievements(sessions: sessions, programs: [], now: now);
      final volume =
          paths.firstWhere((p) => p.id == AchievementPathId.totalVolume);
      expect(volume.currentValue, 1100);
      expect(volume.unlockedTierIndex, 0); // kTotalVolumeTiers[0] == 1000
    });

    test('prCount path counts every rising-max across all programs\' exercises',
        () {
      final ex =
          Exercise.fresh('Bankdrücken', '', 90, [ExerciseSet(w: 60, r: '8')]);
      ex.history.addAll([
        HistoryEntry(
            weight: 60, reps: const [8], date: '2026-07-01'), // 1st best
        HistoryEntry(
            weight: 55, reps: const [8], date: '2026-07-08'), // not a new best
        HistoryEntry(
            weight: 70, reps: const [8], date: '2026-07-15'), // 2nd best
      ]);
      final program = Program(
        id: 'p1',
        name: 'Test',
        mode: 'weekday',
        startDate: '2026-01-01',
        days: [
          Day(label: 'Montag', rest: false, exercises: [ex])
        ],
      );

      final paths =
          computeAchievements(sessions: [], programs: [program], now: now);
      final prCount =
          paths.firstWhere((p) => p.id == AchievementPathId.prCount);
      expect(prCount.currentValue, 2);
    });

    test('progressToNext is 1 once every tier is unlocked', () {
      final sessions = List.generate(
        300,
        (i) => WorkoutSession(
            date: '2026-01-01', durationMinutes: 30, planName: 'A'),
      );
      final paths =
          computeAchievements(sessions: sessions, programs: [], now: now);
      final totalWorkouts =
          paths.firstWhere((p) => p.id == AchievementPathId.totalWorkouts);
      expect(totalWorkouts.hasNextTier, isFalse);
      expect(totalWorkouts.progressToNext, 1);
    });
  });

  group('newlyUnlockedTiers', () {
    test('reports only paths whose tier index increased', () {
      final before = computeAchievements(sessions: [], programs: [], now: now);
      final after = computeAchievements(
        sessions: [
          WorkoutSession(
              date: '2026-08-07', durationMinutes: 30, planName: 'A'),
        ],
        programs: [],
        now: now,
      );

      final unlocked = newlyUnlockedTiers(before, after);
      expect(unlocked[AchievementPathId.totalWorkouts], 0); // crossed tier "1"
      expect(unlocked.containsKey(AchievementPathId.totalVolume), isFalse);
    });

    test('empty when nothing changed', () {
      final snapshot =
          computeAchievements(sessions: [], programs: [], now: now);
      expect(newlyUnlockedTiers(snapshot, snapshot), isEmpty);
    });
  });
}
