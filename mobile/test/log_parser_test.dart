import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/example_log.dart';
import 'package:ironpeak_mobile/services/log_parser.dart';

// Ground-truth values below were obtained by actually running the original
// `src/lib/logParser.js` against `src/lib/exampleLog.js` in Node — not
// hand-derived — so this suite is the primary correctness gate for the
// Dart port.
void main() {
  final result = parseLog(exampleLog);

  test('finds all 6 day headers, numbered 1..6', () {
    expect(result.days.map((d) => d.num).toList(), [1, 2, 3, 4, 5, 6]);
  });

  test('zero warnings for this clean log', () {
    expect(result.warnings, isEmpty);
  });

  test('PR block: bench 87.5 / deadlift 150 / squat 120 / date 2026-04-27', () {
    expect(result.pr.bench, 87.5);
    expect(result.pr.deadlift, 150);
    expect(result.pr.squat, 120);
    expect(result.pr.date, '2026-04-27');
  });

  test(
      '"jeden Trainingstag" preamble has 12 exercises: the daily mobility '
      'routine plus Unterrücken', () {
    expect(result.dailyExercises.length, 12);
    expect(result.dailyExercises.map((e) => e.name).toList(), [
      'Cat and Cow',
      'Ausfallschritt',
      'Ausfallschritt Rotationen',
      'Bein ausgestreckt und anderes vorne, ca. 30°',
      'Ausfallschritt auf dem Bett',
      'Boden Ficker',
      'Liegend Bein zur anderen Seite legen',
      'Schneidersitz anbetten',
      'Waage',
      'Liegend diagonal Hand und Fuß berühren',
      'Vierfüßlerstand, abwechselnd die Hand heben',
      'Unterrücken',
    ]);
    final unterruecken = result.dailyExercises.last;
    expect(unterruecken.note, 'Unterrücken als erstes gerade');
  });

  test('day 1 has 7 exercises, incl. two UN-MERGED "Ein-armige Rows" entries', () {
    final day1 = result.days.firstWhere((d) => d.num == 1);
    expect(day1.exercises.map((e) => e.name).toList(), [
      'Deadlift',
      'Klimmzüge',
      'Ein-armige Rows',
      'Ein-armige Rows',
      'Langhantel',
      'Breites rudern',
      'Zstange Biceps curls',
    ]);
  });

  test('day 1 Deadlift: scheme "2x3" -> setCount=2/reps="3", weight=running max 140', () {
    final day1 = result.days.firstWhere((d) => d.num == 1);
    final dl = day1.exercises.first;
    expect(dl.setCount, 2);
    expect(dl.reps, '3');
    expect(dl.weight, 140.0);
    expect(dl.history.length, 18);
    expect(dl.history.first.weight, 120);
    expect(dl.history.first.reps, [3, 3]);
  });

  test('letter marker "x.x": day 5 Deadlift has a set with reps [x, x]', () {
    final day5 = result.days.firstWhere((d) => d.num == 5);
    final dl = day5.exercises.firstWhere((e) => e.name == 'Deadlift');
    expect(
      dl.history.any((h) => h.weight == 130 && h.reps.contains('x')),
      isTrue,
    );
  });

  test('mixed digit/letter markers: Seitheben (day 6) 16kg set contains 3x "x"', () {
    final day6 = result.days.firstWhere((d) => d.num == 6);
    final seitheben = day6.exercises.firstWhere((e) => e.name == 'Seitheben');
    final r16 = seitheben.history.firstWhere((h) => h.weight == 16).reps;
    expect(r16.where((v) => v == 'x').length, 3);
  });

  group('toWeekdayPlan', () {
    final plan = toWeekdayPlan(result.days);

    test('7 days total, Sonntag rest (Tag 7 never appears in this log)', () {
      expect(plan.length, 7);
      expect(plan[6].label, 'Sonntag');
      expect(plan[6].rest, isTrue);
      expect(plan[6].exercises, isEmpty);
    });

    test('Montag is a training day with 7 exercises', () {
      expect(plan[0].label, 'Montag');
      expect(plan[0].rest, isFalse);
      expect(plan[0].exercises.length, 7);
    });
  });

  test('parseExerciseBlock reads a bare weight/reps block', () {
    final block = parseExerciseBlock(
      '70kg x3 8.7.6 9.7.7 10.8.8\n72.5kg x2 7.6 9.7',
    );
    expect(block.weight, 72.5);
    expect(block.history[0].weight, 70);
    expect(block.history[0].reps, [8, 7, 6, 9, 7, 7, 10, 8, 8]);
    expect(block.history[1].weight, 72.5);
    expect(block.history[1].reps, [7, 6, 9, 7]);
  });

  test('all-dots token records one ✓ per dot-split segment (Kick-ups)', () {
    final block = parseExerciseBlock('1x .....');
    // '.....'.split('.') has 5 dots -> 6 empty segments, matching the
    // original JS `tok.split('.').length` behaviour exactly.
    expect(block.history.single.reps, List.filled(6, '✓'));
  });
}
