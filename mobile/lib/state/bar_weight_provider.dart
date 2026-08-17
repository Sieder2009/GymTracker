import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

const String _kBarWeightKey = 'ironpeak:defaultBarWeightKg';
const double _kDefaultBarWeightKg = 20.0;

/// The persistent default barbell weight used to convert a "per side"
/// weight-entry value into the total stored on [ExerciseSet.w] (see
/// `data/weight_conversion.dart`). Distinct from the plate calculator
/// sheet's own bar-weight field, which is an ephemeral scratchpad default
/// and deliberately doesn't read or write app data.
class BarWeightProvider extends ChangeNotifier {
  BarWeightProvider(this._storage) : _barWeightKg = _initial(_storage);

  final StorageService _storage;
  double _barWeightKg;

  double get barWeightKg => _barWeightKg;

  static double _initial(StorageService storage) {
    final raw = storage.readString(_kBarWeightKey);
    return raw == null ? _kDefaultBarWeightKg : (double.tryParse(raw) ?? _kDefaultBarWeightKg);
  }

  void setBarWeightKg(double value) {
    if (value <= 0) return;
    _barWeightKg = value;
    _storage.writeString(_kBarWeightKey, value.toString());
    notifyListeners();
  }
}
