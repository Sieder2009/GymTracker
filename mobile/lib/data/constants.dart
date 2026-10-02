import 'package:intl/intl.dart';

/// German day names, matching the "1. Wochentag".."7. Wochentag" headers
/// the hand-typed log format uses (see `services/log_parser.dart`). These
/// stay German regardless of the UI language, same as the log format
/// itself: a plan's `Day.label` is persisted data, produced either here
/// (new weekday-mode plan) or by the log parser, not re-derived from the
/// active locale at render time. [kWeekdaysShort] below is index-based
/// display-only (the day-pill row), so THAT one is localized normally.
const List<String> kWeekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

const List<String> kWeekdaysShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

final NumberFormat _deFmt = NumberFormat.decimalPattern('de_DE');
final NumberFormat _deFmt1 = NumberFormat('0.0', 'de_DE');

/// German-locale number formatting (comma decimal separator), pendant to the
/// original `n.toLocaleString('de-DE')`.
String fmt(num n) => _deFmt.format(n);

/// Same as [fmt] but always shows exactly one decimal place.
String fmt1(num n) => _deFmt1.format(n);

/// Weekday-mode "today" index (0=Montag..6=Sonntag); falls back to the given
/// rotation-mode `currentDayIdx` when `mode != 'weekday'`.
int todayIndexForProgram({required String mode, required int currentDayIdx}) {
  if (mode == 'weekday') {
    // JS Date.getDay(): Sun=0..Sat=6, mapped via (js+6)%7 -> Mon=0..Sun=6.
    final jsWeekday = DateTime.now().weekday % 7; // Dart Mon=1..Sun=7 -> Sun=0..Sat=6
    return (jsWeekday + 6) % 7;
  }
  return currentDayIdx;
}

/// Whole days elapsed since an ISO 'YYYY-MM-DD' date string (floor, min 0).
int daysSince(String isoDate) {
  final start = DateTime.parse(isoDate);
  final startMidnight = DateTime(start.year, start.month, start.day);
  final now = DateTime.now();
  final nowMidnight = DateTime(now.year, now.month, now.day);
  final diff = nowMidnight.difference(startMidnight).inDays;
  return diff < 0 ? 0 : diff;
}

/// Generic 'YYYY-MM-DD' formatter for any [DateTime] -- [todayIso] delegates
/// to this for `DateTime.now()`.
String isoOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Today's date as 'YYYY-MM-DD'.
String todayIso() => isoOf(DateTime.now());

/// The concrete calendar date for "this week's" Monday+[pillIdx] weekday-
/// mode Day-pill index (0=Mon..6=Sun) -- e.g. on a Wednesday `now`,
/// pillIdx=2 resolves to that same Wednesday's date and pillIdx=0 resolves
/// to that week's Monday, whatever today actually is. [now] is injectable
/// for pure testing -- unlike [todayIndexForProgram], this never calls
/// `DateTime.now()` when [now] is supplied.
///
/// Used to resolve a per-date [dayOverride] (see `TrainStateProvider`):
/// a weekday-mode pill index only means something once it's pinned to an
/// actual calendar date.
DateTime dateForWeekdayIndex(int pillIdx, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final todayIdx = today.weekday - 1; // Dart Mon=1..Sun=7 -> Mon=0..Sun=6
  // DateTime's constructor normalizes an out-of-range day component (e.g.
  // day 0 or negative), landing on the correct date across a month or DST
  // boundary -- Duration-based `.subtract`/`.add` arithmetic in local time
  // can be off by an hour right around a DST change.
  return DateTime(today.year, today.month, today.day - todayIdx + pillIdx);
}

/// Resolves the actual Day index to show for a weekday-mode plan, given its
/// normal weekday default and any date-scoped override (see
/// `TrainStateProvider.dayOverride`). `null` -> [defaultIdx] (no override
/// for this date); `-1` -> `-1` unchanged (explicitly rest/skipped this
/// date -- a moved-away day); an in-range index -> that index unchanged;
/// anything else (negative other than -1, or >= [daysLength]) falls back to
/// [defaultIdx] rather than ever handing a caller an index it could use to
/// read past the end of `days` -- defends against a hand-edited/foreign
/// backup, since nothing on disk enforces that a stored override still fits
/// its plan's current day count.
int resolveDayOverride({
  required int defaultIdx,
  required int daysLength,
  int? overrideIdx,
}) {
  if (overrideIdx == null) return defaultIdx;
  if (overrideIdx == -1) return -1;
  if (overrideIdx >= 0 && overrideIdx < daysLength) return overrideIdx;
  return defaultIdx;
}

/// Today's date as an unpadded 'D.M' label, used when appending a new
/// entry to a lift's history.
String todayShortLabel() {
  final now = DateTime.now();
  return '${now.day}.${now.month}';
}

/// ISO 'YYYY-MM-DD' -> 'DD.MM.YYYY', used for displaying PR dates.
String fmtDate(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}
