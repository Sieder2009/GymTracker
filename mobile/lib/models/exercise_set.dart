class ExerciseSet {
  ExerciseSet({
    required this.w,
    required this.r,
    this.actualReps,
    this.rpe,
    this.rir,
    this.targetDurationSec,
    this.targetSpeedKmh,
    this.actualDurationSec,
    this.actualSpeedKmh,
  });

  /// Weight in kg. KEEPS its existing meaning unconditionally regardless of
  /// the owning [Exercise.logMode]: normal working weight in Reps mode,
  /// optional added weight in Timed mode (0 = pure bodyweight, already
  /// renders as "BW"), always 0/unused in Cardio mode -- never repurposed
  /// to carry a speed or duration value, so every existing generic
  /// weight-consuming code path (plate calculator, big-lift tracking,
  /// `_maxWeight`/`currentWeight`) stays correct by construction.
  double w;

  /// Target rep range/count, e.g. "8-10" -- unchanged meaning for Reps mode.
  /// For Timed/Cardio sets this is always still written as a literal string
  /// (empty `''`, never omitted/null) -- required so a newer backup
  /// restored on an older app version doesn't null-cast-crash in the old
  /// `ExerciseSet.fromJson`.
  String r;

  /// Reps actually performed, logged live during a guided workout --
  /// distinct from [r] (the *target* rep range, e.g. "8-10") since a set
  /// might not hit the target. Null until the user logs it (or for sets
  /// saved before this field existed).
  int? actualReps;

  /// Rate of perceived exertion (5-10) logged for this set during a guided
  /// workout, when the global effort scale (see
  /// `state/effort_scale_provider.dart`) was set to RPE at the time. Null
  /// when not collected.
  ///
  /// Invariant: at most one of [rpe]/[rir] is ever non-null on a given set
  /// -- which one is populated *is* the scale tag, so a legacy blob that
  /// only ever wrote `rpe` needs no defaulting logic to keep reading as RPE
  /// forever. [ProgramsProvider.setEffort] is the one place that must keep
  /// this true by always clearing the other field on every write.
  int? rpe;

  /// Reps-in-reserve (0-5, where 0 means taken to failure) logged for this
  /// set during a guided workout, when the global effort scale was set to
  /// RIR at the time. Null when not collected. See the invariant on [rpe].
  int? rir;

  /// Planned hold/cardio duration in seconds, set by the exercise editor --
  /// the Timed/Cardio analogue of [r]. Null for a Reps-mode set, or a
  /// Timed/Cardio set saved before this field existed.
  int? targetDurationSec;

  /// Planned cardio speed in km/h, set by the exercise editor. Null for
  /// anything but a Cardio-mode set.
  double? targetSpeedKmh;

  /// Seconds actually held/elapsed, logged live during a guided workout --
  /// the Timed/Cardio analogue of [actualReps]. Null until logged.
  int? actualDurationSec;

  /// Actual cardio speed logged, in km/h. Null until logged, or for
  /// anything but a Cardio-mode set.
  double? actualSpeedKmh;

  ExerciseSet clone() => ExerciseSet(
        w: w,
        r: r,
        actualReps: actualReps,
        rpe: rpe,
        rir: rir,
        targetDurationSec: targetDurationSec,
        targetSpeedKmh: targetSpeedKmh,
        actualDurationSec: actualDurationSec,
        actualSpeedKmh: actualSpeedKmh,
      );

  Map<String, dynamic> toJson() => {
        'w': w,
        'r': r,
        if (actualReps != null) 'actualReps': actualReps,
        if (rpe != null) 'rpe': rpe,
        if (rir != null) 'rir': rir,
        if (targetDurationSec != null) 'targetDurationSec': targetDurationSec,
        if (targetSpeedKmh != null) 'targetSpeedKmh': targetSpeedKmh,
        if (actualDurationSec != null) 'actualDurationSec': actualDurationSec,
        if (actualSpeedKmh != null) 'actualSpeedKmh': actualSpeedKmh,
      };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
        w: (json['w'] as num).toDouble(),
        r: json['r'].toString(),
        actualReps: (json['actualReps'] as num?)?.toInt(),
        rpe: (json['rpe'] as num?)?.toInt(),
        rir: (json['rir'] as num?)?.toInt(),
        targetDurationSec: (json['targetDurationSec'] as num?)?.toInt(),
        targetSpeedKmh: (json['targetSpeedKmh'] as num?)?.toDouble(),
        actualDurationSec: (json['actualDurationSec'] as num?)?.toInt(),
        actualSpeedKmh: (json['actualSpeedKmh'] as num?)?.toDouble(),
      );
}
