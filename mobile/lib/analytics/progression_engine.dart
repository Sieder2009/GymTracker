import '../data/rep_side_split.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/history_entry.dart';

/// What a [ProgressionSuggestion] recommends for the next session.
enum ProgressionAction {
  /// Every set logged last session reached the top of its rep target --
  /// add weight and work up through the target again.
  increaseWeight,

  /// The default whenever the target wasn't fully reached: stay at the
  /// weight and beat last session's reps, set by set. Being a few reps
  /// short (8 of 10) is how double progression is supposed to look, not a
  /// reason to go lighter.
  holdWeight,

  /// The last two sessions were both clearly too heavy (every set at least
  /// [kTooHeavyRepGap] reps under the target's floor) -- go to the weight
  /// that, by the same Epley estimate the app's 1RM uses, lands back inside
  /// the target.
  reduceWeight,
}

/// How far under its target's floor every set must land, two sessions in a
/// row, before a lighter weight is suggested. Two reps short is still "keep
/// at it"; three or more on every set means the weight doesn't fit the
/// target.
const int kTooHeavyRepGap = 3;

/// A soft, data-driven nudge for what to try next session with an
/// exercise -- never a command, same "nudge, not a diagnosis" tone as
/// [PlateauNotice]. Carries last session's numbers too, so the notice can
/// say why it suggests what it does. Built by [suggestNextSession].
class ProgressionSuggestion {
  const ProgressionSuggestion({
    required this.action,
    required this.weightKg,
    required this.lastWeightKg,
    required this.lastReps,
    required this.target,
    this.nextReps = const [],
    this.unilateral = false,
  });

  final ProgressionAction action;

  /// The weight to use next session, in kg -- the same as [lastWeightKg]
  /// for [ProgressionAction.holdWeight].
  final double weightKg;

  /// The weight logged last session, in kg.
  final double lastWeightKg;

  /// Last session's counted reps, set by set (markers and empty sets left
  /// out -- see [suggestNextSession]).
  final List<int> lastReps;

  /// The rep target the advice measures against, e.g. "8-10" or "10".
  final String target;

  /// [ProgressionAction.holdWeight] only: the reps to aim for next session,
  /// set by set -- one more than last time, never past the target's top.
  /// Even totals for a [unilateral] exercise, so they split evenly across
  /// both sides. Empty for the other actions.
  final List<int> nextReps;

  /// Whether the reps are totals across both sides (`Exercise.unilateral`).
  final bool unilateral;
}

class _RepRange {
  const _RepRange(this.min, this.max);
  final int min;
  final int max;

  @override
  String toString() => min == max ? '$min' : '$min-$max';
}

/// Parses a set's target rep field -- "8-10" (range) or "8" (fixed) --
/// into a min/max pair. Null for anything else (AMRAP, a bodyweight dash,
/// free text carried over from a pasted-log import): there's no numeric
/// target to progress against, so callers skip rather than guess one.
_RepRange? _parseRepRange(String r) {
  final trimmed = r.trim();
  final rangeMatch = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(trimmed);
  if (rangeMatch != null) {
    final a = int.parse(rangeMatch.group(1)!);
    final b = int.parse(rangeMatch.group(2)!);
    return _RepRange(a <= b ? a : b, a <= b ? b : a);
  }
  final single = int.tryParse(trimmed);
  return single != null ? _RepRange(single, single) : null;
}

/// The plate increment suggested on a clean clear -- a bigger jump for leg
/// exercises (squat-pattern compounds tend to move more weight per rep
/// than an upper-body lift), the same split Greyskull LP-style linear
/// progression draws between upper (+2.5kg) and lower body (+5kg). Reads
/// [Exercise.muscle]'s raw category key ('legs'/'back'/...), not a
/// localized label, so this is language-independent.
double _weightIncrement(Exercise exercise) => exercise.muscle == 'legs' ? 5.0 : 2.5;

/// The 2.5kg step `widgets/weight_ruler.dart` and the guided workout's
/// stepper snap to, so a lighter weight is always one they can dial in.
const double _weightStep = 2.5;

/// [entry]'s sets that carry a real rep count, each paired with the target
/// it's judged against: set i is measured against the plan's set i (its
/// last set for any extra set logged beyond it), or [fallback] when that
/// set's rep field holds no number. Markers ('✓'/'x'/'m', from the
/// hand-typed log format) and 0 -- what an empty rep field is saved as --
/// carry no count to judge, so they're skipped, same "never guessed" rule
/// `analytics_engine.dart`'s e1RM estimate follows.
List<(int, _RepRange)> _countedSets(HistoryEntry entry, Exercise exercise, _RepRange fallback) {
  final sets = exercise.sets;
  return [
    for (var i = 0; i < entry.reps.length; i++)
      if (entry.reps[i] case final int reps when reps > 0)
        (reps, _parseRepRange(sets[i < sets.length ? i : sets.length - 1].r) ?? fallback),
  ];
}

/// True when every counted set of [entry] landed at least [kTooHeavyRepGap]
/// reps under its target's floor. False when nothing can be judged -- an
/// entry with only markers never counts toward a lighter weight.
bool _tooHeavy(HistoryEntry entry, Exercise exercise, _RepRange fallback) {
  final counted = _countedSets(entry, exercise, fallback);
  return counted.isNotEmpty &&
      counted.every((s) => s.$1 <= s.$2.min - kTooHeavyRepGap);
}

/// Suggests what to try next session for [exercise], or null when there
/// isn't enough real data to say anything: no history yet, no numeric rep
/// target in the plan (free-text/AMRAP rep fields), a bodyweight session,
/// or a last session with no counted reps. Never a guess dressed up as a
/// number.
///
/// Double progression against each set's own target from the plan:
/// - every set at the top of its target -> more weight
///   ([ProgressionAction.increaseWeight]);
/// - otherwise the same weight with one more rep per set
///   ([ProgressionAction.holdWeight]) -- also after a bad day, and also
///   when a set or two is a little under the target's floor;
/// - only when the last two sessions were both clearly too heavy (see
///   [kTooHeavyRepGap]) a lighter weight that fits the target
///   ([ProgressionAction.reduceWeight]).
ProgressionSuggestion? suggestNextSession(Exercise exercise) {
  // A Timed/Cardio exercise has no numeric weight x reps to progress.
  if (exercise.logMode != ExerciseLogMode.reps) return null;
  if (exercise.history.isEmpty || exercise.sets.isEmpty) return null;
  _RepRange? fallback;
  for (final s in exercise.sets) {
    fallback = _parseRepRange(s.r);
    if (fallback != null) break;
  }
  if (fallback == null) return null;

  final history = exercise.history;
  final last = history.last;
  if (last.weight <= 0) return null;
  final counted = _countedSets(last, exercise, fallback);
  if (counted.isEmpty) return null;
  final lastReps = [for (final s in counted) s.$1];
  final target = fallback.toString();

  if (counted.every((s) => s.$1 >= s.$2.max)) {
    return ProgressionSuggestion(
      action: ProgressionAction.increaseWeight,
      weightKg: last.weight + _weightIncrement(exercise),
      lastWeightKg: last.weight,
      lastReps: lastReps,
      target: target,
      unilateral: exercise.unilateral,
    );
  }

  if (history.length >= 2 &&
      _tooHeavy(last, exercise, fallback) &&
      _tooHeavy(history[history.length - 2], exercise, fallback)) {
    // Epley from last session's best set, solved for the target's floor,
    // rounded down so the floor is actually reachable.
    final best = lastReps.reduce((a, b) => a > b ? a : b);
    final oneRepMax = last.weight * (1 + best / 30);
    var next = (oneRepMax / (1 + fallback.min / 30) / _weightStep).floor() * _weightStep;
    if (next >= last.weight) next = last.weight - _weightStep;
    if (next > 0) {
      return ProgressionSuggestion(
        action: ProgressionAction.reduceWeight,
        weightKg: next,
        lastWeightKg: last.weight,
        lastReps: lastReps,
        target: target,
        unilateral: exercise.unilateral,
      );
    }
  }

  int nextFor(int reps, _RepRange range) {
    final n = reps >= range.max ? reps : reps + 1;
    return exercise.unilateral ? nextEvenReps(n) : n;
  }

  return ProgressionSuggestion(
    action: ProgressionAction.holdWeight,
    weightKg: last.weight,
    lastWeightKg: last.weight,
    lastReps: lastReps,
    target: target,
    nextReps: [for (final s in counted) nextFor(s.$1, s.$2)],
    unilateral: exercise.unilateral,
  );
}
