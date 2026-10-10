import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/heatmap_engine.dart';
import 'package:ironpeak_mobile/l10n/app_localizations.dart';
import 'package:ironpeak_mobile/models/workout_session.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:ironpeak_mobile/widgets/contribution_heatmap.dart';

final _today = DateTime(2026, 10, 9); // a Friday

final _days = aggregateHeatmapDays([
  WorkoutSession(date: '2026-10-05', durationMinutes: 50, planName: 'Push', totalVolumeKg: 5000),
  WorkoutSession(date: '2026-10-05', durationMinutes: 20, planName: 'Core'),
  WorkoutSession(date: '2026-10-07', durationMinutes: 45, planName: 'Pull', totalVolumeKg: 3000),
]);

// Mirrors the widget's geometry: 11px cells on a 14px pitch, inset by the
// 2.5px selection-ring padding.
const double _pitch = 14;
const double _inset = 2.5;
const double _halfCell = 5.5;

Widget _host(Widget child, {Locale locale = const Locale('en'), double width = 320}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
    );

Finder get _grid => find.byKey(ContributionHeatmap.gridKey);

/// Number of week columns the painted grid shows.
int _shownColumns(WidgetTester tester) => ((tester.getSize(_grid).width - 2 * _inset + 3) / _pitch).round();

/// Global centre of the cell at [column] (counted within the shown columns)
/// and [row].
Offset _cell(WidgetTester tester, int column, int row) =>
    tester.getTopLeft(_grid) + Offset(_inset + column * _pitch + _halfCell, _inset + row * _pitch + _halfCell);

void main() {
  testWidgets('fitToWidth shows the newest weeks that fit, without scrolling', (tester) async {
    final selected = <DateTime>[];
    await tester.pumpWidget(_host(ContributionHeatmap(
      days: _days,
      layout: HeatmapLayout.fitToWidth,
      onSelectDate: selected.add,
      today: _today,
    )));

    expect(find.descendant(of: find.byType(ContributionHeatmap), matching: find.byType(Scrollable)), findsNothing);
    final columns = _shownColumns(tester);
    expect(columns, inInclusiveRange(10, 30));
    expect(tester.getSize(_grid).width, lessThanOrEqualTo(320));

    // English weeks start on Sunday, so today (a Friday) is row 5 of the
    // last shown column.
    await tester.tapAt(_cell(tester, columns - 1, 5));
    expect(selected, [DateTime(2026, 10, 9)]);

    // Tomorrow is blank: tapping it does nothing.
    await tester.tapAt(_cell(tester, columns - 1, 6));
    expect(selected, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press shows a GitHub-style tooltip until released', (tester) async {
    await tester.pumpWidget(_host(ContributionHeatmap(days: _days, layout: HeatmapLayout.fitToWidth, today: _today)));
    final columns = _shownColumns(tester);

    // Monday 2026-10-05: row 1, last column.
    final press = await tester.startGesture(_cell(tester, columns - 1, 1));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('2 workouts on Oct 5, 2026'), findsOneWidget);

    // Dragging along updates it -- Tuesday had no workout.
    await press.moveBy(const Offset(0, _pitch));
    await tester.pump();
    expect(find.text('2 workouts on Oct 5, 2026'), findsNothing);
    expect(find.text('No workout on Oct 6, 2026'), findsOneWidget);

    await press.up();
    await tester.pump();
    expect(find.text('No workout on Oct 6, 2026'), findsNothing);
  });

  testWidgets('hovering with a mouse shows the tooltip, leaving hides it', (tester) async {
    await tester.pumpWidget(_host(ContributionHeatmap(days: _days, layout: HeatmapLayout.fitToWidth, today: _today)));
    final columns = _shownColumns(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(_cell(tester, columns - 1, 3)); // Wednesday 2026-10-07
    await tester.pump();
    expect(find.text('1 workout on Oct 7, 2026'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('1 workout on Oct 7, 2026'), findsNothing);
  });

  testWidgets('scrollable mode opens scrolled to the newest week', (tester) async {
    final selected = <DateTime>[];
    await tester.pumpWidget(_host(ContributionHeatmap(days: _days, onSelectDate: selected.add, today: _today)));

    expect(find.descendant(of: find.byType(ContributionHeatmap), matching: find.byType(Scrollable)), findsOneWidget);
    expect(_shownColumns(tester), 53);
    // The whole year is laid out, but the newest column is the one on screen.
    await tester.tapAt(_cell(tester, 52, 5));
    expect(selected, [DateTime(2026, 10, 9)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('German: Monday-first rows and localized labels', (tester) async {
    final selected = <DateTime>[];
    await tester.pumpWidget(_host(
      ContributionHeatmap(
        days: _days,
        layout: HeatmapLayout.fitToWidth,
        onSelectDate: selected.add,
        hint: 'Farbe = Trainingsvolumen des Tages',
        today: _today,
      ),
      locale: const Locale('de'),
    ));

    // Flutter's German date data abbreviates weekdays without a dot.
    for (final label in ['Mo', 'Mi', 'Fr', 'Weniger', 'Mehr', 'Farbe = Trainingsvolumen des Tages']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Di'), findsNothing);

    // Monday-first: Friday is row 4.
    await tester.tapAt(_cell(tester, _shownColumns(tester) - 1, 4));
    expect(selected, [DateTime(2026, 10, 9)]);
  });

  testWidgets('a cancelled long-press closes the tooltip', (tester) async {
    await tester.pumpWidget(_host(ContributionHeatmap(days: _days, layout: HeatmapLayout.fitToWidth, today: _today)));
    final press = await tester.startGesture(_cell(tester, _shownColumns(tester) - 1, 1));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('2 workouts on Oct 5, 2026'), findsOneWidget);

    await press.cancel();
    await tester.pump();
    expect(find.text('2 workouts on Oct 5, 2026'), findsNothing);
  });

  testWidgets('tooltips keep working after the range or layout branch changes', (tester) async {
    Widget heatmap(HeatmapRange range, double width) =>
        _host(ContributionHeatmap(days: _days, range: range, today: _today), width: width);

    Future<void> expectHoverTooltip(int column, int row, String text) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_cell(tester, column, row));
      await tester.pump();
      expect(find.text(text), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await mouse.removePointer();
    }

    // Scrollable, then re-keyed scroll view for another range, then back.
    await tester.pumpWidget(heatmap(const HeatmapRange.lastYear(), 320));
    await expectHoverTooltip(52, 1, '2 workouts on Oct 5, 2026');
    await tester.pumpWidget(heatmap(const HeatmapRange.year(2025), 320));
    await tester.pumpWidget(heatmap(const HeatmapRange.lastYear(), 320));
    await expectHoverTooltip(52, 1, '2 workouts on Oct 5, 2026');

    // Wide enough to fit everything: the non-scrolling branch.
    await tester.pumpWidget(heatmap(const HeatmapRange.lastYear(), 900));
    await expectHoverTooltip(52, 1, '2 workouts on Oct 5, 2026');
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives a narrow box and large text without overflowing', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_host(
      ContributionHeatmap(days: _days, layout: HeatmapLayout.fitToWidth, hint: 'Hint', today: _today),
      width: 220,
    ));
    expect(tester.takeException(), isNull);
  });
}
