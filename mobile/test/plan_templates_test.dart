import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/plan_templates.dart';

/// Guards against assets/plan_templates.json silently drifting out of sync
/// with the shared exercise database -- every exercise name it uses must
/// exist verbatim in assets/exercises.json, same guarantee
/// example_ppl_plan_test.dart already gives the hand-written PPL plan.
/// Reads both JSON files directly via dart:io (like that test does)
/// instead of going through loadPlanTemplates()'s rootBundle, which needs
/// a real asset bundle a plain test doesn't have.
void main() {
  test('every plan_templates.json exercise name exists in assets/exercises.json', () {
    final exercisesRaw = File('assets/exercises.json').readAsStringSync();
    final exercisesDecoded = jsonDecode(exercisesRaw) as Map<String, dynamic>;
    final realNames = {
      for (final e in exercisesDecoded['exercises'] as List) (e as Map<String, dynamic>)['name'] as String,
    };

    final templatesRaw = File('assets/plan_templates.json').readAsStringSync();
    final templatesDecoded = jsonDecode(templatesRaw) as Map<String, dynamic>;
    final templates =
        (templatesDecoded['templates'] as List).map((t) => PlanTemplate.fromJson(t as Map<String, dynamic>)).toList();

    expect(templates, isNotEmpty);
    final seenIds = <String>{};
    for (final template in templates) {
      expect(seenIds.add(template.id), isTrue, reason: 'duplicate template id "${template.id}"');
      expect(template.days.length, 7, reason: '"${template.id}" must have exactly 7 days (Mo-So)');

      final program = buildProgramFromTemplate(template, name: 'Test');
      expect(program.days.length, 7);

      var totalExercises = 0;
      for (final day in program.days) {
        if (day.rest) {
          expect(day.exercises, isEmpty);
          continue;
        }
        expect(day.exercises, isNotEmpty);
        for (final ex in day.exercises) {
          totalExercises += 1;
          expect(
            realNames.contains(ex.name),
            isTrue,
            reason: '"${template.id}": "${ex.name}" is not a real exercise name in assets/exercises.json',
          );
          expect(ex.sets, isNotEmpty);
          for (final s in ex.sets) {
            expect(s.w, 0, reason: 'plan should start with unset working weights');
          }
        }
      }
      expect(totalExercises, greaterThan(0), reason: '"${template.id}" has no training days at all');
    }
  });
}
