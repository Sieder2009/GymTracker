import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../data/effort_scale.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/history_entry.dart';
import '../models/program.dart';
import '../services/storage_service.dart';

const String _kProgramsKey = 'ironpeak:programs';

/// Owns every saved [Program]. Exercise-mutation methods take the already
/// resolved `List<Exercise>` (either `program.days[i].exercises` or
/// `program.dailyExercises`) rather than duplicating a parallel set of
/// "daily" handlers — since Dart lists are references, mutating the
/// passed-in list mutates the Program itself.
class ProgramsProvider extends ChangeNotifier {
  ProgramsProvider(this._storage) : _programs = _initial(_storage);

  final StorageService _storage;
  final List<Program> _programs;

  List<Program> get programs => List.unmodifiable(_programs);

  static List<Program> _initial(StorageService storage) {
    final decoded = storage.readJson<List<Program>>(
      _kProgramsKey,
      (raw) => (raw as List)
          .map((e) => Program.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return decoded ?? [];
  }

  void _persist() {
    _storage.writeJson(
      _kProgramsKey,
      () => _programs.map((p) => p.toJson()).toList(),
    );
  }

  Program? byId(String? id) {
    if (id == null) return null;
    for (final p in _programs) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addProgram(Program program) {
    _programs.add(program);
    _persist();
    notifyListeners();
  }

  void removeProgram(String id) {
    _programs.removeWhere((p) => p.id == id);
    _persist();
    notifyListeners();
  }

  /// Appends a new [Exercise] to an already-saved plan's day (or its
  /// `dailyExercises`) — the only way exercises previously entered a plan
  /// was via [PlanEditorScreen] at creation time; this lets a user extend a
  /// plan afterwards from `AddExerciseSheet`.
  void addExercise(List<Exercise> exercises, Exercise exercise) {
    exercises.add(exercise);
    _persist();
    notifyListeners();
  }

  /// Removes one exercise from an already-saved plan's day (or its
  /// `dailyExercises`) -- the inverse of [addExercise]. Takes its logged
  /// history with it, which is why the caller confirms first.
  void removeExercise(List<Exercise> exercises, int exIdx) {
    exercises.removeAt(exIdx);
    _persist();
    notifyListeners();
  }

  /// Moves an exercise from [oldIndex] to [newIndex] within the same
  /// resolved list (a day's exercises, or `dailyExercises`) -- the caller
  /// (a `ReorderableListView.onReorder`) has already done the standard
  /// `newIndex > oldIndex` correction, so this just does the move.
  void reorderExercise(List<Exercise> exercises, int oldIndex, int newIndex) {
    final item = exercises.removeAt(oldIndex);
    exercises.insert(newIndex, item);
    _persist();
    notifyListeners();
  }

  void setMuscle(List<Exercise> exercises, int exIdx, String muscle) {
    exercises[exIdx].muscle = muscle;
    _persist();
    notifyListeners();
  }

  void setNote(List<Exercise> exercises, int exIdx, String note) {
    exercises[exIdx].note = note;
    _persist();
    notifyListeners();
  }

  /// Flips `exercises[exIdx]`'s "logged per side (unilateral)" toggle -- see
  /// `Exercise.unilateral`. Same shape as [setMuscle]/[setNote].
  void setUnilateral(List<Exercise> exercises, int exIdx, bool unilateral) {
    exercises[exIdx].unilateral = unilateral;
    _persist();
    notifyListeners();
  }

  /// Flips `exercises[exIdx]`'s "how this is logged" toggle (see
  /// [Exercise.logMode]) and seeds sane defaults on every set of that
  /// exercise for whichever target field the new mode needs but doesn't
  /// have yet (`targetDurationSec ??= 30`, and `targetSpeedKmh ??= 6.0` for
  /// Cardio) -- never overwriting an already-set value, and never touching
  /// [ExerciseSet.r] (so switching back to Reps restores its original
  /// target range/count untouched).
  void setLogMode(List<Exercise> exercises, int exIdx, ExerciseLogMode mode) {
    final ex = exercises[exIdx];
    ex.logMode = mode;
    if (mode == ExerciseLogMode.timed || mode == ExerciseLogMode.cardio) {
      for (final s in ex.sets) {
        s.targetDurationSec ??= 30;
        if (mode == ExerciseLogMode.cardio) {
          s.targetSpeedKmh ??= 6.0;
        }
      }
    } else {
      // Switching (back) into Reps: a set that was created directly as
      // Timed/Cardio never had a target rep range/count typed in (r stays
      // '' -- see the architecture note on ExerciseSet.r), so seed it with
      // the same '8' default the exercise editors use for a brand-new Reps
      // set, instead of leaving the guided workout's target-reps label (and
      // the rep stepper's starting point) reading blank. Never touches an
      // already-set r, so a set that started life in Reps mode still gets
      // its original target restored untouched.
      for (final s in ex.sets) {
        if (s.r.isEmpty) s.r = '8';
      }
    }
    _persist();
    notifyListeners();
  }

  /// Chains/unchains [exercises][exIdx] with whichever exercise immediately
  /// follows it into a superset (see `data/superset_steps.dart`) -- a no-op
  /// on the list's last exercise, since there's nothing after it to link to.
  void toggleSuperset(List<Exercise> exercises, int exIdx) {
    if (exIdx >= exercises.length - 1) return;
    exercises[exIdx].supersetWithNext = !exercises[exIdx].supersetWithNext;
    _persist();
    notifyListeners();
  }

  void adjustWeight(
    List<Exercise> exercises,
    int exIdx,
    int setIdx,
    double delta,
  ) {
    final set = exercises[exIdx].sets[setIdx];
    var next = set.w + delta;
    if (next < 0) next = 0;
    next = (next * 2).round() / 2;
    set.w = next;
    _persist();
    notifyListeners();
  }

  void toggleSet(List<Exercise> exercises, int exIdx, int setIdx) {
    final ex = exercises[exIdx];
    if (!ex.done.contains(setIdx)) {
      ex.done.add(setIdx);
      _persist();
      notifyListeners();
    }
  }

  /// Clears every exercise's "done" marks for a fresh guided-workout
  /// session — [Exercise.done] is otherwise one-way (never un-marked once
  /// set), which is fine for a single pass through a plan but would leave
  /// every set showing as already-done on the *next* time a repeating
  /// weekday plan comes back around, without this being called first.
  void resetSessionProgress(List<Exercise> exercises) {
    for (final ex in exercises) {
      ex.done.clear();
    }
    _persist();
    notifyListeners();
  }

  void setActualReps(
      List<Exercise> exercises, int exIdx, int setIdx, int reps) {
    exercises[exIdx].sets[setIdx].actualReps = reps < 0 ? 0 : reps;
    _persist();
    notifyListeners();
  }

  /// The Timed/Cardio analogue of [setActualReps] -- logs the actual
  /// seconds held/elapsed for one set live during a guided workout.
  void setActualSeconds(
      List<Exercise> exercises, int exIdx, int setIdx, int seconds) {
    exercises[exIdx].sets[setIdx].actualDurationSec = seconds < 0 ? 0 : seconds;
    _persist();
    notifyListeners();
  }

  /// Steps a Cardio set's actual duration by [deltaSeconds], starting from
  /// whatever's already logged live or, failing that, the planned target --
  /// never from 0, so the first tap on an untouched set nudges away from
  /// its planned duration instead of starting a fresh countdown at 0. Same
  /// clamp-at-zero shape as [adjustWeight].
  void adjustCardioDuration(
      List<Exercise> exercises, int exIdx, int setIdx, int deltaSeconds) {
    final set = exercises[exIdx].sets[setIdx];
    final current = set.actualDurationSec ?? set.targetDurationSec ?? 0;
    var next = current + deltaSeconds;
    if (next < 0) next = 0;
    set.actualDurationSec = next;
    _persist();
    notifyListeners();
  }

  /// Steps a Cardio set's actual speed by [deltaKmh], same "start from
  /// actual-or-target, never 0" and clamp-at-zero shape as
  /// [adjustCardioDuration] -- rounded to the nearest 0.1 km/h step.
  void adjustCardioSpeed(
      List<Exercise> exercises, int exIdx, int setIdx, double deltaKmh) {
    final set = exercises[exIdx].sets[setIdx];
    final current = set.actualSpeedKmh ?? set.targetSpeedKmh ?? 0.0;
    var next = current + deltaKmh;
    if (next < 0) next = 0;
    next = (next * 10).round() / 10;
    set.actualSpeedKmh = next;
    _persist();
    notifyListeners();
  }

  /// Writes [value] into whichever of [ExerciseSet.rpe]/[ExerciseSet.rir]
  /// matches [scale], and clears the other -- the one place that must keep
  /// their mutual-exclusivity invariant true (see the doc comment on
  /// [ExerciseSet.rpe]), so a set re-logged after the global effort-scale
  /// setting changes never carries a stale value in the scale it's no
  /// longer tagged with. A null [value] (no chip picked) clears both,
  /// matching the old `setRpe(..., null)` behavior.
  void setEffort(List<Exercise> exercises, int exIdx, int setIdx,
      EffortScale scale, int? value) {
    final set = exercises[exIdx].sets[setIdx];
    set.rpe = scale == EffortScale.rpe ? value : null;
    set.rir = scale == EffortScale.rir ? value : null;
    _persist();
    notifyListeners();
  }

  /// Appends one [HistoryEntry] summarizing an exercise's just-finished
  /// guided-workout performance -- weight is the highest logged set weight
  /// (not a single overwrite like [saveExerciseLog], since a guided
  /// session's per-set weights are already live-adjusted, correct values,
  /// e.g. an intentional pyramid/dropset). This is what lets the guided
  /// workout feed the same PR/trend machinery ([Exercise.history]) that
  /// previously only [ExerciseDetailScreen]'s manual flow ever wrote to.
  void appendGuidedHistoryEntry(List<Exercise> exercises, int exIdx) {
    final ex = exercises[exIdx];
    switch (ex.logMode) {
      case ExerciseLogMode.reps:
        var maxWeight = 0.0;
        for (final s in ex.sets) {
          if (s.w > maxWeight) maxWeight = s.w;
        }
        final reps = [for (final s in ex.sets) s.actualReps ?? 0];
        ex.history.add(
            HistoryEntry(weight: maxWeight, reps: reps, date: todayIso()));
      case ExerciseLogMode.timed:
        // w keeps its existing meaning (optional added weight, 0 = pure
        // bodyweight) even in Timed mode -- same max-scan as Reps mode.
        var maxWeight = 0.0;
        for (final s in ex.sets) {
          if (s.w > maxWeight) maxWeight = s.w;
        }
        final durations = [for (final s in ex.sets) s.actualDurationSec ?? 0];
        ex.history.add(HistoryEntry(
          weight: maxWeight,
          reps: const [],
          date: todayIso(),
          mode: ExerciseLogMode.timed,
          durations: durations,
        ));
      case ExerciseLogMode.cardio:
        final durations = [for (final s in ex.sets) s.actualDurationSec ?? 0];
        final speeds = [for (final s in ex.sets) s.actualSpeedKmh ?? 0.0];
        ex.history.add(HistoryEntry(
          weight: 0,
          reps: const [],
          date: todayIso(),
          mode: ExerciseLogMode.cardio,
          durations: durations,
          speeds: speeds,
        ));
    }
    _persist();
    notifyListeners();
  }

  /// Pushes a new history entry AND overwrites every current set's weight
  /// to [weight] — always overwrites, unlike [importExerciseHistory] below.
  void saveExerciseLog(
    List<Exercise> exercises,
    int exIdx,
    double weight,
    List<Object> reps,
  ) {
    final ex = exercises[exIdx];
    ex.history.add(HistoryEntry(weight: weight, reps: reps, date: todayIso()));
    for (final s in ex.sets) {
      s.w = weight;
    }
    _persist();
    notifyListeners();
  }

  /// The Timed-mode analogue of [saveExerciseLog] -- [saveExerciseLog]'s
  /// `(idx, weight, reps)` contract is Reps-shaped and must not be reused
  /// here. Always overwrites every current set's added weight and actual
  /// seconds held (by position; a [durationsSec] shorter than the set list
  /// leaves the extra sets' actual seconds unchanged), then appends a
  /// matching [HistoryEntry].
  void saveTimedExerciseLog(
    List<Exercise> exercises,
    int exIdx,
    double addedWeightKg,
    List<int> durationsSec,
  ) {
    final ex = exercises[exIdx];
    ex.history.add(HistoryEntry(
      weight: addedWeightKg,
      reps: const [],
      date: todayIso(),
      mode: ExerciseLogMode.timed,
      durations: durationsSec,
    ));
    for (var i = 0; i < ex.sets.length; i++) {
      ex.sets[i].w = addedWeightKg;
      if (i < durationsSec.length) {
        ex.sets[i].actualDurationSec = durationsSec[i];
      }
    }
    _persist();
    notifyListeners();
  }

  /// The Cardio-mode analogue of [saveExerciseLog] -- weight always stays 0
  /// (unused in Cardio mode). Always overwrites every current set's actual
  /// duration+speed (by position, same shorter-list rule as
  /// [saveTimedExerciseLog]), then appends a matching [HistoryEntry].
  void saveCardioExerciseLog(
    List<Exercise> exercises,
    int exIdx,
    List<int> durationsSec,
    List<double> speedsKmh,
  ) {
    final ex = exercises[exIdx];
    ex.history.add(HistoryEntry(
      weight: 0,
      reps: const [],
      date: todayIso(),
      mode: ExerciseLogMode.cardio,
      durations: durationsSec,
      speeds: speedsKmh,
    ));
    for (var i = 0; i < ex.sets.length; i++) {
      ex.sets[i].w = 0;
      if (i < durationsSec.length) {
        ex.sets[i].actualDurationSec = durationsSec[i];
      }
      if (i < speedsKmh.length) {
        ex.sets[i].actualSpeedKmh = speedsKmh[i];
      }
    }
    _persist();
    notifyListeners();
  }

  void renameExercise(List<Exercise> exercises, int exIdx, String newName) {
    exercises[exIdx].name = newName;
    _persist();
    notifyListeners();
  }

  /// Appends pasted history and always overwrites the current set weights
  /// with the newly imported (last-entered) weight -- matching
  /// [saveExerciseLog], never conditionally keeping an older, heavier
  /// weight around just because it was higher.
  void importExerciseHistory(
    List<Exercise> exercises,
    int exIdx,
    double weight,
    List<HistoryEntry> history,
  ) {
    final ex = exercises[exIdx];
    ex.history.addAll(history);
    for (final s in ex.sets) {
      s.w = weight;
    }
    _persist();
    notifyListeners();
  }

  void finishWorkout(Program program) {
    program.completed += 1;
    _persist();
    notifyListeners();
  }
}
