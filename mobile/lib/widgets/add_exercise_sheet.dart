import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/duration_format.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../state/custom_exercises_provider.dart';
import '../theme/app_colors.dart';
import 'exercise_list_view.dart';
import 'exercise_picker_sheet.dart';
import 'muscle_activation_editor.dart';

/// Adds a single new [Exercise] to an already-saved plan day. Unlike
/// `PlanEditorScreen` (a from-scratch, whole-plan builder), this is the
/// narrower "just add one more exercise" surface for a plan that's already
/// in use. It is laid out as three numbered questions -- which exercise,
/// what gets logged, what the target is -- with every field carrying a
/// visible label and unit (the fields start pre-filled, so a placeholder
/// hint would never show). Note, per-side logging and the fine-grained
/// muscle activation editor sit in a collapsed "more options" group.
/// Returns null if dismissed without saving.
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
  static const _defaultSets = '3';
  static const _defaultCardioSets = '1';

  final _name = TextEditingController();
  final _sets = TextEditingController(text: _defaultSets);
  final _reps = TextEditingController(text: '8');
  final _weight = TextEditingController(text: '0');
  final _targetSeconds = TextEditingController(text: '30');
  final _cardioMinutes = TextEditingController(text: '20');
  final _cardioSpeed = TextEditingController(text: '6.0');
  final _note = TextEditingController();
  String _muscle = '';
  Map<String, double> _muscleActivation = {};
  bool _unilateral = false;
  ExerciseLogMode _logMode = ExerciseLogMode.reps;

  /// Set once the user types into the sets field, so switching to/from
  /// Cardio only swaps the default set count (3 <-> 1) while it is still
  /// untouched -- never overwrites a number they chose.
  bool _setsEdited = false;

  /// Shown after a save attempt with an empty name, instead of the old
  /// silent no-op.
  bool _showNameError = false;

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _targetSeconds.dispose();
    _cardioMinutes.dispose();
    _cardioSpeed.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setLogMode(ExerciseLogMode mode) => setState(() => _applyLogMode(mode));

  /// Call inside setState.
  void _applyLogMode(ExerciseLogMode mode) {
    if (mode == _logMode) return;
    _logMode = mode;
    if (!_setsEdited) {
      _sets.text =
          mode == ExerciseLogMode.cardio ? _defaultCardioSets : _defaultSets;
    }
  }

  Future<void> _pickExercise() async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return;
    // A custom exercise's fine-grained muscle config (if it has one)
    // carries straight into the draft, same as PlanEditorScreen._pickExercise.
    final customActivation =
        context.read<CustomExercisesProvider>().activationFor(picked.id);
    setState(() {
      _name.text = picked.name;
      _showNameError = false;
      // The database's categories are exactly kExerciseCategories, so the
      // muscle group can be filled in for free -- and a cardio entry
      // (treadmill, rowing, ...) almost certainly wants Cardio logging.
      if (kExerciseCategories.contains(picked.category)) {
        _muscle = picked.category;
      }
      if (picked.category == 'cardio') _applyLogMode(ExerciseLogMode.cardio);
      if (customActivation != null) {
        _muscleActivation = {
          for (final e in customActivation.entries) e.key.name: e.value,
        };
      }
    });
  }

  Future<void> _configureMuscles() async {
    final result =
        await showMuscleActivationEditor(context, initial: _muscleActivation);
    if (result != null) setState(() => _muscleActivation = result);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }
    final parsedSets = int.tryParse(_sets.text.trim()) ?? 1;
    final setCount = parsedSets < 1 ? 1 : parsedSets;
    final w = double.tryParse(_weight.text.trim().replaceAll(',', '.')) ?? 0;
    final targetSeconds = _logMode == ExerciseLogMode.cardio
        ? (int.tryParse(_cardioMinutes.text.trim()) ?? 20) * 60
        : int.tryParse(_targetSeconds.text.trim()) ?? 30;
    final targetSpeed =
        double.tryParse(_cardioSpeed.text.trim().replaceAll(',', '.')) ?? 6.0;
    final exercise = Exercise.fresh(
      name,
      _muscle,
      90,
      buildLogModeSets(
        mode: _logMode,
        setCount: setCount,
        weightKg: w,
        repsTarget: _reps.text.trim(),
        targetSeconds: targetSeconds,
        targetSpeedKmh: targetSpeed,
      ),
      note: _note.text.trim(),
      muscleActivation: _muscleActivation,
      unilateral: _unilateral,
      logMode: _logMode,
    );
    Navigator.of(context).pop(exercise);
  }

  // ---------------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------------

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    bool decimal = false,
    bool digitsOnly = true,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: !digitsOnly
          ? TextInputType.text
          : TextInputType.numberWithOptions(decimal: decimal),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        // Keeps the label readable above a pre-filled value instead of
        // letting it collapse into the field.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      ),
    );
  }

  /// The target row for the chosen log mode: always sets first, then the
  /// two mode-specific numbers, each with its label and unit on screen.
  Widget _buildTargetRow(AppLocalizations t) {
    final sets = _numberField(
      controller: _sets,
      label: t.hintSets,
      onChanged: (_) => _setsEdited = true,
    );
    final List<Widget> rest;
    switch (_logMode) {
      case ExerciseLogMode.reps:
        rest = [
          // Free text so a range like "8-12" stays possible.
          _numberField(controller: _reps, label: t.hintReps, digitsOnly: false),
          _numberField(
              controller: _weight,
              label: t.labelWeight,
              suffix: 'kg',
              decimal: true),
        ];
      case ExerciseLogMode.timed:
        rest = [
          _numberField(
              controller: _targetSeconds,
              label: t.labelHoldTime,
              suffix: t.unitSec),
          _numberField(
              controller: _weight,
              label: t.labelAddedWeight,
              suffix: 'kg',
              decimal: true),
        ];
      case ExerciseLogMode.cardio:
        rest = [
          _numberField(
              controller: _cardioMinutes,
              label: t.labelDuration,
              suffix: t.unitMin),
          _numberField(
              controller: _cardioSpeed,
              label: t.labelSpeed,
              suffix: t.unitKmh,
              decimal: true),
        ];
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: sets),
        const SizedBox(width: 8),
        Expanded(flex: 5, child: rest[0]),
        const SizedBox(width: 8),
        Expanded(flex: 6, child: rest[1]),
      ],
    );
  }

  String _modeExplainer(AppLocalizations t) {
    switch (_logMode) {
      case ExerciseLogMode.reps:
        return t.logModeRepsExplainer;
      case ExerciseLogMode.timed:
        return t.logModeTimedExplainer;
      case ExerciseLogMode.cardio:
        return t.logModeCardioExplainer;
    }
  }

  String _targetHelper(AppLocalizations t) {
    switch (_logMode) {
      case ExerciseLogMode.reps:
        return t.helperRepsTarget;
      case ExerciseLogMode.timed:
        return t.helperTimedTarget;
      case ExerciseLogMode.cardio:
        return t.helperCardioTarget;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasMuscles = _muscleActivation.isNotEmpty;
    final helperStyle =
        TextStyle(color: colors.mut, fontSize: 12, height: 1.35);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(t.titleAddExercise,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 19)),
                ),
                IconButton(
                  tooltip: t.actionCancel,
                  icon: Icon(Icons.close, color: colors.mut),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1 -- which exercise --------------------------------------
                  _StepHeader(number: 1, title: t.sectionWhichExercise),
                  const SizedBox(height: 10),
                  _PickFromListTile(
                    title: t.actionBrowseExerciseList,
                    subtitle: t.hintBrowseExerciseList,
                    onTap: _pickExercise,
                  ),
                  _OrDivider(label: t.labelOrTypeOwnName),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (_showNameError) {
                        setState(() => _showNameError = false);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: t.labelExerciseName,
                      prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                      errorText:
                          _showNameError ? t.errorExerciseNameRequired : null,
                      errorMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    // initialValue is only read once -- the key rebuilds
                    // the field when picking from the list fills it in.
                    key: ValueKey(_muscle),
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
                  const SizedBox(height: 26),

                  // 2 -- what gets logged -------------------------------------
                  _StepHeader(number: 2, title: t.sectionWhatYouLog),
                  const SizedBox(height: 10),
                  SegmentedButton<ExerciseLogMode>(
                    showSelectedIcon: false,
                    segments: [
                      // Text only, scaled down when needed: "Wiederholungen"
                      // is wider than a third of a phone-width sheet.
                      for (final (mode, label) in [
                        (ExerciseLogMode.reps, t.logModeReps),
                        (ExerciseLogMode.timed, t.logModeTimed),
                        (ExerciseLogMode.cardio, t.logModeCardio),
                      ])
                        ButtonSegment(
                          value: mode,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(label, maxLines: 1),
                          ),
                        ),
                    ],
                    selected: {_logMode},
                    onSelectionChanged: (s) => _setLogMode(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(_modeExplainer(t), style: helperStyle),
                  const SizedBox(height: 26),

                  // 3 -- target per workout -----------------------------------
                  _StepHeader(number: 3, title: t.sectionTargetPerWorkout),
                  const SizedBox(height: 14),
                  _buildTargetRow(t),
                  const SizedBox(height: 8),
                  Text(_targetHelper(t), style: helperStyle),
                  const SizedBox(height: 14),

                  // More options (collapsed) ----------------------------------
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(Icons.tune, color: colors.mut, size: 20),
                      title: Text(t.sectionMoreOptions,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(t.hintMoreOptions,
                          style: TextStyle(color: colors.mut, fontSize: 12)),
                      children: [
                        TextField(
                          controller: _note,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            labelText: t.labelNote,
                            hintText: t.hintExerciseNote,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _unilateral,
                          onChanged: (v) => setState(() => _unilateral = v),
                          title: Text(t.labelUnilateralToggle,
                              style: const TextStyle(fontSize: 14)),
                          subtitle:
                              Text(t.hintUnilateralToggle, style: helperStyle),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _configureMuscles,
                            icon: Icon(Icons.accessibility_new,
                                size: 18,
                                color: hasMuscles ? colors.accent : colors.mut),
                            label: Text(
                              hasMuscles
                                  ? t.titleMuscleEditor
                                  : t.actionConfigureMuscles,
                              style: TextStyle(
                                  color:
                                      hasMuscles ? colors.accent : colors.mut,
                                  fontSize: 13.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Pinned below the scroll area so it stays reachable above the
          // keyboard; SafeArea keeps it clear of the gesture bar.
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.line)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.actionCancel),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(t.actionAdd),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered step title ("1  Which exercise?").
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: colors.accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }
}

/// The primary way in: a large tappable row that opens the exercise list.
class _PickFromListTile extends StatelessWidget {
  const _PickFromListTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Material(
      color: colors.accentSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.search, color: colors.onAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: colors.accent,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: colors.mut, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// "—— or type your own name ——"
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.line, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child:
                Text(label, style: TextStyle(color: colors.mut, fontSize: 12)),
          ),
          Expanded(child: Divider(color: colors.line, height: 1)),
        ],
      ),
    );
  }
}
