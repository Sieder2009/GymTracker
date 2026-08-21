import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/muscle_group.dart';
import 'package:ironpeak_mobile/models/program.dart';
import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/big_lifts_provider.dart';
import 'package:ironpeak_mobile/state/body_weight_provider.dart';
import 'package:ironpeak_mobile/state/custom_exercises_provider.dart';
import 'package:ironpeak_mobile/state/programs_provider.dart';
import 'package:ironpeak_mobile/state/toast_provider.dart';
import 'package:ironpeak_mobile/state/train_state_provider.dart';
import 'package:ironpeak_mobile/state/workout_history_provider.dart';

/// Opens a fresh on-disk sqflite (FFI) database, one per call — separate
/// physical files rather than `:memory:` so two `StorageService`s can open
/// the SAME backing db and see each other's writes, matching how the real
/// app persists across restarts (see the reload test below). Deletes any
/// leftover file from a previous test run first — the filenames are
/// deterministic (call order), so without this, a later run silently
/// reopens a prior run's file and inherits its data.
int _dbCounter = 0;

Future<Database> _freshDb() async {
  final path = 'test_ironpeak_${_dbCounter++}.db';
  await databaseFactoryFfi.deleteDatabase(path);
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<StorageService> freshStorage() async {
    return StorageService.create(database: await _freshDb());
  }

  group('ProgramsProvider', () {
    test('adjustWeight clamps at 0 and rounds to the nearest 0.5', () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 1, r: '5')]);

      provider.adjustWeight([ex], 0, 0, -5); // 1 - 5 = -4 -> clamp to 0
      expect(ex.sets[0].w, 0);

      provider.adjustWeight([ex], 0, 0, 2.3); // 0 + 2.3 -> rounds to 2.5
      expect(ex.sets[0].w, 2.5);
    });

    test('toggleSet only ever adds, never removes (one-way)', () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]);

      provider.toggleSet([ex], 0, 0);
      provider.toggleSet([ex], 0, 0);
      expect(ex.done, [0]);
    });

    test('saveExerciseLog always overwrites every set weight', () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Bankdrücken', '', 90,
          [ExerciseSet(w: 60, r: '8'), ExerciseSet(w: 60, r: '8')]);

      provider.saveExerciseLog(
          [ex], 0, 50, [8, 7]); // lower weight still overwrites
      expect(ex.sets.every((s) => s.w == 50), isTrue);
      expect(ex.history.single.weight, 50);
    });

    test('importExerciseHistory always overwrites with the last-entered weight',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex =
          Exercise.fresh('Bankdrücken', '', 90, [ExerciseSet(w: 60, r: '8')]);

      provider.importExerciseHistory([ex], 0, 50, []); // lower -> still overwrites
      expect(ex.sets[0].w, 50);

      provider.importExerciseHistory([ex], 0, 70, []); // higher -> overwrites
      expect(ex.sets[0].w, 70);
    });

    test('addProgram + persistence survives a reload from the same db file',
        () async {
      const dbPath = 'test_ironpeak_reload.db';
      Future<Database> reopen() => databaseFactoryFfi.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) => db.execute(
                'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
              ),
            ),
          );
      await databaseFactoryFfi.deleteDatabase(dbPath);

      final storageA = await StorageService.create(database: await reopen());
      final providerA = ProgramsProvider(storageA);
      providerA.addProgram(Program(
        id: 'plan_1',
        name: 'Testplan',
        mode: 'weekday',
        startDate: '2026-01-01',
        days: [],
      ));
      // _persist() fires the write without awaiting it (matches the real
      // app, which never blocks UI handlers on persistence) — give that
      // pending write a chance to land before reading it back.
      await Future<void>.delayed(Duration.zero);

      final storageB = await StorageService.create(database: await reopen());
      final providerB = ProgramsProvider(storageB);
      expect(providerB.programs.single.id, 'plan_1');
    });

    test('resetSessionProgress clears done marks for a fresh session',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]);
      provider.toggleSet([ex], 0, 0);
      expect(ex.done, [0]);

      provider.resetSessionProgress([ex]);
      expect(ex.done, isEmpty);
    });

    test('setActualReps clamps negative input to 0', () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]);

      provider.setActualReps([ex], 0, 0, -3);
      expect(ex.sets[0].actualReps, 0);

      provider.setActualReps([ex], 0, 0, 5);
      expect(ex.sets[0].actualReps, 5);
    });

    test('setRpe writes the given value, including null to clear it', () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]);

      provider.setRpe([ex], 0, 0, 8);
      expect(ex.sets[0].rpe, 8);

      provider.setRpe([ex], 0, 0, null);
      expect(ex.sets[0].rpe, isNull);
    });

    test('appendGuidedHistoryEntry uses the highest set weight and logged reps',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Bankdrücken', '', 90, [
        ExerciseSet(w: 60, r: '8', actualReps: 8),
        ExerciseSet(w: 65, r: '8', actualReps: 6),
      ]);

      provider.appendGuidedHistoryEntry([ex], 0);

      expect(ex.history.single.weight, 65);
      expect(ex.history.single.reps, [8, 6]);
    });

    test('removeExercise deletes only the exercise at the given index',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final a = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]);
      final b = Exercise.fresh('Bench', '', 90, [ExerciseSet(w: 60, r: '8')]);
      final exercises = [a, b];

      provider.removeExercise(exercises, 0);

      expect(exercises, [b]);
    });

    test('removeProgram deletes only the matching id', () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      provider.addProgram(Program(
        id: 'plan_1',
        name: 'A',
        mode: 'weekday',
        startDate: '2026-01-01',
        days: [],
      ));
      provider.addProgram(Program(
        id: 'plan_2',
        name: 'B',
        mode: 'weekday',
        startDate: '2026-01-01',
        days: [],
      ));

      provider.removeProgram('plan_1');

      expect(provider.programs.length, 1);
      expect(provider.programs.single.id, 'plan_2');
    });
  });

  group('TrainStateProvider', () {
    test('selectPlan persists activePlanId + viewedDayIdx', () async {
      final storage = await freshStorage();
      final provider = TrainStateProvider(storage);
      provider.selectPlan('plan_1', viewedDayIdx: 3);
      expect(provider.activePlanId, 'plan_1');
      expect(provider.viewedDayIdx, 3);
    });

    test('clear() resets to no active plan', () async {
      final storage = await freshStorage();
      final provider = TrainStateProvider(storage);
      provider.selectPlan('plan_1', viewedDayIdx: 2);
      provider.clear();
      expect(provider.activePlanId, isNull);
      expect(provider.viewedDayIdx, 0);
    });
  });

  group('BodyWeightProvider', () {
    test('addEntry ignores zero/negative weight', () async {
      final storage = await freshStorage();
      final provider = BodyWeightProvider(storage);
      provider.addEntry(0);
      provider.addEntry(-5);
      expect(provider.entries, isEmpty);
    });

    test('addEntry appends a dated entry', () async {
      final storage = await freshStorage();
      final provider = BodyWeightProvider(storage);
      provider.addEntry(82.5);
      expect(provider.entries.single.weight, 82.5);
      expect(provider.entries.single.date, isNotEmpty);
    });
  });

  group('WorkoutHistoryProvider', () {
    test('logSession appends a session with the given date/duration/plan',
        () async {
      final storage = await freshStorage();
      final provider = WorkoutHistoryProvider(storage);
      provider.logSession(
          date: '2026-08-07', durationMinutes: 45, planName: 'Push Pull Legs');
      expect(provider.sessions.single.date, '2026-08-07');
      expect(provider.sessions.single.durationMinutes, 45);
      expect(provider.sessions.single.planName, 'Push Pull Legs');
    });
  });

  group('BigLiftsProvider', () {
    test('savePr never touches prDate', () async {
      final storage = await freshStorage();
      final provider = BigLiftsProvider(storage);
      provider.mergeParsedPr(bench: 80, date: '2026-01-01');
      provider.savePr('bench', 85);
      expect(provider.lifts.bench.pr, 85);
      expect(provider.lifts.bench.prDate, '2026-01-01');
    });

    test('mergeParsedPr only sets prDate when a date was parsed', () async {
      final storage = await freshStorage();
      final provider = BigLiftsProvider(storage);
      provider.mergeParsedPr(deadlift: 150); // no date
      expect(provider.lifts.deadlift.pr, 150);
      expect(provider.lifts.deadlift.prDate, isNull);
    });

    test('bumpPrIfHigher only updates when the new value beats the current PR',
        () async {
      final storage = await freshStorage();
      final provider = BigLiftsProvider(storage);
      provider.savePr('squat', 100);

      provider.bumpPrIfHigher('squat', 90, '2026-02-01'); // lower -> no-op
      expect(provider.lifts.squat.pr, 100);
      expect(provider.lifts.squat.prDate, isNull);

      provider.bumpPrIfHigher(
          'squat', 110, '2026-02-01'); // higher -> bumps both
      expect(provider.lifts.squat.pr, 110);
      expect(provider.lifts.squat.prDate, '2026-02-01');
    });
  });

  group('CustomExercisesProvider', () {
    test(
        'add generates a custom: prefixed id that cannot collide with the shared database',
        () async {
      final storage = await freshStorage();
      final provider = CustomExercisesProvider(storage);
      provider.add('Meine Übung', 'chest');

      expect(provider.items.single.template.id, startsWith('custom:'));
      expect(provider.templates.single.name, 'Meine Übung');
    });

    test(
        'activationFor returns the configured map, or null for none/unknown id',
        () async {
      final storage = await freshStorage();
      final provider = CustomExercisesProvider(storage);
      provider.add('Meine Übung', 'chest', activation: {MuscleGroup.chest: 80});
      final id = provider.items.single.template.id;

      expect(provider.activationFor(id), {MuscleGroup.chest: 80});
      expect(provider.activationFor('does-not-exist'), isNull);
    });

    test('remove deletes only the matching id', () async {
      final storage = await freshStorage();
      final provider = CustomExercisesProvider(storage);
      provider.add('A', 'chest');
      provider.add('B', 'back');
      final idToRemove = provider.items.first.template.id;

      provider.remove(idToRemove);

      expect(provider.items.length, 1);
      expect(provider.items.single.template.name, 'B');
    });

    test('persists across a reload from the same storage', () async {
      final storage = await freshStorage();
      CustomExercisesProvider(storage).add('Persisted', 'legs');
      await Future<void>.delayed(Duration.zero);

      final reloaded = CustomExercisesProvider(storage);
      expect(reloaded.templates.single.name, 'Persisted');
    });
  });

  group('ToastProvider', () {
    test('show() sets message + visible synchronously', () async {
      final provider = ToastProvider();
      provider.show('Gespeichert');
      expect(provider.visible, isTrue);
      expect(provider.message, 'Gespeichert');
      provider.dispose();
    });
  });
}
