import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/history_entry.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';

/// Field text for a stored number: no grouping (a "1.000" would read back
/// as 1.0) and the comma decimal the rest of the app shows; [_parseNumber]
/// takes either mark back.
final NumberFormat _fieldFmt = NumberFormat('0.##', 'de_DE');

double? _parseNumber(String text) {
  final v = double.tryParse(text.trim().replaceAll(',', '.'));
  return (v == null || v.isNaN || v.isInfinite || v < 0) ? null : v;
}

/// The hand-typed log's per-set markers (see [HistoryEntry.reps]), stored
/// lowercase and shown uppercase.
const Set<String> _repMarkers = {'✓', 'x', 'm'};

/// Opens the editor for one logged [entry] of [exercise]: fix its weight
/// and per-set numbers, or delete it. Resolves to true once the entry was
/// changed or deleted, so the caller can refresh what it shows.
Future<bool> showHistoryEntrySheet(
  BuildContext context, {
  required Exercise exercise,
  required HistoryEntry entry,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HistoryEntrySheet(exercise: exercise, entry: entry),
  );
  return changed ?? false;
}

/// One set row of the editor. [original] (and [originalSpeed]) is what the
/// entry stores for this set -- as long as the row's text is untouched,
/// saving writes exactly that back, so opening and saving an entry never
/// rounds a cardio duration or turns an "X" marker into something else.
/// Rows added in the sheet have no original.
class _SetRow {
  _SetRow(this.initialValue, {this.original, this.initialSpeed, this.originalSpeed})
      : value = TextEditingController(text: initialValue),
        speed = initialSpeed == null ? null : TextEditingController(text: initialSpeed);

  _SetRow.blank({required bool withSpeed}) : this('', initialSpeed: withSpeed ? '' : null);

  final String initialValue;
  final Object? original;
  final String? initialSpeed;
  final double? originalSpeed;
  final TextEditingController value;
  final TextEditingController? speed;

  bool get isEmpty => value.text.trim().isEmpty && (speed?.text.trim().isEmpty ?? true);

  bool get untouched =>
      original != null && value.text == initialValue && (speed == null || speed!.text == initialSpeed);

  void dispose() {
    value.dispose();
    speed?.dispose();
  }
}

/// Edits the entry in its OWN stamped [HistoryEntry.mode], never the
/// exercise's current toggle -- an old Reps entry stays a Reps entry even
/// after the exercise was switched to Timed.
class _HistoryEntrySheet extends StatefulWidget {
  const _HistoryEntrySheet({required this.exercise, required this.entry});

  final Exercise exercise;
  final HistoryEntry entry;

  @override
  State<_HistoryEntrySheet> createState() => _HistoryEntrySheetState();
}

class _HistoryEntrySheetState extends State<_HistoryEntrySheet> {
  late final ExerciseLogMode _mode = widget.entry.mode;
  late final String _initialWeight =
      widget.entry.weight > 0 ? _fieldFmt.format(widget.entry.weight) : '';
  late final TextEditingController _weight = TextEditingController(text: _initialWeight);
  late final List<_SetRow> _rows = _initialRows();
  late final int _initialRowCount = _rows.length;
  // Field errors only show after a save attempt, not while typing.
  bool _showErrors = false;

  List<_SetRow> _initialRows() {
    final e = widget.entry;
    switch (_mode) {
      case ExerciseLogMode.reps:
        return [for (final r in e.reps) _SetRow(r is int ? '$r' : r.toString().toUpperCase(), original: r)];
      case ExerciseLogMode.timed:
        return [for (final d in e.durations ?? const <int>[]) _SetRow('$d', original: d)];
      case ExerciseLogMode.cardio:
        // Minutes, like the exercise screen asks for them.
        final durations = e.durations ?? const <int>[];
        final speeds = e.speeds ?? const <double>[];
        return [
          for (var i = 0; i < durations.length; i++)
            _SetRow(
              _fieldFmt.format(durations[i] / 60),
              original: durations[i],
              initialSpeed: i < speeds.length ? _fieldFmt.format(speeds[i]) : '',
              originalSpeed: i < speeds.length ? speeds[i] : 0.0,
            ),
        ];
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  /// The weight to store, or null when the field holds no valid number.
  /// Empty means bodyweight (Reps) or no added weight (Timed).
  double? get _weightValue {
    if (_weight.text == _initialWeight) return widget.entry.weight;
    if (_weight.text.trim().isEmpty) return 0;
    return _parseNumber(_weight.text);
  }

  /// What [row]'s main field stands for in the entry -- reps or marker,
  /// seconds held, or cardio seconds -- or null when it isn't valid.
  Object? _valueOf(_SetRow row) {
    if (row.original != null && row.value.text == row.initialValue) return row.original;
    final text = row.value.text.trim();
    switch (_mode) {
      case ExerciseLogMode.reps:
        final n = int.tryParse(text);
        if (n != null) return n >= 0 ? n : null;
        final marker = text.toLowerCase();
        return _repMarkers.contains(marker) ? marker : null;
      case ExerciseLogMode.timed:
        final n = int.tryParse(text);
        return n != null && n >= 0 ? n : null;
      case ExerciseLogMode.cardio:
        final minutes = _parseNumber(text);
        return minutes == null ? null : (minutes * 60).round();
    }
  }

  /// Cardio only: the row's speed, 0 when left empty, null when invalid.
  double? _speedOf(_SetRow row) {
    final c = row.speed!;
    if (row.originalSpeed != null && c.text == row.initialSpeed) return row.originalSpeed;
    if (c.text.trim().isEmpty) return 0.0;
    return _parseNumber(c.text);
  }

  bool get _untouched =>
      _weight.text == _initialWeight && _rows.length == _initialRowCount && _rows.every((r) => r.untouched);

  void _revalidate(String _) {
    if (_showErrors) setState(() {});
  }

  void _addRow() => setState(() => _rows.add(_SetRow.blank(withSpeed: _mode == ExerciseLogMode.cardio)));

  void _removeRow(int i) {
    final row = _rows[i];
    setState(() => _rows.removeAt(i));
    // Its TextFields still hold the controllers until this frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _save() {
    if (_untouched) {
      Navigator.of(context).pop(false);
      return;
    }
    final rows = _rows.where((r) => !r.isEmpty).toList();
    final weight = _weightValue;
    final values = [for (final r in rows) _valueOf(r)];
    final speeds = _mode == ExerciseLogMode.cardio ? [for (final r in rows) _speedOf(r)] : const <double?>[];
    if (rows.isEmpty || weight == null || values.contains(null) || speeds.contains(null)) {
      setState(() => _showErrors = true);
      return;
    }
    final t = AppLocalizations.of(context)!;
    final programs = context.read<ProgramsProvider>();
    switch (_mode) {
      case ExerciseLogMode.reps:
        programs.updateHistoryEntry(widget.exercise, widget.entry,
            weight: weight, reps: [for (final v in values) v!]);
      case ExerciseLogMode.timed:
        programs.updateHistoryEntry(widget.exercise, widget.entry,
            weight: weight, durations: [for (final v in values) v! as int]);
      case ExerciseLogMode.cardio:
        programs.updateHistoryEntry(widget.exercise, widget.entry,
            weight: widget.entry.weight,
            durations: [for (final v in values) v! as int],
            speeds: [for (final s in speeds) s!]);
    }
    context.read<ToastProvider>().show(t.toastHistoryEntryUpdated);
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteHistoryEntryTitle),
        content: Text(t.deleteHistoryEntryBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.actionCancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.actionDelete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<ProgramsProvider>().removeHistoryEntry(widget.exercise, widget.entry);
    context.read<ToastProvider>().show(t.toastHistoryEntryDeleted);
    Navigator.of(context).pop(true);
  }

  Widget _buildRow(int i, AppLocalizations t, AppColors colors) {
    final row = _rows[i];
    String? error(bool valid) => _showErrors && !row.isEmpty && !valid ? t.errorInvalidValue : null;
    final String hint;
    switch (_mode) {
      case ExerciseLogMode.reps:
        hint = t.hintReps;
      case ExerciseLogMode.timed:
        hint = t.hintSeconds;
      case ExerciseLogMode.cardio:
        hint = t.hintCardioMinutes;
    }
    return Padding(
      key: ObjectKey(row),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(width: 28, child: Text('${i + 1}', style: TextStyle(color: colors.mut))),
          ),
          Expanded(
            child: TextField(
              controller: row.value,
              keyboardType: _mode == ExerciseLogMode.cardio
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              decoration: InputDecoration(hintText: hint, errorText: error(_valueOf(row) != null)),
              onChanged: _revalidate,
            ),
          ),
          if (row.speed != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: row.speed,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    hintText: t.hintCardioSpeedKmh, errorText: error(_speedOf(row) != null)),
                onChanged: _revalidate,
              ),
            ),
          ],
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _removeRow(i)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final date = DateTime.tryParse(widget.entry.date ?? '');
    final dateLabel = date == null
        ? t.labelNoDate
        : DateFormat.yMMMEd(Localizations.localeOf(context).toString()).format(date);
    final noSetsLeft = _showErrors && _rows.every((r) => r.isEmpty);

    return Padding(
      // Keeps the focused field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.titleEditHistoryEntry, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('${widget.exercise.name} · $dateLabel', style: TextStyle(color: colors.mut)),
              const SizedBox(height: 16),
              if (_mode != ExerciseLogMode.cardio) ...[
                TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _mode == ExerciseLogMode.reps ? t.labelWeightKgField : t.hintAddedWeightKg,
                    hintText: _mode == ExerciseLogMode.reps ? t.labelBodyweightAbbr : null,
                    errorText: _showErrors && _weightValue == null ? t.errorInvalidValue : null,
                  ),
                  onChanged: _revalidate,
                ),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < _rows.length; i++) _buildRow(i, t, colors),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _addRow, child: Text(t.actionAddSet)),
              ),
              if (noSetsLeft)
                Text(t.errorNeedOneSet, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: Text(t.actionDelete, style: const TextStyle(color: Colors.red)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(t.actionCancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _save, child: Text(t.actionSave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
