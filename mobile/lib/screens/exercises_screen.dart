import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/exercise_archetype.dart';
import '../data/exercise_gif_lookup.dart';
import '../data/exercise_guides.dart';
import '../data/exercise_muscle_map.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise_template.dart';
import '../models/muscle_group.dart';
import '../state/custom_exercises_provider.dart';
import '../state/exercise_media_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/app_shell.dart';
import '../widgets/detailed_body_diagram.dart';
import '../widgets/exercise_demo_gif.dart';
import '../widgets/exercise_list_view.dart';

/// "Übungen" tab: the full shared exercise database, searchable and
/// filterable by muscle group — tapping one shows exactly which muscles it
/// trains and how much (see [DetailedBodyDiagram], an original diagram, not
/// a scraped image), a demo animation of how it's performed (when one is
/// mapped), form tips, and a link to search for a video tutorial on YouTube.
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
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ExerciseDetailSheet(exercise: ex),
    );
  }
}

/// Name and category up top, then one card that first shows what the
/// exercise trains (diagram + one bar per muscle) and after a moment hands
/// over to how it's done (the demo animation, when there is one) -- two
/// tabs switch back and forth -- then one card with the form tips and the
/// tutorial video under them.
class _ExerciseDetailSheet extends StatefulWidget {
  const _ExerciseDetailSheet({required this.exercise});

  final ExerciseTemplate exercise;

  @override
  State<_ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<_ExerciseDetailSheet> {
  /// How long the muscles show before the demo animation takes their place.
  static const Duration _musclesFirst = Duration(seconds: 3);

  bool _showDemo = false;
  Timer? _autoSwitch;

  ExerciseTemplate get exercise => widget.exercise;

  Uri get _tutorialSearchUrl => Uri.https('www.youtube.com', '/results', {
        'search_query': '${exercise.name} exercise tutorial form',
      });

  @override
  void initState() {
    super.initState();
    final media = context.read<ExerciseMediaProvider>();
    final gif = exerciseGifForTemplate(exercise);
    if (!media.enabled || gif == null) return;
    // Fetched while the muscles show, so the animation is there -- no
    // spinner -- when it takes over (the web build loads it itself).
    if (!kIsWeb) media.service.loadGif(gif).ignore();
    _autoSwitch = Timer(_musclesFirst, () {
      if (mounted) setState(() => _showDemo = true);
    });
  }

  @override
  void dispose() {
    _autoSwitch?.cancel();
    super.dispose();
  }

  // Touching the card (a tab, the front/back toggle, the zoom) means the
  // user is looking at it: from then on it only changes when they say so.
  void _hold() => _autoSwitch?.cancel();

  void _select(bool demo) {
    _hold();
    setState(() => _showDemo = demo);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    // Custom exercises can never appear in the compile-time `_byId` map
    // (see exercise_muscle_map.dart), so their fine-grained activation, if
    // any was configured, lives in CustomExercisesProvider instead --
    // falling back to the same category default any unrecognized id gets.
    final customActivation =
        context.watch<CustomExercisesProvider>().activationFor(exercise.id);
    final activation = customActivation ?? muscleActivationForExercise(exercise);
    final shares = activationShares(activation);
    final muscles = shares.keys.toList()
      ..sort((a, b) => shares[b]!.compareTo(shares[a]!));
    final archetype = archetypeForExercise(exercise);
    // Null for custom exercises, unmapped ids, or animations switched off
    // -- then the card only ever shows the muscles.
    final gif = resolveTemplateGif(context, exercise);
    final demoGif = _showDemo ? gif : null;
    final showDemo = demoGif != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(
                label: categoryLabel(t, exercise.category),
                color: colors.accent,
                background: colors.accent.withValues(alpha: 0.12),
              ),
              if (exercise.id.startsWith('custom:'))
                _Tag(label: t.labelCustomExercise, color: colors.mut, background: colors.card2),
            ],
          ),
          const SizedBox(height: 20),
          Listener(
            onPointerDown: (_) => _hold(),
            child: _Section(
              title: t.titleMuscleEditor,
              // No animation (custom exercise, unmapped, switched off):
              // just the muscles, no tabs.
              header: gif == null
                  ? null
                  : Row(
                      children: [
                        _HeaderTab(
                          label: t.titleMuscleEditor,
                          selected: !showDemo,
                          onTap: () => _select(false),
                        ),
                        const SizedBox(width: 18),
                        _HeaderTab(
                          label: t.exerciseDemoTitle,
                          selected: showDemo,
                          onTap: () => _select(true),
                        ),
                      ],
                    ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  child: demoGif != null
                      ? LayoutBuilder(
                          key: const ValueKey('demo'),
                          // Borderless: the card around it is the frame. The
                          // "© Gym visual" credit inside has to stay visible.
                          builder: (context, constraints) => Center(
                            child: ExerciseDemoGif(
                              gif: demoGif,
                              size: math.min(260, constraints.maxWidth),
                              exerciseName: exercise.name,
                              bordered: false,
                            ),
                          ),
                        )
                      : Column(
                          key: const ValueKey('muscles'),
                          children: [
                            DetailedBodyDiagram(
                              activation: activation,
                              size: 150,
                              enableZoom: true,
                              showLegend: false,
                            ),
                            if (muscles.isNotEmpty) const SizedBox(height: 16),
                            for (final muscle in muscles)
                              _MuscleBar(
                                label: muscleGroupLabel(t, muscle),
                                share: shares[muscle]!,
                                intensity: activation[muscle]!,
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // How to do it, as one card: a "?" badge with the heading top
          // left, the tips, and the tutorial video right under them.
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.question_mark_rounded, size: 18, color: colors.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.actionExerciseGuide,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(exerciseGuideText(t, archetype), style: const TextStyle(height: 1.4)),
                const SizedBox(height: 8),
                Text(t.captionExerciseGuide, style: TextStyle(color: colors.mut, fontSize: 11)),
                const SizedBox(height: 14),
                _VideoLink(
                  label: t.actionWatchTutorial,
                  onTap: () =>
                      launchUrl(_tutorialSearchUrl, mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label + card, the sheet's building block. [header] replaces the
/// plain label (the muscles/demo card puts its tabs there); with neither,
/// the card carries its own heading.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.title, this.header});

  final String? title;
  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final title = this.title;
    final label = header ??
        (title == null
            ? null
            : Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: label,
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: colors.line),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// The tutorial video under the form tips -- opens a YouTube search, so it
/// reads as a link out (play badge, external-link arrow), not as a button.
class _VideoLink extends StatelessWidget {
  const _VideoLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Material(
      color: colors.card2,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: colors.onAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 14.5),
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 18, color: colors.mut),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the muscles/demo card's two tabs: the section label's look,
/// muted until selected, with a short accent bar under the selected one.
class _HeaderTab extends StatelessWidget {
  const _HeaderTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        selected: selected,
        button: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall!
                  .copyWith(color: selected ? colors.txt : colors.mut),
              child: Text(label.toUpperCase()),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: selected ? 18 : 0,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// One muscle's share of the work ([share] percent, all bars together make
/// 100), colored by how hard it works ([intensity], 0-100) in the diagram's
/// own heat colors.
class _MuscleBar extends StatelessWidget {
  const _MuscleBar({required this.label, required this.share, required this.intensity});

  final String label;
  final int share;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              Text(
                '$share%',
                style: TextStyle(color: colors.mut, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              height: 6,
              color: colors.card2,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: share / 100,
                heightFactor: 1,
                child: ColoredBox(color: activationColor(intensity)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
