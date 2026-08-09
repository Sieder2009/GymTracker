import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/muscle_group.dart';
import '../state/custom_exercises_provider.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';
import 'exercise_list_view.dart';
import 'muscle_activation_editor.dart';

Future<void> showCreateCustomExerciseSheet(BuildContext context,
    {String? initialName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CreateCustomExerciseSheet(initialName: initialName),
  );
}

/// Name + category + optional fine-grained muscle config, saved via
/// [CustomExercisesProvider] -- unlike typing a name straight into a plan's
/// exercise row, this makes the result reusable everywhere the shared
/// database already is (search, the plan editor's picker).
class _CreateCustomExerciseSheet extends StatefulWidget {
  const _CreateCustomExerciseSheet({this.initialName});
  final String? initialName;

  @override
  State<_CreateCustomExerciseSheet> createState() =>
      _CreateCustomExerciseSheetState();
}

class _CreateCustomExerciseSheetState
    extends State<_CreateCustomExerciseSheet> {
  late final TextEditingController _name;
  String _category = kExerciseCategories.first;

  /// `MuscleGroup.name -> 0-100`, matching [showMuscleActivationEditor]'s
  /// shape directly so the result can be handed straight through.
  Map<String, double> _activation = {};

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _configureMuscles() async {
    final result =
        await showMuscleActivationEditor(context, initial: _activation);
    if (result != null) setState(() => _activation = result);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final activation = _activation.isEmpty
        ? null
        : {
            for (final e in _activation.entries)
              if (muscleGroupFromKey(e.key) != null)
                muscleGroupFromKey(e.key)!: e.value,
          };
    context
        .read<CustomExercisesProvider>()
        .add(name, _category, activation: activation);
    final t = AppLocalizations.of(context)!;
    context.read<ToastProvider>().show(t.toastCustomExerciseSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasMuscles = _activation.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.actionCreateCustomExercise,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(hintText: t.hintExercise),
              ),
              const SizedBox(height: 16),
              Text(t.labelCategory, style: TextStyle(color: colors.mut)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kExerciseCategories)
                    ChoiceChip(
                      label: Text(categoryLabel(t, c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child:
                    ElevatedButton(onPressed: _save, child: Text(t.actionSave)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
