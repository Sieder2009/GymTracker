import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/achievements_engine.dart';
import '../analytics/analytics_engine.dart';
import '../analytics/body_measurement_analytics.dart';
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
import '../widgets/body_shape_diagram.dart';
import '../widgets/chart_card.dart';
import '../widgets/kpi_tile.dart';
import '../widgets/plateau_notice.dart';
import '../widgets/strength_line_chart.dart';
import '../widgets/training_calendar_heatmap.dart';
import '../widgets/trend_value.dart';

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
/// (Overview / Strength / Consistency / Achievements), every number and
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
        length: 4,
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
                Tab(text: t.tabAnalyticsAchievements),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(),
                  _StrengthTab(),
                  const _ConsistencyTab(),
                  const _AchievementsTab(),
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
    final volumePoints = [
      for (final b in buckets) ChartPoint(b.weekStart, b.totalVolumeKg),
    ];
    final totalVolume =
        sessions.fold<double>(0, (sum, s) => sum + s.totalVolumeKg);
    final currentStreak = computeConsistency(sessions).currentStreakDays;
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

/// Body-circumference tracking -- six optional entry fields (a user
/// typically only has a few measured on any given day), a chip picker to
/// choose which single field's trend the mini chart below shows (matching
/// how [StrengthLineChart] is already a single-series widget elsewhere,
/// e.g. `strength_screen.dart`'s `_BodyWeightCard`), and, once at least two
/// entries exist, an approximate visual shape (see [BodyShapeDiagram]) so
/// growth shows up as a picture, not just numbers.
class _BodyMeasurementsCard extends StatefulWidget {
  const _BodyMeasurementsCard();

  @override
  State<_BodyMeasurementsCard> createState() => _BodyMeasurementsCardState();
}

class _BodyMeasurementsCardState extends State<_BodyMeasurementsCard> {
  final _chestCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _hipsCtrl = TextEditingController();
  final _armCtrl = TextEditingController();
  final _thighCtrl = TextEditingController();
  final _calfCtrl = TextEditingController();
  BodyMeasurementField _selected = BodyMeasurementField.chest;

  List<TextEditingController> get _controllers =>
      [_chestCtrl, _waistCtrl, _hipsCtrl, _armCtrl, _thighCtrl, _calfCtrl];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  void _save() {
    context.read<BodyMeasurementsProvider>().addEntry(
          chestCm: _parse(_chestCtrl),
          waistCm: _parse(_waistCtrl),
          hipsCm: _parse(_hipsCtrl),
          armCm: _parse(_armCtrl),
          thighCm: _parse(_thighCtrl),
          calfCm: _parse(_calfCtrl),
        );
    setState(() {
      for (final c in _controllers) {
        c.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final entries = context.watch<BodyMeasurementsProvider>().entries;
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
              StrengthLineChart(
                points: points,
                pr: 0,
                color: colors.accent,
                lineColor: colors.line,
              ),
              const SizedBox(height: 8),
              Text('${t.labelCurrent}: ${fmt1(latest!)} cm',
                  style: TextStyle(color: colors.mut)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BodyMeasurementField.chest,
                BodyMeasurementField.waist,
                BodyMeasurementField.hips,
                BodyMeasurementField.arm,
                BodyMeasurementField.thigh,
                BodyMeasurementField.calf,
              ].asMap().entries.map((entry) {
                final ctrl = _controllers[entry.key];
                return SizedBox(
                  width: 90,
                  child: TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: bodyMeasurementFieldLabel(t, entry.value),
                      suffixText: 'cm',
                      isDense: true,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: _save, child: Text(t.actionAddEntry)),
            ),
            if (entries.length >= 2) ...[
              const Divider(height: 28),
              Center(
                child: Text(t.titleBodyShape,
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              const SizedBox(height: 10),
              Center(
                child: BodyShapeDiagram(
                  scaleFactors: measurementScaleFactors(entries),
                ),
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

/// Streaks + workouts-per-week, backed by [computeConsistency] /
/// [weeklyBuckets] — never a fabricated streak when there's no logged
/// history to compute one from.
class _ConsistencyTab extends StatelessWidget {
  const _ConsistencyTab();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final sessions = context.watch<WorkoutHistoryProvider>().sessions;
    final consistency = computeConsistency(sessions);
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
        TrainingCalendarHeatmap(sessions: sessions),
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

/// Achievement paths — every tier derived live from [WorkoutHistoryProvider]/
/// [ProgramsProvider] (see `achievements_engine.dart`), never a separately
/// stored "is this unlocked" flag, matching the rest of this tab's honest,
/// nothing-is-guessed philosophy.
class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab();

  String _pathLabel(AppLocalizations t, AchievementPathId id) {
    switch (id) {
      case AchievementPathId.consistency:
        return t.achievementPathConsistency;
      case AchievementPathId.totalWorkouts:
        return t.achievementPathTotalWorkouts;
      case AchievementPathId.totalVolume:
        return t.achievementPathTotalVolume;
      case AchievementPathId.prCount:
        return t.achievementPathPrCount;
      case AchievementPathId.totalSets:
        return t.achievementPathTotalSets;
      case AchievementPathId.totalWorkoutMinutes:
        return t.achievementPathTotalWorkoutMinutes;
      case AchievementPathId.distinctExercises:
        return t.achievementPathDistinctExercises;
    }
  }

  IconData _pathIcon(AchievementPathId id) {
    switch (id) {
      case AchievementPathId.consistency:
        return Icons.local_fire_department;
      case AchievementPathId.totalWorkouts:
        return Icons.fitness_center;
      case AchievementPathId.totalVolume:
        return Icons.scale;
      case AchievementPathId.prCount:
        return Icons.emoji_events;
      case AchievementPathId.totalSets:
        return Icons.repeat;
      case AchievementPathId.totalWorkoutMinutes:
        return Icons.timer_outlined;
      case AchievementPathId.distinctExercises:
        return Icons.grid_view;
    }
  }

  String _formatValue(AppLocalizations t, AchievementPathId id, double value) {
    switch (id) {
      case AchievementPathId.consistency:
        return t.unitDays(value.round());
      case AchievementPathId.totalVolume:
        return '${fmt(value)} kg';
      case AchievementPathId.totalWorkouts:
      case AchievementPathId.prCount:
      case AchievementPathId.totalSets:
      case AchievementPathId.distinctExercises:
        return '${value.round()}';
      case AchievementPathId.totalWorkoutMinutes:
        final hours = value ~/ 60;
        final minutes = value.round() % 60;
        return hours > 0 ? '${hours}h ${minutes}min' : '${value.round()}min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final sessions = context.watch<WorkoutHistoryProvider>().sessions;
    final programs = context.watch<ProgramsProvider>().programs;
    final paths = computeAchievements(sessions: sessions, programs: programs);
    final rank = computeRank(paths);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
      children: [
        _RankCard(rank: rank, colors: colors, t: t),
        const SizedBox(height: 16),
        for (final path in paths) ...[
          _AchievementPathCard(
            label: _pathLabel(t, path.id),
            icon: _pathIcon(path.id),
            path: path,
            valueLabel: _formatValue(t, path.id, path.currentValue),
            nextLabel: path.hasNextTier
                ? t.achievementProgressToNext(_formatValue(
                    t, path.id, path.nextThreshold! - path.currentValue))
                : t.achievementAllTiersUnlocked,
            colors: colors,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

String _rankLabel(AppLocalizations t, RankTier tier) {
  switch (tier) {
    case RankTier.starter:
      return t.rankStarter;
    case RankTier.bronze:
      return t.rankBronze;
    case RankTier.silver:
      return t.rankSilver;
    case RankTier.gold:
      return t.rankGold;
    case RankTier.platinum:
      return t.rankPlatinum;
    case RankTier.legend:
      return t.rankLegend;
  }
}

Color _rankColor(AppColors colors, RankTier tier) {
  switch (tier) {
    case RankTier.starter:
      return colors.mut;
    case RankTier.bronze:
      return colors.green;
    case RankTier.silver:
      return colors.teal;
    case RankTier.gold:
      return colors.accent;
    case RankTier.platinum:
      return colors.purple;
    case RankTier.legend:
      return colors.yellow;
  }
}

/// Overall progression across every achievement path combined -- shown
/// above the individual path cards so "how am I doing overall" has one
/// answer, not just seven separate ones.
class _RankCard extends StatelessWidget {
  const _RankCard({required this.rank, required this.colors, required this.t});

  final RankResult rank;
  final AppColors colors;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final color = _rankColor(colors, rank.tier);
    final isMaxTier = rank.tier == RankTier.values.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.military_tech, size: 22, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.labelRank, style: TextStyle(color: colors.mut, fontSize: 12)),
                      Text(_rankLabel(t, rank.tier),
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(color: color)),
                    ],
                  ),
                ),
              ],
            ),
            if (!isMaxTier) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: rank.progressToNext,
                  minHeight: 6,
                  backgroundColor: colors.card2,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AchievementPathCard extends StatelessWidget {
  const _AchievementPathCard({
    required this.label,
    required this.icon,
    required this.path,
    required this.valueLabel,
    required this.nextLabel,
    required this.colors,
  });

  final String label;
  final IconData icon;
  final AchievementPathResult path;
  final String valueLabel;
  final String nextLabel;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                Text(valueLabel,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.accent)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < path.thresholds.length; i++)
                  _TierBadge(
                    unlocked: i <= path.unlockedTierIndex,
                    label: '${path.thresholds[i].round()}',
                    colors: colors,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xs),
              child: LinearProgressIndicator(
                value: path.progressToNext,
                backgroundColor: colors.card2,
                color: colors.yellow,
              ),
            ),
            const SizedBox(height: 6),
            Text(nextLabel, style: TextStyle(color: colors.mut, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge(
      {required this.unlocked, required this.label, required this.colors});

  final bool unlocked;
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: unlocked
            ? colors.yellow.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: unlocked ? colors.yellow : colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.emoji_events : Icons.emoji_events_outlined,
            size: 13,
            color: unlocked ? colors.yellow : colors.mut,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: unlocked ? FontWeight.w700 : FontWeight.w600,
                color: unlocked ? colors.yellow : colors.mut,
              )),
        ],
      ),
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
    final consistency = computeConsistency(sessions);
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
