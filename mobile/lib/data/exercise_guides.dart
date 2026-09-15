import '../l10n/app_localizations.dart';
import 'exercise_archetype.dart';

/// Short "how to do it" + "watch out for" tips for an [ExerciseArchetype],
/// shown as the localized replacement for the old per-exercise archetype
/// animation. See [ExerciseArchetype] for why this is per movement
/// pattern rather than per exercise.
String exerciseGuideText(AppLocalizations t, ExerciseArchetype archetype) {
  switch (archetype) {
    case ExerciseArchetype.verticalPush:
      return t.exerciseGuideVerticalPush;
    case ExerciseArchetype.horizontalPush:
      return t.exerciseGuideHorizontalPush;
    case ExerciseArchetype.verticalPull:
      return t.exerciseGuideVerticalPull;
    case ExerciseArchetype.horizontalPull:
      return t.exerciseGuideHorizontalPull;
    case ExerciseArchetype.squat:
      return t.exerciseGuideSquat;
    case ExerciseArchetype.hinge:
      return t.exerciseGuideHinge;
    case ExerciseArchetype.curl:
      return t.exerciseGuideCurl;
    case ExerciseArchetype.extension:
      return t.exerciseGuideExtension;
    case ExerciseArchetype.core:
      return t.exerciseGuideCore;
  }
}
