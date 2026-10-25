import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Shown when [isLiftPlateaued]/[isExercisePlateaued] found the last 30
/// days' trend essentially flat — a nudge, not a diagnosis (see
/// DESIGN.md §101.11/§101.29's "no medical-style diagnosis" rule).
class PlateauNotice extends StatelessWidget {
  const PlateauNotice({super.key, required this.label, this.compact = false});

  final String label;

  /// One tighter line without the title, for inside another card (same
  /// as [ProgressionNotice.compact]).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.yellow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.trending_flat, size: 16, color: colors.yellow),
            const SizedBox(width: 8),
            Expanded(child: Text(t.plateauBody(label, 30), style: TextStyle(color: colors.txt, fontSize: 12))),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.yellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colors.yellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_flat, size: 18, color: colors.yellow),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.labelPlateauDetected,
                  style: TextStyle(color: colors.yellow, fontWeight: FontWeight.w700, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(t.plateauBody(label, 30), style: TextStyle(color: colors.mut, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
