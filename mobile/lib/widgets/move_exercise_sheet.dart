import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';

/// Moves `from[index]` to another day of [plan] for good (see
/// [ProgramsProvider.moveExerciseToDay]) -- unlike MoveDaySheet, which only
/// reschedules a whole day for one date. [fromDayIdx] null means [from] is
/// the plan's "every training day" list.
Future<void> showMoveExerciseSheet(
  BuildContext context, {
  required Program plan,
  required List<Exercise> from,
  required int index,
  required int? fromDayIdx,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MoveExerciseSheet(
      plan: plan,
      from: from,
      index: index,
      fromDayIdx: fromDayIdx,
    ),
  );
}

class _MoveExerciseSheet extends StatelessWidget {
  const _MoveExerciseSheet({
    required this.plan,
    required this.from,
    required this.index,
    required this.fromDayIdx,
  });

  final Program plan;
  final List<Exercise> from;
  final int index;
  final int? fromDayIdx;

  /// A weekday plan's days are named by their weekday in the app's language
  /// (the stored labels are fixed German names); other plans by their label.
  String _dayName(BuildContext context, int i) {
    if (plan.mode != 'weekday') return plan.days[i].label;
    final localeName = Localizations.localeOf(context).toString();
    return DateFormat.EEEE(localeName).format(dateForWeekdayIndex(i));
  }

  void _move(BuildContext context, int? toDayIdx, String targetName) {
    final t = AppLocalizations.of(context)!;
    Navigator.of(context).pop();
    context.read<ProgramsProvider>().moveExerciseToDay(plan, from, index, toDayIdx);
    context.read<ToastProvider>().show(t.toastExerciseMoved(targetName));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;

    Widget target({
      required String title,
      required String subtitle,
      required bool isSource,
      required VoidCallback onTap,
    }) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(title),
          subtitle: Text(subtitle, style: TextStyle(color: colors.mut)),
          trailing: isSource
              ? Text(t.labelCurrent, style: TextStyle(color: colors.mut))
              : Icon(Icons.chevron_right_rounded, color: colors.mut),
          enabled: !isSource,
          onTap: isSource ? null : onTap,
        ),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text(t.titleMoveExercise(from[index].name),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(t.moveExerciseIntro, style: TextStyle(color: colors.mut)),
            const SizedBox(height: 16),
            for (var i = 0; i < plan.days.length; i++)
              target(
                title: _dayName(context, i),
                subtitle: plan.days[i].rest && plan.days[i].exercises.isEmpty
                    ? t.labelRestDay
                    : t.moveExerciseDayCount(plan.days[i].exercises.length),
                isSource: fromDayIdx == i,
                onTap: () => _move(context, i, _dayName(context, i)),
              ),
            target(
              title: t.labelEveryTrainingDay,
              subtitle: t.moveExerciseDayCount(plan.dailyExercises.length),
              isSource: fromDayIdx == null,
              onTap: () => _move(context, null, t.labelEveryTrainingDay),
            ),
          ],
        ),
      ),
    );
  }
}
