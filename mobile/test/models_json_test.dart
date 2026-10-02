import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/models/big_lift.dart';
import 'package:ironpeak_mobile/models/day.dart';
import 'package:ironpeak_mobile/models/day_overrides.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/gym_photo.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';
import 'package:ironpeak_mobile/models/program.dart';
import 'package:ironpeak_mobile/models/train_state.dart';

void main() {
  test('Exercise.fresh derives startW from the max set weight', () {
    final ex = Exercise.fresh(
      'Bankdrücken',
      '',
      90,
      [ExerciseSet(w: 60, r: '8'), ExerciseSet(w: 80, r: '8')],
    );
    expect(ex.startW, 80);
    expect(ex.sets.length, 2);
    expect(ex.done, isEmpty);
    expect(ex.history, isEmpty);
  });

  test('Exercise.fresh defaults unilateral to false', () {
    final ex = Exercise.fresh('Ausfallschritte', '', 90, [ExerciseSet(w: 20, r: '8')]);
    expect(ex.unilateral, isFalse);
  });

  test('Exercise JSON round-trip preserves unilateral:true', () {
    final ex = Exercise.fresh('Ausfallschritte', '', 90, [ExerciseSet(w: 20, r: '8')],
        unilateral: true);
    final decoded = Exercise.fromJson(ex.toJson());
    expect(decoded.unilateral, isTrue);
  });

  test('Exercise.fromJson on a pre-feature blob with no "unilateral" key defaults to false', () {
    final legacyJson = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]).toJson()
      ..remove('unilateral');
    final decoded = Exercise.fromJson(legacyJson);
    expect(decoded.unilateral, isFalse);
  });

  test('Exercise.fresh deep-clones the input sets (mutating one leaves the other untouched)', () {
    final source = [ExerciseSet(w: 60, r: '8')];
    final ex = Exercise.fresh('Squat', '', 90, source);
    ex.sets[0].w = 999;
    expect(source[0].w, 60);
  });

  test('ExerciseSet.clone() copies rir alongside w/r/actualReps/rpe', () {
    final set = ExerciseSet(w: 100, r: '5', actualReps: 5, rir: 2);
    final cloned = set.clone();
    expect(cloned.w, 100);
    expect(cloned.r, '5');
    expect(cloned.actualReps, 5);
    expect(cloned.rpe, isNull);
    expect(cloned.rir, 2);
  });

  test('ExerciseSet JSON round-trip carries rir, including 0 (a real value, not "unset")', () {
    final set = ExerciseSet(w: 100, r: '5', rir: 0);
    final decoded = ExerciseSet.fromJson(set.toJson());
    expect(decoded.rir, 0);
    expect(decoded.rpe, isNull);
  });

  test('ExerciseSet.fromJson on a legacy blob (rpe only, no rir key) reads back as RPE with rir null', () {
    final decoded = ExerciseSet.fromJson({'w': 100.0, 'r': '8', 'rpe': 8});
    expect(decoded.rpe, 8);
    expect(decoded.rir, isNull);
  });

  test('Exercise JSON round-trip preserves history reps (int + String mix)', () {
    final ex = Exercise.fresh(
      'Deadlift',
      '',
      90,
      [ExerciseSet(w: 140, r: '3')],
      history: [
        HistoryEntry(weight: 130, reps: ['x', 'x']),
        HistoryEntry(weight: 120, reps: [3, 3]),
      ],
      note: 'Testnotiz',
    );
    ex.done.add(0);

    final decoded = Exercise.fromJson(ex.toJson());

    expect(decoded.name, ex.name);
    expect(decoded.note, 'Testnotiz');
    expect(decoded.done, [0]);
    expect(decoded.startW, ex.startW);
    expect(decoded.history[0].reps, ['x', 'x']);
    expect(decoded.history[1].reps, [3, 3]);
  });

  group('ExerciseLogMode', () {
    test('Exercise defaults to ExerciseLogMode.reps when the JSON has no "logMode" key', () {
      final legacyJson = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]).toJson()
        ..remove('logMode');
      final decoded = Exercise.fromJson(legacyJson);
      expect(decoded.logMode, ExerciseLogMode.reps);
    });

    test('Exercise.fresh defaults logMode to reps', () {
      final ex = Exercise.fresh('Plank', '', 60, [ExerciseSet(w: 0, r: '')]);
      expect(ex.logMode, ExerciseLogMode.reps);
    });

    test('Exercise/ExerciseSet JSON round-trip for Timed mode', () {
      final ex = Exercise.fresh(
        'Plank',
        'core',
        60,
        [
          ExerciseSet(
            w: 5,
            r: '',
            targetDurationSec: 45,
            actualDurationSec: 50,
          ),
        ],
        logMode: ExerciseLogMode.timed,
      );
      final decoded = Exercise.fromJson(ex.toJson());
      expect(decoded.logMode, ExerciseLogMode.timed);
      expect(decoded.sets.single.w, 5);
      expect(decoded.sets.single.targetDurationSec, 45);
      expect(decoded.sets.single.actualDurationSec, 50);
    });

    test('Exercise/ExerciseSet JSON round-trip for Cardio mode', () {
      final ex = Exercise.fresh(
        'Treadmill',
        '',
        0,
        [
          ExerciseSet(
            w: 0,
            r: '',
            targetDurationSec: 1200,
            targetSpeedKmh: 8.5,
            actualDurationSec: 1180,
            actualSpeedKmh: 8.2,
          ),
        ],
        logMode: ExerciseLogMode.cardio,
      );
      final decoded = Exercise.fromJson(ex.toJson());
      expect(decoded.logMode, ExerciseLogMode.cardio);
      expect(decoded.sets.single.targetSpeedKmh, 8.5);
      expect(decoded.sets.single.actualSpeedKmh, 8.2);
    });

    test('HistoryEntry.mode defaults to reps when missing from JSON (old backups)', () {
      final legacyJson = HistoryEntry(weight: 50, reps: [8, 8]).toJson()
        ..remove('mode');
      final decoded = HistoryEntry.fromJson(legacyJson);
      expect(decoded.mode, ExerciseLogMode.reps);
    });

    test('HistoryEntry reps/weight are always present even for Timed/Cardio, never omitted', () {
      final entry = HistoryEntry(
        weight: 5,
        reps: [],
        mode: ExerciseLogMode.timed,
        durations: [45, 40],
      );
      final json = entry.toJson();
      expect(json['reps'], isNotNull);
      expect(json['weight'], isNotNull);
      final decoded = HistoryEntry.fromJson(json);
      expect(decoded.reps, isEmpty);
      expect(decoded.weight, 5);
      expect(decoded.durations, [45, 40]);
    });

    test('HistoryEntry JSON round-trip carries durations+speeds for Cardio', () {
      final entry = HistoryEntry(
        weight: 0,
        reps: [],
        mode: ExerciseLogMode.cardio,
        durations: [1200],
        speeds: [8.5],
      );
      final decoded = HistoryEntry.fromJson(entry.toJson());
      expect(decoded.mode, ExerciseLogMode.cardio);
      expect(decoded.durations, [1200]);
      expect(decoded.speeds, [8.5]);
    });

    test('HistoryEntry.fromJson tolerates integer speeds/durations from a hand-edited or foreign blob', () {
      final decoded = HistoryEntry.fromJson({
        'weight': 0,
        'reps': [],
        'mode': 'cardio',
        'durations': [1200],
        'speeds': [8], // int, not double
      });
      expect(decoded.speeds, [8.0]);
    });

    test('ExerciseSet.clone() copies targetDurationSec/targetSpeedKmh/actualDurationSec/actualSpeedKmh', () {
      final set = ExerciseSet(
        w: 0,
        r: '',
        targetDurationSec: 30,
        targetSpeedKmh: 6.0,
        actualDurationSec: 28,
        actualSpeedKmh: 5.8,
      );
      final cloned = set.clone();
      expect(cloned.targetDurationSec, 30);
      expect(cloned.targetSpeedKmh, 6.0);
      expect(cloned.actualDurationSec, 28);
      expect(cloned.actualSpeedKmh, 5.8);
    });

    test('ExerciseSet.fromJson on a legacy blob with none of the new fields defaults them all to null', () {
      final decoded = ExerciseSet.fromJson({'w': 60.0, 'r': '8'});
      expect(decoded.targetDurationSec, isNull);
      expect(decoded.targetSpeedKmh, isNull);
      expect(decoded.actualDurationSec, isNull);
      expect(decoded.actualSpeedKmh, isNull);
    });
  });

  test('Day JSON round-trip', () {
    final day = Day(
      label: 'Montag',
      rest: false,
      exercises: [Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')])],
    );
    final decoded = Day.fromJson(day.toJson());
    expect(decoded.label, 'Montag');
    expect(decoded.rest, isFalse);
    expect(decoded.exercises.single.name, 'Squat');
  });

  test('Program JSON round-trip (weekday mode, 7 days + dailyExercises)', () {
    final program = Program(
      id: 'plan_1',
      name: 'Mein Plan',
      mode: 'weekday',
      startDate: '2026-01-01',
      days: List.generate(7, (i) => Day(label: 'Tag $i', rest: i == 6)),
      dailyExercises: [Exercise.fresh('Unterrücken', '', 90, [ExerciseSet(w: 20, r: '8')])],
    );
    final decoded = Program.fromJson(program.toJson());
    expect(decoded.id, 'plan_1');
    expect(decoded.mode, 'weekday');
    expect(decoded.days.length, 7);
    expect(decoded.days.last.rest, isTrue);
    expect(decoded.dailyExercises.single.name, 'Unterrücken');
  });

  test('TrainState JSON round-trip, including null activePlanId', () {
    expect(TrainState.fromJson(TrainState().toJson()).activePlanId, isNull);
    final withPlan = TrainState(activePlanId: 'plan_1', viewedDayIdx: 3);
    final decoded = TrainState.fromJson(withPlan.toJson());
    expect(decoded.activePlanId, 'plan_1');
    expect(decoded.viewedDayIdx, 3);
  });

  test('BigLifts JSON round-trip and byKey lookup', () {
    final lifts = BigLifts();
    lifts.bench.pr = 90;
    lifts.bench.prDate = '2026-04-27';
    lifts.deadlift.history.add(BigLiftPoint(l: '6.8', v: 150));

    final decoded = BigLifts.fromJson(lifts.toJson());
    expect(decoded.byKey('bench').pr, 90);
    expect(decoded.byKey('bench').prDate, '2026-04-27');
    expect(decoded.byKey('deadlift').history.single.l, '6.8');
    expect(decoded.byKey('deadlift').history.single.v, 150);
    expect(decoded.squat.pr, 0);
    expect(decoded.squat.prDate, isNull);
  });

  test('GymPhoto JSON round-trip', () {
    final photo = GymPhoto(id: '12345.jpg', date: '2026-08-07');
    final decoded = GymPhoto.fromJson(photo.toJson());
    expect(decoded.id, '12345.jpg');
    expect(decoded.date, '2026-08-07');
  });

  group('DayOverrides', () {
    test('JSON round-trip via set/get across multiple plan ids and dates', () {
      final overrides = DayOverrides();
      overrides.set('plan_1', '2026-10-05', 3);
      overrides.set('plan_1', '2026-10-06', -1);
      overrides.set('plan_2', '2026-10-05', 0);

      final decoded = DayOverrides.fromJson(overrides.toJson());

      expect(decoded.get('plan_1', '2026-10-05'), 3);
      expect(decoded.get('plan_1', '2026-10-06'), -1);
      expect(decoded.get('plan_2', '2026-10-05'), 0);
      expect(decoded.get('plan_2', '2026-10-06'), isNull);
      expect(decoded.get('plan_does_not_exist', '2026-10-05'), isNull);
    });

    test('fromJson on a missing key / null / non-Map / malformed inner-map input returns an empty store',
        () {
      expect(DayOverrides.fromJson(null).byPlan, isEmpty);
      expect(DayOverrides.fromJson('not a map').byPlan, isEmpty);
      expect(DayOverrides.fromJson([1, 2, 3]).byPlan, isEmpty);
      // planId key maps to something that isn't itself a Map -- skipped
      // rather than failing the whole decode.
      expect(
        DayOverrides.fromJson({'plan_1': 'not a map either'}).byPlan,
        isEmpty,
      );
      // Malformed inner value (not a num) is skipped, valid siblings kept.
      final decoded = DayOverrides.fromJson({
        'plan_1': {'2026-10-05': 'not a number', '2026-10-06': 2},
      });
      expect(decoded.get('plan_1', '2026-10-05'), isNull);
      expect(decoded.get('plan_1', '2026-10-06'), 2);
    });

    test('pruneBefore removes only past-dated entries and drops a plan left with no remaining dates',
        () {
      final overrides = DayOverrides();
      overrides.set('plan_1', '2026-10-01', 0); // past
      overrides.set('plan_1', '2026-10-10', 1); // future, kept
      overrides.set('plan_2', '2026-10-02', 2); // past -- only entry for plan_2

      overrides.pruneBefore('2026-10-05');

      expect(overrides.get('plan_1', '2026-10-01'), isNull);
      expect(overrides.get('plan_1', '2026-10-10'), 1);
      expect(overrides.byPlan.containsKey('plan_2'), isFalse);
    });
  });
}
