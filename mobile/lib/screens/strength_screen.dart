import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_engine.dart';
import '../data/constants.dart';
import '../data/dots_score.dart';
import '../data/lift_balance.dart';
import '../data/lift_rank.dart';
import '../l10n/app_localizations.dart';
import '../models/big_lift.dart';
import '../state/athlete_settings_provider.dart';
import '../state/big_lifts_provider.dart';
import '../state/body_weight_provider.dart';
import '../state/health_provider.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../overlays/settings_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/body_measurements_card.dart';
import '../widgets/calculators_menu.dart';
import '../widgets/chart_card.dart';
import '../widgets/plateau_notice.dart';
import '../widgets/radar_chart.dart';
import '../widgets/rank_emblem.dart';
import '../widgets/strength_line_chart.dart';
import '../widgets/trend_value.dart';
import '../widgets/value_entry_sheet.dart';

/// "Kraft" tab — one overview (overall rank, bodyweight, body measurements,
/// Total/DOTS, a compact tile per lift, the PR radar and a balance check
/// across all three) instead of a row of sub-tabs. Each lift tile opens
/// that lift's own screen ([_LiftDetailScreen]) with a real date-based,
/// range-filterable trend chart, its 30-day trend and its logged history,
/// not just the last 8 points squeezed into a card. The calculators live in
/// the header's ⋮ menu.
class StrengthScreen extends StatelessWidget {
  const StrengthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SafeArea(
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
                const CalculatorsMenuButton(),
              ],
            ),
          ),
          const Expanded(child: _StrengthOverview()),
        ],
      ),
    );
  }
}

class _StrengthOverview extends StatelessWidget {
  const _StrengthOverview();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
      children: [
        const _RankCard(),
        const SizedBox(height: 16),
        const _BodyWeightCard(),
        const SizedBox(height: 16),
        const BodyMeasurementsCard(),
        const SizedBox(height: 16),
        const _PowerliftingScoreCard(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _LiftStatTile(liftKey: 'bench', label: t.labelBenchPress, color: colors.teal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LiftStatTile(liftKey: 'deadlift', label: t.labelDeadlift, color: colors.purple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LiftStatTile(liftKey: 'squat', label: t.labelSquat, color: colors.yellow),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _PrRadarCard(),
        const SizedBox(height: 16),
        const _LiftBalanceCard(),
      ],
    );
  }
}

/// The three PRs as a spider chart on one shared kg scale (rings labelled
/// in kg, each PR at its corner), plus one place to enter all three.
/// Saving goes through [BigLiftsProvider.savePr] -- exactly what each
/// lift's own screen does with its PR field -- so the tiles, those screens
/// and this chart always agree.
class _PrRadarCard extends StatelessWidget {
  const _PrRadarCard();

  static const List<String> _keys = ['squat', 'bench', 'deadlift'];

  List<String> _labels(AppLocalizations t) => [t.labelSquat, t.labelBenchPress, t.labelDeadlift];

  Future<void> _logPrs(BuildContext context, AppLocalizations t) async {
    final provider = context.read<BigLiftsProvider>();
    final before = [for (final key in _keys) provider.lifts.byKey(key).pr];
    final values = await showValueEntrySheet(
      context,
      title: t.actionLogPrs,
      fields: [
        for (final (i, label) in _labels(t).indexed)
          ValueEntryField(label: label, unit: 'kg', initial: before[i] > 0 ? before[i] : null),
      ],
    );
    if (values == null) return;
    for (final (i, key) in _keys.indexed) {
      final value = values[i];
      if (value != null && value != before[i]) provider.savePr(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final lifts = context.watch<BigLiftsProvider>().lifts;
    final labels = _labels(t);
    final prs = [for (final key in _keys) lifts.byKey(key).pr];
    final axes = [
      for (final (i, pr) in prs.indexed)
        RadarAxis(label: labels[i], value: pr > 0 ? pr : null, detail: pr > 0 ? '${fmt(pr)} kg' : '—'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.radar_rounded, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Text(t.titleYourPrs, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (prs.every((pr) => pr <= 0))
              Text(t.emptyNoEntries, style: TextStyle(color: colors.mut))
            else
              RadarChart(
                axes: axes,
                ringLabel: (v, outermost) => outermost ? '${fmt(v)} kg' : fmt(v),
                semanticsLabel: [
                  t.titleYourPrs,
                  for (final a in axes) '${a.label}: ${a.detail}',
                ].join(', '),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _logPrs(context, t),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(t.actionLogPrs),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact "how's this lift doing" tile for the Overview grid — tapping
/// it opens that lift's own screen ([_LiftDetailScreen]), the same way a Garmin Connect stat tile opens
/// its own detail screen instead of everything living on one endless page.
class _LiftStatTile extends StatelessWidget {
  const _LiftStatTile({required this.liftKey, required this.label, required this.color});

  final String liftKey;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final lift = context.watch<BigLiftsProvider>().lifts.byKey(liftKey);
    final bodyWeightEntries = context.watch<BodyWeightProvider>().entries;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final latestBodyWeight = bodyWeightEntries.isEmpty ? null : bodyWeightEntries.last.weight;
    final rank = latestBodyWeight == null
        ? null
        : rankLift(liftKey: liftKey, liftKg: lift.pr, bodyweightKg: latestBodyWeight, isMale: isMale);

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _LiftDetailScreen(liftKey: liftKey, label: label, color: color))),
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
              if (rank != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    RankEmblem(tier: rank.tier, division: rank.division, size: 24),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        rankLabel(t, rank.tier, rank.division),
                        style: TextStyle(color: colors.txt, fontSize: 11.5, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The overall rank -- the average of the three lifts' ranks -- as one big
/// emblem, with the way to the next division underneath. Each lift's own
/// rank sits on its tile below and in detail on its own screen.
class _RankCard extends StatelessWidget {
  const _RankCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final lifts = context.watch<BigLiftsProvider>().lifts;
    final bodyWeight = context.watch<BodyWeightProvider>().entries;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final latestBodyWeight = bodyWeight.isEmpty ? null : bodyWeight.last.weight;
    final ranks = [
      if (latestBodyWeight != null)
        for (final key in BigLifts.keys)
          rankLift(liftKey: key, liftKg: lifts.byKey(key).pr, bodyweightKg: latestBodyWeight, isMale: isMale),
    ];
    // An average of fewer than all three would rank one lift as all of them.
    final rank = ranks.length == 3 && ranks.every((r) => r != null) ? overallRank(ranks) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(t.titleYourRank, style: Theme.of(context).textTheme.headlineMedium)),
                TextButton(
                  onPressed: () => _showAllRanks(context, current: rank?.tier, bodyweightKg: latestBodyWeight, isMale: isMale),
                  child: Text(t.titleAllRanks),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (rank == null)
              Text(
                latestBodyWeight == null ? t.rankNeedBodyweight : t.rankNeedAllThree,
                style: TextStyle(color: colors.mut),
              )
            else
              Row(
                children: [
                  RankEmblem(
                    tier: rank.tier,
                    division: rank.division,
                    size: 84,
                    semanticsLabel: rankLabel(t, rank.tier, rank.division),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rankLabel(t, rank.tier, rank.division),
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 10),
                        _RankProgress(rank: rank),
                      ],
                    ),
                  ),
                ],
              ),
            if (rank != null) ...[
              const SizedBox(height: 12),
              Text(t.rankExplainer, style: TextStyle(color: colors.mut, fontSize: 11.5, height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Every rank from champion down to iron, each with its badge and the PRs
/// that start it -- in kilos at the user's bodyweight, else as multiples of
/// bodyweight -- with the overall rank the user holds marked.
void _showAllRanks(BuildContext context, {RankTier? current, double? bodyweightKg, required bool isMale}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final t = AppLocalizations.of(context)!;
      final colors = Theme.of(context).extension<AppColors>()!;
      final lifts = [('squat', t.labelSquat), ('bench', t.labelBenchPress), ('deadlift', t.labelDeadlift)];
      String startsAt(RankTier tier) => [
            for (final (key, label) in lifts)
              if (tierStartRatio(liftKey: key, tier: tier, isMale: isMale) case final ratio?)
                bodyweightKg == null
                    ? '$label ${fmt1(ratio)}×'
                    : '$label ${fmt(((ratio * bodyweightKg) * 2).ceil() / 2)} kg',
          ].join(' · ');
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(t.titleAllRanks, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              bodyweightKg == null ? t.allRanksCaptionRatio : t.allRanksCaptionKg(fmt(bodyweightKg)),
              style: TextStyle(color: colors.mut, fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 14),
            for (final tier in RankTier.values.reversed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: tier == current ? colors.accent : colors.line,
                    width: tier == current ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    RankEmblem(
                      tier: tier,
                      division: tier == RankTier.champion ? null : 1,
                      size: 64,
                      semanticsLabel: rankLabel(t, tier, null),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(rankLabel(t, tier, null), style: Theme.of(context).textTheme.headlineMedium),
                              if (tier == current) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                  ),
                                  child: Text(
                                    t.labelCurrent,
                                    style: TextStyle(color: colors.accent, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (tier != RankTier.iron) ...[
                            const SizedBox(height: 4),
                            Text(
                              startsAt(tier),
                              style: TextStyle(color: colors.mut, fontSize: 12.5, height: 1.35),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// A bar through the current division and what's next: "12 kg to Gold I"
/// when the kilos are known (a single lift), else "Next rank: Gold I".
class _RankProgress extends StatelessWidget {
  const _RankProgress({required this.rank});

  final LiftRank rank;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final next = rank.next;
    final kg = rank.kgToNext;
    final text = next == null
        ? t.rankTop
        : (kg == null
            ? t.rankNext(rankLabel(t, next.$1, next.$2))
            : t.rankKgToNext(fmt(kg), rankLabel(t, next.$1, next.$2)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: LinearProgressIndicator(
            value: rank.progress,
            minHeight: 6,
            backgroundColor: colors.card2,
            valueColor: AlwaysStoppedAnimation(colors.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(text, style: TextStyle(color: colors.mut, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
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

/// A full screen for one lift, opened from its tile on the overview: hero PR + strength level, a real date-based
/// trend chart with a Garmin-style time-range selector (4W/3M/6M/1Y/All)
/// instead of always just "the last 8 points", plateau detection, the
/// PR/entry inputs, and — new — the actual logged history as a list, not
/// just a line on a chart.
class _LiftDetailScreen extends StatefulWidget {
  const _LiftDetailScreen({required this.liftKey, required this.label, required this.color});

  final String liftKey;
  final String label;
  final Color color;

  @override
  State<_LiftDetailScreen> createState() => _LiftDetailScreenState();
}

class _LiftDetailScreenState extends State<_LiftDetailScreen> {
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
    final rank = latestBodyWeight == null
        ? null
        : rankLift(liftKey: widget.liftKey, liftKg: lift.pr, bodyweightKg: latestBodyWeight, isMale: isMale);

    final rangeStart = _rangeStart(_range);
    final chartPoints = [
      for (final p in lift.history)
        if (p.isoDate != null) ChartPoint(DateTime.parse(p.isoDate!), p.v),
    ].where((p) => rangeStart == null || !p.date.isBefore(rangeStart)).toList();

    final plateaued = isLiftPlateaued(lift) ?? false;
    final prLabel = lift.pr > 0
        ? '${t.prValue(fmt(lift.pr))}${lift.prDate != null ? ' · ${fmtDate(lift.prDate!)}' : ''}'
        : null;

    return Scaffold(
      // No title: the lift's name already heads the page, with its colour and PR.
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
              const SizedBox(height: 12),
              if (rank != null)
                Row(
                  children: [
                    RankEmblem(
                      tier: rank.tier,
                      division: rank.division,
                      size: 60,
                      semanticsLabel: rankLabel(t, rank.tier, rank.division),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rankLabel(t, rank.tier, rank.division),
                              style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 8),
                          _RankProgress(rank: rank),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Text(t.rankNeedBodyweight, style: TextStyle(color: colors.mut, fontSize: 12.5)),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Text(t.labelTrend30Days, style: TextStyle(color: colors.mut, fontSize: 12.5)),
                const Spacer(),
                TrendValue(stat: computeLiftTrend(lift), formatDelta: (d) => '${d.toStringAsFixed(1)}%'),
              ],
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
        ),
      ),
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
