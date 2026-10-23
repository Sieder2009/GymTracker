import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ironpeak_mobile/services/launch_screen_service.dart';
import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/appearance_provider.dart';
import 'package:ironpeak_mobile/state/theme_provider.dart';

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
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late List<MethodCall> calls;
  late ThemeProvider theme;
  late AppearanceProvider appearance;

  setUp(() {
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(LaunchScreenService.channel,
        (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(LaunchScreenService.channel, null);
  });

  /// [themeMode] null: the user never picked a theme.
  Future<LaunchScreenService> start({String? themeMode = 'light', bool android = true}) async {
    final storage = await _freshStorage();
    if (themeMode != null) await storage.writeString('ironpeak:theme', themeMode);
    theme = ThemeProvider(storage);
    appearance = AppearanceProvider(storage);
    final service = LaunchScreenService(theme, appearance, platformSupported: android);
    addTearDown(service.dispose);
    await pumpEventQueue();
    return service;
  }

  List<Object?> sent() => [
        for (final c in calls)
          if (c.method == 'setDark') (c.arguments as Map)['dark'],
      ];

  test('tells Android the mode at startup, even when it is light', () async {
    await start();
    expect(sent(), [false]);
  });

  test('follows the theme, and only on a real change', () async {
    await start();
    theme.setMode('dark');
    await pumpEventQueue();
    appearance.setAccent(const Color(0xFFE24B4A)); // the mode stays dark
    await pumpEventQueue();
    theme.setMode('light');
    await pumpEventQueue();
    expect(sent(), [false, true, false]);
  });

  test('custom mode goes by the brightness of its background', () async {
    await start();
    appearance.setBg(const Color(0xFF16171B));
    theme.setMode('custom');
    await pumpEventQueue();
    expect(sent(), [false, true]);
  });

  test('keeps following the phone until a theme is picked', () async {
    await start(themeMode: null);
    expect(theme.followsSystem, isTrue);
    expect(sent(), [null]);

    theme.setMode(theme.mode); // picking the mode it already shows counts
    await pumpEventQueue();
    expect(theme.followsSystem, isFalse);
    expect(sent(), [null, theme.isDark]);
  });

  test('off Android the channel is never touched', () async {
    await start(themeMode: 'dark', android: false);
    theme.setMode('light');
    await pumpEventQueue();
    expect(calls, isEmpty);
  });
}
