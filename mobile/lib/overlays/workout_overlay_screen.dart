import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/achievements_engine.dart';
import '../analytics/analytics_engine.dart';
import '../data/constants.dart';
import '../data/lift_categories.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../services/notification_service.dart';
import '../state/big_lifts_provider.dart';
import '../state/health_provider.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../state/workout_history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
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
  }
}

/// Guided, sequential set-by-set workout session, ported from
/// `WorkoutOverlay.svelte` and since extended with a live session clock,
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
  int _exIdx = 0;
  int _setIdx = 0;
  DateTime? _restEndsAt;
  int _restTotal = 0;
  int? _rpe;
  Timer? _ticker;
  final DateTime _startedAt = DateTime.now();
  double _sessionVolumeKg = 0;
  int _sessionSets = 0;

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
    // A repeating weekday plan comes back around every week -- without
    // this, every set from last time would still show as "done" the
    // moment this screen opens, since Exercise.done is otherwise one-way.
    _programs.resetSessionProgress(raw);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
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
      _advance(_ordered(_rawExercises()));
      return;
    }
    setState(
        () {}); // just re-render the live clock / rest ring off DateTime.now()
  }

  int _totalSets(List<Exercise> exercises) {
    var total = 0;
    for (final e in exercises) {
      total += e.sets.length;
    }
    return total < 1 ? 1 : total;
  }

  int _doneBefore(List<Exercise> exercises) {
    var done = 0;
    for (var i = 0; i < _exIdx; i++) {
      done += exercises[i].sets.length;
    }
    return done + _setIdx;
  }

  void _step(List<Exercise> exercises, double delta) {
    _programs.adjustWeight(exercises, _exIdx, _setIdx, delta);
  }

  void _stepReps(List<Exercise> exercises, int current, int delta) {
    final next = current + delta;
    _programs.setActualReps(exercises, _exIdx, _setIdx, next < 0 ? 0 : next);
  }

  void _completeSet(List<Exercise> exercises, int reps) {
    final t = AppLocalizations.of(context)!;
    _programs.setActualReps(exercises, _exIdx, _setIdx, reps);
    _programs.setRpe(exercises, _exIdx, _setIdx, _rpe);
    _programs.toggleSet(exercises, _exIdx, _setIdx);

    final ex = exercises[_exIdx];
    _sessionVolumeKg += ex.sets[_setIdx].w * reps;
    _sessionSets += 1;

    final currentSets = ex.sets.length;
    final isLastSetOfExercise = _setIdx >= currentSets - 1;
    final isLastExercise = _exIdx >= exercises.length - 1;

    // Feeds the guided workout's actual performance into the same
    // Exercise.history the manual "save exercise log" flow already writes
    // to -- previously only that manual flow ever populated it, so no
    // exercise outside bench/deadlift/squat could ever show a PR from a
    // guided session. Comparing the estimated 1RM before/after appending
    // is what actually detects "is this a new best."
    String? prMessage;
    if (isLastSetOfExercise) {
      final previousBest = bestEstimatedOneRepMax(ex);
      _programs.appendGuidedHistoryEntry(exercises, _exIdx);
      final newBest = bestEstimatedOneRepMax(ex);
      if (newBest != null && (previousBest == null || newBest > previousBest)) {
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

    if (isLastSetOfExercise && isLastExercise) {
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

    final restSeconds = exercises[_exIdx].rest;
    setState(() {
      _restTotal = restSeconds;
      _restEndsAt = DateTime.now().add(Duration(seconds: restSeconds));
      _rpe = null;
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

  void _advance(List<Exercise> exercises) {
    final currentSets = exercises[_exIdx].sets.length;
    setState(() {
      _restEndsAt = null;
      _rpe = null;
      if (_setIdx < currentSets - 1) {
        _setIdx += 1;
      } else {
        _exIdx += 1;
        _setIdx = 0;
      }
    });
    // Covers both "rest actually elapsed" (harmless no-op cancel, it
    // already fired) and "skipped/advanced early" (the whole reason this
    // matters -- without it, a stale notification for a rest period
    // that's already over would fire later on whatever exercise the user
    // has since moved on to).
    unawaited(context.read<NotificationService>().cancelRestOver());
  }

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
      setState(() => _order.replaceRange(_exIdx + 1, _order.length, reordered));
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
            : _buildMainView(exercises, colors, t),
      ),
    );
  }

  Widget _buildMainView(
      List<Exercise> exercises, AppColors colors, AppLocalizations t) {
    final ex = exercises[_exIdx];
    final sets = ex.sets;
    final weight = sets[_setIdx].w;
    final targetReps = sets[_setIdx].r;
    final actualReps = sets[_setIdx].actualReps ?? _lowRepBound(targetReps);
    final isLast = _exIdx == exercises.length - 1 && _setIdx == sets.length - 1;
    final progress = _doneBefore(exercises) / _totalSets(exercises);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop()),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 26,
                onPressed: () => _stepReps(exercises, actualReps, -1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text('$actualReps',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text(t.hintRepsPerformed,
                        style: TextStyle(color: colors.mut, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 26,
                onPressed: () => _stepReps(exercises, actualReps, 1),
              ),
            ],
          ),
          Center(
            child: Text(t.targetReps(targetReps),
                style: TextStyle(color: colors.mut)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < sets.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        ex.done.contains(i) ? colors.green : Colors.transparent,
                    border: Border.all(
                        color: i == _setIdx ? colors.accent : colors.line),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(t.headerRpe,
              style: TextStyle(color: colors.mut), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              for (var v = 5; v <= 10; v++)
                ChoiceChip(
                  label: Text('$v'),
                  selected: _rpe == v,
                  onSelected: (_) => setState(() => _rpe = v),
                ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => _completeSet(exercises, actualReps),
            child: Text(isLast ? t.actionFinishWorkout : t.actionCompleteSet),
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
            onPressed: () => _advance(_ordered(_rawExercises())),
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

  String _setsSubtitle(Exercise ex) =>
      ex.sets.isEmpty ? '' : '${ex.sets.length} × ${ex.sets.first.r}';

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
                        subtitle: Text(_setsSubtitle(widget.exerciseAt(i)),
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
                    subtitle: Text(_setsSubtitle(current),
                        style: TextStyle(color: colors.mut, fontSize: 12)),
                  ),
                  if (_local.isNotEmpty) ...[
                    _sectionHeader(t.labelUpcomingExercises, colors),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                                _setsSubtitle(widget.exerciseAt(_local[i])),
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
