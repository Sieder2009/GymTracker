import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ironpeak_mobile/widgets/streak_flame.dart';

void main() {
  test('the flame grows with the streak and tops out at 60 days', () {
    expect(StreakFlame.sizeFor(0), 18);
    var previous = StreakFlame.sizeFor(0);
    for (final days in [1, 3, 7, 14, 30, 59]) {
      final size = StreakFlame.sizeFor(days);
      expect(size, greaterThan(previous), reason: '$days days');
      previous = size;
    }
    expect(StreakFlame.sizeFor(60), closeTo(40, 1e-9));
    expect(StreakFlame.sizeFor(365), closeTo(40, 1e-9));
  });

  testWidgets('an unlit flame stands still, a lit one flickers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: StreakFlame(days: 0))));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(const MaterialApp(home: Center(child: StreakFlame(days: 12))));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.hasRunningAnimations, isTrue);
    expect(tester.getSize(find.byType(CustomPaint).last).height, closeTo(StreakFlame.sizeFor(12), 0.5));
  });
}
