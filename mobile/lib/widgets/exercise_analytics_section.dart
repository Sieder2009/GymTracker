import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/analytics_engine.dart';
import '../analytics/progression_engine.dart';
import '../data/constants.dart';
import '../data/duration_format.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/history_entry.dart';
import '../theme/app_colors.dart';
import 'chart_card.dart';
import 'history_entry_sheet.dart';
import 'plateau_notice.dart';
import 'progression_notice.dart';
import 'trend_value.dart';

String _formatRep(Object v) => v is int ? '$v' : v.toString().toUpperCase();

/// How many sessions the list shows before "Show all".
const int _kCollapsedEntries = 5;

/// An exercise's history in one compact card -- the same trend/e1RM/chart
/// treatment the 3 competition lifts get, backed entirely by
/// [exercise.history]'s dated entries: best value and 30-day trend in one
/// line, a low chart, the next-session suggestion or plateau note, and the
/// logged sessions as a list going down (newest first, the latest five
/// until expanded) -- tap one to correct or delete it. Hidden entirely
/// when there's no history at all, so a brand-new exercise doesn't show an
/// empty card before the user has logged anything.
class ExerciseAnalyticsSection extends StatefulWidget {
  const ExerciseAnalyticsSection({super.key, required this.exercise, this.onChanged});

  final Exercise exercise;

  /// Called after an entry was corrected or deleted from this list.
  final VoidCallback? onChanged;

  @override
  State<ExerciseAnalyticsSection> createState() => _ExerciseAnalyticsSectionState();
}

class _ExerciseAnalyticsSectionState extends State<ExerciseAnalyticsSection> {
  bool _expanded = false;

  @override
  void didUpdateWidget(ExerciseAnalyticsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Browsing to the next exercise starts collapsed again.
    if (!identical(oldWidget.exercise, widget.exercise)) _expanded = false;
  }

  Future<void> _edit(HistoryEntry entry) async {
    final changed = await showHistoryEntrySheet(context, exercise: widget.exercise, entry: entry);
    if (!changed || !mounted) return;
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    if (exercise.history.isEmpty) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;

    final TrendStat trend;
    final String bestLabel;
    final String? bestValue;
    final List<ChartPoint> points;
    final String valueSuffix;
    ProgressionSuggestion? progression;
    var plateaued = false;
    switch (exercise.logMode) {
      case ExerciseLogMode.reps:
        trend = computeExerciseTrend(exercise);
        bestLabel = t.labelEstOneRepMax;
        final best = bestEstimatedOneRepMax(exercise);
        bestValue = best != null ? '${fmt1(best)} kg' : null;
        points = exerciseHistoryPoints(exercise).map((p) => ChartPoint(p.date, p.e1rm ?? p.topWeight)).toList();
        valueSuffix = ' kg';
        progression = suggestNextSession(exercise);
        plateaued = isExercisePlateaued(exercise) == true;
      // Timed/Cardio: the longest hold / fastest pace instead of an e1RM,
      // and no progression or plateau note -- [suggestNextSession] has
      // nothing weight-based to suggest for them.
      case ExerciseLogMode.timed:
        trend = computeExerciseTimeTrend(exercise);
        bestLabel = t.labelBestHold;
        final best = bestHeldSeconds(exercise);
        bestValue = best != null ? formatSeconds(best.round()) : null;
        points = exerciseTimeHistoryPoints(exercise).map((p) => ChartPoint(p.key, p.value)).toList();
        valueSuffix = 's';
      case ExerciseLogMode.cardio:
        trend = computeExerciseSpeedTrend(exercise);
        bestLabel = t.labelBestPace;
        final best = bestSpeedKmh(exercise);
        bestValue = best != null ? '${fmt1(best)} ${t.unitKmh}' : null;
        points = exerciseSpeedHistoryPoints(exercise).map((p) => ChartPoint(p.key, p.value)).toList();
        valueSuffix = ' ${t.unitKmh}';
    }

    final newestFirst = exercise.history.reversed.toList();
    final shown = _expanded ? newestFirst : newestFirst.take(_kCollapsedEntries).toList();
    // The X/M/✓ legend only matters once an entry actually carries one of
    // those markers (hand-typed log imports); numbers explain themselves.
    final hasMarkers = newestFirst.any((e) => e.mode == ExerciseLogMode.reps && e.reps.any((r) => r is! int));
    final statLabelStyle = TextStyle(color: colors.mut, fontSize: 11, fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.headerHistory, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(bestLabel, style: statLabelStyle),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        bestValue ?? t.insufficientDataShort,
                        style: bestValue != null
                            ? TextStyle(color: colors.txt, fontSize: 15, fontWeight: FontWeight.w700)
                            : TextStyle(color: colors.mut, fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Text(t.labelTrend30Days, style: statLabelStyle),
                    const SizedBox(width: 6),
                    TrendValue(
                      stat: trend,
                      formatDelta: (d) => '${d.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TrendLineChart(
                  points: points,
                  emptyLabel: t.chartEmptyExercise,
                  valueSuffix: valueSuffix,
                  color: colors.accent,
                  height: 110,
                ),
                if (progression != null) ...[
                  const SizedBox(height: 10),
                  ProgressionNotice(suggestion: progression, compact: true),
                ],
                if (plateaued) ...[
                  const SizedBox(height: 6),
                  PlateauNotice(label: exercise.name, compact: true),
                ],
                const SizedBox(height: 8),
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.line),
                  _HistoryRow(entry: shown[i], isLatest: i == 0, onTap: () => _edit(shown[i])),
                ],
                if (newestFirst.length > _kCollapsedEntries)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(_expanded ? t.historyShowLess : t.historyShowAll(newestFirst.length)),
                    ),
                  )
                else
                  const SizedBox(height: 6),
                Text(t.infoHistoryTapToEdit, style: TextStyle(color: colors.mut, fontSize: 10.5)),
                const SizedBox(height: 8),
                if (hasMarkers) ...[
                  Text(t.infoHistoryLegend, style: TextStyle(color: colors.mut, fontSize: 10.5)),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One logged session as a list row: date (when known), the bold headline
/// value, and the per-set numbers on the right -- the newest one in the
/// accent color. Read from the entry's OWN stamped [HistoryEntry.mode],
/// never the exercise's current toggle (see the doc comment on that
/// field), so switching an exercise's mode later never recolors how an
/// older entry displays.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.isLatest, required this.onTap});

  final HistoryEntry entry;
  final bool isLatest;
  final VoidCallback onTap;

  String _primaryLabel(AppLocalizations t) {
    switch (entry.mode) {
      case ExerciseLogMode.reps:
        return entry.weight > 0 ? '${fmt1(entry.weight)} kg' : t.labelBodyweightAbbr;
      case ExerciseLogMode.timed:
        final durations = entry.durations ?? const <int>[];
        final best = durations.fold(0, (m, d) => d > m ? d : m);
        final hold = formatSeconds(best);
        return entry.weight > 0 ? '$hold · ${fmt1(entry.weight)} kg' : hold;
      case ExerciseLogMode.cardio:
        final speeds = entry.speeds ?? const <double>[];
        final best = speeds.fold(0.0, (m, s) => s > m ? s : m);
        return '${fmt1(best)} ${t.unitKmh}';
    }
  }

  String _secondaryLabel() {
    switch (entry.mode) {
      case ExerciseLogMode.reps:
        return entry.reps.map(_formatRep).join(' · ');
      case ExerciseLogMode.timed:
      case ExerciseLogMode.cardio:
        return (entry.durations ?? const <int>[]).map(formatSeconds).join(' · ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final date = DateTime.tryParse(entry.date ?? '');
    final dateLabel = date == null ? '' : DateFormat.Md(Localizations.localeOf(context).toString()).format(date);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(dateLabel, style: TextStyle(color: colors.mut, fontSize: 12)),
            ),
            Text(
              _primaryLabel(t),
              style: TextStyle(
                color: isLatest ? colors.accent : colors.txt,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _secondaryLabel(),
                textAlign: TextAlign.end,
                style: TextStyle(color: colors.mut, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
