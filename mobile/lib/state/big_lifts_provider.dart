import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../models/big_lift.dart';
import '../services/storage_service.dart';

const String _kBigLiftsKey = 'ironpeak:bigLifts';

class BigLiftsProvider extends ChangeNotifier {
  BigLiftsProvider(this._storage) : _lifts = _initial(_storage);

  final StorageService _storage;
  BigLifts _lifts;

  BigLifts get lifts => _lifts;

  static BigLifts _initial(StorageService storage) {
    return storage.readJson<BigLifts>(
          _kBigLiftsKey,
          (raw) => BigLifts.fromJson(raw as Map<String, dynamic>),
        ) ??
        BigLifts();
  }

  void _persist() => _storage.writeJson(_kBigLiftsKey, () => _lifts.toJson());

  /// Overwrites `pr` only — never touches `prDate`, which is a manual-entry
  /// field the app never auto-dates.
  void savePr(String key, double value) {
    if (value <= 0) return;
    _lifts.byKey(key).pr = value;
    _persist();
    notifyListeners();
  }

  /// Bumps `pr` *and* `prDate` together, but only when [value] actually
  /// beats the current PR — unlike [savePr] (a manual-entry field that
  /// deliberately never auto-dates), this is the auto-detected path: the
  /// guided workout calls it after logging a set, so a bench/deadlift/squat
  /// PR set mid-session shows up here with a real date, not just silently
  /// overwriting whatever was there before.
  void bumpPrIfHigher(String key, double value, String date) {
    if (value <= 0) return;
    final lift = _lifts.byKey(key);
    if (value <= lift.pr) return;
    lift.pr = value;
    lift.prDate = date;
    _persist();
    notifyListeners();
  }

  void addEntry(String key, double value) {
    if (value <= 0) return;
    _lifts.byKey(key).history.add(
          BigLiftPoint(l: todayShortLabel(), v: value, isoDate: todayIso()),
        );
    _persist();
    notifyListeners();
  }

  /// Merges PRs detected by [parseLog]'s PR block into the lift PRs — only
  /// overwrites `prDate` when a date was actually parsed, matching the
  /// original ImportLog save behaviour.
  void mergeParsedPr({
    double? bench,
    double? deadlift,
    double? squat,
    String? date,
  }) {
    if (bench != null) {
      _lifts.bench.pr = bench;
      if (date != null) _lifts.bench.prDate = date;
    }
    if (deadlift != null) {
      _lifts.deadlift.pr = deadlift;
      if (date != null) _lifts.deadlift.prDate = date;
    }
    if (squat != null) {
      _lifts.squat.pr = squat;
      if (date != null) _lifts.squat.prDate = date;
    }
    if (bench != null || deadlift != null || squat != null) {
      _persist();
      notifyListeners();
    }
  }
}
