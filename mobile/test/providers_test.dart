import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ironpeak_mobile/data/constants.dart';
import 'package:ironpeak_mobile/data/effort_scale.dart';
import 'package:ironpeak_mobile/models/day.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/muscle_group.dart';
import 'package:ironpeak_mobile/models/program.dart';
import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/big_lifts_provider.dart';
import 'package:ironpeak_mobile/state/body_weight_provider.dart';
import 'package:ironpeak_mobile/state/custom_exercises_provider.dart';
import 'package:ironpeak_mobile/state/effort_scale_provider.dart';
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

    test('setUnilateral flips the flag and persists', () async {
      const dbPath = 'test_ironpeak_unilateral_reload.db';
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
      final ex = Exercise.fresh('Lunge', '', 90, [ExerciseSet(w: 20, r: '8')]);
      providerA.addProgram(Program(
        id: 'plan_1',
        name: 'Testplan',
        mode: 'weekday',
        startDate: '2026-01-01',
        days: [Day(label: 'Montag', rest: false, exercises: [ex])],
      ));

      final exercises = providerA.programs.single.days[0].exercises;
      providerA.setUnilateral(exercises, 0, true);
      expect(exercises[0].unilateral, isTrue);
      // _persist() fires the write without awaiting it (matches the real
      // app) -- give that pending write a chance to land before reading it
      // back from a fresh provider over the same storage.
      await Future<void>.delayed(Duration.zero);

      final storageB = await StorageService.create(database: await reopen());
      final providerB = ProgramsProvider(storageB);
      expect(providerB.programs.single.days[0].exercises[0].unilateral, isTrue);
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

    test(
        'setEffort writes exactly one of rpe/rir and clears the other when the scale changes',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]);

      provider.setEffort([ex], 0, 0, EffortScale.rpe, 8);
      expect(ex.sets[0].rpe, 8);
      expect(ex.sets[0].rir, isNull);

      // Re-logging the same set after the global scale switched to RIR must
      // not leave the old RPE value sitting around alongside the new RIR
      // one.
      provider.setEffort([ex], 0, 0, EffortScale.rir, 2);
      expect(ex.sets[0].rir, 2);
      expect(ex.sets[0].rpe, isNull);
    });

    test('setEffort with a null value clears both fields regardless of scale',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '5')]);

      provider.setEffort([ex], 0, 0, EffortScale.rpe, 8);
      provider.setEffort([ex], 0, 0, EffortScale.rir, null);
      expect(ex.sets[0].rpe, isNull);
      expect(ex.sets[0].rir, isNull);
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

    test('setLogMode flips the mode and seeds default targetDurationSec/targetSpeedKmh only when null',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Plank', 'core', 60,
          [ExerciseSet(w: 0, r: '', targetDurationSec: 90)]);

      provider.setLogMode([ex], 0, ExerciseLogMode.timed);
      expect(ex.logMode, ExerciseLogMode.timed);
      // Already-set target duration is not clobbered by the default.
      expect(ex.sets[0].targetDurationSec, 90);

      final ex2 = Exercise.fresh('Treadmill', '', 0, [ExerciseSet(w: 0, r: '')]);
      provider.setLogMode([ex2], 0, ExerciseLogMode.cardio);
      expect(ex2.logMode, ExerciseLogMode.cardio);
      expect(ex2.sets[0].targetDurationSec, 30);
      expect(ex2.sets[0].targetSpeedKmh, 6.0);
    });

    test('setLogMode never touches r, so switching back to Reps restores the original target',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Squat', '', 90, [ExerciseSet(w: 100, r: '8-10')]);

      provider.setLogMode([ex], 0, ExerciseLogMode.timed);
      provider.setLogMode([ex], 0, ExerciseLogMode.reps);
      expect(ex.logMode, ExerciseLogMode.reps);
      expect(ex.sets[0].r, '8-10');
    });

    test('setLogMode seeds r with the editors\' "8" default when switching into Reps on a set that never had a rep target (created directly as Timed/Cardio)',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh(
        'Plank',
        'core',
        60,
        [ExerciseSet(w: 0, r: '', targetDurationSec: 30)],
        logMode: ExerciseLogMode.timed,
      );

      provider.setLogMode([ex], 0, ExerciseLogMode.reps);

      expect(ex.logMode, ExerciseLogMode.reps);
      expect(ex.sets[0].r, '8');
    });

    test('appendGuidedHistoryEntry for a Timed exercise writes durations + reps:[] + mode:timed + weight=max added w',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh(
        'Weighted Plank',
        'core',
        60,
        [
          ExerciseSet(w: 10, r: '', actualDurationSec: 45),
          ExerciseSet(w: 15, r: '', actualDurationSec: 40),
        ],
        logMode: ExerciseLogMode.timed,
      );

      provider.appendGuidedHistoryEntry([ex], 0);

      final entry = ex.history.single;
      expect(entry.mode, ExerciseLogMode.timed);
      expect(entry.weight, 15); // max added weight
      expect(entry.reps, isEmpty);
      expect(entry.durations, [45, 40]);
    });

    test('appendGuidedHistoryEntry for a Cardio exercise writes durations+speeds + reps:[] + mode:cardio + weight=0',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh(
        'Treadmill',
        '',
        0,
        [ExerciseSet(w: 0, r: '', actualDurationSec: 1200, actualSpeedKmh: 8.5)],
        logMode: ExerciseLogMode.cardio,
      );

      provider.appendGuidedHistoryEntry([ex], 0);

      final entry = ex.history.single;
      expect(entry.mode, ExerciseLogMode.cardio);
      expect(entry.weight, 0);
      expect(entry.reps, isEmpty);
      expect(entry.durations, [1200]);
      expect(entry.speeds, [8.5]);
    });

    test('setActualSeconds clamps negative input to 0', () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Plank', 'core', 60, [ExerciseSet(w: 0, r: '')]);

      provider.setActualSeconds([ex], 0, 0, -3);
      expect(ex.sets[0].actualDurationSec, 0);

      provider.setActualSeconds([ex], 0, 0, 45);
      expect(ex.sets[0].actualDurationSec, 45);
    });

    test('adjustCardioDuration starts from the target when no actual is logged yet, and clamps at 0',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Treadmill', '', 0,
          [ExerciseSet(w: 0, r: '', targetDurationSec: 600)]);

      provider.adjustCardioDuration([ex], 0, 0, 60);
      expect(ex.sets[0].actualDurationSec, 660); // 600 (target) + 60, not 0 + 60

      provider.adjustCardioDuration([ex], 0, 0, -10000);
      expect(ex.sets[0].actualDurationSec, 0);
    });

    test('adjustCardioSpeed starts from the target when no actual is logged yet, and clamps at 0',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh('Treadmill', '', 0,
          [ExerciseSet(w: 0, r: '', targetSpeedKmh: 6.0)]);

      provider.adjustCardioSpeed([ex], 0, 0, 0.5);
      expect(ex.sets[0].actualSpeedKmh, 6.5);

      provider.adjustCardioSpeed([ex], 0, 0, -100);
      expect(ex.sets[0].actualSpeedKmh, 0);
    });

    test('saveTimedExerciseLog overwrites sets and appends a matching HistoryEntry, mirroring saveExerciseLog',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh(
        'Weighted Plank',
        'core',
        60,
        [ExerciseSet(w: 0, r: ''), ExerciseSet(w: 0, r: '')],
        logMode: ExerciseLogMode.timed,
      );

      provider.saveTimedExerciseLog([ex], 0, 12.5, [50, 55]);

      expect(ex.sets.every((s) => s.w == 12.5), isTrue);
      expect(ex.sets[0].actualDurationSec, 50);
      expect(ex.sets[1].actualDurationSec, 55);
      expect(ex.history.single.weight, 12.5);
      expect(ex.history.single.mode, ExerciseLogMode.timed);
      expect(ex.history.single.durations, [50, 55]);
      expect(ex.history.single.reps, isEmpty);
    });

    test('saveCardioExerciseLog overwrites sets and appends a matching HistoryEntry, mirroring saveExerciseLog',
        () async {
      final storage = await freshStorage();
      final provider = ProgramsProvider(storage);
      final ex = Exercise.fresh(
        'Treadmill',
        '',
        0,
        [ExerciseSet(w: 0, r: '')],
        logMode: ExerciseLogMode.cardio,
      );

      provider.saveCardioExerciseLog([ex], 0, [1200], [8.5]);

      expect(ex.sets[0].w, 0);
      expect(ex.sets[0].actualDurationSec, 1200);
      expect(ex.sets[0].actualSpeedKmh, 8.5);
      expect(ex.history.single.weight, 0);
      expect(ex.history.single.mode, ExerciseLogMode.cardio);
      expect(ex.history.single.durations, [1200]);
      expect(ex.history.single.speeds, [8.5]);
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

  group('EffortScaleProvider', () {
    test('defaults to EffortScale.rpe on a fresh store with no key written',
        () async {
      final storage = await freshStorage();
      final provider = EffortScaleProvider(storage);
      expect(provider.scale, EffortScale.rpe);
    });

    test(
        'setScale persists and a second provider opened against the same db reads it back',
        () async {
      const dbPath = 'test_ironpeak_effort_reload.db';
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
      final providerA = EffortScaleProvider(storageA);
      providerA.setScale(EffortScale.rir);
      // setScale's writeString fires without awaiting it (see the
      // ProgramsProvider reload test above) -- give that pending write a
      // chance to land before reading it back from a fresh provider.
      await Future<void>.delayed(Duration.zero);

      final storageB = await StorageService.create(database: await reopen());
      final providerB = EffortScaleProvider(storageB);
      expect(providerB.scale, EffortScale.rir);
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

    // Future-dated (relative to "now") rather than a hardcoded string --
    // TrainStateProvider prunes any override dated before today on every
    // load and after every write, so a fixed past/near-past date would get
    // silently dropped as this test suite ages.
    String futureIso(int daysFromNow) {
      final now = DateTime.now();
      return isoOf(DateTime(now.year, now.month, now.day + daysFromNow));
    }

    test(
        'setDayOverride + dayOverride round-trip and survive a reload from the same db file',
        () async {
      const dbPath = 'test_ironpeak_day_override_reload.db';
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
      final iso = futureIso(3);

      final providerA = TrainStateProvider(await StorageService.create(database: await reopen()));
      providerA.setDayOverride('plan_1', iso, 4);
      expect(providerA.dayOverride('plan_1', iso), 4);
      // setDayOverride's writeJson fires without awaiting it (matches the
      // real app) -- give that pending write a chance to land before
      // reading it back from a fresh provider over the same storage.
      await Future<void>.delayed(Duration.zero);

      final providerB = TrainStateProvider(await StorageService.create(database: await reopen()));
      expect(providerB.dayOverride('plan_1', iso), 4);
    });

    test('moveDayOverride writes both the target date (chosen dayIdx) and the source date (-1) in one call',
        () async {
      final storage = await freshStorage();
      final provider = TrainStateProvider(storage);
      final sourceIso = futureIso(1);
      final targetIso = futureIso(2);

      provider.moveDayOverride('plan_1',
          sourceIso: sourceIso, dayIdx: 5, targetIso: targetIso);

      expect(provider.dayOverride('plan_1', targetIso), 5);
      expect(provider.dayOverride('plan_1', sourceIso), -1);
    });

    test('clearDayOverride removes only the targeted plan+date entry, leaving other dates/plans untouched',
        () async {
      final storage = await freshStorage();
      final provider = TrainStateProvider(storage);
      final isoA = futureIso(1);
      final isoB = futureIso(2);
      provider.setDayOverride('plan_1', isoA, 1);
      provider.setDayOverride('plan_1', isoB, 2);
      provider.setDayOverride('plan_2', isoA, 3);

      provider.clearDayOverride('plan_1', isoA);

      expect(provider.dayOverride('plan_1', isoA), isNull);
      expect(provider.dayOverride('plan_1', isoB), 2);
      expect(provider.dayOverride('plan_2', isoA), 3);
    });

    test('selectPlan does NOT wipe an existing day override (regression guard)', () async {
      final storage = await freshStorage();
      final provider = TrainStateProvider(storage);
      final iso = futureIso(1);
      provider.setDayOverride('plan_1', iso, 2);

      provider.selectPlan('plan_1', viewedDayIdx: 0);

      expect(provider.dayOverride('plan_1', iso), 2);
    });

    test('dropOverridesForPlan removes every entry for that plan id only', () async {
      final storage = await freshStorage();
      final provider = TrainStateProvider(storage);
      final iso = futureIso(1);
      provider.setDayOverride('plan_1', iso, 1);
      provider.setDayOverride('plan_2', iso, 2);

      provider.dropOverridesForPlan('plan_1');

      expect(provider.dayOverride('plan_1', iso), isNull);
      expect(provider.dayOverride('plan_2', iso), 2);
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
