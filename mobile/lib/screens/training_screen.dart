import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics_engine.dart';
import '../data/constants.dart';
import '../data/example_log.dart';
import '../data/example_ppl_plan.dart';
import '../data/health_brand.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../overlays/exercise_detail_screen.dart';
import '../overlays/import_log_screen.dart';
import '../overlays/plan_editor_screen.dart';
import '../overlays/settings_screen.dart';
import '../overlays/workout_overlay_screen.dart';
import '../state/big_lifts_provider.dart';
import '../state/health_provider.dart';
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
import '../widgets/day_pill_selector.dart';
import '../widgets/exercise_card.dart';
import '../widgets/health_connect_feedback.dart';
import '../widgets/language_picker_sheet.dart';
import '../widgets/plan_picker_sheet.dart';
import '../state/theme_provider.dart';
import 'calendar_screen.dart';
import 'gallery_screen.dart';

String _greeting(AppLocalizations t) {
  final hour = DateTime.now().hour;
  if (hour < 12) return t.greetingMorning;
  if (hour < 18) return t.greetingAfternoon;
  return t.greetingEvening;
}

/// Rough estimate only (no per-exercise timing data exists) — roughly 3
/// minutes per set including rest, matching the guided workout's typical
/// pace. Shown with a "~" prefix so it never reads as a precise number.
int _estimateWorkoutMinutes(List<Exercise> exercises) {
  var sets = 0;
  for (final e in exercises) {
    sets += e.sets.length;
  }
  return sets * 3;
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
    // the shell's PageView) — forces the plan prompt when multiple plans
    // exist, so the user always confirms which one they're training today.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeForcePlanPrompt());
  }

  Future<void> _maybeForcePlanPrompt() async {
    if (!mounted) return;
    final programs = context.read<ProgramsProvider>().programs;
    if (programs.length <= 1) return;
    final trainState = context.read<TrainStateProvider>();
    final chosen = await showPlanPicker(
      context,
      programs: programs,
      activeId: trainState.activePlanId,
      onDelete: _deletePlan,
      isDismissible: false,
      onNewPlan: _newPlan,
      onLoadPpl: _loadPplExample,
    );
    if (chosen != null) _selectPlan(chosen);
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
    final dayIdx =
        plan.mode == 'weekday' ? trainState.viewedDayIdx : plan.currentDayIdx;
    final day = (plan.days.isNotEmpty && dayIdx < plan.days.length)
        ? plan.days[dayIdx]
        : null;
    final isRestDay = day?.rest ?? true;
    final exercises =
        isRestDay ? const <Exercise>[] : (day?.exercises ?? const <Exercise>[]);
    final dailyExercises = isRestDay ? const <Exercise>[] : plan.dailyExercises;

    final localeName = Localizations.localeOf(context).toString();

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
              const Spacer(),
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
          Text(_greeting(t), style: Theme.of(context).textTheme.headlineLarge),
          Text(
            DateFormat.yMMMMEEEEd(localeName).format(DateTime.now()),
            style: TextStyle(color: colors.mut),
          ),
          const _UpdateAvailableCard(),
          const SizedBox(height: 12),
          Text(plan.name, style: Theme.of(context).textTheme.headlineMedium),
          Text(
            isRestDay
                ? t.daySubtitleRest(day?.label ?? '')
                : t.daySubtitleWorkouts(day?.label ?? '', plan.completed),
            style: TextStyle(color: colors.mut),
          ),
          const SizedBox(height: 12),
          if (plan.mode == 'weekday')
            DayPillSelector(
              todayIdx: todayIdx,
              selectedIdx: dayIdx,
              onSelect: (i) =>
                  context.read<TrainStateProvider>().setViewedDayIdx(i),
            ),
          const SizedBox(height: 16),
          _HomeDashboardStats(exercises: exercises, isRestDay: isRestDay),
          // Extra breathing room (not just the usual 16) before the "start
          // workout" CTA -- it's the one button that can land right at the
          // floating nav bar's fold on first load (no scroll needed), and
          // longer-language translations of everything above it (stats
          // labels, health-connect card, PR list) push it further down
          // than German does, so a tight gap here risks the button peeking
          // out from behind the bar instead of sitting safely under it.
          const SizedBox(height: 28),
          if (isRestDay)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  t.emptyRestDay,
                  style: TextStyle(color: colors.mut),
                ),
              ),
            )
          else ...[
            if (exercises.isNotEmpty)
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
            for (var i = 0; i < exercises.length; i++)
              ExerciseCard(
                exercise: exercises[i],
                onTapName: () => _openExerciseDetail(plan.id, dayIdx, i),
              ),
            TextButton(
              onPressed: () => _addExercise(plan.id, dayIdx),
              child: Text(t.actionAddExercise),
            ),
            const SizedBox(height: 16),
            Text(t.headerEveryTrainingDay,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < dailyExercises.length; i++)
              ExerciseCard(
                exercise: dailyExercises[i],
                onTapName: () => _openExerciseDetail(plan.id, null, i),
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

/// Quick Stats + This Week + Recent PRs — the "at a glance" section of the
/// home dashboard, entirely computed from [analytics_engine], never shown
/// for a rest day's exercise estimate (that part alone respects [isRestDay]).
class _HomeDashboardStats extends StatelessWidget {
  const _HomeDashboardStats({required this.exercises, required this.isRestDay});

  final List<Exercise> exercises;
  final bool isRestDay;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final sessions = context.watch<WorkoutHistoryProvider>().sessions;
    final lifts = context.watch<BigLiftsProvider>().lifts;

    final week = computeWeekSummary(sessions);
    final recentPrs = countRecentLiftPrs(lifts);

    final prEntries = <MapEntry<String, double>>[
      if (lifts.bench.pr > 0) MapEntry(t.labelBenchPress, lifts.bench.pr),
      if (lifts.deadlift.pr > 0) MapEntry(t.labelDeadlift, lifts.deadlift.pr),
      if (lifts.squat.pr > 0) MapEntry(t.labelSquat, lifts.squat.pr),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isRestDay && exercises.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.labelNextWorkout,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Text(
                    t.exerciseCountEstimate(
                        exercises.length, _estimateWorkoutMinutes(exercises)),
                    style: TextStyle(color: colors.mut),
                  ),
                ],
              ),
            ),
          ),
        Text(t.labelQuickStats, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _QuickStatTile(
                    label: t.labelWorkouts, value: '${week.workoutCount}')),
            const SizedBox(width: 10),
            Expanded(
                child: _QuickStatTile(
                    label: t.labelVolume,
                    value: '${fmt(week.totalVolumeKg)} kg')),
            const SizedBox(width: 10),
            Expanded(
                child: _QuickStatTile(label: t.labelPRs, value: '$recentPrs')),
          ],
        ),
        const _HealthCard(),
        if (prEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(t.labelRecentPrs, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          for (final entry in prEntries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 18, color: colors.yellow),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key)),
                  Text('${fmt1(entry.value)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Surfaces a ready-to-install (or, lacking a platform build asset, just
/// available) app update right on the home screen — previously this state
/// was only visible if the user happened to open Settings, easy to miss
/// since [UpdateProvider] checks and downloads silently in the background.
/// Gone once [UpdateProvider.status] moves past updateAvailable/downloaded
/// (e.g. back to upToDate once the user has installed and relaunched).
class _UpdateAvailableCard extends StatelessWidget {
  const _UpdateAvailableCard();

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();
    final isDownloaded = update.status == UpdateStatus.downloaded;
    final isAvailable = update.status == UpdateStatus.updateAvailable;
    if (!isDownloaded && !isAvailable) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final version =
        (isDownloaded ? update.downloadedVersion : update.result?.latestVersion) ?? '';
    final releaseUrl = update.result?.releaseUrl;
    final onTap = isDownloaded
        ? () => update.openDownloadedUpdate()
        : (releaseUrl == null ? null : () => launchUrl(Uri.parse(releaseUrl)));

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: const Icon(Icons.arrow_circle_up_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.labelUpdateAvailable(version),
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 2),
                      Text(
                        isDownloaded ? t.actionInstallUpdate : t.actionDownloadUpdate,
                        style: TextStyle(color: colors.mut, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: colors.mut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-time connect prompt, only shown on Android/iOS (see
/// [HealthProvider.isSupportedPlatform]) and only until the user actually
/// connects — once [HealthProvider.isConnected] is true this card is gone
/// from the dashboard entirely (re-enabling/disabling afterwards lives in
/// Settings, see `_HealthSection`) rather than sitting there permanently
/// showing a steps count nobody asked to see on the home screen every day.
///
/// Styled as one fully-tappable iOS-Settings-style row (leading brand tile,
/// title/subtitle, trailing chevron) rather than a card with its own inner
/// button — the old [OutlinedButton] rendered in [AppColors.secondary]
/// (green), which reads as an unrelated accent next to the rest of the
/// screen's blue. iOS/Android get their own real product name (see
/// [healthBrandName]/[healthBrandColor]) and brand color here (not the
/// app's own accent) so the row visually
/// reads as "this connects to the OS's health store", distinct from in-app
/// actions — deliberately not Apple's actual "Works with Apple Health"
/// badge artwork or Health Connect's launcher icon, both of which are
/// trademarked assets this app isn't licensed to reproduce; a generic
/// heart glyph on the brand color communicates the same thing without
/// copying either badge design.
class _HealthCard extends StatelessWidget {
  const _HealthCard();

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    if (!health.isSupportedPlatform || health.isConnected) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final brandColor = healthBrandColor();
    final brandName = healthBrandName();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: health.isLoading ? null : () => connectHealthWithFeedback(context, health, t),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(brandName,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 2),
                      Text(
                        health.isLoading ? t.actionConnectHealth : t.titleHealthSync,
                        style: TextStyle(color: colors.mut, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (health.isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.mut),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: colors.mut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStatTile extends StatelessWidget {
  const _QuickStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: colors.mut, fontSize: 11.5)),
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
