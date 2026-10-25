import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

const String _kShowNextWorkoutKey = 'ironpeak:home:showNextWorkout';
const String _kShowStartWorkoutKey = 'ironpeak:home:showStartWorkout';

/// Which optional parts the home screen shows: the "Next workout" card
/// (exercise count + estimated duration) and the "Start workout" button
/// into the guided session. Both off by default, so the home screen is
/// just the calendar, creatine and today's plan; Settings turns them on.
class HomeLayoutProvider extends ChangeNotifier {
  HomeLayoutProvider(this._storage)
      : _showNextWorkout = _storage.readString(_kShowNextWorkoutKey) == 'true',
        _showStartWorkout = _storage.readString(_kShowStartWorkoutKey) == 'true';

  final StorageService _storage;
  bool _showNextWorkout;
  bool _showStartWorkout;

  bool get showNextWorkout => _showNextWorkout;
  bool get showStartWorkout => _showStartWorkout;

  void setShowNextWorkout(bool value) {
    if (value == _showNextWorkout) return;
    _showNextWorkout = value;
    _storage.writeString(_kShowNextWorkoutKey, value ? 'true' : 'false');
    notifyListeners();
  }

  void setShowStartWorkout(bool value) {
    if (value == _showStartWorkout) return;
    _showStartWorkout = value;
    _storage.writeString(_kShowStartWorkoutKey, value ? 'true' : 'false');
    notifyListeners();
  }
}
