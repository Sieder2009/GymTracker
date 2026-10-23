import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/body_atlas.dart';
import '../l10n/app_localizations.dart';
import '../models/muscle_group.dart';
import '../state/athlete_settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

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

/// Each muscle's share of the whole exercise's work, in whole percent that
/// add up to exactly 100 (largest remainder). The activation values
/// themselves are 0-100 intensities per muscle -- shown side by side as
/// percentages they add up to nonsense like 180 %, so every label shows
/// this instead. Muscles at 0 are left out; nothing worked -> empty.
Map<MuscleGroup, int> activationShares(Map<MuscleGroup, double> activation) {
  final worked = {
    for (final MapEntry(key: m, value: v) in activation.entries)
      if (v > 0) m: v,
  };
  final total = worked.values.fold(0.0, (sum, v) => sum + v);
  if (total <= 0) return {};
  final exact = {for (final MapEntry(key: m, value: v) in worked.entries) m: v * 100 / total};
  final shares = {for (final MapEntry(key: m, value: v) in exact.entries) m: v.floor()};
  var left = 100 - shares.values.fold(0, (sum, v) => sum + v);
  // The points rounding lost go to the biggest remainders; ties to the
  // harder-worked muscle, then a fixed order, so labels never flicker.
  final byRemainder = exact.keys.toList()
    ..sort((a, b) {
      final byRest = (exact[b]! - shares[b]!).compareTo(exact[a]! - shares[a]!);
      if (byRest != 0) return byRest;
      final byValue = worked[b]!.compareTo(worked[a]!);
      return byValue != 0 ? byValue : a.index.compareTo(b.index);
    });
  for (final m in byRemainder) {
    if (left <= 0) break;
    shares[m] = shares[m]! + 1;
    left--;
  }
  return shares;
}

double _activationTotal(Map<MuscleGroup, double> activation, bool front) {
  var sum = 0.0;
  for (final m in front ? kFrontMuscles : kBackMuscles) {
    sum += activation[m] ?? 0;
  }
  return sum;
}

/// Whether [activation] is better shown from the front -- the view a
/// diagram or thumbnail opens on: the side of the hardest-worked muscle
/// (squats: the quads, even though glutes + hamstrings + lower back add up
/// to more). The totals only break a tie, and a full tie goes front.
bool preferFrontView(Map<MuscleGroup, double> activation) {
  double peak(bool front) => (front ? kFrontMuscles : kBackMuscles)
      .fold(0.0, (top, m) => math.max(top, activation[m] ?? 0));
  final front = peak(true);
  final back = peak(false);
  if (front != back) return front > back;
  return _activationTotal(activation, true) >= _activationTotal(activation, false);
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
    this.showLegend = true,
  });

  /// [MuscleGroup] -> 0-100 intensity.
  final Map<MuscleGroup, double> activation;
  final double size;

  /// Whether tapping the diagram opens a full-screen, pinch-zoomable view --
  /// worth it once the diagram is illustrated in enough detail that a
  /// thumbnail-sized card can't show it all (small phone screens especially).
  final bool enableZoom;

  /// The pill legend under the figure; off where the caller lists the
  /// muscles itself (the Exercises tab's detail sheet shows bars instead).
  final bool showLegend;

  @override
  State<DetailedBodyDiagram> createState() => _DetailedBodyDiagramState();
}

class _DetailedBodyDiagramState extends State<DetailedBodyDiagram> {
  late bool _front;

  @override
  void initState() {
    super.initState();
    _front = preferFrontView(widget.activation);
  }

  double _totalFor(bool front) => _activationTotal(widget.activation, front);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final gender = isMale ? BodyGender.male : BodyGender.female;
    final shares = activationShares(widget.activation);
    final sorted = shares.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

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
        if (widget.showLegend && sorted.isNotEmpty) ...[
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
                    '${muscleGroupLabel(t, entry.key)} · ${entry.value}%',
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

const Set<MuscleGroup> _kLowerBody = {
  MuscleGroup.quads,
  MuscleGroup.hamstrings,
  MuscleGroup.calves,
  MuscleGroup.glutes,
};

/// A list-row-sized preview of what an exercise trains: the same painted
/// body, but only the half that does the work -- shoulders to hips, or hips
/// to feet -- from the side [preferFrontView] picks, filling a square
/// [size] tile. Half the figure is exactly square (the atlas is 1:2), and at
/// list size the whole body would shrink the muscles to specks.
class MuscleThumbnail extends StatelessWidget {
  const MuscleThumbnail({super.key, required this.activation, this.size = 52});

  final Map<MuscleGroup, double> activation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isMale = context.select<AthleteSettingsProvider, bool>((s) => s.isMale);
    var lower = 0.0;
    var total = 0.0;
    for (final MapEntry(key: m, value: v) in activation.entries) {
      total += v;
      if (_kLowerBody.contains(muscleGroupParent(m) ?? m)) lower += v;
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: ColoredBox(
          color: colors.card2,
          child: CustomPaint(
            size: Size.square(size),
            painter: _HalfBodyPainter(
              body: BodyDiagramPainter(
                front: preferFrontView(activation),
                gender: isMale ? BodyGender.male : BodyGender.female,
                activation: activation,
                accent: colors.accent,
              ),
              lowerHalf: total > 0 && lower * 2 >= total,
            ),
          ),
        ),
      ),
    );
  }
}

class _HalfBodyPainter extends CustomPainter {
  _HalfBodyPainter({required this.body, required this.lowerHalf});

  final BodyDiagramPainter body;
  final bool lowerHalf;

  @override
  void paint(Canvas canvas, Size size) {
    // One fixed figure size per tile size, so ParsedBodyAtlas parses it
    // once for the whole list.
    final figure = Size(size.width, size.width / kBodyDiagramAspect);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (lowerHalf) canvas.translate(0, size.height - figure.height);
    body.paint(canvas, figure);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HalfBodyPainter old) =>
      old.lowerHalf != lowerHalf || body.shouldRepaint(old.body);
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
    // Shown as its share of the work, like every other label.
    final shares = activationShares(widget.activation);
    final selectedValue = selected == null
        ? null
        : shares[selected] ?? shares[muscleGroupParent(selected)] ?? 0;
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
                        '${muscleGroupLabel(t, selected)} · $selectedValue%',
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
