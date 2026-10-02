import 'exercise_log_mode.dart';

/// One historical session's per-set rep record for an exercise.
///
/// `reps` mixes actual rep counts (`int`) with letter markers carried over
/// from the hand-typed log format: `'✓'` = completed without a logged rep
/// count, `'x'` = weniger Gewicht verwendet, `'m'` = mehr Gewicht verwendet.
class HistoryEntry {
  HistoryEntry({
    required this.weight,
    required this.reps,
    this.date,
    this.mode = ExerciseLogMode.reps,
    this.durations,
    this.speeds,
  });

  double weight;
  List<Object> reps;

  /// 'YYYY-MM-DD', when known. Entries logged live (ExerciseDetailScreen
  /// "Speichern") are stamped with today's date; entries from a pasted log
  /// import have no real per-session date (the hand-typed format doesn't
  /// carry one) and stay null — analytics must treat those as
  /// undated/all-time data, never guess a date for them.
  String? date;

  /// Which [ExerciseLogMode] this entry was logged under -- stamped once at
  /// write time, NOT re-derived from the owning exercise's current
  /// `logMode`, so a later mode flip on the exercise never recolors
  /// already-logged history (an old Reps PR stays a Reps PR even after the
  /// exercise is switched to Timed, and vice versa). Every history/
  /// achievement consumer must filter on this field, not `exercise.logMode`.
  /// Defaults to [ExerciseLogMode.reps] for every blob saved before this
  /// feature existed.
  ExerciseLogMode mode;

  /// Per-set actual seconds held/elapsed, Timed & Cardio only. Null for a
  /// Reps entry.
  List<int>? durations;

  /// Per-set actual speed in km/h, Cardio only. Null otherwise.
  List<double>? speeds;

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'date': date,
        'mode': exerciseLogModeToJson(mode),
        if (durations != null) 'durations': durations,
        if (speeds != null) 'speeds': speeds,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        weight: (json['weight'] as num).toDouble(),
        reps: List<Object>.from(json['reps'] as List),
        date: json['date'] as String?,
        mode: exerciseLogModeFromJson(json['mode'] as String?),
        durations: (json['durations'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        speeds: (json['speeds'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
      );
}
