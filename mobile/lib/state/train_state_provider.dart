import 'package:flutter/foundation.dart';

import '../models/train_state.dart';
import '../services/storage_service.dart';

const String _kTrainStateKey = 'ironpeak:trainState';

class TrainStateProvider extends ChangeNotifier {
  TrainStateProvider(this._storage) : _state = _initial(_storage);

  final StorageService _storage;
  TrainState _state;

  String? get activePlanId => _state.activePlanId;
  int get viewedDayIdx => _state.viewedDayIdx;

  static TrainState _initial(StorageService storage) {
    return storage.readJson<TrainState>(
          _kTrainStateKey,
          (raw) => TrainState.fromJson(raw as Map<String, dynamic>),
        ) ??
        TrainState();
  }

  void _persist() => _storage.writeJson(_kTrainStateKey, () => _state.toJson());

  void selectPlan(String planId, {required int viewedDayIdx}) {
    _state = TrainState(activePlanId: planId, viewedDayIdx: viewedDayIdx);
    _persist();
    notifyListeners();
  }

  void setViewedDayIdx(int idx) {
    _state.viewedDayIdx = idx;
    _persist();
    notifyListeners();
  }

  /// No plan selected — used after deleting the last remaining plan.
  void clear() {
    _state = TrainState();
    _persist();
    notifyListeners();
  }
}
