import '../models/exercise.dart';

/// One set to perform, in walk order, for a guided workout session.
/// [restAfter] is false for every step except the last one in a superset
/// "round" (or every step of a plain, non-grouped exercise) -- the guided
/// workout screen starts its rest timer only when [restAfter] is true, and
/// otherwise advances straight to the next step with no rest in between.
class WorkoutStep {
  const WorkoutStep({
    required this.exerciseIndex,
    required this.setIndex,
    required this.restAfter,
  });

  /// Index into the ordered exercise list this step was built from.
  final int exerciseIndex;
  final int setIndex;
  final bool restAfter;

  @override
  bool operator ==(Object other) =>
      other is WorkoutStep &&
      other.exerciseIndex == exerciseIndex &&
      other.setIndex == setIndex &&
      other.restAfter == restAfter;

  @override
  int get hashCode => Object.hash(exerciseIndex, setIndex, restAfter);

  @override
  String toString() => 'WorkoutStep(ex: $exerciseIndex, set: $setIndex, restAfter: $restAfter)';
}

/// Flattens [exercises] (already in the session's walk order) into the
/// literal sequence of sets a guided workout steps through.
///
/// A superset is a run of consecutive exercises chained by
/// [Exercise.supersetWithNext] -- e.g. A.supersetWithNext=true,
/// B.supersetWithNext=true, C.supersetWithNext=false groups [A, B, C].
/// Its sets interleave round-by-round (A's set 1, B's set 1, C's set 1,
/// *rest*, A's set 2, B's set 2, C's set 2, *rest*, ...) rather than
/// finishing one exercise before starting the next; a member with fewer
/// sets than the group's longest simply drops out of later rounds. A plain
/// exercise (supersetWithNext always false, the case for every exercise in
/// an existing saved plan) is its own group of one, walked set-by-set with
/// a rest after every single one -- byte-for-byte the same order this
/// screen always used before supersets existed.
List<WorkoutStep> buildWorkoutSteps(List<Exercise> exercises) {
  final steps = <WorkoutStep>[];
  var i = 0;
  while (i < exercises.length) {
    var groupEnd = i;
    while (groupEnd < exercises.length - 1 && exercises[groupEnd].supersetWithNext) {
      groupEnd += 1;
    }
    final groupIndices = [for (var k = i; k <= groupEnd; k++) k];

    if (groupIndices.length == 1) {
      final ex = exercises[i];
      for (var s = 0; s < ex.sets.length; s++) {
        steps.add(WorkoutStep(exerciseIndex: i, setIndex: s, restAfter: true));
      }
    } else {
      final maxSets = groupIndices.map((idx) => exercises[idx].sets.length).fold(0, (a, b) => a > b ? a : b);
      for (var round = 0; round < maxSets; round++) {
        final roundSteps = [
          for (final idx in groupIndices)
            if (round < exercises[idx].sets.length)
              WorkoutStep(exerciseIndex: idx, setIndex: round, restAfter: false),
        ];
        if (roundSteps.isEmpty) continue;
        steps.addAll(roundSteps.sublist(0, roundSteps.length - 1));
        final last = roundSteps.last;
        steps.add(WorkoutStep(exerciseIndex: last.exerciseIndex, setIndex: last.setIndex, restAfter: true));
      }
    }
    i = groupEnd + 1;
  }
  return steps;
}
