import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../models/body_measurement_entry.dart';
import '../services/storage_service.dart';

/// Body-circumference log (chest/waist/hips/arm/thigh/calf) — independent
/// from [BodyWeightProvider], shown as its own card on the Analyse
/// overview. Same "own table, not a growing JSON blob" storage shape as
/// body weight (see `body_measurement_entries` in [StorageService]).
class BodyMeasurementsProvider extends ChangeNotifier {
  BodyMeasurementsProvider(this._storage) : _entries = _initial(_storage);

  final StorageService _storage;
  List<BodyMeasurementEntry> _entries;

  List<BodyMeasurementEntry> get entries => List.unmodifiable(_entries);

  static List<BodyMeasurementEntry> _initial(StorageService storage) {
    return storage.bodyMeasurementEntries
        .map((row) => BodyMeasurementEntry(
              date: row['date'] as String,
              chestCm: (row['chestCm'] as num?)?.toDouble(),
              waistCm: (row['waistCm'] as num?)?.toDouble(),
              hipsCm: (row['hipsCm'] as num?)?.toDouble(),
              armCm: (row['armCm'] as num?)?.toDouble(),
              thighCm: (row['thighCm'] as num?)?.toDouble(),
              calfCm: (row['calfCm'] as num?)?.toDouble(),
            ))
        .toList();
  }

  /// Every field optional -- a user typically logs whichever subset they
  /// measured this time, not all six at once. No-op if every field is
  /// null (nothing was actually entered).
  void addEntry({
    double? chestCm,
    double? waistCm,
    double? hipsCm,
    double? armCm,
    double? thighCm,
    double? calfCm,
  }) {
    if (chestCm == null &&
        waistCm == null &&
        hipsCm == null &&
        armCm == null &&
        thighCm == null &&
        calfCm == null) {
      return;
    }
    final entry = BodyMeasurementEntry(
      date: todayIso(),
      chestCm: chestCm,
      waistCm: waistCm,
      hipsCm: hipsCm,
      armCm: armCm,
      thighCm: thighCm,
      calfCm: calfCm,
    );
    _entries = [..._entries, entry];
    _storage.insertBodyMeasurementEntry(entry.toJson());
    notifyListeners();
  }
}
