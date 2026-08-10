import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/body_atlas.dart';
import '../l10n/app_localizations.dart';
import '../models/muscle_group.dart';
import '../state/athlete_settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'detailed_body_diagram.dart';
import 'exercise_list_view.dart';

/// Multi-select filter result -- any exercise matching *any* selected
/// muscle or category is shown (broadening, not narrowing, matches how
/// picking several body parts at once is expected to behave: "show me
/// shoulders AND chest exercises", not their intersection).
class MuscleFilterResult {
  const MuscleFilterResult({required this.muscles, required this.categories});
  const MuscleFilterResult.empty()
      : muscles = const {},
        categories = const {};

  final Set<MuscleGroup> muscles;
  final Set<String> categories;

  bool get isEmpty => muscles.isEmpty && categories.isEmpty;
}

Future<MuscleFilterResult?> showMuscleFilterSheet(
  BuildContext context, {
  required MuscleFilterResult initial,
}) {
  return showModalBottomSheet<MuscleFilterResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MuscleFilterSheet(initial: initial),
  );
}

/// Tap one or more body parts to filter the exercise list by muscle group
/// -- reuses the exact tap-to-select mechanism already built for
/// [MuscleActivationEditor] ([ParsedBodyAtlas.hitTest] against the real
/// illustrated shape), extended to multi-select (tap again to remove), plus
/// a manual multi-select category fallback below for anyone who'd rather
/// just pick categories the old way. Selections only take effect on
/// "Anwenden" -- closing the sheet any other way (back/swipe) discards
/// them, matching how the rest of the app treats an editor sheet.
class _MuscleFilterSheet extends StatefulWidget {
  const _MuscleFilterSheet({required this.initial});
  final MuscleFilterResult initial;

  @override
  State<_MuscleFilterSheet> createState() => _MuscleFilterSheetState();
}

class _MuscleFilterSheetState extends State<_MuscleFilterSheet> {
  bool _front = true;
  late Set<MuscleGroup> _muscles;
  late Set<String> _categories;

  @override
  void initState() {
    super.initState();
    _muscles = {...widget.initial.muscles};
    _categories = {...widget.initial.categories};
  }

  void _toggleMuscle(MuscleGroup m) {
    setState(() {
      if (!_muscles.add(m)) _muscles.remove(m);
    });
  }

  void _toggleCategory(String c) {
    setState(() {
      if (!_categories.add(c)) _categories.remove(c);
    });
  }

  void _clearAll() => setState(() {
        _muscles.clear();
        _categories.clear();
      });

  void _apply() => Navigator.of(context)
      .pop(MuscleFilterResult(muscles: _muscles, categories: _categories));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final gender = isMale ? BodyGender.male : BodyGender.female;
    final hasSelection = _muscles.isNotEmpty || _categories.isNotEmpty;
    // Highlight every selected muscle at full intensity by reusing the
    // diagram's normal activation coloring, rather than needing a
    // multi-value "selected" concept the painter doesn't have.
    final highlightActivation = {for (final m in _muscles) m: 100.0};

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(t.titleMuscleFilter,
                          style: Theme.of(context).textTheme.headlineLarge),
                    ),
                    if (hasSelection)
                      TextButton(
                        onPressed: _clearAll,
                        child: Text(t.categoryAll),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t.hintMuscleFilterOrManual,
                    style: TextStyle(color: colors.mut, fontSize: 12.5)),
                if (hasSelection) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in _muscles)
                        _SelectionChip(
                          label: muscleGroupLabel(t, m),
                          colors: colors,
                          onRemove: () => _toggleMuscle(m),
                        ),
                      for (final c in _categories)
                        _SelectionChip(
                          label: categoryLabel(t, c),
                          colors: colors,
                          onRemove: () => _toggleCategory(c),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(t.actionFront)),
                    ButtonSegment(value: false, label: Text(t.actionBack)),
                  ],
                  selected: {_front},
                  onSelectionChanged: (s) => setState(() => _front = s.first),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: kBodyDiagramAspect,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = Size(
                                  constraints.maxWidth, constraints.maxHeight);
                              return GestureDetector(
                                onTapUp: (details) {
                                  final hit =
                                      ParsedBodyAtlas.get(gender, _front, size)
                                          .hitTest(details.localPosition);
                                  if (hit != null) _toggleMuscle(hit);
                                },
                                child: CustomPaint(
                                  size: size,
                                  painter: BodyDiagramPainter(
                                    front: _front,
                                    gender: gender,
                                    activation: highlightActivation,
                                    accent: colors.accent,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: colors.line),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in kExerciseCategories)
                              FilterChip(
                                label: Text(categoryLabel(t, c)),
                                selected: _categories.contains(c),
                                onSelected: (_) => _toggleCategory(c),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: Text(t.actionApply),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip(
      {required this.label, required this.colors, required this.onRemove});

  final String label;
  final AppColors colors;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5)),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
