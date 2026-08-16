import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ironpeak_mobile/services/storage_service.dart';

/// Covers the part of the storage rewrite that's actually risky: real
/// user data sitting in the old single-blob-per-key shape has to survive
/// the move to real tables (workout_sessions/big_lift_history/
/// body_weight_entries/gym_photos) without loss, exactly once, and backup
/// export/import has to keep working across the same change. Everything
/// here operates on a real on-disk sqflite (FFI) file, not `:memory:`, so
/// re-opening actually exercises persistence the way the app does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  int dbCounter = 0;
  Future<Database> freshLegacyDb() async {
    final path = 'test_migration_${dbCounter++}.db';
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

  group('legacy blob migration', () {
    test('workout history: a pre-existing kv blob is absorbed into the table', () async {
      final db = await freshLegacyDb();
      await db.insert('kv', {
        'key': 'ironpeak:workoutHistory',
        'value': jsonEncode([
          {'date': '2026-01-01', 'durationMinutes': 40, 'planName': 'Push', 'totalVolumeKg': 500.0, 'totalSets': 12},
        ]),
      });

      final storage = await StorageService.create(database: db);

      expect(storage.workoutSessions, hasLength(1));
      expect(storage.workoutSessions.single['planName'], 'Push');
      // The legacy key is gone -- migration doesn't leave stale duplicate
      // data sitting on disk once it's been absorbed.
      expect(storage.readString('ironpeak:workoutHistory'), isNull);
    });

    test('body weight: a pre-existing kv blob is absorbed into the table', () async {
      final db = await freshLegacyDb();
      await db.insert('kv', {
        'key': 'ironpeak:bodyWeight',
        'value': jsonEncode([
          {'date': '2026-01-01', 'weight': 80.0},
          {'date': '2026-01-08', 'weight': 79.5},
        ]),
      });

      final storage = await StorageService.create(database: db);

      expect(storage.bodyWeightEntries, hasLength(2));
      expect(storage.bodyWeightEntries.last['weight'], 79.5);
      expect(storage.readString('ironpeak:bodyWeight'), isNull);
    });

    test('gym photos: a pre-existing kv blob is absorbed into the table', () async {
      final db = await freshLegacyDb();
      await db.insert('kv', {
        'key': 'ironpeak:gymPhotos',
        'value': jsonEncode([
          {'id': 'photo1.jpg', 'date': '2026-01-01'},
        ]),
      });

      final storage = await StorageService.create(database: db);

      expect(storage.gymPhotos, hasLength(1));
      expect(storage.gymPhotos.single['id'], 'photo1.jpg');
      expect(storage.readString('ironpeak:gymPhotos'), isNull);
    });

    test('big lifts: legacy nested history is split into the table, pr/prDate stay in kv', () async {
      final db = await freshLegacyDb();
      await db.insert('kv', {
        'key': 'ironpeak:bigLifts',
        'value': jsonEncode({
          'bench': {
            'pr': 100.0,
            'prDate': '2026-01-01',
            'history': [
              {'l': '1.1', 'v': 90.0, 'isoDate': '2026-01-01'},
              {'l': '15.1', 'v': 100.0, 'isoDate': '2026-01-15'},
            ],
          },
          'deadlift': {'pr': 150.0, 'prDate': null, 'history': <dynamic>[]},
          'squat': {'pr': 0.0, 'prDate': null, 'history': <dynamic>[]},
        }),
      });

      final storage = await StorageService.create(database: db);

      expect(storage.bigLiftHistory, hasLength(2));
      expect(storage.bigLiftHistory.every((row) => row['liftKey'] == 'bench'), isTrue);

      // pr/prDate must still be readable the normal way -- only `history`
      // moved out.
      final decoded = jsonDecode(storage.readString('ironpeak:bigLifts')!) as Map<String, dynamic>;
      expect(decoded['bench']['pr'], 100.0);
      expect(decoded['bench']['prDate'], '2026-01-01');
      expect(decoded['bench']['history'], isEmpty);
    });

    test('migration never runs twice: re-opening the same file does not duplicate rows', () async {
      const path = 'test_migration_no_dupe.db';
      await databaseFactoryFfi.deleteDatabase(path);
      Future<Database> reopen() => databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) => db.execute(
                'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
              ),
            ),
          );

      final db1 = await reopen();
      await db1.insert('kv', {
        'key': 'ironpeak:bodyWeight',
        'value': jsonEncode([
          {'date': '2026-01-01', 'weight': 80.0},
        ]),
      });
      final storageA = await StorageService.create(database: db1);
      expect(storageA.bodyWeightEntries, hasLength(1));

      // Re-opening the same physical file a second time must not re-run
      // the migration and duplicate the row -- the legacy key is gone
      // after the first absorb, so this second create() finds nothing
      // left to migrate.
      final storageB = await StorageService.create(database: await reopen());
      expect(storageB.bodyWeightEntries, hasLength(1));
    });
  });

  group('migration does not clobber real data', () {
    test('a stale legacy blob never overwrites rows already in the table', () async {
      final db = await freshLegacyDb();
      // Simulate: app already migrated once, user logged a real entry
      // afterwards (so the table has data)...
      await db.insert('kv', {'key': 'kv_seed', 'value': 'x'}); // no-op, keeps db non-empty
      await StorageService.create(database: db); // creates schema

      await db.insert('body_weight_entries', {'date': '2026-02-01', 'weight': 82.0});

      // ...but a stale ironpeak:bodyWeight blob is somehow still sitting
      // in kv (shouldn't normally happen, but must never win over real
      // data if it does).
      await db.insert('kv', {
        'key': 'ironpeak:bodyWeight',
        'value': jsonEncode([
          {'date': '2020-01-01', 'weight': 999.0},
        ]),
      });

      final storage = await StorageService.create(database: db);

      expect(storage.bodyWeightEntries, hasLength(1));
      expect(storage.bodyWeightEntries.single['weight'], 82.0);
    });
  });

  group('export / import round-trip', () {
    test('exportAll produces the historical key shapes', () async {
      final storage = await StorageService.create(database: await freshLegacyDb());
      await storage.insertBodyWeightEntry({'date': '2026-01-01', 'weight': 80.0});
      await storage.insertWorkoutSession(
        {'date': '2026-01-01', 'durationMinutes': 30, 'planName': 'Legs', 'totalVolumeKg': 100.0, 'totalSets': 5},
      );
      await storage.insertBigLiftHistory({'liftKey': 'squat', 'label': '1.1', 'isoDate': '2026-01-01', 'value': 120.0});

      final exported = storage.exportAll();

      final weights = jsonDecode(exported['ironpeak:bodyWeight']!) as List;
      expect(weights.single['weight'], 80.0);

      final sessions = jsonDecode(exported['ironpeak:workoutHistory']!) as List;
      expect(sessions.single['planName'], 'Legs');

      final liftHistory = jsonDecode(exported['ironpeak:bigLiftHistory']!) as List;
      expect(liftHistory.single['liftKey'], 'squat');
      expect(liftHistory.single['v'], 120.0);
    });

    test('importAll fully replaces a table, not merges into it', () async {
      final storage = await StorageService.create(database: await freshLegacyDb());
      await storage.insertBodyWeightEntry({'date': '2026-01-01', 'weight': 80.0});
      expect(storage.bodyWeightEntries, hasLength(1));

      await storage.importAll({
        'ironpeak:bodyWeight': jsonEncode([
          {'date': '2026-03-01', 'weight': 77.0},
          {'date': '2026-03-08', 'weight': 76.5},
        ]),
      });

      expect(storage.bodyWeightEntries, hasLength(2));
      expect(storage.bodyWeightEntries.every((e) => e['weight'] != 80.0), isTrue);
    });

    test('importAll restores an old-format backup (history nested in bigLifts)', () async {
      final storage = await StorageService.create(database: await freshLegacyDb());

      await storage.importAll({
        'ironpeak:bigLifts': jsonEncode({
          'bench': {
            'pr': 105.0,
            'prDate': '2026-04-01',
            'history': [
              {'l': '1.4', 'v': 105.0, 'isoDate': '2026-04-01'},
            ],
          },
        }),
      });

      expect(storage.bigLiftHistory, hasLength(1));
      expect(storage.bigLiftHistory.single['liftKey'], 'bench');
      expect(storage.bigLiftHistory.single['value'], 105.0);
    });
  });
}
