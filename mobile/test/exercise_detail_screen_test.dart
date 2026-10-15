import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/l10n/app_localizations.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
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
