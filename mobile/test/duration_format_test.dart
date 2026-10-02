import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/duration_format.dart';
import 'package:ironpeak_mobile/l10n/app_localizations.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';

void main() {
  final t = lookupAppLocalizations(const Locale('en'));

  group('formatSeconds', () {
    test('0 -> 0:00', () {
      expect(formatSeconds(0), '0:00');
    });

    test('45 -> 0:45', () {
      expect(formatSeconds(45), '0:45');
    });

    test('60 -> 1:00', () {
      expect(formatSeconds(60), '1:00');
    });

    test('90 -> 1:30', () {
      expect(formatSeconds(90), '1:30');
    });

    test('3661 -> 1:01:01 (past an hour)', () {
      expect(formatSeconds(3661), '1:01:01');
    });

    test('negative input clamps to 0:00', () {
      expect(formatSeconds(-5), '0:00');
    });
  });

  group('exerciseSetsSummaryLabel', () {
    test('Reps mode: "3× 8-10"', () {
      final ex = Exercise.fresh('Bench', '', 90, [
        ExerciseSet(w: 60, r: '8-10'),
        ExerciseSet(w: 60, r: '8-10'),
        ExerciseSet(w: 60, r: '8-10'),
      ]);
      expect(exerciseSetsSummaryLabel(t, ex), '3× 8-10');
    });

    test('Timed mode: "3× 0:30"', () {
      final ex = Exercise.fresh(
        'Plank',
        'core',
        60,
        [
          ExerciseSet(w: 0, r: '', targetDurationSec: 30),
          ExerciseSet(w: 0, r: '', targetDurationSec: 30),
          ExerciseSet(w: 0, r: '', targetDurationSec: 30),
        ],
        logMode: ExerciseLogMode.timed,
      );
      expect(exerciseSetsSummaryLabel(t, ex), '3× 0:30');
    });

    test('Cardio mode: "20 min · <speed> km/h" (fmt1 always uses a German-style decimal comma, matching every other weight/speed display in the app)', () {
      final ex = Exercise.fresh(
        'Treadmill',
        '',
        0,
        [ExerciseSet(w: 0, r: '', targetDurationSec: 1200, targetSpeedKmh: 8.0)],
        logMode: ExerciseLogMode.cardio,
      );
      expect(exerciseSetsSummaryLabel(t, ex), '20 min · 8,0 km/h');
    });

    test('empty sets list returns an empty string for any mode', () {
      final ex = Exercise.fresh('Empty', '', 90, []);
      expect(exerciseSetsSummaryLabel(t, ex), '');
    });
  });
}
