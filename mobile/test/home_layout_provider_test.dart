import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/home_layout_provider.dart';

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

  test('the next-workout card is off by default and the choice survives a restart', () async {
    final storage = await _freshStorage();
    final layout = HomeLayoutProvider(storage);
    var notified = 0;
    layout.addListener(() => notified++);
    expect(layout.showNextWorkout, isFalse);

    layout.setShowNextWorkout(true);
    layout.setShowNextWorkout(true); // no change, no rebuild
    expect(layout.showNextWorkout, isTrue);
    expect(notified, 1);
    expect(HomeLayoutProvider(storage).showNextWorkout, isTrue);

    layout.setShowNextWorkout(false);
    expect(HomeLayoutProvider(storage).showNextWorkout, isFalse);
  });

  test('the start-workout button is off by default and switches on its own', () async {
    final storage = await _freshStorage();
    final layout = HomeLayoutProvider(storage);
    expect(layout.showStartWorkout, isFalse);

    layout.setShowStartWorkout(true);
    final reloaded = HomeLayoutProvider(storage);
    expect(reloaded.showStartWorkout, isTrue);
    expect(reloaded.showNextWorkout, isFalse);
  });
}
