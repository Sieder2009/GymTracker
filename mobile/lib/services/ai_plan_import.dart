import 'dart:convert';

import '../data/constants.dart';
import '../data/exercise_categories.dart';
import '../data/exercise_gif_lookup.dart' show normalizeExerciseName;
import '../data/exercise_muscle_map.dart';
import '../models/day.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/exercise_set.dart';
import '../models/exercise_template.dart';
import '../models/muscle_group.dart';
import '../models/program.dart';
import 'ai_plan_prompt.dart' show kAiPlanPromptOpening;

/// Reads a training plan that an AI chat wrote from the prompt in
/// `ai_plan_prompt.dart`. Deliberately forgiving, unlike
/// `parseSharedPlanPayload`: a chat answer comes wrapped in prose and a
/// ```json fence, and models drop fields, quote numbers, write "8–10" with
/// an en dash or leave a trailing comma. Everything it can read is cleaned
/// into the same [Program] the plan editor would build, and nothing a
/// model invents (ids, history, progress counters) is trusted.

/// Why [parseAiPlan] couldn't build a plan. Each needs a different fix
/// from the user, so each gets its own message.
enum AiPlanImportError {
  /// Nothing to read: an empty clipboard or paste field.
  empty,

  /// No JSON object with a `days` list anywhere in the text.
  noPlan,

  /// More than seven days, which can't be laid onto one week.
  tooManyDays,

  /// Shaped like a plan, but without a single exercise.
  noExercises,

  /// The instructions for the AI rather than its answer -- copied, then
  /// pasted back before the chat. They hold an example plan, which must
  /// not be taken for the user's plan.
  promptNotAnswer,
}

class AiPlanImportResult {
  AiPlanImportResult.success(Program this.program, {this.unknownExercises = const [], this.cutOff = false})
      : error = null;

  AiPlanImportResult.failure(AiPlanImportError this.error)
      : program = null,
        unknownExercises = const [],
        cutOff = false;

  final Program? program;
  final AiPlanImportError? error;

  /// Exercise names that match nothing in the exercise library, in plan
  /// order and without repeats. They import fine but get no animation.
  final List<String> unknownExercises;

  /// The text ended before the plan did (an answer that hit the model's
  /// length limit, or a paste that lost its end). [program] holds what was
  /// complete; the days after it are rest days.
  final bool cutOff;

  int get trainingDays => program?.days.where((d) => !d.rest).length ?? 0;

  int get exerciseCount {
    final p = program;
    if (p == null) return 0;
    var count = p.dailyExercises.length;
    for (final d in p.days) {
      count += d.exercises.length;
    }
    return count;
  }
}

const int _kMaxExercisesPerDay = 30;
const int _kMaxSetsPerExercise = 20;

/// Parses [text] (a whole chat answer, or just its JSON) into a ready-to-
/// train weekday plan with a fresh id, starting today.
///
/// [library] is the exercise database plus the user's own exercises. A name
/// is matched like the exercise animations match it (case and spacing
/// don't matter, an id such as `bench_press` counts too), then a looser
/// pass ignores punctuation. A match is renamed to the library's spelling,
/// and when the AI left out the muscles, it gets the library's muscle map
/// ([customActivation] for the user's own exercises).
AiPlanImportResult parseAiPlan(
  String text, {
  required List<ExerciseTemplate> library,
  Map<String, Map<MuscleGroup, double>> customActivation = const {},
  String fallbackName = 'AI plan',
  DateTime? now,
}) {
  if (text.trim().isEmpty) return AiPlanImportResult.failure(AiPlanImportError.empty);
  if (text.contains(kAiPlanPromptOpening)) {
    return AiPlanImportResult.failure(AiPlanImportError.promptNotAnswer);
  }

  Map<String, dynamic>? plan;
  var cutOff = false;
  for (final candidate in _jsonCandidates(text)) {
    plan = _planMap(_decodeLenient(candidate));
    if (plan != null) break;
    // An object that never closes: the text stops mid-plan. Keep what's
    // complete rather than reject the whole plan; the user is told.
    if (_matchingBrace(candidate, 0) == -1) {
      plan = _planMap(_decodeCutOff(candidate));
      if (plan != null) {
        cutOff = true;
        break;
      }
    }
  }
  if (plan == null) return AiPlanImportResult.failure(AiPlanImportError.noPlan);

  final rawDays = plan['days'] as List;
  if (rawDays.length > 7) return AiPlanImportResult.failure(AiPlanImportError.tooManyDays);

  final lib = _Library(library, customActivation);
  final unknown = _UnknownNames();
  final daily = _parseExercises(plan['dailyExercises'], lib, unknown);

  final days = [for (final label in kWeekdays) Day(label: label, rest: true)];
  final slots = _weekdaySlots(rawDays);
  for (var k = 0; k < rawDays.length; k++) {
    final raw = rawDays[k];
    if (raw is! Map) continue; // stays a rest day
    final slot = slots[k];
    // The prompt's contract: a rest day has no exercises. Exercises listed
    // on a day flagged as rest would sit hidden behind "Rest day" anyway.
    final rest = _bool(raw['rest']) ?? false;
    final exercises = rest ? <Exercise>[] : _parseExercises(raw['exercises'], lib, unknown);
    days[slot] = Day(
      label: kWeekdays[slot],
      // A training day without exercises would only show an empty list --
      // unless daily exercises fill it.
      rest: rest || (exercises.isEmpty && daily.isEmpty),
      exercises: exercises,
    );
  }

  final exerciseCount = daily.length + days.fold<int>(0, (n, d) => n + d.exercises.length);
  if (exerciseCount == 0) return AiPlanImportResult.failure(AiPlanImportError.noExercises);

  final stamp = now ?? DateTime.now();
  final name = _clip(_string(plan['name'])?.trim() ?? '', 60);
  return AiPlanImportResult.success(
    Program(
      id: 'plan_ai_${stamp.millisecondsSinceEpoch}',
      name: name.isEmpty ? fallbackName : name,
      // Always weekday: rotation plans never advance to their next day.
      mode: 'weekday',
      startDate: isoOf(stamp),
      days: days,
      dailyExercises: daily,
    ),
    unknownExercises: unknown.names,
    cutOff: cutOff,
  );
}

// --- Finding the JSON ------------------------------------------------------

/// Every span of [text] that might be the plan, most likely first: what's
/// inside ``` fences, then each balanced `{...}` in reading order (prose
/// before the plan may contain braces of its own).
Iterable<String> _jsonCandidates(String text) sync* {
  for (final fence in RegExp(r'```[A-Za-z]*[^\S\n]*\n?([\s\S]*?)```').allMatches(text)) {
    yield* _balancedObjects(fence.group(1)!);
  }
  yield* _balancedObjects(text);
}

Iterable<String> _balancedObjects(String s) sync* {
  var start = s.indexOf('{');
  for (var tries = 0; start != -1 && tries < 40; tries++) {
    final end = _matchingBrace(s, start);
    if (end == -1) {
      // Cut off mid-answer; still worth one decode attempt (a missing
      // closing brace can't be repaired, but it also can't hurt).
      yield s.substring(start);
      return;
    }
    yield s.substring(start, end + 1);
    start = s.indexOf('{', end + 1);
  }
}

/// Index of the `}` closing the `{` at [start], skipping braces inside
/// string values; -1 when it never closes.
int _matchingBrace(String s, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < s.length; i++) {
    final c = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// [candidate] as JSON, repairing the slips chat models make -- but only
/// when the text doesn't parse as it is, so valid JSON is never touched.
Object? _decodeLenient(String candidate) {
  Object? tryDecode(String s) {
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  final repaired = _stripCommentsAndTrailingCommas(candidate);
  return tryDecode(candidate) ??
      tryDecode(repaired) ??
      // Typographic quotes as delimiters (text that went through a word
      // processor). Last, because valid JSON may hold „these“ in a note.
      tryDecode(repaired.replaceAll(RegExp('[“”„‟″]'), '"'));
}

/// A cut-off object [s] (it never closes) made whole: everything up to the
/// last complete object or list, with every bracket still open closed
/// after it -- the longest prefix that decodes. Null when not even one
/// inner value is complete.
Object? _decodeCutOff(String s) {
  final open = <String>[]; // the closer each open bracket needs
  final cuts = <(int, String)>[]; // (end of a complete value, closers then)
  var inString = false;
  var escaped = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    switch (c) {
      case '"':
        inString = true;
      case '{':
        open.add('}');
      case '[':
        open.add(']');
      case '}' || ']':
        if (open.isEmpty) return null; // a stray closer: not JSON at all
        open.removeLast();
        if (open.isNotEmpty) cuts.add((i + 1, open.reversed.join()));
    }
  }
  var tries = 0;
  for (final (end, closers) in cuts.reversed) {
    if (++tries > 100) break;
    final decoded = _decodeLenient('${s.substring(0, end)}$closers');
    if (decoded != null) return decoded;
  }
  return null;
}

/// Drops `//` and `/* */` comments and commas right before `}` or `]`,
/// all outside string values.
String _stripCommentsAndTrailingCommas(String s) {
  final out = StringBuffer();
  var inString = false;
  var escaped = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (inString) {
      out.write(c);
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      while (i + 1 < s.length && s[i + 1] != '\n') {
        i++;
      }
      continue;
    } else if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
      final end = s.indexOf('*/', i + 2);
      i = end == -1 ? s.length : end + 1;
      continue;
    } else if (c == ',') {
      var j = i + 1;
      while (j < s.length && s[j].trim().isEmpty) {
        j++;
      }
      if (j < s.length && (s[j] == '}' || s[j] == ']')) continue;
    }
    out.write(c);
  }
  return out.toString();
}

/// The plan object inside [decoded]: the share envelope's `data`, a bare
/// plan, or one wrapped as `plan`/`program`.
Map<String, dynamic>? _planMap(Object? decoded) {
  if (decoded is! Map) return null;
  if (decoded['days'] is List) return Map<String, dynamic>.from(decoded);
  for (final key in const ['data', 'plan', 'program']) {
    final inner = decoded[key];
    if (inner is Map && inner['days'] is List) return Map<String, dynamic>.from(inner);
  }
  return null;
}

// --- Days ------------------------------------------------------------------

/// Where each of [rawDays] lands in the week. By weekday name when every
/// day carries a distinct, recognizable one (so a plan that lists only its
/// training days still lands on the right days), otherwise by position,
/// Monday first, as the prompt asks.
List<int> _weekdaySlots(List rawDays) {
  final byName = <int>[];
  for (final raw in rawDays) {
    final label = raw is Map ? _string(raw['label'] ?? raw['day'] ?? raw['weekday']) : null;
    final idx = label == null ? null : _weekdayIndex(label);
    if (idx == null || byName.contains(idx)) {
      return [for (var i = 0; i < rawDays.length; i++) i];
    }
    byName.add(idx);
  }
  return byName;
}

/// Weekday names in the app's ten languages, Monday first. German comes
/// first because that's what the prompt asks for; the rest catch a model
/// that translated the labels into the conversation's language.
const List<List<String>> _kWeekdayNames = [
  ['montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag'],
  ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
  ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'],
  ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'],
  ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'],
  ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'],
  ['poniedziałek', 'wtorek', 'środa', 'czwartek', 'piątek', 'sobota', 'niedziela'],
  ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'],
  ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'],
  ['pazartesi', 'salı', 'çarşamba', 'perşembe', 'cuma', 'cumartesi', 'pazar'],
];

/// Short forms count only as the whole label ("Mo"), never as a prefix --
/// "Mobility" is not Monday.
const List<List<String>> _kWeekdayShortNames = [
  ['mo', 'di', 'mi', 'do', 'fr', 'sa', 'so'],
  ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
];

/// Longest names first, so "cumartesi" (Saturday) wins over its prefix
/// "cuma" (Friday) and "pazartesi" over "pazar".
final List<(String, int)> _kWeekdayPrefixes = [
  for (final names in _kWeekdayNames)
    for (var i = 0; i < 7; i++) (names[i], i),
]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

int? _weekdayIndex(String label) {
  final s = label.trim().toLowerCase();
  if (s.isEmpty) return null;
  final word = s.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
  for (final names in _kWeekdayShortNames) {
    final i = names.indexOf(word);
    if (i != -1) return i;
  }
  for (final (name, i) in _kWeekdayPrefixes) {
    if (s.startsWith(name)) return i;
  }
  return null;
}

// --- Exercises -------------------------------------------------------------

class _Library {
  _Library(List<ExerciseTemplate> templates, this._customActivation) {
    for (final t in templates) {
      _exact.putIfAbsent(normalizeExerciseName(t.name), () => t);
      _loose.putIfAbsent(_looseKey(t.name), () => t);
    }
    // Ids read as words second, so a real name always wins.
    for (final t in templates) {
      _exact.putIfAbsent(normalizeExerciseName(t.id.replaceAll('_', ' ')), () => t);
      _loose.putIfAbsent(_looseKey(t.id), () => t);
    }
    _exact.remove('');
    _loose.remove('');
  }

  final Map<String, Map<MuscleGroup, double>> _customActivation;
  final Map<String, ExerciseTemplate> _exact = {};
  final Map<String, ExerciseTemplate> _loose = {};

  ExerciseTemplate? find(String name) => _exact[normalizeExerciseName(name)] ?? _loose[_looseKey(name)];

  /// What the app itself knows about [t]'s muscles: the user's own map for
  /// one of their exercises (nothing when they never set one), the curated
  /// map for a database exercise.
  Map<String, double> activationFor(ExerciseTemplate t) {
    final source = _customActivation[t.id] ??
        (t.id.startsWith('custom:') ? const <MuscleGroup, double>{} : muscleActivationForExercise(t));
    return {for (final e in source.entries) e.key.name: e.value};
  }
}

/// Lowercase letters and digits only, words separated by single spaces:
/// "Schulterdrücken Langhantel" finds "Schulterdrücken (Langhantel)".
String _looseKey(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();

class _UnknownNames {
  final Set<String> _seen = {};
  final List<String> names = [];

  void add(String name) {
    if (_seen.add(normalizeExerciseName(name))) names.add(name);
  }
}

List<Exercise> _parseExercises(Object? raw, _Library lib, _UnknownNames unknown) {
  if (raw is! List) return [];
  final exercises = <Exercise>[];
  for (final item in raw) {
    if (exercises.length == _kMaxExercisesPerDay) break;
    final exercise = item is Map ? _parseExercise(item, lib, unknown) : null;
    if (exercise != null) exercises.add(exercise);
  }
  // A superset link needs a next exercise to point at.
  if (exercises.isNotEmpty) exercises.last.supersetWithNext = false;
  return exercises;
}

Exercise? _parseExercise(Map m, _Library lib, _UnknownNames unknown) {
  final rawName = _string(m['name'] ?? m['exercise'])?.trim() ?? '';
  if (rawName.isEmpty) return null;
  final match = lib.find(rawName);
  final name = match?.name ?? _clip(rawName, 80);
  if (match == null) unknown.add(name);

  final logMode = _logMode(m);
  var activation = _activation(m['muscleActivation'] ?? m['muscles']);
  if (activation.isEmpty && match != null) activation = lib.activationFor(match);

  final exercise = Exercise.fresh(
    name,
    _category(m['muscle'] ?? m['category'], activation, match),
    _restSeconds(m['rest'] ?? m['restSeconds'] ?? m['restSec']),
    _parseSets(m, logMode),
    note: _clip(_string(m['note'] ?? m['notes'])?.trim() ?? '', 300),
    muscleActivation: activation,
    unilateral: _bool(m['unilateral']) ?? false,
    logMode: logMode,
  );
  exercise.supersetWithNext = _bool(m['supersetWithNext'] ?? m['superset']) ?? false;
  return exercise;
}

ExerciseLogMode _logMode(Map m) {
  switch (_string(m['logMode'] ?? m['mode'])?.trim().toLowerCase()) {
    case 'reps' || 'rep' || 'weight' || 'strength':
      return ExerciseLogMode.reps;
    case 'timed' || 'time' || 'hold' || 'duration' || 'isometric':
      return ExerciseLogMode.timed;
    case 'cardio' || 'distance' || 'endurance':
      return ExerciseLogMode.cardio;
  }
  // Not stated: tell from the sets what they measure.
  final rawSets = m['sets'];
  final sets = rawSets is List ? rawSets.whereType<Map>().toList() : [m];
  if (sets.any((s) => _pick(s, _kSpeedKeys) != null)) return ExerciseLogMode.cardio;
  final timed = sets.any((s) => _pick(s, _kSecondsKeys) != null || _pick(s, _kMinutesKeys) != null);
  final counted = sets.any((s) => _repsTarget(_pick(s, _kRepsKeys)).isNotEmpty);
  return timed && !counted ? ExerciseLogMode.timed : ExerciseLogMode.reps;
}

const List<String> _kWeightKeys = ['w', 'weight', 'weightKg', 'kg'];
const List<String> _kRepsKeys = ['r', 'reps', 'targetReps'];
const List<String> _kSecondsKeys = ['targetDurationSec', 'durationSec', 'seconds', 'duration'];
const List<String> _kMinutesKeys = ['minutes', 'durationMin', 'targetDurationMin'];
const List<String> _kSpeedKeys = ['targetSpeedKmh', 'speedKmh', 'speed'];

Object? _pick(Map m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null) return v;
  }
  return null;
}

/// One [ExerciseSet] per set the AI listed. Also takes the shorthand
/// `"sets": 3` (or a list of bare rep counts) with weight/reps on the
/// exercise itself.
List<ExerciseSet> _parseSets(Map m, ExerciseLogMode mode) {
  final raw = m['sets'];
  final List<Map> setMaps;
  if (raw is List) {
    setMaps = [
      for (final s in raw)
        if (s is Map) s else if (s is num || s is String) {'r': s},
    ];
  } else {
    setMaps = List.filled(_clampInt(_int(raw) ?? 3, 1, _kMaxSetsPerExercise), const {});
  }
  final sets = [
    for (final s in setMaps.take(_kMaxSetsPerExercise)) _parseSet(s, m, mode),
  ];
  if (sets.isEmpty) return List.generate(3, (_) => _parseSet(const {}, m, mode));
  return sets;
}

/// Reads one set from [s], falling back to the exercise's own fields [m]
/// for anything the set doesn't say. Defaults follow the plan editor's,
/// except a missing cardio speed: that stays 0, since a rower or cross
/// trainer has none (the prompt asks for 0 there).
ExerciseSet _parseSet(Map s, Map m, ExerciseLogMode mode) {
  Object? field(List<String> keys) => _pick(s, keys) ?? _pick(m, keys);
  final weight = _clampDouble(_num(field(_kWeightKeys)) ?? 0, 0, 1000);
  int? seconds() {
    final secs = _num(field(_kSecondsKeys));
    if (secs != null) return secs.round();
    final minutes = _num(field(_kMinutesKeys));
    return minutes == null ? null : (minutes * 60).round();
  }

  switch (mode) {
    case ExerciseLogMode.reps:
      final r = _repsTarget(field(_kRepsKeys));
      return ExerciseSet(w: weight, r: r.isEmpty ? '—' : r);
    case ExerciseLogMode.timed:
      return ExerciseSet(w: weight, r: '', targetDurationSec: _clampInt(seconds() ?? 30, 1, 3600));
    case ExerciseLogMode.cardio:
      return ExerciseSet(
        w: 0,
        r: '',
        targetDurationSec: _clampInt(seconds() ?? 20 * 60, 1, 4 * 3600),
        targetSpeedKmh: _clampDouble(_num(field(_kSpeedKeys)) ?? 0, 0, 60),
      );
  }
}

/// A rep target the way the app reads one -- "8" or "8-10" -- from what a
/// model writes: 8, "8–10", "8 to 10 reps", "3x10". Anything without a
/// number (AMRAP) is kept as short text, which the app shows but doesn't
/// progress.
String _repsTarget(Object? v) {
  if (v == null || v is bool) return '';
  if (v is num) return v.isFinite ? _clampInt(v.round(), 0, 999).toString() : '';
  var s = v.toString().trim();
  if (s.isEmpty) return '';
  s = s.replaceAllMapped(
    RegExp(r'(\d)\s*(?:-|–|—|−|to|bis)\s*(\d)', caseSensitive: false),
    (x) => '${x[1]}-${x[2]}',
  );
  final sets = RegExp(r'^\d+\s*[x×]\s*(\d+(?:-\d+)?)', caseSensitive: false).firstMatch(s);
  if (sets != null) return sets[1]!;
  final target = RegExp(r'^(\d+(?:-\d+)?)').firstMatch(s);
  if (target != null) return target[1]!;
  return _clip(s, 12);
}

/// Seconds of rest: 90, "90", "90s", "2 min", "1:30". The app's default
/// (90) when missing; at most 15 minutes.
int _restSeconds(Object? v) {
  if (v is String) {
    final clock = RegExp(r'^\s*(\d+):(\d{2})\s*$').firstMatch(v);
    if (clock != null) {
      return _clampInt(int.parse(clock[1]!) * 60 + int.parse(clock[2]!), 0, 900);
    }
    final n = _num(v);
    if (n == null) return 90;
    return _clampInt((v.toLowerCase().contains('min') ? n * 60 : n).round(), 0, 900);
  }
  final n = _num(v);
  return n == null ? 90 : _clampInt(n.round(), 0, 900);
}

// --- Muscles ---------------------------------------------------------------

/// Names models use for a muscle instead of the app's key, by [_bare] form.
const Map<String, MuscleGroup> _kMuscleSynonyms = {
  'pecs': MuscleGroup.chest,
  'pectorals': MuscleGroup.chest,
  'pectoralis': MuscleGroup.chest,
  'upperchest': MuscleGroup.chestUpper,
  'lowerchest': MuscleGroup.chestLower,
  'abdominals': MuscleGroup.abs,
  'core': MuscleGroup.abs,
  'frontdelt': MuscleGroup.frontDelts,
  'anteriordelts': MuscleGroup.frontDelts,
  'sidedelt': MuscleGroup.sideDelts,
  'lateraldelts': MuscleGroup.sideDelts,
  'reardelt': MuscleGroup.rearDelts,
  'posteriordelts': MuscleGroup.rearDelts,
  'bicep': MuscleGroup.biceps,
  'tricep': MuscleGroup.triceps,
  'forearm': MuscleGroup.forearms,
  'grip': MuscleGroup.forearms,
  'quad': MuscleGroup.quads,
  'quadriceps': MuscleGroup.quads,
  'hamstring': MuscleGroup.hamstrings,
  'glute': MuscleGroup.glutes,
  'gluteus': MuscleGroup.glutes,
  'calf': MuscleGroup.calves,
  'lat': MuscleGroup.lats,
  'latissimus': MuscleGroup.lats,
  'trap': MuscleGroup.traps,
  'trapezius': MuscleGroup.traps,
  'neck': MuscleGroup.traps,
  'rhomboids': MuscleGroup.upperBack,
  'erectors': MuscleGroup.lowerBack,
  'spinalerectors': MuscleGroup.lowerBack,
};

/// Lowercase letters only: "Front Delts", "front_delts" -> "frontdelts".
String _bare(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');

final Map<String, MuscleGroup> _kMusclesByBareName = {
  for (final m in MuscleGroup.values) _bare(m.name): m,
  ..._kMuscleSynonyms,
};

MuscleGroup? _muscle(String key) => muscleGroupFromKey(key) ?? _kMusclesByBareName[_bare(key)];

/// `MuscleGroup.name -> 0-100` with every unknown key dropped. Values
/// written as fractions (0.8) are read as percent.
Map<String, double> _activation(Object? raw) {
  if (raw is! Map) return {};
  final values = <String, double>{};
  for (final e in raw.entries) {
    final muscle = _muscle(e.key.toString());
    final v = _num(e.value);
    if (muscle == null || v == null || v <= 0) continue;
    values[muscle.name] = v;
  }
  final fractions = values.values.every((v) => v <= 1);
  return {
    for (final e in values.entries)
      e.key: _clampDouble((fractions ? e.value * 100 : e.value).roundToDouble(), 1, 100),
  };
}

/// The broad category ([Exercise.muscle]) of a muscle.
String _categoryOf(MuscleGroup m) => switch (muscleGroupParent(m) ?? m) {
      MuscleGroup.chest => 'chest',
      MuscleGroup.lats || MuscleGroup.upperBack || MuscleGroup.lowerBack || MuscleGroup.traps => 'back',
      MuscleGroup.frontDelts || MuscleGroup.sideDelts || MuscleGroup.rearDelts => 'shoulders',
      MuscleGroup.biceps || MuscleGroup.triceps || MuscleGroup.forearms => 'arms',
      MuscleGroup.abs || MuscleGroup.obliques => 'core',
      _ => 'legs',
    };

/// The AI's category when it's one of the seven; a muscle name in its
/// place is turned into the area it belongs to. Otherwise the library's
/// category, otherwise the area of the most worked muscle, otherwise none.
String _category(Object? raw, Map<String, double> activation, ExerciseTemplate? match) {
  final s = _string(raw)?.trim().toLowerCase() ?? '';
  if (kExerciseCategories.contains(s)) return s;
  final plural = '${s}s';
  if (kExerciseCategories.contains(plural)) return plural; // "leg", "shoulder", "arm"
  final asMuscle = s.isEmpty ? null : _muscle(s);
  if (asMuscle != null) return _categoryOf(asMuscle);
  if (match != null && kExerciseCategories.contains(match.category)) return match.category;
  if (activation.isEmpty) return '';
  final strongest = activation.entries.reduce((a, b) => b.value > a.value ? b : a);
  final muscle = muscleGroupFromKey(strongest.key);
  return muscle == null ? '' : _categoryOf(muscle);
}

// --- Scalars ---------------------------------------------------------------

String? _string(Object? v) => v is String ? v : (v is num ? v.toString() : null);

/// A number from a number or from text such as "60 kg" or "2,5".
double? _num(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is! String) return null;
  final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(v);
  return m == null ? null : double.tryParse(m[0]!.replaceAll(',', '.'));
}

int? _int(Object? v) => _num(v)?.round();

bool? _bool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    switch (v.trim().toLowerCase()) {
      case 'true' || 'yes' || 'ja' || '1':
        return true;
      case 'false' || 'no' || 'nein' || '0':
        return false;
    }
  }
  return null;
}

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

double _clampDouble(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max).trimRight();
