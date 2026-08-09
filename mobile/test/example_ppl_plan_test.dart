import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/example_ppl_plan.dart';

/// Guards against the PPL plan silently drifting out of sync with the
/// shared exercise database -- every exercise name it uses must exist
/// verbatim in `assets/exercises.json`, so this fails loudly instead of
/// shipping a plan full of names nobody can find or cross-reference.
void main() {
  test(
      'buildExamplePplProgram only uses exercise names that exist in assets/exercises.json',
      () {
    final raw = File('assets/exercises.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final realNames = {
      for (final e in decoded['exercises'] as List)
        (e as Map<String, dynamic>)['name'] as String,
    };

    final program = buildExamplePplProgram(name: 'Push/Pull/Legs');

    expect(program.mode, 'weekday');
    expect(program.days.length, 7);
    expect(program.days.last.rest, isTrue,
        reason: 'Sunday should be a rest day');
    expect(program.days.last.exercises, isEmpty);

    var totalExercises = 0;
    for (final day in program.days.take(6)) {
      expect(day.rest, isFalse);
      expect(day.exercises, isNotEmpty);
      for (final ex in day.exercises) {
        totalExercises += 1;
        expect(
          realNames.contains(ex.name),
          isTrue,
          reason:
              '"${ex.name}" is not a real exercise name in assets/exercises.json',
        );
        expect(ex.sets, isNotEmpty);
        for (final s in ex.sets) {
          expect(s.w, 0,
              reason: 'plan should start with unset working weights');
        }
      }
    }
    expect(totalExercises, 30);
  });
}
