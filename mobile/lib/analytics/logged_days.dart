import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/program.dart';
import '../models/workout_session.dart';
import 'heatmap_engine.dart';

/// Every training day the calendar should show: the recorded guided-workout
/// [sessions], plus one synthesized session per date on which exercises were
/// logged some other way -- opening a single exercise and pressing save
/// writes only a [HistoryEntry], never a [WorkoutSession], and that still
/// was a workout.
///
/// Dates that already have a real session keep exactly that session (the
/// guided workout writes history entries too, so adding them again would
/// count the same sets twice). History entries without a parseable date
/// (old pasted logs) are skipped rather than guessed onto some day.
///
/// Synthesized sessions carry the plan name(s), the logged sets' volume
/// (weight x reps, reps-mode only) and set count, and minutes only for
/// timed/cardio sets, whose durations are real; for a reps-only day the
/// duration is 0 -- unknown, not "zero minutes trained".
List<WorkoutSession> sessionsWithLoggedExercises(
  Iterable<WorkoutSession> sessions,
  Iterable<Program> programs,
) {
  final sessionDays = <String>{};
  for (final s in sessions) {
    final key = heatmapDateKey(s.date);
    if (key != null) sessionDays.add(key);
  }

  final logged = <String, _LoggedDay>{};
  for (final program in programs) {
    final exercises = <Exercise>[
      for (final day in program.days) ...day.exercises,
      ...program.dailyExercises,
    ];
    for (final exercise in exercises) {
      for (final entry in exercise.history) {
        final raw = entry.date;
        final key = raw == null ? null : heatmapDateKey(raw);
        if (key == null || sessionDays.contains(key)) continue;
        final day = logged.putIfAbsent(key, _LoggedDay.new);
        day.planNames.add(program.name);
        switch (entry.mode) {
          case ExerciseLogMode.reps:
            day.sets += entry.reps.length;
            for (final r in entry.reps) {
              day.volumeKg += entry.weight * _repCount(r);
            }
          case ExerciseLogMode.timed:
          case ExerciseLogMode.cardio:
            final durations = entry.durations ?? const <int>[];
            day.sets += durations.length;
            for (final seconds in durations) {
              day.seconds += seconds;
            }
        }
      }
    }
  }

  return [
    ...sessions,
    for (final MapEntry(key: date, value: day) in logged.entries)
      WorkoutSession(
        date: date,
        durationMinutes: (day.seconds / 60).round(),
        planName: day.planNames.join(', '),
        totalVolumeKg: day.volumeKg,
        totalSets: day.sets,
      ),
  ];
}

/// A logged rep value as a number: history stores ints, but hand-typed
/// logs can carry strings ("8") -- anything unreadable counts as 0 reps.
double _repCount(Object value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim()) ?? 0;
}

class _LoggedDay {
  final Set<String> planNames = {};
  double volumeKg = 0;
  int sets = 0;
  int seconds = 0;
}
