import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/l10n/app_localizations.dart';
import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/bar_weight_provider.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:ironpeak_mobile/widgets/plate_calculator_sheet.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _dbCounter = 0;

Future<StorageService> _freshStorage() async {
  final path = 'test_plate_calculator_${_dbCounter++}.db';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('BarWeightProvider plates', () {
    test('every standard plate is available until switched off', () async {
      final equipment = BarWeightProvider(await _freshStorage());
      expect(equipment.availablePlates(kg: true), [25, 20, 15, 10, 5, 2.5, 1.25, 0.5]);
      expect(equipment.availablePlates(kg: false), [45, 35, 25, 10, 5, 2.5]);
    });

    test('plate choices survive a reload; unknown plates are ignored', () async {
      final storage = await _freshStorage();
      BarWeightProvider(storage)
        ..setPlateAvailable(20, kg: true, available: false)
        ..setPlateAvailable(0.5, kg: true, available: false)
        ..setPlateAvailable(7, kg: true, available: true);

      final reloaded = BarWeightProvider(storage);
      expect(reloaded.availablePlates(kg: true), [25, 15, 10, 5, 2.5, 1.25]);
      expect(reloaded.availablePlates(kg: false), [45, 35, 25, 10, 5, 2.5]);
    });

    test('the last plate left cannot be switched off', () async {
      final equipment = BarWeightProvider(await _freshStorage());
      for (final plate in [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]) {
        equipment.setPlateAvailable(plate, kg: false, available: false);
      }
      expect(equipment.availablePlates(kg: false), [2.5]);
    });
  });

  testWidgets('finds the plates for a weight, and adds tapped plates up', (tester) async {
    final equipment = BarWeightProvider(await tester.runAsync(_freshStorage) as StorageService);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: equipment,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const Scaffold(body: PlateCalculatorSheet()),
      ),
    ));
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    final fields = find.byType(TextField);
    String emptyWeight() => tester.widget<TextField>(fields.last).controller!.text;

    // The empty weight starts at the bar weight from Settings.
    expect(emptyWeight(), '20');

    // 260 kg on a leg press (sled not counted): 130 a side.
    await tester.enterText(fields.first, '260');
    await tester.enterText(fields.last, '0');
    await tester.tap(find.text(t.actionCalculate));
    await tester.pump();
    expect(find.text('25 kg'), findsNWidgets(5));
    expect(find.text('5 kg'), findsOneWidget);

    // No 25s in this gym: the result updates at once, and the choice sticks.
    await tester.ensureVisible(find.widgetWithText(FilterChip, '25'));
    await tester.tap(find.widgetWithText(FilterChip, '25'));
    await tester.pump();
    expect(find.text('25 kg'), findsNothing);
    expect(find.text('20 kg'), findsNWidgets(6));
    expect(find.text('10 kg'), findsOneWidget);
    expect(equipment.availablePlates(kg: true), isNot(contains(25)));

    // The other way round: 20, then 10, then 25 on each side of a 20 kg bar.
    await tester.tap(find.text(t.plateModeAddUp));
    await tester.pump();
    await tester.enterText(fields.last, '20');
    for (final plate in ['+ 20', '+ 10', '+ 25']) {
      await tester.tap(find.text(plate));
      await tester.pump();
    }
    expect(find.text('${t.labelPerSide}: 55 kg'), findsOneWidget);
    expect(find.text('130 kg'), findsOneWidget);

    // Taking the 10 off again.
    await tester.tap(find.descendant(
      of: find.widgetWithText(InputChip, '10 kg'),
      matching: find.byIcon(Icons.clear),
    ));
    await tester.pump();
    expect(find.text('110 kg'), findsOneWidget);

    await tester.tap(find.text(t.actionClearPlates));
    await tester.pump();
    expect(find.byType(InputChip), findsNothing);
    expect(find.text('20 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
