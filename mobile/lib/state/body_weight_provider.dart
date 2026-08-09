import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../models/body_weight_entry.dart';
import '../services/storage_service.dart';

const String _kBodyWeightKey = 'ironpeak:bodyWeight';

/// Bodyweight log — independent from the per-exercise weight tracked in
/// training plans, shown as its own small chart card at the top of the
/// "Kraft" tab. Same persisted-list pattern as [BigLiftsProvider]'s history.
class BodyWeightProvider extends ChangeNotifier {
  BodyWeightProvider(this._storage) : _entries = _initial(_storage);

  final StorageService _storage;
  List<BodyWeightEntry> _entries;

  List<BodyWeightEntry> get entries => List.unmodifiable(_entries);

  static List<BodyWeightEntry> _initial(StorageService storage) {
    final decoded = storage.readJson<List<BodyWeightEntry>>(
      _kBodyWeightKey,
      (raw) => (raw as List)
          .map((e) => BodyWeightEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return decoded ?? [];
  }

  void _persist() {
    _storage.writeJson(_kBodyWeightKey, () => _entries.map((e) => e.toJson()).toList());
  }

  void addEntry(double weight) {
    if (weight <= 0) return;
    _entries = [..._entries, BodyWeightEntry(date: todayIso(), weight: weight)];
    _persist();
    notifyListeners();
  }
}
