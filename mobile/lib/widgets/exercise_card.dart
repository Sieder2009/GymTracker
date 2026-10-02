import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/duration_format.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// The trailing badge -- weight/BW for Reps (unchanged, still driven by
/// [Exercise.currentWeight]'s history-derived value), the added weight (if
/// any) or else the target hold time for Timed, and the target speed for
/// Cardio (target duration already shows in the sets summary line above).
///
/// Timed/Cardio deliberately read the added weight from the exercise's own
/// LIVE set config (`sets.first.w`/`targetDurationSec`/`targetSpeedKmh`)
/// rather than [Exercise.currentWeight] -- that getter is mode-unaware (it
/// just returns whichever history entry was logged last, in whatever mode
/// that was), so right after a Reps→Timed flip it would still show the
/// stale Reps working weight as if it were an added weight.
String _trailingLabel(AppLocalizations t, Exercise exercise) {
  switch (exercise.logMode) {
    case ExerciseLogMode.reps:
      final weight = exercise.currentWeight;
      return weight > 0 ? '${fmt1(weight)} kg' : t.labelBodyweightAbbr;
    case ExerciseLogMode.timed:
      final weight = exercise.sets.isNotEmpty ? exercise.sets.first.w : 0.0;
      if (weight > 0) return '${fmt1(weight)} kg';
      final seconds =
          exercise.sets.isNotEmpty ? exercise.sets.first.targetDurationSec ?? 0 : 0;
      return formatSeconds(seconds);
    case ExerciseLogMode.cardio:
      final speed =
          exercise.sets.isNotEmpty ? exercise.sets.first.targetSpeedKmh ?? 0 : 0.0;
      return '${fmt1(speed)} ${t.unitKmh}';
  }
}

/// A single exercise's card in the Training screen's day list -- name,
/// current weight, target sets×reps, and a technique note, nothing else.
/// Sets are logged and weight is adjusted exclusively in the exercise
/// detail screen (tap to open); this card is read-only, deliberately
/// without a per-set confirm button or its own weight steppers. [onDelete]
/// is the one exception -- a whole-exercise removal, not a per-set edit --
/// and only shows its trailing button when the caller passes one.
///
/// [onToggleSuperset], when non-null, adds a link toggle for chaining this
/// exercise with the very next one in the same list into a superset (see
/// `data/superset_steps.dart`) -- the caller only passes it for a card that
/// isn't the list's last, since there's nothing to link to otherwise.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTapName,
    this.onDelete,
    this.onToggleSuperset,
  });

  final Exercise exercise;
  final VoidCallback onTapName;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleSuperset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;
    final linked = exercise.supersetWithNext;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTapName,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (exercise.sets.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              exerciseSetsSummaryLabel(t, exercise),
                              style: TextStyle(color: colors.mut, fontSize: 12.5),
                            ),
                          ),
                        if (exercise.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              exercise.note,
                              style: TextStyle(color: colors.mut, fontSize: 12.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _trailingLabel(t, exercise),
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (onToggleSuperset != null)
                    IconButton(
                      icon: Icon(linked ? Icons.link_rounded : Icons.link_off_rounded, size: 20),
                      color: linked ? colors.accent : colors.mut,
                      tooltip: t.actionToggleSuperset,
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleSuperset,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: t.actionDelete,
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                ],
              ),
              if (linked) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_rounded, size: 14, color: colors.accent),
                    const SizedBox(width: 4),
                    Text(
                      t.labelSupersetWithNext,
                      style: TextStyle(color: colors.accent, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
              if (exercise.unilateral) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 14, color: colors.mut),
                    const SizedBox(width: 4),
                    Text(
                      t.labelUnilateralTag,
                      style: TextStyle(color: colors.mut, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
