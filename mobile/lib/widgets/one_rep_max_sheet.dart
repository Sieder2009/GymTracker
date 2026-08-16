import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/dots_score.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

Future<void> showOneRepMaxCalculator(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _OneRepMaxSheet(),
  );
}

/// Epley-formula 1RM estimator — purely a scratchpad calculator, doesn't
/// read or write any app data (no lift/exercise is implied by the input).
class _OneRepMaxSheet extends StatefulWidget {
  const _OneRepMaxSheet();

  @override
  State<_OneRepMaxSheet> createState() => _OneRepMaxSheetState();
}

class _OneRepMaxSheetState extends State<_OneRepMaxSheet> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  double? _result;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _calculate() {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final reps = int.tryParse(_repsController.text.trim());
    if (weight == null || reps == null) return;
    setState(() => _result = estimateOneRepMax(weight: weight, reps: reps));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title1rmCalculator, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: t.hintWeightKg),
                    onSubmitted: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t.hintRepsPerformed),
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
            if (_result != null) ...[
              const SizedBox(height: 20),
              Center(
                child: Text(
                  t.estimated1rmResult(fmt1(_result!)),
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: colors.accent),
                ),
              ),
              const SizedBox(height: 20),
              Text(t.labelRepMaxTable, style: TextStyle(color: colors.mut, fontSize: 12.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var reps = 2; reps <= 10; reps++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.card2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(t.repMaxRow(reps), style: TextStyle(color: colors.mut, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '${fmt1(weightForRepMax(oneRepMax: _result!, reps: reps))} kg',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
