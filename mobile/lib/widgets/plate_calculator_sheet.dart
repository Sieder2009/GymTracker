import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/plate_calculator.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

Future<void> showPlateCalculator(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PlateCalculatorSheet(),
  );
}

const double _kDefaultBarKg = 20;
const double _kDefaultBarLb = 45;

/// "Which plates do I put on the bar?" — purely a scratchpad calculator
/// like [showOneRepMaxCalculator], doesn't read or write any app data.
/// Unit toggle is local to this sheet only (the rest of the app is
/// kg-only), so switching it just swaps the default bar weight and the
/// plate set [calculatePlates] uses — nothing else in the app needs to
/// know or care.
class _PlateCalculatorSheet extends StatefulWidget {
  const _PlateCalculatorSheet();

  @override
  State<_PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<_PlateCalculatorSheet> {
  final TextEditingController _targetController = TextEditingController();
  late final TextEditingController _barController;
  bool _isKg = true;
  PlateCalculatorResult? _result;
  bool _targetTooLight = false;

  @override
  void initState() {
    super.initState();
    _barController = TextEditingController(text: fmt(_kDefaultBarKg));
  }

  @override
  void dispose() {
    _targetController.dispose();
    _barController.dispose();
    super.dispose();
  }

  void _setUnit(bool isKg) {
    if (isKg == _isKg) return;
    setState(() {
      _isKg = isKg;
      _barController.text = fmt(isKg ? _kDefaultBarKg : _kDefaultBarLb);
      _result = null;
      _targetTooLight = false;
    });
  }

  void _calculate() {
    final target = double.tryParse(_targetController.text.replaceAll(',', '.'));
    final bar = double.tryParse(_barController.text.replaceAll(',', '.'));
    if (target == null || bar == null) return;
    final result = calculatePlates(
      targetKg: target,
      barWeightKg: bar,
      availablePlates: _isKg ? kStandardPlatesKg : kStandardPlatesLb,
    );
    setState(() {
      _result = result;
      _targetTooLight = result == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final unit = _isKg ? 'kg' : 'lb';

    return SafeArea(
      child: Padding(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: '${t.labelTargetWeight} ($unit)'),
                    onSubmitted: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _barController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: '${t.labelBarWeight} ($unit)'),
                    onSubmitted: (_) => _calculate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _calculate, child: Text(t.actionCalculate)),
            ),
            if (_targetTooLight) ...[
              const SizedBox(height: 16),
              Text(t.emptyPlateTargetBelowBar, style: TextStyle(color: colors.mut)),
            ] else if (_result != null) ...[
              const SizedBox(height: 20),
              if (_result!.perSide.isEmpty)
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
                      for (final plate in _result!.perSide) _PlateChip(weight: plate, unit: unit, color: colors.accent),
                    ],
                  ),
                ),
              ],
              if (_result!.isApproximate) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    t.infoPlateApprox(fmt1(_result!.achievedTotal), unit),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.mut, fontSize: 12.5),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
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
