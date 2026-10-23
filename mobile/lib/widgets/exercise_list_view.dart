import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/exercise_muscle_map.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise_template.dart';
import '../models/muscle_group.dart';
import '../state/custom_exercises_provider.dart';
import '../state/exercise_database_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'create_custom_exercise_sheet.dart';
import 'detailed_body_diagram.dart';
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

  // The chip row edits the same category set as the filter sheet, so the
  // two always agree; none selected means all.
  void _toggleCategory(String c) => setState(() => _filter = MuscleFilterResult(
      muscles: _filter.muscles,
      categories: _filter.categories.contains(c)
          ? ({..._filter.categories}..remove(c))
          : {..._filter.categories, c}));

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
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            itemCount: kExerciseCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final c = kExerciseCategories[i];
              return _CategoryPill(
                label: categoryLabel(t, c),
                selected: _filter.categories.contains(c),
                onTap: () => _toggleCategory(c),
              );
            },
          ),
        ),
        if (_filter.muscles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
              ],
            ),
          ),
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
            child: Text(
              t.moveExerciseDayCount(filtered.length),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
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
                    return _ExerciseRow(
                      exercise: ex,
                      // Custom exercises keep their configured muscles in the
                      // provider -- the same lookup the detail sheet makes.
                      activation: custom.activationFor(ex.id) ??
                          muscleActivationForExercise(ex),
                      onTap: () => widget.onTap(ex),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A category toggle in the chip row above the list.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Material(
      color: selected ? colors.accent : colors.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? colors.accent : colors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? colors.onAccent : colors.txt,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One exercise in the list: what it trains at a glance (the working half
/// of the body diagram), its name, and its main muscles by name.
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.activation, required this.onTap});

  final ExerciseTemplate exercise;
  final Map<MuscleGroup, double> activation;
  final VoidCallback onTap;

  /// The three hardest-worked muscles, finer heads folded into their
  /// muscle so "Chest" doesn't show up next to "Upper chest".
  String _mainMuscles(AppLocalizations t) {
    final byMuscle = <MuscleGroup, double>{};
    for (final MapEntry(key: m, value: v) in activation.entries) {
      if (v <= 0) continue;
      final muscle = muscleGroupParent(m) ?? m;
      if (v > (byMuscle[muscle] ?? 0)) byMuscle[muscle] = v;
    }
    final sorted = byMuscle.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(3)) muscleGroupLabel(t, e.key)].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muscles = _mainMuscles(t);
    final subtitle = [
      if (exercise.id.startsWith('custom:')) t.labelCustomExercise,
      muscles.isEmpty ? categoryLabel(t, exercise.category) : muscles,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                MuscleThumbnail(activation: activation),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.mut, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: colors.mut, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
