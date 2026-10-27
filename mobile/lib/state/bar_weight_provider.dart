import 'package:flutter/foundation.dart';

import '../data/plate_calculator.dart';
import '../services/storage_service.dart';

const String _kBarWeightKey = 'ironpeak:defaultBarWeightKg';
const String _kPlatesKgKey = 'ironpeak:availablePlatesKg';
const String _kPlatesLbKey = 'ironpeak:availablePlatesLb';
const double _kDefaultBarWeightKg = 20.0;

/// The persistent default barbell weight used to convert a "per side"
/// weight-entry value into the total stored on [ExerciseSet.w] (see
/// `data/weight_conversion.dart`), plus which plates the user's gym has.
/// The plate calculator starts its empty-weight field from the bar weight
/// and remembers its plate toggles here; the field itself stays a
/// scratchpad that never writes back.
class BarWeightProvider extends ChangeNotifier {
  BarWeightProvider(this._storage)
      : _barWeightKg = _initial(_storage),
        _platesKg = _readPlates(_storage, _kPlatesKgKey, kStandardPlatesKg),
        _platesLb = _readPlates(_storage, _kPlatesLbKey, kStandardPlatesLb);

  final StorageService _storage;
  double _barWeightKg;
  List<double> _platesKg;
  List<double> _platesLb;

  double get barWeightKg => _barWeightKg;

  /// The plates switched on for the kg or the lb set, largest first --
  /// every standard plate until the user turns some off.
  List<double> availablePlates({required bool kg}) => List.unmodifiable(kg ? _platesKg : _platesLb);

  static double _initial(StorageService storage) {
    final raw = storage.readString(_kBarWeightKey);
    return raw == null ? _kDefaultBarWeightKg : (double.tryParse(raw) ?? _kDefaultBarWeightKg);
  }

  /// Only plates of the standard set count, so a stale or hand-edited
  /// value can't add a plate the calculator has no toggle for.
  static List<double> _readPlates(StorageService storage, String key, List<double> standard) {
    final raw = storage.readString(key);
    if (raw == null) return [...standard];
    final stored = {for (final part in raw.split(',')) double.tryParse(part)};
    final plates = [for (final plate in standard) if (stored.contains(plate)) plate];
    return plates.isEmpty ? [...standard] : plates;
  }

  void setBarWeightKg(double value) {
    if (value <= 0) return;
    _barWeightKg = value;
    _storage.writeString(_kBarWeightKey, value.toString());
    notifyListeners();
  }

  /// Switches [plate] on or off in the kg or lb set. The last plate left
  /// can't be switched off -- with none at all there is nothing to load.
  void setPlateAvailable(double plate, {required bool kg, required bool available}) {
    final standard = kg ? kStandardPlatesKg : kStandardPlatesLb;
    final current = kg ? _platesKg : _platesLb;
    if (!standard.contains(plate) || current.contains(plate) == available) return;
    if (!available && current.length == 1) return;
    final next = [
      for (final p in standard)
        if (p == plate ? available : current.contains(p)) p,
    ];
    if (kg) {
      _platesKg = next;
    } else {
      _platesLb = next;
    }
    _storage.writeString(kg ? _kPlatesKgKey : _kPlatesLbKey, next.join(','));
    notifyListeners();
  }
}
