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
import '../widgets/exercise_demo_gif.dart';
import '../widgets/exercise_list_view.dart';

/// "Übungen" tab: the full shared exercise database, searchable and
/// filterable by muscle group — tapping one shows a demo animation of how
/// it's performed (when one is mapped), exactly which muscles it trains and
/// how much (see [DetailedBodyDiagram], an original diagram, not a scraped
/// image), form tips, and a link to search for a video tutorial on YouTube.
///
/// The demo animations are third-party content (© Gym visual, distributed
/// through the open exercises dataset on GitHub — see
/// `data/exercise_gifs.dart`), so the app does not redistribute them: this
/// repo and every release build contain only the exercise-id → file-name
/// mapping, never an animation. Each one is downloaded at runtime from a
/// pinned public CDN copy of that dataset the first time it's shown, then
/// cached on the device (see `ExerciseMediaService`); it's credited
/// wherever it appears, and Settings can switch animations off entirely.
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
    // How it's done first, then what it trains -- the diagram stays as the
    // muscle breakdown the animation can't show. Null (no slot at all) for
    // custom exercises, unmapped ids, or animations switched off.
    final gif = resolveTemplateGif(context, widget.exercise);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gif != null) ...[
              ExerciseDemoGif(
                gif: gif,
                size: 200,
                exerciseName: widget.exercise.name,
              ),
              const SizedBox(height: 16),
            ],
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
