import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../models/big_lift.dart';
import '../services/storage_service.dart';

const String _kBigLiftsKey = 'ironpeak:bigLifts';

class BigLiftsProvider extends ChangeNotifier {
  BigLiftsProvider(this._storage) : _lifts = _initial(_storage);

  final StorageService _storage;
  final BigLifts _lifts;

  BigLifts get lifts => _lifts;

  /// `pr`/`prDate` come from the small kv blob (still keyed by
  /// [_kBigLiftsKey]); `history` comes from StorageService's
  /// `big_lift_history` table, filtered per lift — see [_persist] for why
  /// those two live in different places now.
  static BigLifts _initial(StorageService storage) {
    final lifts = storage.readJson<BigLifts>(
          _kBigLiftsKey,
          (raw) => BigLifts.fromJson(raw as Map<String, dynamic>),
        ) ??
        BigLifts();
    for (final key in BigLifts.keys) {
      lifts.byKey(key).history = storage.bigLiftHistory
          .where((row) => row['liftKey'] == key)
          .map((row) => BigLiftPoint(
                l: row['label'] as String,
                v: (row['value'] as num).toDouble(),
                isoDate: row['isoDate'] as String?,
              ))
          .toList();
    }
    return lifts;
  }

  /// Writes only `pr`/`prDate` — `history` is deliberately left out (see
  /// [addEntry]): it lives in StorageService's `big_lift_history` table
  /// now, one row per logged entry, so logging one more doesn't mean
  /// rewriting every entry ever logged for that lift back to disk.
  void _persist() {
    final snapshot = BigLifts(
      bench: BigLift(pr: _lifts.bench.pr, prDate: _lifts.bench.prDate),
      deadlift: BigLift(pr: _lifts.deadlift.pr, prDate: _lifts.deadlift.prDate),
      squat: BigLift(pr: _lifts.squat.pr, prDate: _lifts.squat.prDate),
    );
    _storage.writeJson(_kBigLiftsKey, () => snapshot.toJson());
  }

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
    final point = BigLiftPoint(l: todayShortLabel(), v: value, isoDate: todayIso());
    _lifts.byKey(key).history.add(point);
    _storage.insertBigLiftHistory({
      'liftKey': key,
      'label': point.l,
      'isoDate': point.isoDate,
      'value': point.v,
    });
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
