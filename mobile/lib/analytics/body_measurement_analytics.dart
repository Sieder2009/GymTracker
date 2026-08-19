import '../models/body_measurement_entry.dart';

/// For each measurement field with at least 2 logged (non-null) values,
/// the ratio of the latest reading to the user's own first-ever reading --
/// a *relative growth* indicator against their own baseline, not an
/// absolute anthropometric measurement. Clamped to ±15%: the illustrated
/// body has no per-limb rig, so [BodyShapeDiagram] can only nudge existing
/// muscle-overlay regions, not truly reshape the figure -- a modest,
/// visually-plausible range keeps that nudge from ever looking broken.
/// Fields with fewer than 2 data points are omitted (nothing to compare).
Map<BodyMeasurementField, double> measurementScaleFactors(
  List<BodyMeasurementEntry> entries,
) {
  final result = <BodyMeasurementField, double>{};
  for (final field in BodyMeasurementField.values) {
    double? baseline;
    double? latest;
    for (final e in entries) {
      final v = bodyMeasurementFieldValue(e, field);
      if (v == null) continue;
      baseline ??= v;
      latest = v;
    }
    if (baseline == null || latest == null || baseline == latest) continue;
    final ratio = (latest / baseline).clamp(0.85, 1.15);
    result[field] = ratio;
  }
  return result;
}
