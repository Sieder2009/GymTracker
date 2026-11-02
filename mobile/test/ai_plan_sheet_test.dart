import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/l10n/app_localizations.dart';
import 'package:ironpeak_mobile/models/exercise_template.dart';
import 'package:ironpeak_mobile/services/ai_plan_prompt.dart';
import 'package:ironpeak_mobile/services/exercise_database_service.dart';
import 'package:ironpeak_mobile/services/storage_service.dart';
import 'package:ironpeak_mobile/state/athlete_settings_provider.dart';
import 'package:ironpeak_mobile/state/bar_weight_provider.dart';
import 'package:ironpeak_mobile/state/big_lifts_provider.dart';
import 'package:ironpeak_mobile/state/body_weight_provider.dart';
import 'package:ironpeak_mobile/state/custom_exercises_provider.dart';
import 'package:ironpeak_mobile/state/effort_scale_provider.dart';
import 'package:ironpeak_mobile/state/exercise_database_provider.dart';
import 'package:ironpeak_mobile/state/programs_provider.dart';
import 'package:ironpeak_mobile/state/toast_provider.dart';
import 'package:ironpeak_mobile/state/train_state_provider.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:ironpeak_mobile/widgets/ai_plan_sheet.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Memory-only storage: StorageService falls back to that when its database
/// can't be used (here: one that is already closed), so nothing in these
/// widget tests waits on real disk I/O inside the fake clock.
Future<StorageService> _memoryStorage() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.close();
  return StorageService.create(database: db);
}

/// The bundled database, served without touching the network.
class _OfflineDatabase extends ExerciseDatabaseService {
  _OfflineDatabase(this.templates);

  final List<ExerciseTemplate> templates;

  @override
  Future<List<ExerciseTemplate>> fetchFromGitHub({Duration timeout = const Duration(seconds: 8)}) async =>
      templates;

  @override
  Future<List<ExerciseTemplate>> loadBundled() async => templates;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final decoded = jsonDecode(File('assets/exercises.json').readAsStringSync()) as Map<String, dynamic>;
  final library = [
    for (final e in decoded['exercises'] as List) ExerciseTemplate.fromJson(e as Map<String, dynamic>),
  ];
  const aiAnswer = 'Hier ist dein Plan:\n\n```json\n$kAiPlanPromptExample\n```\n\nKopiere den Code-Block.';

  late StorageService storage;
  late ToastProvider toast;
  late ProgramsProvider programs;
  late TrainStateProvider trainState;
  late CustomExercisesProvider custom;
  String? clipboard;

  setUp(() async {
    storage = await _memoryStorage();
    toast = ToastProvider();
    programs = ProgramsProvider(storage);
    trainState = TrainStateProvider(storage);
    custom = CustomExercisesProvider(storage);
    clipboard = null;
  });

  Future<void> pumpHost(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboard = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return clipboard == null ? null : {'text': clipboard};
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider.value(value: toast),
        ChangeNotifierProvider.value(value: programs),
        ChangeNotifierProvider.value(value: trainState),
        ChangeNotifierProvider.value(value: custom),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => ExerciseDatabaseProvider(storage, _OfflineDatabase(library)),
        ),
        ChangeNotifierProvider(create: (_) => BodyWeightProvider(storage)),
        ChangeNotifierProvider(create: (_) => BigLiftsProvider(storage)),
        ChangeNotifierProvider(create: (_) => AthleteSettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => BarWeightProvider(storage)),
        ChangeNotifierProvider(create: (_) => EffortScaleProvider(storage)),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(onPressed: () => copyAiPlanPrompt(context), child: const Text('copy')),
                TextButton(onPressed: () => importAiPlanFromClipboard(context), child: const Text('paste')),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Lets the toast's auto-hide timer run out before the test ends.
  Future<void> finish(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

  testWidgets('copying puts the whole prompt on the clipboard, with my data only when allowed', (tester) async {
    custom.add('Meine Spezialübung', 'arms');
    await pumpHost(tester);

    await tester.tap(find.text('copy'));
    await tester.pump();
    expect(clipboard, contains('Talk to me in German'));
    expect(clipboard, contains('"Einstellungen" → "KI-TRAININGSPLAN" → "Plan von der KI einfügen"'));
    expect(clipboard, contains('Bankdrücken | Schrägbankdrücken'));
    expect(clipboard, contains('Meine Spezialübung (arms)'));
    expect(clipboard, contains('ABOUT ME'));
    expect(toast.message, 'Kopiert – jetzt in ChatGPT, Claude oder Gemini einfügen');

    setAiPromptIncludesMyData(storage, false);
    await tester.tap(find.text('copy'));
    await tester.pump();
    expect(clipboard, isNot(contains('ABOUT ME')));
    await finish(tester);
  });

  testWidgets('pasting the copied instructions back explains the mix-up instead of importing their example',
      (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('copy'));
    await tester.pump();

    await tester.tap(find.text('paste'));
    await tester.pumpAndSettle();
    expect(
      find.text('Das ist die Anleitung für die KI, nicht ihre Antwort. '
          'Füge sie in einen KI-Chat ein und kopiere dann, was die KI antwortet.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(programs.programs, isEmpty);
    await finish(tester);
  });

  testWidgets('pasting the AI\'s answer asks once, then adds the plan and makes it active', (tester) async {
    await pumpHost(tester);
    clipboard = aiAnswer;

    await tester.tap(find.text('paste'));
    await tester.pumpAndSettle();
    expect(find.text('„Full body 2x“ als neuen Plan hinzufügen und gleich aktivieren?'), findsOneWidget);
    expect(find.text('2 Trainingstage · 7 Übungen'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Plan importieren'));
    await tester.pumpAndSettle();
    final plan = programs.programs.single;
    expect(plan.name, 'Full body 2x');
    expect(trainState.activePlanId, plan.id);
    expect(toast.message, 'Plan importiert und aktiviert');
    await finish(tester);
  });

  testWidgets('a cut-off answer still imports what is complete, with a warning in the question', (tester) async {
    await pumpHost(tester);
    clipboard = aiAnswer.substring(0, aiAnswer.indexOf('"label": "Mittwoch"'));

    await tester.tap(find.text('paste'));
    await tester.pumpAndSettle();
    expect(
      find.text('Die Antwort ist abgeschnitten, das Ende des Plans fehlt. '
          'Kilo übernimmt, was da ist; fehlende Tage werden Ruhetage.'),
      findsOneWidget,
    );
    expect(find.text('1 Trainingstag · 3 Übungen'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(programs.programs, isEmpty);
  });

  testWidgets('cancelling the question adds nothing', (tester) async {
    await pumpHost(tester);
    clipboard = aiAnswer;

    await tester.tap(find.text('paste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(programs.programs, isEmpty);
  });

  testWidgets('without a plan on the clipboard the sheet explains why and takes a pasted answer', (tester) async {
    await pumpHost(tester);

    await tester.tap(find.text('paste'));
    await tester.pumpAndSettle();
    expect(find.text('Noch nichts zum Importieren – kopiere zuerst die Antwort der KI.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Welche Tage passen dir?');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Plan importieren'));
    await tester.pumpAndSettle();
    expect(find.text('Das ist kein Kilo-Plan. Kopiere die ganze Antwort der KI samt Code-Block.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), aiAnswer);
    await tester.pump();
    expect(find.textContaining('Das ist kein Kilo-Plan'), findsNothing, reason: 'typing clears the old error');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Plan importieren'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Plan importieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Plan importieren'));
    await tester.pumpAndSettle();

    expect(programs.programs.single.name, 'Full body 2x');
    expect(find.byType(TextField), findsNothing, reason: 'the sheet closes after the import');
    await finish(tester);
  });
}
