import '../data/dots_score.dart';
import '../models/big_lift.dart';
import '../models/body_weight_entry.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';

/// How much a computed number should be trusted — every trend/percentage in
/// the app carries one of these instead of silently showing a number
/// computed from too little (or no) real data. UI must branch on this
/// rather than rendering [TrendStat.changePercent] unconditionally.
enum DataQuality { good, limited, insufficient }

class TrendStat {
  const TrendStat({required this.delta, required this.quality, required this.sampleCount});

  /// Change over the requested window. What this represents depends on the
  /// producing function — a **percent** change for [computeLiftTrend] /
  /// [WeekSummary.volumeChangePercent], an **absolute kg** delta for
  /// [computeBodyWeightTrend]. Only meaningful when [quality] !=
  /// insufficient — null in that case.
  final double? delta;
  final DataQuality quality;
  final int sampleCount;

  static const TrendStat none = TrendStat(delta: null, quality: DataQuality.insufficient, sampleCount: 0);
}

class WeekSummary {
  const WeekSummary({
    required this.workoutCount,
    required this.totalVolumeKg,
    required this.totalSets,
    required this.volumeChangePercent,
    required this.quality,
  });

  final int workoutCount;
  final double totalVolumeKg;
  final int totalSets;
  final double? volumeChangePercent; // vs the previous 7-day window
  final DataQuality quality;
}

class ConsistencyStats {
  const ConsistencyStats({
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.workoutsThisMonth,
  });

  final int currentStreakDays;
  final int bestStreakDays;
  final int workoutsThisMonth;
}

class LiftImprovement {
  const LiftImprovement({required this.key, required this.label, required this.changePercent});
  final String key; // 'bench' | 'deadlift' | 'squat'
  final String label;
  final double changePercent;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _parseIso(String? iso) {
  if (iso == null) return null;
  return DateTime.tryParse(iso);
}

/// Workouts logged in [start, end) — both dated, so this is always exact
/// (no date-quality concerns, unlike lift/exercise history which can be
/// undated for imported data).
List<WorkoutSession> _sessionsInRange(List<WorkoutSession> sessions, DateTime start, DateTime end) {
  return sessions.where((s) {
    final d = _parseIso(s.date);
    return d != null && !d.isBefore(start) && d.isBefore(end);
  }).toList();
}

/// This week (last 7 days incl. today) vs the previous 7-day window.
/// [quality] is [DataQuality.insufficient] only when there is literally no
/// logged workout ever — a real zero week (0 workouts, 0 volume) is still
/// "good" data, not a data gap.
WeekSummary computeWeekSummary(List<WorkoutSession> sessions, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final weekStart = today.subtract(const Duration(days: 6));
  final prevWeekStart = weekStart.subtract(const Duration(days: 7));

  final thisWeek = _sessionsInRange(sessions, weekStart, today.add(const Duration(days: 1)));
  final prevWeek = _sessionsInRange(sessions, prevWeekStart, weekStart);

  final volume = thisWeek.fold<double>(0, (sum, s) => sum + s.totalVolumeKg);
  final sets = thisWeek.fold<int>(0, (sum, s) => sum + s.totalSets);
  final prevVolume = prevWeek.fold<double>(0, (sum, s) => sum + s.totalVolumeKg);

  double? changePercent;
  if (prevVolume > 0) {
    changePercent = (volume - prevVolume) / prevVolume * 100;
  } else if (volume > 0) {
    changePercent = null; // no baseline to compare against — not "0%"
  }

  return WeekSummary(
    workoutCount: thisWeek.length,
    totalVolumeKg: volume,
    totalSets: sets,
    volumeChangePercent: changePercent,
    quality: sessions.isEmpty ? DataQuality.insufficient : DataQuality.good,
  );
}

/// Longest run of consecutive calendar days containing >=1 workout, and
/// whether that run reaches up to today/yesterday (the "current" streak).
ConsistencyStats computeConsistency(List<WorkoutSession> sessions, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final dates = sessions
      .map((s) => _parseIso(s.date))
      .whereType<DateTime>()
      .map(_dateOnly)
      .toSet()
      .toList()
    ..sort();

  var bestStreak = 0;
  var runStreak = 0;
  DateTime? prev;
  var currentStreak = 0;

  for (final d in dates) {
    if (prev != null && d.difference(prev).inDays == 1) {
      runStreak += 1;
    } else {
      runStreak = 1;
    }
    bestStreak = runStreak > bestStreak ? runStreak : bestStreak;
    prev = d;
  }

  if (dates.isNotEmpty) {
    final last = dates.last;
    final gapToToday = today.difference(last).inDays;
    // Streak still "current" if the most recent workout was today or
    // yesterday (rest-day-friendly — one skipped day doesn't reset it to 0,
    // but a whole week off does).
    if (gapToToday <= 1) {
      currentStreak = runStreak;
    }
  }

  final workoutsThisMonth = sessions.where((s) {
    final d = _parseIso(s.date);
    return d != null && d.year == today.year && d.month == today.month;
  }).length;

  return ConsistencyStats(
    currentStreakDays: currentStreak,
    bestStreakDays: bestStreak,
    workoutsThisMonth: workoutsThisMonth,
  );
}

/// Shared core of every "% change over a window" trend calculation — dated
/// points only, first-vs-last inside the window, quality graded by sample
/// count. [computeLiftTrend] and [computeExerciseTrend] both funnel through
/// this so a big lift and a plain exercise are judged by identical rules.
TrendStat _trendFromDatedValues(List<MapEntry<DateTime, double>> points, DateTime windowStart) {
  final sorted = [...points]..sort((a, b) => a.key.compareTo(b.key));
  final inWindow = sorted.where((p) => !p.key.isBefore(windowStart)).toList();
  if (inWindow.length < 2) {
    return TrendStat(delta: null, quality: DataQuality.insufficient, sampleCount: inWindow.length);
  }

  final first = inWindow.first.value;
  final last = inWindow.last.value;
  if (first <= 0) {
    return TrendStat(delta: null, quality: DataQuality.insufficient, sampleCount: inWindow.length);
  }

  return TrendStat(
    delta: (last - first) / first * 100,
    quality: inWindow.length >= 4 ? DataQuality.good : DataQuality.limited,
    sampleCount: inWindow.length,
  );
}

/// % change in a big lift's tracked value over [windowDays], using only
/// dated history points (undated legacy/imported points are excluded
/// rather than mis-ordered) plus the current PR as the latest sample when
/// it's the most recent thing recorded.
TrendStat computeLiftTrend(BigLift lift, {int windowDays = 30, DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final windowStart = today.subtract(Duration(days: windowDays));

  final points = <MapEntry<DateTime, double>>[
    for (final p in lift.history)
      if (_parseIso(p.isoDate) != null) MapEntry(_parseIso(p.isoDate)!, p.v),
    if (lift.pr > 0 && _parseIso(lift.prDate) != null) MapEntry(_parseIso(lift.prDate)!, lift.pr),
  ];

  return _trendFromDatedValues(points, windowStart);
}

/// The highest integer rep count logged in a history entry — reps also
/// carries non-numeric markers ('✓'/'x'/'m') from the hand-typed log
/// format, so this is the only reliable number to feed an e1RM estimate.
/// Null when the entry has no numeric rep count at all.
int? _maxIntReps(List<Object> reps) {
  int? best;
  for (final r in reps) {
    if (r is int && (best == null || r > best)) best = r;
  }
  return best;
}

/// One dated sample of a plain exercise's progress: the heaviest weight
/// actually logged that session, plus an Epley-estimated one-rep max when
/// the entry has a real numeric rep count to estimate from (never guessed
/// when reps is just '✓'/'x'/'m').
class ExerciseHistoryPoint {
  const ExerciseHistoryPoint({required this.date, required this.topWeight, this.e1rm});
  final DateTime date;
  final double topWeight;
  final double? e1rm;
}

/// Every dated history entry of [exercise] as a chartable point, oldest
/// first. Undated entries (pasted-log imports with no real per-session
/// date) are excluded, same rule as big-lift trends.
List<ExerciseHistoryPoint> exerciseHistoryPoints(Exercise exercise) {
  final points = <ExerciseHistoryPoint>[];
  for (final h in exercise.history) {
    final d = _parseIso(h.date);
    if (d == null || h.weight <= 0) continue;
    final reps = _maxIntReps(h.reps);
    final e1rm = reps != null ? estimateOneRepMax(weight: h.weight, reps: reps) : null;
    points.add(ExerciseHistoryPoint(date: d, topWeight: h.weight, e1rm: e1rm));
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// % change in [exercise]'s progress over [windowDays] — estimated 1RM when
/// available (a fairer comparison across rep ranges), falling back to raw
/// top weight for sessions that only logged non-numeric reps.
TrendStat computeExerciseTrend(Exercise exercise, {int windowDays = 30, DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final windowStart = today.subtract(Duration(days: windowDays));
  final points = exerciseHistoryPoints(exercise)
      .map((p) => MapEntry(p.date, p.e1rm ?? p.topWeight))
      .toList();
  return _trendFromDatedValues(points, windowStart);
}

/// One rolling 7-day bucket, used to chart volume/workout-count trends
/// across several weeks without needing calendar-week alignment.
class WeekBucket {
  const WeekBucket({required this.weekStart, required this.totalVolumeKg, required this.workoutCount});
  final DateTime weekStart;
  final double totalVolumeKg;
  final int workoutCount;
}

/// [weeks] rolling 7-day buckets, oldest first, the most recent one ending
/// today — e.g. for charting "volume per week" or "workouts per week" over
/// the last couple of months. A week with zero logged sessions is still a
/// real (zero-valued) bucket, not a data gap.
List<WeekBucket> weeklyBuckets(List<WorkoutSession> sessions, {int weeks = 8, DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final buckets = <WeekBucket>[];
  for (var i = weeks - 1; i >= 0; i--) {
    final end = today.subtract(Duration(days: 7 * i));
    final start = end.subtract(const Duration(days: 6));
    final inBucket = _sessionsInRange(sessions, start, end.add(const Duration(days: 1)));
    final volume = inBucket.fold<double>(0, (sum, s) => sum + s.totalVolumeKg);
    buckets.add(WeekBucket(weekStart: start, totalVolumeKg: volume, workoutCount: inBucket.length));
  }
  return buckets;
}

/// Every dated sample of [lift]'s history (plus the current PR, when
/// dated), oldest first — the chartable counterpart to [computeLiftTrend]'s
/// internal point list.
List<MapEntry<DateTime, double>> liftHistoryPoints(BigLift lift) {
  final points = <MapEntry<DateTime, double>>[
    for (final p in lift.history)
      if (_parseIso(p.isoDate) != null) MapEntry(_parseIso(p.isoDate)!, p.v),
    if (lift.pr > 0 && _parseIso(lift.prDate) != null) MapEntry(_parseIso(lift.prDate)!, lift.pr),
  ]..sort((a, b) => a.key.compareTo(b.key));
  return points;
}

/// Highest estimated 1RM ever recorded for [exercise] from dated history —
/// null when no entry had a numeric rep count to estimate from.
double? bestEstimatedOneRepMax(Exercise exercise) {
  double? best;
  for (final p in exerciseHistoryPoints(exercise)) {
    final v = p.e1rm;
    if (v != null && (best == null || v > best)) best = v;
  }
  return best;
}

/// Same plateau rule as [isLiftPlateaued], generalized to any exercise.
bool? isExercisePlateaued(Exercise exercise, {int windowDays = 30, double thresholdPercent = 1.0, DateTime? now}) {
  final trend = computeExerciseTrend(exercise, windowDays: windowDays, now: now);
  if (trend.quality == DataQuality.insufficient || trend.delta == null) return null;
  return trend.delta!.abs() < thresholdPercent;
}

/// A lift is flagged as plateaued when there's enough data to trust a trend
/// (never on [DataQuality.insufficient]) AND that trend is essentially flat
/// — less than [thresholdPercent] change either way. Returns null when
/// there isn't enough data to say either way (never guesses).
bool? isLiftPlateaued(BigLift lift, {int windowDays = 30, double thresholdPercent = 1.0, DateTime? now}) {
  final trend = computeLiftTrend(lift, windowDays: windowDays, now: now);
  if (trend.quality == DataQuality.insufficient || trend.delta == null) return null;
  return trend.delta!.abs() < thresholdPercent;
}

/// Which of the 3 competition lifts improved the most over [windowDays] —
/// null if none has enough data to say.
LiftImprovement? bestLiftImprovement(BigLifts lifts, {int windowDays = 30, DateTime? now, required Map<String, String> labels}) {
  LiftImprovement? best;
  for (final key in BigLifts.keys) {
    final trend = computeLiftTrend(lifts.byKey(key), windowDays: windowDays, now: now);
    if (trend.delta == null) continue;
    if (best == null || trend.delta! > best.changePercent) {
      best = LiftImprovement(key: key, label: labels[key] ?? key, changePercent: trend.delta!);
    }
  }
  return best;
}

/// How many of the 3 competition lifts recorded a NEW pr within
/// [windowDays] — bounded to 0..3 since the app only keeps one current PR
/// per lift, not a full log of every PR ever set.
int countRecentLiftPrs(BigLifts lifts, {int windowDays = 30, DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final windowStart = today.subtract(Duration(days: windowDays));
  var count = 0;
  for (final key in BigLifts.keys) {
    final lift = lifts.byKey(key);
    final d = _parseIso(lift.prDate);
    if (lift.pr > 0 && d != null && !d.isBefore(windowStart)) count += 1;
  }
  return count;
}

/// 30-day bodyweight change — same insufficient-data guard as lift trends.
TrendStat computeBodyWeightTrend(List<BodyWeightEntry> entries, {int windowDays = 30, DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final windowStart = today.subtract(Duration(days: windowDays));

  final inWindow = entries.where((e) {
    final d = _parseIso(e.date);
    return d != null && !d.isBefore(windowStart);
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  if (inWindow.length < 2) {
    return TrendStat(delta: null, quality: DataQuality.insufficient, sampleCount: inWindow.length);
  }
  return TrendStat(
    delta: inWindow.last.weight - inWindow.first.weight, // absolute kg delta, not %
    quality: inWindow.length >= 4 ? DataQuality.good : DataQuality.limited,
    sampleCount: inWindow.length,
  );
}
