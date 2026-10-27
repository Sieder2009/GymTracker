import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/body_measurement_analytics.dart';
import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/body_measurement_entry.dart';
import '../state/body_measurements_provider.dart';
import '../theme/app_colors.dart';
import 'radar_chart.dart';
import 'strength_line_chart.dart';
import 'value_entry_sheet.dart';

/// Body-circumference tracking -- a chip picker to choose which single
/// field's trend the mini chart shows (matching how [StrengthLineChart] is
/// already a single-series widget elsewhere, e.g. `strength_screen.dart`'s
/// `_BodyWeightCard`), one button that opens a clear entry sheet for all six
/// fields (any subset; a user typically measures only a few on a given day),
/// and a spider chart of every measured field on one cm scale, first value
/// against latest, so growth shows as a shape with the change at each
/// corner.
class BodyMeasurementsCard extends StatefulWidget {
  const BodyMeasurementsCard({super.key});

  @override
  State<BodyMeasurementsCard> createState() => _BodyMeasurementsCardState();
}

class _BodyMeasurementsCardState extends State<BodyMeasurementsCard> {
  BodyMeasurementField _selected = BodyMeasurementField.chest;

  /// Spider-chart order: chest on top, then clockwise down the arm, round
  /// the waist and hips, and up the leg.
  static const List<BodyMeasurementField> _radarOrder = [
    BodyMeasurementField.chest,
    BodyMeasurementField.arm,
    BodyMeasurementField.waist,
    BodyMeasurementField.hips,
    BodyMeasurementField.thigh,
    BodyMeasurementField.calf,
  ];

  Future<void> _log(AppLocalizations t, Map<BodyMeasurementField, ({double first, double latest})> spans) async {
    const fields = BodyMeasurementField.values;
    final values = await showValueEntrySheet(
      context,
      title: t.actionLogMeasurements,
      fields: [
        for (final f in fields)
          ValueEntryField(label: bodyMeasurementFieldLabel(t, f), unit: 'cm', last: spans[f]?.latest),
      ],
    );
    if (values == null || !mounted) return;
    double? valueOf(BodyMeasurementField f) => values[fields.indexOf(f)];
    context.read<BodyMeasurementsProvider>().addEntry(
          chestCm: valueOf(BodyMeasurementField.chest),
          waistCm: valueOf(BodyMeasurementField.waist),
          hipsCm: valueOf(BodyMeasurementField.hips),
          armCm: valueOf(BodyMeasurementField.arm),
          thighCm: valueOf(BodyMeasurementField.thigh),
          calfCm: valueOf(BodyMeasurementField.calf),
        );
  }

  RadarAxis _axis(AppLocalizations t, BodyMeasurementField f, ({double first, double latest}) span) {
    final delta = span.latest - span.first;
    final change = delta == 0 ? '' : ' · ${delta > 0 ? '+' : '−'}${fmt(delta.abs())}';
    return RadarAxis(
      label: bodyMeasurementFieldLabel(t, f),
      value: span.latest,
      start: delta == 0 ? null : span.first,
      detail: '${fmt(span.latest)} cm$change',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final entries = context.watch<BodyMeasurementsProvider>().entries;
    final spans = measurementSpans(entries);
    final radarAxes = [
      for (final f in _radarOrder)
        if (spans[f] case final span?) _axis(t, f, span),
    ];
    final series = [
      for (final e in entries)
        if (bodyMeasurementFieldValue(e, _selected) != null) bodyMeasurementFieldValue(e, _selected)!,
    ];
    final points = series.length > 8 ? series.sublist(series.length - 8) : series;
    final latest = points.isEmpty ? null : points.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Text(t.titleBodyMeasurements,
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in BodyMeasurementField.values)
                  ChoiceChip(
                    label: Text(bodyMeasurementFieldLabel(t, f)),
                    selected: _selected == f,
                    onSelected: (_) => setState(() => _selected = f),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (points.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(t.emptyNoEntries, style: TextStyle(color: colors.mut)),
              )
            else ...[
              // Same fix as _BodyWeightCard's chart in strength_screen.dart:
              // a single point has nothing to connect to, so it just centers
              // one dot in an otherwise blank frame -- reads as broken, not
              // "not enough data yet". Skip straight to the value.
              if (points.length > 1) ...[
                StrengthLineChart(
                  points: points,
                  pr: 0,
                  color: colors.accent,
                  lineColor: colors.line,
                ),
                const SizedBox(height: 8),
              ],
              Text('${t.labelCurrent}: ${fmt1(latest!)} cm',
                  style: TextStyle(color: colors.mut)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _log(t, spans),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(t.actionLogMeasurements),
              ),
            ),
            // A web needs at least three spokes.
            if (radarAxes.length >= 3) ...[
              const Divider(height: 28),
              Text(t.titleBodyShape, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              RadarChart(
                axes: radarAxes,
                ringLabel: (v, outermost) => outermost ? '${fmt(v)} cm' : fmt(v),
                nowLabel: t.labelCurrent,
                startLabel: t.labelStart,
                semanticsLabel: [
                  t.titleBodyShape,
                  for (final a in radarAxes) '${a.label}: ${a.detail}',
                ].join(', '),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
