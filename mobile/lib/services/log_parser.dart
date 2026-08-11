import '../data/constants.dart';
import '../models/day.dart';
import '../models/exercise.dart';
import '../models/exercise_set.dart';
import '../models/history_entry.dart';

// A line is treated as a SET/WEIGHT
// line if it starts with a digit (e.g. "135kg x5 2.1 1.1 ...", "72,5kg x1
// 5.4", "1x 20.19.15.10"). Anything else starting a new paragraph is an
// EXERCISE NAME line, optionally carrying a "NxM" or "NxM-M" scheme (sets x
// reps), e.g. "Deadlift 2x3 nt muskelversagen" or "Klimmzüge 2x6-10".
final RegExp _setLine = RegExp(r'^\d');
final RegExp _dayHeader =
    RegExp(r'^(\d+)\s*\.\s*Wochentag', caseSensitive: false);
final RegExp _dividerLine = RegExp(r'^[=\-_*]{3,}$');
final RegExp _scheme =
    RegExp(r'(\d+)\s*x\s*([\d]+(?:\s*-\s*[\d]+)?)', caseSensitive: false);
final RegExp _weightRe =
    RegExp(r'^(\d+(?:[.,]\d+)?)\s*kg', caseSensitive: false);
final RegExp _prHeader = RegExp(r'^1?\s*PR\s*\(([^)]*)\)', caseSensitive: false);
final RegExp _dateInText = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})');
final RegExp _prLine =
    RegExp(r'^([^\d]+?)\s+(\d+(?:[.,]\d+)?)\s*kg', caseSensitive: false);
final RegExp _xMarker = RegExp(r'^\d*x\d*$', caseSensitive: false);
final RegExp _kgAnywhere = RegExp(r'kg', caseSensitive: false);
final RegExp _trailingDash = RegExp(r'[-–]\s*$');
final RegExp _multiSpace = RegExp(r'\s{2,}');
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _parenGroup = RegExp(r'\(([^)]*)\)');
final RegExp _digitsOnly = RegExp(r'^\d+$');
final RegExp _dotsOnly = RegExp(r'^\.+$');
final RegExp _newline = RegExp(r'\r?\n');

double _parseWeight(String line) {
  final m = _weightRe.firstMatch(line);
  if (m == null) return 0;
  return double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
}

String _cleanName(String line) {
  var s = line.replaceFirst(_scheme, '');
  s = s.replaceFirst(_trailingDash, '');
  s = s.replaceAll(_multiSpace, ' ');
  return s.trim();
}

class _NameNote {
  _NameNote(this.name, this.note);
  final String name;
  final String note;
}

// Splits a leading "(...)" style aside from an exercise name line into a
// separate note (machine setting like "(Stufe 14)" or an execution cue like
// "(Rücken und Beine gerade)") so it can be shown on its own instead of
// disappearing into the name.
_NameNote _splitNameNote(String line) {
  final parenMatch = _parenGroup.firstMatch(line);
  final note = parenMatch != null ? (parenMatch.group(1) ?? '').trim() : '';
  final withoutParen = line.replaceFirst(_parenGroup, '');
  return _NameNote(_cleanName(withoutParen), note);
}

// Reads the per-set reps trailing a weight line, e.g. "135 kg x5  2.1  1.1
// 3.2" -> [2,1,1,1,3,2] (each "N.M" token is 2+ sets: first number = set 1,
// second = set 2, ...). Letters (x/m, per the log's own legend: x = weniger
// Gewicht, m = mehr Gewicht) are kept as-is. A token made only of dots (e.g.
// "....." for an exercise with no rep count, like bodyweight holds) means
// "done, no reps logged" — recorded as '✓' once per dot-split segment
// (`tok.split('.').length` is dots+1, so a 3-dot token yields 4 checkmarks).
List<Object> _parseHistoryReps(String line) {
  final tokens = line.trim().split(_whitespace);
  final xIdx = tokens.indexWhere((t) => _xMarker.hasMatch(t));
  if (xIdx == -1) return [];
  final reps = <Object>[];
  for (final tok in tokens.sublist(xIdx + 1)) {
    if (tok == '—' || tok == '-') continue;
    if (_dotsOnly.hasMatch(tok)) {
      final segments = tok.split('.').length;
      for (var i = 0; i < segments; i++) {
        reps.add('✓');
      }
      continue;
    }
    for (final part in tok.split('.')) {
      if (part.isEmpty) continue;
      reps.add(_digitsOnly.hasMatch(part) ? int.parse(part) : part.toLowerCase());
    }
  }
  return reps;
}

/// A single parsed exercise entry (day-scoped or "every training day").
///
/// Named `setCount` (not `sets`) to avoid colliding with [Exercise.sets],
/// which is a `List<ExerciseSet>`.
class ParsedExercise {
  ParsedExercise({
    required this.name,
    required this.note,
    required this.setCount,
    required this.reps,
    required this.weight,
    required this.history,
  });

  final String name;
  final String note;
  final int setCount;
  final String reps;
  final double weight;
  final List<HistoryEntry> history;
}

class ParsedDay {
  ParsedDay({required this.num, required this.exercises});
  final int num;
  final List<ParsedExercise> exercises;
}

class ParsedPr {
  double? bench;
  double? deadlift;
  double? squat;
  String? date; // 'YYYY-MM-DD'
}

class ParsedLog {
  ParsedLog({
    required this.days,
    required this.dailyExercises,
    required this.pr,
    required this.warnings,
  });

  final List<ParsedDay> days;
  final List<ParsedExercise> dailyExercises;
  final ParsedPr pr;
  final List<String> warnings;
}

class ParsedBlock {
  ParsedBlock({required this.weight, required this.history});
  final double weight;
  final List<HistoryEntry> history;
}

class _CurrentExercise {
  _CurrentExercise({
    this.name,
    this.note = '',
    this.setCount = 2,
    this.reps = '8',
    this.weight = 0,
    this.sawKg = false,
  }) : history = [];

  String? name;
  String note;
  int setCount;
  String reps;
  double weight;
  bool sawKg;
  final List<HistoryEntry> history;
}

// Collects lines into exercise entries (name line -> following weight
// lines), shared between day-scoped and "every training day" exercises.
class _Accumulator {
  _Accumulator(this._out, this._warnings, this._contextLabel);

  final List<ParsedExercise> _out;
  final List<String> _warnings;
  final String _contextLabel;
  _CurrentExercise? _current;

  void flush() {
    final cur = _current;
    if (cur != null) {
      // A name line with no weight line at all before the next one (e.g.
      // two exercise-name lines in a row, or a decorative "====" divider
      // that slipped through) leaves nothing to show — skip it instead of
      // adding an empty card with no real history.
      final isEmpty = cur.weight == 0 && !cur.sawKg && cur.history.isEmpty;
      if (!isEmpty) {
        if (cur.weight == 0 && cur.sawKg) {
          _warnings.add(
            '"${cur.name}" ($_contextLabel): kein Gewicht erkannt, wird als '
            'Körpergewicht geführt.',
          );
        }
        final name = (cur.name == null || cur.name!.isEmpty)
            ? 'Unbenannte Übung'
            : cur.name!;
        _out.add(ParsedExercise(
          name: name,
          note: cur.note,
          setCount: cur.setCount,
          reps: cur.reps,
          weight: cur.weight,
          history: cur.history,
        ));
      }
    }
    _current = null;
  }

  void consumeLine(String raw) {
    if (_setLine.hasMatch(raw)) {
      _current ??= _CurrentExercise();
      final cur = _current!;
      final w = _parseWeight(raw);
      if (_kgAnywhere.hasMatch(raw)) cur.sawKg = true;
      if (w > cur.weight) cur.weight = w;
      final reps = _parseHistoryReps(raw);
      if (reps.isNotEmpty) cur.history.add(HistoryEntry(weight: w, reps: reps));
    } else {
      flush();
      final schemeMatch = _scheme.firstMatch(raw);
      int setCount;
      String reps;
      if (schemeMatch != null) {
        final parsed = int.parse(schemeMatch.group(1)!);
        setCount = parsed < 1 ? 1 : parsed;
        reps = schemeMatch.group(2)!.replaceAll(_whitespace, '');
      } else {
        setCount = 2;
        reps = '8';
      }
      final nn = _splitNameNote(raw);
      _current = _CurrentExercise(
        name: nn.name,
        note: nn.note,
        setCount: setCount,
        reps: reps,
      );
    }
  }
}

/// Parses a raw pasted/uploaded training log into structured plan data.
ParsedLog parseLog(String text) {
  final lines = text.split(_newline).map((l) => l.trim()).toList();
  final days = <ParsedDay>[];
  final warnings = <String>[];
  final pr = ParsedPr();
  final dailyExercises = <ParsedExercise>[];

  var mode = 'preamble'; // 'preamble' | 'pr' | 'day'
  _Accumulator? dayAcc;
  final preambleAcc = _Accumulator(dailyExercises, warnings, 'jeden Trainingstag');

  for (final raw in lines) {
    if (raw.isEmpty) {
      if (mode == 'pr') mode = 'preamble';
      continue;
    }
    if (_dividerLine.hasMatch(raw)) continue; // "====" / "----" dividers

    final dayMatch = _dayHeader.firstMatch(raw);
    if (dayMatch != null) {
      dayAcc?.flush();
      preambleAcc.flush();
      final dayNum = int.parse(dayMatch.group(1)!);
      final currentDay = ParsedDay(num: dayNum, exercises: []);
      days.add(currentDay);
      dayAcc = _Accumulator(currentDay.exercises, warnings, 'Tag $dayNum');
      mode = 'day';
      continue;
    }

    if (mode != 'day') {
      final prMatch = _prHeader.firstMatch(raw);
      if (prMatch != null) {
        mode = 'pr';
        final dm = _dateInText.firstMatch(prMatch.group(1) ?? '');
        if (dm != null) {
          final rawYear = dm.group(3)!;
          final year = rawYear.length == 2 ? '20$rawYear' : rawYear;
          final month = dm.group(2)!.padLeft(2, '0');
          final day = dm.group(1)!.padLeft(2, '0');
          pr.date = '$year-$month-$day';
        }
        continue;
      }
    }

    if (mode == 'pr') {
      final m = _prLine.firstMatch(raw);
      if (m != null) {
        final name = m.group(1)!.trim().toLowerCase();
        final weight = double.tryParse(m.group(2)!.replaceAll(',', '.')) ?? 0;
        if (name.contains('bench') || name.contains('bankdrücken')) {
          pr.bench = weight;
        } else if (name.contains('deadlift')) {
          pr.deadlift = weight;
        } else if (name.contains('squat')) {
          pr.squat = weight;
        }
      }
      continue;
    }

    if (mode == 'preamble') {
      preambleAcc.consumeLine(raw);
      continue;
    }

    dayAcc!.consumeLine(raw);
  }
  dayAcc?.flush();
  preambleAcc.flush();

  if (days.isEmpty) {
    warnings.add(
      'Es wurden keine Tage im Format "1. Wochentag" gefunden — es konnte '
      'nichts importiert werden.',
    );
  }

  return ParsedLog(
    days: days,
    dailyExercises: dailyExercises,
    pr: pr,
    warnings: warnings,
  );
}

/// Reads raw weight/set lines for a SINGLE exercise (no day or name header —
/// the name is already known from the UI). Used by the "Verlauf einfügen"
/// paste-in on an existing exercise.
ParsedBlock parseExerciseBlock(String text) {
  final lines = text
      .split(_newline)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  var weight = 0.0;
  final history = <HistoryEntry>[];
  for (final raw in lines) {
    if (_dividerLine.hasMatch(raw) || !_setLine.hasMatch(raw)) continue;
    final w = _parseWeight(raw);
    if (w > weight) weight = w;
    final reps = _parseHistoryReps(raw);
    if (reps.isNotEmpty) history.add(HistoryEntry(weight: w, reps: reps));
  }
  return ParsedBlock(weight: weight, history: history);
}

/// Maps the parsed {num, exercises} days onto a 7-day weekday plan (Tag 1 =
/// Montag ... Tag 6 = Samstag, Tag 7 = Sonntag). Any weekday without a
/// matching parsed day becomes a rest day.
List<Day> toWeekdayPlan(List<ParsedDay> parsedDays) {
  return List.generate(kWeekdays.length, (i) {
    final label = kWeekdays[i];
    ParsedDay? found;
    for (final d in parsedDays) {
      if (d.num == i + 1) {
        found = d;
        break;
      }
    }
    if (found == null || found.exercises.isEmpty) {
      return Day(label: label, rest: true, exercises: []);
    }
    return Day(
      label: label,
      rest: false,
      exercises: found.exercises.map((ex) {
        final sets = List.generate(
          ex.setCount,
          (_) => ExerciseSet(w: ex.weight, r: ex.reps),
        );
        return Exercise.fresh(ex.name, '', 90, sets,
            history: ex.history, note: ex.note);
      }).toList(),
    );
  });
}

/// Maps parsed "every training day" exercises onto [Exercise] objects.
List<Exercise> toDailyExercises(List<ParsedExercise> list) {
  return list.map((ex) {
    final sets = List.generate(
      ex.setCount,
      (_) => ExerciseSet(w: ex.weight, r: ex.reps),
    );
    return Exercise.fresh(ex.name, '', 90, sets,
        history: ex.history, note: ex.note);
  }).toList();
}
