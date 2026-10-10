import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_engine.dart';
import '../analytics/heatmap_engine.dart';
import '../data/constants.dart' show isoOf;
import '../l10n/app_localizations.dart';
import '../state/workout_history_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/contribution_heatmap.dart';
import '../widgets/kpi_tile.dart';

/// The training calendar, laid out like a GitHub profile: "N workouts in
/// the last year" over a full contribution graph ([ContributionHeatmap]),
/// GitHub's year list as chips, a volume/duration toggle for what the shade
/// means, the current/best streak (GitHub's classic graph showed those right
/// below it), and the tapped day's sessions underneath. Every number comes
/// from [WorkoutHistoryProvider], which every finished workout feeds.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.initialDate});

  /// Day to select on open -- e.g. a cell tapped on the Analytics card.
  /// Older than the rolling year, its calendar year is shown instead.
  final DateTime? initialDate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;
  late HeatmapRange _range;
  HeatmapMetric _metric = HeatmapMetric.volume;

  @override
  void initState() {
    super.initState();
    final today = heatmapDateOnly(DateTime.now());
    final initial = widget.initialDate;
    _selectedDate = initial == null ? today : heatmapDateOnly(initial);
    _range = heatmapRangeFor(_selectedDate, today: today);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final localeName = Localizations.localeOf(context).toString();
    final sessions = context.watch<WorkoutHistoryProvider>().sessions;
    final today = heatmapDateOnly(DateTime.now());

    final days = aggregateHeatmapDays(sessions);
    final summary = summarizeHeatmap(days, range: _range, today: today);
    final streaks = computeConsistency(sessions);
    final years = heatmapYears(days, today: today);
    final shownYear = _range.year;
    // A year opened via initialDate without any sessions still needs its chip.
    if (shownYear != null && !years.contains(shownYear)) {
      years
        ..add(shownYear)
        ..sort((a, b) => b.compareTo(a));
    }
    final yearFormat = DateFormat.y(localeName);
    final hours = NumberFormat('#,##0.#', localeName).format(summary.totalMinutes / 60);
    final volumeFormat = NumberFormat.decimalPattern(localeName);
    final selectedKey = isoOf(_selectedDate);
    final selectedSessions = [
      for (final s in sessions)
        if (heatmapDateKey(s.date) == selectedKey) s,
    ];

    Widget rangeChip(String label, HeatmapRange range) => ChoiceChip(
          label: Text(label),
          selected: _range == range,
          onSelected: (_) => setState(() => _range = range),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.titleCalendar)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              shownYear == null
                  ? t.heatmapWorkoutsLastYear(summary.sessionCount)
                  : t.heatmapWorkoutsInYear(summary.sessionCount, yearFormat.format(DateTime(shownYear))),
              style: textTheme.headlineLarge?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              '${t.heatmapTrainingDays(summary.trainingDays)} · ${t.heatmapTotalHours(hours)}',
              style: TextStyle(color: colors.mut),
            ),
            const SizedBox(height: 14),
            // GitHub's year list, as a row that scrolls once there are many
            // years (this is a pushed route, so no tab swipe to fight).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  rangeChip(t.heatmapRangeLastYear, const HeatmapRange.lastYear()),
                  for (final year in years) ...[
                    const SizedBox(width: 8),
                    rangeChip(yearFormat.format(DateTime(year)), HeatmapRange.year(year)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SegmentedButton<HeatmapMetric>(
                segments: [
                  ButtonSegment(value: HeatmapMetric.volume, label: Text(t.heatmapMetricVolume)),
                  ButtonSegment(value: HeatmapMetric.duration, label: Text(t.heatmapMetricDuration)),
                ],
                selected: {_metric},
                onSelectionChanged: (selection) => setState(() => _metric = selection.first),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: ContributionHeatmap(
                  days: days,
                  range: _range,
                  metric: _metric,
                  selectedDate: _selectedDate,
                  onSelectDate: (day) => setState(() => _selectedDate = day),
                  hint: _metric == HeatmapMetric.volume ? t.heatmapHintVolume : t.heatmapHintDuration,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: KpiTile(
                    icon: Icons.local_fire_department_rounded,
                    value: t.unitDays(streaks.currentStreakDays),
                    label: t.labelCurrentStreak,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KpiTile(
                    icon: Icons.military_tech_rounded,
                    value: t.unitDays(streaks.bestStreakDays),
                    label: t.labelBestStreak,
                    color: colors.yellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              DateFormat.yMMMMEEEEd(localeName).format(_selectedDate),
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (selectedSessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(t.emptyNoSessionsThisDay, style: TextStyle(color: colors.mut)),
              )
            else
              for (final s in selectedSessions)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.fitness_center, color: colors.accent),
                    title: Text(s.planName),
                    subtitle: s.totalVolumeKg > 0
                        ? Text('${t.labelVolume}: ${volumeFormat.format(s.totalVolumeKg.round())} kg')
                        : null,
                    trailing: Text(t.labelMinutesShort(s.durationMinutes)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
