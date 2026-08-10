// Dev utility: fills the real on-device database with realistic demo data
// (a Push/Pull/Legs plan, 8 weeks of workout history, PR progression,
// bodyweight trend) so the analytics screens have something real to show
// instead of empty states. Never run automatically — this is for local
// development only, never bundled into the app itself.
//
// Usage: dart run tool/seed_demo_data.dart
// (fully close the running app first — SQLite on Windows locks the file)
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ironpeak_mobile/models/big_lift.dart';
import 'package:ironpeak_mobile/models/body_weight_entry.dart';
import 'package:ironpeak_mobile/models/day.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';
import 'package:ironpeak_mobile/models/program.dart';
import 'package:ironpeak_mobile/models/train_state.dart';
import 'package:ironpeak_mobile/models/workout_session.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _shortLabel(DateTime d) => '${d.day}.${d.month}';

Future<void> main() async {
  sqfliteFfiInit();
  // USERPROFILE (Windows) / HOME (macOS/Linux) -> that user's Documents
  // folder, matching where the real app's StorageService actually keeps
  // its database. Only falls back to the current working directory (which
  // used to be the unconditional default here, and would silently land
  // ironpeak.db inside this repo when run as `dart run tool/seed_demo_data
  // .dart` from mobile/) if neither env var is set.
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  final docs = home != null ? p.join(home, 'Documents') : Directory.current.path;
  final dbPath = p.join(docs, 'ironpeak.db');
  print('Seeding $dbPath ...');

  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      ),
    ),
  );

  Future<void> put(String key, Object value) async {
    await db.insert(
      'kv',
      {'key': key, 'value': jsonEncode(value)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  final today = DateTime(2026, 8, 7);
  final rand = Random(42);

  // --- Training plan: Push/Pull/Legs, 3-on-1-off, 8 weeks of history ---
  Exercise makeExercise(String name, double startW, double weeklyGainKg, {String note = ''}) {
    final history = <HistoryEntry>[];
    var w = startW;
    for (var weekAgo = 8; weekAgo >= 0; weekAgo--) {
      final date = today.subtract(Duration(days: weekAgo * 7));
      w += weeklyGainKg + (rand.nextDouble() - 0.5); // small natural noise
      w = (w * 2).round() / 2;
      history.add(HistoryEntry(weight: w, reps: [8, 8, 7], date: _iso(date)));
    }
    return Exercise.fresh(
      name,
      '',
      90,
      [ExerciseSet(w: w, r: '8'), ExerciseSet(w: w, r: '8'), ExerciseSet(w: w, r: '6-8')],
      history: history,
      note: note,
    );
  }

  final pushDay = Day(label: 'Montag', rest: false, exercises: [
    makeExercise('Bankdrücken', 60, 0.6),
    makeExercise('Schulterdrücken', 30, 0.3),
    makeExercise('Trizepsdrücken am Kabel', 20, 0.2),
  ]);
  final pullDay = Day(label: 'Dienstag', rest: false, exercises: [
    makeExercise('Kreuzheben', 100, 0.9),
    makeExercise('Klimmzüge', 0, 0, note: 'Zusatzgewicht'),
    makeExercise('Langhantelrudern', 55, 0.4),
  ]);
  final legDay = Day(label: 'Mittwoch', rest: false, exercises: [
    makeExercise('Squats', 90, 0.05), // deliberately near-flat -> plateau demo
    makeExercise('Beinpresse', 120, 0.5),
    makeExercise('Wadenheben', 60, 0.2),
  ]);
  final restDay = Day(label: 'Donnerstag', rest: true);

  final program = Program(
    id: 'plan_demo_ppl',
    name: 'Push Pull Legs',
    mode: 'weekday',
    completed: 24,
    currentDayIdx: 0,
    startDate: _iso(today.subtract(const Duration(days: 63))),
    days: [
      pushDay,
      pullDay,
      legDay,
      restDay,
      Day(label: 'Freitag', rest: true),
      Day(label: 'Samstag', rest: true),
      Day(label: 'Sonntag', rest: true),
    ],
    dailyExercises: [
      makeExercise('Unterarmtraining', 15, 0.1),
    ],
  );

  await put('ironpeak:programs', [program.toJson()]);
  await put(
    'ironpeak:trainState',
    TrainState(activePlanId: program.id, viewedDayIdx: 0).toJson(),
  );

  // --- Big lifts: bench trending up, deadlift trending up, squat flat ---
  BigLift makeLift(double startPr, double weeklyGainKg) {
    final history = <BigLiftPoint>[];
    var v = startPr;
    for (var weekAgo = 8; weekAgo >= 1; weekAgo--) {
      final date = today.subtract(Duration(days: weekAgo * 7));
      v += weeklyGainKg;
      v = (v * 2).round() / 2;
      history.add(BigLiftPoint(l: _shortLabel(date), v: v, isoDate: _iso(date)));
    }
    final prDate = today.subtract(const Duration(days: 3));
    return BigLift(pr: v + weeklyGainKg, prDate: _iso(prDate), history: history);
  }

  final bigLifts = BigLifts(
    bench: makeLift(85, 1.1),
    deadlift: makeLift(130, 1.6),
    squat: makeLift(110, 0.1), // flat -> plateau notice shows up
  );
  await put('ironpeak:bigLifts', bigLifts.toJson());

  // --- Bodyweight: gentle downward trend over 8 weeks ---
  final bodyWeightEntries = <BodyWeightEntry>[];
  var bw = 84.2;
  for (var weekAgo = 8; weekAgo >= 0; weekAgo--) {
    final date = today.subtract(Duration(days: weekAgo * 7));
    bw -= 0.22 + (rand.nextDouble() - 0.5) * 0.2;
    bodyWeightEntries.add(BodyWeightEntry(date: _iso(date), weight: (bw * 10).round() / 10));
  }
  await put('ironpeak:bodyWeight', bodyWeightEntries.map((e) => e.toJson()).toList());

  // --- Workout history: 3-on/1-off cycle for 8 weeks, ends on/near today ---
  final sessions = <WorkoutSession>[];
  var cycleIdx = 0;
  for (var daysAgo = 58; daysAgo >= 0; daysAgo--) {
    final date = today.subtract(Duration(days: daysAgo));
    final posInCycle = (58 - daysAgo) % 4; // 3 train days, 1 rest day
    if (posInCycle == 3) continue; // rest day in the cycle
    cycleIdx = posInCycle;
    final baseVolume = 4200.0 + cycleIdx * 400;
    sessions.add(WorkoutSession(
      date: _iso(date),
      durationMinutes: 48 + rand.nextInt(20),
      planName: program.name,
      totalVolumeKg: (baseVolume + rand.nextInt(600)).roundToDouble(),
      totalSets: 18 + rand.nextInt(5),
    ));
  }
  await put('ironpeak:workoutHistory', sessions.map((e) => e.toJson()).toList());

  await put('ironpeak:athleteIsMale', true);

  await db.close();
  print('Done — ${sessions.length} workout sessions, PRs, bodyweight and plan seeded.');
  print('Fully restart the app to see the data (providers load once at startup).');
}
