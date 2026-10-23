import '../models/body_measurement_entry.dart';

/// Per measurement field, the first and the latest value ever logged --
/// what the measurements radar compares. Entries are sparse (a user logs
/// whichever fields they measured that day), so each field is looked up on
/// its own: "latest" is the newest entry that HAS that field, not simply the
/// newest entry. [entries] is in logging order, oldest first (as
/// BodyMeasurementsProvider keeps it). Fields never logged are left out;
/// a field logged once has the same first and latest value.
Map<BodyMeasurementField, ({double first, double latest})> measurementSpans(
  List<BodyMeasurementEntry> entries,
) {
  final spans = <BodyMeasurementField, ({double first, double latest})>{};
  for (final field in BodyMeasurementField.values) {
    double? first;
    double? latest;
    for (final entry in entries) {
      final value = bodyMeasurementFieldValue(entry, field);
      if (value == null) continue;
      first ??= value;
      latest = value;
    }
    if (first != null && latest != null) spans[field] = (first: first, latest: latest);
  }
  return spans;
}
