import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/exercise_archetype.dart';
import '../data/exercise_guides.dart';
import '../data/exercise_muscle_map.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise_template.dart';
import '../state/custom_exercises_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/app_shell.dart';
import '../widgets/detailed_body_diagram.dart';
import '../widgets/exercise_list_view.dart';

/// "Übungen" tab: the full shared exercise database, searchable and
/// filterable by muscle group — tapping one shows exactly which muscles it
/// trains and how much (see [DetailedBodyDiagram], an original diagram,
/// not a scraped image) and a link to search for a tutorial. The app never
/// embeds or downloads third-party exercise videos/photos — only links out
/// to let the user watch one on YouTube themselves, which sidesteps
/// redistributing anyone else's copyrighted material.
class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(t.tabExercises,
                style: Theme.of(context).textTheme.headlineLarge),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: kFloatingNavClearance),
              child: ExerciseListView(
                onTap: (ex) => _showDetail(context, ex),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, ExerciseTemplate ex) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExerciseDetailSheet(exercise: ex),
    );
  }
}

class _ExerciseDetailSheet extends StatefulWidget {
  const _ExerciseDetailSheet({required this.exercise});

  final ExerciseTemplate exercise;

  @override
  State<_ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<_ExerciseDetailSheet> {
  bool _showGuide = false;

  Uri get _tutorialSearchUrl => Uri.https('www.youtube.com', '/results', {
        'search_query': '${widget.exercise.name} exercise tutorial form',
      });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    // Custom exercises can never appear in the compile-time `_byId` map
    // (see exercise_muscle_map.dart), so their fine-grained activation, if
    // any was configured, lives in CustomExercisesProvider instead --
    // falling back to the same category default any unrecognized id gets.
    final customActivation =
        context.watch<CustomExercisesProvider>().activationFor(widget.exercise.id);
    final activation =
        customActivation ?? muscleActivationForExercise(widget.exercise);
    final archetype = archetypeForExercise(widget.exercise);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailedBodyDiagram(
              activation: activation,
              size: 170,
              enableZoom: true,
            ),
            const SizedBox(height: 16),
            Text(widget.exercise.name,
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(categoryLabel(t, widget.exercise.category),
                style: TextStyle(color: colors.mut)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showGuide = !_showGuide),
                icon: Icon(
                    _showGuide
                        ? Icons.expand_less
                        : Icons.tips_and_updates_outlined,
                    size: 18),
                label: Text(t.actionExerciseGuide),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showGuide
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(exerciseGuideText(t, archetype)),
                            const SizedBox(height: 8),
                            Text(
                              t.captionExerciseGuide,
                              style:
                                  TextStyle(color: colors.mut, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(_tutorialSearchUrl,
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: Text(t.actionWatchTutorial),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
