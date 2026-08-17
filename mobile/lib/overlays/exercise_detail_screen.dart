import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../data/weight_conversion.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/history_entry.dart';
import '../models/muscle_group.dart';
import '../services/log_parser.dart';
import '../state/bar_weight_provider.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/detailed_body_diagram.dart';
import '../widgets/exercise_analytics_section.dart';
import '../widgets/exercise_list_view.dart';
import '../widgets/weight_ruler.dart';

String _formatRep(Object v) => v is int ? '$v' : v.toString().toUpperCase();

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
  });

  final List<Exercise> exercises;
  final int startIdx;
  final void Function(int idx, double weight, List<Object> reps) onSave;
  final void Function(int idx, String newName)? onRename;
  final void Function(int idx, double weight, List<HistoryEntry> history)?
      onImportHistory;
  final void Function(int idx, String muscle)? onMuscleChanged;
  final void Function(int idx, String note)? onNoteChanged;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late int _idx;
  late double _weight;
  List<TextEditingController> _repsControllers = [];
  bool _renaming = false;
  final TextEditingController _renameController = TextEditingController();
  bool _historyPasteOpen = false;
  final TextEditingController _historyPasteController = TextEditingController();
  late TextEditingController _noteController;
  late String _muscle;
  bool _perSideEntry = false;

  Exercise get _ex => widget.exercises[_idx];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _loadExercise(widget.startIdx);
  }

  void _loadExercise(int i) {
    for (final c in _repsControllers) {
      c.dispose();
    }
    final ex = widget.exercises[i];
    final lastSetWeight = ex.sets.isNotEmpty ? ex.sets.last.w : 0.0;
    _idx = i;
    _weight = lastSetWeight > 0 ? lastSetWeight : ex.startW;
    _repsControllers =
        List.generate(ex.sets.length, (_) => TextEditingController());
    _renaming = false;
    _historyPasteOpen = false;
    _historyPasteController.clear();
    _noteController.text = ex.note;
    _muscle = ex.muscle;
    _perSideEntry = false;
  }

  @override
  void dispose() {
    for (final c in _repsControllers) {
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
    setState(() => _repsControllers.add(TextEditingController()));
  }

  void _removeSetRow(int i) {
    setState(() {
      _repsControllers[i].dispose();
      _repsControllers.removeAt(i);
    });
  }

  void _save() {
    final reps = _repsControllers
        .map<Object>((c) => int.tryParse(c.text.trim()) ?? 0)
        .toList();
    widget.onSave(_idx, _weight, reps);
    if (_idx < widget.exercises.length - 1) {
      setState(() => _loadExercise(_idx + 1));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;
    final ex = _ex;
    final isLastExercise = _idx == widget.exercises.length - 1;
    final canShowHistoryPaste =
        widget.onImportHistory != null && !_hasRepsEntered;
    // Reverse chronological order, newest first — history entries are
    // appended oldest-first, so this list needs reversing before display.
    final history = ex.history.reversed.toList();

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
                for (var i = 0; i < _repsControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 28,
                            child: Text('${i + 1}',
                                style: TextStyle(color: colors.mut))),
                        Expanded(
                          child: TextField(
                            controller: _repsControllers[i],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(hintText: t.hintReps),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeSetRow(i),
                        ),
                      ],
                    ),
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
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(t.headerHistory,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _HistoryCard(
                        entry: history[i],
                        isLatest: i == 0,
                        colors: colors,
                        t: t,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.infoHistoryLegend,
                    style: TextStyle(color: colors.mut, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One session in the horizontally-scrolling history strip — newest entry
/// (highlighted) on the left, oldest entries trailing to the right, weight
/// as the leading (top-left) label per entry.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard(
      {required this.entry,
      required this.isLatest,
      required this.colors,
      required this.t});

  final HistoryEntry entry;
  final bool isLatest;
  final AppColors colors;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
            left: BorderSide(
                color: isLatest ? colors.green : colors.line, width: 3)),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                entry.weight > 0
                    ? '${fmt1(entry.weight)} kg'
                    : t.labelBodyweightAbbr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (isLatest) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                  ),
                  child: Text(
                    t.labelCurrent,
                    style: TextStyle(
                        color: colors.green,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.reps.map(_formatRep).join(' · '),
            style: TextStyle(color: colors.mut, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
