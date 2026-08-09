class ExerciseSet {
  ExerciseSet({required this.w, required this.r, this.actualReps, this.rpe});

  double w;
  String r;

  /// Reps actually performed, logged live during a guided workout --
  /// distinct from [r] (the *target* rep range, e.g. "8-10") since a set
  /// might not hit the target. Null until the user logs it (or for sets
  /// saved before this field existed).
  int? actualReps;

  /// Rate of perceived exertion (5-10) logged for this set during a guided
  /// workout. Null when not collected.
  int? rpe;

  ExerciseSet clone() =>
      ExerciseSet(w: w, r: r, actualReps: actualReps, rpe: rpe);

  Map<String, dynamic> toJson() => {
        'w': w,
        'r': r,
        if (actualReps != null) 'actualReps': actualReps,
        if (rpe != null) 'rpe': rpe,
      };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
        w: (json['w'] as num).toDouble(),
        r: json['r'].toString(),
        actualReps: (json['actualReps'] as num?)?.toInt(),
        rpe: (json['rpe'] as num?)?.toInt(),
      );
}
