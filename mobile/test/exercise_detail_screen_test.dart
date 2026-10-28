import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/l10n/app_localizations.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';
import 'package:ironpeak_mobile/overlays/exercise_detail_screen.dart';
import 'package:ironpeak_mobile/services/exercise_media_service.dart';
import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/bar_weight_provider.dart';
import 'package:ironpeak_mobile/state/exercise_media_provider.dart';
import 'package:ironpeak_mobile/state/programs_provider.dart';
import 'package:ironpeak_mobile/state/toast_provider.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _dbCounter = 0;

Future<StorageService> _freshStorage() async {
  final path = 'test_exercise_detail_${_dbCounter++}.db';
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
  // AppConfig reads .env (the screen's GitHub links); defaults are fine.
  dotenv.loadFromString(envString: '', isOptional: true);

  late StorageService storage;
  late List<Exercise> exercises;
  final saved = <List<Object>>[];

  setUp(() async {
    storage = await _freshStorage();
    // No exercise animations: they would need the shared exercise database.
    await storage.writeString('ironpeak:exerciseMediaEnabled', 'false');
    exercises = [
      Exercise.fresh('Bench', '', 90, [ExerciseSet(w: 60, r: '8'), ExerciseSet(w: 60, r: '8')]),
      Exercise.fresh('Row', '', 90, [ExerciseSet(w: 50, r: '10')]),
    ];
    saved.clear();
  });

  Widget screen() => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProgramsProvider(storage)),
          ChangeNotifierProvider(create: (_) => BarWeightProvider(storage)),
          ChangeNotifierProvider(create: (_) => ToastProvider()),
          ChangeNotifierProvider(create: (_) => ExerciseMediaProvider(storage, ExerciseMediaService())),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColors.light]),
          home: ExerciseDetailScreen(
            exercises: exercises,
            startIdx: 0,
            onSave: (idx, weight, reps) => saved.add(reps),
          ),
        ),
      );

  // The screen's vertical list -- the weight ruler and the history strip
  // scroll too.
  Finder mainScroll() => find
      .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
      .first;
  Finder repsFields() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Wdh.');
  Finder targetFields() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Ziel');

  testWidgets('typed reps survive closing and reopening the exercise', (tester) async {
    await tester.pumpWidget(screen());
    await tester.enterText(repsFields().first, '7');
    await tester.pumpWidget(const SizedBox()); // screen closed without saving
    await tester.pumpWidget(screen());

    final field = tester.widget<TextField>(repsFields().first);
    expect(field.controller!.text, '7');
  });

  testWidgets('saving drops the draft', (tester) async {
    await tester.pumpWidget(screen());
    await tester.enterText(repsFields().first, '7');
    await tester.scrollUntilVisible(find.text('Speichern & weiter'), 300, scrollable: mainScroll());
    await tester.tap(find.text('Speichern & weiter'));
    await tester.pumpAndSettle();
    expect(saved.single.first, 7);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    expect(tester.widget<TextField>(repsFields().first).controller!.text, isEmpty);
  });

  testWidgets('target reps are editable and go straight into the plan', (tester) async {
    await tester.pumpWidget(screen());
    expect(targetFields(), findsNWidgets(2));
    await tester.enterText(targetFields().at(1), '10-12');
    expect(exercises[0].sets[1].r, '10-12');
  });

  Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);
  Finder sheetField(String labelOrHint) => inSheet(find.byWidgetPredicate((w) =>
      w is TextField && (w.decoration?.labelText == labelOrHint || w.decoration?.hintText == labelOrHint)));

  // Scrolls to the hint right below the history rows (one widget, unlike a
  // row text two entries can share), then taps the newest matching row.
  Future<void> openHistoryEntry(WidgetTester tester, String rowText) async {
    await tester.scrollUntilVisible(
        find.text('Tippe auf einen Eintrag, um ihn zu korrigieren.'), 300, scrollable: mainScroll());
    await tester.ensureVisible(find.text(rowText).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(rowText).first);
    await tester.pumpAndSettle();
  }

  testWidgets('a wrongly saved history entry can be corrected, and the working weight follows',
      (tester) async {
    exercises[0].history.add(HistoryEntry(weight: 1000, reps: [8, 8], date: '2026-10-27'));
    for (final s in exercises[0].sets) {
      s.w = 1000;
    }
    await tester.pumpWidget(screen());
    expect(find.text('1000,0 kg'), findsWidgets);

    await openHistoryEntry(tester, '8 · 8');
    await tester.enterText(sheetField('Gewicht (kg)'), '100');
    await tester.enterText(sheetField('Wdh.').at(1), '7');
    await tester.tap(inSheet(find.text('Speichern')));
    await tester.pumpAndSettle();

    final entry = exercises[0].history.single;
    expect(entry.weight, 100);
    expect(entry.reps, [8, 7]);
    expect(exercises[0].sets.map((s) => s.w), [100, 100]);
    // The big weight at the top followed, so the next save can't write
    // the typo again.
    expect(find.text('1000,0 kg'), findsNothing);
    expect(find.text('8 · 7'), findsOneWidget);
  });

  testWidgets('correcting the weight keeps the stored rep markers as they are', (tester) async {
    exercises[0].history.add(HistoryEntry(weight: 122.5, reps: ['x', 8, '✓'], date: '2026-10-27'));
    await tester.pumpWidget(screen());

    await openHistoryEntry(tester, 'X · 8 · ✓');
    expect(tester.widget<TextField>(sheetField('Gewicht (kg)')).controller!.text, '122,5');
    await tester.enterText(sheetField('Gewicht (kg)'), '120');
    await tester.tap(inSheet(find.text('Speichern')));
    await tester.pumpAndSettle();

    final entry = exercises[0].history.single;
    expect(entry.weight, 120);
    expect(entry.reps, ['x', 8, '✓']);
    expect(entry.durations, isNull);
    // Sets at 60 kg weren't written from this entry, so they stay.
    expect(exercises[0].sets.map((s) => s.w), [60, 60]);
  });

  testWidgets('a cardio entry keeps its exact seconds when only a speed is changed', (tester) async {
    exercises[0]
      ..logMode = ExerciseLogMode.cardio
      ..history.add(HistoryEntry(
        weight: 0,
        reps: const [],
        date: '2026-10-27',
        mode: ExerciseLogMode.cardio,
        durations: [90, 600],
        speeds: [8.25, 10],
      ));
    await tester.pumpWidget(screen());

    await openHistoryEntry(tester, '1:30 · 10:00');
    expect(tester.widget<TextField>(sheetField('Minuten').first).controller!.text, '1,5');
    await tester.enterText(sheetField('Geschwindigkeit (km/h)').at(1), '11');
    await tester.tap(inSheet(find.text('Speichern')));
    await tester.pumpAndSettle();

    final entry = exercises[0].history.single;
    expect(entry.durations, [90, 600]);
    expect(entry.speeds, [8.25, 11]);
  });

  testWidgets('a history entry can be deleted after confirming', (tester) async {
    exercises[0].history.addAll([
      HistoryEntry(weight: 60, reps: [8, 8], date: '2026-10-20'),
      HistoryEntry(weight: 1000, reps: [8, 8], date: '2026-10-27'),
    ]);
    for (final s in exercises[0].sets) {
      s.w = 1000;
    }
    await tester.pumpWidget(screen());

    // Newest first: the 1000 kg typo.
    await openHistoryEntry(tester, '8 · 8');
    await tester.tap(inSheet(find.text('Löschen')));
    await tester.pumpAndSettle();
    expect(find.text('Eintrag löschen?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Löschen')));
    await tester.pumpAndSettle();

    expect(exercises[0].history.single.weight, 60);
    expect(exercises[0].sets.map((s) => s.w), [60, 60]);
    expect(find.text('1000,0 kg'), findsNothing);
  });

  testWidgets('the end of the screen shows what comes next', (tester) async {
    await tester.pumpWidget(screen());
    await tester.scrollUntilVisible(find.text('ALS NÄCHSTES'), 400, scrollable: mainScroll());
    expect(find.text('Row'), findsOneWidget);

    await tester.tap(find.text('Row'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ALS NÄCHSTES'), 400, scrollable: mainScroll());
    expect(find.text('Das ist die letzte Übung – danach bist du fertig.'), findsOneWidget);
  });
}
