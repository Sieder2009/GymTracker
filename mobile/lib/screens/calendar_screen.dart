import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/workout_session.dart';
import '../state/workout_history_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/contribution_heatmap.dart';

const int _kHeatmapWeeks = 53;

/// GitHub-contribution-graph-style view of logged workouts (see
/// [ContributionHeatmap]) instead of a single-month grid — the whole
/// trailing year is visible at a glance, scrollable back further. Tapping a
/// day shows that day's sessions below the grid — total time comes
/// straight from [WorkoutHistoryProvider], which every finished
/// [WorkoutOverlayScreen] session feeds.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
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

    final today = DateTime.now();
    final currentWeekMonday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    final rangeStart = currentWeekMonday.subtract(const Duration(days: 7 * (_kHeatmapWeeks - 1)));
    final rangeSessions = sessions.where((s) {
      final d = DateTime.tryParse(s.date);
      return d != null && !d.isBefore(rangeStart);
    }).toList();
    final rangeMinutes = rangeSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

    final selectedSessions = byDate[_iso(_selectedDate)];

    return Scaffold(
      appBar: AppBar(title: Text(t.titleCalendar)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              '${DateFormat.yMMM(localeName).format(rangeStart)} '
              '– ${DateFormat.yMMM(localeName).format(today)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 2),
            Text(
              t.calendarMonthSummary(rangeSessions.length, (rangeMinutes / 60).toStringAsFixed(1)),
              style: TextStyle(color: colors.mut),
            ),
            const SizedBox(height: 16),
            ContributionHeatmap(
              sessionsByDate: byDate,
              selectedDate: _selectedDate,
              onSelectDate: (d) => setState(() => _selectedDate = d),
              weeks: _kHeatmapWeeks,
            ),
            const SizedBox(height: 20),
            Text(
              DateFormat.yMMMMEEEEd(localeName).format(_selectedDate),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
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
