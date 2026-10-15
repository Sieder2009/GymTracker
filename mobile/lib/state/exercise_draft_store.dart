import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';

/// What was typed on the single-exercise screen but not saved yet: the
/// weight and every set row's main number (reps, seconds or minutes) and
/// speed, as text.
class ExerciseDraft {
  const ExerciseDraft({
    required this.logMode,
    required this.weight,
    required this.values,
    required this.speeds,
  });

  /// The mode the values were typed in -- a draft typed as reps must never
  /// come back as seconds after the exercise's mode was switched.
  final ExerciseLogMode logMode;
  final double weight;
  final List<String> values;
  final List<String> speeds;
}

/// Unsaved input of ExerciseDetailScreen, kept in memory only: it survives
/// browsing to another exercise and closing/reopening the screen, and is
/// dropped when the exercise is saved -- or with the app process, on
/// purpose never written to storage (a half-typed set from yesterday must
/// not reappear next week).
///
/// Keyed by the [Exercise] object itself (an [Expando], so a draft can
/// never keep a deleted exercise alive). The plan's exercises are the same
/// objects for the whole session; after a backup restore or plan import
/// they are new objects and the old drafts simply no longer match.
abstract final class ExerciseDraftStore {
  static final Expando<ExerciseDraft> _drafts = Expando('ExerciseDraft');

  static ExerciseDraft? of(Exercise exercise) => _drafts[exercise];

  static void put(Exercise exercise, ExerciseDraft draft) => _drafts[exercise] = draft;

  static void clear(Exercise exercise) => _drafts[exercise] = null;
}
