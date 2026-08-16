import 'package:flutter/foundation.dart';

import '../models/workout_session.dart';
import '../services/storage_service.dart';

/// One entry per finished workout (date + how long it took + which plan) —
/// backs the training calendar. Independent from [ProgramsProvider.finishWorkout]'s
/// simple `completed` counter, which stays untouched for backward compatibility.
///
/// Backed by StorageService's `workout_sessions` table — one row per
/// finished workout, added with a single INSERT — rather than a single
/// growing JSON blob that would mean rewriting every workout ever logged
/// back to disk each time one more finishes.
class WorkoutHistoryProvider extends ChangeNotifier {
  WorkoutHistoryProvider(this._storage) : _sessions = _initial(_storage);

  final StorageService _storage;
  List<WorkoutSession> _sessions;

  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);

  static List<WorkoutSession> _initial(StorageService storage) {
    return storage.workoutSessions
        .map((row) => WorkoutSession(
              date: row['date'] as String,
              durationMinutes: row['durationMinutes'] as int,
              planName: row['planName'] as String,
              totalVolumeKg: (row['totalVolumeKg'] as num).toDouble(),
              totalSets: row['totalSets'] as int,
            ))
        .toList();
  }

  void logSession({
    required String date,
    required int durationMinutes,
    required String planName,
    double totalVolumeKg = 0,
    int totalSets = 0,
  }) {
    final session = WorkoutSession(
      date: date,
      durationMinutes: durationMinutes,
      planName: planName,
      totalVolumeKg: totalVolumeKg,
      totalSets: totalSets,
    );
    _sessions = [..._sessions, session];
    _storage.insertWorkoutSession(session.toJson());
    notifyListeners();
  }
}
