import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics_engine.dart';
import '../analytics/heatmap_engine.dart';
import '../analytics/logged_days.dart';
import '../analytics/rest_days.dart';
import '../data/constants.dart';
import '../data/example_log.dart';
import '../data/example_ppl_plan.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/exercise_log_mode.dart';
import '../models/program.dart';
import '../overlays/exercise_detail_screen.dart';
import '../overlays/import_log_screen.dart';
import '../overlays/plan_editor_screen.dart';
import '../overlays/settings_screen.dart';
import '../overlays/workout_overlay_screen.dart';
import '../state/creatine_provider.dart';
import '../state/home_layout_provider.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../state/train_state_provider.dart';
import '../state/update_provider.dart';
import '../state/workout_history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/add_exercise_sheet.dart';
import '../widgets/app_shell.dart';
import '../widgets/backup_sheet.dart';
import '../widgets/contribution_heatmap.dart';
import '../widgets/day_pill_selector.dart';
import '../widgets/exercise_card.dart';
import '../widgets/language_picker_sheet.dart';
import '../widgets/move_day_sheet.dart';
import '../widgets/move_exercise_sheet.dart';
import '../widgets/plan_picker_sheet.dart';
import '../widgets/streak_flame.dart';
import '../state/theme_provider.dart';
import 'calendar_screen.dart';
import 'gallery_screen.dart';

/// Rough estimate only (no per-exercise timing data exists) — roughly 3
/// minutes per set including rest, matching the guided workout's typical
/// pace, EXCEPT a Timed/Cardio exercise's sets, which instead each add
/// their own planned `targetDurationSec` -- a flat 3-min/set constant would
/// badly under-report a plan containing e.g. a 20-minute cardio bout. Shown
/// with a "~" prefix so it never reads as a precise number.
int _estimateWorkoutMinutes(List<Exercise> exercises) {
  var minutes = 0.0;
  for (final e in exercises) {
    if (e.logMode == ExerciseLogMode.reps) {
      minutes += e.sets.length * 3;
    } else {
      for (final s in e.sets) {
        minutes += (s.targetDurationSec ?? 30) / 60;
      }
    }
  }
  return minutes.round();
}

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  @override
  void initState() {
    super.initState();
    // Runs once (this screen stays mounted for the app's lifetime inside
    // the shell's PageView).
    WidgetsBinding.instance.addPostFrameCallback((_) => _openActivePlanOnToday());
  }

  /// No plan picker on launch: the plan the user picked stays their fixed
  /// plan (TrainStateProvider persists it; switching lives in the overflow
  /// menu). Launching only re-opens it on today's day, which the old
  /// launch prompt used to do as a side effect of re-selecting the plan.
  void _openActivePlanOnToday() {
    if (!mounted) return;
    final programs = context.read<ProgramsProvider>();
    if (programs.programs.isEmpty) return;
    final activeId = context.read<TrainStateProvider>().activePlanId;
    _selectPlan(programs.byId(activeId) ?? programs.programs.first);
  }

  void _selectPlan(Program p) {
    final idx =
        todayIndexForProgram(mode: p.mode, currentDayIdx: p.currentDayIdx);
    context.read<TrainStateProvider>().selectPlan(p.id, viewedDayIdx: idx);
  }

  void _newPlan() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PlanEditorScreen(),
    ));
  }

  /// Straight from tap to a saved, ready-to-train [Program] -- unlike
  /// "Beispielplan laden", this skips [ImportLogScreen]/the hand-typed-log
  /// parser entirely, since [buildExamplePplProgram] already produces a
  /// valid structured plan (mirrors how [PlanEditorScreen._save] ends).
  void _loadPplExample() {
    final t = AppLocalizations.of(context)!;
    final program = buildExamplePplProgram(name: t.examplePplPlanName);
    context.read<ProgramsProvider>().addProgram(program);
    _selectPlan(program);
    context.read<ToastProvider>().show(t.toastPplPlanLoaded);
  }

  void _deletePlan(Program p) {
    final t = AppLocalizations.of(context)!;
    final programs = context.read<ProgramsProvider>();
    final trainState = context.read<TrainStateProvider>();
    final wasActive = trainState.activePlanId == p.id;
    programs.removeProgram(p.id);
    trainState.dropOverridesForPlan(p.id);
    context.read<ToastProvider>().show(t.toastPlanDeleted);
    if (!wasActive) return;
    final remaining = programs.programs;
    if (remaining.isEmpty) {
      trainState.clear();
    } else {
      _selectPlan(remaining.first);
    }
  }

  void _openExerciseDetail(String programId, int? dayIdx, int startIdx) {
    final programs = context.read<ProgramsProvider>();
    final plan = programs.byId(programId)!;
    final exercises =
        dayIdx == null ? plan.dailyExercises : plan.days[dayIdx].exercises;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ExerciseDetailScreen(
        exercises: exercises,
        startIdx: startIdx,
        onSave: (idx, weight, reps) =>
            programs.saveExerciseLog(exercises, idx, weight, reps),
        onRename: (idx, name) => programs.renameExercise(exercises, idx, name),
        onImportHistory: (idx, weight, history) =>
            programs.importExerciseHistory(exercises, idx, weight, history),
        onMuscleChanged: (idx, muscle) =>
            programs.setMuscle(exercises, idx, muscle),
        onNoteChanged: (idx, note) => programs.setNote(exercises, idx, note),
        onUnilateralChanged: (idx, unilateral) =>
            programs.setUnilateral(exercises, idx, unilateral),
        onLogModeChanged: (idx, mode) =>
            programs.setLogMode(exercises, idx, mode),
        onSaveTimed: (idx, addedWeightKg, durationsSec) => programs
            .saveTimedExerciseLog(exercises, idx, addedWeightKg, durationsSec),
        onSaveCardio: (idx, durationsSec, speedsKmh) => programs
            .saveCardioExerciseLog(exercises, idx, durationsSec, speedsKmh),
      ),
    ));
  }

  /// Adds a new exercise to an already-saved plan -- either a specific
  /// day's list ([dayIdx] set) or the "every training day" list
  /// ([dayIdx] null), same list-resolution as [_openExerciseDetail].
  Future<void> _addExercise(String programId, int? dayIdx) async {
    final programs = context.read<ProgramsProvider>();
    final plan = programs.byId(programId)!;
    final exercises =
        dayIdx == null ? plan.dailyExercises : plan.days[dayIdx].exercises;
    final exercise = await showAddExerciseSheet(context);
    if (exercise != null) programs.addExercise(exercises, exercise);
  }

  /// Removes one exercise from an already-saved plan, same list-resolution
  /// as [_openExerciseDetail] -- confirms first since it takes the
  /// exercise's whole logged history with it, same reasoning as
  /// [_deletePlan].
  Future<void> _removeExercise(
      String programId, int? dayIdx, int exIdx, Exercise exercise) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteExerciseTitle),
        content: Text(t.deleteExerciseBody(exercise.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.actionCancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.actionDelete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final programs = context.read<ProgramsProvider>();
    final plan = programs.byId(programId)!;
    final exercises =
        dayIdx == null ? plan.dailyExercises : plan.days[dayIdx].exercises;
    programs.removeExercise(exercises, exIdx);
    context.read<ToastProvider>().show(t.toastExerciseDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final programsProvider = context.watch<ProgramsProvider>();
    final trainState = context.watch<TrainStateProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;
    final programs = programsProvider.programs;
    final t = AppLocalizations.of(context)!;

    if (programs.isEmpty) {
      return _EmptyState(
        onNewPlan: _newPlan,
        onImportLog: () => Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const ImportLogScreen(),
        )),
        onLoadExample: () => Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ImportLogScreen(
            initialText: exampleLog,
            initialName: t.exampleLogPlanName,
          ),
        )),
        onLoadPpl: _loadPplExample,
      );
    }

    final plan =
        programsProvider.byId(trainState.activePlanId) ?? programs.first;
    final todayIdx = todayIndexForProgram(
        mode: plan.mode, currentDayIdx: plan.currentDayIdx);
    // The raw pill/weekday index -- mechanical browsing, independent of any
    // override in effect for that date. This is what DayPillSelector tracks.
    final rawViewedIdx =
        plan.mode == 'weekday' ? trainState.viewedDayIdx : plan.currentDayIdx;
    // Only a weekday-mode plan has a coherent calendar date per pill index
    // (rotation mode's currentDayIdx never even advances anywhere in the
    // app today), so overrides only apply there.
    final viewedIso = plan.mode == 'weekday'
        ? isoOf(dateForWeekdayIndex(rawViewedIdx))
        : null;
    final overrideIdx =
        viewedIso == null ? null : trainState.dayOverride(plan.id, viewedIso);
    // The resolved index -- what every downstream call site (exercise list,
    // add/remove/reorder, ExerciseDetailScreen, WorkoutOverlayScreen) keys
    // off of, so "Start workout" always launches the session actually shown
    // on screen.
    final dayIdx = plan.mode == 'weekday'
        ? resolveDayOverride(
            defaultIdx: rawViewedIdx,
            daysLength: plan.days.length,
            overrideIdx: overrideIdx,
          )
        : plan.currentDayIdx;
    final day = (plan.days.isNotEmpty && dayIdx >= 0 && dayIdx < plan.days.length)
        ? plan.days[dayIdx]
        : null;
    final isRestDay = dayIdx == -1 || (day?.rest ?? true);
    // Falls back to the date's normal (un-overridden) Day for display when
    // the viewed date was vacated by a move (dayIdx == -1, so `day` above
    // is null) -- otherwise the header would show an empty day name
    // ("· Rest day") instead of naming the day that's actually vacated.
    final labelDay = day ??
        ((rawViewedIdx >= 0 && rawViewedIdx < plan.days.length)
            ? plan.days[rawViewedIdx]
            : null);
    final exercises =
        isRestDay ? const <Exercise>[] : (day?.exercises ?? const <Exercise>[]);
    final dailyExercises = isRestDay ? const <Exercise>[] : plan.dailyExercises;

    final localeName = Localizations.localeOf(context).toString();
    final homeLayout = context.watch<HomeLayoutProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, kFloatingNavClearance),
        children: [
          // Absolute top-right corner, above everything else — one
          // persistent menu for every header action (settings included)
          // instead of a row of separate icon buttons competing with the
          // greeting for the same line.
          Row(
            children: [
              const _VersionPill(),
              const Spacer(),
              const _StreakBadge(),
              const SizedBox(width: 8),
              _OverflowMenuButton(
                t: t,
                programs: programs,
                activePlanId: plan.id,
                onSelectPlan: _selectPlan,
                onDeletePlan: _deletePlan,
                onNewPlan: _newPlan,
                onLoadPpl: _loadPplExample,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const _HomeCalendarCard(),
          const SizedBox(height: 12),
          const _CreatineCard(),
          const SizedBox(height: 16),
          Text(plan.name, style: Theme.of(context).textTheme.headlineMedium),
          Text(
            isRestDay
                ? t.daySubtitleRest(labelDay?.label ?? '')
                : t.daySubtitleWorkouts(labelDay?.label ?? '', plan.completed),
            style: TextStyle(color: colors.mut),
          ),
          const SizedBox(height: 12),
          if (plan.mode == 'weekday')
            DayPillSelector(
              todayIdx: todayIdx,
              selectedIdx: rawViewedIdx,
              onSelect: (i) =>
                  context.read<TrainStateProvider>().setViewedDayIdx(i),
            ),
          // Hidden for a plan-designed rest day with no override -- nothing
          // to move away from it, and no override to clear either. Stays
          // visible whenever there's real content to move OR an override
          // (in-range or the vacated -1) is already in effect, so "Back to
          // weekly plan" is always reachable from the sheet.
          if (plan.mode == 'weekday' && (!isRestDay || overrideIdx != null)) ...[
            const SizedBox(height: 8),
            // Shown only when the resolved day actually differs from the
            // date's own natural weekday -- moved-in content that happens
            // to land back on its own natural weekday isn't "rescheduled",
            // and a corrupt/out-of-range override that fell back to
            // rawViewedIdx isn't either. The vacated (-1) case gets its own
            // explanation via emptyRestDayRescheduled below instead of a
            // badge here.
            if (dayIdx >= 0 && dayIdx != rawViewedIdx)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  t.moveDayRescheduledNote(DateFormat.EEEE(localeName)
                      .format(dateForWeekdayIndex(dayIdx))),
                  style: TextStyle(color: colors.mut, fontStyle: FontStyle.italic),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showMoveDaySheet(
                  context,
                  plan: plan,
                  viewedIso: viewedIso!,
                  dayIdx: dayIdx,
                  hasOverride: overrideIdx != null,
                  localeName: localeName,
                ),
                icon: const Icon(Icons.event_repeat, size: 18),
                label: Text(t.actionMoveToAnotherDay),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (!isRestDay && exercises.isNotEmpty && homeLayout.showNextWorkout) ...[
            _NextWorkoutCard(exercises: exercises),
            const SizedBox(height: 12),
          ],
          if (isRestDay)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  // dayIdx == -1 means this date was deliberately vacated
                  // by a move, not designed as a rest day in the plan
                  // itself -- reads very differently, so it gets its own
                  // string rather than the generic rest-day message.
                  dayIdx == -1 ? t.emptyRestDayRescheduled : t.emptyRestDay,
                  style: TextStyle(color: colors.mut),
                ),
              ),
            )
          else ...[
            if (exercises.isNotEmpty && homeLayout.showStartWorkout)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => WorkoutOverlayScreen(
                          programId: plan.id, dayIdx: dayIdx),
                    )),
                    child: Text(t.actionStartWorkout),
                  ),
                ),
              ),
            // Today's day-specific exercises come first -- the daily ones
            // (done every training day, see below) are secondary/repeated
            // context and belong at the bottom of the list, not competing
            // with today's actual focus for the top spot. The header and
            // "add exercise" button stay visible even when the list is
            // still empty, so a day with nothing in it yet isn't a dead
            // end -- otherwise there'd be no way to add its first exercise
            // from this screen.
            Text(t.headerTodaysDay,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            // Long-press a card to start dragging it -- ReorderableListView
            // nested (shrinkWrap + no own scrolling) inside this screen's
            // outer ListView, same nesting workout_overlay_screen.dart's
            // reorder sheet already uses.
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                context
                    .read<ProgramsProvider>()
                    .reorderExercise(exercises, oldIndex, newIndex);
              },
              children: [
                for (var i = 0; i < exercises.length; i++)
                  ReorderableDelayedDragStartListener(
                    key: ObjectKey(exercises[i]),
                    index: i,
                    child: ExerciseCard(
                      exercise: exercises[i],
                      onTapName: () => _openExerciseDetail(plan.id, dayIdx, i),
                      onDelete: () =>
                          _removeExercise(plan.id, dayIdx, i, exercises[i]),
                      onMoveToDay: () => showMoveExerciseSheet(context,
                          plan: plan, from: exercises, index: i, fromDayIdx: dayIdx),
                      onToggleSuperset: i < exercises.length - 1
                          ? () => context.read<ProgramsProvider>().toggleSuperset(exercises, i)
                          : null,
                    ),
                  ),
              ],
            ),
            TextButton(
              onPressed: () => _addExercise(plan.id, dayIdx),
              child: Text(t.actionAddExercise),
            ),
            const SizedBox(height: 16),
            Text(t.headerEveryTrainingDay,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                context
                    .read<ProgramsProvider>()
                    .reorderExercise(dailyExercises, oldIndex, newIndex);
              },
              children: [
                for (var i = 0; i < dailyExercises.length; i++)
                  ReorderableDelayedDragStartListener(
                    key: ObjectKey(dailyExercises[i]),
                    index: i,
                    child: ExerciseCard(
                      exercise: dailyExercises[i],
                      onTapName: () => _openExerciseDetail(plan.id, null, i),
                      onDelete: () => _removeExercise(
                          plan.id, null, i, dailyExercises[i]),
                      onMoveToDay: () => showMoveExerciseSheet(context,
                          plan: plan, from: dailyExercises, index: i, fromDayIdx: null),
                      onToggleSuperset: i < dailyExercises.length - 1
                          ? () => context.read<ProgramsProvider>().toggleSuperset(dailyExercises, i)
                          : null,
                    ),
                  ),
              ],
            ),
            TextButton(
              onPressed: () => _addExercise(plan.id, null),
              child: Text(t.actionAddExercise),
            ),
          ],
        ],
      ),
    );
  }
}

/// How big today's session is, at a glance. The workout/volume/PR counters
/// and the recent-PR list used to sit here too; the home screen is now just
/// the calendar and today's plan, the numbers live in the Analytics tab.
/// Off unless turned on in Settings (see [HomeLayoutProvider]).
class _NextWorkoutCard extends StatelessWidget {
  const _NextWorkoutCard({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.labelNextWorkout, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            Text(
              t.exerciseCountEstimate(exercises.length, _estimateWorkoutMinutes(exercises)),
              style: TextStyle(color: colors.mut),
            ),
          ],
        ),
      ),
    );
  }
}

/// The training calendar where the greeting used to be: the newest weeks of
/// the GitHub-style graph that fit the width (no sideways scrolling -- the
/// app's page view owns that swipe), counting guided workouts and days on
/// which single exercises were saved alike. Any tap opens the full calendar.
class _HomeCalendarCard extends StatelessWidget {
  const _HomeCalendarCard();

  void _open(BuildContext context, [DateTime? day]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalendarScreen(initialDate: day)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final localeName = Localizations.localeOf(context).toString();
    final days = aggregateHeatmapDays(sessionsWithLoggedExercises(
      context.watch<WorkoutHistoryProvider>().sessions,
      context.watch<ProgramsProvider>().programs,
    ));
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.yMMMMEEEEd(localeName).format(DateTime.now()),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Icon(Icons.calendar_month_rounded, size: 20, color: colors.mut),
                ],
              ),
              const SizedBox(height: 12),
              ContributionHeatmap(
                days: days,
                layout: HeatmapLayout.fitToWidth,
                onSelectDate: (day) => _open(context, day),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current training streak in the header: a flame that grows with it
/// and the number of days. Counted like the calendar and the Consistency
/// tab -- guided workouts plus days of single saved exercises, rest days
/// from the plan don't break it. A tap opens the full calendar.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final programs = context.watch<ProgramsProvider>();
    final streak = computeConsistency(
      sessionsWithLoggedExercises(context.watch<WorkoutHistoryProvider>().sessions, programs.programs),
      isRestDay: activePlanRestDays(programs, context.watch<TrainStateProvider>()),
    ).currentStreakDays;

    return Semantics(
      button: true,
      label: '${t.labelCurrentStreak}: ${t.trainingStreak(streak)}',
      child: ExcludeSemantics(
        child: Tooltip(
          message: t.trainingStreak(streak),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StreakFlame(days: streak),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: TextStyle(
                      color: streak > 0 ? colors.txt : colors.mut,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ticking off the daily creatine, kept compact so it doesn't push today's
/// plan down: a check for today, the last seven days as small dots
/// underneath (tap one to fix a forgotten or wrong tick), and the days in
/// a row as a flame next to the title.
class _CreatineCard extends StatelessWidget {
  const _CreatineCard();

  static void _toggle(BuildContext context, DateTime day) {
    HapticFeedback.selectionClick();
    context.read<CreatineProvider>().toggle(day);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final creatine = context.watch<CreatineProvider>();
    final localeName = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final takenToday = creatine.takenOn(today);
    final streak = creatine.streak(now: now);
    final week = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(Icons.medication_rounded, size: 16, color: colors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              t.creatineTitle,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 14.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (streak > 0) ...[
                            const SizedBox(width: 6),
                            Semantics(
                              label: t.creatineStreak(streak),
                              child: ExcludeSemantics(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_fire_department_rounded, size: 14, color: colors.accent),
                                    Text(
                                      '$streak',
                                      style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        takenToday ? t.creatineTakenToday : t.creatineNotYet,
                        style: TextStyle(
                          color: takenToday ? colors.green : colors.mut,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  checked: takenToday,
                  label: t.creatineTitle,
                  child: GestureDetector(
                    onTap: () => _toggle(context, today),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: takenToday ? colors.accent : colors.card2,
                        border: Border.all(color: takenToday ? colors.accent : colors.line, width: 1.5),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 19,
                        color: takenToday ? colors.onAccent : colors.mut,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final day in week)
                  _CreatineDay(
                    weekday: DateFormat.E(localeName).format(day),
                    date: DateFormat.MMMd(localeName).format(day),
                    taken: creatine.takenOn(day),
                    isToday: day == today,
                    onTap: () => _toggle(context, day),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the last seven days: weekday above a dot that's filled once
/// ticked; today's has a ring.
class _CreatineDay extends StatelessWidget {
  const _CreatineDay({
    required this.weekday,
    required this.date,
    required this.taken,
    required this.isToday,
    required this.onTap,
  });

  final String weekday;
  final String date;
  final bool taken;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Semantics(
      button: true,
      checked: taken,
      label: '$weekday, $date',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Column(
            children: [
              Text(
                weekday,
                style: TextStyle(
                  color: isToday ? colors.txt : colors.mut,
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: taken ? colors.accent : colors.card2,
                  border: isToday && !taken ? Border.all(color: colors.accent, width: 1.5) : null,
                ),
                child: taken ? Icon(Icons.check_rounded, size: 13, color: colors.onAccent) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app version, small, in the header's top-left corner (the menu has
/// the right one) -- and the one-tap way to update. [UpdateProvider] checks and
/// downloads silently in the background; once it has found a newer release
/// this turns into an accent "↑ v2.14.0" pill that installs it on tap (with
/// a progress ring while the download runs), retries a failed download, or
/// -- where this platform has no download -- opens the release page. Up to
/// date it shows the installed version, muted, and a tap checks again.
class _VersionPill extends StatelessWidget {
  const _VersionPill();

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final status = update.status;
    final latest = update.result?.latestVersion;
    final newer = switch (status) {
      UpdateStatus.downloaded => update.downloadedVersion ?? latest,
      UpdateStatus.updateAvailable || UpdateStatus.downloading => latest,
      _ => null,
    };
    final installed = update.installedVersion;
    final version = newer ?? installed;
    if (version == null) return const SizedBox.shrink();

    final releaseUrl = update.result?.releaseUrl;
    final VoidCallback? onTap;
    final String tooltip;
    switch (status) {
      case UpdateStatus.downloaded:
        onTap = update.openDownloadedUpdate;
        tooltip = t.labelUpdateReady(version);
      case UpdateStatus.updateAvailable:
        // Still "available" after a failed download: checking again starts
        // a fresh one. Without a build for this platform, the release page.
        onTap = update.result?.assetForThisPlatform != null
            ? update.checkNow
            : (releaseUrl == null
                ? null
                : () => launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication));
        tooltip = t.labelUpdateAvailable(version);
      case UpdateStatus.downloading:
        onTap = null;
        tooltip = t.labelDownloadingUpdate((update.downloadProgress * 100).round());
      case UpdateStatus.checking:
        onTap = null;
        tooltip = t.actionChecking;
      case UpdateStatus.upToDate:
        onTap = update.checkNow;
        tooltip = t.labelUpToDate;
      case UpdateStatus.idle:
      case UpdateStatus.error:
        onTap = update.checkNow;
        tooltip = t.labelInstalledVersion(version);
    }

    final highlight = newer != null;
    final foreground = highlight ? colors.onAccent : colors.mut;
    final Widget? lead = switch (status) {
      UpdateStatus.downloading => SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(
            value: update.downloadProgress > 0 ? update.downloadProgress : null,
            strokeWidth: 2,
            color: foreground,
          ),
        ),
      UpdateStatus.checking => SizedBox.square(
          dimension: 11,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: foreground),
        ),
      _ when highlight => Icon(Icons.arrow_upward_rounded, size: 15, color: foreground),
      _ => null,
    };
    return Tooltip(
      message: tooltip,
      child: Material(
        color: highlight ? colors.accent : colors.card2,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 5)],
                Text(
                  'v$version',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onNewPlan,
    required this.onImportLog,
    required this.onLoadExample,
    required this.onLoadPpl,
  });

  final VoidCallback onNewPlan;
  final VoidCallback onImportLog;
  final VoidCallback onLoadExample;
  final VoidCallback onLoadPpl;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SafeArea(
      child: Stack(
        children: [
          _buildBody(context, t),
          // Same corner as on a plan's screen.
          const Positioned(top: 12, left: 16, child: _VersionPill()),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.emptyNoPlan,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: onNewPlan, child: Text(t.actionNewPlan)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onImportLog,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text(t.actionImportLog),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLoadExample,
                icon: const Icon(Icons.star_outline, size: 18),
                label: Text(t.actionLoadExample),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLoadPpl,
                icon: const Icon(Icons.fitness_center, size: 18),
                label: Text(t.actionLoadPplExample),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OverflowAction {
  settings,
  allPlans,
  calendar,
  gallery,
  theme,
  language,
  backup,
}

/// One persistent dropdown for every header action, settings included —
/// calendar, gallery, plan switcher, theme, language, backup all live here
/// instead of as a row of separate icon buttons. A row of 5+ icon buttons
/// reads as cluttered on a phone-width header; one recognizable "more" icon
/// pinned to the very top-right corner that opens all of them does the same
/// job without the visual noise. Acting in [onSelected] (fired after the
/// menu has already closed) rather than a per-item `onTap` avoids the
/// bottom sheet's route fighting with the popup menu's own closing
/// animation.
class _OverflowMenuButton extends StatelessWidget {
  const _OverflowMenuButton({
    required this.t,
    required this.programs,
    required this.activePlanId,
    required this.onSelectPlan,
    required this.onDeletePlan,
    required this.onNewPlan,
    required this.onLoadPpl,
  });

  final AppLocalizations t;
  final List<Program> programs;
  final String activePlanId;
  final ValueChanged<Program> onSelectPlan;
  final ValueChanged<Program> onDeletePlan;
  final VoidCallback onNewPlan;
  final VoidCallback onLoadPpl;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_OverflowAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        switch (action) {
          case _OverflowAction.settings:
            Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const SettingsScreen(),
            ));
          case _OverflowAction.allPlans:
            final chosen = await showPlanPicker(
              context,
              programs: programs,
              activeId: activePlanId,
              onDelete: onDeletePlan,
              onNewPlan: onNewPlan,
              onLoadPpl: onLoadPpl,
            );
            if (chosen != null) onSelectPlan(chosen);
          case _OverflowAction.calendar:
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarScreen()));
          case _OverflowAction.gallery:
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const GalleryScreen()));
          case _OverflowAction.theme:
            context.read<ThemeProvider>().toggle();
          case _OverflowAction.language:
            showLanguagePicker(context);
          case _OverflowAction.backup:
            showBackupSheet(context);
        }
      },
      itemBuilder: (context) {
        final isDark = context.read<ThemeProvider>().isDark;
        return [
          PopupMenuItem(
            value: _OverflowAction.settings,
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(t.titleSettings),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _OverflowAction.allPlans,
            child: ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(t.actionAllPlans),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _OverflowAction.calendar,
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(t.titleCalendar),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _OverflowAction.gallery,
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.titleGallery),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _OverflowAction.theme,
            child: ListTile(
              leading: Icon(
                  isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
              title: Text(isDark ? t.actionLightMode : t.actionDarkMode),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _OverflowAction.language,
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(t.settingsLanguage),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _OverflowAction.backup,
            child: ListTile(
              leading: const Icon(Icons.import_export),
              title: Text(t.titleBackup),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ];
      },
    );
  }
}
