import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/exercise_set.dart';
import 'constants.dart';

/// `m:ss` (or `h:mm:ss` past an hour) formatting for a duration given in
/// whole seconds -- the Timed/Cardio analogue of a rep count. Digits read
/// the same in every supported language, so this is deliberately free of
/// l10n (unlike e.g. `fmt`/`fmt1` in `constants.dart`, which format
/// locale-specific decimal separators).
String formatSeconds(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final ss = sec.toString().padLeft(2, '0');
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:$ss';
  }
  return '$m:$ss';
}

/// "3× 8-10" (Reps) / "3× 0:30" (Timed) / "20 min · 8.0 km/h" (Cardio) --
/// the single mode-aware place both `ExerciseCard` and the guided workout's
/// session-overview sheet build their compact per-exercise sets summary,
/// instead of each hand-rolling their own reps-shaped branch.
String exerciseSetsSummaryLabel(AppLocalizations t, Exercise exercise) {
  if (exercise.sets.isEmpty) return '';
  switch (exercise.logMode) {
    case ExerciseLogMode.reps:
      final distinctReps = exercise.sets.map((s) => s.r).toSet();
      final rep =
          distinctReps.length == 1 ? distinctReps.first : exercise.sets.first.r;
      return '${exercise.sets.length}× $rep';
    case ExerciseLogMode.timed:
      final seconds = exercise.sets.first.targetDurationSec ?? 0;
      return '${exercise.sets.length}× ${formatSeconds(seconds)}';
    case ExerciseLogMode.cardio:
      final first = exercise.sets.first;
      final minutes = ((first.targetDurationSec ?? 0) / 60).round();
      final speed = first.targetSpeedKmh ?? 0;
      return '$minutes ${t.unitMin} · ${fmt1(speed)} ${t.unitKmh}';
  }
}

/// Builds [setCount] identical [ExerciseSet]s for one freshly-authored
/// exercise, shaped for [mode] -- the one place `PlanEditorScreen` and
/// `AddExerciseSheet` both turn their editor fields into sets, so the two
/// surfaces can never drift apart on what each mode's set actually looks
/// like. [repsTarget] is only read in Reps mode; [targetSeconds] is the
/// target hold in Timed mode or the target duration (already converted to
/// seconds) in Cardio mode; [targetSpeedKmh] is Cardio-only. `w` keeps its
/// normal meaning throughout (working weight in Reps mode, optional added
/// weight in Timed mode, forced to 0 in Cardio mode).
List<ExerciseSet> buildLogModeSets({
  required ExerciseLogMode mode,
  required int setCount,
  required double weightKg,
  required String repsTarget,
  required int targetSeconds,
  required double targetSpeedKmh,
}) {
  switch (mode) {
    case ExerciseLogMode.reps:
      final r = repsTarget.isEmpty ? '—' : repsTarget;
      return List.generate(setCount, (_) => ExerciseSet(w: weightKg, r: r));
    case ExerciseLogMode.timed:
      final secs = targetSeconds < 1 ? 30 : targetSeconds;
      return List.generate(
          setCount, (_) => ExerciseSet(w: weightKg, r: '', targetDurationSec: secs));
    case ExerciseLogMode.cardio:
      final secs = targetSeconds < 1 ? 60 : targetSeconds;
      final speed = targetSpeedKmh < 0 ? 0.0 : targetSpeedKmh;
      return List.generate(
          setCount,
          (_) => ExerciseSet(
              w: 0, r: '', targetDurationSec: secs, targetSpeedKmh: speed));
  }
}
