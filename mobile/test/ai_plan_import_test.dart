import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/constants.dart';
import 'package:ironpeak_mobile/data/exercise_muscle_map.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_template.dart';
import 'package:ironpeak_mobile/models/muscle_group.dart';
import 'package:ironpeak_mobile/models/program.dart';
import 'package:ironpeak_mobile/services/ai_plan_import.dart';
import 'package:ironpeak_mobile/services/ai_plan_prompt.dart';
import 'package:ironpeak_mobile/services/plan_share_codec.dart';

List<ExerciseTemplate> _bundledLibrary() {
  final decoded = jsonDecode(File('assets/exercises.json').readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final e in decoded['exercises'] as List) ExerciseTemplate.fromJson(e as Map<String, dynamic>),
  ];
}

/// A plan of [days] (each a list of exercise JSON maps, null = rest day),
/// wrapped like the prompt asks.
String _plan(List<List<Map<String, Object?>>?> days, {List<Map<String, Object?>> daily = const []}) =>
    jsonEncode({
      'app': 'ironpeak',
      'type': 'plan',
      'version': 1,
      'data': {
        'name': 'Test',
        'mode': 'weekday',
        'days': [
          for (var i = 0; i < days.length; i++)
            {'label': kWeekdays[i % 7], 'rest': days[i] == null, 'exercises': days[i] ?? []},
        ],
        'dailyExercises': daily,
      },
    });

void main() {
  final library = _bundledLibrary();
  final now = DateTime(2026, 11, 1, 9, 30);

  AiPlanImportResult parse(String text) => parseAiPlan(text, library: library, now: now, fallbackName: 'Fallback');

  group('the example inside the prompt', () {
    late AiPlanImportResult result;
    late Program plan;

    setUp(() {
      result = parse(kAiPlanPromptExample);
      plan = result.program!;
    });

    test('imports as a 7-day weekday plan starting today', () {
      expect(result.error, isNull);
      expect(plan.mode, 'weekday');
      expect(plan.startDate, '2026-11-01');
      expect(plan.id, startsWith('plan_ai_'));
      expect(plan.name, 'Full body 2x');
      expect([for (final d in plan.days) d.label], kWeekdays);
      expect([for (final d in plan.days) d.rest], [false, true, false, true, true, true, true]);
      expect(result.trainingDays, 2);
      expect(result.exerciseCount, 7);
      expect(plan.dailyExercises, isEmpty);
      expect(result.cutOff, isFalse);
    });

    test('only uses names from the exercise database', () {
      expect(result.unknownExercises, isEmpty);
    });

    test('keeps every field a person sets in the editor', () {
      final bench = plan.days[0].exercises[0];
      expect(bench.name, 'Bankdrücken');
      expect(bench.muscle, 'chest');
      expect(bench.rest, 150);
      expect(bench.logMode, ExerciseLogMode.reps);
      expect([for (final s in bench.sets) '${s.w}x${s.r}'], ['60.0x6-8', '60.0x6-8', '60.0x6-8']);
      expect(bench.startW, 60);
      expect(bench.muscleActivation, {'chest': 100, 'frontDelts': 40, 'triceps': 45});
      expect(bench.note, startsWith('Full body A'));
      expect(bench.history, isEmpty);
      expect(bench.done, isEmpty);

      final split = plan.days[0].exercises[1];
      expect(split.unilateral, isTrue);
      expect(split.sets.first.r, '20');

      final plank = plan.days[0].exercises[2];
      expect(plank.logMode, ExerciseLogMode.timed);
      expect(plank.sets.map((s) => s.targetDurationSec), [45, 45]);
      expect(plank.sets.first.r, '');

      final curls = plan.days[2].exercises[1];
      expect(curls.supersetWithNext, isTrue);
      expect(plan.days[2].exercises[2].muscleActivation['tricepsLateralHead'], 100);

      final run = plan.days[2].exercises[3];
      expect(run.logMode, ExerciseLogMode.cardio);
      expect(run.muscle, 'cardio');
      expect(run.sets.single.targetDurationSec, 1200);
      expect(run.sets.single.targetSpeedKmh, 9.5);
      expect(run.sets.single.w, 0);
      expect(run.rest, 0);
    });

    test('survives saving and sharing like any other plan', () {
      final restored = Program.fromJson(jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>);
      expect(restored.days[2].exercises[3].sets.single.targetSpeedKmh, 9.5);
      final shared = parseSharedPlanPayload(buildPlanSharePayload(plan));
      expect(shared, isNotNull);
      expect(shared!.days[0].exercises[0].muscleActivation['chest'], 100);
    });
  });

  test('reads a real chat answer: prose, a fence, sloppy values', () {
    const answer = '''
Here is your plan! I focused on {strength} first.

```json
{
  "app": "ironpeak",
  "type": "plan",
  "version": 1,
  "data": {
    "name": "Kraft 3x",
    "mode": "weekday",
    "days": [
      {"label": "Montag", "rest": false, "exercises": [
        {"name": "bankdrücken", "muscle": "Chest", "rest": "2 min", "logMode": "reps",
         "sets": [{"w": "60 kg", "r": "8–10"}, {"w": 62.5, "r": 8}, {"w": 65}],
         "muscleActivation": {"pecs": 0.9, "front_delts": 0.4, "wings": 50},
         "supersetWithNext": "false"},
        {"name": "Plank", "sets": [{"targetDurationSec": 40}, {"targetDurationSec": 40}]},
        {"name": "Sandbag Hug Hold", "muscle": "forearms", "rest": "1:30", "logMode": "timed",
         "sets": 2, "seconds": 60, "weight": 24, "supersetWithNext": true},
      ]},
      {"label": "Dienstag", "rest": true, "exercises": [{"name": "Spazieren"}]},
      {"label": "Mittwoch", "rest": false, "exercises": []},
    ],
  }
}
```

Copy the code block, then in Kilo tap Settings → AI TRAINING PLAN → Paste plan from AI.''';
    final result = parse(answer);
    expect(result.error, isNull);
    final plan = result.program!;
    expect(plan.name, 'Kraft 3x');

    final bench = plan.days[0].exercises[0];
    expect(bench.name, 'Bankdrücken', reason: 'renamed to the library spelling');
    expect(bench.muscle, 'chest');
    expect(bench.rest, 120);
    expect([for (final s in bench.sets) s.r], ['8-10', '8', '—']);
    expect([for (final s in bench.sets) s.w], [60, 62.5, 65]);
    expect(bench.muscleActivation, {'chest': 90, 'frontDelts': 40}, reason: 'fractions, synonyms, unknown keys dropped');
    expect(bench.supersetWithNext, isFalse);

    final plank = plan.days[0].exercises[1];
    expect(plank.logMode, ExerciseLogMode.timed, reason: 'durations without reps mean a hold');
    expect(plank.sets.map((s) => s.targetDurationSec), [40, 40]);
    expect(plank.muscle, 'core', reason: 'category from the library');
    expect(plank.muscleActivation, isNotEmpty, reason: 'muscles from the library when the AI left them out');

    final walk = plan.days[0].exercises[2];
    expect(walk.rest, 90);
    expect(walk.muscle, 'arms', reason: 'a muscle given as the category becomes its body area');
    expect(walk.sets.length, 2);
    expect(walk.sets.every((s) => s.w == 24 && s.targetDurationSec == 60), isTrue);
    expect(walk.supersetWithNext, isFalse, reason: 'the last exercise of a day has nothing to chain to');

    expect(plan.days[1].rest, isTrue);
    expect(plan.days[1].exercises, isEmpty, reason: 'a rest day keeps no exercises');
    expect(plan.days[2].rest, isTrue, reason: 'an empty training day becomes a rest day');
    expect(plan.days.skip(3).every((d) => d.rest), isTrue, reason: 'missing days are rest days');
    expect(result.unknownExercises, ['Sandbag Hug Hold']);
  });

  test('accepts the bare plan or a "plan" wrapper instead of the envelope', () {
    final bare = jsonEncode({
      'name': 'Bare',
      'days': [
        {
          'rest': false,
          'exercises': [
            {'name': 'Squats', 'sets': 3, 'reps': '5', 'weight': 100},
          ],
        },
      ],
    });
    final squat = parse(bare).program!.days[0].exercises.single;
    expect(squat.sets.length, 3);
    expect(squat.sets.every((s) => s.r == '5' && s.w == 100), isTrue);
    expect(parse('{"plan": $bare}').program!.name, 'Bare');
  });

  test('places days by weekday name when the AI lists only training days', () {
    final result = parse(jsonEncode({
      'name': 'Three days',
      'days': [
        for (final day in ['Monday', 'Mittwoch', 'Vendredi'])
          {
            'label': day,
            'rest': false,
            'exercises': [
              {'name': 'Kreuzheben', 'sets': [{'w': 100, 'r': '5'}]},
            ],
          },
      ],
    }));
    expect([for (final d in result.program!.days) d.rest], [false, true, false, true, false, true, true]);
    expect([for (final d in result.program!.days) d.label], kWeekdays);
  });

  test('falls back to the order of the days when names repeat or are not weekdays', () {
    final result = parse(jsonEncode({
      'name': 'Labels',
      'days': [
        for (final label in ['Push', 'Pull'])
          {
            'label': label,
            'exercises': [
              {'name': 'Dips', 'sets': [{'w': 0, 'r': '10'}]},
            ],
          },
      ],
    }));
    expect([for (final d in result.program!.days.take(3)) d.rest], [false, false, true]);
  });

  test('matches names by id and without punctuation, reports the rest once', () {
    final result = parse(_plan([
      [
        {'name': 'bench press', 'sets': [{'w': 50, 'r': '8'}]},
        {'name': 'Schulterdrücken Langhantel', 'sets': [{'w': 30, 'r': '8'}]},
        {'name': 'Zercher Carry Deluxe', 'sets': [{'w': 40, 'r': '8'}]},
      ],
      [
        {'name': 'zercher carry deluxe', 'sets': [{'w': 40, 'r': '8'}]},
      ],
    ]));
    final names = [for (final d in result.program!.days) ...d.exercises.map((e) => e.name)];
    expect(names, ['Bankdrücken', 'Schulterdrücken (Langhantel)', 'Zercher Carry Deluxe', 'zercher carry deluxe']);
    expect(result.unknownExercises, ['Zercher Carry Deluxe']);
  });

  test('fills muscles the AI left out from what the app knows', () {
    const template = ExerciseTemplate(id: 'bench_press', name: 'Bankdrücken', category: 'chest');
    const custom = ExerciseTemplate(id: 'custom:1_0', name: 'Meine Übung', category: 'arms');
    final result = parseAiPlan(
      _plan([
        [
          {'name': 'Bankdrücken', 'sets': [{'w': 50, 'r': '8'}]},
          {'name': 'Meine Übung', 'sets': [{'w': 10, 'r': '12'}]},
          {'name': 'Unbekannt', 'sets': [{'w': 10, 'r': '12'}]},
        ],
      ]),
      library: [template, custom],
      customActivation: {
        'custom:1_0': {MuscleGroup.biceps: 80},
      },
      now: now,
    );
    final exercises = result.program!.days[0].exercises;
    expect(exercises[0].muscleActivation, {
      for (final e in muscleActivationForExercise(template).entries) e.key.name: e.value,
    });
    expect(exercises[0].muscle, 'chest');
    expect(exercises[1].muscleActivation, {'biceps': 80});
    expect(exercises[1].muscle, 'arms');
    expect(exercises[2].muscleActivation, isEmpty, reason: 'nothing is guessed for an unknown exercise');
    expect(exercises[2].muscle, '');
  });

  test('takes the body area from the strongest muscle when nothing else says it', () {
    final ex = parse(_plan([
      [
        {
          'name': 'Something new',
          'muscleActivation': {'glutes': 100, 'hamstrings': 60},
          'sets': [{'w': 0, 'r': '12'}],
        },
      ],
    ])).program!.days[0].exercises.single;
    expect(ex.muscle, 'legs');
  });

  test('daily exercises keep otherwise empty training days', () {
    final result = parse(_plan([
      [],
      null,
    ], daily: [
      {'name': 'Plank', 'logMode': 'timed', 'sets': [{'w': 0, 'r': '', 'targetDurationSec': 30}]},
    ]));
    expect(result.program!.days[0].rest, isFalse);
    expect(result.program!.days[1].rest, isTrue);
    expect(result.program!.dailyExercises.single.name, 'Plank');
  });

  test('cardio sets: 20 minutes when the time is missing, no speed when none is given', () {
    final run = parse(_plan([
      [
        {'name': 'Laufen', 'logMode': 'cardio', 'sets': [{'w': 50}]},
      ],
    ])).program!.days[0].exercises.single;
    expect(run.sets.single.w, 0, reason: 'cardio has no weight');
    expect(run.sets.single.targetDurationSec, 1200);
    expect(run.sets.single.targetSpeedKmh, 0, reason: 'a rower or cross trainer shows no km/h');
  });

  test('clamps numbers a model got wrong', () {
    final ex = parse(_plan([
      [
        {
          'name': 'Bankdrücken',
          'rest': 99999,
          'muscleActivation': {'chest': 250},
          'sets': [for (var i = 0; i < 40; i++) {'w': -5, 'r': '3x10'}],
        },
      ],
    ])).program!.days[0].exercises.single;
    expect(ex.rest, 900);
    expect(ex.muscleActivation['chest'], 100);
    expect(ex.sets.length, 20);
    expect(ex.sets.first.w, 0);
    expect(ex.sets.first.r, '10');
  });

  group('repairs JSON only when it does not parse', () {
    test('comments and trailing commas', () {
      const text = '''{
  // my plan
  "name": "Commented",
  "days": [
    {"label": "Montag", "exercises": [
      {"name": "Dips", /* bodyweight */ "sets": [{"w": 0, "r": "10"},],},
    ],},
  ],
}''';
      expect(parse(text).program!.days[0].exercises.single.name, 'Dips');
    });

    test('typographic quotes as delimiters', () {
      const text = '{“name”: “Quotes”, “days”: [{“label”: “Montag”, “exercises”: '
          '[{“name”: “Dips”, “sets”: [{“w”: 0, “r”: “10”}]}]}]}';
      expect(parse(text).program!.name, 'Quotes');
    });

    test('German quotes inside a valid note stay as they are', () {
      final ex = parse(_plan([
        [
          {'name': 'Dips', 'note': '„Push A“ – langsam', 'sets': [{'w': 0, 'r': '10'}]},
        ],
      ])).program!.days[0].exercises.single;
      expect(ex.note, '„Push A“ – langsam');
    });

    test('a URL inside a string is not taken for a comment', () {
      final ex = parse(_plan([
        [
          {'name': 'Dips', 'note': 'see https://example.com', 'sets': [{'w': 0, 'r': '10'}]},
        ],
      ])).program!.days[0].exercises.single;
      expect(ex.note, 'see https://example.com');
    });
  });

  group('a cut-off answer', () {
    Map<String, Object?> dips(String r) => {
          'name': 'Dips',
          'sets': [
            {'w': 0, 'r': r},
            {'w': 0, 'r': r},
          ],
        };

    test('keeps every complete day, says so, and leaves the rest as rest days', () {
      final full = const JsonEncoder.withIndent('  ').convert({
        'app': 'ironpeak',
        'type': 'plan',
        'version': 1,
        'data': {
          'name': 'Six days',
          'mode': 'weekday',
          'days': [
            for (var i = 0; i < 6; i++)
              {'label': kWeekdays[i], 'rest': false, 'exercises': [dips('${i + 5}')]},
            {'label': 'Sonntag', 'rest': true, 'exercises': []},
          ],
        },
      });
      // Stops in the middle of Saturday, like a reply that hit its length
      // limit; the code fence never closes either.
      final cut = full.substring(0, full.lastIndexOf('"exercises": [\n          {\n            "name": "Dips"') + 14);
      final result = parse('Here you go:\n\n```json\n$cut');

      expect(result.error, isNull);
      expect(result.cutOff, isTrue);
      final plan = result.program!;
      expect(plan.name, 'Six days');
      expect([for (final d in plan.days) d.rest], [false, false, false, false, false, true, true]);
      expect([for (final d in plan.days.take(5)) d.exercises.single.sets.first.r], ['5', '6', '7', '8', '9']);
    });

    test('a set list cut in the middle keeps its complete sets', () {
      final result = parse('{"name": "Cut", "days": [{"label": "Montag", "exercises": '
          '[{"name": "Dips", "sets": [{"w": 0, "r": "10"}, {"w": 0, "r": "1');
      expect(result.cutOff, isTrue);
      expect(result.program!.days[0].exercises.single.sets.map((s) => s.r), ['10']);
    });
  });

  group('tells the user what went wrong', () {
    test('nothing pasted', () {
      expect(parse('  \n ').error, AiPlanImportError.empty);
    });

    test('no plan in the text', () {
      expect(parse('Sure! What is your goal?').error, AiPlanImportError.noPlan);
      expect(parse('{"name": "no days"}').error, AiPlanImportError.noPlan);
      expect(parse('{"name": "cut off", "days": [{"label": "Montag", "exer').error, AiPlanImportError.noPlan);
    });

    test('more than a week', () {
      final days = [for (var i = 0; i < 8; i++) <Map<String, Object?>>[]];
      expect(parse(_plan(days)).error, AiPlanImportError.tooManyDays);
    });

    test('no exercise at all', () {
      expect(parse(_plan([null, null, []])).error, AiPlanImportError.noExercises);
    });

    test('the instructions pasted back instead of the answer -- never their example plan', () {
      final prompt = buildAiPlanPrompt(
        language: 'German',
        today: '2026-11-01',
        exercises: library,
        pastePath: const ['Settings', 'AI TRAINING PLAN', 'Paste plan from the AI'],
      );
      expect(parse(prompt).error, AiPlanImportError.promptNotAnswer);
      // A whole chat copied at once can't tell the example from the answer.
      expect(parse('$prompt\n\nSure!\n```json\n${_plan([[]])}\n```').error, AiPlanImportError.promptNotAnswer);
    });
  });

  test('a plan without a name gets the fallback name', () {
    final result = parse(jsonEncode({
      'days': [
        {
          'exercises': [
            {'name': 'Dips', 'sets': [{'w': 0, 'r': '10'}]},
          ],
        },
      ],
    }));
    expect(result.program!.name, 'Fallback');
  });
}
