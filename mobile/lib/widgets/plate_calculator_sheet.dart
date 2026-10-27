import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../data/plate_calculator.dart';
import '../l10n/app_localizations.dart';
import '../state/bar_weight_provider.dart';
import '../theme/app_colors.dart';

Future<void> showPlateCalculator(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const PlateCalculatorSheet(),
  );
}

/// Target weight → plates, or the other way round.
enum PlateCalculatorMode { findPlates, addUp }

const double _kgPerLb = 0.45359237;

/// "Which plates do I put on?" -- and the reverse, "what does this weigh?":
/// tap the plates on one side (20, then 10, then 25 …) and it adds them up.
/// The empty weight starts at the bar weight from Settings
/// ([BarWeightProvider]); set it to 0 for a leg press whose sled doesn't
/// count. It is a scratchpad that never writes back, while the plate
/// toggles of the find mode are remembered there. The unit toggle is local
/// to this sheet (the rest of the app is kg-only): lb converts the empty
/// weight and swaps in the lb plates.
class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({super.key});

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _emptyController = TextEditingController();
  PlateCalculatorMode _mode = PlateCalculatorMode.findPlates;
  bool _isKg = true;
  // After the first Calculate, every change recalculates right away, so a
  // result on screen never describes an older setup.
  bool _calculated = false;
  PlateCalculatorResult? _result;
  bool _targetTooLight = false;
  // Add-up mode: the plates on one side, in the order they were tapped.
  final List<double> _loaded = [];

  @override
  void initState() {
    super.initState();
    final barKg = context.read<BarWeightProvider>().barWeightKg;
    _emptyController.text = fmt(barKg);
  }

  @override
  void dispose() {
    _targetController.dispose();
    _emptyController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) => double.tryParse(controller.text.replaceAll(',', '.'));

  void _setUnit(bool isKg) {
    if (isKg == _isKg) return;
    final barKg = context.read<BarWeightProvider>().barWeightKg;
    _isKg = isKg;
    // In lb the nearest 5, which puts a 20 kg bar on the familiar 45.
    _emptyController.text = fmt(isKg ? barKg : (barKg / _kgPerLb / 5).round() * 5);
    // kg plates mean nothing in lb.
    _loaded.clear();
    _refresh();
  }

  void _setPlate(double plate, bool available) {
    context.read<BarWeightProvider>().setPlateAvailable(plate, kg: _isKg, available: available);
    _refresh();
  }

  void _refresh() => _calculated ? _calculate() : setState(() {});

  void _calculate() {
    final target = _parse(_targetController);
    final empty = _parse(_emptyController);
    final result = target == null || empty == null
        ? null
        : calculatePlates(
            targetKg: target,
            barWeightKg: empty,
            availablePlates: context.read<BarWeightProvider>().availablePlates(kg: _isKg),
          );
    setState(() {
      _calculated = true;
      _result = result;
      _targetTooLight = result == null && target != null && empty != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final unit = _isKg ? 'kg' : 'lb';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.titlePlateCalculator, style: Theme.of(context).textTheme.headlineMedium),
                ),
                ChoiceChip(label: const Text('kg'), selected: _isKg, onSelected: (_) => _setUnit(true)),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('lb'), selected: !_isKg, onSelected: (_) => _setUnit(false)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<PlateCalculatorMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: PlateCalculatorMode.findPlates, label: Text(t.plateModeFind)),
                  ButtonSegment(value: PlateCalculatorMode.addUp, label: Text(t.plateModeAddUp)),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) => setState(() => _mode = selection.first),
              ),
            ),
            const SizedBox(height: 16),
            ...switch (_mode) {
              PlateCalculatorMode.findPlates => _findPlates(context, t, unit),
              PlateCalculatorMode.addUp => _addUp(context, t, unit),
            },
          ],
        ),
      ),
    );
  }

  TextField _emptyWeightField(AppLocalizations t, String unit) => TextField(
        controller: _emptyController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: '${t.labelEmptyWeight} ($unit)'),
        onChanged: (_) => _refresh(),
        onSubmitted: (_) => _calculate(),
      );

  List<Widget> _findPlates(BuildContext context, AppLocalizations t, String unit) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final available = context.watch<BarWeightProvider>().availablePlates(kg: _isKg);
    final result = _result;
    return [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${t.labelTargetWeight} ($unit)'),
              onChanged: (_) => _refresh(),
              onSubmitted: (_) => _calculate(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _emptyWeightField(t, unit)),
        ],
      ),
      const SizedBox(height: 14),
      Text(t.labelAvailablePlates, style: TextStyle(color: colors.mut, fontSize: 12.5)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final plate in _isKg ? kStandardPlatesKg : kStandardPlatesLb)
            FilterChip(
              label: Text(fmt(plate)),
              showCheckmark: false,
              selected: available.contains(plate),
              onSelected: (on) => _setPlate(plate, on),
            ),
        ],
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(onPressed: _calculate, child: Text(t.actionCalculate)),
      ),
      if (_targetTooLight) ...[
        const SizedBox(height: 16),
        Text(t.emptyPlateTargetBelowBar, style: TextStyle(color: colors.mut)),
      ] else if (result != null) ...[
        const SizedBox(height: 20),
        if (result.perSide.isEmpty)
          Center(
            child: Text(t.infoPlateBarAlone, style: TextStyle(color: colors.mut)),
          )
        else ...[
          Text(t.labelPerSide, style: TextStyle(color: colors.mut, fontSize: 12.5)),
          const SizedBox(height: 8),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final plate in result.perSide) _PlateChip(weight: plate, unit: unit, color: colors.accent),
              ],
            ),
          ),
        ],
        if (result.isApproximate) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              t.infoPlateApprox(fmt1(result.achievedTotal), unit),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.mut, fontSize: 12.5),
            ),
          ),
        ],
      ],
    ];
  }

  List<Widget> _addUp(BuildContext context, AppLocalizations t, String unit) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final perSide = _loaded.fold<double>(0, (sum, plate) => sum + plate);
    final empty = _parse(_emptyController) ?? 0;
    return [
      Row(
        children: [
          Expanded(child: _emptyWeightField(t, unit)),
          const Spacer(),
        ],
      ),
      const SizedBox(height: 14),
      Text(t.hintTapPlatesPerSide, style: TextStyle(color: colors.mut, fontSize: 12.5)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final plate in _isKg ? kStandardPlatesKg : kStandardPlatesLb)
            ActionChip(
              label: Text('+ ${fmt(plate)}'),
              onPressed: () => setState(() => _loaded.add(plate)),
            ),
        ],
      ),
      if (_loaded.isNotEmpty) ...[
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text('${t.labelPerSide}: ${fmt(perSide)} $unit',
                  style: TextStyle(color: colors.mut, fontSize: 12.5)),
            ),
            TextButton(
              onPressed: () => setState(_loaded.clear),
              child: Text(t.actionClearPlates),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _loaded.length; i++)
              InputChip(
                label: Text('${fmt(_loaded[i])} $unit'),
                onDeleted: () => setState(() => _loaded.removeAt(i)),
              ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      Center(
        child: Column(
          children: [
            Text(t.labelTotal, style: TextStyle(color: colors.mut, fontSize: 12.5)),
            Text(
              '${fmt(empty + 2 * perSide)} $unit',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: colors.accent),
            ),
          ],
        ),
      ),
    ];
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.weight, required this.unit, required this.color});

  final double weight;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${fmt(weight)} $unit',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
