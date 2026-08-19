import 'package:flutter/material.dart';

import '../data/body_atlas.dart';
import '../models/body_measurement_entry.dart';
import '../models/muscle_group.dart';

/// Which [MuscleGroup] region(s) approximate each measurement point.
/// Lists both the coarse group and every finer sub-region it might be
/// split into (see `body_atlas.dart`'s triceps/biceps/chest/quad splits) --
/// at any given time [ParsedBodyAtlas.musclesOutline] only ever actually
/// contains one "family" (either the coarse key or its head-level
/// children) for a given muscle, so listing every possibility here and
/// unioning whichever ones exist keeps this file correct either way,
/// without needing to know which split is in effect.
const Map<BodyMeasurementField, List<MuscleGroup>> _kFieldRegions = {
  BodyMeasurementField.chest: [
    MuscleGroup.chest,
    MuscleGroup.chestUpper,
    MuscleGroup.chestMid,
    MuscleGroup.chestLower,
  ],
  BodyMeasurementField.waist: [MuscleGroup.abs, MuscleGroup.obliques],
  BodyMeasurementField.hips: [MuscleGroup.glutes],
  BodyMeasurementField.arm: [
    MuscleGroup.biceps,
    MuscleGroup.bicepsLongHead,
    MuscleGroup.bicepsShortHead,
    MuscleGroup.triceps,
    MuscleGroup.tricepsLongHead,
    MuscleGroup.tricepsLateralHead,
    MuscleGroup.tricepsMedialHead,
  ],
  BodyMeasurementField.thigh: [
    MuscleGroup.quads,
    MuscleGroup.quadRectusFemoris,
    MuscleGroup.quadVastusLateralis,
    MuscleGroup.quadVastusMedialis,
    MuscleGroup.hamstrings,
  ],
  BodyMeasurementField.calf: [MuscleGroup.calves],
};

Path? _unionRegion(ParsedBodyAtlas atlas, BodyMeasurementField field) {
  final groups = _kFieldRegions[field] ?? const [];
  Path? union;
  for (final g in groups) {
    final path = atlas.musclesOutline[g];
    if (path == null) continue;
    union = union == null ? path : Path.combine(PathOperation.union, union, path);
  }
  return union;
}

/// Draws the normal neutral silhouette, then locally rescales just the
/// muscle-overlay regions in [scaleFactors] around their own bounding-box
/// center -- deliberately never touches the silhouette itself, which is
/// what keeps this seam-free (a rescaled overlay can only ever shrink
/// inside or spill slightly past its own region, never tear away from a
/// silhouette edge it was never welded to in the first place).
class BodyShapeOverlayPainter extends CustomPainter {
  BodyShapeOverlayPainter({
    required this.front,
    required this.gender,
    required this.scaleFactors,
    required this.tint,
  });

  final bool front;
  final BodyGender gender;
  final Map<BodyMeasurementField, double> scaleFactors;
  final Color tint;

  static const Color _kSilhouetteBase = Color(0xFFC9CDD3);
  static const Color _kSilhouetteOutline = Color(0xFF5B5F66);

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

    final overlayFill = Paint()..color = tint.withValues(alpha: 0.55);
    final overlayStroke = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.006;

    for (final entry in scaleFactors.entries) {
      final region = _unionRegion(atlas, entry.key);
      if (region == null) continue;
      final bounds = region.getBounds();
      final ratio = entry.value;
      canvas.save();
      canvas.translate(bounds.center.dx, bounds.center.dy);
      canvas.scale(ratio, ratio);
      canvas.translate(-bounds.center.dx, -bounds.center.dy);
      canvas.drawPath(region, overlayFill);
      canvas.drawPath(region, overlayStroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant BodyShapeOverlayPainter old) {
    return old.front != front ||
        old.gender != gender ||
        old.scaleFactors != scaleFactors ||
        old.tint != tint;
  }
}
