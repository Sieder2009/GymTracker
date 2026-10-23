import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_engine.dart';
import '../analytics/body_measurement_analytics.dart';
import '../analytics/heatmap_engine.dart';
import '../analytics/logged_days.dart';
import '../analytics/rest_days.dart';
import '../data/constants.dart';
import '../data/lift_categories.dart';
import '../l10n/app_localizations.dart';
import '../models/big_lift.dart';
import '../models/body_measurement_entry.dart';
import '../state/big_lifts_provider.dart';
import '../state/body_measurements_provider.dart';
import '../state/body_weight_provider.dart';
import '../state/programs_provider.dart';
import '../state/train_state_provider.dart';
import '../state/workout_history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/app_shell.dart';
import '../widgets/chart_card.dart';
import '../widgets/contribution_heatmap.dart';
import '../widgets/kpi_tile.dart';
import '../widgets/plateau_notice.dart';
import '../widgets/radar_chart.dart';
import '../widgets/strength_line_chart.dart';
import '../widgets/trend_value.dart';
import '../widgets/value_entry_sheet.dart';
import 'calendar_screen.dart';

class _ProgressRow {
  _ProgressRow(
      {required this.name,
      required this.start,
      required this.now,
      required this.delta});
  final String name;
  final double start;
  final double now;
  final double delta;
}

/// "Fortschritt"/Analytics tab — its own dedicated multi-section area
/// (Overview / Strength / Consistency), every number and
/// chart traced back to real logged data. Nothing here is guessed: charts
/// show an honest empty state instead of a flat line when there isn't
/// enough data yet (see analytics_engine.dart's [DataQuality]).
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final programsProvider = context.watch<ProgramsProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;
    final programs = programsProvider.programs;
    final t = AppLocalizations.of(context)!;

    if (programs.isEmpty) {
      return SafeArea(
        child: Center(
          child: Text(t.emptyNoPlanShort, style: TextStyle(color: colors.mut)),
        ),
      );
    }

    return SafeArea(
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(t.tabProgress,
                  style: Theme.of(context).textTheme.headlineLarge),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: colors.accent,
              unselectedLabelColor: colors.mut,
              indicatorColor: colors.accent,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: t.tabAnalyticsOverview),
                Tab(text: t.tabAnalyticsStrength),
                Tab(text: t.tabAnalyticsConsistency),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(),
                  _StrengthTab(),
                  const _ConsistencyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "central feature" summary — a plain-language read on how training
/// is going, plus a rolling weekly-volume chart for an at-a-glance trend
/// (see DESIGN.md §101.30).
class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final sessions = context.watch<WorkoutHistoryProvider>().sessions;
    final lifts = context.watch<BigLiftsProvider>().lifts;

    final buckets = weeklyBuckets(sessions);
    // weeklyBuckets deliberately zero-fills a week with no sessions (see its
    // own doc comment) -- real signal for someone who trained earlier and
    // tapered off. But with *zero sessions ever* (a fresh install), every
    // one of the 8 buckets is trivially zero and carries no information;
    // charting that renders LineChartCard's fake-padded ±1 axis around a
    // flat line instead of the honest "not enough data" state it was built
    // to show for exactly this case.
    final volumePoints = sessions.isEmpty
        ? const <ChartPoint>[]
        : [for (final b in buckets) ChartPoint(b.weekStart, b.totalVolumeKg)];
    final totalVolume =
        sessions.fold<double>(0, (sum, s) => sum + s.totalVolumeKg);
    final currentStreak = computeConsistency(
      sessions,
      isRestDay: activePlanRestDays(context.watch<ProgramsProvider>(), context.watch<TrainStateProvider>()),
    ).currentStreakDays;
    final recentPrs = countRecentLiftPrs(lifts);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
      children: [
        Row(
          children: [
            Expanded(
              child: KpiTile(
                icon: Icons.fitness_center_rounded,
                value: '${sessions.length}',
                label: t.labelWorkouts,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiTile(
                icon: Icons.monitor_weight_rounded,
                value: '${fmt(totalVolume)} kg',
                label: t.labelVolume,
                color: colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: KpiTile(
                icon: Icons.local_fire_department_rounded,
                value: t.unitDays(currentStreak),
                label: t.labelCurrentStreak,
                color: colors.purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiTile(
                icon: Icons.emoji_events_rounded,
                value: '$recentPrs',
                label: t.labelPRs,
                color: colors.yellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _YourProgressCard(),
        const SizedBox(height: 16),
        const _BodyMeasurementsCard(),
        const SizedBox(height: 16),
        LineChartCard(
          title: t.chartTitleWeeklyVolume,
          subtitle: t.labelLast8Weeks,
          points: volumePoints,
          emptyLabel: t.chartEmptyVolume,
          valueSuffix: ' kg',
          color: colors.teal,
        ),
      ],
    );
  }
}

/// Body-circumference tracking -- a chip picker to choose which single
/// field's trend the mini chart shows (matching how [StrengthLineChart] is
/// already a single-series widget elsewhere, e.g. `strength_screen.dart`'s
/// `_BodyWeightCard`), one button that opens a clear entry sheet for all six
/// fields (any subset; a user typically measures only a few on a given day),
/// and a spider chart of every measured field on one cm scale, first value
/// against latest, so growth shows as a shape with the change at each
/// corner.
class _BodyMeasurementsCard extends StatefulWidget {
  const _BodyMeasurementsCard();

  @override
  State<_BodyMeasurementsCard> createState() => _BodyMeasurementsCardState();
}

class _BodyMeasurementsCardState extends State<_BodyMeasurementsCard> {
  BodyMeasurementField _selected = BodyMeasurementField.chest;

  /// Spider-chart order: chest on top, then clockwise down the arm, round
  /// the waist and hips, and up the leg.
  static const List<BodyMeasurementField> _radarOrder = [
    BodyMeasurementField.chest,
    BodyMeasurementField.arm,
    BodyMeasurementField.waist,
    BodyMeasurementField.hips,
    BodyMeasurementField.thigh,
    BodyMeasurementField.calf,
  ];

  Future<void> _log(AppLocalizations t, Map<BodyMeasurementField, ({double first, double latest})> spans) async {
    const fields = BodyMeasurementField.values;
    final values = await showValueEntrySheet(
      context,
      title: t.actionLogMeasurements,
      fields: [
        for (final f in fields)
          ValueEntryField(label: bodyMeasurementFieldLabel(t, f), unit: 'cm', last: spans[f]?.latest),
      ],
    );
    if (values == null || !mounted) return;
    double? valueOf(BodyMeasurementField f) => values[fields.indexOf(f)];
    context.read<BodyMeasurementsProvider>().addEntry(
          chestCm: valueOf(BodyMeasurementField.chest),
          waistCm: valueOf(BodyMeasurementField.waist),
          hipsCm: valueOf(BodyMeasurementField.hips),
          armCm: valueOf(BodyMeasurementField.arm),
          thighCm: valueOf(BodyMeasurementField.thigh),
          calfCm: valueOf(BodyMeasurementField.calf),
        );
  }

  RadarAxis _axis(AppLocalizations t, BodyMeasurementField f, ({double first, double latest}) span) {
    final delta = span.latest - span.first;
    final change = delta == 0 ? '' : ' · ${delta > 0 ? '+' : '−'}${fmt(delta.abs())}';
    return RadarAxis(
      label: bodyMeasurementFieldLabel(t, f),
      value: span.latest,
      start: delta == 0 ? null : span.first,
      detail: '${fmt(span.latest)} cm$change',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final entries = context.watch<BodyMeasurementsProvider>().entries;
    final spans = measurementSpans(entries);
    final radarAxes = [
      for (final f in _radarOrder)
        if (spans[f] case final span?) _axis(t, f, span),
    ];
    final series = [
      for (final e in entries)
        if (bodyMeasurementFieldValue(e, _selected) != null) bodyMeasurementFieldValue(e, _selected)!,
    ];
    final points = series.length > 8 ? series.sublist(series.length - 8) : series;
    final latest = points.isEmpty ? null : points.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Text(t.titleBodyMeasurements,
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in BodyMeasurementField.values)
                  ChoiceChip(
                    label: Text(bodyMeasurementFieldLabel(t, f)),
                    selected: _selected == f,
                    onSelected: (_) => setState(() => _selected = f),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (points.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(t.emptyNoEntries, style: TextStyle(color: colors.mut)),
              )
            else ...[
              // Same fix as _BodyWeightCard's chart in strength_screen.dart:
              // a single point has nothing to connect to, so it just centers
              // one dot in an otherwise blank frame -- reads as broken, not
              // "not enough data yet". Skip straight to the value.
              if (points.length > 1) ...[
                StrengthLineChart(
                  points: points,
                  pr: 0,
                  color: colors.accent,
                  lineColor: colors.line,
                ),
                const SizedBox(height: 8),
              ],
              Text('${t.labelCurrent}: ${fmt1(latest!)} cm',
                  style: TextStyle(color: colors.mut)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _log(t, spans),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(t.actionLogMeasurements),
              ),
            ),
            // A web needs at least three spokes.
            if (radarAxes.length >= 3) ...[
              const Divider(height: 28),
              Text(t.titleBodyShape, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              RadarChart(
                axes: radarAxes,
                ringLabel: (v, outermost) => outermost ? '${fmt(v)} cm' : fmt(v),
                nowLabel: t.labelCurrent,
                startLabel: t.labelStart,
                semanticsLabel: [
                  t.titleBodyShape,
                  for (final a in radarAxes) '${a.label}: ${a.detail}',
                ].join(', '),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Per-lift trend charts + Start→Now deltas (tap a row to enter that lift's
/// PR directly), generalized via [computeLiftTrend]/[liftHistoryPoints] so
/// this isn't special-cased to just showing PR numbers.
class _StrengthTab extends StatelessWidget {
  Future<void> _openPrDialog(
    BuildContext context,
    AppLocalizations t,
    String liftKey,
    String liftLabel,
    double currentPr,
  ) async {
    final controller =
        TextEditingController(text: currentPr > 0 ? fmt(currentPr) : '');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.titleEnterLiftPr(liftLabel)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.actionCancel)),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.of(ctx).pop(v);
            },
            child: Text(t.actionSave),
          ),
        ],
      ),
    );
    if (result != null && result > 0 && context.mounted) {
      context.read<BigLiftsProvider>().savePr(liftKey, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programsProvider = context.watch<ProgramsProvider>();
    final trainState = context.watch<TrainStateProvider>();
    final lifts = context.watch<BigLiftsProvider>().lifts;
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;
    final liftKeys = ['deadlift', 'bench', 'squat'];
    final liftLabelByKey = {
      'deadlift': t.labelDeadlift,
      'bench': t.labelBenchPress,
      'squat': t.labelSquat
    };

    final plan = programsProvider.byId(trainState.activePlanId) ??
        programsProvider.programs.first;
    final allEx = [
      ...plan.dailyExercises,
      for (final d in plan.days) ...d.exercises,
    ];

    final rows = <_ProgressRow>[];
    for (final ex in allEx) {
      if (!bigThreePattern.hasMatch(ex.name)) continue;
      var now = 0.0;
      for (final s in ex.sets) {
        if (s.w > now) now = s.w;
      }
      if (now <= 0) continue;
      final delta = ((now - ex.startW) * 10).round() / 10;
      rows.add(_ProgressRow(
          name: ex.name, start: ex.startW, now: now, delta: delta));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
      children: [
        for (final key in liftKeys) ...[
          _LiftTrendCard(lift: lifts.byKey(key), label: liftLabelByKey[key]!),
          const SizedBox(height: 16),
        ],
        Text(t.labelStartToNow, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(t.emptyNoWeightedExercises,
                style: TextStyle(color: colors.mut)),
          )
        else
          for (final row in rows)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                onTap: () {
                  final cat = liftCategoryForName(row.name);
                  if (cat == null) return;
                  _openPrDialog(context, t, cat.key, liftLabelByKey[cat.key]!,
                      lifts.byKey(cat.key).pr);
                },
                child: ListTile(
                  title: Text(row.name),
                  subtitle: Text(t.weightRange(fmt1(row.start), fmt1(row.now))),
                  trailing: row.delta == 0
                      ? null
                      : _DeltaBadge(delta: row.delta, colors: colors),
                ),
              ),
            ),
      ],
    );
  }
}

class _LiftTrendCard extends StatelessWidget {
  const _LiftTrendCard({required this.lift, required this.label});

  final BigLift lift;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final trend = computeLiftTrend(lift);
    final plateaued = isLiftPlateaued(lift);
    final points = [
      for (final p in liftHistoryPoints(lift)) ChartPoint(p.key, p.value),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LineChartCard(
          title: label,
          subtitle: t.labelTrend30Days,
          points: points,
          emptyLabel: t.chartEmptyExercise,
          valueSuffix: ' kg',
          color: colors.accent,
          height: 150,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TrendValue(
              stat: trend, formatDelta: (d) => '${d.toStringAsFixed(1)}%'),
        ),
        if (plateaued == true) ...[
          const SizedBox(height: 8),
          PlateauNotice(label: label),
        ],
      ],
    );
  }
}

/// Streaks, the GitHub-style training-activity graph and workouts-per-week,
/// backed by [computeConsistency] / [summarizeHeatmap] / [weeklyBuckets] —
/// never a fabricated streak when there's no logged history to compute one
/// from.
class _ConsistencyTab extends StatelessWidget {
  const _ConsistencyTab();

  void _openCalendar(BuildContext context, [DateTime? day]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalendarScreen(initialDate: day)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final sessions = context.watch<WorkoutHistoryProvider>().sessions;
    // Streaks and the graph also count days of single saved exercises,
    // same as the calendar; the per-week bars stay guided workouts only.
    final trainingDays = sessionsWithLoggedExercises(
        sessions, context.watch<ProgramsProvider>().programs);
    final consistency = computeConsistency(
      trainingDays,
      isRestDay: activePlanRestDays(context.watch<ProgramsProvider>(), context.watch<TrainStateProvider>()),
    );
    final heatmapDays = aggregateHeatmapDays(trainingDays);
    // The full rolling year, however many weeks the card has room for.
    final lastYear = summarizeHeatmap(heatmapDays, range: const HeatmapRange.lastYear());
    final buckets = weeklyBuckets(sessions);
    final bars = [
      for (final b in buckets)
        BarPoint('${b.weekStart.day}.${b.weekStart.month}',
            b.workoutCount.toDouble()),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
      children: [
        Row(
          children: [
            Expanded(
              child: KpiTile(
                icon: Icons.local_fire_department_rounded,
                value: t.unitDays(consistency.currentStreakDays),
                label: t.labelCurrentStreak,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiTile(
                icon: Icons.military_tech_rounded,
                value: t.unitDays(consistency.bestStreakDays),
                label: t.labelBestStreak,
                color: colors.yellow,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiTile(
                icon: Icons.event_available_rounded,
                value: '${consistency.workoutsThisMonth}',
                label: t.labelWorkoutsThisMonth,
                color: colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.heatmapCardTitle, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text(
                  t.heatmapWorkoutsLastYear(lastYear.sessionCount),
                  style: TextStyle(color: colors.mut, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                // fitToWidth: this tab lives in a TabBarView, so the graph
                // must not scroll sideways -- it shows the newest weeks that
                // fit, and the calendar screen has the whole year.
                ContributionHeatmap(
                  days: heatmapDays,
                  layout: HeatmapLayout.fitToWidth,
                  hint: t.heatmapHintVolume,
                  onSelectDate: (day) => _openCalendar(context, day),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => _openCalendar(context),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: Text(t.heatmapOpenCalendar),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BarChartCard(
          title: t.chartTitleWorkoutsPerWeek,
          subtitle: t.labelLast8Weeks,
          bars: bars,
          emptyLabel: t.chartEmptyConsistency,
          color: colors.purple,
        ),
      ],
    );
  }
}

class _YourProgressCard extends StatelessWidget {
  const _YourProgressCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;

    final sessions = context.watch<WorkoutHistoryProvider>().sessions;
    final lifts = context.watch<BigLiftsProvider>().lifts;
    final bodyWeight = context.watch<BodyWeightProvider>().entries;

    final week = computeWeekSummary(sessions);
    final consistency = computeConsistency(
      sessions,
      isRestDay: activePlanRestDays(context.watch<ProgramsProvider>(), context.watch<TrainStateProvider>()),
    );
    final strengthTrend = bestLiftImprovement(
      lifts,
      labels: {
        'bench': t.labelBenchPress,
        'deadlift': t.labelDeadlift,
        'squat': t.labelSquat
      },
    );
    final recentPrs = countRecentLiftPrs(lifts);
    final bodyWeightTrend = computeBodyWeightTrend(bodyWeight);

    final message = strengthTrend != null && strengthTrend.changePercent > 0
        ? t.progressMessageImproving
        : week.workoutCount > 0
            ? t.progressMessageSteady
            : t.progressMessageNoData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.titleYourProgress,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(message, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _ProgressStatRow(
              label: t.labelStrength,
              child: strengthTrend != null
                  ? TrendValue(
                      stat: TrendStat(
                          delta: strengthTrend.changePercent,
                          quality: DataQuality.good,
                          sampleCount: 2),
                      formatDelta: (d) => '${d.toStringAsFixed(1)}%',
                    )
                  : Text(t.insufficientDataShort,
                      style: TextStyle(color: colors.mut, fontSize: 12.5)),
            ),
            _ProgressStatRow(
              label: t.labelVolume,
              child: TrendValue(
                stat: TrendStat(
                  delta: week.volumeChangePercent,
                  quality: week.quality,
                  sampleCount: week.workoutCount,
                ),
                formatDelta: (d) => '${d.toStringAsFixed(1)}%',
              ),
            ),
            _ProgressStatRow(
              label: t.labelConsistency,
              child: Text(
                t.unitDays(consistency.currentStreakDays),
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: colors.txt),
              ),
            ),
            _ProgressStatRow(
              label: t.labelPRs,
              child: Text('$recentPrs',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: colors.txt)),
            ),
            _ProgressStatRow(
              label: t.labelBodyweightTitle,
              child: TrendValue(
                stat: bodyWeightTrend,
                formatDelta: (d) => '${fmt1(d)} kg',
              ),
            ),
            if (strengthTrend != null) ...[
              const Divider(height: 24),
              Text(t.labelBestImprovement,
                  style: TextStyle(
                      color: colors.mut,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(strengthTrend.label,
                  style: Theme.of(context).textTheme.headlineMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressStatRow extends StatelessWidget {
  const _ProgressStatRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors.mut)),
          child,
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta, required this.colors});

  final double delta;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final color = positive ? colors.green : colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        '${positive ? '+' : ''}${fmt1(delta)} kg',
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
