import 'package:flutter/material.dart';

import '../data/calorie_calculator.dart';
import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

Future<void> showCalorieCalculator(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CalorieCalculatorSheet(),
  );
}

String _activityLabel(AppLocalizations t, ActivityLevel level) => switch (level) {
      ActivityLevel.sedentary => t.activitySedentary,
      ActivityLevel.light => t.activityLight,
      ActivityLevel.moderate => t.activityModerate,
      ActivityLevel.active => t.activityActive,
      ActivityLevel.veryActive => t.activityVeryActive,
    };

String _goalLabel(AppLocalizations t, CalorieGoal goal) => switch (goal) {
      CalorieGoal.lose => t.goalLose,
      CalorieGoal.maintain => t.goalMaintain,
      CalorieGoal.gain => t.goalGain,
    };

/// Mifflin-St Jeor BMR + activity-level TDEE, then a goal-adjusted calorie
/// and macro split (see `data/calorie_calculator.dart`) -- purely a
/// scratchpad calculator like [showOneRepMaxCalculator]/
/// [showPlateCalculator], doesn't read or write any app data (no stored
/// profile, nothing persisted between opens).
class _CalorieCalculatorSheet extends StatefulWidget {
  const _CalorieCalculatorSheet();

  @override
  State<_CalorieCalculatorSheet> createState() => _CalorieCalculatorSheetState();
}

class _CalorieCalculatorSheetState extends State<_CalorieCalculatorSheet> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  bool _isMale = true;
  ActivityLevel _activity = ActivityLevel.moderate;
  CalorieGoal _goal = CalorieGoal.maintain;
  MacroTargets? _result;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _calculate() {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final height = double.tryParse(_heightController.text.replaceAll(',', '.'));
    final age = int.tryParse(_ageController.text.trim());
    if (weight == null || height == null || age == null) return;
    final bmr = basalMetabolicRate(weightKg: weight, heightCm: height, age: age, isMale: _isMale);
    final tdee = totalDailyEnergyExpenditure(bmr: bmr, activity: _activity);
    setState(() => _result = macroTargets(weightKg: weight, tdee: tdee, goal: _goal));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.titleCalorieCalculator, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: t.hintWeightKg),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: t.hintHeightCm),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: t.hintAgeYears),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('M')),
                      ButtonSegment(value: false, label: Text('F')),
                    ],
                    selected: {_isMale},
                    onSelectionChanged: (s) => setState(() => _isMale = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ActivityLevel>(
                initialValue: _activity,
                decoration: InputDecoration(labelText: t.labelActivityLevel, isDense: true),
                isExpanded: true,
                items: [
                  for (final level in ActivityLevel.values)
                    DropdownMenuItem(value: level, child: Text(_activityLabel(t, level))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _activity = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CalorieGoal>(
                initialValue: _goal,
                decoration: InputDecoration(labelText: t.labelGoal, isDense: true),
                isExpanded: true,
                items: [
                  for (final goal in CalorieGoal.values)
                    DropdownMenuItem(value: goal, child: Text(_goalLabel(t, goal))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _goal = v);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _calculate, child: Text(t.actionCalculate)),
              ),
              if (_result != null) ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '${fmt(_result!.calories.round())} kcal',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: colors.accent),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(t.labelCalorieTarget, style: TextStyle(color: colors.mut, fontSize: 12)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _MacroTile(
                            label: t.labelProtein, grams: _result!.proteinG, colors: colors)),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            _MacroTile(label: t.labelCarbs, grams: _result!.carbsG, colors: colors)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _MacroTile(label: t.labelFat, grams: _result!.fatG, colors: colors)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  t.captionCalorieCalculator,
                  style: TextStyle(color: colors.mut, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({required this.label, required this.grams, required this.colors});

  final String label;
  final double grams;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: colors.card2,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        children: [
          Text('${fmt(grams.round())} g',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: colors.mut, fontSize: 11)),
        ],
      ),
    );
  }
}
