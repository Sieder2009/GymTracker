import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/services/csv_import_parser.dart';

void main() {
  group('parseCsvRows', () {
    test('splits a simple comma-separated file into rows of fields', () {
      final rows = parseCsvRows('a,b,c\n1,2,3\n');
      expect(rows, [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('handles a quoted field containing a comma', () {
      final rows = parseCsvRows('name,note\nBench,"heavy, felt good"\n');
      expect(rows[1], ['Bench', 'heavy, felt good']);
    });

    test('handles an escaped double-quote inside a quoted field', () {
      final rows = parseCsvRows('name\n"5\'\'10"" guy"\n');
      expect(rows[1], ['5\'\'10" guy']);
    });

    test('tolerates CRLF line endings', () {
      final rows = parseCsvRows('a,b\r\n1,2\r\n');
      expect(rows, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('ignores a trailing blank line', () {
      final rows = parseCsvRows('a,b\n1,2\n\n');
      expect(rows.length, 2);
    });

    test('strips a leading UTF-8 byte-order mark from Excel-exported files', () {
      final bom = String.fromCharCode(0xFEFF);
      final rows = parseCsvRows('$bom' 'Date,Exercise\n2024-01-01,Bench\n');
      expect(rows.first, ['Date', 'Exercise']);
    });
  });

  group('detectCsvFormat', () {
    test('recognizes a FitNotes header', () {
      expect(
        detectCsvFormat(['Date', 'Exercise', 'Category', 'Weight', 'Weight Unit', 'Reps', 'Distance', 'Distance Unit', 'Time', 'Comment']),
        CsvImportFormat.fitnotes,
      );
    });

    test('recognizes a Strong header', () {
      expect(
        detectCsvFormat(['Date', 'Workout Name', 'Duration', 'Exercise Name', 'Set Order', 'Weight', 'Weight Unit', 'Reps', 'RPE']),
        CsvImportFormat.strong,
      );
    });

    test('recognizes a Hevy header', () {
      expect(
        detectCsvFormat(['title', 'start_time', 'end_time', 'exercise_title', 'superset_id', 'set_index', 'weight_kg', 'reps', 'rpe']),
        CsvImportFormat.hevy,
      );
    });

    test('returns null for an unrelated CSV', () {
      expect(detectCsvFormat(['id', 'name', 'value']), isNull);
    });
  });

  group('parseFitNotesCsv', () {
    const csv = 'Date,Exercise,Category,Weight,Weight Unit,Reps,Distance,Distance Unit,Time,Comment\n'
        '2026-01-05,Bench Press,Chest,60,kg,8,,,,\n'
        '2026-01-05,Bench Press,Chest,60,kg,7,,,,\n'
        '2026-01-12,Bench Press,Chest,62.5,kg,6,,,,\n'
        '2026-01-05,Squat,Legs,100,kg,5,,,,\n';

    test('groups same-weight same-day sets into one history entry with multiple reps', () {
      final parsed = parseFitNotesCsv(csv);
      final bench = parsed.dailyExercises.firstWhere((e) => e.name == 'Bench Press');
      expect(bench.history.length, 2); // 2026-01-05 @60kg (2 sets), 2026-01-12 @62.5kg
      expect(bench.history[0].weight, 60);
      expect(bench.history[0].reps, [8, 7]);
      expect(bench.history[0].date, '2026-01-05');
      expect(bench.history[1].weight, 62.5);
      expect(bench.history[1].date, '2026-01-12');
    });

    test('seeds weight/setCount from the most recent session only', () {
      final parsed = parseFitNotesCsv(csv);
      final bench = parsed.dailyExercises.firstWhere((e) => e.name == 'Bench Press');
      expect(bench.weight, 62.5);
      expect(bench.setCount, 1); // only one set logged on 2026-01-12
    });

    test('converts pounds to kilograms', () {
      const lbCsv = 'Date,Exercise,Category,Weight,Weight Unit,Reps,Distance,Distance Unit,Time,Comment\n'
          '2026-01-05,Deadlift,Back,225,lb,5,,,,\n';
      final parsed = parseFitNotesCsv(lbCsv);
      final deadlift = parsed.dailyExercises.single;
      expect(deadlift.weight, closeTo(225 * 0.45359237, 0.001));
    });

    test('every distinct exercise becomes its own entry', () {
      final parsed = parseFitNotesCsv(csv);
      expect(parsed.dailyExercises.map((e) => e.name).toSet(), {'Bench Press', 'Squat'});
    });

    test('still parses (and still finds a date) when the file starts with a BOM', () {
      final bom = String.fromCharCode(0xFEFF);
      final parsed = parseFitNotesCsv('$bom' '$csv');
      final bench = parsed.dailyExercises.firstWhere((e) => e.name == 'Bench Press');
      expect(bench.history.first.date, '2026-01-05');
    });
  });

  group('parseStrongCsv', () {
    const csv = 'Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Weight Unit,Reps,Distance,Distance Unit,Seconds,Notes,Workout Notes,RPE\n'
        '2026-02-01,Push Day,60min,Overhead Press,1,40,kg,10,,,,,,7\n'
        '2026-02-01,Push Day,60min,Overhead Press,2,40,kg,8,,,,,,8\n';

    test('parses sets and warns that RPE is not carried into history', () {
      final parsed = parseStrongCsv(csv);
      final ohp = parsed.dailyExercises.single;
      expect(ohp.name, 'Overhead Press');
      expect(ohp.history.single.reps, [10, 8]);
      expect(parsed.warnings, isNotEmpty);
    });
  });

  group('parseHevyCsv', () {
    const csv = 'title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe\n'
        'Leg Day,05 Jan 2026 09:00,05 Jan 2026 10:00,,Squat (Barbell),,,0,normal,100,5,,,\n'
        'Leg Day,05 Jan 2026 09:00,05 Jan 2026 10:00,,Squat (Barbell),,,1,normal,100,5,,,\n';

    test('parses weight_kg directly (no unit conversion needed) and the Hevy-style date', () {
      final parsed = parseHevyCsv(csv);
      final squat = parsed.dailyExercises.single;
      expect(squat.weight, 100);
      expect(squat.history.single.date, '2026-01-05');
      expect(squat.history.single.reps, [5, 5]);
    });
  });

  group('parseImportedWorkoutCsv', () {
    test('dispatches to the right parser based on the detected header', () {
      const fitnotes = 'Date,Exercise,Category,Weight,Weight Unit,Reps,Distance,Distance Unit,Time,Comment\n'
          '2026-01-05,Row,Back,50,kg,10,,,,\n';
      final parsed = parseImportedWorkoutCsv(fitnotes);
      expect(parsed.dailyExercises.single.name, 'Row');
    });

    test('an unrecognized file yields a clear warning and no exercises', () {
      final parsed = parseImportedWorkoutCsv('id,name\n1,foo\n');
      expect(parsed.dailyExercises, isEmpty);
      expect(parsed.warnings, isNotEmpty);
    });

    test('an empty file yields a clear warning', () {
      final parsed = parseImportedWorkoutCsv('');
      expect(parsed.warnings, isNotEmpty);
    });
  });
}
