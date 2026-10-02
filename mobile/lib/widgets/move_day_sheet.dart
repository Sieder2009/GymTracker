import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/program.dart';
import '../state/toast_provider.dart';
import '../state/train_state_provider.dart';
import '../theme/app_colors.dart';

/// "Move to another day" bottom sheet -- reschedules the Day currently
/// showing on [viewedIso] onto a different calendar date (or clears an
/// existing override), without ever touching the saved plan's Day list.
/// Same shape as `plan_picker_sheet.dart`'s `PlanPickerSheet`/`showPlanPicker`.
class MoveDaySheet extends StatelessWidget {
  const MoveDaySheet({
    super.key,
    required this.plan,
    required this.viewedIso,
    required this.dayIdx,
    required this.hasOverride,
    required this.localeName,
  });

  final Program plan;

  /// The date currently being viewed, 'YYYY-MM-DD' -- the move's source.
  final String viewedIso;

  /// The resolved Day index currently showing on [viewedIso]. `-1` means
  /// this date was explicitly vacated (rest/skipped) -- there's nothing to
  /// move away from it, so the target-date list is hidden.
  final int dayIdx;

  /// Whether [viewedIso] currently has ANY override applied (in-range or
  /// `-1`) -- gates the "Back to weekly plan" row.
  final bool hasOverride;

  final String localeName;

  String _labelForResolvedIdx(AppLocalizations t, int resolvedIdx) {
    if (resolvedIdx < 0 || resolvedIdx >= plan.days.length) {
      return t.labelRestDay;
    }
    final day = plan.days[resolvedIdx];
    return day.rest ? t.labelRestDay : day.label;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final trainState = context.read<TrainStateProvider>();

    // The weekday [viewedIso] would show by default (no override) -- used
    // only to decide whether the "rescheduled from" note below is actually
    // telling the user something (a moved-in day showing on the very date
    // it naturally belongs to isn't "rescheduled").
    final naturalIdx = DateTime.parse(viewedIso).weekday - 1;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    // Next 7 calendar dates starting today, excluding the source date
    // itself -- moving a day onto the very date it's already showing on
    // wouldn't do anything.
    final candidates = [
      for (var offset = 0; offset < 7; offset++)
        DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day + offset),
    ].where((d) => isoOf(d) != viewedIso).toList();

    // Real content to move away from -- a plan-designed rest day (built
    // into the plan, not vacated by a move) has nothing to move, so the
    // target-date list stays hidden for it too, same as for dayIdx == -1.
    final hasContentToMove =
        dayIdx >= 0 && dayIdx < plan.days.length && !plan.days[dayIdx].rest;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.titleMoveDay, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(t.moveDaySheetIntro, style: TextStyle(color: colors.mut)),
            const SizedBox(height: 12),
            Text(
              t.moveDayCurrentlyShowing(_labelForResolvedIdx(t, dayIdx)),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (dayIdx >= 0 && dayIdx < plan.days.length && dayIdx != naturalIdx)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t.moveDayRescheduledNote(
                      DateFormat.EEEE(localeName).format(dateForWeekdayIndex(dayIdx))),
                  style: TextStyle(color: colors.mut, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            if (hasContentToMove) ...[
              Text(t.moveDayPickTargetPrompt,
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              for (final candidate in candidates)
                _CandidateTile(
                  t: t,
                  colors: colors,
                  plan: plan,
                  localeName: localeName,
                  candidate: candidate,
                  overrideIdx: trainState.dayOverride(plan.id, isoOf(candidate)),
                  onTap: () {
                    final candidateIso = isoOf(candidate);
                    Navigator.of(context).pop();
                    trainState.moveDayOverride(
                      plan.id,
                      sourceIso: viewedIso,
                      dayIdx: dayIdx,
                      targetIso: candidateIso,
                    );
                    context.read<ToastProvider>().show(
                        t.toastDayMoved(DateFormat.EEEE(localeName).format(candidate)));
                  },
                ),
            ],
            if (hasOverride) ...[
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.undo),
                  title: Text(t.actionBackToWeeklyPlan),
                  onTap: () {
                    Navigator.of(context).pop();
                    trainState.clearDayOverride(plan.id, viewedIso);
                    context.read<ToastProvider>().show(t.toastDayOverrideCleared);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One selectable target-date row -- resolves the candidate date's OWN
/// override the same way `training_screen.dart` resolves the viewed date's,
/// so the subtitle always shows what a tap on this row would actually
/// overwrite.
class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.t,
    required this.colors,
    required this.plan,
    required this.localeName,
    required this.candidate,
    required this.overrideIdx,
    required this.onTap,
  });

  final AppLocalizations t;
  final AppColors colors;
  final Program plan;
  final String localeName;
  final DateTime candidate;
  final int? overrideIdx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final defaultIdx = candidate.weekday - 1; // Dart Mon=1..Sun=7 -> Mon=0..Sun=6
    final resolvedIdx = resolveDayOverride(
      defaultIdx: defaultIdx,
      daysLength: plan.days.length,
      overrideIdx: overrideIdx,
    );
    final day = (resolvedIdx >= 0 && resolvedIdx < plan.days.length)
        ? plan.days[resolvedIdx]
        : null;
    final isRest = resolvedIdx == -1 || (day?.rest ?? true);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(DateFormat.MMMEd(localeName).format(candidate)),
        subtitle: Text(
          isRest ? t.moveDayTargetSubtitleRest : t.moveDayTargetSubtitleWorkout(day?.label ?? ''),
          style: TextStyle(color: colors.mut),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Shows [MoveDaySheet] as a modal bottom sheet.
Future<void> showMoveDaySheet(
  BuildContext context, {
  required Program plan,
  required String viewedIso,
  required int dayIdx,
  required bool hasOverride,
  required String localeName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => MoveDaySheet(
      plan: plan,
      viewedIso: viewedIso,
      dayIdx: dayIdx,
      hasOverride: hasOverride,
      localeName: localeName,
    ),
  );
}
