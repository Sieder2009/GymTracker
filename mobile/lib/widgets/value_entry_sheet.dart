import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// One number to enter in [showValueEntrySheet].
@immutable
class ValueEntryField {
  const ValueEntryField({required this.label, required this.unit, this.initial, this.last});

  final String label;
  final String unit;

  /// Prefilled value (e.g. the current PR); saving it unchanged is not a
  /// change.
  final double? initial;

  /// The previous value, shown under the label as a reference ("Last: 36.5
  /// cm") when the field starts empty.
  final double? last;
}

/// Parses what the user typed: comma or point as the decimal mark. Null
/// for empty; NaN for something that isn't a number above zero.
double? parseEntryValue(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final value = double.tryParse(trimmed.replaceAll(',', '.'));
  return (value == null || value <= 0 || value.isNaN || value.isInfinite) ? double.nan : value;
}

/// A sheet with one clearly labelled row per value -- label (and the last
/// value as a reference) on the left, a number field with its unit on the
/// right -- and one Save button that only lights up once something valid
/// was changed. Replaces cramped rows of tiny inline fields. Returns the
/// value of every field in order (null = left empty), or null when
/// dismissed; the caller decides what a change means.
Future<List<double?>?> showValueEntrySheet(
  BuildContext context, {
  required String title,
  required List<ValueEntryField> fields,
}) {
  return showModalBottomSheet<List<double?>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ValueEntrySheet(title: title, fields: fields),
  );
}

class _ValueEntrySheet extends StatefulWidget {
  const _ValueEntrySheet({required this.title, required this.fields});

  final String title;
  final List<ValueEntryField> fields;

  @override
  State<_ValueEntrySheet> createState() => _ValueEntrySheetState();
}

class _ValueEntrySheetState extends State<_ValueEntrySheet> {
  late final List<TextEditingController> _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial == null ? '' : fmt(f.initial!)),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<double?> get _values => [for (final c in _controllers) parseEntryValue(c.text)];

  bool get _canSave {
    final values = _values;
    if (values.any((v) => v != null && v.isNaN)) return false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null && v != widget.fields[i].initial) return true;
    }
    return false;
  }

  void _save() {
    if (_canSave) Navigator.of(context).pop(_values);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final fields = widget.fields;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: colors.line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: colors.line),
                    _EntryRow(
                      field: fields[i],
                      controller: _controllers[i],
                      autofocus: i == 0,
                      last: i == fields.length - 1,
                      onChanged: () => setState(() {}),
                      onSubmitted: _save,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _canSave ? _save : null,
              child: Text(t.actionSave),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.field,
    required this.controller,
    required this.autofocus,
    required this.last,
    required this.onChanged,
    required this.onSubmitted,
  });

  final ValueEntryField field;
  final TextEditingController controller;
  final bool autofocus;
  final bool last;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final value = parseEntryValue(controller.text);
    final invalid = value != null && value.isNaN;
    final previous = field.last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(field.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                if (previous != null && field.initial == null) ...[
                  const SizedBox(height: 2),
                  Text(
                    t.labelLastValue('${fmt(previous)} ${field.unit}'),
                    style: TextStyle(color: colors.mut, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 124,
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textInputAction: last ? TextInputAction.done : TextInputAction.next,
              onChanged: (_) => onChanged(),
              onSubmitted: last ? (_) => onSubmitted() : null,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                hintText: previous == null ? null : fmt(previous),
                suffixText: field.unit,
                errorText: invalid ? t.errorInvalidValue : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
