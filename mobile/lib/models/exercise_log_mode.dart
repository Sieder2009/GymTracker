/// How one plan entry's sets are logged -- see the architecture note on
/// `exercise_template.dart`: this is a per-plan-entry logging choice made in
/// the exercise editor(s), never exercise identity. Defaults to [reps] for
/// every existing and new exercise, so nothing changes unless a user
/// explicitly opts in.
///
/// IMPORTANT naming note: this is unrelated to the pre-existing broad
/// category string `Exercise.muscle == 'cardio'` (one of
/// `kExerciseCategories` in `widgets/exercise_list_view.dart`) -- a treadmill
/// exercise tagged `muscle: 'cardio'` is not automatically `logMode:
/// cardio`, and vice versa. Keep these two axes conceptually and textually
/// distinct.
enum ExerciseLogMode {
  /// Weight x reps -- today's only behavior, unchanged.
  reps,

  /// A held/timed set (planks, wall-sits, hangs, loaded carries): logs
  /// seconds held instead of reps, plus an optional added weight.
  timed,

  /// A duration+speed cardio bout: logs seconds elapsed and km/h, no
  /// weight at all.
  cardio,
}

/// Defensive: a missing key (every exercise saved before this feature
/// existed), a corrupted value, or a future mode this build doesn't know
/// about all read back as [ExerciseLogMode.reps] -- matching today's only
/// behavior and never crashing on an unrecognized value.
ExerciseLogMode exerciseLogModeFromJson(String? raw) => switch (raw) {
      'timed' => ExerciseLogMode.timed,
      'cardio' => ExerciseLogMode.cardio,
      _ => ExerciseLogMode.reps,
    };

String exerciseLogModeToJson(ExerciseLogMode mode) => mode.name;
