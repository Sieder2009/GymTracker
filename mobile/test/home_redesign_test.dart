import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/heatmap_engine.dart';
import 'package:ironpeak_mobile/analytics/logged_days.dart';
import 'package:ironpeak_mobile/models/day.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';
import 'package:ironpeak_mobile/models/program.dart';
import 'package:ironpeak_mobile/models/workout_session.dart';
import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/exercise_draft_store.dart';
import 'package:ironpeak_mobile/state/programs_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _dbCounter = 0;

Future<StorageService> _freshStorage() async {
  final path = 'test_home_redesign_${_dbCounter++}.db';
  await databaseFactoryFfi.deleteDatabase(path);
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      ),
    ),
  );
  return StorageService.create(database: db);
}

Exercise _ex(String name, {List<HistoryEntry>? history, bool linked = false}) {
  final ex = Exercise.fresh(name, '', 90, [ExerciseSet(w: 50, r: '8'), ExerciseSet(w: 50, r: '8')]);
  if (history != null) ex.history.addAll(history);
  ex.supersetWithNext = linked;
  return ex;
}

Program _plan({List<Day>? days, List<Exercise>? daily}) => Program(
      id: 'p1',
      name: 'Push Pull',
      mode: 'weekday',
      startDate: '2026-01-01',
      days: days ??
          [
            Day(label: 'Montag', rest: false, exercises: [_ex('Bench'), _ex('Row')]),
            Day(label: 'Dienstag', rest: true),
          ],
      dailyExercises: daily,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('sessionsWithLoggedExercises', () {
    test('a day with only a saved exercise becomes a training day', () {
      final plan = _plan(days: [
        Day(label: 'Montag', rest: false, exercises: [
          _ex('Bench', history: [
            HistoryEntry(weight: 60, reps: [8, 8, 6], date: '2026-10-14'),
          ]),
        ]),
      ]);
      final all = sessionsWithLoggedExercises(const [], [plan]);
      expect(all, hasLength(1));
      final day = all.single;
      expect(day.date, '2026-10-14');
      expect(day.planName, 'Push Pull');
      expect(day.totalVolumeKg, 60 * 22);
      expect(day.totalSets, 3);
      expect(day.durationMinutes, 0);
      expect(aggregateHeatmapDays(all)['2026-10-14']!.sessionCount, 1);
    });

    test('a date with a guided workout is never counted twice', () {
      final session = WorkoutSession(
          date: '2026-10-14', durationMinutes: 50, planName: 'Push Pull', totalVolumeKg: 999);
      final plan = _plan(days: [
        Day(label: 'Montag', rest: false, exercises: [
          _ex('Bench', history: [HistoryEntry(weight: 60, reps: [8], date: '2026-10-14')]),
        ]),
      ]);
      final all = sessionsWithLoggedExercises([session], [plan]);
      expect(all, [session]);
    });

    test('merges a day across exercises, the daily list and timed sets', () {
      final plan = _plan(
        days: [
          Day(label: 'Montag', rest: false, exercises: [
            _ex('Bench', history: [HistoryEntry(weight: 50, reps: [10, '8'], date: '2026-10-13')]),
          ]),
        ],
        daily: [
          _ex('Plank', history: [
            HistoryEntry(
              weight: 0,
              reps: const [],
              date: '2026-10-13',
              mode: ExerciseLogMode.timed,
              durations: [60, 60],
            ),
          ]),
        ],
      );
      final day = sessionsWithLoggedExercises(const [], [plan]).single;
      expect(day.totalVolumeKg, 50 * 18);
      expect(day.totalSets, 4);
      expect(day.durationMinutes, 2);
    });

    test('skips entries without a readable date', () {
      final plan = _plan(days: [
        Day(label: 'Montag', rest: false, exercises: [
          _ex('Bench', history: [
            HistoryEntry(weight: 60, reps: [8]),
            HistoryEntry(weight: 60, reps: [8], date: 'gestern'),
          ]),
        ]),
      ]);
      expect(sessionsWithLoggedExercises(const [], [plan]), isEmpty);
    });
  });

  group('ProgramsProvider.moveExerciseToDay', () {
    test('moves the exercise with its history to the end of the target day', () async {
      final provider = ProgramsProvider(await _freshStorage());
      final plan = _plan();
      final monday = plan.days[0].exercises;
      final bench = monday[0]..history.add(HistoryEntry(weight: 60, reps: [8], date: '2026-10-01'));

      provider.moveExerciseToDay(plan, monday, 0, 1);

      expect(monday.map((e) => e.name), ['Row']);
      expect(plan.days[1].exercises, [bench]);
      expect(bench.history, hasLength(1));
      // A rest day that receives an exercise becomes a training day.
      expect(plan.days[1].rest, isFalse);
    });

    test('moves into and out of the every-training-day list', () async {
      final provider = ProgramsProvider(await _freshStorage());
      final plan = _plan();
      final monday = plan.days[0].exercises;

      provider.moveExerciseToDay(plan, monday, 1, null);
      expect(plan.dailyExercises.map((e) => e.name), ['Row']);

      provider.moveExerciseToDay(plan, plan.dailyExercises, 0, 0);
      expect(plan.dailyExercises, isEmpty);
      expect(monday.map((e) => e.name), ['Bench', 'Row']);
    });

    test('never leaves a superset link pointing at a stranger', () async {
      final provider = ProgramsProvider(await _freshStorage());
      final plan = _plan(days: [
        Day(label: 'Montag', rest: false, exercises: [
          _ex('A', linked: true),
          _ex('B', linked: true),
          _ex('C'),
        ]),
        Day(label: 'Dienstag', rest: false),
      ]);
      final monday = plan.days[0].exercises;

      provider.moveExerciseToDay(plan, monday, 1, 1);

      expect(monday.map((e) => e.name), ['A', 'C']);
      expect(monday[0].supersetWithNext, isFalse);
      expect(plan.days[1].exercises.single.supersetWithNext, isFalse);
    });

    test('moving onto its own list or a bad index does nothing', () async {
      final provider = ProgramsProvider(await _freshStorage());
      final plan = _plan();
      final monday = plan.days[0].exercises;
      provider.moveExerciseToDay(plan, monday, 0, 0);
      provider.moveExerciseToDay(plan, monday, 5, 1);
      expect(monday.map((e) => e.name), ['Bench', 'Row']);
      expect(plan.days[1].exercises, isEmpty);
    });
  });

  group('ProgramsProvider.setTargetReps', () {
    test('edits one planned set and ignores rows the plan does not have', () async {
      final provider = ProgramsProvider(await _freshStorage());
      final ex = _ex('Bench');
      provider.setTargetReps([ex], 0, 1, '10-12');
      provider.setTargetReps([ex], 0, 5, '3');
      expect(ex.sets.map((s) => s.r), ['8', '10-12']);
    });
  });

  group('ExerciseDraftStore', () {
    test('keeps a draft per exercise object until it is cleared', () {
      final a = _ex('Bench');
      final b = _ex('Bench');
      const draft = ExerciseDraft(
        logMode: ExerciseLogMode.reps,
        weight: 62.5,
        values: ['8', '7'],
        speeds: ['', ''],
      );
      ExerciseDraftStore.put(a, draft);
      expect(ExerciseDraftStore.of(a), same(draft));
      expect(ExerciseDraftStore.of(b), isNull); // same name, other exercise
      ExerciseDraftStore.clear(a);
      expect(ExerciseDraftStore.of(a), isNull);
    });
  });
}
