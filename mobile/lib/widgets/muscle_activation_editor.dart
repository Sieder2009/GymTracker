import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/body_atlas.dart';
import '../l10n/app_localizations.dart';
import '../models/muscle_group.dart';
import '../state/athlete_settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'detailed_body_diagram.dart';

/// Opens the full front/back muscle-activation editor as a bottom sheet.
/// [initial] and the resolved result are both `MuscleGroup.name -> 0-100`
/// maps, matching [Exercise.muscleActivation]'s JSON shape directly — the
/// caller never has to convert. Returns null if dismissed without saving.
Future<Map<String, double>?> showMuscleActivationEditor(
  BuildContext context, {
  required Map<String, double> initial,
}) {
  return showModalBottomSheet<Map<String, double>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => MuscleActivationEditor(initial: initial),
  );
}

class MuscleActivationEditor extends StatefulWidget {
  const MuscleActivationEditor({super.key, required this.initial});
  final Map<String, double> initial;

  @override
  State<MuscleActivationEditor> createState() => _MuscleActivationEditorState();
}

class _MuscleActivationEditorState extends State<MuscleActivationEditor> {
  late Map<MuscleGroup, double> _activation;
  bool _front = true;
  MuscleGroup? _selected;

  @override
  void initState() {
    super.initState();
    _activation = {
      for (final entry in widget.initial.entries)
        if (muscleGroupFromKey(entry.key) != null)
          muscleGroupFromKey(entry.key)!: entry.value,
    };
  }

  void _toggle(MuscleGroup m) {
    setState(() {
      if (_activation.containsKey(m)) {
        _activation.remove(m);
        if (_selected == m) _selected = null;
      } else {
        _activation[m] = 50;
        _selected = m;
      }
    });
  }

  void _setIntensity(double v) {
    final selected = _selected;
    if (selected == null) return;
    setState(() => _activation[selected] = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final gender = isMale ? BodyGender.male : BodyGender.female;
    final muscles = _front ? kFrontMuscles : kBackMuscles;

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
                      child: Text(t.titleMuscleEditor,
                          style: Theme.of(context).textTheme.headlineLarge),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop({
                        for (final e in _activation.entries)
                          muscleGroupKey(e.key): e.value,
                      }),
                      child: Text(t.actionSave),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t.hintTapMuscle,
                    style: TextStyle(color: colors.mut, fontSize: 12.5)),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
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
                                  if (hit != null) _toggle(hit);
                                },
                                child: CustomPaint(
                                  size: size,
                                  painter: BodyDiagramPainter(
                                    front: _front,
                                    gender: gender,
                                    activation: _activation,
                                    selected: _selected,
                                    accent: colors.accent,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in muscles)
                              _MuscleChip(
                                label: muscleGroupLabel(t, m),
                                active: _activation.containsKey(m),
                                selected: _selected == m,
                                onTap: () {
                                  if (!_activation.containsKey(m)) {
                                    _toggle(m);
                                  } else {
                                    setState(() => _selected = m);
                                  }
                                },
                                onLongPress: () => _toggle(m),
                              ),
                          ],
                        ),
                        if (_selected != null) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.labelIntensity,
                                  style: TextStyle(color: colors.mut)),
                              Text(
                                '${(_activation[_selected!] ?? 0).round()}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: colors.txt),
                              ),
                            ],
                          ),
                          Slider(
                            value: _activation[_selected!] ?? 0,
                            min: 0,
                            max: 100,
                            divisions: 20,
                            onChanged: _setIntensity,
                          ),
                        ],
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

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({
    required this.label,
    required this.active,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool active;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final bg =
        selected ? colors.accent : (active ? colors.accentSoft : colors.card2);
    final fg = selected ? colors.onAccent : (active ? colors.accent : colors.txt);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
        child: Text(label,
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}
