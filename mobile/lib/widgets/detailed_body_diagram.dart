import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/body_atlas.dart';
import '../l10n/app_localizations.dart';
import '../models/muscle_group.dart';
import '../state/athlete_settings_provider.dart';
import '../theme/app_colors.dart';

export '../data/body_atlas.dart' show BodyGender, kBodyDiagramAspect;

/// 0-100 activation -> white (unworked) through light red to dark red
/// (worked hardest) -- a fixed heat scale independent of the app's accent
/// color, matching how dedicated muscle-map tools show intensity. White is
/// used even for muscle groups absent from [activation] entirely so the
/// full silhouette always reads as an anatomy reference, not just the
/// muscles a given exercise happens to train.
Color activationColor(double value) {
  const white = Color(0xFFEDEFF2);
  const lightRed = Color(0xFFFF8A80);
  const darkRed = Color(0xFF9A1212);
  final v = (value / 100).clamp(0.0, 1.0);
  if (v <= 0) return white;
  if (v < 0.5) return Color.lerp(white, lightRed, v / 0.5)!;
  return Color.lerp(lightRed, darkRed, (v - 0.5) / 0.5)!;
}

/// Fixed, theme-independent body-silhouette colors. Deliberately NOT
/// sourced from [AppColors]'s card/line tokens -- those are tuned for
/// subtle card backgrounds and nearly disappear against the page in light
/// mode, far too low-contrast for a detailed illustration with fine
/// linework that needs to read clearly in both themes.
const Color _kSilhouetteBase = Color(0xFFC9CDD3);
const Color _kSilhouetteOutline = Color(0xFF5B5F66);

/// Draws the full illustrated body (see [ParsedBodyAtlas]) plus every
/// muscle region in [activation], colored by intensity -- shared by the
/// read-only [DetailedBodyDiagram] and the tappable `MuscleActivationEditor`.
class BodyDiagramPainter extends CustomPainter {
  BodyDiagramPainter({
    required this.front,
    required this.gender,
    required this.activation,
    required this.accent,
    this.selected,
  });

  final bool front;
  final BodyGender gender;
  final Map<MuscleGroup, double> activation;
  final MuscleGroup? selected;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final atlas = ParsedBodyAtlas.get(gender, front, size);
    final fillPaint = Paint()..color = _kSilhouetteBase;
    final outlinePaint = Paint()
      ..color = _kSilhouetteOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.005;

    for (final part in atlas.silhouette) {
      canvas.drawPath(part, fillPaint);
      canvas.drawPath(part, outlinePaint);
    }

    for (final entry in atlas.musclesOutline.entries) {
      // A coarse-tagged exercise (the ~1300 hand-tagged entries in
      // exercise_muscle_map.dart all are) has no value for a head-level
      // key like tricepsLongHead -- since triceps/biceps/chest/quads no
      // longer exist as their own atlas keys once split into heads, this
      // falls back to the parent's value so every one of those exercises
      // still paints its heads uniformly, instead of silently painting
      // nothing.
      final value = activation[entry.key] ??
          activation[muscleGroupParent(entry.key)];
      final isSelected = selected == entry.key;
      final color = activationColor(value ?? 0);
      // One bold fill + one outer stroke per muscle group (not per
      // sub-shape) -- reads as a clean solid region instead of a seam
      // between every ab block/quad head that happens to share a color,
      // closer to how dedicated muscle-map apps present intensity.
      canvas.drawPath(entry.value, Paint()..color = color);
      canvas.drawPath(
        entry.value,
        Paint()
          ..color =
              isSelected ? accent : _kSilhouetteOutline.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * (isSelected ? 0.009 : 0.0035),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BodyDiagramPainter old) {
    return old.front != front ||
        old.gender != gender ||
        old.activation != activation ||
        old.selected != selected ||
        old.accent != accent;
  }
}

/// Read-only front/back-toggleable body diagram + a text legend of every
/// involved muscle sorted by intensity -- used to show exactly which
/// muscles an exercise trains and how much, for every exercise in the
/// shared database (not just the 7 broad categories). The illustrated
/// body matches the athlete's own gender setting (`AthleteSettingsProvider`,
/// the same one used for the DOTS score) rather than a separate toggle.
class DetailedBodyDiagram extends StatefulWidget {
  const DetailedBodyDiagram({
    super.key,
    required this.activation,
    this.size = 220,
    this.enableZoom = false,
  });

  /// [MuscleGroup] -> 0-100 intensity.
  final Map<MuscleGroup, double> activation;
  final double size;

  /// Whether tapping the diagram opens a full-screen, pinch-zoomable view --
  /// worth it once the diagram is illustrated in enough detail that a
  /// thumbnail-sized card can't show it all (small phone screens especially).
  final bool enableZoom;

  @override
  State<DetailedBodyDiagram> createState() => _DetailedBodyDiagramState();
}

class _DetailedBodyDiagramState extends State<DetailedBodyDiagram> {
  late bool _front;

  @override
  void initState() {
    super.initState();
    _front = _totalFor(true) >= _totalFor(false);
  }

  double _totalFor(bool front) {
    var sum = 0.0;
    for (final m in front ? kFrontMuscles : kBackMuscles) {
      sum += widget.activation[m] ?? 0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final gender = isMale ? BodyGender.male : BodyGender.female;
    final sorted = widget.activation.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_totalFor(true) > 0 && _totalFor(false) > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(t.actionFront)),
                ButtonSegment(value: false, label: Text(t.actionBack)),
              ],
              selected: {_front},
              onSelectionChanged: (s) => setState(() => _front = s.first),
            ),
          ),
        GestureDetector(
          onTap: widget.enableZoom
              ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (context) => _ZoomedBodyDiagram(
                      activation: widget.activation,
                      initialFront: _front,
                      gender: gender,
                    ),
                  ))
              : null,
          // Swipe left/right as an alternative to the segmented-button
          // toggle -- only meaningful once both views actually have
          // something to show (mirrors when the toggle itself renders).
          onHorizontalDragEnd: (_totalFor(true) > 0 && _totalFor(false) > 0)
              ? (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < 150) return;
                  final wantFront = velocity > 0;
                  if (wantFront != _front) setState(() => _front = wantFront);
                }
              : null,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: SizedBox(
                  key: ValueKey(_front),
                  width: widget.size,
                  height: widget.size / kBodyDiagramAspect,
                  child: CustomPaint(
                    painter: BodyDiagramPainter(
                      front: _front,
                      gender: gender,
                      activation: widget.activation,
                      accent: colors.accent,
                    ),
                  ),
                ),
              ),
              if (widget.enableZoom)
                Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: colors.card2, shape: BoxShape.circle),
                  child: Icon(Icons.zoom_in, size: 16, color: colors.mut),
                ),
            ],
          ),
        ),
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final entry in sorted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.card2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${muscleGroupLabel(t, entry.key)} · ${entry.value.round()}%',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.txt),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Full-screen pinch-zoom-pan presentation of the same diagram, opened by
/// tapping a [DetailedBodyDiagram] built with `enableZoom: true`. Keeps its
/// own front/back toggle so exploring the illustration here never mutates
/// the small card that opened it. Tapping a muscle here (not on the small
/// card, where a tap already means "open this view") selects it via the
/// same [ParsedBodyAtlas.hitTest] the tappable `MuscleActivationEditor`
/// uses, and shows its name + activation -- "detailliert alles zeigen" for
/// heads/regions too fine to label individually in the legend below the
/// small card.
class _ZoomedBodyDiagram extends StatefulWidget {
  const _ZoomedBodyDiagram({
    required this.activation,
    required this.initialFront,
    required this.gender,
  });

  final Map<MuscleGroup, double> activation;
  final bool initialFront;
  final BodyGender gender;

  @override
  State<_ZoomedBodyDiagram> createState() => _ZoomedBodyDiagramState();
}

class _ZoomedBodyDiagramState extends State<_ZoomedBodyDiagram> {
  late bool _front = widget.initialFront;
  MuscleGroup? _selected;

  void _handleTap(TapUpDetails details, Size diagramSize) {
    final hit = ParsedBodyAtlas.get(widget.gender, _front, diagramSize)
        .hitTest(details.localPosition);
    setState(() => _selected = (hit == null || hit == _selected) ? null : hit);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final width = MediaQuery.of(context).size.width * 0.85;
    final diagramSize = Size(width, width / kBodyDiagramAspect);
    final selected = _selected;
    // A coarse-tagged exercise has no entry for a head-level key -- same
    // parent fallback [BodyDiagramPainter] already applies when coloring
    // the region itself, so the label always matches what's on screen.
    final selectedValue = selected == null
        ? null
        : widget.activation[selected] ??
            widget.activation[muscleGroupParent(selected)] ??
            0;
    return Scaffold(
      appBar: AppBar(
        title: SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(t.actionFront)),
            ButtonSegment(value: false, label: Text(t.actionBack)),
          ],
          selected: {_front},
          onSelectionChanged: (s) => setState(() {
            _front = s.first;
            _selected = null;
          }),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    child: GestureDetector(
                      key: ValueKey(_front),
                      onTapUp: (details) => _handleTap(details, diagramSize),
                      child: SizedBox(
                        width: diagramSize.width,
                        height: diagramSize.height,
                        child: CustomPaint(
                          painter: BodyDiagramPainter(
                            front: _front,
                            gender: widget.gender,
                            activation: widget.activation,
                            selected: _selected,
                            accent: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: selected == null
                  ? const SizedBox(height: 48)
                  : Padding(
                      key: ValueKey(selected),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        '${muscleGroupLabel(t, selected)} · ${selectedValue!.round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: colors.txt,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
