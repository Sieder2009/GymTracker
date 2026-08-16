import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../models/body_weight_entry.dart';
import '../services/storage_service.dart';

/// Bodyweight log — independent from the per-exercise weight tracked in
/// training plans, shown as its own small chart card at the top of the
/// "Kraft" tab.
///
/// Backed by StorageService's `body_weight_entries` table — one row per
/// weigh-in, added with a single INSERT — rather than a single growing
/// JSON blob rewritten in full on every new entry.
class BodyWeightProvider extends ChangeNotifier {
  BodyWeightProvider(this._storage) : _entries = _initial(_storage);

  final StorageService _storage;
  List<BodyWeightEntry> _entries;

  List<BodyWeightEntry> get entries => List.unmodifiable(_entries);

  static List<BodyWeightEntry> _initial(StorageService storage) {
    return storage.bodyWeightEntries
        .map((row) => BodyWeightEntry(date: row['date'] as String, weight: (row['weight'] as num).toDouble()))
        .toList();
  }

  void addEntry(double weight) {
    if (weight <= 0) return;
    final entry = BodyWeightEntry(date: todayIso(), weight: weight);
    _entries = [..._entries, entry];
    _storage.insertBodyWeightEntry(entry.toJson());
    notifyListeners();
  }
}
