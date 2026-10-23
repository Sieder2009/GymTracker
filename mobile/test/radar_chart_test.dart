import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/body_measurement_analytics.dart';
import 'package:ironpeak_mobile/models/body_measurement_entry.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:ironpeak_mobile/widgets/radar_chart.dart';
import 'package:ironpeak_mobile/widgets/value_entry_sheet.dart';

void main() {
  group('radarScale', () {
    void expectScale(double peak, double max, List<double> rings) {
      final scale = radarScale(peak);
      expect(scale.max, max, reason: 'peak $peak');
      expect(scale.rings, rings, reason: 'peak $peak');
    }

    test('picks a round step and an outer ring that holds the peak', () {
      expectScale(140, 150, [50, 100, 150]);
      expectScale(100, 100, [25, 50, 75, 100]);
      expectScale(38.5, 40, [10, 20, 30, 40]);
      final big = radarScale(212);
      expect(big.max, greaterThanOrEqualTo(212));
      expect(big.rings.length, inInclusiveRange(3, 5));
    });

    test('an empty chart still has one ring', () {
      expectScale(0, 1, [1]);
    });
  });

  group('measurementSpans', () {
    BodyMeasurementEntry entry(String date, {double? arm, double? calf, double? chest}) =>
        BodyMeasurementEntry(date: date, armCm: arm, calfCm: calf, chestCm: chest);

    test('first and latest per field, skipping entries without that field', () {
      final spans = measurementSpans([
        entry('2026-09-01', arm: 35, chest: 100),
        entry('2026-09-15', calf: 38),
        entry('2026-10-01', arm: 36.5),
        entry('2026-10-15', chest: 102),
      ]);
      expect(spans[BodyMeasurementField.arm], (first: 35.0, latest: 36.5));
      expect(spans[BodyMeasurementField.chest], (first: 100.0, latest: 102.0));
      // Logged once: start and latest are the same value.
      expect(spans[BodyMeasurementField.calf], (first: 38.0, latest: 38.0));
      expect(spans.containsKey(BodyMeasurementField.waist), isFalse);
    });

    test('nothing logged, nothing to show', () {
      expect(measurementSpans(const []), isEmpty);
    });
  });

  group('parseEntryValue', () {
    test('accepts comma and point, rejects zero and garbage', () {
      expect(parseEntryValue(''), isNull);
      expect(parseEntryValue('  '), isNull);
      expect(parseEntryValue('36,5'), 36.5);
      expect(parseEntryValue('120.25'), 120.25);
      expect(parseEntryValue('0')!.isNaN, isTrue);
      expect(parseEntryValue('1.2.3')!.isNaN, isTrue);
    });
  });

  group('RadarChart', () {
    Widget host(Widget child, {double width = 288, double textScale = 1}) => MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
          ),
        );

    testWidgets('long labels at a narrow width and large text never overflow', (tester) async {
      await tester.pumpWidget(host(
        width: 260,
        textScale: 1.3,
        RadarChart(
          axes: const [
            RadarAxis(label: 'Brust', value: 102, start: 100, detail: '102 cm · +2'),
            RadarAxis(label: 'Arm', value: 36.5, start: 35, detail: '36,5 cm · +1,5'),
            RadarAxis(label: 'Taille', value: 82, start: 84, detail: '82 cm · −2'),
            RadarAxis(label: 'Hüfte', value: 98, detail: '98 cm'),
            RadarAxis(label: 'Oberschenkel', value: 58, detail: '58 cm'),
            RadarAxis(label: 'Wade', value: 38, detail: '38 cm'),
          ],
          ringLabel: (v, outermost) => outermost ? '${v.round()} cm' : '${v.round()}',
          nowLabel: 'Aktuell',
          startLabel: 'Start',
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Oberschenkel'), findsOneWidget);
      // With a start outline, the legend tells the two shapes apart.
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('three spokes, one of them empty; no legend without a start', (tester) async {
      await tester.pumpWidget(host(
        RadarChart(
          axes: const [
            RadarAxis(label: 'Squat', value: 140, detail: '140 kg'),
            RadarAxis(label: 'Bench Press', value: 100, detail: '100 kg'),
            RadarAxis(label: 'Deadlift', detail: '—'),
          ],
          ringLabel: (v, outermost) => '${v.round()}',
          nowLabel: 'Aktuell',
          startLabel: 'Start',
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });
  });
}
