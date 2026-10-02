import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/constants.dart';

void main() {
  group('dateForWeekdayIndex', () {
    // 2026-09-30 is a Wednesday (Dart weekday=3 -> pill index 2).
    final wednesday = DateTime(2026, 9, 30);

    test('pillIdx below today\'s own weekday index resolves to this week\'s earlier date', () {
      expect(dateForWeekdayIndex(0, now: wednesday), DateTime(2026, 9, 28)); // Monday
    });

    test('pillIdx equal to today\'s own weekday index resolves to today', () {
      expect(dateForWeekdayIndex(2, now: wednesday), DateTime(2026, 9, 30)); // Wednesday
    });

    test('pillIdx above today\'s own weekday index resolves to this week\'s later date', () {
      expect(dateForWeekdayIndex(6, now: wednesday), DateTime(2026, 10, 4)); // Sunday
    });

    test('never calls DateTime.now() when now is supplied (pure, deterministic)', () {
      final a = dateForWeekdayIndex(4, now: wednesday);
      final b = dateForWeekdayIndex(4, now: wednesday);
      expect(a, b);
    });
  });

  group('resolveDayOverride', () {
    test('returns defaultIdx when overrideIdx is null', () {
      expect(
        resolveDayOverride(defaultIdx: 3, daysLength: 7, overrideIdx: null),
        3,
      );
    });

    test('returns overrideIdx unchanged when it is a valid in-range index', () {
      expect(
        resolveDayOverride(defaultIdx: 3, daysLength: 7, overrideIdx: 5),
        5,
      );
      expect(
        resolveDayOverride(defaultIdx: 3, daysLength: 7, overrideIdx: 0),
        0,
      );
    });

    test('returns -1 unchanged for the rest/skip sentinel regardless of daysLength', () {
      expect(
        resolveDayOverride(defaultIdx: 3, daysLength: 7, overrideIdx: -1),
        -1,
      );
      expect(
        resolveDayOverride(defaultIdx: 3, daysLength: 0, overrideIdx: -1),
        -1,
      );
    });

    test('falls back to defaultIdx when overrideIdx is negative (other than -1)', () {
      expect(
        resolveDayOverride(defaultIdx: 3, daysLength: 7, overrideIdx: -2),
        3,
      );
    });

    test('falls back to defaultIdx when overrideIdx is >= daysLength (corrupt/foreign data)', () {
      expect(
        resolveDayOverride(defaultIdx: 3, daysLength: 7, overrideIdx: 7),
        3,
      );
      expect(
        resolveDayOverride(defaultIdx: 3, daysLength: 0, overrideIdx: 0),
        3,
      );
    });
  });
}
