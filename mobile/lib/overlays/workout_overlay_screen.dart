import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../analytics/achievements_engine.dart';
import '../analytics/analytics_engine.dart';
import '../data/constants.dart';
import '../data/duration_format.dart';
import '../data/effort_scale.dart';
import '../data/lift_categories.dart';
import '../data/rep_side_split.dart';
import '../data/superset_steps.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/exercise_set.dart';
import '../services/notification_service.dart';
import '../state/big_lifts_provider.dart';
import '../state/effort_scale_provider.dart';
import '../state/health_provider.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../state/workout_history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/exercise_list_view.dart' show categoryLabel;
import '../widgets/rest_ring.dart';

String _formatElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Lowest number in a target-reps string like "8" or "8-10" -- used as a
/// conservative starting point for the actual-reps stepper (better to
/// nudge up from a number the user definitely hit than default to the top
/// of the range and imply they always hit it without logging anything).
int _lowRepBound(String r) {
  final numbers =
      RegExp(r'\d+').allMatches(r).map((m) => int.parse(m.group(0)!)).toList();
  if (numbers.isEmpty) return 0;
  return numbers.reduce((a, b) => a < b ? a : b);
}

/// Short label for a just-unlocked achievement path's toast -- mirrors
/// `progress_screen.dart`'s `_AchievementsTab._pathLabel` (kept separate
/// rather than shared, since `achievements_engine.dart` itself stays
/// l10n-free, matching `analytics_engine.dart`'s existing convention).
String _pathLabel(AppLocalizations t, AchievementPathId id) {
  switch (id) {
    case AchievementPathId.consistency:
      return t.achievementPathConsistency;
    case AchievementPathId.totalWorkouts:
      return t.achievementPathTotalWorkouts;
    case AchievementPathId.totalVolume:
      return t.achievementPathTotalVolume;
    case AchievementPathId.prCount:
      return t.achievementPathPrCount;
    case AchievementPathId.totalSets:
      return t.achievementPathTotalSets;
    case AchievementPathId.totalWorkoutMinutes:
      return t.achievementPathTotalWorkoutMinutes;
    case AchievementPathId.distinctExercises:
      return t.achievementPathDistinctExercises;
    // Never actually produced by computeAchievements (only by the separate
    // computeMuscleProgress, which newlyUnlockedTiers here is never fed) --
    // handled anyway because the switch is exhaustive over the whole enum.
    case AchievementPathId.chestVolume:
      return categoryLabel(t, 'chest');
    case AchievementPathId.backVolume:
      return categoryLabel(t, 'back');
    case AchievementPathId.shouldersVolume:
      return categoryLabel(t, 'shoulders');
    case AchievementPathId.legsVolume:
      return categoryLabel(t, 'legs');
    case AchievementPathId.armsVolume:
      return categoryLabel(t, 'arms');
    case AchievementPathId.coreVolume:
      return categoryLabel(t, 'core');
  }
}

/// Guided, sequential set-by-set workout session, with a live session clock,
/// a wall-clock rest timer, actual weight+rep tracking, PR detection, and
/// a full session overview (completed/current/upcoming, with reordering).
///
/// Weight/rep adjustments persist immediately via [ProgramsProvider] even
/// if the screen is force-closed mid-rest — the [_ticker] is cancelled in
/// [dispose], which `Navigator.pop` reliably triggers.
///
/// Both the elapsed-session clock and the rest countdown are computed from
/// wall-clock [DateTime] timestamps rather than a decrementing tick
/// counter, and re-synced on [AppLifecycleState.resumed] -- a plain
/// `Timer.periodic` only fires while the app is actually running, so
/// counting down "one tick per callback" would silently freeze (or worse,
/// undercount) the whole time the phone was locked or the app was
/// backgrounded mid-rest, which is exactly when people actually background
/// this screen. Recomputing from timestamps on every tick and on resume
/// means the displayed numbers are always correct regardless of how long
/// the app was away.
class WorkoutOverlayScreen extends StatefulWidget {
  const WorkoutOverlayScreen(
      {super.key, required this.programId, required this.dayIdx});

  final String programId;
  final int dayIdx;

  @override
  State<WorkoutOverlayScreen> createState() => _WorkoutOverlayScreenState();
}

class _WorkoutOverlayScreenState extends State<WorkoutOverlayScreen>
    with WidgetsBindingObserver {
  /// The literal walk order of sets for this session -- see
  /// `data/superset_steps.dart`. Rebuilt whenever [_order] changes (session
  /// reorder); for a plan with no superset pairs this is just one step per
  /// set in [_exIdx]/[_setIdx] order, exactly how this screen always walked
  /// before supersets existed.
  late List<WorkoutStep> _steps;
  int _stepIdx = 0;
  int get _exIdx => _steps[_stepIdx].exerciseIndex;
  int get _setIdx => _steps[_stepIdx].setIndex;
  DateTime? _restEndsAt;
  int _restTotal = 0;
  int? _effort;
  Timer? _ticker;
  final DateTime _startedAt = DateTime.now();
  double _sessionVolumeKg = 0;
  int _sessionSets = 0;

  /// Non-null while a Timed set's work timer is running -- wall-clock
  /// based, same pattern as [_restEndsAt]. Mutually exclusive with
  /// [_resting]: starting a hold only happens from the main view (never
  /// while resting), and [_completeTimedSet] clears this before a rest
  /// period (if any) can start.
  DateTime? _workStartedAt;

  bool get _working => _workStartedAt != null;

  /// Session-local exercise order (indices into the plan day's exercise
  /// list) -- reordering here only changes what order *this* workout walks
  /// through, it never touches the saved plan template.
  late List<int> _order;

  bool get _resting => _restEndsAt != null;

  ProgramsProvider get _programs => context.read<ProgramsProvider>();

  List<Exercise> _rawExercises() {
    final plan = _programs.byId(widget.programId)!;
    return plan.days[widget.dayIdx].exercises;
  }

  List<Exercise> _ordered(List<Exercise> raw) =>
      [for (final i in _order) raw[i]];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final raw = _rawExercises();
    _order = List.generate(raw.length, (i) => i);
    _steps = buildWorkoutSteps(_ordered(raw));
    // A repeating weekday plan comes back around every week -- without
    // this, every set from last time would still show as "done" the
    // moment this screen opens, since Exercise.done is otherwise one-way.
    _programs.resetSessionProgress(raw);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    // A locked screen mid-set is the single most common real-gym annoyance
    // this screen can actually fix -- barbell in hand, phone auto-locks,
    // now unlocking one-handed just to log a rep count. Scoped to exactly
    // this screen's lifetime (enabled here, disabled in dispose), not
    // requested app-wide.
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(WakelockPlus.disable());
    // Force-closing mid-rest (back gesture, session-overview navigation
    // away, ...) shouldn't leave a "rest over" ping scheduled for a
    // workout the user already left.
    if (_resting) unawaited(context.read<NotificationService>().cancelRestOver());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onTick();
  }

  void _onTick() {
    if (!mounted) return;
    final restEndsAt = _restEndsAt;
    if (restEndsAt != null && !DateTime.now().isBefore(restEndsAt)) {
      _advance();
      return;
    }
    setState(
        () {}); // just re-render the live clock / rest ring off DateTime.now()
  }

  int _totalSets(List<Exercise> exercises) => _steps.isEmpty ? 1 : _steps.length;

  int _doneBefore(List<Exercise> exercises) => _stepIdx;

  void _step(List<Exercise> exercises, double delta) {
    _programs.adjustWeight(exercises, _exIdx, _setIdx, delta);
  }

  void _stepReps(List<Exercise> exercises, int current, int delta) {
    final next = current + delta;
    _programs.setActualReps(exercises, _exIdx, _setIdx, next < 0 ? 0 : next);
  }

  void _completeSet(List<Exercise> exercises, int reps) {
    final scale = context.read<EffortScaleProvider>().scale;
    // Guards against a rare mid-session scale change (background/foreground
    // through Settings): if _effort was tapped under the old scale and no
    // longer falls within the new scale's range, it must not land in the
    // new scale's field as a raw, mismatched number -- that would be
    // exactly the "wrong number in the wrong field" this feature's model
    // design is built to avoid (see ProgramsProvider.setEffort).
    final effort = (_effort != null && effortValuesFor(scale).contains(_effort))
        ? _effort
        : null;
    _programs.setActualReps(exercises, _exIdx, _setIdx, reps);
    _programs.setEffort(exercises, _exIdx, _setIdx, scale, effort);

    final ex = exercises[_exIdx];
    // Only a Reps set contributes real lifted-and-repped kg-volume -- same
    // rule `achievements_engine.dart`'s `_historyVolumeKg` already follows
    // for all-time volume.
    _sessionVolumeKg += ex.sets[_setIdx].w * reps;

    _finishSet(exercises);
  }

  /// Stops the running work timer, logs the elapsed hold, and funnels into
  /// the shared [_finishSet] tail -- the Timed analogue of [_completeSet].
  void _completeTimedSet(List<Exercise> exercises) {
    final elapsedSeconds =
        DateTime.now().difference(_workStartedAt!).inSeconds;
    _programs.setActualSeconds(exercises, _exIdx, _setIdx, elapsedSeconds);
    // Clear the work timer BEFORE _finishSet can start a rest period --
    // _working and _resting must never both be true.
    setState(() => _workStartedAt = null);
    _finishSet(exercises);
  }

  /// Writes back whatever duration/speed is currently displayed for this
  /// set (already-live-adjusted via the duration/speed steppers, or --
  /// untouched -- the set's own planned target, the same "write the
  /// displayed default" rule [_completeSet] already follows for an
  /// untouched reps stepper) and funnels into [_finishSet] -- the Cardio
  /// analogue of [_completeSet]. No timer: Cardio sets are logged via
  /// steppers, not a start/stop hold.
  void _completeCardioSet(List<Exercise> exercises) {
    _programs.adjustCardioDuration(exercises, _exIdx, _setIdx, 0);
    _programs.adjustCardioSpeed(exercises, _exIdx, _setIdx, 0);
    _finishSet(exercises);
  }

  /// Starts a Timed set's work timer -- enters [_buildWorkView].
  void _startHold() {
    setState(() => _workStartedAt = DateTime.now());
  }

  /// Cancels a running hold without logging anything, back to the main
  /// view -- so a user who started a hold by mistake isn't stuck mid-hold.
  void _cancelHold() {
    setState(() => _workStartedAt = null);
  }

  /// The shared tail every set-completion path (`_completeSet`,
  /// `_completeTimedSet`, `_completeCardioSet`) funnels through once its
  /// own mode-specific value has already been written to the set: marks
  /// the set done, counts it toward this session's set total (every mode
  /// -- a plank/cardio-only session still counts toward the
  /// totalSets/streak achievements), appends a history entry on the
  /// exercise's last set, and either finishes the workout or advances/
  /// rests. This single shared tail is what keeps a superset mixing a Reps
  /// exercise with a Timed one interleaving correctly (see
  /// `data/superset_steps.dart` -- `buildWorkoutSteps` walks by literal set
  /// count and is mode-blind).
  void _finishSet(List<Exercise> exercises) {
    final t = AppLocalizations.of(context)!;
    _programs.toggleSet(exercises, _exIdx, _setIdx);

    final ex = exercises[_exIdx];
    _sessionSets += 1;

    final currentSets = ex.sets.length;
    final isLastSetOfExercise = _setIdx >= currentSets - 1;
    final isLastStep = _stepIdx >= _steps.length - 1;

    // Feeds the guided workout's actual performance into the same
    // Exercise.history the manual "save exercise log" flow already writes
    // to -- previously only that manual flow ever populated it, so no
    // exercise outside bench/deadlift/squat could ever show a PR from a
    // guided session. Comparing the estimated 1RM before/after appending
    // is what actually detects "is this a new best." Timed/Cardio never
    // reach this block -- their added/zero weight must never produce a
    // fake e1RM/PR toast or a BigLifts bump.
    String? prMessage;
    if (isLastSetOfExercise) {
      final previousBest =
          ex.logMode == ExerciseLogMode.reps ? bestEstimatedOneRepMax(ex) : null;
      _programs.appendGuidedHistoryEntry(exercises, _exIdx);
      if (ex.logMode == ExerciseLogMode.reps) {
        final newBest = bestEstimatedOneRepMax(ex);
        if (newBest != null &&
            (previousBest == null || newBest > previousBest)) {
          var maxWeight = 0.0;
          var repsAtMax = 0;
          for (final s in ex.sets) {
            if (s.w > maxWeight) {
              maxWeight = s.w;
              repsAtMax = s.actualReps ?? 0;
            }
          }
          prMessage = t.toastNewPr(ex.name, fmt1(maxWeight), repsAtMax);
          final liftCategory = liftCategoryForName(ex.name);
          if (liftCategory != null) {
            final bigLifts = context.read<BigLiftsProvider>();
            bigLifts.addEntry(liftCategory.key, maxWeight);
            bigLifts.bumpPrIfHigher(liftCategory.key, maxWeight, todayIso());
          }
        }
      }
    }

    if (isLastStep) {
      final plan = _programs.byId(widget.programId)!;
      _programs.finishWorkout(plan);
      final minutes = DateTime.now().difference(_startedAt).inMinutes;

      final history = context.read<WorkoutHistoryProvider>();
      final beforeAchievements = computeAchievements(
          sessions: history.sessions, programs: _programs.programs);
      history.logSession(
        date: todayIso(),
        durationMinutes: minutes < 1 ? 1 : minutes,
        planName: plan.name,
        totalVolumeKg: _sessionVolumeKg,
        totalSets: _sessionSets,
      );
      final afterAchievements = computeAchievements(
          sessions: history.sessions, programs: _programs.programs);
      final unlocked =
          newlyUnlockedTiers(beforeAchievements, afterAchievements);

      // Best-effort, never blocks finishing the workout — Health Connect/
      // HealthKit access can fail for reasons entirely outside the app's
      // control (not connected, permission revoked, ...).
      unawaited(context.read<HealthProvider>().writeWorkout(
            start: _startedAt,
            end: DateTime.now(),
            title: plan.name,
          ));

      // ToastProvider only shows one message at a time (a second call
      // silently drops the first) -- a PR, a newly-unlocked achievement,
      // and "workout finished" could all be true on the same last set, so
      // they're combined into one string rather than racing each other.
      final parts = [
        if (prMessage != null) prMessage,
        for (final id in unlocked.keys)
          t.toastAchievementUnlocked(_pathLabel(t, id)),
      ];
      context
          .read<ToastProvider>()
          .show(parts.isEmpty ? t.toastWorkoutFinished : parts.join(' • '));
      Navigator.of(context).pop();
      return;
    }

    if (prMessage != null) {
      context.read<ToastProvider>().show(prMessage);
    }

    // A superset's non-final step in its round (see superset_steps.dart) --
    // straight to the partner exercise's matching set, no rest in between.
    if (!_steps[_stepIdx].restAfter) {
      setState(() {
        _stepIdx += 1;
        _effort = null;
      });
      return;
    }

    final restSeconds = exercises[_exIdx].rest;
    setState(() {
      _restTotal = restSeconds;
      _restEndsAt = DateTime.now().add(Duration(seconds: restSeconds));
      _effort = null;
    });
    unawaited(_scheduleRestOverNotification(restSeconds));
  }

  /// The rest countdown itself is wall-clock-based and stays accurate
  /// backgrounded (see the class doc comment), but that's silent -- without
  /// a system notification, noticing rest ended while the phone's locked
  /// in a pocket means unlocking and checking. requestPermission() is
  /// idempotent (an already-granted or already-denied answer resolves
  /// immediately, no repeat prompt), so it's simplest to just ask fresh
  /// each time rather than track "have we asked" state of our own.
  Future<void> _scheduleRestOverNotification(int restSeconds) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context)!;
    final notifications = context.read<NotificationService>();
    await notifications.requestPermission();
    await notifications.scheduleRestOver(
      Duration(seconds: restSeconds),
      title: t.notificationRestOverTitle,
      body: t.notificationRestOverBody,
    );
  }

  /// A single mis-tap on the close button used to silently discard the
  /// entire session -- no undo, and while each already-completed set's
  /// weight/reps stick around (ProgramsProvider saves those incrementally),
  /// the session itself never reaches WorkoutHistoryProvider.logSession, so
  /// it wouldn't count toward this week's stats or the streak. Only worth
  /// asking about once there's actually something to lose -- exiting
  /// before the first set is still a silent, immediate pop.
  Future<void> _confirmExit(List<Exercise> exercises) async {
    if (_doneBefore(exercises) == 0) {
      Navigator.of(context).pop();
      return;
    }
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.titleExitWorkout),
        content: Text(t.bodyExitWorkoutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.actionCancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.actionExitWorkout, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop();
  }

  void _advance() {
    setState(() {
      _restEndsAt = null;
      _effort = null;
      _stepIdx += 1;
    });
    // Covers both "rest actually elapsed" (harmless no-op cancel, it
    // already fired) and "skipped/advanced early" (the whole reason this
    // matters -- without it, a stale notification for a rest period
    // that's already over would fire later on whatever exercise the user
    // has since moved on to).
    unawaited(context.read<NotificationService>().cancelRestOver());
  }

  // Position-based (everything before _exIdx's slot in _order is
  // "completed"), same as before supersets existed -- exactly right for a
  // plain sequential walk. Mid-superset, a partner exercise can show as
  // "completed" here a round or two before its own last set is actually
  // done (its later rounds are still ahead, interleaved with the exercise
  // that's genuinely current) -- a cosmetic quirk of this one secondary
  // view, not the actual set-by-set walk order (_steps), which is correct.
  Future<void> _openSessionOverview() async {
    final completed = _order.sublist(0, _exIdx);
    final current = _order[_exIdx];
    final upcoming = _order.sublist(_exIdx + 1);
    final reordered = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SessionOverviewSheet(
        completedIndices: completed,
        currentIndex: current,
        upcomingIndices: upcoming,
        exerciseAt: (i) => _rawExercises()[i],
      ),
    );
    if (reordered != null) {
      // The step the user is mid-set on right now, identified by (exercise,
      // set) rather than by position -- reordering only ever touches
      // exercises strictly after the current one, so that identity is
      // stable across the rebuild and lets this find its new position in
      // the freshly-built step list without having to reason about how
      // many superset rounds have already been walked.
      final currentStep = _steps[_stepIdx];
      setState(() {
        _order.replaceRange(_exIdx + 1, _order.length, reordered);
        _steps = buildWorkoutSteps(_ordered(_rawExercises()));
        _stepIdx = _steps.indexWhere(
          (s) => s.exerciseIndex == currentStep.exerciseIndex && s.setIndex == currentStep.setIndex,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ProgramsProvider>().byId(widget.programId)!;
    final exercises = _ordered(plan.days[widget.dayIdx].exercises);
    final colors = Theme.of(context).extension<AppColors>()!;

    if (_exIdx >= exercises.length) {
      // finish already pops before this can render; guard defensively.
      return const SizedBox.shrink();
    }

    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: _resting
            ? _buildRestView(colors, t)
            : _working
                ? _buildWorkView(exercises, colors, t)
                : _buildMainView(exercises, colors, t),
      ),
    );
  }

  Widget _buildMainView(
      List<Exercise> exercises, AppColors colors, AppLocalizations t) {
    final ex = exercises[_exIdx];
    final sets = ex.sets;
    final isLast = _stepIdx == _steps.length - 1;
    final progress = _doneBefore(exercises) / _totalSets(exercises);
    final inSuperset = ex.supersetWithNext || (_exIdx > 0 && exercises[_exIdx - 1].supersetWithNext);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: t.actionExitWorkout,
                  onPressed: () => _confirmExit(exercises)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1).toDouble(),
                    backgroundColor: colors.card2,
                    color: colors.accent,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: t.actionReorderExercises,
                onPressed: _openSessionOverview,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 14, color: colors.mut),
                const SizedBox(width: 4),
                Text(
                  _formatElapsed(DateTime.now().difference(_startedAt)),
                  style: TextStyle(
                    color: colors.mut,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (inSuperset)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded, size: 14, color: colors.accent),
                  const SizedBox(width: 4),
                  Text(
                    t.labelSuperset,
                    style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          Text(
            ex.name,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          Text(
            t.exerciseSetProgress(
                _exIdx + 1, exercises.length, _setIdx + 1, sets.length),
            style: TextStyle(color: colors.mut),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ..._buildModeControls(exercises, sets, colors, t),
          const SizedBox(height: 16),
          _buildSetDots(ex, sets, colors),
          const Spacer(),
          _buildBottomButton(exercises, sets, isLast, t),
        ],
      ),
    );
  }

  /// The set-progress dots row -- unchanged across every mode.
  Widget _buildSetDots(Exercise ex, List<ExerciseSet> sets, AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < sets.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ex.done.contains(i) ? colors.green : Colors.transparent,
              border:
                  Border.all(color: i == _setIdx ? colors.accent : colors.line),
            ),
          ),
      ],
    );
  }

  /// The mode-dependent middle section: Reps keeps the weight+reps
  /// steppers and effort chips unchanged; Timed keeps the weight stepper
  /// (now "added weight") but drops the reps stepper/effort chips in favor
  /// of a target-hold readout; Cardio drops both steppers for its own
  /// duration+speed steppers, no weight and no effort chips.
  List<Widget> _buildModeControls(List<Exercise> exercises,
      List<ExerciseSet> sets, AppColors colors, AppLocalizations t) {
    final ex = exercises[_exIdx];
    final set = sets[_setIdx];
    switch (ex.logMode) {
      case ExerciseLogMode.reps:
        final targetReps = set.r;
        final rawActualReps = set.actualReps ?? _lowRepBound(targetReps);
        // A unilateral exercise's displayed/stepped rep count is always
        // snapped to even first (see `data/rep_side_split.dart`) -- covers
        // a persisted odd value logged before the toggle existed, or an
        // odd target-range low bound -- so every step, and "Complete set"
        // below, always writes back an even total.
        final actualReps =
            ex.unilateral ? nextEvenReps(rawActualReps) : rawActualReps;
        final repStep = repStepFor(unilateral: ex.unilateral);
        final effortScale = context.watch<EffortScaleProvider>().scale;
        return [
          _weightStepperRow(exercises, set.w, t),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 26,
                onPressed: () => _stepReps(exercises, actualReps, -repStep),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text('$actualReps',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text(t.hintRepsPerformed,
                        style: TextStyle(color: colors.mut, fontSize: 11)),
                    if (ex.unilateral)
                      Text(t.labelRepsPerSide(fmt(repsPerSide(actualReps))),
                          style: TextStyle(color: colors.mut, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 26,
                onPressed: () => _stepReps(exercises, actualReps, repStep),
              ),
            ],
          ),
          Center(
            child: Text(t.targetReps(targetReps),
                style: TextStyle(color: colors.mut)),
          ),
          const SizedBox(height: 16),
          Text(
              effortScale == EffortScale.rir ? t.headerRir : t.headerRpe,
              style: TextStyle(color: colors.mut), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              for (final v in effortValuesFor(effortScale))
                ChoiceChip(
                  label: Text('$v'),
                  selected: _effort == v,
                  onSelected: (_) => setState(() => _effort = v),
                ),
            ],
          ),
        ];
      case ExerciseLogMode.timed:
        return [
          _weightStepperRow(exercises, set.w, t, label: t.hintAddedWeightKg),
          const SizedBox(height: 16),
          Center(
            child: Text(t.targetHoldSeconds(set.targetDurationSec ?? 30),
                style: TextStyle(color: colors.mut)),
          ),
        ];
      case ExerciseLogMode.cardio:
        final duration = set.actualDurationSec ?? set.targetDurationSec ?? 0;
        final speed = set.actualSpeedKmh ?? set.targetSpeedKmh ?? 0;
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 28,
                onPressed: () =>
                    _programs.adjustCardioDuration(exercises, _exIdx, _setIdx, -30),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(formatSeconds(duration),
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 28,
                onPressed: () =>
                    _programs.adjustCardioDuration(exercises, _exIdx, _setIdx, 30),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 26,
                onPressed: () =>
                    _programs.adjustCardioSpeed(exercises, _exIdx, _setIdx, -0.5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('${fmt1(speed)} ${t.unitKmh}',
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 26,
                onPressed: () =>
                    _programs.adjustCardioSpeed(exercises, _exIdx, _setIdx, 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
                t.targetCardioPace(((set.targetDurationSec ?? 0) / 60).round(),
                    fmt1(set.targetSpeedKmh ?? 0)),
                style: TextStyle(color: colors.mut)),
          ),
        ];
    }
  }

  Widget _weightStepperRow(
      List<Exercise> exercises, double weight, AppLocalizations t,
      {String? label}) {
    return Column(
      children: [
        if (label != null)
          Text(label, style: TextStyle(color: Theme.of(context).extension<AppColors>()!.mut, fontSize: 11.5)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 32,
              onPressed: () => _step(exercises, -2.5),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                weight > 0 ? '${fmt1(weight)} kg' : t.labelBodyweightAbbr,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 32,
              onPressed: () => _step(exercises, 2.5),
            ),
          ],
        ),
      ],
    );
  }

  /// Reps/Cardio complete this set directly; Timed instead starts the work
  /// timer (see [_buildWorkView]) -- only its Stop button actually logs the
  /// set and advances.
  Widget _buildBottomButton(List<Exercise> exercises, List<ExerciseSet> sets,
      bool isLast, AppLocalizations t) {
    final ex = exercises[_exIdx];
    switch (ex.logMode) {
      case ExerciseLogMode.reps:
        final targetReps = sets[_setIdx].r;
        final rawActualReps =
            sets[_setIdx].actualReps ?? _lowRepBound(targetReps);
        final actualReps =
            ex.unilateral ? nextEvenReps(rawActualReps) : rawActualReps;
        return ElevatedButton(
          onPressed: () => _completeSet(exercises, actualReps),
          child: Text(isLast ? t.actionFinishWorkout : t.actionCompleteSet),
        );
      case ExerciseLogMode.timed:
        return ElevatedButton(
          onPressed: _startHold,
          child: Text(t.actionStartHold),
        );
      case ExerciseLogMode.cardio:
        return ElevatedButton(
          onPressed: () => _completeCardioSet(exercises),
          child: Text(isLast ? t.actionFinishWorkout : t.actionCompleteSet),
        );
    }
  }

  /// The Timed work timer -- reuses [RestRing] (progress = elapsed/target,
  /// clamped) with a Stop button that reads elapsed seconds and calls
  /// [_completeTimedSet]. Wall-clock based (elapsed = now - _workStartedAt,
  /// re-derived every tick via [_onTick]'s unconditional `setState`), same
  /// pattern the class doc mandates for the rest timer, so it survives the
  /// app being backgrounded mid-hold.
  Widget _buildWorkView(
      List<Exercise> exercises, AppColors colors, AppLocalizations t) {
    final ex = exercises[_exIdx];
    final target = ex.sets[_setIdx].targetDurationSec ?? 30;
    final elapsed = DateTime.now().difference(_workStartedAt!).inSeconds;
    final progress = target == 0 ? 0.0 : elapsed / target;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(ex.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          RestRing(
            progress: progress.clamp(0, 1),
            trackColor: colors.card2,
            progressColor: colors.accent,
            child: Text(formatSeconds(elapsed),
                style: Theme.of(context).textTheme.headlineLarge),
          ),
          const SizedBox(height: 16),
          Text(t.targetHoldSeconds(target), style: TextStyle(color: colors.mut)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _completeTimedSet(exercises),
            child: Text(t.actionStopAndLog),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cancelHold,
            child: Text(t.actionCancel),
          ),
        ],
      ),
    );
  }

  Widget _buildRestView(AppColors colors, AppLocalizations t) {
    final restEndsAt = _restEndsAt!;
    final restLeft =
        restEndsAt.difference(DateTime.now()).inSeconds.clamp(0, _restTotal);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RestRing(
            progress: _restTotal == 0 ? 0 : restLeft / _restTotal,
            trackColor: colors.card2,
            progressColor: colors.accent,
            child: Text('$restLeft',
                style: Theme.of(context).textTheme.headlineLarge),
          ),
          const SizedBox(height: 16),
          Text(t.secondsPause, style: TextStyle(color: colors.mut)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _advance,
            child: Text(t.actionSkipRest),
          ),
        ],
      ),
    );
  }
}

/// Full session overview: completed exercises (read-only, checkmarked),
/// the current one (read-only, highlighted), and everything still ahead
/// (drag-to-reorder, or tap a row to jump it to the front). Purely
/// session-local — the caller applies the result to `_order`, never to
/// the saved plan.
class _SessionOverviewSheet extends StatefulWidget {
  const _SessionOverviewSheet({
    required this.completedIndices,
    required this.currentIndex,
    required this.upcomingIndices,
    required this.exerciseAt,
  });

  final List<int> completedIndices;
  final int currentIndex;
  final List<int> upcomingIndices;
  final Exercise Function(int planIndex) exerciseAt;

  @override
  State<_SessionOverviewSheet> createState() => _SessionOverviewSheetState();
}

class _SessionOverviewSheetState extends State<_SessionOverviewSheet> {
  late final List<int> _local;

  @override
  void initState() {
    super.initState();
    _local = List.of(widget.upcomingIndices);
  }

  void _jumpTo(int planIdx) {
    setState(() {
      _local.remove(planIdx);
      _local.insert(0, planIdx);
    });
    Navigator.of(context).pop(_local);
  }

  String _setsSubtitle(AppLocalizations t, Exercise ex) =>
      exerciseSetsSummaryLabel(t, ex);

  Widget _sectionHeader(String label, AppColors colors) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 4),
        child: Text(
          label,
          style: TextStyle(
              color: colors.mut, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final current = widget.exerciseAt(widget.currentIndex);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.titleReorderExercises,
                            style: Theme.of(context).textTheme.headlineMedium),
                        Text(t.hintReorderExercises,
                            style:
                                TextStyle(color: colors.mut, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_local),
                    child: Text(t.actionSave),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  if (widget.completedIndices.isNotEmpty) ...[
                    _sectionHeader(t.labelCompletedExercises, colors),
                    for (final i in widget.completedIndices)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.check_circle,
                            color: colors.green, size: 20),
                        title: Text(widget.exerciseAt(i).name),
                        subtitle: Text(_setsSubtitle(t, widget.exerciseAt(i)),
                            style: TextStyle(color: colors.mut, fontSize: 12)),
                      ),
                  ],
                  _sectionHeader(t.labelCurrentExerciseInSession, colors),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.play_circle_fill,
                        color: colors.accent, size: 20),
                    title: Text(current.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: colors.accent)),
                    subtitle: Text(_setsSubtitle(t, current),
                        style: TextStyle(color: colors.mut, fontSize: 12)),
                  ),
                  if (_local.isNotEmpty) ...[
                    _sectionHeader(t.labelUpcomingExercises, colors),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // onReorder reports newIndex as if the dragged item
                      // hadn't been removed from oldIndex yet -- moving it
                      // down the list needs the standard -1 correction so
                      // it lands where the user actually dropped it.
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _local.removeAt(oldIndex);
                          _local.insert(newIndex, item);
                        });
                      },
                      children: [
                        for (var i = 0; i < _local.length; i++)
                          ListTile(
                            key: ValueKey(_local[i]),
                            contentPadding: EdgeInsets.zero,
                            leading: Text('${i + 1}',
                                style: TextStyle(color: colors.mut)),
                            title: Text(widget.exerciseAt(_local[i]).name),
                            subtitle: Text(
                                _setsSubtitle(t, widget.exerciseAt(_local[i])),
                                style:
                                    TextStyle(color: colors.mut, fontSize: 12)),
                            trailing: const Icon(Icons.drag_handle),
                            onTap: () => _jumpTo(_local[i]),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
