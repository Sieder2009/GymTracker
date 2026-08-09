import 'package:flutter/foundation.dart';

import '../services/health_service.dart';

/// Bridges Apple Health / Health Connect into the app: read-only steps +
/// weight sync in, finished-workout write-out. Purely a live device
/// integration — nothing here is persisted through [StorageService]; the
/// health store itself is the source of truth, re-queried each time.
class HealthProvider extends ChangeNotifier {
  HealthProvider(this._service) {
    _checkExistingAuthorization();
  }

  final HealthService _service;

  bool _authorized = false;
  int? _stepsToday;
  bool _loading = false;

  bool get isSupportedPlatform => _service.isSupportedPlatform;
  bool get isAuthorized => _authorized;
  int? get stepsToday => _stepsToday;
  bool get isLoading => _loading;

  Future<void> _checkExistingAuthorization() async {
    if (!isSupportedPlatform) return;
    _authorized = await _service.hasPermissions();
    if (_authorized) await refreshSteps();
    notifyListeners();
  }

  Future<void> connect() async {
    if (!isSupportedPlatform || _loading) return;
    _loading = true;
    notifyListeners();
    _authorized = await _service.requestAuthorization();
    if (_authorized) await _refreshStepsQuiet();
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshSteps() async {
    await _refreshStepsQuiet();
    notifyListeners();
  }

  Future<void> _refreshStepsQuiet() async {
    if (!_authorized) return;
    _stepsToday = await _service.stepsToday();
  }

  Future<double?> fetchLatestWeightKg() {
    if (!_authorized) return Future.value(null);
    return _service.latestWeightKg();
  }

  Future<bool> writeWorkout({required DateTime start, required DateTime end, String? title}) {
    if (!_authorized) return Future.value(false);
    return _service.writeWorkout(start: start, end: end, title: title);
  }
}
