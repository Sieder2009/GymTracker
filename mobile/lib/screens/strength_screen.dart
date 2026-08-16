import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_engine.dart';
import '../data/constants.dart';
import '../data/dots_score.dart';
import '../data/strength_standards.dart';
import '../l10n/app_localizations.dart';
import '../state/athlete_settings_provider.dart';
import '../state/big_lifts_provider.dart';
import '../state/body_weight_provider.dart';
import '../state/health_provider.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/one_rep_max_sheet.dart';
import '../widgets/plate_calculator_sheet.dart';
import '../widgets/plateau_notice.dart';
import '../widgets/strength_line_chart.dart';

/// "Kraft" tab — bodyweight log, Total/DOTS score, then Bench/Deadlift/Squat
/// PR tracker. The 1RM calculator lives in the header since it's a
/// standalone tool, not tied to any one lift.
class StrengthScreen extends StatelessWidget {
  const StrengthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, kFloatingNavClearance),
        children: [
          Row(
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
          const SizedBox(height: 8),
          const _BodyWeightCard(),
          const _PowerliftingScoreCard(),
          _LiftCard(liftKey: 'bench', label: t.labelBenchPress, color: colors.teal),
          _LiftCard(liftKey: 'deadlift', label: t.labelDeadlift, color: colors.purple),
          _LiftCard(liftKey: 'squat', label: t.labelSquat, color: colors.yellow),
        ],
      ),
    );
  }
}

/// Total (Bench+Deadlift+Squat PRs) and DOTS score (bodyweight-normalized) —
/// the two numbers every powerlifter tracks beyond the individual lifts.
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
                Text(t.dotsFormulaFor, style: TextStyle(color: colors.mut, fontSize: 12.5)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('M'),
                  selected: athlete.isMale,
                  onSelected: (_) => athlete.setIsMale(true),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('F'),
                  selected: !athlete.isMale,
                  onSelected: (_) => athlete.setIsMale(false),
                ),
              ],
            ),
          ],
        ),
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
              StrengthLineChart(
                points: points.map((e) => e.weight).toList(),
                pr: 0,
                color: colors.accent,
                lineColor: colors.line,
              ),
              const SizedBox(height: 8),
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

class _LiftCard extends StatefulWidget {
  const _LiftCard({required this.liftKey, required this.label, required this.color});

  final String liftKey;
  final String label;
  final Color color;

  @override
  State<_LiftCard> createState() => _LiftCardState();
}

class _LiftCardState extends State<_LiftCard> {
  late final TextEditingController _prController;
  final TextEditingController _entryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Lazily seed once from the store's current PR so this field starts
    // pre-filled, but never gets overwritten while the user is actively
    // typing in it.
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
    final points = lift.history.length > 8
        ? lift.history.sublist(lift.history.length - 8)
        : lift.history;
    final prLabel = lift.pr > 0
        ? '${t.prValue(fmt(lift.pr))}${lift.prDate != null ? ' · ${fmtDate(lift.prDate!)}' : ''}'
        : null;
    final plateaued = isLiftPlateaued(lift) ?? false;

    final bodyWeightEntries = context.watch<BodyWeightProvider>().entries;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final latestBodyWeight = bodyWeightEntries.isEmpty ? null : bodyWeightEntries.last.weight;
    final standard = (lift.pr > 0 && latestBodyWeight != null)
        ? classifyLift(liftKey: widget.liftKey, liftKg: lift.pr, bodyweightKg: latestBodyWeight, isMale: isMale)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(widget.label, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
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
            const SizedBox(height: 12),
            if (points.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  prLabel ?? t.emptyNoEntries,
                  style: TextStyle(color: colors.mut),
                ),
              )
            else ...[
              StrengthLineChart(
                points: points.map((p) => p.v).toList(),
                pr: lift.pr,
                color: widget.color,
                lineColor: colors.line,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(t.labelEntry),
                  if (prLabel != null) ...[
                    const SizedBox(width: 16),
                    Text(prLabel, style: TextStyle(color: colors.mut)),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }
}
