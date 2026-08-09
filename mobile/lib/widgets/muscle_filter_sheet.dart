import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/body_atlas.dart';
import '../l10n/app_localizations.dart';
import '../models/muscle_group.dart';
import '../state/athlete_settings_provider.dart';
import '../theme/app_colors.dart';
import 'detailed_body_diagram.dart';
import 'exercise_list_view.dart';

/// Result of the muscle-filter sheet -- mutually exclusive: either a tapped
/// [muscle] (fine-grained, matched via [exerciseWorksMuscle]), a manually
/// picked [category], or neither (clears the filter). `null` from
/// [showMuscleFilterSheet] itself means "dismissed, don't change anything",
/// distinct from this class's `.all()` (explicit "show everything").
class MuscleFilterResult {
  const MuscleFilterResult.muscle(MuscleGroup m)
      : muscle = m,
        category = null;
  const MuscleFilterResult.category(String c)
      : muscle = null,
        category = c;
  const MuscleFilterResult.all()
      : muscle = null,
        category = null;

  final MuscleGroup? muscle;
  final String? category;
}

Future<MuscleFilterResult?> showMuscleFilterSheet(BuildContext context) {
  return showModalBottomSheet<MuscleFilterResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _MuscleFilterSheet(),
  );
}

/// Tap a body part to filter the exercise list by muscle group -- reuses
/// the exact tap-to-select mechanism already built for
/// [MuscleActivationEditor] ([ParsedBodyAtlas.hitTest] against the real
/// illustrated shape), plus a manual category fallback below for anyone
/// who'd rather just pick a category the old way.
class _MuscleFilterSheet extends StatefulWidget {
  const _MuscleFilterSheet();

  @override
  State<_MuscleFilterSheet> createState() => _MuscleFilterSheetState();
}

class _MuscleFilterSheetState extends State<_MuscleFilterSheet> {
  bool _front = true;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final gender = isMale ? BodyGender.male : BodyGender.female;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.92,
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
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pop(const MuscleFilterResult.all()),
                      child: Text(t.categoryAll),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t.hintMuscleFilterOrManual,
                    style: TextStyle(color: colors.mut, fontSize: 12.5)),
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
                                  if (hit != null) {
                                    Navigator.of(context)
                                        .pop(MuscleFilterResult.muscle(hit));
                                  }
                                },
                                child: CustomPaint(
                                  size: size,
                                  painter: BodyDiagramPainter(
                                    front: _front,
                                    gender: gender,
                                    activation: const {},
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
                              ActionChip(
                                label: Text(categoryLabel(t, c)),
                                onPressed: () => Navigator.of(context)
                                    .pop(MuscleFilterResult.category(c)),
                              ),
                          ],
                        ),
                      ],
                    ),
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
