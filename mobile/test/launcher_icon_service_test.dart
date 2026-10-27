import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ironpeak_mobile/services/launcher_icon_service.dart';
import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/appearance_provider.dart';
import 'package:ironpeak_mobile/state/theme_provider.dart';
import 'package:ironpeak_mobile/theme/launcher_icons.dart';

/// Stands in for IronpeakActivity.kt on the other end of the channel: a
/// release build ([supported]) with [enabled] aliases switched on. Records
/// every call; switching itself only ever happens natively, on exit.
class _FakeActivity {
  bool supported = true;
  List<String> enabled = ['.MainActivity'];
  bool failEverything = false;
  final List<MethodCall> calls = [];
  // Checked in tearDown: an expect() in here would only turn into a
  // PlatformException, which the service is built to swallow.
  final List<String> problems = [];

  static final List<String> _allAliases = [
    for (final v in LauncherIcons.all) v.androidAlias,
  ];

  List<String> get methods => [for (final c in calls) c.method];

  List<Object?> get targets => [
        for (final c in calls)
          if (c.method == 'setTarget') (c.arguments as Map)['target'],
      ];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    if (failEverything) throw PlatformException(code: 'boom', message: 'PackageManager died');
    final args = call.arguments as Map;
    if (!listEquals(args['aliases'] as List?, _allAliases)) {
      problems.add('${call.method} without the full alias list');
    }
    switch (call.method) {
      case 'getState':
        return {'supported': supported, 'enabled': enabled};
      case 'enableNow':
        if (enabled.isNotEmpty) return false;
        enabled = [args['target'] as String];
        return true;
      case 'setTarget':
        return null;
    }
    throw MissingPluginException();
  }
}

/// A private in-memory database per call. Not a file like providers_test's:
/// test files run in parallel. singleInstance: false, or every open of
/// [inMemoryDatabasePath] hands back the same shared database.
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

/// What the engine receives when the app goes to the background or comes
/// back, delivered the way Android delivers it.
Future<void> _lifecycle(AppLifecycleState state) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
    (_) {},
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _FakeActivity activity;
  late StorageService storage;
  late ThemeProvider theme;
  late AppearanceProvider appearance;

  setUp(() async {
    activity = _FakeActivity();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(LauncherIconService.channel, activity.handle);
    storage = await _freshStorage();
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(LauncherIconService.channel, null);
    LauncherIconService.debugResetHolds();
    expect(activity.problems, isEmpty);
  });

  /// Starts the service the way app.dart does, in [themeMode], and waits
  /// for the startup handshake.
  Future<LauncherIconService> start({String themeMode = 'light', bool android = true}) async {
    await storage.writeString('ironpeak:theme', themeMode);
    theme = ThemeProvider(storage);
    appearance = AppearanceProvider(storage);
    final service = LauncherIconService(storage, theme, appearance, platformSupported: android);
    addTearDown(service.dispose);
    await service.ready;
    await pumpEventQueue();
    return service;
  }

  group('where icons cannot switch', () {
    test('a build without aliases is only asked once', () async {
      activity
        ..supported = false
        ..enabled = [];
      final service = await start();
      expect(service.supported, isFalse);
      expect(service.pending, isFalse);

      theme.setMode('dark');
      LauncherIconService.holdSwitch();
      LauncherIconService.releaseSwitch();
      service.setAdaptive(false);
      await pumpEventQueue();
      expect(activity.methods, ['getState']);
    });

    test('off Android the channel is never touched', () async {
      final service = await start(themeMode: 'dark', android: false);
      expect(service.supported, isFalse);
      expect(service.desired.id, 'dark_green');

      theme.setMode('light');
      await pumpEventQueue();
      expect(service.desired.id, 'light_blue');
      expect(activity.calls, isEmpty);
    });
  });

  group('startup', () {
    test('disarms the activity when the icon already matches', () async {
      final service = await start();
      expect(service.supported, isTrue);
      expect(service.desired, LauncherIcons.defaultVariant);
      expect(service.pending, isFalse);
      expect(activity.methods, ['getState', 'setTarget']);
      expect(activity.targets, [null]);
    });

    test('arms the matching alias when the icon is outdated', () async {
      final service = await start(themeMode: 'dark');
      expect(service.pending, isTrue);
      expect(activity.targets, ['.LauncherIcon_dark_green']);
    });

    test('repairs a missing launcher entry right away', () async {
      activity.enabled = [];
      final service = await start(themeMode: 'dark');
      expect(activity.methods, ['getState', 'enableNow', 'setTarget']);
      expect((activity.calls[1].arguments as Map)['target'], '.LauncherIcon_dark_green');
      // Repaired with the right icon already, so nothing is left to switch.
      expect(activity.targets, [null]);
      expect(service.pending, isFalse);
    });

    test('cleans up when more than one alias is enabled', () async {
      activity.enabled = ['.MainActivity', '.LauncherIcon_dark_blue'];
      final service = await start();
      expect(service.pending, isTrue);
      expect(activity.targets, ['.MainActivity']);
    });
  });

  group('following the appearance', () {
    test('a theme change arms the new alias, changing back disarms it', () async {
      final service = await start();
      var notified = 0;
      service.addListener(() => notified++);

      theme.setMode('dark');
      await pumpEventQueue();
      expect(service.desired.id, 'dark_green');
      expect(service.pending, isTrue);
      expect(activity.targets, [null, '.LauncherIcon_dark_green']);

      theme.setMode('light');
      await pumpEventQueue();
      expect(service.pending, isFalse);
      expect(activity.targets, [null, '.LauncherIcon_dark_green', null]);
      expect(notified, 2);
    });

    test('the glyph follows the accent; other colors cause no traffic', () async {
      final service = await start();
      var notified = 0;
      service.addListener(() => notified++);

      appearance.setAccent(const Color(0xFFE24B4A));
      await pumpEventQueue();
      expect(activity.targets.last, '.LauncherIcon_light_red');

      final before = activity.calls.length;
      appearance.setSecondary(const Color(0xFF1FA76A));
      appearance.setAccent(const Color(0xFFF44336)); // another red
      await pumpEventQueue();
      expect(activity.calls, hasLength(before));
      expect(notified, 1);
    });

    test('custom mode takes the backdrop from its background', () async {
      final service = await start();
      appearance.setBg(const Color(0xFF16171B));
      theme.setMode('custom');
      await pumpEventQueue();
      expect(service.desired.id, 'dark_blue');
      expect(activity.targets.last, '.LauncherIcon_dark_blue');
    });

    test('re-reads the enabled alias when the app comes back', () async {
      final service = await start(themeMode: 'dark');
      expect(service.pending, isTrue);

      // The activity applied the switch on exit and outlived it.
      activity.enabled = ['.LauncherIcon_dark_green'];
      await _lifecycle(AppLifecycleState.paused);
      await _lifecycle(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(activity.methods.where((m) => m == 'getState'), hasLength(2));
      expect(service.pending, isFalse);
      expect(activity.targets, ['.LauncherIcon_dark_green', null]);
    });
  });

  group('guided workout guard', () {
    test('holds the switch while a workout is open', () async {
      await start(themeMode: 'dark');
      expect(activity.targets, ['.LauncherIcon_dark_green']);

      LauncherIconService.holdSwitch();
      await pumpEventQueue();
      expect(activity.targets.last, isNull);

      // Appearance changes during the workout stay disarmed...
      appearance.setAccent(const Color(0xFFE24B4A));
      await pumpEventQueue();
      expect(activity.targets.last, isNull);

      // ...until the last workout screen closes, which arms the latest one.
      LauncherIconService.holdSwitch();
      LauncherIconService.releaseSwitch();
      await pumpEventQueue();
      expect(activity.targets.last, isNull);

      LauncherIconService.releaseSwitch();
      await pumpEventQueue();
      expect(activity.targets, ['.LauncherIcon_dark_green', null, '.LauncherIcon_dark_red']);
    });

    test('an unbalanced release never goes below zero', () async {
      await start(themeMode: 'dark');
      LauncherIconService.releaseSwitch();
      LauncherIconService.holdSwitch();
      await pumpEventQueue();
      expect(activity.targets.last, isNull);
    });
  });

  group('adaptive switch', () {
    test('off pins the default icon and is remembered', () async {
      final service = await start(themeMode: 'dark');
      expect(service.adaptive, isTrue);
      expect(activity.targets, ['.LauncherIcon_dark_green']);

      service.setAdaptive(false);
      await pumpEventQueue();
      expect(service.desired, LauncherIcons.defaultVariant);
      expect(service.pending, isFalse);
      expect(activity.targets, ['.LauncherIcon_dark_green', null]);
      expect(storage.readString('ironpeak:launcherIcon:adaptive'), 'false');

      final reloaded = LauncherIconService(storage, theme, appearance, platformSupported: false);
      addTearDown(reloaded.dispose);
      expect(reloaded.adaptive, isFalse);
      expect(reloaded.desired, LauncherIcons.defaultVariant);

      service.setAdaptive(true);
      await pumpEventQueue();
      expect(service.desired.id, 'dark_green');
      expect(activity.targets.last, '.LauncherIcon_dark_green');
    });
  });

  group('own pick', () {
    test('pins the icon, turns following the appearance off, and is remembered', () async {
      final service = await start();
      const pick = LauncherIconVariant(IconBackdrop.dark, IconHue.amber);
      service.choose(pick);
      await pumpEventQueue();
      expect(service.adaptive, isFalse);
      expect(service.desired, pick);
      expect(activity.targets.last, '.LauncherIcon_dark_amber');

      // The theme no longer moves it.
      theme.setMode('dark');
      appearance.setAccent(const Color(0xFFE24B4A));
      await pumpEventQueue();
      expect(service.desired, pick);

      final reloaded = LauncherIconService(storage, theme, appearance, platformSupported: false);
      addTearDown(reloaded.dispose);
      expect(reloaded.adaptive, isFalse);
      expect(reloaded.desired, pick);
    });

    test('following the appearance again keeps the pick for later', () async {
      final service = await start();
      const pick = LauncherIconVariant(IconBackdrop.light, IconHue.teal);
      service.choose(pick);
      service.setAdaptive(true);
      await pumpEventQueue();
      expect(service.desired, LauncherIcons.defaultVariant); // light theme, default accent
      expect(service.chosen, pick);

      service.setAdaptive(false);
      expect(service.desired, pick);
    });
  });

  group('errors', () {
    test('a failing channel leaves the service unsupported, never throwing', () async {
      activity.failEverything = true;
      final service = await start(themeMode: 'dark');
      expect(service.supported, isFalse);
      theme.setMode('light');
      await pumpEventQueue();
      expect(activity.methods, ['getState']);
    });

    test('a missing channel is treated the same', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(LauncherIconService.channel, null);
      final service = await start(themeMode: 'dark');
      expect(service.supported, isFalse);
      expect(service.pending, isFalse);
    });

    test('errors after the handshake are swallowed', () async {
      final service = await start();
      activity.failEverything = true;
      theme.setMode('dark');
      LauncherIconService.holdSwitch();
      await _lifecycle(AppLifecycleState.paused);
      await _lifecycle(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(service.supported, isTrue);
      expect(activity.methods.last, 'getState');
    });
  });
}
