/// One historical session's per-set rep record for an exercise.
///
/// `reps` mixes actual rep counts (`int`) with letter markers carried over
/// from the hand-typed log format: `'✓'` = completed without a logged rep
/// count, `'x'` = weniger Gewicht verwendet, `'m'` = mehr Gewicht verwendet.
class HistoryEntry {
  HistoryEntry({required this.weight, required this.reps, this.date});

  double weight;
  List<Object> reps;

  /// 'YYYY-MM-DD', when known. Entries logged live (ExerciseDetailScreen
  /// "Speichern") are stamped with today's date; entries from a pasted log
  /// import have no real per-session date (the hand-typed format doesn't
  /// carry one) and stay null — analytics must treat those as
  /// undated/all-time data, never guess a date for them.
  String? date;

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps, 'date': date};

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        weight: (json['weight'] as num).toDouble(),
        reps: List<Object>.from(json['reps'] as List),
        date: json['date'] as String?,
      );
}
