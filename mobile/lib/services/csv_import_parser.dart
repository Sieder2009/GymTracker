import '../models/history_entry.dart';
import 'log_parser.dart' show ParsedLog, ParsedExercise, ParsedPr, ParsedDay;

const double _kgPerLb = 0.45359237;

/// Which app's CSV export a file was recognized as, by sniffing its header
/// row -- never by file extension or a user-picked dropdown, since a wrong
/// guess there would silently misparse every column.
enum CsvImportFormat { fitnotes, strong, hevy }

/// Splits CSV text into rows of raw string fields (RFC 4180: quoted fields
/// may contain commas/newlines, `""` is an escaped quote). Hand-rolled
/// rather than a dependency -- the exports this reads are simple, single-
/// sheet files, and one small, testable tokenizer is worth less than a new
/// package for it.
List<List<String>> parseCsvRows(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  final len = text.length;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    // Skip blank trailing rows (a lone empty field from a trailing newline).
    if (row.length > 1 || row.first.trim().isNotEmpty) rows.add(row);
    row = [];
  }

  while (i < len) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < len && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i += 1;
        continue;
      }
      field.write(c);
      i += 1;
      continue;
    }
    if (c == '"') {
      inQuotes = true;
      i += 1;
    } else if (c == ',') {
      endField();
      i += 1;
    } else if (c == '\r') {
      i += 1; // swallow, \n (or end of text) closes the row
    } else if (c == '\n') {
      endRow();
      i += 1;
    } else {
      field.write(c);
      i += 1;
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Case/whitespace-insensitive lookup of a column by any of [names] --
/// export tools rename columns across versions often enough that matching
/// by exact position would be fragile.
int _colIndex(List<String> header, List<String> names) {
  final normalized = header.map((h) => h.trim().toLowerCase()).toList();
  for (final name in names) {
    final idx = normalized.indexOf(name.toLowerCase());
    if (idx != -1) return idx;
  }
  return -1;
}

String _cell(List<String> row, int idx) => (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

/// Tries a handful of date/time shapes real export files actually use.
/// Never guesses when none match -- the caller records that date as
/// unknown (null) rather than attributing a set to the wrong day.
DateTime? _tryParseDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final direct = DateTime.tryParse(s); // handles 'YYYY-MM-DD' and ISO 8601
  if (direct != null) return direct;
  // '08 Jan 2024, 09:00' / '08 Jan 2024' (seen in Hevy exports).
  final months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  final m = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\w*\s+(\d{4})').firstMatch(s);
  if (m != null) {
    final month = months[m.group(2)!.toLowerCase()];
    if (month != null) {
      return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
    }
  }
  // 'MM/DD/YYYY' (seen in Strong/FitNotes exports on some locales).
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
  if (slash != null) {
    return DateTime(int.parse(slash.group(3)!), int.parse(slash.group(1)!), int.parse(slash.group(2)!));
  }
  return null;
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _RawSet {
  _RawSet({required this.exercise, required this.date, required this.weightKg, required this.reps});
  final String exercise;
  final DateTime? date;
  final double weightKg;
  final int reps;
}

/// Sniffs which app produced this CSV from its header row alone.
CsvImportFormat? detectCsvFormat(List<String> header) {
  final normalized = header.map((h) => h.trim().toLowerCase()).toSet();
  if (normalized.contains('exercise_title') && normalized.contains('set_index')) {
    return CsvImportFormat.hevy;
  }
  if (normalized.contains('workout name') && normalized.contains('exercise name')) {
    return CsvImportFormat.strong;
  }
  if (normalized.contains('exercise') && normalized.contains('category') && normalized.contains('weight unit')) {
    return CsvImportFormat.fitnotes;
  }
  return null;
}

/// Turns a flat list of (exercise, date, weight, reps) sets -- already
/// extracted from whichever export format -- into the same [ParsedLog]
/// shape the pasted-log importer produces, so [ImportLogScreen] reuses its
/// existing preview/save flow unchanged. Every exercise goes into
/// [ParsedLog.dailyExercises] ("jeden Trainingstag") rather than being
/// forced into a guessed weekday split -- a chronological session history
/// has no reliable weekly pattern to reconstruct, and dailyExercises is
/// exactly "the exercises you do", full history attached, ready to edit
/// into a real weekly plan afterward.
ParsedLog _buildParsedLog(List<_RawSet> sets, {required List<String> warnings}) {
  if (sets.isEmpty) {
    return ParsedLog(days: const [], dailyExercises: const [], pr: ParsedPr(), warnings: warnings);
  }

  final byExercise = <String, List<_RawSet>>{};
  for (final s in sets) {
    byExercise.putIfAbsent(s.exercise, () => []).add(s);
  }
  if (sets.any((s) => s.date == null)) {
    warnings.add('Bei manchen Sätzen konnte kein Datum gelesen werden -- sie zählen ohne Datum zur Historie.');
  }

  final dailyExercises = <ParsedExercise>[];
  for (final entry in byExercise.entries) {
    final rows = entry.value..sort((a, b) {
      final ad = a.date, bd = b.date;
      if (ad == null && bd == null) return 0;
      if (ad == null) return -1;
      if (bd == null) return 1;
      return ad.compareTo(bd);
    });

    // One HistoryEntry per (date, weight) group -- multiple sets at the
    // same weight on the same day collapse into one entry's rep list,
    // matching how the pasted-log format already represents a session;
    // a different weight the same day (a pyramid/back-off set) stays its
    // own entry so no real data gets conflated together.
    final history = <HistoryEntry>[];
    String? lastKey;
    for (final r in rows) {
      final key = '${r.date == null ? '' : _isoDate(r.date!)}|${r.weightKg}';
      if (key != lastKey || history.isEmpty) {
        history.add(HistoryEntry(weight: r.weightKg, reps: [r.reps], date: r.date == null ? null : _isoDate(r.date!)));
        lastKey = key;
      } else {
        history.last.reps.add(r.reps);
      }
    }

    final lastSessionDate = rows.last.date;
    final lastSessionRows = lastSessionDate == null
        ? [rows.last]
        : rows.where((r) => r.date != null && _isoDate(r.date!) == _isoDate(lastSessionDate)).toList();
    final latestWeight = lastSessionRows.map((r) => r.weightKg).fold<double>(0, (a, b) => a > b ? a : b);
    final repsLabel = '${lastSessionRows.first.reps}';

    dailyExercises.add(ParsedExercise(
      name: entry.key,
      note: '',
      setCount: lastSessionRows.length,
      reps: repsLabel,
      weight: latestWeight,
      history: history,
    ));
  }

  return ParsedLog(days: const <ParsedDay>[], dailyExercises: dailyExercises, pr: ParsedPr(), warnings: warnings);
}

ParsedLog parseFitNotesCsv(String csv) {
  final rows = parseCsvRows(csv);
  final warnings = <String>[];
  if (rows.isEmpty) return ParsedLog(days: const [], dailyExercises: const [], pr: ParsedPr(), warnings: warnings);
  final header = rows.first;
  final dateI = _colIndex(header, ['date']);
  final exI = _colIndex(header, ['exercise']);
  final weightI = _colIndex(header, ['weight']);
  final unitI = _colIndex(header, ['weight unit', 'unit']);
  final repsI = _colIndex(header, ['reps']);

  final sets = <_RawSet>[];
  for (final row in rows.skip(1)) {
    final name = _cell(row, exI);
    if (name.isEmpty) continue;
    final w = double.tryParse(_cell(row, weightI).replaceAll(',', '.')) ?? 0;
    final unit = _cell(row, unitI).toLowerCase();
    final reps = int.tryParse(_cell(row, repsI)) ?? 0;
    sets.add(_RawSet(
      exercise: name,
      date: _tryParseDate(_cell(row, dateI)),
      weightKg: unit == 'lb' || unit == 'lbs' ? w * _kgPerLb : w,
      reps: reps,
    ));
  }
  return _buildParsedLog(sets, warnings: warnings);
}

ParsedLog parseStrongCsv(String csv) {
  final rows = parseCsvRows(csv);
  final warnings = <String>[];
  if (rows.isEmpty) return ParsedLog(days: const [], dailyExercises: const [], pr: ParsedPr(), warnings: warnings);
  final header = rows.first;
  final dateI = _colIndex(header, ['date']);
  final exI = _colIndex(header, ['exercise name', 'exercise']);
  final weightI = _colIndex(header, ['weight']);
  final unitI = _colIndex(header, ['weight unit', 'unit']);
  final repsI = _colIndex(header, ['reps']);
  final rpeI = _colIndex(header, ['rpe']);
  if (rpeI != -1) {
    warnings.add('RPE-Werte aus der Strong-Datei werden nicht übernommen -- die App speichert kein RPE für importierte Historie.');
  }

  final sets = <_RawSet>[];
  for (final row in rows.skip(1)) {
    final name = _cell(row, exI);
    if (name.isEmpty) continue;
    final w = double.tryParse(_cell(row, weightI).replaceAll(',', '.')) ?? 0;
    final unit = _cell(row, unitI).toLowerCase();
    final reps = int.tryParse(_cell(row, repsI)) ?? 0;
    sets.add(_RawSet(
      exercise: name,
      date: _tryParseDate(_cell(row, dateI)),
      weightKg: unit == 'lb' || unit == 'lbs' ? w * _kgPerLb : w,
      reps: reps,
    ));
  }
  return _buildParsedLog(sets, warnings: warnings);
}

ParsedLog parseHevyCsv(String csv) {
  final rows = parseCsvRows(csv);
  final warnings = <String>[];
  if (rows.isEmpty) return ParsedLog(days: const [], dailyExercises: const [], pr: ParsedPr(), warnings: warnings);
  final header = rows.first;
  final dateI = _colIndex(header, ['start_time', 'date']);
  final exI = _colIndex(header, ['exercise_title', 'exercise']);
  // Hevy already exports weight in kilograms under weight_kg -- unlike
  // FitNotes/Strong there's no separate unit column to check.
  final weightI = _colIndex(header, ['weight_kg', 'weight']);
  final repsI = _colIndex(header, ['reps']);
  final rpeI = _colIndex(header, ['rpe']);
  if (rpeI != -1) {
    warnings.add('RPE-Werte aus der Hevy-Datei werden nicht übernommen -- die App speichert kein RPE für importierte Historie.');
  }

  final sets = <_RawSet>[];
  for (final row in rows.skip(1)) {
    final name = _cell(row, exI);
    if (name.isEmpty) continue;
    final w = double.tryParse(_cell(row, weightI).replaceAll(',', '.')) ?? 0;
    final reps = int.tryParse(_cell(row, repsI)) ?? 0;
    sets.add(_RawSet(exercise: name, date: _tryParseDate(_cell(row, dateI)), weightKg: w, reps: reps));
  }
  return _buildParsedLog(sets, warnings: warnings);
}

/// Detects the format from [csv]'s header row and parses it, or returns
/// null (with a warning explaining why) when it isn't recognized as any of
/// the three supported exports -- never falls back to guessing a format.
ParsedLog parseImportedWorkoutCsv(String csv) {
  final rows = parseCsvRows(csv);
  if (rows.isEmpty) {
    return ParsedLog(
      days: const [],
      dailyExercises: const [],
      pr: ParsedPr(),
      warnings: const ['Die Datei enthält keine erkennbaren Zeilen.'],
    );
  }
  final format = detectCsvFormat(rows.first);
  switch (format) {
    case CsvImportFormat.fitnotes:
      return parseFitNotesCsv(csv);
    case CsvImportFormat.strong:
      return parseStrongCsv(csv);
    case CsvImportFormat.hevy:
      return parseHevyCsv(csv);
    case null:
      return ParsedLog(
        days: const [],
        dailyExercises: const [],
        pr: ParsedPr(),
        warnings: const [
          'Dateiformat nicht erkannt -- unterstützt werden CSV-Exporte aus FitNotes, Strong und Hevy.',
        ],
      );
  }
}
