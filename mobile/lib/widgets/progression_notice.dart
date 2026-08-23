import 'package:flutter/material.dart';

import '../analytics/progression_engine.dart';
import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Shown when [suggestNextSession] has enough real logged history to
/// recommend what to try next -- a soft nudge, not a command, laid out
/// like [PlateauNotice] (which it sits next to in
/// `ExerciseAnalyticsSection`) so an exercise card can carry either, both,
/// or neither depending on what the data actually supports.
class ProgressionNotice extends StatelessWidget {
  const ProgressionNotice({super.key, required this.suggestion});

  final ProgressionSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final weightLabel = '${fmt1(suggestion.weightKg)} kg';

    final IconData icon;
    final Color color;
    final String body;
    switch (suggestion.action) {
      case ProgressionAction.increaseWeight:
        icon = Icons.trending_up_rounded;
        color = colors.green;
        body = t.progressionIncreaseWeight(weightLabel);
        break;
      case ProgressionAction.increaseReps:
        icon = Icons.repeat_rounded;
        color = colors.accent;
        body = t.progressionIncreaseReps(weightLabel);
        break;
      case ProgressionAction.deload:
        icon = Icons.trending_down_rounded;
        color = colors.yellow;
        body = t.progressionDeload(weightLabel);
        break;
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
