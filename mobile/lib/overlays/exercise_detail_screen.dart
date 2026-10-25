import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../data/duration_format.dart';
import '../data/rep_side_split.dart';
import '../data/weight_conversion.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/history_entry.dart';
import '../models/muscle_group.dart';
import '../services/log_parser.dart';
import '../state/bar_weight_provider.dart';
import '../state/exercise_draft_store.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/detailed_body_diagram.dart';
import '../widgets/exercise_analytics_section.dart';
import '../widgets/exercise_demo_gif.dart';
import '../widgets/exercise_list_view.dart';
import '../widgets/weight_ruler.dart';

/// [Exercise.muscleActivation] is keyed by [MuscleGroup.name] (set via
/// [showMuscleActivationEditor] on a user-authored custom exercise) --
/// [DetailedBodyDiagram] wants the enum itself, so unknown/stale keys
/// (e.g. from a future app version) are simply dropped rather than crash.
Map<MuscleGroup, double> _parsedMuscleActivation(Exercise ex) {
  final byName = {for (final m in MuscleGroup.values) m.name: m};
  return {
    for (final entry in ex.muscleActivation.entries)
      if (byName[entry.key] case final m?) m: entry.value,
  };
}

/// Single-exercise editor: drag-ruler weight picker, per-set reps, rename,
/// "Verlauf einfügen" paste-in, and reversed (most-recent-first) history.
///
/// Saving auto-advances to the next exercise in [exercises] instead of
/// closing — the screen only pops after saving the LAST exercise in the
/// list. Independent of saving, the user can also browse between
/// exercises directly via a horizontal swipe or the left/right arrow keys
/// (see [_goToOffset]) — browsing away never saves unsaved rep entries,
/// same as tapping the close button.
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exercises,
    required this.startIdx,
    required this.onSave,
    this.onRename,
    this.onImportHistory,
    this.onMuscleChanged,
    this.onNoteChanged,
    this.onUnilateralChanged,
    this.onLogModeChanged,
    this.onSaveTimed,
    this.onSaveCardio,
  });

  final List<Exercise> exercises;
  final int startIdx;
  final void Function(int idx, double weight, List<Object> reps) onSave;
  final void Function(int idx, String newName)? onRename;
  final void Function(int idx, double weight, List<HistoryEntry> history)?
      onImportHistory;
  final void Function(int idx, String muscle)? onMuscleChanged;
  final void Function(int idx, String note)? onNoteChanged;
  final void Function(int idx, bool unilateral)? onUnilateralChanged;

  /// See `Exercise.logMode` -- the only place an already-added exercise's
  /// mode can be changed later (the plan editors only set it at creation).
  final void Function(int idx, ExerciseLogMode mode)? onLogModeChanged;

  /// The Timed-mode analogue of [onSave] -- [onSave]'s `(idx, weight,
  /// reps)` contract is Reps-shaped and must not be reused for a Timed
  /// exercise's `(added weight, seconds held per set)`.
  final void Function(int idx, double addedWeightKg, List<int> durationsSec)?
      onSaveTimed;

  /// The Cardio-mode analogue of [onSave].
  final void Function(int idx, List<int> durationsSec, List<double> speedsKmh)?
      onSaveCardio;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late int _idx;
  late double _weight;
  // Reused as each set's main number across modes: reps (Reps), seconds
  // held (Timed), or minutes (Cardio) -- see the class doc.
  List<TextEditingController> _repsControllers = [];
  // Cardio-only: each set's actual speed, kept in step with
  // [_repsControllers] (same length, same add/remove/dispose points).
  List<TextEditingController> _speedControllers = [];
  // The plan's target reps per set (ExerciseSet.r), editable here; one per
  // planned set, so set rows added on this screen have none.
  List<TextEditingController> _targetControllers = [];
  // The weight the exercise opened with -- a draft is only worth keeping
  // once something differs from it (see _stashDraft).
  double _loadedWeight = 0;
  // False once the exercise was saved and the screen closes: dispose must
  // not stash the just-saved input as a draft again.
  bool _stashOnDispose = true;
  bool _renaming = false;
  final TextEditingController _renameController = TextEditingController();
  bool _historyPasteOpen = false;
  final TextEditingController _historyPasteController = TextEditingController();
  late TextEditingController _noteController;
  late String _muscle;
  bool _perSideEntry = false;
  bool _unilateral = false;
  late ExerciseLogMode _logMode;

  Exercise get _ex => widget.exercises[_idx];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _loadExercise(widget.startIdx, stash: false);
  }

  /// Keeps what was typed for the current exercise but not saved in
  /// [ExerciseDraftStore] (memory only), or forgets it when nothing differs
  /// from how the exercise opened.
  void _stashDraft() {
    final ex = _ex;
    final typed = _repsControllers.any((c) => c.text.trim().isNotEmpty) ||
        _speedControllers.any((c) => c.text.trim().isNotEmpty);
    if (!typed && _weight == _loadedWeight && _repsControllers.length == ex.sets.length) {
      ExerciseDraftStore.clear(ex);
      return;
    }
    ExerciseDraftStore.put(
      ex,
      ExerciseDraft(
        logMode: _logMode,
        weight: _weight,
        values: [for (final c in _repsControllers) c.text],
        speeds: [for (final c in _speedControllers) c.text],
      ),
    );
  }

  /// Shows exercise [i], first stashing the current one's unsaved input
  /// unless [stash] is false (first load, or right after saving).
  void _loadExercise(int i, {bool stash = true}) {
    if (stash) _stashDraft();
    for (final c in _repsControllers) {
      c.dispose();
    }
    for (final c in _speedControllers) {
      c.dispose();
    }
    for (final c in _targetControllers) {
      c.dispose();
    }
    final ex = widget.exercises[i];
    final lastSetWeight = ex.sets.isNotEmpty ? ex.sets.last.w : 0.0;
    _idx = i;
    _weight = lastSetWeight > 0 ? lastSetWeight : ex.startW;
    _repsControllers =
        List.generate(ex.sets.length, (_) => TextEditingController());
    _speedControllers =
        List.generate(ex.sets.length, (_) => TextEditingController());
    _renaming = false;
    _historyPasteOpen = false;
    _historyPasteController.clear();
    _noteController.text = ex.note;
    _muscle = ex.muscle;
    _perSideEntry = false;
    _unilateral = ex.unilateral;
    _logMode = ex.logMode;
    _targetControllers = [for (final set in ex.sets) TextEditingController(text: set.r)];
    _loadedWeight = _weight;
    // Back to where the user left off, if they typed something and left
    // without saving -- but never across a log-mode switch.
    final draft = ExerciseDraftStore.of(ex);
    if (draft != null && draft.logMode == _logMode) {
      _weight = draft.weight;
      for (final c in _repsControllers) {
        c.dispose();
      }
      for (final c in _speedControllers) {
        c.dispose();
      }
      _repsControllers = [for (final v in draft.values) TextEditingController(text: v)];
      _speedControllers = [
        for (var k = 0; k < draft.values.length; k++)
          TextEditingController(text: k < draft.speeds.length ? draft.speeds[k] : ''),
      ];
    }
  }

  @override
  void dispose() {
    if (_stashOnDispose) _stashDraft();
    for (final c in _targetControllers) {
      c.dispose();
    }
    for (final c in _repsControllers) {
      c.dispose();
    }
    for (final c in _speedControllers) {
      c.dispose();
    }
    _renameController.dispose();
    _historyPasteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _confirmNote() {
    widget.onNoteChanged?.call(_idx, _noteController.text.trim());
  }

  void _changeMuscle(String? value) {
    setState(() => _muscle = value ?? '');
    widget.onMuscleChanged?.call(_idx, _muscle);
  }

  void _changeUnilateral(bool? value) {
    final v = value ?? false;
    setState(() => _unilateral = v);
    widget.onUnilateralChanged?.call(_idx, v);
  }

  /// Flips this exercise's log mode and clears every per-set text field --
  /// a "12" typed as reps is not 12 seconds, so nothing typed under the old
  /// mode should survive into the new one's differently-shaped fields.
  void _changeLogMode(ExerciseLogMode? value) {
    final mode = value ?? ExerciseLogMode.reps;
    if (mode == _logMode) return;
    setState(() {
      _logMode = mode;
      for (final c in _repsControllers) {
        c.clear();
      }
      for (final c in _speedControllers) {
        c.clear();
      }
    });
    widget.onLogModeChanged?.call(_idx, mode);
  }

  void _startRename() {
    setState(() {
      _renameController.text = _ex.name;
      _renaming = true;
    });
  }

  void _confirmRename() {
    final name = _renameController.text.trim();
    if (name.isNotEmpty) widget.onRename?.call(_idx, name);
    setState(() => _renaming = false);
  }

  bool get _hasRepsEntered =>
      _repsControllers.any((c) => c.text.trim().isNotEmpty);

  void _importHistoryPaste() {
    final t = AppLocalizations.of(context)!;
    final block = parseExerciseBlock(_historyPasteController.text);
    if (block.history.isEmpty) {
      context.read<ToastProvider>().show(t.emptyNoSetsRecognized);
      return;
    }
    widget.onImportHistory?.call(_idx, block.weight, block.history);
    setState(() {
      if (block.weight > 0) _weight = block.weight;
      _historyPasteOpen = false;
      _historyPasteController.clear();
    });
    context.read<ToastProvider>().show(t.toastHistoryImported);
  }

  Future<void> _openWeightKeyboardEntry() async {
    final t = AppLocalizations.of(context)!;
    final barWeightKg = context.read<BarWeightProvider>().barWeightKg;
    var perSide = _perSideEntry;
    String initialText(bool perSideMode) {
      if (_weight <= 0) return '';
      final v = perSideMode
          ? totalToPerSide(totalKg: _weight, barWeightKg: barWeightKg)
          : _weight;
      return fmt1(v);
    }

    final controller = TextEditingController(text: initialText(perSide));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void setMode(bool perSideMode) {
            if (perSideMode == perSide) return;
            setDialogState(() {
              perSide = perSideMode;
              controller.text = initialText(perSide);
            });
          }

          double? parsed() {
            final raw = double.tryParse(controller.text.replaceAll(',', '.'));
            if (raw == null) return null;
            return perSide
                ? perSideToTotal(perSideKg: raw, barWeightKg: barWeightKg)
                : raw;
          }

          return AlertDialog(
            title: Text(t.titleEnterWeight),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(t.labelTotal)),
                    ButtonSegment(value: true, label: Text(t.labelPerSide)),
                  ],
                  selected: {perSide},
                  onSelectionChanged: (s) => setMode(s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(suffixText: 'kg'),
                  // Both comma and period should work as the decimal separator.
                  onSubmitted: (_) => Navigator.of(ctx).pop(parsed()),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(t.actionCancel)),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(parsed()),
                child: Text(t.actionApply),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && result >= 0) {
      setState(() {
        _weight = result;
        _perSideEntry = perSide;
      });
    }
  }

  /// Browses to another exercise in [widget.exercises] without saving --
  /// clamps silently at either end instead of wrapping, so swiping past
  /// the first/last exercise is just a no-op rather than looping around.
  void _goToOffset(int delta) {
    final next = _idx + delta;
    if (next < 0 || next >= widget.exercises.length) return;
    setState(() => _loadExercise(next));
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Swipe left (negative velocity) -> next exercise, mirroring the
    // left-to-right reading order of "forward" through the list.
    if (velocity < -250) {
      _goToOffset(1);
    } else if (velocity > 250) {
      _goToOffset(-1);
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goToOffset(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goToOffset(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _addSetRow() {
    setState(() {
      _repsControllers.add(TextEditingController());
      _speedControllers.add(TextEditingController());
    });
  }

  void _removeSetRow(int i) {
    setState(() {
      _repsControllers[i].dispose();
      _repsControllers.removeAt(i);
      _speedControllers[i].dispose();
      _speedControllers.removeAt(i);
    });
  }

  /// The planned target reps of set [i] (e.g. "8" or "8-12"), saved into
  /// the plan as it is typed; rows added only on this screen have no
  /// planned set to edit.
  Widget _targetField(int i, AppLocalizations t) {
    if (i >= _targetControllers.length) return const SizedBox.shrink();
    return TextField(
      controller: _targetControllers[i],
      keyboardType: TextInputType.text,
      textAlign: TextAlign.center,
      decoration: InputDecoration(labelText: t.labelTargetReps),
      onChanged: (value) {
        final reps = value.trim();
        if (reps.isEmpty) return;
        context.read<ProgramsProvider>().setTargetReps(widget.exercises, _idx, i, reps);
      },
    );
  }

  /// One set's row, shaped for [_logMode]: reps (unchanged), a single
  /// seconds-held field (Timed), or minutes+speed fields (Cardio) --
  /// [_repsControllers] is reused as each mode's main number (see the
  /// class doc), with [_speedControllers] added in parallel for Cardio.
  Widget _buildSetRow(int i, AppLocalizations t, AppColors colors) {
    final indexLabel =
        SizedBox(width: 28, child: Text('${i + 1}', style: TextStyle(color: colors.mut)));
    final removeButton = IconButton(
      icon: const Icon(Icons.close, size: 18),
      onPressed: () => _removeSetRow(i),
    );
    switch (_logMode) {
      case ExerciseLogMode.reps:
        return Row(
          children: [
            indexLabel,
            Expanded(
              child: AnimatedBuilder(
                animation: _repsControllers[i],
                builder: (context, _) {
                  final parsed = int.tryParse(_repsControllers[i].text.trim());
                  final perSideCaption = _unilateral && parsed != null
                      ? t.labelRepsPerSide(fmt(repsPerSide(parsed)))
                      : null;
                  return TextField(
                    controller: _repsControllers[i],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: t.hintReps,
                      helperText: perSideCaption,
                      helperStyle: TextStyle(color: colors.mut, fontSize: 11.5),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 84, child: _targetField(i, t)),
            removeButton,
          ],
        );
      case ExerciseLogMode.timed:
        return Row(
          children: [
            indexLabel,
            Expanded(
              child: TextField(
                controller: _repsControllers[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: t.hintTargetSeconds),
              ),
            ),
            removeButton,
          ],
        );
      case ExerciseLogMode.cardio:
        return Row(
          children: [
            indexLabel,
            Expanded(
              child: TextField(
                controller: _repsControllers[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: t.hintCardioMinutes),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _speedControllers[i],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(hintText: t.hintCardioSpeedKmh),
              ),
            ),
            removeButton,
          ],
        );
    }
  }

  void _save() {
    switch (_logMode) {
      case ExerciseLogMode.reps:
        final reps = _repsControllers
            .map<Object>((c) => int.tryParse(c.text.trim()) ?? 0)
            .toList();
        widget.onSave(_idx, _weight, reps);
      case ExerciseLogMode.timed:
        final durations = [
          for (final c in _repsControllers) int.tryParse(c.text.trim()) ?? 0
        ];
        widget.onSaveTimed?.call(_idx, _weight, durations);
      case ExerciseLogMode.cardio:
        final durations = [
          for (final c in _repsControllers)
            (int.tryParse(c.text.trim()) ?? 0) * 60
        ];
        final speeds = [
          for (final c in _speedControllers)
            double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0.0
        ];
        widget.onSaveCardio?.call(_idx, durations, speeds);
    }
    ExerciseDraftStore.clear(_ex);
    if (_idx < widget.exercises.length - 1) {
      setState(() => _loadExercise(_idx + 1, stash: false));
    } else {
      _stashOnDispose = false;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;
    final ex = _ex;
    final isLastExercise = _idx == widget.exercises.length - 1;
    // The hand-typed-log paste format is reps-only by design (see
    // `services/log_parser.dart`) and must never fabricate a weight/rep
    // history entry on a Timed/Cardio exercise.
    final canShowHistoryPaste = widget.onImportHistory != null &&
        !_hasRepsEntered &&
        _logMode == ExerciseLogMode.reps;
    // Re-resolved from the current name on every build, so it follows a
    // swipe/arrow-key move to another exercise and a rename alike; null
    // (no card) for names the shared database doesn't know.
    final demoGif = resolveExerciseGif(context, ex.name);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _renaming
            ? TextField(
                controller: _renameController,
                autofocus: true,
                onSubmitted: (_) => _confirmRename(),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                      child: Text(ex.name, overflow: TextOverflow.ellipsis)),
                  if (widget.onRename != null)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: _startRename,
                    ),
                ],
              ),
        actions: _renaming
            ? [
                IconButton(
                    icon: const Icon(Icons.check), onPressed: _confirmRename)
              ]
            : null,
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _onHorizontalSwipe,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (demoGif != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ExerciseDemoCard(gif: demoGif, exerciseName: ex.name),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _noteController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: t.hintExerciseNote,
                      isDense: true,
                    ),
                    onEditingComplete: _confirmNote,
                    onTapOutside: (_) => _confirmNote(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _muscle,
                    decoration: InputDecoration(
                      labelText: t.labelMuscleGroup,
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                          value: '', child: Text(t.labelMuscleGroupNone)),
                      for (final c in kExerciseCategories)
                        DropdownMenuItem(
                            value: c, child: Text(categoryLabel(t, c))),
                    ],
                    onChanged: _changeMuscle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.labelLogMode, style: TextStyle(color: colors.mut, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      SegmentedButton<ExerciseLogMode>(
                        segments: [
                          ButtonSegment(
                              value: ExerciseLogMode.reps,
                              label: Text(t.logModeReps)),
                          ButtonSegment(
                              value: ExerciseLogMode.timed,
                              label: Text(t.logModeTimed)),
                          ButtonSegment(
                              value: ExerciseLogMode.cardio,
                              label: Text(t.logModeCardio)),
                        ],
                        selected: {_logMode},
                        onSelectionChanged: (s) => _changeLogMode(s.first),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _unilateral,
                            onChanged: _changeUnilateral,
                          ),
                          Expanded(
                            child: Text(t.labelUnilateralToggle,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          t.hintUnilateralToggle,
                          style: TextStyle(color: colors.mut, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Only custom exercises carry their own activation map
                // (picked exercises show this in the "Übungen" library
                // instead, keyed off the shared database) -- an empty map
                // just means nobody has configured one for this exercise
                // yet, not an error.
                if (ex.muscleActivation.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: DetailedBodyDiagram(
                        activation: _parsedMuscleActivation(ex),
                        size: 150,
                        enableZoom: true,
                      ),
                    ),
                  ),
                if (_logMode != ExerciseLogMode.cardio) ...[
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      onTap: _openWeightKeyboardEntry,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          _weight > 0
                              ? '${fmt1(_weight)} kg'
                              : t.labelBodyweightAbbr,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  WeightRuler(
                      value: _weight,
                      onChanged: (v) => setState(() => _weight = v)),
                  Center(
                    child: Text(
                      t.infoDragToChange,
                      style: TextStyle(color: colors.mut, fontSize: 11.5),
                    ),
                  ),
                  if (_perSideEntry && _weight > 0)
                    Center(
                      child: Text(
                        '${fmt1(totalToPerSide(totalKg: _weight, barWeightKg: context.watch<BarWeightProvider>().barWeightKg))} kg ${t.labelPerSide.toLowerCase()}',
                        style: TextStyle(color: colors.mut, fontSize: 11.5),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                for (var i = 0; i < _repsControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildSetRow(i, t, colors),
                  ),
                TextButton(onPressed: _addSetRow, child: Text(t.actionAddSet)),
                const SizedBox(height: 12),
                if (canShowHistoryPaste) ...[
                  if (!_historyPasteOpen)
                    TextButton(
                      onPressed: () =>
                          setState(() => _historyPasteOpen = true),
                      child: Text(t.actionAddHistoryPaste),
                    )
                  else ...[
                    TextField(
                      controller: _historyPasteController,
                      maxLines: 4,
                      decoration:
                          InputDecoration(hintText: t.hintExerciseHistoryPaste),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _historyPasteOpen = false),
                          child: Text(t.actionCancel),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _importHistoryPaste,
                          child: Text(t.actionApply),
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(
                        isLastExercise ? t.actionSave : t.actionSaveAndNext),
                  ),
                ),
                const SizedBox(height: 28),
                ExerciseAnalyticsSection(exercise: ex),
                const SizedBox(height: 28),
                _UpNextCard(
                  next: isLastExercise ? null : widget.exercises[_idx + 1],
                  onTap: () => _goToOffset(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "how it's done" card: a small animation (credited inside its own
/// card) beside a title and a tap-to-enlarge hint -- the whole card opens
/// the full-size view. Only taps are claimed here, so a horizontal swipe
/// starting on the card still reaches the screen's swipe-to-browse handler.
class _ExerciseDemoCard extends StatelessWidget {
  const _ExerciseDemoCard({required this.gif, required this.exerciseName});

  final String gif;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    void enlarge() => showExerciseDemoDialog(context, gif: gif, exerciseName: exerciseName);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enlarge,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ExerciseDemoGif(
                gif: gif,
                size: 110,
                exerciseName: exerciseName,
                onTap: enlarge,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.exerciseDemoTitle,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      t.exerciseDemoTapToEnlarge,
                      style: TextStyle(color: colors.mut, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_full_rounded, size: 18, color: colors.mut),
            ],
          ),
        ),
      ),
    );
  }
}

/// The end of the scroll view: what comes after this exercise, so scrolling
/// all the way down answers "what's next?" -- tapping it browses there
/// (without saving, like a swipe; unsaved input stays as a draft). On the
/// last exercise it just says so.
class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.next, required this.onTap});

  final Exercise? next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final exercise = next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.headerUpNext, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        if (exercise == null)
          Text(t.infoLastExercise, style: TextStyle(color: colors.mut))
        else
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: onTap,
              title: Text(exercise.name, style: Theme.of(context).textTheme.headlineMedium),
              subtitle: exercise.sets.isEmpty
                  ? null
                  : Text(exerciseSetsSummaryLabel(t, exercise), style: TextStyle(color: colors.mut)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (exercise.logMode == ExerciseLogMode.reps && exercise.currentWeight > 0)
                    Text('${fmt1(exercise.currentWeight)} kg',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right_rounded, color: colors.mut),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
