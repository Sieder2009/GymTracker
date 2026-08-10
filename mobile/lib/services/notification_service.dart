import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const int _kWorkoutReminderId = 1001;
const int _kRestOverId = 1002;

/// Local "time to train" reminder, fired daily at a user-chosen time.
/// `flutter_local_notifications` has no Windows implementation (see
/// pubspec.yaml — no `flutter_local_notifications_windows` package gets
/// pulled in), so every call here is fail-soft and gated behind
/// [isSupportedPlatform], the same pattern as [HealthService] for the same
/// underlying reason: a platform with no plugin backing must never crash,
/// it should just quietly do nothing.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get isSupportedPlatform =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux;

  Future<void> _ensureInitialized() async {
    if (_initialized || !isSupportedPlatform) return;
    try {
      tz_data.initializeTimeZones();
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));

      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      ));
      _initialized = true;
    } catch (_) {
      // fail-soft — reminders simply won't fire on this device.
    }
  }

  Future<bool> requestPermission() async {
    if (!isSupportedPlatform) return false;
    await _ensureInitialized();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleDaily(TimeOfDay time, {required String title, required String body}) async {
    if (!isSupportedPlatform) return;
    await _ensureInitialized();
    try {
      await _plugin.zonedSchedule(
        _kWorkoutReminderId,
        title,
        body,
        _nextInstanceOf(time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'workout_reminder',
            'Workout Reminder',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // fail-soft
    }
  }

  Future<void> cancel() async {
    if (!isSupportedPlatform) return;
    await _ensureInitialized();
    try {
      await _plugin.cancel(_kWorkoutReminderId);
    } catch (_) {
      // fail-soft
    }
  }

  /// One-shot "rest is over" ping for the guided workout's rest timer --
  /// the timer itself is wall-clock-based and keeps counting accurately
  /// even backgrounded, but without this the only way to notice it
  /// finished while the phone is in a pocket is to unlock and look.
  /// [delay] is scheduled fresh each time a rest period starts, so it
  /// always reflects that exercise's actual rest length.
  Future<void> scheduleRestOver(Duration delay, {required String title, required String body}) async {
    if (!isSupportedPlatform) return;
    await _ensureInitialized();
    try {
      await _plugin.zonedSchedule(
        _kRestOverId,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(delay),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_over',
            'Rest Timer',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // fail-soft
    }
  }

  /// Cancels a pending "rest is over" notification -- called whenever rest
  /// ends any way other than the scheduled delay actually elapsing (user
  /// skips it, advances early, or leaves the workout entirely), so a stale
  /// ping can't fire later for a rest period that's already moved on.
  Future<void> cancelRestOver() async {
    if (!isSupportedPlatform) return;
    await _ensureInitialized();
    try {
      await _plugin.cancel(_kRestOverId);
    } catch (_) {
      // fail-soft
    }
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
