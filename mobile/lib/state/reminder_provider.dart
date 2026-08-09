import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/storage_service.dart';

const String _kEnabledKey = 'ironpeak:reminder:enabled';
const String _kTimeKey = 'ironpeak:reminder:time';

/// A daily "time to train" reminder — enabled/disabled + a chosen time,
/// persisted so it survives restarts and re-armed via [NotificationService]
/// whenever either changes. See [NotificationService] for why this quietly
/// does nothing on platforms with no notification plugin (Windows).
class ReminderProvider extends ChangeNotifier {
  ReminderProvider(this._storage, this._notifications)
      : _enabled = _storage.readString(_kEnabledKey) == 'true',
        _time = _parseTime(_storage.readString(_kTimeKey)) {
    if (_enabled) _arm();
  }

  final StorageService _storage;
  final NotificationService _notifications;

  bool _enabled;
  TimeOfDay _time;

  bool get enabled => _enabled;
  TimeOfDay get time => _time;
  bool get isSupportedPlatform => _notifications.isSupportedPlatform;

  static TimeOfDay _parseTime(String? raw) {
    if (raw == null) return const TimeOfDay(hour: 18, minute: 0);
    final parts = raw.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 18 : 18;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> setEnabled(bool value, {required String title, required String body}) async {
    _enabled = value;
    await _storage.writeString(_kEnabledKey, value.toString());
    if (value) {
      final granted = await _notifications.requestPermission();
      if (granted) {
        await _arm(title: title, body: body);
      } else {
        _enabled = false;
        await _storage.writeString(_kEnabledKey, 'false');
      }
    } else {
      await _notifications.cancel();
    }
    notifyListeners();
  }

  Future<void> setTime(TimeOfDay time, {required String title, required String body}) async {
    _time = time;
    await _storage.writeString(_kTimeKey, '${time.hour}:${time.minute}');
    if (_enabled) await _arm(title: title, body: body);
    notifyListeners();
  }

  Future<void> _arm({String? title, String? body}) {
    return _notifications.scheduleDaily(
      _time,
      title: title ?? 'Ironpeak Fitness',
      body: body ?? 'Time to train.',
    );
  }
}
