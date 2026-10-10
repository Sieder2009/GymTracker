import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/heatmap_engine.dart';
import 'package:ironpeak_mobile/models/workout_session.dart';

WorkoutSession _session(String date, {int minutes = 45, double volume = 0}) =>
    WorkoutSession(date: date, durationMinutes: minutes, planName: 'A', totalVolumeKg: volume);

/// 'YYYY-MM-DD' of the calendar day after [key], computed in UTC so the
/// expectation itself can't be thrown off by the machine's DST rules.
String _nextKey(String key) {
  final d = DateTime.parse('${key}T00:00:00Z');
  final next = DateTime.utc(d.year, d.month, d.day + 1);
  return '${next.year.toString().padLeft(4, '0')}-'
      '${next.month.toString().padLeft(2, '0')}-'
      '${next.day.toString().padLeft(2, '0')}';
}

List<HeatmapSlot> _drawn(HeatmapGrid grid) => grid.slots.where((s) => s.inRange).toList();

void main() {
  final today = DateTime(2026, 10, 9); // a Friday

  group('DST-safe grid', () {
    // The rolling window ending 2026-04-15 spans both the 2025-10-26
    // fall-back and the 2026-03-29 spring-forward in CET/CEST. Stepping
    // local midnights with `.add(Duration(days: 1))` -- the old widget's
    // approach -- produces a duplicated date after the fall-back on such a
    // machine; calendar arithmetic must not.
    for (final firstDay in [0, 1]) {
      test('every slot is exactly one calendar day after the previous one (firstDay=$firstDay)', () {
        final grid = HeatmapGrid(
          range: const HeatmapRange.lastYear(),
          firstDayOfWeekIndex: firstDay,
          today: DateTime(2026, 4, 15),
        );
        expect(grid.weekCount, 53);
        expect(grid.slots, hasLength(371));

        final keys = grid.slots.map((s) => s.key).toList();
        expect(keys.toSet(), hasLength(keys.length), reason: 'no date may appear twice');
        for (var i = 1; i < keys.length; i++) {
          expect(keys[i], _nextKey(keys[i - 1]), reason: 'slot $i');
        }
        for (var i = 0; i < grid.slots.length; i++) {
          final slot = grid.slots[i];
          expect(slot.date.hour, 0, reason: '${slot.key} must stay at local midnight');
          expect(grid.rowOfWeekday(slot.date.weekday), i % 7, reason: '${slot.key} sits in the wrong weekday row');
        }
        expect(keys, containsAll(['2025-10-25', '2025-10-26', '2025-10-27', '2026-03-29', '2026-03-30']));
      });
    }

    test('calendarDaysBetween counts the 23h/25h DST nights as one day', () {
      expect(calendarDaysBetween(DateTime(2026, 3, 29), DateTime(2026, 3, 30)), 1);
      expect(calendarDaysBetween(DateTime(2025, 10, 26), DateTime(2025, 10, 27)), 1);
      expect(calendarDaysBetween(DateTime(2025, 10, 1), DateTime(2026, 4, 1)), 182);
      expect(addCalendarDays(DateTime(2025, 10, 25), 2), DateTime(2025, 10, 27));
    });

    test('the rolling range draws exactly the last 365 days, ending today', () {
      final grid = HeatmapGrid(range: const HeatmapRange.lastYear(), firstDayOfWeekIndex: 1, today: today);
      final drawn = _drawn(grid);
      expect(drawn, hasLength(kHeatmapRollingDays));
      expect(drawn.first.key, '2025-10-10');
      expect(drawn.last.key, '2026-10-09');
      // Future days of the current week exist as slots but stay blank.
      expect(grid.slots.last.key, '2026-10-11');
      expect(grid.slots.last.inRange, isFalse);
      expect(grid.lastDrawnColumn, 52);
    });

    test('indexOf finds a date across a DST change and rejects dates outside', () {
      final grid = HeatmapGrid(range: const HeatmapRange.lastYear(), firstDayOfWeekIndex: 1, today: today);
      final i = grid.indexOf(DateTime(2026, 3, 30))!;
      expect(grid.slots[i].key, '2026-03-30');
      expect(grid.indexOf(DateTime(2024, 1, 1)), isNull);
      expect(grid.indexOf(DateTime(2027, 1, 1)), isNull);
    });
  });

  group('aggregateHeatmapDays', () {
    test('sums sessions per day and normalizes the stored date', () {
      final days = aggregateHeatmapDays([
        _session('2026-10-05', minutes: 40, volume: 1000),
        _session('2026-10-05T18:30:00', minutes: 20, volume: 500),
        _session('2026-10-06', minutes: 30),
        _session('not a date'),
      ]);
      expect(days.keys, unorderedEquals(['2026-10-05', '2026-10-06']));
      expect(days['2026-10-05']!.sessionCount, 2);
      expect(days['2026-10-05']!.minutes, 60);
      expect(days['2026-10-05']!.volumeKg, 1500);
      expect(days['2026-10-06']!.valueOf(HeatmapMetric.volume), 0);
      expect(days['2026-10-06']!.valueOf(HeatmapMetric.duration), 30);
    });
  });

  group('quartile levels', () {
    HeatmapLevels levelsFor(List<WorkoutSession> sessions, HeatmapMetric metric) => computeHeatmapLevels(
          aggregateHeatmapDays(sessions),
          range: const HeatmapRange.lastYear(),
          metric: metric,
          today: today,
        );

    test('levels follow the quartiles of the trained days in range', () {
      final sessions = [
        _session('2026-10-01', volume: 100),
        _session('2026-10-02', volume: 200),
        _session('2026-10-03', volume: 300),
        _session('2026-10-04', volume: 400),
        _session('2026-10-05', volume: 0), // bodyweight/cardio day
      ];
      final days = aggregateHeatmapDays(sessions);
      final levels = levelsFor(sessions, HeatmapMetric.volume);
      // sorted [100, 200, 300, 400]: q(.25)=s[1], q(.5)=s[2], q(.75)=s[3]
      expect(levels.thresholds, [200, 300, 400]);
      expect(levels.levelOf(days['2026-10-01']), 1);
      expect(levels.levelOf(days['2026-10-02']), 2);
      expect(levels.levelOf(days['2026-10-03']), 3);
      expect(levels.levelOf(days['2026-10-04']), 4);
      expect(levels.levelOf(days['2026-10-05']), 1, reason: 'trained but no volume is still level 1');
      expect(levels.levelOf(days['2026-10-06']), 0, reason: 'no session');
      expect(levels.levelOf(null), 0);
    });

    test('one heavy outlier no longer washes every other day out', () {
      final sessions = [
        for (final (i, v) in [100.0, 110.0, 120.0, 130.0, 10000.0].indexed)
          _session('2026-09-${(10 + i).toString()}', volume: v),
      ];
      final days = aggregateHeatmapDays(sessions);
      final levels = levelsFor(sessions, HeatmapMetric.volume);
      expect([for (var d = 10; d <= 14; d++) levels.levelOf(days['2026-09-$d'])], [1, 2, 3, 4, 4]);
    });

    test('the duration metric ranks by minutes instead of volume', () {
      final sessions = [
        _session('2026-10-01', minutes: 90, volume: 100),
        _session('2026-10-02', minutes: 30, volume: 5000),
      ];
      final days = aggregateHeatmapDays(sessions);
      final levels = levelsFor(sessions, HeatmapMetric.duration);
      expect(levels.levelOf(days['2026-10-01']), 4);
      expect(levels.levelOf(days['2026-10-02']), 2);
    });

    test('a single trained day is the darkest shade', () {
      final sessions = [_session('2026-10-01', volume: 750)];
      final levels = levelsFor(sessions, HeatmapMetric.volume);
      expect(levels.thresholds, [750, 750, 750]);
      expect(levels.levelOf(aggregateHeatmapDays(sessions)['2026-10-01']), 4);
    });

    test('only zero-value days: every trained day is level 1', () {
      final sessions = [_session('2026-10-01'), _session('2026-10-02')];
      final days = aggregateHeatmapDays(sessions);
      final levels = levelsFor(sessions, HeatmapMetric.volume);
      expect(levels.thresholds, isEmpty);
      expect(levels.levelOf(days['2026-10-01']), 1);
      expect(levels.levelOf(days['2026-10-02']), 1);
    });

    test('empty history: no thresholds, everything level 0', () {
      final levels = levelsFor(const [], HeatmapMetric.volume);
      expect(levels.thresholds, isEmpty);
      expect(levels.levelOf(null), 0);
      final grid = HeatmapGrid(range: const HeatmapRange.lastYear(), today: today);
      final cells = grid.cellLevels(const {}, levels);
      expect(cells.where((l) => l > 0), isEmpty);
      expect(cells.where((l) => l == 0), hasLength(kHeatmapRollingDays));
      expect(cells.where((l) => l < 0), hasLength(371 - kHeatmapRollingDays));
    });

    test('days outside the range do not move the thresholds', () {
      final sessions = [
        _session('2024-05-01', volume: 99999), // long before the rolling window
        _session('2026-10-01', volume: 100),
        _session('2026-10-02', volume: 200),
      ];
      final levels = levelsFor(sessions, HeatmapMetric.volume);
      expect(levels.thresholds, [100, 200, 200]);
    });
  });

  group('year range', () {
    test('a past year draws Jan 1 to Dec 31 and blanks the padding around it', () {
      final grid = HeatmapGrid(range: const HeatmapRange.year(2025), firstDayOfWeekIndex: 1, today: today);
      final drawn = _drawn(grid);
      expect(drawn, hasLength(365));
      expect(drawn.first.key, '2025-01-01');
      expect(drawn.last.key, '2025-12-31');
      // 2025-01-01 is a Wednesday: Monday-first, Mon/Tue of that week are
      // last year's days and stay blank.
      expect(grid.slotAt(0, 0).key, '2024-12-30');
      expect(grid.slotAt(0, 0).inRange, isFalse);
      expect(grid.slotAt(0, 2).key, '2025-01-01');
      expect(grid.slots.last.inRange, isFalse); // 2026-01-04, padding after Dec 31
      expect(grid.weekCount, 53);
      expect(grid.lastDrawnColumn, grid.weekCount - 1);
    });

    test('the running year spans the whole year but stops drawing at today', () {
      final grid = HeatmapGrid(range: const HeatmapRange.year(2026), firstDayOfWeekIndex: 1, today: today);
      final drawn = _drawn(grid);
      expect(drawn.first.key, '2026-01-01');
      expect(drawn.last.key, '2026-10-09');
      expect(grid.slots.firstWhere((s) => s.key == '2026-10-10').inRange, isFalse);
      expect(grid.slots.any((s) => s.key == '2026-12-31'), isTrue);
      expect(grid.lastDrawnColumn, lessThan(grid.weekCount - 1));
    });

    test('a leap year starting on the last row needs 54 columns', () {
      // 2028-01-01 is a Saturday (last row when weeks start on Sunday);
      // 2040-01-01 is a Sunday (last row when weeks start on Monday).
      final sundayFirst = HeatmapGrid(
          range: const HeatmapRange.year(2028), firstDayOfWeekIndex: 0, today: DateTime(2029, 6, 1));
      expect(sundayFirst.weekCount, 54);
      expect(_drawn(sundayFirst), hasLength(366));
      expect(sundayFirst.slotAt(0, 6).key, '2028-01-01');
      expect(sundayFirst.slotAt(53, 0).key, '2028-12-31');

      final mondayFirst = HeatmapGrid(
          range: const HeatmapRange.year(2040), firstDayOfWeekIndex: 1, today: DateTime(2041, 6, 1));
      expect(mondayFirst.weekCount, 54);
      // The same year Sunday-first fits in 53.
      expect(
          HeatmapGrid(range: const HeatmapRange.year(2040), firstDayOfWeekIndex: 0, today: DateTime(2041, 6, 1))
              .weekCount,
          53);
    });

    test('a year that has not started draws nothing', () {
      final grid = HeatmapGrid(range: const HeatmapRange.year(2027), today: today);
      expect(_drawn(grid), isEmpty);
      expect(grid.lastDrawnColumn, grid.weekCount - 1);
    });
  });

  group('first day of week', () {
    test('Sunday-first (GitHub/en-US) puts Mon/Wed/Fri on rows 1/3/5', () {
      final grid = HeatmapGrid(range: const HeatmapRange.lastYear(), firstDayOfWeekIndex: 0, today: today);
      expect(grid.rowOfWeekday(DateTime.sunday), 0);
      expect(grid.rowOfWeekday(DateTime.monday), 1);
      expect(grid.rowOfWeekday(DateTime.wednesday), 3);
      expect(grid.rowOfWeekday(DateTime.friday), 5);
      expect(grid.slotAt(52, 0).key, '2026-10-04'); // the Sunday starting today's week
      expect(grid.slotAt(52, 5).key, '2026-10-09'); // today, a Friday
      expect(grid.slotAt(52, 6).inRange, isFalse); // tomorrow
    });

    test('Monday-first (de) puts Mon/Wed/Fri on rows 0/2/4', () {
      final grid = HeatmapGrid(range: const HeatmapRange.lastYear(), firstDayOfWeekIndex: 1, today: today);
      expect(grid.rowOfWeekday(DateTime.monday), 0);
      expect(grid.rowOfWeekday(DateTime.wednesday), 2);
      expect(grid.rowOfWeekday(DateTime.friday), 4);
      expect(grid.rowOfWeekday(DateTime.sunday), 6);
      expect(grid.slotAt(52, 0).key, '2026-10-05');
      expect(grid.slotAt(52, 4).key, '2026-10-09');
    });

    test('Saturday-first works too', () {
      final grid = HeatmapGrid(range: const HeatmapRange.lastYear(), firstDayOfWeekIndex: 6, today: today);
      expect(grid.rowOfWeekday(DateTime.saturday), 0);
      expect(grid.slotAt(52, 0).key, '2026-10-03');
      expect(grid.slotAt(52, 6).key, '2026-10-09');
    });
  });

  group('month labels', () {
    test('label the first drawn column and every column starting a new month', () {
      final grid = HeatmapGrid(range: const HeatmapRange.lastYear(), firstDayOfWeekIndex: 1, today: today);
      final starts = grid.monthStarts();
      // Column 0 starts Mon 2025-10-06 but only draws from 2025-10-10.
      expect(starts.first.column, 0);
      expect(starts.first.month, DateTime(2025, 10));
      // First Monday in November 2025 is the 3rd -> column 4.
      expect(starts[1].column, 4);
      expect(starts[1].month, DateTime(2025, 11));
      expect(starts.last.month, DateTime(2026, 10));
      expect(starts, hasLength(13));
    });

    test('a narrower window labels its own first column', () {
      final grid = HeatmapGrid(range: const HeatmapRange.lastYear(), firstDayOfWeekIndex: 1, today: today);
      final starts = grid.monthStarts(firstColumn: 40);
      expect(starts.first.column, 40);
    });
  });

  group('header counts', () {
    final sessions = [
      _session('2026-10-09', minutes: 60, volume: 1000), // today
      _session('2026-10-09', minutes: 30, volume: 500), // second session, same day
      _session('2025-10-10', minutes: 45), // 364 days ago: still inside
      _session('2025-10-09', minutes: 50), // 365 days ago: outside
      _session('2026-10-10', minutes: 99), // tomorrow: never counted
      _session('2025-03-01', minutes: 40),
      _session('2023-06-01', minutes: 40),
    ];
    final days = aggregateHeatmapDays(sessions);

    test('rolling range counts the last 365 days only', () {
      final summary = summarizeHeatmap(days, range: const HeatmapRange.lastYear(), today: today);
      expect(summary.sessionCount, 3);
      expect(summary.trainingDays, 2);
      expect(summary.totalMinutes, 135);
      expect(summary.totalVolumeKg, 1500);
    });

    test('a year range counts that calendar year up to today', () {
      final y2025 = summarizeHeatmap(days, range: const HeatmapRange.year(2025), today: today);
      expect(y2025.sessionCount, 3);
      expect(y2025.trainingDays, 3);
      expect(y2025.totalMinutes, 135);

      final y2026 = summarizeHeatmap(days, range: const HeatmapRange.year(2026), today: today);
      expect(y2026.sessionCount, 2, reason: "tomorrow's session is not counted yet");
      expect(y2026.trainingDays, 1);
    });

    test('empty history counts zero', () {
      final summary = summarizeHeatmap(const {}, range: const HeatmapRange.lastYear(), today: today);
      expect(summary.sessionCount, 0);
      expect(summary.trainingDays, 0);
      expect(summary.totalMinutes, 0);
    });

    test('year list: years with sessions plus the current one, newest first', () {
      expect(heatmapYears(days, today: today), [2026, 2025, 2023]);
      expect(heatmapYears(const {}, today: today), [2026]);
      expect(heatmapYears(aggregateHeatmapDays([_session('2030-01-01')]), today: today), [2026]);
    });

    test('heatmapRangeFor picks the rolling year while the date is inside it', () {
      expect(heatmapRangeFor(DateTime(2026, 1, 15), today: today), const HeatmapRange.lastYear());
      expect(heatmapRangeFor(DateTime(2025, 10, 10), today: today), const HeatmapRange.lastYear());
      expect(heatmapRangeFor(DateTime(2025, 10, 9), today: today), const HeatmapRange.year(2025));
      expect(heatmapRangeFor(DateTime(2023, 6, 1), today: today), const HeatmapRange.year(2023));
    });
  });
}
