import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/rest_days.dart';
import 'package:ironpeak_mobile/models/day.dart';
import 'package:ironpeak_mobile/models/program.dart';

Program _plan({String mode = 'weekday', List<bool> rest = const [false, true, false, true, false, true, true]}) =>
    Program(
      id: 'p1',
      name: 'Plan',
      mode: mode,
      startDate: '2026-08-01',
      days: [for (final (i, r) in rest.indexed) Day(label: 'D$i', rest: r)],
    );

void main() {
  // 2026-08-03 is a Monday.
  final monday = DateTime(2026, 8, 3);
  final tuesday = DateTime(2026, 8, 4);
  final wednesday = DateTime(2026, 8, 5);

  test("a weekday plan's rest days are its rest weekdays", () {
    final isRest = planRestDays(_plan(), overrideFor: (_, __) => null)!;
    expect(isRest(monday), isFalse);
    expect(isRest(tuesday), isTrue);
    expect(isRest(wednesday), isFalse);
    expect(isRest(DateTime(2026, 8, 9)), isTrue); // Sunday
  });

  test('date-scoped overrides count, as on the Training screen', () {
    final overrides = {
      '2026-08-03': -1, // Monday's day moved away: rest
      '2026-08-04': 0, // Tuesday does Monday's training day
    };
    final isRest = planRestDays(_plan(), overrideFor: (planId, iso) {
      expect(planId, 'p1');
      return overrides[iso];
    })!;
    expect(isRest(monday), isTrue);
    expect(isRest(tuesday), isFalse);
    expect(isRest(wednesday), isFalse);
  });

  test('rotation plans have no date-bound rest days', () {
    expect(planRestDays(_plan(mode: 'rotation'), overrideFor: (_, __) => null), isNull);
  });
}
