import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/body_atlas.dart';
import '../l10n/app_localizations.dart';
import '../models/body_measurement_entry.dart';
import '../state/athlete_settings_provider.dart';
import '../theme/app_colors.dart';
import 'body_shape_diagram_painter.dart';

/// Approximate, stylized "your shape" illustration -- driven by
/// [measurementScaleFactors] against the same illustrated body
/// [DetailedBodyDiagram] uses, front/back toggleable the same way. This is
/// explicitly NOT an anthropometrically accurate reconstruction (see
/// `body_measurement_analytics.dart`'s doc comment) -- just enough of a
/// visual nudge that logged growth shows up as a picture, not only numbers.
class BodyShapeDiagram extends StatefulWidget {
  const BodyShapeDiagram({
    super.key,
    required this.scaleFactors,
    this.size = 200,
  });

  final Map<BodyMeasurementField, double> scaleFactors;
  final double size;

  @override
  State<BodyShapeDiagram> createState() => _BodyShapeDiagramState();
}

class _BodyShapeDiagramState extends State<BodyShapeDiagram> {
  bool _front = true;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final isMale = context.watch<AthleteSettingsProvider>().isMale;
    final gender = isMale ? BodyGender.male : BodyGender.female;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(t.actionFront)),
            ButtonSegment(value: false, label: Text(t.actionBack)),
          ],
          selected: {_front},
          onSelectionChanged: (s) => setState(() => _front = s.first),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: widget.size,
          height: widget.size / kBodyDiagramAspect,
          child: CustomPaint(
            painter: BodyShapeOverlayPainter(
              front: _front,
              gender: gender,
              scaleFactors: widget.scaleFactors,
              tint: colors.accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.captionBodyShapeApprox,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.mut, fontSize: 11.5),
        ),
      ],
    );
  }
}
