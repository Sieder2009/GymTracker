import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/day.dart';
import '../models/exercise.dart';
import '../models/exercise_set.dart';
import '../models/program.dart';
import '../state/custom_exercises_provider.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../state/train_state_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/exercise_list_view.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/muscle_activation_editor.dart';

class _DraftExercise {
  _DraftExercise()
      : name = TextEditingController(),
        sets = TextEditingController(text: '3'),
        reps = TextEditingController(text: '8'),
        weight = TextEditingController(text: '0'),
        note = TextEditingController();

  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController note;

  /// Broad category dropdown -- see [kExerciseCategories]. Distinct from
  /// [muscleActivation] below, which is a much finer per-muscle breakdown.
  String muscle = '';

  /// Set via [MuscleActivationEditor] — a detailed per-muscle breakdown for
  /// user-authored exercises, on top of the broad category the shared
  /// exercise database already provides for picked-from-list exercises.
  Map<String, double> muscleActivation = {};

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
    note.dispose();
  }
}

class _DraftDay {
  _DraftDay({required this.label, List<_DraftExercise>? exercises})
      : labelController = TextEditingController(text: label),
        exercises = exercises ?? [];

  final String label;
  final TextEditingController labelController;
  bool rest = false;
  List<_DraftExercise> exercises;

  void dispose() {
    labelController.dispose();
    for (final e in exercises) {
      e.dispose();
    }
  }
}

/// "+ Neuer Plan" — full-screen plan builder.
/// Switching weekday/rotation mode discards whatever was entered and resets
/// to a fresh skeleton.
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _mode = 'weekday';
  late List<_DraftDay> _days;

  @override
  void initState() {
    super.initState();
    _days = _weekdaySkeleton();
  }

  List<_DraftDay> _weekdaySkeleton() =>
      kWeekdays.map((label) => _DraftDay(label: label)).toList();

  List<_DraftDay> _rotationSkeleton() =>
      List.generate(3, (i) => _DraftDay(label: 'Tag ${i + 1}'));

  void _setMode(String mode) {
    if (mode == _mode) return;
    for (final d in _days) {
      d.dispose();
    }
    setState(() {
      _mode = mode;
      _days = mode == 'weekday' ? _weekdaySkeleton() : _rotationSkeleton();
    });
  }

  void _addRotationDay() {
    setState(() => _days.add(_DraftDay(label: 'Tag ${_days.length + 1}')));
  }

  void _removeDay(int i) {
    setState(() {
      _days[i].dispose();
      _days.removeAt(i);
    });
  }

  void _addExercise(int dayIdx) {
    setState(() => _days[dayIdx].exercises.add(_DraftExercise()));
  }

  void _removeExercise(int dayIdx, int exIdx) {
    setState(() {
      _days[dayIdx].exercises[exIdx].dispose();
      _days[dayIdx].exercises.removeAt(exIdx);
    });
  }

  void _save() {
    final t = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.read<ToastProvider>().show(t.toastNameRequired);
      return;
    }

    final days = _days.map((d) {
      final isRest = _mode == 'weekday' && d.rest;
      final exercises = isRest
          ? <Exercise>[]
          : d.exercises.where((e) => e.name.text.trim().isNotEmpty).map((e) {
              final parsedSets = int.tryParse(e.sets.text.trim()) ?? 1;
              final setCount = parsedSets < 1 ? 1 : parsedSets;
              final w =
                  double.tryParse(e.weight.text.trim().replaceAll(',', '.')) ??
                      0;
              final r = e.reps.text.trim().isEmpty ? '—' : e.reps.text.trim();
              return Exercise.fresh(
                e.name.text.trim(),
                e.muscle,
                90,
                List.generate(setCount, (_) => ExerciseSet(w: w, r: r)),
                note: e.note.text.trim(),
                muscleActivation: e.muscleActivation,
              );
            }).toList();
      final label = d.labelController.text.trim().isEmpty
          ? d.label
          : d.labelController.text.trim();
      return Day(label: label, rest: isRest, exercises: exercises);
    }).toList();

    final program = Program(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      mode: _mode,
      startDate: todayIso(),
      days: days,
    );

    context.read<ProgramsProvider>().addProgram(program);
    final idx = todayIndexForProgram(
        mode: program.mode, currentDayIdx: program.currentDayIdx);
    context
        .read<TrainStateProvider>()
        .selectPlan(program.id, viewedDayIdx: idx);
    context.read<ToastProvider>().show(t.toastPlanSaved);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final d in _days) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t.titleNewPlan),
        actions: [TextButton(onPressed: _save, child: Text(t.actionSave))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: t.labelPlanName),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'weekday', label: Text(t.modeWeekday)),
                ButtonSegment(value: 'rotation', label: Text(t.modeRotation)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _setMode(s.first),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _days.length; i++) _buildDayCard(i, t),
            if (_mode == 'rotation')
              OutlinedButton(
                onPressed: _addRotationDay,
                child: Text(t.actionAddDayOrRoutine),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(int i, AppLocalizations t) {
    final day = _days[i];
    final hidden = _mode == 'weekday' && day.rest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _mode == 'rotation'
                      ? TextField(
                          controller: day.labelController,
                          decoration:
                              InputDecoration(labelText: t.labelDesignation),
                        )
                      // Weekday labels (Montag..Sonntag) stay in the log
                      // format's German, independent of the UI language —
                      // see the class doc on kWeekdays in data/constants.dart.
                      : Text(day.label,
                          style: Theme.of(context).textTheme.headlineMedium),
                ),
                if (_mode == 'weekday') ...[
                  Text(t.labelRestDay),
                  Checkbox(
                    value: day.rest,
                    onChanged: (v) => setState(() => day.rest = v ?? false),
                  ),
                ],
                if (_mode == 'rotation')
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeDay(i),
                  ),
              ],
            ),
            if (!hidden) ...[
              for (var j = 0; j < day.exercises.length; j++)
                _buildExerciseRow(i, j, t),
              TextButton(
                onPressed: () => _addExercise(i),
                child: Text(t.actionAddExercise),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickExercise(_DraftExercise ex) async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return;
    ex.name.text = picked.name;
    // A custom exercise's fine-grained muscle config (if it has one) should
    // carry straight into this plan instead of starting blank again --
    // otherwise "reusable" custom exercises would only reuse the name.
    final customActivation =
        context.read<CustomExercisesProvider>().activationFor(picked.id);
    if (customActivation != null) {
      setState(() => ex.muscleActivation = {
            for (final e in customActivation.entries) e.key.name: e.value,
          });
    }
  }

  Future<void> _configureMuscles(_DraftExercise ex) async {
    final result =
        await showMuscleActivationEditor(context, initial: ex.muscleActivation);
    if (result != null) setState(() => ex.muscleActivation = result);
  }

  Widget _buildExerciseRow(int dayIdx, int exIdx, AppLocalizations t) {
    final ex = _days[dayIdx].exercises[exIdx];
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasMuscles = ex.muscleActivation.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: ex.name,
                  decoration: InputDecoration(
                    hintText: t.hintExercise,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, size: 18),
                      tooltip: t.actionPickFromList,
                      onPressed: () => _pickExercise(ex),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: ex.sets,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: t.hintSets),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: ex.reps,
                  decoration: InputDecoration(hintText: t.hintReps),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: ex.weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: t.hintWeightKg),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _removeExercise(dayIdx, exIdx),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ex.note,
            decoration: InputDecoration(hintText: t.hintExerciseNote),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: ex.muscle,
            decoration: InputDecoration(labelText: t.labelMuscleGroup),
            items: [
              DropdownMenuItem(value: '', child: Text(t.labelMuscleGroupNone)),
              for (final c in kExerciseCategories)
                DropdownMenuItem(value: c, child: Text(categoryLabel(t, c))),
            ],
            onChanged: (v) => setState(() => ex.muscle = v ?? ''),
          ),
          TextButton.icon(
            onPressed: () => _configureMuscles(ex),
            icon: Icon(Icons.accessibility_new,
                size: 16, color: hasMuscles ? colors.accent : colors.mut),
            label: Text(
              hasMuscles ? t.titleMuscleEditor : t.actionConfigureMuscles,
              style: TextStyle(
                  color: hasMuscles ? colors.accent : colors.mut,
                  fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
