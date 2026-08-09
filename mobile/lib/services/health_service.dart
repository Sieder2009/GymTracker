import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Thin wrapper around the `health` plugin (Apple HealthKit / Android
/// Health Connect) — reads steps + weight into the app, and writes
/// finished Ironpeak workouts back out. Only available on Android/iOS;
/// every method is a safe no-op (`null`/`false`) on any other platform or
/// if anything about the underlying health store goes wrong, since health
/// data access can fail for many reasons entirely outside the app's
/// control (no Health Connect installed, permission denied, user declined,
/// ...) — callers should treat "no data" as a normal, expected state, not
/// an error to surface loudly.
class HealthService {
  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.WEIGHT,
    HealthDataType.WORKOUT,
  ];
  static const List<HealthDataAccess> _access = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ_WRITE,
  ];

  bool get isSupportedPlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // TRADITIONAL_STRENGTH_TRAINING is iOS-only and STRENGTH_TRAINING is
  // Android-only in this plugin's own platform-support tables — passing
  // the wrong one for the current platform throws, so the type has to be
  // picked per-platform rather than using one constant everywhere.
  HealthWorkoutActivityType get _strengthTrainingType =>
      Platform.isIOS ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING : HealthWorkoutActivityType.STRENGTH_TRAINING;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> hasPermissions() async {
    if (!isSupportedPlatform) return false;
    try {
      await _ensureConfigured();
      return await _health.hasPermissions(_types, permissions: _access) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    if (!isSupportedPlatform) return false;
    try {
      await _ensureConfigured();
      return await _health.requestAuthorization(_types, permissions: _access);
    } catch (_) {
      return false;
    }
  }

  Future<int?> stepsToday() async {
    if (!isSupportedPlatform) return null;
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      return await _health.getTotalStepsInInterval(midnight, now);
    } catch (_) {
      return null;
    }
  }

  /// Most recent weight entry logged in the health store within the last
  /// [withinDays] days, or null if there isn't one / access failed.
  Future<double?> latestWeightKg({int withinDays = 30}) async {
    if (!isSupportedPlatform) return null;
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WEIGHT],
        startTime: now.subtract(Duration(days: withinDays)),
        endTime: now,
      );
      if (points.isEmpty) return null;
      points.sort((a, b) => a.dateTo.compareTo(b.dateTo));
      final value = points.last.value;
      return value is NumericHealthValue ? value.numericValue.toDouble() : null;
    } catch (_) {
      return null;
    }
  }

  /// Writes a finished Ironpeak workout to Apple Health / Health Connect so
  /// it shows up alongside the user's other activity there too.
  Future<bool> writeWorkout({required DateTime start, required DateTime end, String? title}) async {
    if (!isSupportedPlatform) return false;
    try {
      await _ensureConfigured();
      return await _health.writeWorkoutData(
        activityType: _strengthTrainingType,
        start: start,
        end: end,
        title: title,
      );
    } catch (_) {
      return false;
    }
  }
}
