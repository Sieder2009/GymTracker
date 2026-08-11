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
  }) {
    return Exercise(
      name: name,
      muscle: muscle,
      rest: rest,
      sets: sets.map((s) => s.clone()).toList(),
      history: history ?? [],
      note: note,
      muscleActivation: muscleActivation,
    );
  }

  static double _maxWeight(List<ExerciseSet> sets) {
    var max = 0.0;
    for (final s in sets) {
      if (s.w > max) max = s.w;
    }
    return max;
  }

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
      );
}
