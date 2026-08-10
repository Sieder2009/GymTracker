import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/health_service.dart';
import '../services/storage_service.dart';

const String _kConnectedKey = 'ironpeak:healthConnectedOnce';
const String _kDisabledKey = 'ironpeak:healthDisabled';

/// Bridges Apple Health / Health Connect into the app: read-only steps +
/// weight sync in, finished-workout write-out.
///
/// [isConnected] combines two things: whether the OS actually granted
/// access, and whether the user has since turned the integration back off
/// from Settings (see [disconnect]). The OS grant itself can't be queried
/// reliably on every platform — Android Health Connect answers
/// [HealthService.hasPermissions] honestly, but iOS HealthKit deliberately
/// never confirms *read* authorization once granted (a privacy design
/// choice: an app shouldn't be able to distinguish "denied" from "no
/// data"), so on iOS this falls back to remembering that [connect]
/// succeeded at some point. Neither the OS grant nor that memory can be
/// revoked by this app — only the user can do that, from the OS's own
/// Health / Health Connect settings — so [disconnect] only stops *this
/// app* from reading/writing and brings the dashboard prompt back; it's
/// not a real permission revocation.
class HealthProvider extends ChangeNotifier {
  HealthProvider(this._service, this._storage) {
    unawaited(_checkExistingAuthorization());
  }

  final HealthService _service;
  final StorageService _storage;

  bool _authorized = false;
  bool _userDisabled = false;
  int? _stepsToday;
  bool _loading = false;

  bool get isSupportedPlatform => _service.isSupportedPlatform;
  bool get isConnected => _authorized && !_userDisabled;
  int? get stepsToday => _stepsToday;
  bool get isLoading => _loading;

  Future<void> _checkExistingAuthorization() async {
    if (!isSupportedPlatform) return;
    _userDisabled = _storage.readString(_kDisabledKey) == 'true';
    final osReports = await _service.hasPermissions();
    _authorized = osReports || (Platform.isIOS && _storage.readString(_kConnectedKey) == 'true');
    if (isConnected) await refreshSteps();
    notifyListeners();
  }

  Future<void> connect() async {
    if (!isSupportedPlatform || _loading) return;
    _loading = true;
    notifyListeners();
    _authorized = await _service.requestAuthorization();
    if (_authorized) {
      unawaited(_storage.writeString(_kConnectedKey, 'true'));
      _userDisabled = false;
      unawaited(_storage.writeString(_kDisabledKey, 'false'));
      await _refreshStepsQuiet();
    }
    _loading = false;
    notifyListeners();
  }

  void disconnect() {
    _userDisabled = true;
    unawaited(_storage.writeString(_kDisabledKey, 'true'));
    notifyListeners();
  }

  Future<void> refreshSteps() async {
    await _refreshStepsQuiet();
    notifyListeners();
  }

  Future<void> _refreshStepsQuiet() async {
    if (!isConnected) return;
    _stepsToday = await _service.stepsToday();
  }

  Future<double?> fetchLatestWeightKg() {
    if (!isConnected) return Future.value(null);
    return _service.latestWeightKg();
  }

  Future<bool> writeWorkout({required DateTime start, required DateTime end, String? title}) {
    if (!isConnected) return Future.value(false);
    return _service.writeWorkout(start: start, end: end, title: title);
  }
}
