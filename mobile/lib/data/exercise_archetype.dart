import '../models/exercise_template.dart';

/// Movement-pattern archetypes for [ExerciseArchetypeAnimation] -- a small,
/// reusable set of ORIGINAL animated illustrations (see that widget) rather
/// than one bespoke animation per exercise, which hundreds of exercises
/// makes infeasible. [core] is also the fallback for anything that isn't a
/// push/pull/squat/hinge rep pattern (ab work, cardio).
enum ExerciseArchetype {
  verticalPush,
  horizontalPush,
  verticalPull,
  horizontalPull,
  squat,
  hinge,
  curl,
  extension,
  core,
}

ExerciseArchetype _categoryDefault(String category) {
  switch (category) {
    case 'chest':
      return ExerciseArchetype.horizontalPush;
    case 'shoulders':
      return ExerciseArchetype.verticalPush;
    case 'back':
      return ExerciseArchetype.horizontalPull;
    case 'legs':
      return ExerciseArchetype.squat;
    case 'arms':
      return ExerciseArchetype.curl;
    default:
      return ExerciseArchetype.core;
  }
}

/// Best-effort heuristic, same honest-fallback spirit as
/// `exercise_muscle_map.dart`'s `_categoryDefault` -- a category-level
/// default refined by a few common name keywords, never a claim of
/// per-exercise accuracy.
ExerciseArchetype archetypeForExercise(ExerciseTemplate ex) {
  final name = ex.name.toLowerCase();
  if (name.contains('deadlift') ||
      name.contains('rdl') ||
      name.contains('hip thrust') ||
      name.contains('good morning')) {
    return ExerciseArchetype.hinge;
  }
  if (name.contains('squat') || name.contains('lunge') || name.contains('leg press')) {
    return ExerciseArchetype.squat;
  }
  if (name.contains('pulldown') ||
      name.contains('pull-up') ||
      name.contains('pullup') ||
      name.contains('chin-up') ||
      name.contains('chinup')) {
    return ExerciseArchetype.verticalPull;
  }
  if (name.contains('row')) return ExerciseArchetype.horizontalPull;
  if (name.contains('curl')) return ExerciseArchetype.curl;
  if (name.contains('extension') ||
      name.contains('pushdown') ||
      name.contains('skull') ||
      name.contains('kickback') ||
      name.contains('raise')) {
    return ExerciseArchetype.extension;
  }
  return _categoryDefault(ex.category);
}
