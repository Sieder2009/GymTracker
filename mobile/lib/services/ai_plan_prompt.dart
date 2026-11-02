import '../data/constants.dart';
import '../data/effort_scale.dart';
import '../data/exercise_categories.dart';
import '../data/exercise_gif_lookup.dart' show normalizeExerciseName;
import '../models/exercise_log_mode.dart';
import '../models/exercise_template.dart';
import '../models/muscle_group.dart';
import '../models/program.dart';

/// The text a user copies into an AI chat (ChatGPT, Claude, Gemini, ...)
/// so it writes a training plan Kilo can import as it is -- see
/// `ai_plan_import.dart` for the reading side. Written in English, which
/// every model follows most reliably; the model is told to talk to the user
/// in the app's language. Built from the live exercise library, so the AI
/// can only pick names the app knows, and it documents every field a
/// person fills in by hand in the plan editor: sets, reps, weight, rest,
/// how a set is logged, notes, one side at a time, supersets, the muscle
/// group and the muscles shown on the body diagram.

/// English names of the app's languages, for "talk to me in ...".
const Map<String, String> _kLanguageNames = {
  'de': 'German',
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'it': 'Italian',
  'nl': 'Dutch',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'tr': 'Turkish',
};

String aiPromptLanguageName(String languageCode) => _kLanguageNames[languageCode] ?? 'English';

/// The prompt's first sentence. The import looks for it to recognize the
/// prompt itself pasted back in -- which also holds a complete example
/// plan, the one plan that must never be imported.
const String kAiPlanPromptOpening = 'I want a training plan for my workout app Kilo.';

/// What the user agreed to share about themselves (Settings > "Include my
/// data"). Every part is optional; a missing one is simply not mentioned.
class AiPromptProfile {
  const AiPromptProfile({
    this.isMale,
    this.bodyWeightKg,
    this.bodyWeightDate,
    this.prs = const {},
    this.workingWeights = const [],
  });

  final bool? isMale;
  final double? bodyWeightKg;
  final String? bodyWeightDate;

  /// Heaviest weight per big lift, keyed `bench`/`squat`/`deadlift`.
  final Map<String, double> prs;

  final List<AiPromptWorkingWeight> workingWeights;

  bool get isEmpty => isMale == null && bodyWeightKg == null && prs.isEmpty && workingWeights.isEmpty;
}

/// The last logged session of one exercise: its weight and the reps of
/// each set.
class AiPromptWorkingWeight {
  const AiPromptWorkingWeight({required this.name, required this.weightKg, this.reps = const []});

  final String name;
  final double weightKg;
  final List<int> reps;
}

/// The most recently trained exercises across [programs], newest first,
/// one line per exercise name: weight-and-reps sessions only, at most
/// [limit]. Entries without a date (pasted-in logs) count as oldest.
List<AiPromptWorkingWeight> recentWorkingWeights(Iterable<Program> programs, {int limit = 25}) {
  final latest = <String, (String, AiPromptWorkingWeight)>{};
  for (final program in programs) {
    for (final exercise in [...program.days.expand((d) => d.exercises), ...program.dailyExercises]) {
      final entries = exercise.history.where((h) => h.mode == ExerciseLogMode.reps && h.weight > 0);
      if (entries.isEmpty) continue;
      final last = entries.last;
      final date = last.date ?? '';
      final key = normalizeExerciseName(exercise.name);
      final known = latest[key];
      if (known != null && known.$1.compareTo(date) >= 0) continue;
      latest[key] = (
        date,
        AiPromptWorkingWeight(
          name: exercise.name,
          weightKg: last.weight,
          reps: [for (final r in last.reps) if (r is int) r],
        ),
      );
    }
  }
  final sorted = latest.values.toList()..sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final e in sorted.take(limit)) e.$2];
}

/// The complete example plan inside the prompt. Valid JSON in exactly the
/// format the import reads (a test parses it), showing every kind of
/// exercise once: weight x reps, one side at a time, a timed hold, a
/// superset and a cardio bout.
const String kAiPlanPromptExample = '''
{
  "app": "ironpeak",
  "type": "plan",
  "version": 1,
  "data": {
    "name": "Full body 2x",
    "mode": "weekday",
    "days": [
      {
        "label": "Montag",
        "rest": false,
        "exercises": [
          {
            "name": "Bankdrücken",
            "muscle": "chest",
            "muscleActivation": {"chest": 100, "frontDelts": 40, "triceps": 45},
            "rest": 150,
            "logMode": "reps",
            "sets": [{"w": 60, "r": "6-8"}, {"w": 60, "r": "6-8"}, {"w": 60, "r": "6-8"}],
            "note": "Full body A – stop 1-2 reps before failure",
            "unilateral": false,
            "supersetWithNext": false
          },
          {
            "name": "Bulgarian Split Squats",
            "muscle": "legs",
            "muscleActivation": {"quads": 100, "glutes": 85, "hamstrings": 30},
            "rest": 90,
            "logMode": "reps",
            "sets": [{"w": 12, "r": "20"}, {"w": 12, "r": "20"}, {"w": 12, "r": "20"}],
            "note": "10 per leg, one dumbbell in each hand",
            "unilateral": true,
            "supersetWithNext": false
          },
          {
            "name": "Plank",
            "muscle": "core",
            "muscleActivation": {"abs": 100, "obliques": 40},
            "rest": 60,
            "logMode": "timed",
            "sets": [{"w": 0, "r": "", "targetDurationSec": 45}, {"w": 0, "r": "", "targetDurationSec": 45}],
            "note": "",
            "unilateral": false,
            "supersetWithNext": false
          }
        ]
      },
      {"label": "Dienstag", "rest": true, "exercises": []},
      {
        "label": "Mittwoch",
        "rest": false,
        "exercises": [
          {
            "name": "Klimmzüge",
            "muscle": "back",
            "muscleActivation": {"lats": 100, "upperBack": 55, "biceps": 50, "rearDelts": 25},
            "rest": 120,
            "logMode": "reps",
            "sets": [{"w": 0, "r": "6-10"}, {"w": 0, "r": "6-10"}, {"w": 0, "r": "6-10"}],
            "note": "Full body B – bodyweight, full range of motion",
            "unilateral": false,
            "supersetWithNext": false
          },
          {
            "name": "Langhantel-Bizepscurls",
            "muscle": "arms",
            "muscleActivation": {"biceps": 100, "forearms": 25},
            "rest": 60,
            "logMode": "reps",
            "sets": [{"w": 25, "r": "10-12"}, {"w": 25, "r": "10-12"}],
            "note": "Superset with the next exercise",
            "unilateral": false,
            "supersetWithNext": true
          },
          {
            "name": "Trizepsdrücken am Kabel",
            "muscle": "arms",
            "muscleActivation": {"triceps": 90, "tricepsLateralHead": 100},
            "rest": 60,
            "logMode": "reps",
            "sets": [{"w": 0, "r": "10-12"}, {"w": 0, "r": "10-12"}],
            "note": "Rope attachment, elbows stay at your sides",
            "unilateral": false,
            "supersetWithNext": false
          },
          {
            "name": "Laufband",
            "muscle": "cardio",
            "muscleActivation": {"quads": 100, "calves": 80, "hamstrings": 60, "glutes": 50},
            "rest": 0,
            "logMode": "cardio",
            "sets": [{"w": 0, "r": "", "targetDurationSec": 1200, "targetSpeedKmh": 9.5}],
            "note": "Easy pace, you can still talk",
            "unilateral": false,
            "supersetWithNext": false
          }
        ]
      },
      {"label": "Donnerstag", "rest": true, "exercises": []},
      {"label": "Freitag", "rest": true, "exercises": []},
      {"label": "Samstag", "rest": true, "exercises": []},
      {"label": "Sonntag", "rest": true, "exercises": []}
    ],
    "dailyExercises": []
  }
}''';

/// Builds the prompt.
///
/// [language] is an English language name ([aiPromptLanguageName]),
/// [today] an ISO date. [exercises] is the shared exercise database,
/// [customExercises] the user's own. [pastePath] is where the import sits
/// in the app, in the app's language (e.g. Settings > section > row), so the
/// AI's closing hint names the buttons exactly as the user sees them.
String buildAiPlanPrompt({
  required String language,
  required String today,
  required List<ExerciseTemplate> exercises,
  List<ExerciseTemplate> customExercises = const [],
  AiPromptProfile? profile,
  double barWeightKg = 20,
  EffortScale effortScale = EffortScale.rpe,
  required List<String> pastePath,
}) {
  final hasProfile = profile != null && !profile.isEmpty;
  final path = pastePath.map((p) => '"$p"').join(' → ');
  final b = StringBuffer()
    ..writeln('$kAiPlanPromptOpening Please act as my experienced personal trainer. '
        'Kilo reads your answer as data, so the plan has to follow the JSON format below exactly.')
    ..writeln()
    ..writeln('Talk to me in $language, and write the plan name and all notes in $language. Today is $today.')
    ..writeln()
    ..writeln('HOW WE WORK')
    ..writeln('1. First ask me what you need to know, in one short message with numbered questions: my goal '
        '(build muscle, get stronger, lose fat, get fitter), my training experience, how many days a week and '
        'on which weekdays I can train, how long a session may take, where I train and what equipment I have, '
        'injuries or exercises I can\'t do, and wishes (favourite exercises, cardio, weak points)'
        '${hasProfile ? '. Don\'t ask for anything "About me" already answers' : ', plus my sex, age, height, body weight and, if I know them, my current weights for the main lifts'}. '
        'Then wait for my answers.')
    ..writeln('2. Build the plan the way a good coach would: big compound lifts first, a balanced split, '
        'sensible weekly volume per muscle and enough recovery. Every session has to fit the time I have: Kilo '
        'counts about 3 minutes per set (rest included) plus the time of holds and cardio; leave a few minutes for '
        'warming up, and mention each session\'s length in your explanation.')
    ..writeln('3. Send the complete plan as ONE ```json code block that contains nothing but the JSON. Before it, '
        'explain the plan in a few short sentences. After it, tell me: copy the code block, then in Kilo tap $path.')
    ..writeln('4. If I ask for changes, send the complete updated JSON again, never just the changed part.')
    ..writeln();

  if (hasProfile) {
    b.writeln('ABOUT ME (from my app)');
    _writeProfile(b, profile);
    b.writeln();
  }

  b
    ..writeln('KILO SETTINGS')
    ..writeln('- All weights are in kg. My barbell weighs ${_kg(barWeightKg)} kg.')
    ..writeln(effortScale == EffortScale.rir
        ? '- Kilo records how hard each set was as RIR (reps in reserve, 0 = failure).'
        : '- Kilo records how hard each set was as RPE (5-10, 10 = failure).')
    ..writeln()
    ..writeln('JSON FORMAT (an example – its texts are in English, yours are in $language; exercise names and '
        'weekday labels stay exactly as listed)')
    ..writeln(kAiPlanPromptExample)
    ..writeln()
    ..writeln('RULES FOR THE PLAN')
    ..writeln('- Keep "app", "type" and "version" exactly as in the example ("ironpeak" is Kilo\'s technical '
        'name). "mode" is always "weekday".')
    ..writeln('- "name": a short name for the plan.')
    ..writeln('- "days": exactly 7 entries, Monday to Sunday in this order. "label" is always the German weekday: '
        '${kWeekdays.join(', ')} – even if we talk in another language.')
    ..writeln('- Kilo repeats the same week every week, so plan one fixed week (no alternating A/B weeks).')
    ..writeln('- A rest day is {"label": "Dienstag", "rest": true, "exercises": []}.')
    ..writeln('- Kilo has no field for a session\'s title: start the "note" of the FIRST exercise of each training '
        'day with it, e.g. "Push A – …".')
    ..writeln('- "dailyExercises": only if I explicitly want something in every session – Kilo shows these on '
        'every training day in addition to the day\'s own exercises. Otherwise [].')
    ..writeln()
    ..writeln('RULES FOR EACH EXERCISE')
    ..writeln('- "name": copy the name exactly from the exercise list at the end (German names, same spelling). '
        'Only exact names get Kilo\'s exercise animation and statistics. If the list has the exercise for my '
        'equipment (e.g. a "(Kurzhantel)" variant), take that one; otherwise the general name, with the equipment '
        'in the note. Only if nothing on the list fits, write your own short, clear name.')
    ..writeln('- "muscle": the group the exercise is listed under in the exercise list (e.g. Rumänisches '
        'Kreuzheben is back, even on a leg day). For your own names, the closest of: '
        '${kExerciseCategories.join(', ')}.')
    ..writeln('- "muscleActivation": which muscles the exercise trains and how hard, 1-100. Kilo colours them on its '
        'body diagram. What it targets most gets 100 – that may be a detailed part (see the muscle keys) – the '
        'others less by how much they work; usually 1-5 keys (one is fine for an isolation exercise), leaving out '
        'muscles that barely work. Use only the muscle keys below; muscles without a key (adductors, hip flexors, '
        'shins) are left out.')
    ..writeln('- "rest": rest between sets in seconds, e.g. 150-180 for heavy compound lifts, 90-120 for other '
        'compound lifts, 60-90 for isolation exercises.')
    ..writeln('- "logMode": "reps" (weight × reps), "timed" (holds such as plank, wall sit, dead hang, loaded '
        'carries) or "cardio" (running, cycling, rowing and the like).')
    ..writeln('- "sets": one object per working set (no warm-up sets) – 4 sets are 4 objects. Sets may differ, e.g. '
        'a pyramid or a top set with back-off sets.')
    ..writeln('  - reps: {"w": 60, "r": "8-10"}. "r" is the target as a string: one number ("8") or a range '
        '("8-10"), nothing else.')
    ..writeln('  - timed: {"w": 0, "r": "", "targetDurationSec": 45}. Here "w" is extra weight, 0 = none.')
    ..writeln('  - cardio: {"w": 0, "r": "", "targetDurationSec": 1200, "targetSpeedKmh": 9.5}. Usually one set. '
        '"targetSpeedKmh" only where the machine shows km/h (treadmill, bike), otherwise 0.')
    ..writeln('- "w" is the total weight in kg: barbell, SZ bar or trap bar = total including that bar, dumbbells = '
        'one dumbbell, machines and cables = the number on the stack, 0 = bodyweight or not set yet. '
        'Estimate barbell and dumbbell weights from '
        '${hasProfile ? '"About me"' : 'what I tell you'}, rather a little too light. Machines and cables differ '
        'from gym to gym: use 0 for them unless ${hasProfile ? '"About me" gives' : 'I give you'} that exercise\'s '
        'weight – I\'ll set it in the app. Resistance bands: 0, and describe the band in the note. Decimals are '
        'fine (12.5); only use weights my equipment has.')
    ..writeln('- "note": a short coaching tip (technique, tempo, the target ${effortScale == EffortScale.rir ? 'RIR' : 'RPE'}) '
        'or "".')
    ..writeln('- "unilateral": true for exercises done one side at a time, alternating ones included (lunges, split '
        'squats, one-arm rows, dead bugs). '
        'Then "r" counts both sides together (8-10 per side is "16-20"), a hold\'s "targetDurationSec" is per '
        'side, and "rest" is the pause after both sides.')
    ..writeln('- "supersetWithNext": true joins this exercise with the next one into a superset. Kilo then goes '
        'straight from one to the next and rests only after each round, using the "rest" of the superset\'s last '
        'exercise. Give the exercises of a superset the same number of sets; three or more in a row make a '
        'circuit. Never true on the last exercise of a day.')
    ..writeln()
    ..writeln('MUSCLE KEYS for "muscleActivation"');
  _writeMuscles(b);
  b
    ..writeln()
    ..writeln('EXERCISE LIST (exact names, grouped by "muscle")');
  _writeExercises(b, exercises, customExercises);
  return b.toString().trimRight();
}

void _writeProfile(StringBuffer b, AiPromptProfile p) {
  final isMale = p.isMale;
  if (isMale != null) b.writeln('- Sex: ${isMale ? 'male' : 'female'}');
  final bodyWeight = p.bodyWeightKg;
  if (bodyWeight != null) {
    final date = p.bodyWeightDate;
    b.writeln('- Body weight: ${_kg(bodyWeight)} kg${date == null ? '' : ' (weighed on $date)'}');
  }
  if (p.prs.isNotEmpty) {
    const names = {'bench': 'bench press', 'squat': 'squat', 'deadlift': 'deadlift'};
    final lifts = [
      for (final key in names.keys)
        if (p.prs[key] case final kg?) '${names[key]} ${_kg(kg)} kg',
    ];
    b.writeln('- Heaviest weight I have lifted (PR): ${lifts.join(', ')}');
  }
  if (p.workingWeights.isNotEmpty) {
    b.writeln('- My latest sessions (weight × reps per set):');
    for (final w in p.workingWeights) {
      final reps = w.reps.isEmpty ? '' : ' × ${w.reps.join(', ')}';
      b.writeln('  - ${w.name}: ${_kg(w.weightKg)} kg$reps');
    }
  }
}

void _writeMuscles(StringBuffer b) {
  final main = MuscleGroup.values.where((m) => muscleGroupParent(m) == null);
  b.writeln('Main muscles: ${main.map((m) => '${m.name} (${_muscleDescription(m)})').join(' · ')}');
  b.writeln('Detailed parts – optional, and only together with their main muscle, when an exercise clearly '
      'favours one part (e.g. incline press: chest 80 + chestUpper 100):');
  final parts = <MuscleGroup, List<MuscleGroup>>{};
  for (final m in MuscleGroup.values) {
    final parent = muscleGroupParent(m);
    if (parent != null) (parts[parent] ??= []).add(m);
  }
  b.writeln(parts.entries
      .map((e) => '${e.value.map((m) => '${m.name} (${_muscleDescription(m)})').join(', ')} → ${e.key.name}')
      .join(' · '));
}

/// Plain-English description of each muscle key. A switch rather than a
/// map, so a muscle added to [MuscleGroup] can't be forgotten here.
String _muscleDescription(MuscleGroup m) => switch (m) {
      MuscleGroup.chest => 'pecs',
      MuscleGroup.abs => 'six-pack',
      MuscleGroup.obliques => 'side abs',
      MuscleGroup.frontDelts => 'front shoulders',
      MuscleGroup.sideDelts => 'side shoulders',
      MuscleGroup.biceps => 'front upper arm',
      MuscleGroup.forearms => 'forearms and grip',
      MuscleGroup.quads => 'front thighs',
      MuscleGroup.calves => 'lower legs',
      MuscleGroup.upperBack => 'between the shoulder blades',
      MuscleGroup.lowerBack => 'spinal erectors',
      MuscleGroup.lats => 'wide back muscles',
      MuscleGroup.traps => 'upper traps and neck',
      MuscleGroup.rearDelts => 'rear shoulders',
      MuscleGroup.triceps => 'back upper arm',
      MuscleGroup.glutes => 'buttocks',
      MuscleGroup.hamstrings => 'back thighs',
      MuscleGroup.tricepsLongHead => 'long head',
      MuscleGroup.tricepsLateralHead => 'lateral head',
      MuscleGroup.tricepsMedialHead => 'medial head',
      MuscleGroup.bicepsLongHead => 'long head',
      MuscleGroup.bicepsShortHead => 'short head',
      MuscleGroup.chestUpper => 'upper chest',
      MuscleGroup.chestMid => 'middle chest',
      MuscleGroup.chestLower => 'lower chest',
      MuscleGroup.quadRectusFemoris => 'rectus femoris',
      MuscleGroup.quadVastusLateralis => 'outer quad',
      MuscleGroup.quadVastusMedialis => 'inner quad, teardrop',
    };

void _writeExercises(StringBuffer b, List<ExerciseTemplate> exercises, List<ExerciseTemplate> custom) {
  final byCategory = <String, List<String>>{};
  for (final e in exercises) {
    final category = kExerciseCategories.contains(e.category) ? e.category : 'other';
    (byCategory[category] ??= []).add(e.name);
  }
  for (final category in [...kExerciseCategories, 'other']) {
    final names = byCategory[category];
    if (names != null) b.writeln('$category: ${names.join(' | ')}');
  }
  if (custom.isNotEmpty) {
    b.writeln('My own exercises, use them where they fit: '
        '${custom.map((e) => '${e.name} (${e.category})').join(' | ')}');
  }
}

/// "80", "82.5" -- no trailing ".0", one decimal at most.
String _kg(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
