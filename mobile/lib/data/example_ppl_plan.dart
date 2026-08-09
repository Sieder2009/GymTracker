import 'constants.dart';
import '../models/day.dart';
import '../models/exercise.dart';
import '../models/exercise_set.dart';
import '../models/program.dart';

class _ExerciseSpec {
  const _ExerciseSpec(this.name, this.sets, this.reps, this.restSeconds);
  final String name;
  final int sets;
  final String reps;
  final int restSeconds;
}

/// One classic 6-day Push/Pull/Legs rotation, mapped onto real weekdays
/// (Sunday rest) rather than the app's largely-unfinished `'rotation'`
/// mode (`Program.currentDayIdx` is never advanced anywhere in this
/// codebase, so a rotation-mode plan would show the same day forever).
/// Exercise names/ids are verified verbatim against `assets/exercises.json`
/// (see `test/example_ppl_plan_test.dart`) so this can't silently drift out
/// of sync if the shared exercise database changes later.
const List<List<_ExerciseSpec>> _pplWeek = [
  // Montag — Push A
  [
    _ExerciseSpec('Bankdrücken', 4, '6-8', 150),
    _ExerciseSpec('Schulterdrücken (Langhantel)', 3, '6-8', 120),
    _ExerciseSpec('Kurzhantel-Schrägbankdrücken', 3, '8-10', 90),
    _ExerciseSpec('Seitheben', 3, '12-15', 60),
    _ExerciseSpec('Trizepsdrücken am Kabel', 3, '10-12', 60),
  ],
  // Dienstag — Pull A
  [
    _ExerciseSpec('Kreuzheben', 3, '5', 180),
    _ExerciseSpec('Klimmzüge', 3, '6-10', 120),
    _ExerciseSpec('Langhantelrudern', 3, '8-10', 120),
    _ExerciseSpec('Face Pull', 3, '15', 60),
    _ExerciseSpec('Langhantel-Bizepscurls', 3, '10-12', 60),
  ],
  // Mittwoch — Legs A
  [
    _ExerciseSpec('Squats', 4, '6-8', 150),
    _ExerciseSpec('Rumänisches Kreuzheben', 3, '8-10', 120),
    _ExerciseSpec('Beinpresse', 3, '10-12', 90),
    _ExerciseSpec('Beinstrecker', 3, '12-15', 60),
    _ExerciseSpec('Wadenheben (stehend)', 3, '12-15', 60),
  ],
  // Donnerstag — Push B
  [
    _ExerciseSpec('Schrägbankdrücken', 4, '6-8', 150),
    _ExerciseSpec('Dips', 3, '8-10', 120),
    _ExerciseSpec('Arnold Press', 3, '8-10', 90),
    _ExerciseSpec('Kabelzug-Crossover', 3, '12-15', 60),
    _ExerciseSpec('Trizeps-Überkopfdrücken', 3, '10-12', 60),
  ],
  // Freitag — Pull B
  [
    _ExerciseSpec('Latzug', 4, '8-10', 120),
    _ExerciseSpec('T-Bar-Rudern', 3, '8-10', 120),
    _ExerciseSpec('Reverse Butterfly (hintere Schulter)', 3, '12-15', 60),
    _ExerciseSpec('Hammercurls', 3, '10-12', 60),
    _ExerciseSpec('Scottcurls', 3, '10-12', 60),
  ],
  // Samstag — Legs B
  [
    _ExerciseSpec('Hip Thrust', 4, '8-10', 120),
    _ExerciseSpec('Bulgarian Split Squats', 3, '8-10', 90),
    _ExerciseSpec('Beinbeuger (liegend)', 3, '12-15', 60),
    _ExerciseSpec('Abduktoren-Maschine', 3, '15-20', 45),
    _ExerciseSpec('Wadenheben (sitzend)', 3, '12-15', 60),
  ],
];

const List<String> pplDayMarkers = [
  'Push-Tag A',
  'Pull-Tag A',
  'Bein-Tag A',
  'Push-Tag B',
  'Pull-Tag B',
  'Bein-Tag B',
];

/// Builds a fresh, ready-to-train Push/Pull/Legs [Program] -- every set
/// starts at 0kg/bodyweight, same as a freshly hand-built plan; the user
/// dials in real working weights via the guided workout's stepper as they
/// go. [name] is passed in rather than hardcoded so callers can supply a
/// localized display name without this file depending on `AppLocalizations`.
Program buildExamplePplProgram({required String name}) {
  final days = <Day>[
    for (var i = 0; i < 6; i++)
      Day(
        label: kWeekdays[i],
        rest: false,
        exercises: [
          for (var j = 0; j < _pplWeek[i].length; j++)
            Exercise.fresh(
              _pplWeek[i][j].name,
              '',
              _pplWeek[i][j].restSeconds,
              List.generate(
                _pplWeek[i][j].sets,
                (_) => ExerciseSet(w: 0, r: _pplWeek[i][j].reps),
              ),
              note: j == 0 ? pplDayMarkers[i] : '',
            ),
        ],
      ),
    Day(label: kWeekdays[6], rest: true), // Sonntag
  ];

  return Program(
    id: 'plan_ppl_${DateTime.now().millisecondsSinceEpoch}',
    name: name,
    mode: 'weekday',
    startDate: todayIso(),
    days: days,
  );
}
