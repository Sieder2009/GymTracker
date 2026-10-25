// Dev utility: fills a database with realistic demo data -- a six-day
// Push/Pull/Legs plan (Thursday off), six months of workouts and exercise
// history, PR progression for the big three, a bodyweight trend, body
// measurements and a creatine streak -- so every screen has something
// real to show (e.g. for the README screenshots). Never run automatically
// and never bundled into the app itself.
//
// Usage: dart run tool/seed_demo_data.dart [path/to/ironpeak.db [locale]]
// Without a path it seeds the desktop app's own database in your
// Documents folder -- fully close the running app first (SQLite on Windows
// locks the file), and note that it replaces your plans, history, PRs and
// bodyweight there. With a path it writes a fresh file you can copy onto a
// device or emulator instead (e.g. into the debug app's app_flutter/ via
// `adb shell run-as`). A locale code after the path (e.g. `de`) sets the
// app language, as for the README screenshots.
// ignore_for_file: avoid_print
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

/// Date parts, not Duration: a 23-hour DST night can't skip a day.
DateTime _daysAgo(DateTime today, int n) => DateTime(today.year, today.month, today.day - n);

/// One planned exercise: German name exactly as in `assets/exercises.json`
/// (same names as `data/example_ppl_plan.dart`), today's working weight and
/// how much it went up per week.
class _Spec {
  const _Spec(this.name, this.sets, this.reps, this.rest, this.kg, this.weeklyGain);
  final String name;
  final int sets;
  final String reps;
  final int rest;
  final double kg;
  final double weeklyGain;
}

const List<(String, List<_Spec>?)> _week = [
  ('Montag', [
    _Spec('Bankdrücken', 4, '6-8', 150, 95, 0.6),
    _Spec('Schulterdrücken (Langhantel)', 3, '6-8', 120, 55, 0.3),
    _Spec('Kurzhantel-Schrägbankdrücken', 3, '8-10', 90, 32, 0.25),
    _Spec('Seitheben', 3, '12-15', 60, 12, 0.1),
    _Spec('Trizepsdrücken am Kabel', 3, '10-12', 60, 30, 0.2),
  ]),
  ('Dienstag', [
    _Spec('Kreuzheben', 3, '5', 180, 160, 1.2),
    _Spec('Klimmzüge', 3, '6-10', 120, 10, 0.2),
    _Spec('Langhantelrudern', 3, '8-10', 120, 80, 0.5),
    _Spec('Face Pull', 3, '15', 60, 25, 0.15),
    _Spec('Langhantel-Bizepscurls', 3, '10-12', 60, 35, 0.2),
  ]),
  ('Mittwoch', [
    _Spec('Squats', 4, '6-8', 150, 125, 0.8),
    _Spec('Rumänisches Kreuzheben', 3, '8-10', 120, 110, 0.6),
    _Spec('Beinpresse', 3, '10-12', 90, 200, 1.5),
    _Spec('Beinstrecker', 3, '12-15', 60, 55, 0.3),
    _Spec('Wadenheben (stehend)', 3, '12-15', 60, 80, 0.4),
  ]),
  ('Donnerstag', null),
  ('Freitag', [
    _Spec('Schrägbankdrücken', 4, '6-8', 150, 80, 0.5),
    _Spec('Dips', 3, '8-10', 120, 15, 0.2),
    _Spec('Arnold Press', 3, '8-10', 90, 22, 0.15),
    _Spec('Kabelzug-Crossover', 3, '12-15', 60, 17.5, 0.1),
    _Spec('Trizeps-Überkopfdrücken', 3, '10-12', 60, 25, 0.15),
  ]),
  ('Samstag', [
    _Spec('Latzug', 4, '8-10', 120, 70, 0.4),
    _Spec('T-Bar-Rudern', 3, '8-10', 120, 60, 0.4),
    _Spec('Reverse Butterfly (hintere Schulter)', 3, '12-15', 60, 15, 0.1),
    _Spec('Hammercurls', 3, '10-12', 60, 18, 0.1),
    _Spec('Scottcurls', 3, '10-12', 60, 30, 0.15),
  ]),
  ('Sonntag', [
    _Spec('Hip Thrust', 4, '8-10', 120, 140, 1.0),
    _Spec('Bulgarian Split Squats', 3, '8-10', 90, 20, 0.15),
    _Spec('Beinbeuger (liegend)', 3, '12-15', 60, 45, 0.25),
    _Spec('Abduktoren-Maschine', 3, '15-20', 45, 60, 0.3),
    _Spec('Wadenheben (sitzend)', 3, '12-15', 60, 50, 0.3),
  ]),
];

const int _historyDays = 182;

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  final String dbPath;
  if (args.isNotEmpty) {
    dbPath = args.first;
  } else {
    // USERPROFILE (Windows) / HOME (macOS/Linux) -> that user's Documents
    // folder, matching where the desktop app's StorageService keeps its
    // database. Only falls back to the current working directory if
    // neither env var is set.
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    final docs = home != null ? p.join(home, 'Documents') : Directory.current.path;
    dbPath = p.join(docs, 'ironpeak.db');
  }
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

  // The four growing collections (sessions, PR history, bodyweight, body
  // measurements) go in as their kv blobs; the app moves them into their
  // own tables on its next start, as long as those tables are still empty.
  Future<void> putRaw(String key, String value) =>
      db.insert('kv', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> put(String key, Object value) => putRaw(key, jsonEncode(value));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final rand = Random(42);

  // --- Which days were trained: the plan's training weekdays, ~85% of the
  // time, with a two-week break about three months ago. The last six days
  // are all done and the week before missed two, so this week's volume
  // reads as a step up. Today is left open.
  final trainedDays = <DateTime>[];
  for (var n = _historyDays; n >= 1; n--) {
    final date = _daysAgo(today, n);
    if (_week[date.weekday - 1].$2 == null) continue;
    if (n >= 84 && n < 98) continue; // holiday
    if (n == 7 || n == 8) continue;
    if (n > 6 && rand.nextDouble() < 0.15) continue;
    trainedDays.add(date);
  }

  double round(double kg, double step) => (kg / step).round() * step;

  Exercise makeExercise(_Spec s, int weekday) {
    final history = <HistoryEntry>[];
    for (final date in trainedDays.where((d) => d.weekday == weekday)) {
      final weeksAgo = today.difference(date).inDays / 7;
      final kg = round(s.kg - s.weeklyGain * weeksAgo, s.kg >= 40 ? 2.5 : 0.5);
      final top = int.tryParse(s.reps.split('-').last) ?? 8;
      history.add(HistoryEntry(
        weight: kg,
        reps: [for (var i = 0; i < s.sets; i++) top - rand.nextInt(3)],
        date: _iso(date),
      ));
    }
    return Exercise.fresh(
      s.name,
      '',
      s.rest,
      [for (var i = 0; i < s.sets; i++) ExerciseSet(w: s.kg, r: s.reps)],
      history: history,
    );
  }

  final program = Program(
    id: 'plan_demo_ppl',
    name: 'Push Pull Legs',
    mode: 'weekday',
    completed: trainedDays.length,
    startDate: _iso(_daysAgo(today, _historyDays)),
    days: [
      for (var i = 0; i < _week.length; i++)
        _week[i].$2 == null
            ? Day(label: _week[i].$1, rest: true)
            : Day(
                label: _week[i].$1,
                rest: false,
                exercises: [for (final s in _week[i].$2!) makeExercise(s, i + 1)],
              ),
    ],
  );

  await put('ironpeak:programs', [program.toJson()]);
  await put(
    'ironpeak:trainState',
    TrainState(activePlanId: program.id, viewedDayIdx: today.weekday - 1).toJson(),
  );

  // --- Workout history: one session per trained day, volume and length
  // from that day's exercises at the weight of the time.
  final sessions = <WorkoutSession>[];
  for (final date in trainedDays) {
    final specs = _week[date.weekday - 1].$2!;
    final weeksAgo = today.difference(date).inDays / 7;
    var volume = 0.0;
    var sets = 0;
    for (final s in specs) {
      final reps = int.tryParse(s.reps.split('-').first) ?? 8;
      volume += s.sets * reps * max(0, s.kg - s.weeklyGain * weeksAgo);
      sets += s.sets;
    }
    sessions.add(WorkoutSession(
      date: _iso(date),
      durationMinutes: 52 + rand.nextInt(26),
      planName: program.name,
      totalVolumeKg: (volume * (0.92 + rand.nextDouble() * 0.12)).roundToDouble(),
      totalSets: sets,
    ));
  }
  await put('ironpeak:workoutHistory', sessions.map((e) => e.toJson()).toList());

  // --- Big lifts: a PR every two weeks or so, rounded down to 2.5 kg so
  // the newest one is still a step up; the squat stalls for the last six
  // weeks, so the plateau notice shows up.
  BigLift makeLift(double startPr, double endPr, {int flatWeeks = 0}) {
    final history = <BigLiftPoint>[];
    const points = 13;
    for (var i = 0; i < points; i++) {
      final weeksAgo = 24 - i * 2;
      final progress = min(1.0, i / (points - 1 - flatWeeks / 2));
      final date = _daysAgo(today, weeksAgo * 7 + 4);
      history.add(BigLiftPoint(
        l: _shortLabel(date),
        v: progress == 1.0 ? endPr : ((startPr + (endPr - startPr) * progress) / 2.5).floor() * 2.5,
        isoDate: _iso(date),
      ));
    }
    return BigLift(pr: endPr, prDate: history.last.isoDate ?? _iso(today), history: history);
  }

  await put(
    'ironpeak:bigLifts',
    BigLifts(
      bench: makeLift(92.5, 105),
      deadlift: makeLift(160, 185),
      squat: makeLift(130, 145, flatWeeks: 6),
    ).toJson(),
  );

  // --- Bodyweight: weekly, slowly down from 86 to about 82 kg ---
  final bodyWeight = <BodyWeightEntry>[];
  for (var weeksAgo = 26; weeksAgo >= 0; weeksAgo--) {
    final kg = 82.4 + weeksAgo * 0.15 + (rand.nextDouble() - 0.5) * 0.6;
    bodyWeight.add(BodyWeightEntry(date: _iso(_daysAgo(today, weeksAgo * 7)), weight: (kg * 10).round() / 10));
  }
  await put('ironpeak:bodyWeight', bodyWeight.map((e) => e.toJson()).toList());

  // --- Body measurements: every eight weeks, a bit more arm and less waist ---
  await put('ironpeak:bodyMeasurements', [
    for (final (n, f) in const [(168, 0.0), (112, 0.35), (56, 0.7), (7, 1.0)])
      {
        'date': _iso(_daysAgo(today, n)),
        'chestCm': 101.0 + 3.5 * f,
        'waistCm': 88.0 - 4.0 * f,
        'hipsCm': 99.0 - 1.5 * f,
        'armCm': 37.0 + 1.6 * f,
        'thighCm': 58.5 + 1.7 * f,
        'calfCm': 38.0 + 0.6 * f,
      },
  ]);

  // --- Creatine: nearly every day for six weeks, today included ---
  await put('ironpeak:creatine:days', [
    for (var n = 45; n >= 0; n--)
      if (n != 9 && n != 27) _iso(_daysAgo(today, n)),
  ]);

  await putRaw('ironpeak:athleteIsMale', 'true');
  await putRaw('ironpeak:onboardingComplete', 'true');
  if (args.length > 1) await putRaw('ironpeak:locale', args[1]);

  await db.close();
  print('Done -- ${sessions.length} workouts, PRs, bodyweight, measurements, creatine and plan seeded.');
  print('Fully restart the app to see the data (providers load once at startup).');
}
