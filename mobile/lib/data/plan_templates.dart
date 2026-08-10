import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'constants.dart';
import '../models/day.dart';
import '../models/exercise.dart';
import '../models/exercise_set.dart';
import '../models/program.dart';

class PlanTemplateExercise {
  const PlanTemplateExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  final String name;
  final int sets;
  final String reps;
  final int restSeconds;

  factory PlanTemplateExercise.fromJson(Map<String, dynamic> json) => PlanTemplateExercise(
        name: json['name'] as String,
        sets: (json['sets'] as num).toInt(),
        reps: json['reps'] as String,
        restSeconds: (json['restSeconds'] as num).toInt(),
      );
}

class PlanTemplateDay {
  const PlanTemplateDay({required this.rest, this.marker = '', this.exercises = const []});

  final bool rest;
  final String marker;
  final List<PlanTemplateExercise> exercises;

  factory PlanTemplateDay.fromJson(Map<String, dynamic> json) => PlanTemplateDay(
        rest: json['rest'] as bool? ?? false,
        marker: json['marker'] as String? ?? '',
        exercises: (json['exercises'] as List? ?? [])
            .map((e) => PlanTemplateExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A full 7-day (Mo-So) program blueprint -- structure only (days,
/// exercises, sets/reps/rest), no display name: same convention as the
/// original hand-written PPL builder, so the name can be localized by the
/// caller instead of being baked into data that ships in every language at
/// once.
class PlanTemplate {
  const PlanTemplate({required this.id, required this.days});

  final String id;
  final List<PlanTemplateDay> days;

  factory PlanTemplate.fromJson(Map<String, dynamic> json) => PlanTemplate(
        id: json['id'] as String,
        days: (json['days'] as List)
            .map((d) => PlanTemplateDay.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}

/// Loads every template from `assets/plan_templates.json` -- a data-driven
/// pendant to `example_ppl_plan.dart`'s hand-written PPL builder, for the
/// rest of the well-known program splits (Upper/Lower, Arnold Split, Full
/// Body, Bro Split, ...) without hardcoding each one as its own Dart file.
/// Exercise names are verified verbatim against `assets/exercises.json` by
/// `test/plan_templates_test.dart`, same guarantee the PPL builder already
/// has.
Future<List<PlanTemplate>> loadPlanTemplates() async {
  final raw = await rootBundle.loadString('assets/plan_templates.json');
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return (decoded['templates'] as List)
      .map((t) => PlanTemplate.fromJson(t as Map<String, dynamic>))
      .toList();
}

/// Builds a fresh, ready-to-train [Program] from a [PlanTemplate] -- every
/// set starts at 0kg/bodyweight, same as [buildExamplePplProgram] and a
/// freshly hand-built plan; the user dials in real working weights via the
/// guided workout's stepper as they go.
Program buildProgramFromTemplate(PlanTemplate template, {required String name}) {
  final days = <Day>[
    for (var i = 0; i < template.days.length; i++)
      Day(
        label: kWeekdays[i],
        rest: template.days[i].rest,
        exercises: [
          for (var j = 0; j < template.days[i].exercises.length; j++)
            Exercise.fresh(
              template.days[i].exercises[j].name,
              '',
              template.days[i].exercises[j].restSeconds,
              List.generate(
                template.days[i].exercises[j].sets,
                (_) => ExerciseSet(w: 0, r: template.days[i].exercises[j].reps),
              ),
              note: j == 0 ? template.days[i].marker : '',
            ),
        ],
      ),
  ];

  return Program(
    id: 'plan_${template.id}_${DateTime.now().millisecondsSinceEpoch}',
    name: name,
    mode: 'weekday',
    startDate: todayIso(),
    days: days,
  );
}
