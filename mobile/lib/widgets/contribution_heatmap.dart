import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_session.dart';
import '../theme/app_colors.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const double _cell = 12;
const double _gap = 3;
const double _pitch = _cell + _gap;
const double _monthLabelHeight = 16;

/// GitHub-contribution-graph-style activity grid: one column per week
/// (Monday-first, matching this app's own calendar convention), one cell
/// per day, shaded by that day's training volume relative to the heaviest
/// day in the shown window. Colors come from [AppColors] (a lerp from
/// `card2` to `teal`) rather than GitHub's own green, so it re-themes with
/// the rest of the app -- including a user's custom accent/secondary pick
/// in Settings -- instead of being a fixed, foreign-looking green box.
class ContributionHeatmap extends StatelessWidget {
  const ContributionHeatmap({
    super.key,
    required this.sessionsByDate,
    required this.selectedDate,
    required this.onSelectDate,
    this.weeks = 53,
  });

  /// ISO date ('YYYY-MM-DD') -> that day's sessions.
  final Map<String, List<WorkoutSession>> sessionsByDate;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final localeName = Localizations.localeOf(context).toString();
    final today = _dateOnly(DateTime.now());

    // Grid columns run Monday-first, same as the rest of the app's calendar
    // widgets. The last column is the week containing today; days after
    // today within that final week are left blank (not "zero activity",
    // just not real days yet).
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = currentWeekMonday.subtract(Duration(days: 7 * (weeks - 1)));

    double scoreFor(DateTime day) {
      final sessions = sessionsByDate[_iso(day)];
      if (sessions == null || sessions.isEmpty) return 0;
      final volume = sessions.fold<double>(0, (sum, s) => sum + s.totalVolumeKg);
      // A logged session with no tracked volume (e.g. a bodyweight-only
      // day) should still read as "something happened", not an empty cell.
      return volume > 0 ? volume : 1;
    }

    var maxScore = 0.0;
    for (var i = 0; i < weeks * 7; i++) {
      final day = firstMonday.add(Duration(days: i));
      if (day.isAfter(today)) break;
      final s = scoreFor(day);
      if (s > maxScore) maxScore = s;
    }

    int levelFor(double score) {
      if (score <= 0 || maxScore <= 0) return 0;
      final t = (score / maxScore).clamp(0.0, 1.0);
      return 1 + (t * 3.999).floor(); // 1..4
    }

    Color colorForLevel(int level) {
      if (level == 0) return colors.card2;
      const stops = [0.3, 0.55, 0.8, 1.0];
      return Color.lerp(colors.card2, colors.teal, stops[level - 1])!;
    }

    String? monthLabelFor(int weekIndex) {
      final weekMonday = firstMonday.add(Duration(days: 7 * weekIndex));
      if (weekIndex == 0) return DateFormat.MMM(localeName).format(weekMonday);
      final prevMonday = weekMonday.subtract(const Duration(days: 7));
      if (weekMonday.month == prevMonday.month) return null;
      return DateFormat.MMM(localeName).format(weekMonday);
    }

    // Mon/Wed/Fri only (formatted from a real date of that weekday, via the
    // public DateFormat.E API rather than poking at ICU symbol tables) --
    // GitHub's own graph only labels every other row too; a label on all 7
    // rows crowds a column this narrow.
    String sideLabelFor(int weekday) {
      if (weekday != DateTime.monday && weekday != DateTime.wednesday && weekday != DateTime.friday) {
        return '';
      }
      final sample = firstMonday.add(Duration(days: weekday - DateTime.monday));
      return DateFormat.E(localeName).format(sample);
    }

    final weekColumns = <Widget>[];
    for (var w = 0; w < weeks; w++) {
      if (w > 0) weekColumns.add(const SizedBox(width: _gap));
      final dayCells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        if (d > 0) dayCells.add(const SizedBox(height: _gap));
        final day = firstMonday.add(Duration(days: 7 * w + d));
        if (day.isAfter(today)) {
          dayCells.add(const SizedBox(width: _cell, height: _cell));
          continue;
        }
        final level = levelFor(scoreFor(day));
        final isToday = _iso(day) == _iso(today);
        final isSelected = selectedDate != null && _iso(day) == _iso(selectedDate!);
        dayCells.add(GestureDetector(
          onTap: () => onSelectDate(day),
          child: Container(
            width: _cell,
            height: _cell,
            decoration: BoxDecoration(
              color: colorForLevel(level),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: isSelected
                    ? colors.accent
                    : (isToday ? colors.accent.withValues(alpha: 0.6) : Colors.transparent),
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
        ));
      }
      weekColumns.add(Column(children: dayCells));
    }

    final monthLabels = <Widget>[
      for (var w = 0; w < weeks; w++)
        SizedBox(
          width: _pitch,
          height: _monthLabelHeight,
          child: Text(
            monthLabelFor(w) ?? '',
            style: TextStyle(color: colors.mut, fontSize: 9, fontWeight: FontWeight.w600),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _monthLabelHeight),
              child: Column(
                children: [
                  for (var w = DateTime.monday; w <= DateTime.sunday; w++)
                    SizedBox(
                      height: w == DateTime.sunday ? _cell : _pitch,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          sideLabelFor(w),
                          style: TextStyle(color: colors.mut, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // Starts scrolled to the most recent week, same as opening
                // GitHub's own contribution graph -- the interesting part
                // (now) is on screen without the user having to swipe.
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: monthLabels),
                    Row(children: weekColumns),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var level = 0; level <= 4; level++) ...[
              Container(
                width: _cell,
                height: _cell,
                decoration: BoxDecoration(color: colorForLevel(level), borderRadius: BorderRadius.circular(3)),
              ),
              if (level < 4) const SizedBox(width: 3),
            ],
          ],
        ),
      ],
    );
  }
}
