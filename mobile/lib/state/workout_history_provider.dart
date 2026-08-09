import 'package:flutter/foundation.dart';

import '../models/workout_session.dart';
import '../services/storage_service.dart';

const String _kWorkoutHistoryKey = 'ironpeak:workoutHistory';

/// One entry per finished workout (date + how long it took + which plan) —
/// backs the training calendar. Independent from [ProgramsProvider.finishWorkout]'s
/// simple `completed` counter, which stays untouched for backward compatibility.
class WorkoutHistoryProvider extends ChangeNotifier {
  WorkoutHistoryProvider(this._storage) : _sessions = _initial(_storage);

  final StorageService _storage;
  List<WorkoutSession> _sessions;

  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);

  static List<WorkoutSession> _initial(StorageService storage) {
    final decoded = storage.readJson<List<WorkoutSession>>(
      _kWorkoutHistoryKey,
      (raw) => (raw as List)
          .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return decoded ?? [];
  }

  void _persist() {
    _storage.writeJson(_kWorkoutHistoryKey, () => _sessions.map((e) => e.toJson()).toList());
  }

  void logSession({
    required String date,
    required int durationMinutes,
    required String planName,
    double totalVolumeKg = 0,
    int totalSets = 0,
  }) {
    _sessions = [
      ..._sessions,
      WorkoutSession(
        date: date,
        durationMinutes: durationMinutes,
        planName: planName,
        totalVolumeKg: totalVolumeKg,
        totalSets: totalSets,
      ),
    ];
    _persist();
    notifyListeners();
  }
}
