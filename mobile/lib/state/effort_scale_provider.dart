import 'package:flutter/foundation.dart';

import '../data/effort_scale.dart';
import '../services/storage_service.dart';

const String _kEffortScaleKey = 'ironpeak:effortScale';

/// The one global preference that decides which scale the guided workout's
/// per-set effort chip row collects for newly-logged sets (RPE or RIR --
/// see `data/effort_scale.dart`). Switching it never rewrites or
/// reinterprets any already-saved set: each [ExerciseSet] remembers which
/// scale its own logged value used via its own field, so an old RPE-only
/// backup keeps reading back as RPE forever regardless of this setting.
class EffortScaleProvider extends ChangeNotifier {
  EffortScaleProvider(this._storage)
      : _scale = effortScaleFromStorage(_storage.readString(_kEffortScaleKey));

  final StorageService _storage;
  EffortScale _scale;

  EffortScale get scale => _scale;

  void setScale(EffortScale value) {
    _scale = value;
    _storage.writeString(_kEffortScaleKey, value.storageValue);
    notifyListeners();
  }
}
