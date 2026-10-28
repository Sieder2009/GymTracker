import 'package:flutter/material.dart';

import '../analytics/progression_engine.dart';
import '../data/constants.dart';
import '../data/rep_side_split.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Shown when [suggestNextSession] has enough real logged history to
/// recommend what to try next -- a soft nudge, not a command, laid out
/// like [PlateauNotice] (which it sits next to in
/// `ExerciseAnalyticsSection`) so an exercise card can carry either, both,
/// or neither depending on what the data actually supports.
class ProgressionNotice extends StatelessWidget {
  const ProgressionNotice({super.key, required this.suggestion, this.compact = false});

  final ProgressionSuggestion suggestion;

  /// One tighter line without the title, for inside another card -- the
  /// icon and the sentence already say it's a suggestion.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final s = suggestion;
    // Every sentence names last session's numbers and the target, so the
    // advice explains itself ("8 · 7 at 100 kg, target 10 -> try 9 · 8").
    final lastWeight = '${fmt1(s.lastWeightKg)} kg';
    final nextWeight = '${fmt1(s.weightKg)} kg';
    final lastReps = s.lastReps.join(' · ');
    final nextReps = s.nextReps.join(' · ');

    final IconData icon;
    final Color color;
    final String body;
    switch (s.action) {
      case ProgressionAction.increaseWeight:
        icon = Icons.trending_up_rounded;
        color = colors.green;
        body = t.progressionAddWeight(lastReps, lastWeight, nextWeight, s.target);
      case ProgressionAction.holdWeight:
        icon = Icons.repeat_rounded;
        color = colors.accent;
        body = s.unilateral
            ? t.progressionHoldUnilateral(lastWeight, lastReps, s.target, nextReps,
                s.nextReps.map((r) => fmt(repsPerSide(r))).join(' · '))
            : t.progressionHold(lastWeight, lastReps, s.target, nextReps);
      case ProgressionAction.reduceWeight:
        icon = Icons.trending_down_rounded;
        color = colors.yellow;
        body = t.progressionReduceWeight(lastReps, lastWeight, s.target, nextWeight);
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(body, style: TextStyle(color: colors.txt, fontSize: 12))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.labelProgressionSuggestion,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: colors.mut, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
