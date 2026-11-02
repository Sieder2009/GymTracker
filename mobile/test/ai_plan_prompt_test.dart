import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/constants.dart';
import 'package:ironpeak_mobile/data/effort_scale.dart';
import 'package:ironpeak_mobile/data/exercise_categories.dart';
import 'package:ironpeak_mobile/models/day.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/exercise_template.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';
import 'package:ironpeak_mobile/models/muscle_group.dart';
import 'package:ironpeak_mobile/models/program.dart';
import 'package:ironpeak_mobile/services/ai_plan_prompt.dart';

List<ExerciseTemplate> _bundledLibrary() {
  final decoded = jsonDecode(File('assets/exercises.json').readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final e in decoded['exercises'] as List) ExerciseTemplate.fromJson(e as Map<String, dynamic>),
  ];
}

Exercise _logged(String name, List<HistoryEntry> history) =>
    Exercise.fresh(name, '', 90, [ExerciseSet(w: 0, r: '8')], history: history);

Program _program(List<Exercise> exercises) => Program(
      id: 'p',
      name: 'P',
      mode: 'weekday',
      startDate: '2026-01-01',
      days: [Day(label: 'Montag', rest: false, exercises: exercises)],
    );

void main() {
  final library = _bundledLibrary();
  const pastePath = ['Einstellungen', 'KI-TRAININGSPLAN', 'Plan von der KI einfügen'];

  String build({AiPromptProfile? profile, EffortScale scale = EffortScale.rpe, List<ExerciseTemplate> custom = const []}) =>
      buildAiPlanPrompt(
        language: aiPromptLanguageName('de'),
        today: '2026-11-01',
        exercises: library,
        customExercises: custom,
        profile: profile,
        barWeightKg: 20,
        effortScale: scale,
        pastePath: pastePath,
      );

  test('speaks the app language and knows today', () {
    final prompt = build();
    expect(prompt, contains('Talk to me in German'));
    expect(prompt, contains('Today is 2026-11-01'));
    expect(aiPromptLanguageName('xx'), 'English');
  });

  test('tells the AI where the answer goes, in the words the app shows', () {
    expect(build(), contains('"Einstellungen" → "KI-TRAININGSPLAN" → "Plan von der KI einfügen"'));
  });

  test('carries the example the import is tested against', () {
    expect(build(), contains(kAiPlanPromptExample));
  });

  test('the example only uses real exercise names', () {
    final names = {for (final e in library) e.name};
    final example = jsonDecode(kAiPlanPromptExample) as Map<String, dynamic>;
    for (final day in (example['data'] as Map<String, dynamic>)['days'] as List) {
      for (final ex in (day as Map<String, dynamic>)['exercises'] as List) {
        final name = (ex as Map<String, dynamic>)['name'] as String;
        expect(names, contains(name));
      }
    }
  });

  test('explains every muscle key and every body area', () {
    final prompt = build();
    for (final m in MuscleGroup.values) {
      expect(prompt, contains('${m.name} ('), reason: m.name);
    }
    for (final c in kExerciseCategories) {
      expect(prompt, contains('$c: '), reason: 'exercise list group $c');
    }
    expect(prompt, contains(kExerciseCategories.join(', ')));
  });

  test('lists every exercise of the library and the user\'s own', () {
    final prompt = build(custom: const [ExerciseTemplate(id: 'custom:1', name: 'Meine Spezialübung', category: 'arms')]);
    for (final e in library) {
      expect(prompt, contains(e.name), reason: e.name);
    }
    expect(prompt, contains('Meine Spezialübung (arms)'));
  });

  test('names all seven German weekday labels', () {
    final prompt = build();
    expect(prompt, contains(kWeekdays.join(', ')));
  });

  test('without my data it asks for body weight and weights, and has no "About me"', () {
    final prompt = build();
    expect(prompt, isNot(contains('ABOUT ME')));
    expect(prompt, contains('plus my sex, age, height, body weight'));
    expect(prompt, contains('use 0 for them unless I give you that exercise'));
  });

  test('with my data it lists what the app knows and does not ask again', () {
    final prompt = build(
      profile: const AiPromptProfile(
        isMale: false,
        bodyWeightKg: 61.5,
        bodyWeightDate: '2026-10-30',
        prs: {'bench': 55, 'deadlift': 110},
        workingWeights: [
          AiPromptWorkingWeight(name: 'Bankdrücken', weightKg: 47.5, reps: [8, 8, 7]),
          AiPromptWorkingWeight(name: 'Kreuzheben', weightKg: 90),
        ],
      ),
      scale: EffortScale.rir,
    );
    expect(prompt, contains('ABOUT ME'));
    expect(prompt, contains('- Sex: female'));
    expect(prompt, contains('- Body weight: 61.5 kg (weighed on 2026-10-30)'));
    expect(prompt, contains('bench press 55 kg, deadlift 110 kg'));
    expect(prompt, contains('  - Bankdrücken: 47.5 kg × 8, 8, 7'));
    expect(prompt, contains('  - Kreuzheben: 90 kg\n'));
    expect(prompt, contains("Don't ask for anything \"About me\" already answers"));
    expect(prompt, isNot(contains('plus my sex')));
    expect(prompt, contains('use 0 for them unless "About me" gives that exercise'));
    expect(prompt, contains('RIR (reps in reserve'));
  });

  test('an empty profile counts as no data', () {
    expect(build(profile: const AiPromptProfile()), isNot(contains('ABOUT ME')));
  });

  test('states the bar weight and the effort scale', () {
    final prompt = build();
    expect(prompt, contains('My barbell weighs 20 kg.'));
    expect(prompt, contains('RPE (5-10'));
  });

  group('recentWorkingWeights', () {
    HistoryEntry entry(double kg, String? date, {ExerciseLogMode mode = ExerciseLogMode.reps}) =>
        HistoryEntry(weight: kg, reps: const [8, 'x', 7], date: date, mode: mode);

    test('newest first, one line per exercise, only weight-and-reps sessions', () {
      final weights = recentWorkingWeights([
        _program([
          _logged('Bankdrücken', [entry(60, '2026-10-01'), entry(62.5, '2026-10-20')]),
          _logged('Plank', [entry(10, '2026-10-25', mode: ExerciseLogMode.timed)]),
          _logged('Dips', [entry(0, '2026-10-26')]),
          _logged('Squats', [entry(100, null)]),
        ]),
        _program([
          _logged('bankdrücken', [entry(55, '2026-09-01')]),
          _logged('Kreuzheben', [entry(120, '2026-10-22')]),
        ]),
      ]);
      expect([for (final w in weights) '${w.name} ${w.weightKg}'],
          ['Kreuzheben 120.0', 'Bankdrücken 62.5', 'Squats 100.0']);
      expect(weights[1].reps, [8, 7], reason: 'markers are left out');
    });

    test('stops at the limit', () {
      final weights = recentWorkingWeights([
        _program([
          for (var i = 0; i < 30; i++) _logged('Übung $i', [entry(10, '2026-10-${(i % 28 + 1).toString().padLeft(2, '0')}')]),
        ]),
      ], limit: 5);
      expect(weights.length, 5);
    });
  });
}
