import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../services/storage_service.dart';

const String _kCreatineDaysKey = 'ironpeak:creatine:days';

/// The days the user ticked off taking creatine -- one 'YYYY-MM-DD' per
/// day, in the kv store like every other small 'ironpeak:' value (so a
/// backup carries it too). Any day can be ticked or unticked, not just
/// today: a forgotten tick is fixed the next morning.
class CreatineProvider extends ChangeNotifier {
  CreatineProvider(this._storage)
      : _days = {
          ...?_storage.readJson<List<String>>(
              _kCreatineDaysKey, (decoded) => (decoded as List).whereType<String>().toList()),
        };

  final StorageService _storage;
  final Set<String> _days;

  bool takenOn(DateTime day) => _days.contains(isoOf(day));

  void toggle(DateTime day) {
    final iso = isoOf(day);
    if (!_days.remove(iso)) _days.add(iso);
    final sorted = _days.toList()..sort();
    _storage.writeJson(_kCreatineDaysKey, () => sorted);
    notifyListeners();
  }

  /// Days in a row up to [now] (default: today). Today not ticked YET
  /// doesn't break it -- the run then counts up to yesterday.
  int streak({DateTime? now}) => creatineStreak(_days, now ?? DateTime.now());
}

/// See [CreatineProvider.streak]; [days] are 'YYYY-MM-DD' strings.
@visibleForTesting
int creatineStreak(Set<String> days, DateTime now) {
  var day = DateTime(now.year, now.month, now.day);
  if (!days.contains(isoOf(day))) day = DateTime(day.year, day.month, day.day - 1);
  var count = 0;
  // Date parts, not Duration: a 23-hour DST night can't skip a day.
  while (days.contains(isoOf(day))) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}
