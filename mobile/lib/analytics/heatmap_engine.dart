import '../data/constants.dart' show isoOf;
import '../models/workout_session.dart';

/// Pure date/aggregation logic behind the GitHub-style training heatmap
/// (`widgets/contribution_heatmap.dart`, `screens/calendar_screen.dart`) --
/// no Flutter imports and `today` injectable everywhere, so every rule here
/// is unit-tested in isolation (`test/heatmap_engine_test.dart`).
///
/// Calendar dates are local-midnight [DateTime]s and are only ever stepped
/// with `DateTime(y, m, d + n)`. Never `.add(Duration(days: n))` and never
/// `.difference(...).inDays`: across a DST change a calendar day is 23 or 25
/// hours long, so on a CET/CEST device duration arithmetic lands on 23:00 of
/// the previous day after the October fall-back (one date drawn twice,
/// another never), and `inDays` reads the 23-hour spring-forward night as 0
/// days. Range membership is decided on ISO 'YYYY-MM-DD' keys instead, which
/// sort lexicographically exactly like the dates they spell.

/// How many days the rolling "last 12 months" view covers (today included)
/// -- also the window behind every "N workouts in the last year" count.
const int kHeatmapRollingDays = 365;

/// What a day's shade is based on.
enum HeatmapMetric { volume, duration }

/// One slice of history a heatmap can show: GitHub's default rolling year,
/// or one calendar year (GitHub's year list).
class HeatmapRange {
  /// The last [kHeatmapRollingDays] days, ending today.
  const HeatmapRange.lastYear() : year = null;

  /// January 1 to December 31 of [year] (never past today).
  const HeatmapRange.year(int this.year);

  /// Null for the rolling range.
  final int? year;

  bool get isLastYear => year == null;

  /// First day this range draws -- the single source of truth (together
  /// with [lastDay]) for which cells are drawn, which days feed the shade
  /// thresholds, and what the header counts.
  DateTime firstDay(DateTime today) {
    final y = year;
    if (y == null) {
      final t = heatmapDateOnly(today);
      return addCalendarDays(t, -(kHeatmapRollingDays - 1));
    }
    return DateTime(y, 1, 1);
  }

  /// Last day this range draws: today for the rolling range, otherwise
  /// December 31 -- or today, while that year is still running. Days after
  /// today are never drawn, like GitHub.
  DateTime lastDay(DateTime today) {
    final t = heatmapDateOnly(today);
    final y = year;
    if (y == null) return t;
    final end = DateTime(y, 12, 31);
    return isoOf(end).compareTo(isoOf(t)) <= 0 ? end : t;
  }

  /// Last day the grid's columns reach. Differs from [lastDay] only for the
  /// running year, whose grid still spans the whole year (future days stay
  /// blank) so its shape matches every other year's.
  DateTime spanEnd(DateTime today) {
    final y = year;
    return y == null ? heatmapDateOnly(today) : DateTime(y, 12, 31);
  }

  @override
  bool operator ==(Object other) => other is HeatmapRange && other.year == year;

  @override
  int get hashCode => year.hashCode;

  @override
  String toString() => year == null ? 'HeatmapRange.lastYear()' : 'HeatmapRange.year($year)';
}

/// Local midnight of [d]'s calendar date.
DateTime heatmapDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] moved by [days] calendar days -- DST-proof, unlike `d.add(Duration)`.
DateTime addCalendarDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Whole calendar days from [from] to [to] (negative when [to] is earlier).
/// Measured between the UTC midnights of the two dates, where every day is
/// exactly 24 hours, so a DST change in between can't shave an hour off and
/// round the result down.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Canonical ISO key ('YYYY-MM-DD') for a stored session date, or null when
/// it doesn't parse. Rebuilt from the parsed year/month/day so a stray time
/// suffix can't split one day into two keys.
String? heatmapDateKey(String raw) {
  final parsed = DateTime.tryParse(raw.trim());
  return parsed == null ? null : isoOf(parsed);
}

/// Everything logged on one calendar day.
class HeatmapDay {
  const HeatmapDay({this.sessionCount = 0, this.minutes = 0, this.volumeKg = 0});

  final int sessionCount;
  final int minutes;
  final double volumeKg;

  /// The number a day's shade is ranked by.
  double valueOf(HeatmapMetric metric) => switch (metric) {
        HeatmapMetric.volume => volumeKg,
        HeatmapMetric.duration => minutes.toDouble(),
      };
}

/// Per-day totals keyed by ISO date. Sessions whose date doesn't parse are
/// skipped rather than guessed onto some day.
Map<String, HeatmapDay> aggregateHeatmapDays(Iterable<WorkoutSession> sessions) {
  final totals = <String, HeatmapDay>{};
  for (final s in sessions) {
    final key = heatmapDateKey(s.date);
    if (key == null) continue;
    final prev = totals[key];
    totals[key] = HeatmapDay(
      sessionCount: (prev?.sessionCount ?? 0) + 1,
      minutes: (prev?.minutes ?? 0) + s.durationMinutes,
      volumeKg: (prev?.volumeKg ?? 0) + s.totalVolumeKg,
    );
  }
  return totals;
}

/// One cell position of a [HeatmapGrid].
class HeatmapSlot {
  const HeatmapSlot({required this.date, required this.key, required this.inRange});

  /// Local midnight of the slot's calendar date.
  final DateTime date;

  /// [date] as 'YYYY-MM-DD'.
  final String key;

  /// False for padding before the range starts and for days after it ends
  /// (including every day after today) -- those cells stay blank.
  final bool inRange;
}

/// A month label's anchor: the column it sits above.
class HeatmapMonthStart {
  const HeatmapMonthStart({required this.column, required this.month});

  final int column;

  /// First day of the labelled month.
  final DateTime month;
}

/// Geometry of a GitHub-style contribution grid: one column per week, one
/// row per weekday starting at [firstDayOfWeekIndex].
///
/// [slots] holds every position, blanks included, column by column
/// (`index = column * 7 + row`), each exactly one calendar day after the
/// previous one.
class HeatmapGrid {
  HeatmapGrid._({
    required this.range,
    required this.firstDayOfWeekIndex,
    required this.today,
    required this.start,
    required this.weekCount,
    required this.firstKey,
    required this.lastKey,
    required this.slots,
  });

  /// [firstDayOfWeekIndex] uses Flutter's
  /// `MaterialLocalizations.firstDayOfWeekIndex` convention: 0 = Sunday
  /// (GitHub, en-US) ... 6 = Saturday; 1 = Monday for German.
  factory HeatmapGrid({
    required HeatmapRange range,
    int firstDayOfWeekIndex = 0,
    DateTime? today,
  }) {
    assert(firstDayOfWeekIndex >= 0 && firstDayOfWeekIndex <= 6);
    final t = heatmapDateOnly(today ?? DateTime.now());
    final firstDay = range.firstDay(t);
    final lastDay = range.lastDay(t);
    final spanEnd = range.spanEnd(t);

    int rowOf(DateTime d) => _rowOf(d.weekday, firstDayOfWeekIndex);
    // The first column starts on the first weekday on/before the range's
    // first day; the last column is the week containing the span's end.
    final start = addCalendarDays(firstDay, -rowOf(firstDay));
    final slotCount = calendarDaysBetween(start, spanEnd) + 1;
    // Usually 53; 54 for a leap year whose Jan 1 falls on the last row
    // (e.g. 2028 Sunday-first) -- computed, never hardcoded.
    final weekCount = (slotCount + 6) ~/ 7;

    final firstKey = isoOf(firstDay);
    final lastKey = isoOf(lastDay);
    final slots = List<HeatmapSlot>.generate(weekCount * 7, (i) {
      final date = addCalendarDays(start, i);
      final key = isoOf(date);
      return HeatmapSlot(
        date: date,
        key: key,
        inRange: firstKey.compareTo(key) <= 0 && key.compareTo(lastKey) <= 0,
      );
    }, growable: false);

    return HeatmapGrid._(
      range: range,
      firstDayOfWeekIndex: firstDayOfWeekIndex,
      today: t,
      start: start,
      weekCount: weekCount,
      firstKey: firstKey,
      lastKey: lastKey,
      slots: slots,
    );
  }

  final HeatmapRange range;
  final int firstDayOfWeekIndex;

  /// Local midnight of the "today" this grid was built for.
  final DateTime today;

  /// Date of the top cell of the first column (often a blank slot).
  final DateTime start;
  final int weekCount;

  /// ISO keys of the first/last drawn day. [lastKey] sorts before
  /// [firstKey] when nothing is drawable (a year that hasn't started yet).
  final String firstKey;
  final String lastKey;
  final List<HeatmapSlot> slots;

  static int _rowOf(int weekday, int firstDayOfWeekIndex) =>
      // DateTime.weekday is Monday=1..Sunday=7; `% 7` turns it into
      // Flutter's Sunday=0..Saturday=6 so it lines up with the index.
      (weekday % 7 - firstDayOfWeekIndex + 7) % 7;

  /// The row a weekday (`DateTime.monday`..`DateTime.sunday`) lives in.
  int rowOfWeekday(int weekday) => _rowOf(weekday, firstDayOfWeekIndex);

  HeatmapSlot slotAt(int column, int row) => slots[column * 7 + row];

  /// Whether [isoKey] is one of the drawn days.
  bool containsKey(String isoKey) => firstKey.compareTo(isoKey) <= 0 && isoKey.compareTo(lastKey) <= 0;

  /// Slot index of [date], or null when it's outside the grid entirely.
  int? indexOf(DateTime date) {
    final i = calendarDaysBetween(start, date);
    return i >= 0 && i < slots.length ? i : null;
  }

  /// Column of the last drawn day (today, or Dec 31 of a past year) -- where
  /// a width-limited view should end. Falls back to the last column when
  /// nothing is drawn.
  int get lastDrawnColumn {
    for (var i = slots.length - 1; i >= 0; i--) {
      if (slots[i].inRange) return i ~/ 7;
    }
    return weekCount - 1;
  }

  /// Where month labels go within columns [firstColumn]..[lastColumn]: the
  /// first column there that draws anything, plus every column whose first
  /// drawn day is in a different month than the previous column's. A week
  /// that starts mid-month keeps the old month's label, as on GitHub.
  /// Whether a label actually fits is the widget's call (text width).
  List<HeatmapMonthStart> monthStarts({int firstColumn = 0, int? lastColumn}) {
    final last = lastColumn ?? weekCount - 1;
    final result = <HeatmapMonthStart>[];
    int? previousMonth;
    for (var c = firstColumn; c <= last; c++) {
      DateTime? firstDrawn;
      for (var r = 0; r < 7; r++) {
        final slot = slots[c * 7 + r];
        if (slot.inRange) {
          firstDrawn = slot.date;
          break;
        }
      }
      if (firstDrawn == null) continue;
      final month = firstDrawn.year * 12 + firstDrawn.month;
      if (month != previousMonth) {
        result.add(HeatmapMonthStart(column: c, month: DateTime(firstDrawn.year, firstDrawn.month)));
      }
      previousMonth = month;
    }
    return result;
  }

  /// The shade level of every slot (-1 for blank slots), precomputed once
  /// per build so painting is a plain list lookup.
  List<int> cellLevels(Map<String, HeatmapDay> days, HeatmapLevels levels) => [
        for (final slot in slots) slot.inRange ? levels.levelOf(days[slot.key]) : -1,
      ];
}

/// GitHub-style shade thresholds: quartiles of the metric over every day
/// in the range that has at least one session and a positive value.
///
/// Ranking by quartile (instead of the old "share of the single heaviest
/// day") means one outlier day no longer washes every other day out to the
/// palest green.
class HeatmapLevels {
  const HeatmapLevels({required this.metric, required this.thresholds});

  final HeatmapMetric metric;

  /// The 25th/50th/75th percentile values, ascending; empty when no day in
  /// the range has a positive value.
  final List<double> thresholds;

  /// 0 = no session; 1 = trained, but the value is 0 (e.g. a cardio or
  /// bodyweight day without volume) or below the first quartile; 2..4 = at
  /// or above the first/second/third quartile.
  int levelOf(HeatmapDay? day) {
    if (day == null || day.sessionCount <= 0) return 0;
    final value = day.valueOf(metric);
    if (thresholds.isEmpty || value <= 0) return 1;
    if (value >= thresholds[2]) return 4;
    if (value >= thresholds[1]) return 3;
    if (value >= thresholds[0]) return 2;
    return 1;
  }
}

/// [HeatmapLevels] for [range]. Thresholds always come from the whole range
/// -- never just the columns a narrow layout shows -- so the same day gets
/// the same shade on the Analytics card and in the calendar screen.
HeatmapLevels computeHeatmapLevels(
  Map<String, HeatmapDay> days, {
  required HeatmapRange range,
  required HeatmapMetric metric,
  DateTime? today,
}) {
  final t = heatmapDateOnly(today ?? DateTime.now());
  final firstKey = isoOf(range.firstDay(t));
  final lastKey = isoOf(range.lastDay(t));
  final values = <double>[];
  days.forEach((key, day) {
    if (key.compareTo(firstKey) < 0 || key.compareTo(lastKey) > 0) return;
    if (day.sessionCount <= 0) return;
    final value = day.valueOf(metric);
    if (value > 0) values.add(value);
  });
  if (values.isEmpty) return HeatmapLevels(metric: metric, thresholds: const []);
  values.sort();
  final n = values.length;
  double quantile(double p) {
    final i = (p * n).floor();
    return values[i < n - 1 ? i : n - 1];
  }

  return HeatmapLevels(metric: metric, thresholds: [quantile(0.25), quantile(0.5), quantile(0.75)]);
}

/// Header numbers for one range.
class HeatmapSummary {
  const HeatmapSummary({
    required this.sessionCount,
    required this.trainingDays,
    required this.totalMinutes,
    required this.totalVolumeKg,
  });

  final int sessionCount;

  /// Distinct days with at least one session.
  final int trainingDays;
  final int totalMinutes;
  final double totalVolumeKg;
}

/// Totals over exactly the days [range] draws: the last
/// [kHeatmapRollingDays] days for the rolling range, or the selected year
/// up to today -- independent of how many week columns a layout shows.
HeatmapSummary summarizeHeatmap(
  Map<String, HeatmapDay> days, {
  required HeatmapRange range,
  DateTime? today,
}) {
  final t = heatmapDateOnly(today ?? DateTime.now());
  final firstKey = isoOf(range.firstDay(t));
  final lastKey = isoOf(range.lastDay(t));
  var sessions = 0;
  var trainingDays = 0;
  var minutes = 0;
  var volume = 0.0;
  days.forEach((key, day) {
    if (key.compareTo(firstKey) < 0 || key.compareTo(lastKey) > 0) return;
    if (day.sessionCount <= 0) return;
    sessions += day.sessionCount;
    trainingDays += 1;
    minutes += day.minutes;
    volume += day.volumeKg;
  });
  return HeatmapSummary(
    sessionCount: sessions,
    trainingDays: trainingDays,
    totalMinutes: minutes,
    totalVolumeKg: volume,
  );
}

/// The calendar years to offer next to "last 12 months", newest first:
/// every year with a logged session plus the current one. Years after the
/// current one are left out -- their days are never drawn anyway.
List<int> heatmapYears(Map<String, HeatmapDay> days, {DateTime? today}) {
  final currentYear = (today ?? DateTime.now()).year;
  final years = <int>{currentYear};
  for (final key in days.keys) {
    final year = int.tryParse(key.substring(0, 4));
    if (year != null && year <= currentYear) years.add(year);
  }
  return years.toList()..sort((a, b) => b.compareTo(a));
}

/// The range that shows [date]: the rolling year while [date] is inside it,
/// otherwise [date]'s calendar year.
HeatmapRange heatmapRangeFor(DateTime date, {DateTime? today}) {
  final t = heatmapDateOnly(today ?? DateTime.now());
  const rolling = HeatmapRange.lastYear();
  return isoOf(date).compareTo(isoOf(rolling.firstDay(t))) >= 0 ? rolling : HeatmapRange.year(date.year);
}
