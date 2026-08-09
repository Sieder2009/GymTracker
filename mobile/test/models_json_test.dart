import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/models/big_lift.dart';
import 'package:ironpeak_mobile/models/day.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
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

  test('Exercise.fresh deep-clones the input sets (mutating one leaves the other untouched)', () {
    final source = [ExerciseSet(w: 60, r: '8')];
    final ex = Exercise.fresh('Squat', '', 90, source);
    ex.sets[0].w = 999;
    expect(source[0].w, 60);
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
}
