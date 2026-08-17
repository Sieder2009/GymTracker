import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// "3× 8-10" -- falls back to the first set's rep range when sets carry
/// different targets (e.g. a pyramid scheme), rather than an unbounded
/// concatenation that wouldn't fit this compact list row.
String _setsRepsLabel(Exercise exercise) {
  if (exercise.sets.isEmpty) return '';
  final distinctReps = exercise.sets.map((s) => s.r).toSet();
  final rep = distinctReps.length == 1 ? distinctReps.first : exercise.sets.first.r;
  return '${exercise.sets.length}× $rep';
}

/// A single exercise's card in the Training screen's day list -- name,
/// current weight, target sets×reps, and a technique note, nothing else.
/// Sets are logged and weight is adjusted exclusively in the exercise
/// detail screen (tap to open); this card is read-only, deliberately
/// without a per-set confirm button or its own weight steppers.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTapName,
  });

  final Exercise exercise;
  final VoidCallback onTapName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;
    final weight = exercise.currentWeight;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTapName,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
                          _setsRepsLabel(exercise),
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
                weight > 0 ? '${fmt1(weight)} kg' : t.labelBodyweightAbbr,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
