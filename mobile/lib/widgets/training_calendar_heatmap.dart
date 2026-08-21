import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/workout_session.dart';
import '../theme/app_colors.dart';

/// Compact, read-only current-month grid for the Analytics tab — a trained
/// day gets a filled teal ring, today gets an accent outline. Same visual
/// language as [CalendarScreen]'s own month grid (`calendar_screen.dart`),
/// just smaller and without navigation or day selection, so "how consistent
/// was I this month" doesn't require leaving the Analytics tab. Every
/// marked day comes straight from [sessions] — never a guessed pattern.
class TrainingCalendarHeatmap extends StatelessWidget {
  const TrainingCalendarHeatmap({super.key, required this.sessions});

  final List<WorkoutSession> sessions;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final localeName = Localizations.localeOf(context).toString();
    final now = DateTime.now();

    final trainedDays = <String>{};
    final monthSessions = <WorkoutSession>[];
    for (final s in sessions) {
      final d = DateTime.tryParse(s.date);
      if (d == null || d.year != now.year || d.month != now.month) continue;
      trainedDays.add(_iso(d));
      monthSessions.add(s);
    }
    final monthMinutes =
        monthSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

    final firstOfMonth = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1; // Monday=1 -> 0 blanks
    final cellCount = leadingBlanks + daysInMonth;
    final rowCount = (cellCount / 7).ceil();
    final weekdaysShort = [
      t.weekdayMonShort, t.weekdayTueShort, t.weekdayWedShort, t.weekdayThuShort,
      t.weekdayFriShort, t.weekdaySatShort, t.weekdaySunShort,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.yMMMM(localeName).format(now),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(
              t.calendarMonthSummary(
                  monthSessions.length, (monthMinutes / 60).toStringAsFixed(1)),
              style: TextStyle(color: colors.mut, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final w in weekdaysShort)
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: TextStyle(
                              color: colors.mut,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rowCount * 7,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, i) {
                final dayNum = i - leadingBlanks + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final trained = trainedDays.contains(
                    _iso(DateTime(now.year, now.month, dayNum)));
                final isToday = dayNum == now.day;
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: trained
                          ? colors.teal.withValues(alpha: 0.16)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday
                            ? colors.accent
                            : (trained ? colors.teal : colors.line),
                        width: isToday ? 1.6 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            trained || isToday ? FontWeight.w700 : FontWeight.w500,
                        color: trained
                            ? colors.teal
                            : (isToday ? colors.accent : colors.mut),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
