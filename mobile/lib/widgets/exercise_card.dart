import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// A single exercise's card in the Training screen's day list: name (tap ->
/// detail), optional note, and one row per set with a ±2.5kg stepper and a
/// tap-to-mark-done indicator (one-way, never un-marked).
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTapName,
    required this.onAdjustWeight,
    required this.onToggleSet,
  });

  final Exercise exercise;
  final VoidCallback onTapName;
  final void Function(int setIdx, double delta) onAdjustWeight;
  final void Function(int setIdx) onToggleSet;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTapName,
              child: Text(
                exercise.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (exercise.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  exercise.note,
                  style: TextStyle(color: colors.mut, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 8),
            for (var i = 0; i < exercise.sets.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _SetRow(
                  index: i,
                  weight: exercise.sets[i].w,
                  reps: exercise.sets[i].r,
                  done: exercise.done.contains(i),
                  onAdjust: (delta) => onAdjustWeight(i, delta),
                  onToggle: () => onToggleSet(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.weight,
    required this.reps,
    required this.done,
    required this.onAdjust,
    required this.onToggle,
  });

  final int index;
  final double weight;
  final String reps;
  final bool done;
  final ValueChanged<double> onAdjust;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final weightLabel = weight > 0 ? '${fmt1(weight)} kg' : AppLocalizations.of(context)!.labelBodyweightAbbr;

    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '${index + 1}',
            style: TextStyle(color: colors.mut, fontSize: 12.5),
          ),
        ),
        _StepButton(icon: Icons.remove, onTap: () => onAdjust(-2.5)),
        Expanded(
          child: Center(
            child: Text(
              weightLabel,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        _StepButton(icon: Icons.add, onTap: () => onAdjust(2.5)),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            reps,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mut),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: done ? colors.green : colors.card2,
              shape: BoxShape.circle,
              border: Border.all(color: colors.line),
            ),
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colors.card2,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon, size: 18, color: colors.txt),
      ),
    );
  }
}
