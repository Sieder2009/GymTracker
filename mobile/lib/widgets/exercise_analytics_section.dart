import 'package:flutter/material.dart';

import '../analytics/analytics_engine.dart';
import '../analytics/progression_engine.dart';
import '../data/constants.dart';
import '../data/duration_format.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../theme/app_colors.dart';
import 'chart_card.dart';
import 'plateau_notice.dart';
import 'progression_notice.dart';
import 'trend_value.dart';

/// Per-exercise analytics — every exercise gets the same trend/e1RM/chart
/// treatment previously reserved for the 3 competition lifts, backed
/// entirely by [exercise.history]'s dated entries. Hidden entirely when
/// there's no history at all, so a brand-new exercise doesn't show an
/// empty analytics card before the user has logged anything.
class ExerciseAnalyticsSection extends StatelessWidget {
  const ExerciseAnalyticsSection({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    if (exercise.history.isEmpty) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;

    if (exercise.logMode != ExerciseLogMode.reps) {
      return _buildTimedOrCardio(context, t, colors);
    }

    final trend = computeExerciseTrend(exercise);
    final bestE1rm = bestEstimatedOneRepMax(exercise);
    final plateaued = isExercisePlateaued(exercise);
    final progression = suggestNextSession(exercise);
    final points = exerciseHistoryPoints(exercise)
        .map((p) => ChartPoint(p.date, p.e1rm ?? p.topWeight))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.titleAnalytics, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.labelTrend30Days, style: TextStyle(color: colors.mut, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      TrendValue(stat: trend, formatDelta: (d) => '${d.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: colors.line),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.labelEstOneRepMax, style: TextStyle(color: colors.mut, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          bestE1rm != null ? '${fmt1(bestE1rm)} kg' : t.insufficientDataShort,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: bestE1rm != null ? 16 : 12.5,
                            color: bestE1rm != null ? colors.txt : colors.mut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LineChartCard(
          title: t.chartTitleWeightProgress,
          points: points,
          emptyLabel: t.chartEmptyExercise,
          valueSuffix: ' kg',
          color: colors.accent,
          height: 160,
        ),
        if (progression != null) ...[
          const SizedBox(height: 12),
          ProgressionNotice(suggestion: progression),
        ],
        if (plateaued == true) ...[
          const SizedBox(height: 12),
          PlateauNotice(label: exercise.name),
        ],
      ],
    );
  }

  /// Timed/Cardio analytics -- swaps the Reps-only "Est. 1RM" tile + weight
  /// chart for a "Best hold"/"Best pace" tile + hold-duration/speed chart.
  /// No progression/plateau notice here: [suggestNextSession] is explicitly
  /// guarded to return null for a non-Reps exercise, so there is nothing
  /// weight-based to suggest.
  Widget _buildTimedOrCardio(
      BuildContext context, AppLocalizations t, AppColors colors) {
    final isTimed = exercise.logMode == ExerciseLogMode.timed;
    final trend = isTimed
        ? computeExerciseTimeTrend(exercise)
        : computeExerciseSpeedTrend(exercise);
    final best = isTimed ? bestHeldSeconds(exercise) : bestSpeedKmh(exercise);
    final points = (isTimed
            ? exerciseTimeHistoryPoints(exercise)
            : exerciseSpeedHistoryPoints(exercise))
        .map((p) => ChartPoint(p.key, p.value))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.titleAnalytics, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.labelTrend30Days, style: TextStyle(color: colors.mut, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      TrendValue(stat: trend, formatDelta: (d) => '${d.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: colors.line),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isTimed ? t.labelBestHold : t.labelBestPace, style: TextStyle(color: colors.mut, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          best != null
                              ? (isTimed
                                  ? formatSeconds(best.round())
                                  : '${fmt1(best)} ${t.unitKmh}')
                              : t.insufficientDataShort,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: best != null ? 16 : 12.5,
                            color: best != null ? colors.txt : colors.mut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LineChartCard(
          title: isTimed ? t.chartTitleHoldProgress : t.chartTitlePaceProgress,
          points: points,
          emptyLabel: t.chartEmptyExercise,
          valueSuffix: isTimed ? 's' : ' ${t.unitKmh}',
          color: colors.accent,
          height: 160,
        ),
      ],
    );
  }
}
