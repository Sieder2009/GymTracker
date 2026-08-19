import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/workout_session.dart';
import '../state/workout_history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Month-grid view of logged workouts, ported to the same design language
/// as the rest of the app (cards, accent dots) rather than a generic
/// calendar-package look. Tapping a day shows that day's sessions below
/// the grid — total time comes straight from [WorkoutHistoryProvider],
/// which every finished [WorkoutOverlayScreen] session feeds.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDate = null;
    });
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final localeName = Localizations.localeOf(context).toString();
    final sessions = context.watch<WorkoutHistoryProvider>().sessions;

    final byDate = <String, List<WorkoutSession>>{};
    for (final s in sessions) {
      byDate.putIfAbsent(s.date, () => []).add(s);
    }

    final monthSessions = sessions.where((s) {
      final d = DateTime.tryParse(s.date);
      return d != null && d.year == _visibleMonth.year && d.month == _visibleMonth.month;
    }).toList();
    final monthMinutes = monthSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

    final weekdaysShort = [
      t.weekdayMonShort, t.weekdayTueShort, t.weekdayWedShort, t.weekdayThuShort,
      t.weekdayFriShort, t.weekdaySatShort, t.weekdaySunShort,
    ];

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1; // Monday=1 -> 0 blanks
    final cellCount = leadingBlanks + daysInMonth;
    final rowCount = (cellCount / 7).ceil();

    final selectedSessions = _selectedDate == null ? null : byDate[_iso(_selectedDate!)];

    return Scaffold(
      appBar: AppBar(title: Text(t.titleCalendar)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: t.calendarPrevMonth,
                  onPressed: () => _shiftMonth(-1),
                ),
                Text(
                  DateFormat.yMMMM(localeName).format(_visibleMonth),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: t.calendarNextMonth,
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            Center(
              child: Text(
                t.calendarMonthSummary(monthSessions.length, (monthMinutes / 60).toStringAsFixed(1)),
                style: TextStyle(color: colors.mut),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final w in weekdaysShort)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(color: colors.mut, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rowCount * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, i) {
                final dayNum = i - leadingBlanks + 1;
                if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
                final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
                final hasSession = byDate.containsKey(_iso(date));
                final isSelected = _selectedDate != null &&
                    _selectedDate!.year == date.year &&
                    _selectedDate!.month == date.month &&
                    _selectedDate!.day == date.day;
                final isToday = _iso(date) == _iso(DateTime.now());

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? colors.accent : colors.card2,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: isToday && !isSelected
                            ? Border.all(color: colors.accent, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              color: isSelected ? colors.onAccent : colors.txt,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (hasSession)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? colors.onAccent : colors.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (selectedSessions == null || selectedSessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(t.emptyNoSessionsThisDay, style: TextStyle(color: colors.mut)),
              )
            else
              for (final s in selectedSessions)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.fitness_center, color: colors.accent),
                    title: Text(s.planName),
                    trailing: Text(t.labelMinutesShort(s.durationMinutes)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
