import 'exercise_log_mode.dart';
import 'exercise_set.dart';
import 'history_entry.dart';

class Exercise {
  Exercise({
    required this.name,
    required this.muscle,
    required this.rest,
    required this.sets,
    List<int>? done,
    double? startW,
    List<HistoryEntry>? history,
    this.note = '',
    Map<String, double>? muscleActivation,
    this.supersetWithNext = false,
    this.unilateral = false,
    this.logMode = ExerciseLogMode.reps,
  })  : done = done ?? [],
        history = history ?? [],
        startW = startW ?? _maxWeight(sets),
        muscleActivation = muscleActivation ?? const {};

  String name;
  String muscle;
  int rest; // seconds
  List<ExerciseSet> sets;
  List<int> done; // indices of sets marked done — one-way, never un-marked
  double startW; // baseline weight for progress deltas
  List<HistoryEntry> history;
  String note;

  /// True when this exercise is chained into a superset with whichever
  /// exercise immediately follows it in the same day's list -- a whole
  /// superset group is just a run of consecutive exercises each with this
  /// set to true (see `data/superset_steps.dart`), so grouping never needs
  /// its own id, and a plain, non-superset plan (every existing saved plan,
  /// since this defaults false) walks exactly as it always did.
  bool supersetWithNext;

  /// True when this exercise is logged per side (unilateral) -- lunges,
  /// single-arm rows, and similar movements where the user still logs the
  /// TOTAL reps across both sides on [ExerciseSet] exactly as today, but
  /// the app additionally derives and shows the per-side split (see
  /// `data/rep_side_split.dart`) and steps any rep stepper/suggestion for
  /// this exercise by 2 instead of 1, so its total can never drift to a
  /// number that can't split evenly across both sides. Off by default for
  /// every existing and new exercise -- a per-plan-entry logging property,
  /// not exercise identity (see the architecture note on
  /// `exercise_template.dart`).
  bool unilateral;

  /// How this plan entry's sets are logged -- see [ExerciseLogMode]. Off
  /// (i.e. [ExerciseLogMode.reps]) by default for every existing and new
  /// exercise, a per-plan-entry choice made in the exercise editor(s), not
  /// exercise identity.
  ExerciseLogMode logMode;

  /// [MuscleGroup.name] -> activation intensity 0-100, set via
  /// [MuscleActivationEditor] on a user-authored custom exercise. Empty
  /// (never null) when the user hasn't configured it — a broad, missing
  /// detail, not a zero.
  Map<String, double> muscleActivation;

  /// Builds a fresh [Exercise] from its base fields — deep-clones `sets`
  /// and derives `startW` from their max weight.
  factory Exercise.fresh(
    String name,
    String muscle,
    int rest,
    List<ExerciseSet> sets, {
    List<HistoryEntry>? history,
    String note = '',
    Map<String, double>? muscleActivation,
    bool unilateral = false,
    ExerciseLogMode logMode = ExerciseLogMode.reps,
  }) {
    return Exercise(
      name: name,
      muscle: muscle,
      rest: rest,
      sets: sets.map((s) => s.clone()).toList(),
      history: history ?? [],
      note: note,
      muscleActivation: muscleActivation,
      unilateral: unilateral,
      logMode: logMode,
    );
  }

  static double _maxWeight(List<ExerciseSet> sets) {
    var max = 0.0;
    for (final s in sets) {
      if (s.w > max) max = s.w;
    }
    return max;
  }

  /// The weight to show as "current" for this exercise -- the most
  /// recently logged history entry's weight (last entered, never the
  /// heaviest ever lifted), or each set's configured weight before any
  /// history exists yet.
  double get currentWeight =>
      history.isNotEmpty ? history.last.weight : _maxWeight(sets);

  Map<String, dynamic> toJson() => {
        'name': name,
        'muscle': muscle,
        'rest': rest,
        'sets': sets.map((s) => s.toJson()).toList(),
        'done': done,
        'startW': startW,
        'history': history.map((h) => h.toJson()).toList(),
        'note': note,
        'muscleActivation': muscleActivation,
        'supersetWithNext': supersetWithNext,
        'unilateral': unilateral,
        'logMode': exerciseLogModeToJson(logMode),
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        name: json['name'] as String,
        muscle: json['muscle'] as String? ?? '',
        rest: (json['rest'] as num?)?.toInt() ?? 90,
        sets: (json['sets'] as List)
            .map((s) => ExerciseSet.fromJson(s as Map<String, dynamic>))
            .toList(),
        done: List<int>.from(json['done'] as List? ?? []),
        startW: (json['startW'] as num?)?.toDouble(),
        history: (json['history'] as List? ?? [])
            .map((h) => HistoryEntry.fromJson(h as Map<String, dynamic>))
            .toList(),
        note: json['note'] as String? ?? '',
        muscleActivation: (json['muscleActivation'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        supersetWithNext: json['supersetWithNext'] as bool? ?? false,
        unilateral: json['unilateral'] as bool? ?? false,
        logMode: exerciseLogModeFromJson(json['logMode'] as String?),
      );
}
