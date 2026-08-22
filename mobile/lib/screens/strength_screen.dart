import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_engine.dart';
import '../data/constants.dart';
import '../data/dots_score.dart';
import '../data/lift_balance.dart';
import '../data/strength_standards.dart';
import '../l10n/app_localizations.dart';
import '../state/athlete_settings_provider.dart';
import '../state/big_lifts_provider.dart';
import '../state/body_weight_provider.dart';
import '../state/health_provider.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../overlays/settings_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/chart_card.dart';
import '../widgets/one_rep_max_sheet.dart';
import '../widgets/plate_calculator_sheet.dart';
import '../widgets/plateau_notice.dart';
import '../widgets/strength_line_chart.dart';

/// "Kraft" tab — a segmented view (Overview / each of the three big lifts /
/// Tools) instead of one long scroll of every card stacked on top of each
/// other, same pattern the Analytics tab's own TabBar already uses (see
/// ProgressScreen). Overview stays a quick glance (bodyweight, Total/DOTS,
/// a compact tile per lift, a balance check across all three); each lift
/// gets its own full screen with a real date-based, range-filterable trend
/// chart and its logged history, not just the last 8 points squeezed into
/// a card.
class StrengthScreen extends StatelessWidget {
  const StrengthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;

    return SafeArea(
      child: DefaultTabController(
        length: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.tabStrength, style: Theme.of(context).textTheme.headlineLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fitness_center_outlined),
                    tooltip: t.titlePlateCalculator,
                    onPressed: () => showPlateCalculator(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calculate_outlined),
                    tooltip: t.title1rmCalculator,
                    onPressed: () => showOneRepMaxCalculator(context),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: colors.accent,
              unselectedLabelColor: colors.mut,
              indicatorColor: colors.accent,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: t.tabStrengthOverview),
                Tab(text: t.labelBenchPress),
                Tab(text: t.labelDeadlift),
                Tab(text: t.labelSquat),
                Tab(text: t.tabStrengthTools),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const _OverviewTab(),
                  _LiftDetailTab(liftKey: 'bench', label: t.labelBenchPress, color: colors.teal, tabIndex: 1),
                  _LiftDetailTab(liftKey: 'deadlift', label: t.labelDeadlift, color: colors.purple, tabIndex: 2),
                  _LiftDetailTab(liftKey: 'squat', label: t.labelSquat, color: colors.yellow, tabIndex: 3),
                  const _ToolsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
      children: [
        const _BodyWeightCard(),
        const SizedBox(height: 16),
        const _PowerliftingScoreCard(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _LiftStatTile(liftKey: 'bench', label: t.labelBenchPress, color: colors.teal, tabIndex: 1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LiftStatTile(liftKey: 'deadlift', label: t.labelDeadlift, color: colors.purple, tabIndex: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LiftStatTile(liftKey: 'squat', label: t.labelSquat, color: colors.yellow, tabIndex: 3),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _LiftBalanceCard(),
      ],
    );
  }
}

/// A compact "how's this lift doing" tile for the Overview grid — tapping
/// it jumps straight to that lift's own tab via the shared
/// [DefaultTabController], the same way a Garmin Connect stat tile opens
/// its own detail screen instead of everything living on one endless page.
class _LiftStatTile extends StatelessWidget {
  const _LiftStatTile({required this.liftKey, required this.label, required this.color, required this.tabIndex});

  final String liftKey;
  final String label;
  final Color color;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final lift = context.watch<BigLiftsProvider>().lifts.byKey(liftKey);
    final bodyWeightEntries = context.watch<BodyWeightProvider>().entries;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final latestBodyWeight = bodyWeightEntries.isEmpty ? null : bodyWeightEntries.last.weight;
    final standard = (lift.pr > 0 && latestBodyWeight != null)
        ? classifyLift(liftKey: liftKey, liftKg: lift.pr, bodyweightKg: latestBodyWeight, isMale: isMale)
        : null;

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => DefaultTabController.of(context).animateTo(tabIndex),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: colors.mut, fontSize: 11, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lift.pr > 0 ? '${fmt(lift.pr)} kg' : '—',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              if (standard != null) ...[
                const SizedBox(height: 4),
                Text(
                  _levelLabel(t, standard.level),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _levelLabel(AppLocalizations t, StrengthLevel level) {
  switch (level) {
    case StrengthLevel.beginner:
      return t.strengthLevelBeginner;
    case StrengthLevel.novice:
      return t.strengthLevelNovice;
    case StrengthLevel.intermediate:
      return t.strengthLevelIntermediate;
    case StrengthLevel.advanced:
      return t.strengthLevelAdvanced;
    case StrengthLevel.elite:
      return t.strengthLevelElite;
  }
}

/// "Are these three proportionate to each other?" — a derived insight new
/// to this redesign, using nothing but the three PRs already logged (see
/// data/lift_balance.dart). Flags a lift that's notably out of the typical
/// range relative to squat, the way a Beszel/Garmin-style dashboard
/// surfaces a derived reading instead of just raw numbers side by side.
class _LiftBalanceCard extends StatelessWidget {
  const _LiftBalanceCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final lifts = context.watch<BigLiftsProvider>().lifts;

    final balance = computeLiftBalance(benchPr: lifts.bench.pr, squatPr: lifts.squat.pr, deadliftPr: lifts.deadlift.pr);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.balance_outlined, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Text(t.titleLiftBalance, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (balance == null)
              Text(t.emptyNeedAllThreeLiftsForBalance, style: TextStyle(color: colors.mut))
            else ...[
              _BalanceRow(label: t.labelBenchToSquat, ratio: balance.benchToSquat, flag: balance.benchFlag),
              const SizedBox(height: 10),
              _BalanceRow(label: t.labelDeadliftToSquat, ratio: balance.deadliftToSquat, flag: balance.deadliftFlag),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.label, required this.ratio, required this.flag});

  final String label;
  final double ratio;
  final LiftBalanceFlag flag;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final (flagColor, flagLabel) = switch (flag) {
      LiftBalanceFlag.low => (colors.yellow, t.balanceFlagLow),
      LiftBalanceFlag.balanced => (colors.green, t.balanceFlagBalanced),
      LiftBalanceFlag.high => (colors.accent, t.balanceFlagHigh),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Text(t.balanceRatioValue(fmt1(ratio)), style: TextStyle(color: colors.mut, fontSize: 12.5)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: flagColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(flagLabel, style: TextStyle(color: flagColor, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Total (Bench+Deadlift+Squat PRs) and DOTS score (bodyweight-normalized).
class _PowerliftingScoreCard extends StatelessWidget {
  const _PowerliftingScoreCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final lifts = context.watch<BigLiftsProvider>().lifts;
    final bodyWeight = context.watch<BodyWeightProvider>().entries;
    final athlete = context.watch<AthleteSettingsProvider>();

    final hasAllThree = lifts.bench.pr > 0 && lifts.deadlift.pr > 0 && lifts.squat.pr > 0;
    final total = lifts.bench.pr + lifts.deadlift.pr + lifts.squat.pr;
    final latestBodyWeight = bodyWeight.isEmpty ? null : bodyWeight.last.weight;
    final dots = (hasAllThree && latestBodyWeight != null)
        ? dotsScore(bodyweightKg: latestBodyWeight, totalKg: total, isMale: athlete.isMale)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.military_tech_outlined, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Text(t.labelPowerliftingScore, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasAllThree)
              Text(t.emptyNeedAllThreeLifts, style: TextStyle(color: colors.mut))
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScoreStat(label: t.labelTotal, value: '${fmt1(total)} kg'),
                  _ScoreStat(
                    label: t.labelDotsScore,
                    value: dots != null ? fmt1(dots) : '—',
                  ),
                ],
              ),
              if (dots == null) ...[
                const SizedBox(height: 8),
                Text(t.emptyNeedBodyweight, style: TextStyle(color: colors.mut, fontSize: 12.5)),
              ] else ...[
                const SizedBox(height: 8),
                Text(t.infoDotsExplainer, style: TextStyle(color: colors.mut, fontSize: 12.5)),
              ],
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${t.dotsFormulaFor} ${athlete.isMale ? 'M' : 'F'}',
                  style: TextStyle(color: colors.mut, fontSize: 12.5),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SettingsScreen()),
                  ),
                  child: Text(t.actionEditInSettings, style: const TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreStat extends StatelessWidget {
  const _ScoreStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.mut, fontSize: 12.5)),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 22),
        ),
      ],
    );
  }
}

class _BodyWeightCard extends StatefulWidget {
  const _BodyWeightCard();

  @override
  State<_BodyWeightCard> createState() => _BodyWeightCardState();
}

class _BodyWeightCardState extends State<_BodyWeightCard> {
  final TextEditingController _entryController = TextEditingController();

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _addEntry() {
    final v = double.tryParse(_entryController.text.replaceAll(',', '.'));
    if (v == null || v <= 0) return;
    context.read<BodyWeightProvider>().addEntry(v);
    _entryController.clear();
  }

  Future<void> _syncFromHealth() async {
    final t = AppLocalizations.of(context)!;
    final toast = context.read<ToastProvider>();
    final weight = await context.read<HealthProvider>().fetchLatestWeightKg();
    if (!mounted) return;
    if (weight == null) {
      toast.show(t.toastNoHealthWeight);
      return;
    }
    context.read<BodyWeightProvider>().addEntry(weight);
    toast.show(t.toastWeightSynced);
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<BodyWeightProvider>().entries;
    final health = context.watch<HealthProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;
    final points = entries.length > 8 ? entries.sublist(entries.length - 8) : entries;
    final latestLabel = entries.isEmpty ? null : '${fmt1(entries.last.weight)} kg';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Text(t.labelBodyweightTitle, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (points.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(t.emptyNoEntries, style: TextStyle(color: colors.mut)),
              )
            else ...[
              // A single point has nothing to connect to -- StrengthLineChart
              // would just center one dot in an otherwise blank frame with no
              // axis to give it context, which reads as broken rather than
              // "not enough data yet". Skip straight to the value; the chart
              // earns its place once there's a second entry to draw a trend
              // between.
              if (points.length > 1) ...[
                StrengthLineChart(
                  points: points.map((e) => e.weight).toList(),
                  pr: 0,
                  color: colors.accent,
                  lineColor: colors.line,
                ),
                const SizedBox(height: 8),
              ],
              Text('${t.labelCurrent}: $latestLabel', style: TextStyle(color: colors.mut)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _entryController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: t.hintWeightTodayKg),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _addEntry, child: Text(t.actionAddEntry)),
              ],
            ),
            if (health.isSupportedPlatform && health.isConnected) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _syncFromHealth,
                  icon: const Icon(Icons.favorite_border, size: 16),
                  label: Text(t.actionSyncWeightFromHealth),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ChartRange { fourWeeks, threeMonths, sixMonths, oneYear, all }

DateTime? _rangeStart(_ChartRange range) {
  final now = DateTime.now();
  switch (range) {
    case _ChartRange.fourWeeks:
      return now.subtract(const Duration(days: 28));
    case _ChartRange.threeMonths:
      return now.subtract(const Duration(days: 90));
    case _ChartRange.sixMonths:
      return now.subtract(const Duration(days: 182));
    case _ChartRange.oneYear:
      return now.subtract(const Duration(days: 365));
    case _ChartRange.all:
      return null;
  }
}

/// A full tab for one lift: hero PR + strength level, a real date-based
/// trend chart with a Garmin-style time-range selector (4W/3M/6M/1Y/All)
/// instead of always just "the last 8 points", plateau detection, the
/// PR/entry inputs, and — new — the actual logged history as a list, not
/// just a line on a chart.
class _LiftDetailTab extends StatefulWidget {
  const _LiftDetailTab({required this.liftKey, required this.label, required this.color, required this.tabIndex});

  final String liftKey;
  final String label;
  final Color color;
  final int tabIndex;

  @override
  State<_LiftDetailTab> createState() => _LiftDetailTabState();
}

class _LiftDetailTabState extends State<_LiftDetailTab> {
  late final TextEditingController _prController;
  final TextEditingController _entryController = TextEditingController();
  _ChartRange _range = _ChartRange.threeMonths;

  @override
  void initState() {
    super.initState();
    final lift = context.read<BigLiftsProvider>().lifts.byKey(widget.liftKey);
    _prController = TextEditingController(text: lift.pr > 0 ? fmt(lift.pr) : '');
  }

  @override
  void dispose() {
    _prController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _savePr() {
    final v = double.tryParse(_prController.text.replaceAll(',', '.'));
    if (v == null || v <= 0) return;
    context.read<BigLiftsProvider>().savePr(widget.liftKey, v);
  }

  void _addEntry() {
    final v = double.tryParse(_entryController.text.replaceAll(',', '.'));
    if (v == null || v <= 0) return;
    context.read<BigLiftsProvider>().addEntry(widget.liftKey, v);
    _entryController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lift = context.watch<BigLiftsProvider>().lifts.byKey(widget.liftKey);
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;

    final bodyWeightEntries = context.watch<BodyWeightProvider>().entries;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final latestBodyWeight = bodyWeightEntries.isEmpty ? null : bodyWeightEntries.last.weight;
    final standard = (lift.pr > 0 && latestBodyWeight != null)
        ? classifyLift(liftKey: widget.liftKey, liftKg: lift.pr, bodyweightKg: latestBodyWeight, isMale: isMale)
        : null;

    final rangeStart = _rangeStart(_range);
    final chartPoints = [
      for (final p in lift.history)
        if (p.isoDate != null) ChartPoint(DateTime.parse(p.isoDate!), p.v),
    ].where((p) => rangeStart == null || !p.date.isBefore(rangeStart)).toList();

    final plateaued = isLiftPlateaued(lift) ?? false;
    final prLabel = lift.pr > 0
        ? '${t.prValue(fmt(lift.pr))}${lift.prDate != null ? ' · ${fmtDate(lift.prDate!)}' : ''}'
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(widget.label, style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            Text(
              lift.pr > 0 ? '${fmt(lift.pr)} kg' : '—',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 24, color: widget.color),
            ),
          ],
        ),
        if (prLabel != null) ...[
          const SizedBox(height: 2),
          Text(prLabel, style: TextStyle(color: colors.mut, fontSize: 12.5)),
        ],
        if (lift.pr > 0) ...[
          const SizedBox(height: 10),
          if (standard != null)
            _StrengthLevelIndicator(standard: standard, color: widget.color)
          else
            Text(t.emptyNeedBodyweightForLevel, style: TextStyle(color: colors.mut, fontSize: 12.5)),
        ],
        if (plateaued) ...[
          const SizedBox(height: 10),
          PlateauNotice(label: widget.label),
        ],
        const SizedBox(height: 16),
        _ChartRangeSelector(range: _range, onChanged: (r) => setState(() => _range = r)),
        const SizedBox(height: 12),
        LineChartCard(
          title: widget.label,
          points: chartPoints,
          emptyLabel: t.emptyNoEntries,
          valueSuffix: ' kg',
          color: widget.color,
          height: 180,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _prController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.labelPrKg),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _savePr, child: Text(t.actionSave)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _entryController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.hintWeightTodayKg),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _addEntry, child: Text(t.actionAddEntry)),
          ],
        ),
        if (lift.history.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(t.headerHistory, style: TextStyle(color: colors.mut, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (final entry in lift.history.reversed.take(30))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.isoDate != null ? fmtDate(entry.isoDate!) : entry.l,
                            style: TextStyle(color: colors.mut),
                          ),
                          Text('${fmt(entry.v)} kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChartRangeSelector extends StatelessWidget {
  const _ChartRangeSelector({required this.range, required this.onChanged});

  final _ChartRange range;
  final ValueChanged<_ChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final options = {
      _ChartRange.fourWeeks: t.rangeLabel4Weeks,
      _ChartRange.threeMonths: t.rangeLabel3Months,
      _ChartRange.sixMonths: t.rangeLabel6Months,
      _ChartRange.oneYear: t.rangeLabel1Year,
      _ChartRange.all: t.rangeLabelAll,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: range == entry.key,
                onSelected: (_) => onChanged(entry.key),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: range == entry.key ? colors.bg : colors.mut,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A bare DOTS number means nothing to someone who's never heard of
/// Wilks/DOTS (see [_PowerliftingScoreCard]) -- this is the legible
/// per-lift answer to "is this PR any good?": a level name plus a thin
/// progress bar toward the next one, both driven by [classifyLift].
class _StrengthLevelIndicator extends StatelessWidget {
  const _StrengthLevelIndicator({required this.standard, required this.color});

  final StrengthStandardResult standard;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final nextLevel = standard.nextLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _levelLabel(t, standard.level),
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            if (nextLevel != null)
              Text(
                t.progressToNextLevel((standard.progressToNext * 100).round(), _levelLabel(t, nextLevel)),
                style: TextStyle(color: colors.mut, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: standard.progressToNext,
            minHeight: 5,
            backgroundColor: colors.card2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
      children: [
        _ToolCard(
          icon: Icons.calculate_outlined,
          title: t.title1rmCalculator,
          description: t.infoTool1rmDescription,
          onTap: () => showOneRepMaxCalculator(context),
        ),
        const SizedBox(height: 12),
        _ToolCard(
          icon: Icons.fitness_center_outlined,
          title: t.titlePlateCalculator,
          description: t.infoToolPlateDescription,
          onTap: () => showPlateCalculator(context),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(AppRadii.sm)),
                child: Icon(icon, color: colors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    Text(description, style: TextStyle(color: colors.mut, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.mut),
            ],
          ),
        ),
      ),
    );
  }
}
