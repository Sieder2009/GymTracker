import '../models/exercise.dart';
import '../models/history_entry.dart';

/// What a [ProgressionSuggestion] recommends for the next session.
enum ProgressionAction {
  /// Every numeric rep logged last session matched or beat the top of the
  /// exercise's rep range -- add weight and restart at the bottom of the
  /// range.
  increaseWeight,

  /// Last session landed inside the rep range but short of the top --
  /// double progression: hold the weight, chase one more rep.
  increaseReps,

  /// Missed the bottom of the rep range on the last two logged sessions in
  /// a row -- suggest a deload rather than grinding at a stuck weight.
  deload,
}

/// A soft, data-driven nudge for what to try next session with an
/// exercise -- never a command, same "nudge, not a diagnosis" tone as
/// [PlateauNotice]. Built by [suggestNextSession].
class ProgressionSuggestion {
  const ProgressionSuggestion({required this.action, required this.weightKg});

  final ProgressionAction action;

  /// The weight to try next session, in kg -- unchanged from the last
  /// logged weight for [ProgressionAction.increaseReps].
  final double weightKg;
}

/// Numeric rep counts only. [HistoryEntry.reps] also carries non-numeric
/// markers ('✓'/'x'/'m') from the hand-typed log format, which carry no
/// reliable count to judge a rep-range target against -- same "never
/// guessed" rule `analytics_engine.dart`'s e1RM estimate follows for the
/// same markers.
List<int> _numericReps(List<Object> reps) => [for (final r in reps) if (r is int) r];

class _RepRange {
  const _RepRange(this.min, this.max);
  final int min;
  final int max;
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

/// Rounds to the nearest 2.5kg step -- the same increment
/// `widgets/weight_ruler.dart` snaps manual weight entry to -- so a
/// suggestion always lands on a weight the slider can actually hit.
double _roundToStep(double kg, {double step = 2.5}) => (kg / step).round() * step;

/// True when every numeric rep logged in [entry] fell short of [range]'s
/// floor. Null (neither hit nor miss) when the entry has no numeric reps
/// at all -- only markers, or an undated import -- so a session that
/// can't be judged never silently counts as a miss.
bool? _missedFloor(HistoryEntry entry, _RepRange range) {
  final reps = _numericReps(entry.reps);
  if (reps.isEmpty) return null;
  return reps.every((r) => r < range.min);
}

/// Suggests what to try next session for [exercise], or null when there
/// isn't enough real data to say anything: no history yet, no numeric rep
/// target to read (free-text/AMRAP rep field), or the last logged session
/// carries only non-numeric markers. Never a guess dressed up as a number.
///
/// Double progression within the exercise's own configured rep range (its
/// first set's target -- see [_parseRepRange]): a full clear (every
/// logged rep at or above the top of the range) bumps the weight; a
/// session inside the range but short of the top holds the weight and
/// chases one more rep; two clean misses of the range's floor in a row
/// suggest a deload instead of grinding at a stuck weight. A single missed
/// session stays quiet rather than nagging after one off day.
ProgressionSuggestion? suggestNextSession(Exercise exercise) {
  if (exercise.history.isEmpty || exercise.sets.isEmpty) return null;
  final range = _parseRepRange(exercise.sets.first.r);
  if (range == null) return null;

  final history = exercise.history;
  final last = history.last;
  if (last.weight <= 0) return null;
  final lastNumeric = _numericReps(last.reps);
  if (lastNumeric.isEmpty) return null;

  if (lastNumeric.every((r) => r >= range.max)) {
    return ProgressionSuggestion(
      action: ProgressionAction.increaseWeight,
      weightKg: last.weight + _weightIncrement(exercise),
    );
  }

  if (_missedFloor(last, range) == true) {
    final missedBefore =
        history.length >= 2 && _missedFloor(history[history.length - 2], range) == true;
    if (!missedBefore) return null;
    return ProgressionSuggestion(
      action: ProgressionAction.deload,
      weightKg: _roundToStep(last.weight * 0.9),
    );
  }

  return ProgressionSuggestion(action: ProgressionAction.increaseReps, weightKg: last.weight);
}
