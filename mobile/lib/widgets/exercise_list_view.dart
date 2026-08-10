import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/exercise_muscle_map.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise_template.dart';
import '../models/muscle_group.dart';
import '../state/custom_exercises_provider.dart';
import '../state/exercise_database_provider.dart';
import '../theme/app_colors.dart';
import 'create_custom_exercise_sheet.dart';
import 'muscle_filter_sheet.dart';

const List<String> kExerciseCategories = [
  'chest',
  'back',
  'shoulders',
  'legs',
  'arms',
  'core',
  'cardio',
];

String categoryLabel(AppLocalizations t, String category) {
  switch (category) {
    case 'chest':
      return t.categoryChest;
    case 'back':
      return t.categoryBack;
    case 'shoulders':
      return t.categoryShoulders;
    case 'legs':
      return t.categoryLegs;
    case 'arms':
      return t.categoryArms;
    case 'core':
      return t.categoryCore;
    case 'cardio':
      return t.categoryCardio;
    default:
      return category;
  }
}

/// Search + muscle/category filter + list, shared between the standalone
/// "Übungen" tab and the plan editor's picker sheet — one implementation,
/// two call sites (see [ExercisesScreen] and `exercise_picker_sheet.dart`).
/// The list is the shared GitHub-sourced database plus every user-created
/// [CustomExercise] concatenated in, so a custom exercise is reusable
/// everywhere the real database already is instead of a one-off typed into
/// a single plan.
class ExerciseListView extends StatefulWidget {
  const ExerciseListView({super.key, required this.onTap});

  final ValueChanged<ExerciseTemplate> onTap;

  @override
  State<ExerciseListView> createState() => _ExerciseListViewState();
}

class _ExerciseListViewState extends State<ExerciseListView> {
  final TextEditingController _search = TextEditingController();
  MuscleFilterResult _filter = const MuscleFilterResult.empty();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final result = await showMuscleFilterSheet(context, initial: _filter);
    if (result == null) return; // dismissed without applying -- no change
    setState(() => _filter = result);
  }

  void _removeMuscle(MuscleGroup m) =>
      setState(() => _filter = MuscleFilterResult(
          muscles: {..._filter.muscles}..remove(m),
          categories: _filter.categories));

  void _removeCategory(String c) => setState(() => _filter = MuscleFilterResult(
      muscles: _filter.muscles,
      categories: {..._filter.categories}..remove(c)));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final db = context.watch<ExerciseDatabaseProvider>();
    final custom = context.watch<CustomExercisesProvider>();
    final query = _search.text.trim().toLowerCase();
    final hasFilter = !_filter.isEmpty;

    final allExercises = [...db.exercises, ...custom.templates];
    final filtered = allExercises.where((e) {
      if (hasFilter) {
        final matchesMuscle =
            _filter.muscles.any((m) => exerciseWorksMuscle(e, m));
        final matchesCategory = _filter.categories.contains(e.category);
        if (!matchesMuscle && !matchesCategory) return false;
      }
      if (query.isNotEmpty && !e.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: t.hintSearchExercise,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                    hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined),
                color: hasFilter ? colors.accent : null,
                tooltip: t.titleMuscleFilter,
                onPressed: _openFilterSheet,
              ),
            ],
          ),
        ),
        if (hasFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _filter.muscles)
                  Chip(
                    label: Text(muscleGroupLabel(t, m)),
                    onDeleted: () => _removeMuscle(m),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                for (final c in _filter.categories)
                  Chip(
                    label: Text(categoryLabel(t, c)),
                    onDeleted: () => _removeCategory(c),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        db.isLoading ? '…' : t.emptyExerciseSearch,
                        style: TextStyle(color: colors.mut),
                      ),
                      if (!db.isLoading && !hasFilter && query.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => showCreateCustomExerciseSheet(
                              context,
                              initialName: _search.text.trim()),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(t.actionCreateCustomExercise),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, i) {
                    if (i == filtered.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              showCreateCustomExerciseSheet(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(t.actionCreateCustomExercise),
                        ),
                      );
                    }
                    final ex = filtered[i];
                    final isCustom = ex.id.startsWith('custom:');
                    return Card(
                      child: ListTile(
                        title: Text(ex.name),
                        subtitle: Text(isCustom
                            ? '${categoryLabel(t, ex.category)} · ${t.labelCustomExercise}'
                            : categoryLabel(t, ex.category)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => widget.onTap(ex),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
