import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

const String _kIsMaleKey = 'ironpeak:athleteIsMale';

/// The one athlete-specific setting the app needs: which DOTS coefficient
/// table to use for the powerlifting score (see data/dots_score.dart).
/// Nothing else in the app reads or displays this.
class AthleteSettingsProvider extends ChangeNotifier {
  AthleteSettingsProvider(this._storage) : _isMale = _initial(_storage);

  final StorageService _storage;
  bool _isMale;

  bool get isMale => _isMale;

  static bool _initial(StorageService storage) {
    return storage.readString(_kIsMaleKey) != 'false';
  }

  void setIsMale(bool value) {
    _isMale = value;
    _storage.writeString(_kIsMaleKey, value.toString());
    notifyListeners();
  }
}
