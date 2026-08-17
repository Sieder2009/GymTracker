import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_set.dart';
import '../state/custom_exercises_provider.dart';
import '../theme/app_colors.dart';
import 'exercise_list_view.dart';
import 'exercise_picker_sheet.dart';
import 'muscle_activation_editor.dart';

/// Adds a single new [Exercise] to an already-saved plan day. Unlike
/// `PlanEditorScreen` (a from-scratch, whole-plan builder), this is the
/// narrower "just add one more exercise" surface for a plan that's already
/// in use — name/sets/reps/weight, the same muscle-category dropdown and
/// note field as the plan editor, plus the existing fine-grained "Muskeln
/// konfigurieren" activation editor. Returns null if dismissed without
/// saving.
Future<Exercise?> showAddExerciseSheet(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _AddExerciseSheet(),
  );
}

class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet();

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final _name = TextEditingController();
  final _sets = TextEditingController(text: '3');
  final _reps = TextEditingController(text: '8');
  final _weight = TextEditingController(text: '0');
  final _note = TextEditingController();
  String _muscle = '';
  Map<String, double> _muscleActivation = {};

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickExercise() async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return;
    _name.text = picked.name;
    // A custom exercise's fine-grained muscle config (if it has one)
    // carries straight into the draft, same as PlanEditorScreen._pickExercise.
    final customActivation =
        context.read<CustomExercisesProvider>().activationFor(picked.id);
    if (customActivation != null) {
      setState(() => _muscleActivation = {
            for (final e in customActivation.entries) e.key.name: e.value,
          });
    }
  }

  Future<void> _configureMuscles() async {
    final result =
        await showMuscleActivationEditor(context, initial: _muscleActivation);
    if (result != null) setState(() => _muscleActivation = result);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final parsedSets = int.tryParse(_sets.text.trim()) ?? 1;
    final setCount = parsedSets < 1 ? 1 : parsedSets;
    final w = double.tryParse(_weight.text.trim().replaceAll(',', '.')) ?? 0;
    final r = _reps.text.trim().isEmpty ? '—' : _reps.text.trim();
    final exercise = Exercise.fresh(
      name,
      _muscle,
      90,
      List.generate(setCount, (_) => ExerciseSet(w: w, r: r)),
      note: _note.text.trim(),
      muscleActivation: _muscleActivation,
    );
    Navigator.of(context).pop(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasMuscles = _muscleActivation.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.actionAddExercise,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: t.hintExercise,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, size: 18),
                        tooltip: t.actionPickFromList,
                        onPressed: _pickExercise,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _sets,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: t.hintSets),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _reps,
                    decoration: InputDecoration(hintText: t.hintReps),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _weight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(hintText: t.hintWeightKg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(hintText: t.hintExerciseNote),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _muscle,
              decoration: InputDecoration(labelText: t.labelMuscleGroup),
              items: [
                DropdownMenuItem(
                    value: '', child: Text(t.labelMuscleGroupNone)),
                for (final c in kExerciseCategories)
                  DropdownMenuItem(
                      value: c, child: Text(categoryLabel(t, c))),
              ],
              onChanged: (v) => setState(() => _muscle = v ?? ''),
            ),
            TextButton.icon(
              onPressed: _configureMuscles,
              icon: Icon(Icons.accessibility_new,
                  size: 16, color: hasMuscles ? colors.accent : colors.mut),
              label: Text(
                hasMuscles ? t.titleMuscleEditor : t.actionConfigureMuscles,
                style: TextStyle(
                    color: hasMuscles ? colors.accent : colors.mut,
                    fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.actionCancel),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _save,
                  child: Text(t.actionSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
