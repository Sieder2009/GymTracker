import 'analytics_engine.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../models/workout_session.dart';

/// A progression of tiers a user climbs by training -- everything here is
/// derived live from the same logged data the rest of `analytics/` already
/// uses (no separate "is this unlocked" persistence, matching this
/// module's existing philosophy: nothing is guessed or stored twice).
enum AchievementPathId {
  consistency,
  totalWorkouts,
  totalVolume,
  prCount,
  totalSets,
  totalWorkoutMinutes,
  distinctExercises,
}

const List<int> kConsistencyTiers = [3, 7, 14, 30, 60, 100];
const List<int> kTotalWorkoutsTiers = [1, 5, 10, 25, 50, 100, 250];
const List<double> kTotalVolumeTiers = [
  1000,
  5000,
  10000,
  25000,
  50000,
  100000
];
const List<int> kPrCountTiers = [1, 3, 5, 10, 20, 35];
const List<int> kTotalSetsTiers = [50, 150, 400, 1000, 2500, 5000];
const List<int> kTotalWorkoutMinutesTiers = [60, 300, 900, 2400, 6000, 12000];
const List<int> kDistinctExercisesTiers = [3, 8, 15, 25, 40, 60];

class AchievementPathResult {
  AchievementPathResult({
    required this.id,
    required this.currentValue,
    required this.thresholds,
  }) : unlockedTierIndex = _unlocked(currentValue, thresholds);

  final AchievementPathId id;
  final double currentValue;

  /// Ascending tier thresholds for this path.
  final List<double> thresholds;

  /// Index into [thresholds] of the highest tier reached, or -1 if none.
  final int unlockedTierIndex;

  bool get hasNextTier => unlockedTierIndex + 1 < thresholds.length;
  double? get nextThreshold =>
      hasNextTier ? thresholds[unlockedTierIndex + 1] : null;

  /// 0..1 progress toward the next tier (1 once every tier is unlocked).
  double get progressToNext {
    if (!hasNextTier) return 1;
    final prev = unlockedTierIndex >= 0 ? thresholds[unlockedTierIndex] : 0;
    final next = thresholds[unlockedTierIndex + 1];
    if (next <= prev) return 1;
    return ((currentValue - prev) / (next - prev)).clamp(0, 1);
  }

  static int _unlocked(double value, List<double> thresholds) {
    var idx = -1;
    for (var i = 0; i < thresholds.length; i++) {
      if (value >= thresholds[i]) idx = i;
    }
    return idx;
  }
}

/// Every exercise across every saved program (daily + per-day) -- the pool
/// [_prEventCount] scans for rising-max ("new best") events.
List<Exercise> _allExercises(List<Program> programs) {
  return [
    for (final p in programs) ...p.dailyExercises,
    for (final p in programs)
      for (final d in p.days) ...d.exercises,
  ];
}

/// Counts every point in time a new best (estimated 1RM, or raw top weight
/// when reps weren't numeric) was set across every exercise -- a rising-max
/// scan over already-existing history, not a separately persisted PR log.
/// Only meaningful once something actually writes to [Exercise.history]
/// (the guided workout's [appendGuidedHistoryEntry] and
/// [ExerciseDetailScreen]'s manual save both do).
int _prEventCount(List<Program> programs) {
  var count = 0;
  for (final ex in _allExercises(programs)) {
    double? best;
    for (final p in exerciseHistoryPoints(ex)) {
      final v = p.e1rm ?? p.topWeight;
      if (best == null || v > best) {
        best = v;
        count += 1;
      }
    }
  }
  return count;
}

/// Count of distinct exercises actually trained at least once (non-empty
/// [Exercise.history]) across every saved program -- matched by lowercased
/// name, since the same exercise can appear in more than one plan/day as
/// separate [Exercise] objects. Deliberately not "every exercise sitting in
/// a plan," only ones with real logged history.
int _distinctExercisesTrained(List<Program> programs) {
  final names = <String>{};
  for (final ex in _allExercises(programs)) {
    if (ex.history.isNotEmpty) names.add(ex.name.trim().toLowerCase());
  }
  return names.length;
}

List<AchievementPathResult> computeAchievements({
  required List<WorkoutSession> sessions,
  required List<Program> programs,
  DateTime? now,
}) {
  final totalVolume =
      sessions.fold<double>(0, (sum, s) => sum + s.totalVolumeKg);
  final totalSets = sessions.fold<int>(0, (sum, s) => sum + s.totalSets);
  final totalMinutes =
      sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
  return [
    AchievementPathResult(
      id: AchievementPathId.consistency,
      currentValue:
          computeConsistency(sessions, now: now).bestStreakDays.toDouble(),
      thresholds: kConsistencyTiers.map((e) => e.toDouble()).toList(),
    ),
    AchievementPathResult(
      id: AchievementPathId.totalWorkouts,
      currentValue: sessions.length.toDouble(),
      thresholds: kTotalWorkoutsTiers.map((e) => e.toDouble()).toList(),
    ),
    AchievementPathResult(
      id: AchievementPathId.totalVolume,
      currentValue: totalVolume,
      thresholds: kTotalVolumeTiers,
    ),
    AchievementPathResult(
      id: AchievementPathId.prCount,
      currentValue: _prEventCount(programs).toDouble(),
      thresholds: kPrCountTiers.map((e) => e.toDouble()).toList(),
    ),
    AchievementPathResult(
      id: AchievementPathId.totalSets,
      currentValue: totalSets.toDouble(),
      thresholds: kTotalSetsTiers.map((e) => e.toDouble()).toList(),
    ),
    AchievementPathResult(
      id: AchievementPathId.totalWorkoutMinutes,
      currentValue: totalMinutes.toDouble(),
      thresholds: kTotalWorkoutMinutesTiers.map((e) => e.toDouble()).toList(),
    ),
    AchievementPathResult(
      id: AchievementPathId.distinctExercises,
      currentValue: _distinctExercisesTrained(programs).toDouble(),
      thresholds: kDistinctExercisesTiers.map((e) => e.toDouble()).toList(),
    ),
  ];
}

/// A single overall progression across every achievement path combined --
/// sums how many tiers are unlocked path-wide against the theoretical max
/// (every path at its top tier) and buckets that fraction into one of 6
/// named tiers. Colors are existing [AppColors] tokens, not new hex
/// literals, so a rank badge always matches whatever accent/secondary the
/// user (or a Custom theme) has picked.
enum RankTier { starter, bronze, silver, gold, platinum, legend }

class RankResult {
  RankResult({required this.tier, required this.progressToNext});

  final RankTier tier;

  /// 0..1 progress toward the next tier (1 once Legend is reached -- there
  /// is no tier after it).
  final double progressToNext;
}

RankResult computeRank(List<AchievementPathResult> paths) {
  var score = 0;
  var maxScore = 0;
  for (final p in paths) {
    score += p.unlockedTierIndex + 1;
    maxScore += p.thresholds.length;
  }
  final fraction = maxScore == 0 ? 0.0 : score / maxScore;
  final tierCount = RankTier.values.length;
  final tierIndex = (fraction * tierCount).floor().clamp(0, tierCount - 1);
  final bandStart = tierIndex / tierCount;
  final bandEnd = (tierIndex + 1) / tierCount;
  final progress = tierIndex == tierCount - 1
      ? 1.0
      : ((fraction - bandStart) / (bandEnd - bandStart)).clamp(0.0, 1.0);
  return RankResult(tier: RankTier.values[tierIndex], progressToNext: progress);
}

/// Which paths just climbed a tier between two snapshots (e.g. one taken
/// immediately before and one immediately after logging a session) --
/// {consistency: 2} means that path just reached tier index 2. Empty when
/// nothing newly unlocked.
Map<AchievementPathId, int> newlyUnlockedTiers(
  List<AchievementPathResult> before,
  List<AchievementPathResult> after,
) {
  final result = <AchievementPathId, int>{};
  for (final a in after) {
    var beforeIndex = -1;
    for (final b in before) {
      if (b.id == a.id) {
        beforeIndex = b.unlockedTierIndex;
        break;
      }
    }
    if (a.unlockedTierIndex > beforeIndex) {
      result[a.id] = a.unlockedTierIndex;
    }
  }
  return result;
}
