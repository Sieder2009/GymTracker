import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../models/day_overrides.dart';
import '../models/train_state.dart';
import '../services/storage_service.dart';

const String _kTrainStateKey = 'ironpeak:trainState';
// Deliberately its own top-level kv key, NOT nested inside [TrainState] --
// [selectPlan]/[clear] below replace `_state` wholesale, and
// training_screen.dart's `_maybeForcePlanPrompt` calls [selectPlan] on
// every app launch once 2+ plans exist. Nesting overrides inside
// [TrainState] would silently wipe them on nearly every relaunch for a
// multi-plan user.
const String _kDayOverridesKey = 'ironpeak:dayOverrides';

class TrainStateProvider extends ChangeNotifier {
  TrainStateProvider(this._storage)
      : _state = _initial(_storage),
        _overrides = _initialOverrides(_storage) {
    // pruneBefore inside _initialOverrides may have actually dropped stale
    // entries -- persist that once at load so they don't linger on disk
    // until the next override write happens to come along.
    _persistOverrides();
  }

  final StorageService _storage;
  TrainState _state;
  final DayOverrides _overrides;

  String? get activePlanId => _state.activePlanId;
  int get viewedDayIdx => _state.viewedDayIdx;

  static TrainState _initial(StorageService storage) {
    return storage.readJson<TrainState>(
          _kTrainStateKey,
          (raw) => TrainState.fromJson(raw as Map<String, dynamic>),
        ) ??
        TrainState();
  }

  static DayOverrides _initialOverrides(StorageService storage) {
    final overrides = storage.readJson<DayOverrides>(
          _kDayOverridesKey,
          DayOverrides.fromJson,
        ) ??
        DayOverrides();
    overrides.pruneBefore(todayIso());
    return overrides;
  }

  void _persist() => _storage.writeJson(_kTrainStateKey, () => _state.toJson());

  void _persistOverrides() =>
      _storage.writeJson(_kDayOverridesKey, () => _overrides.toJson());

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

  // --- Day overrides -----------------------------------------------------
  //
  // Personal scheduling metadata only -- never part of the plan definition
  // itself, so a plan stays exactly as shareable/importable as before (see
  // `services/plan_share_codec.dart`, which is untouched by this feature).

  int? dayOverride(String planId, String iso) => _overrides.get(planId, iso);

  void setDayOverride(String planId, String iso, int value) {
    _overrides.set(planId, iso, value);
    _persistAndPruneOverrides();
  }

  void clearDayOverride(String planId, String iso) {
    _overrides.clear(planId, iso);
    _persistAndPruneOverrides();
  }

  /// Writes the target date (gets the moved Day's index) AND the source
  /// date (`-1`, explicitly rest/skipped) together, in one persist+notify.
  /// A single-direction write (target only) would leave the source date
  /// still showing the very session the user just said they can't do --
  /// contradicting the whole point of "sick today, move Tuesday's leg day
  /// to Wednesday instead".
  void moveDayOverride(
    String planId, {
    required String sourceIso,
    required int dayIdx,
    required String targetIso,
  }) {
    _overrides.set(planId, targetIso, dayIdx);
    _overrides.set(planId, sourceIso, -1);
    _persistAndPruneOverrides();
  }

  void dropOverridesForPlan(String planId) {
    _overrides.dropPlan(planId);
    _persistAndPruneOverrides();
  }

  void _persistAndPruneOverrides() {
    _overrides.pruneBefore(todayIso());
    _persistOverrides();
    notifyListeners();
  }
}
