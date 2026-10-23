import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/creatine_provider.dart';

/// A private in-memory database per call (see launcher_icon_service_test).
Future<StorageService> _freshStorage() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      ),
    ),
  );
  return StorageService.create(database: db);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  final today = DateTime(2026, 10, 22);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  test('ticks a day, unticks it again, and keeps it across a restart', () async {
    final storage = await _freshStorage();
    final creatine = CreatineProvider(storage);
    var notified = 0;
    creatine.addListener(() => notified++);

    creatine.toggle(today);
    creatine.toggle(daysAgo(1));
    expect(creatine.takenOn(today), isTrue);
    expect(creatine.takenOn(daysAgo(1)), isTrue);
    expect(creatine.takenOn(daysAgo(2)), isFalse);

    creatine.toggle(daysAgo(1)); // a wrong tick, fixed
    expect(creatine.takenOn(daysAgo(1)), isFalse);
    expect(notified, 3);

    final reloaded = CreatineProvider(storage);
    expect(reloaded.takenOn(today), isTrue);
    expect(reloaded.takenOn(daysAgo(1)), isFalse);
  });

  group('creatineStreak', () {
    Set<String> iso(List<DateTime> days) => {
          for (final d in days)
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        };

    test('counts the run up to today', () {
      expect(creatineStreak(iso([today, daysAgo(1), daysAgo(2), daysAgo(4)]), today), 3);
    });

    test('today not ticked yet counts the run up to yesterday', () {
      expect(creatineStreak(iso([daysAgo(1), daysAgo(2)]), today), 2);
    });

    test('a missed day ends it', () {
      expect(creatineStreak(iso([daysAgo(2), daysAgo(3)]), today), 0);
      expect(creatineStreak(const {}, today), 0);
    });

    test('runs across a month end', () {
      final first = DateTime(2026, 11, 1);
      expect(creatineStreak(iso([first, DateTime(2026, 10, 31), DateTime(2026, 10, 30)]), first), 3);
    });
  });
}
