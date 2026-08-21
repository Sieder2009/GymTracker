import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// One dated sample for [LineChartCard].
class ChartPoint {
  const ChartPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

/// One labeled sample for [BarChartCard].
class BarPoint {
  const BarPoint(this.label, this.value);
  final String label;
  final double value;
}

/// A titled card wrapping an [fl_chart] line chart, themed from [AppColors]
/// instead of fl_chart's defaults so every chart in the app looks like one
/// design system. Shows an honest empty state instead of a flat/fake line
/// when there aren't at least 2 real dated points to connect — charts must
/// never imply a trend that isn't backed by real logged data.
class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.points,
    required this.emptyLabel,
    this.subtitle,
    this.valueSuffix = '',
    this.color,
    this.height = 180,
  });

  final String title;
  final String? subtitle;
  final List<ChartPoint> points;
  final String emptyLabel;
  final String valueSuffix;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final lineColor = color ?? colors.accent;
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: TextStyle(color: colors.mut, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: sorted.length < 2
                  ? Center(
                      child: Text(
                        emptyLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.mut, fontSize: 12.5),
                      ),
                    )
                  : _buildChart(sorted, lineColor, colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
      List<ChartPoint> sorted, Color lineColor, AppColors colors) {
    final minY = sorted.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = sorted.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.15).clamp(1.0, double.infinity);
    // Shared by the grid lines AND the left-axis labels below: passing it
    // explicitly to both (instead of leaving the labels to fl_chart's own
    // auto-computed interval) is what keeps every gridline lined up with
    // its label. Without this, a near-flat series (e.g. several weeks of
    // 0 volume) makes fl_chart pick a sub-1 interval on its own, and
    // toStringAsFixed(0) then rounds adjacent fractional ticks (like 0.5
    // and 1.0) to the same displayed integer -- duplicate-looking labels.
    final interval = ((maxY - minY + pad * 2) / 3).clamp(0.1, double.infinity);
    final labelDecimals = interval < 1 ? 1 : 0;
    final spots = [
      for (var i = 0; i < sorted.length; i++)
        FlSpot(i.toDouble(), sorted[i].value),
    ];

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colors.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(labelDecimals),
                style: TextStyle(color: colors.mut, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval:
                  (sorted.length / 4).clamp(1, double.infinity).roundToDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.Md().format(sorted[i].date),
                    style: TextStyle(color: colors.mut, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.card2,
            getTooltipItems: (touched) => touched.map((t) {
              final p = sorted[t.x.toInt()];
              return LineTooltipItem(
                '${p.value.toStringAsFixed(1)}$valueSuffix\n${DateFormat.yMMMd().format(p.date)}',
                TextStyle(
                    color: colors.txt,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(
              // The most recent point gets a bigger dot with a soft halo
              // ring around it (fl_chart has no built-in glow), so "where
              // are we now" reads instantly instead of blending into the
              // rest of the line.
              getDotPainter: (spot, percent, bar, index) => index == sorted.length - 1
                  ? FlDotCirclePainter(
                      radius: 5,
                      color: lineColor,
                      strokeColor: lineColor.withValues(alpha: 0.35),
                      strokeWidth: 6,
                    )
                  : FlDotCirclePainter(
                      radius: 3, color: lineColor, strokeColor: lineColor),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.32),
                  lineColor.withValues(alpha: 0.0)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled card wrapping an [fl_chart] bar chart — used for weekly volume,
/// per-category comparisons, etc. Same empty-state contract as
/// [LineChartCard]: no bars drawn (just the honest message) when there's
/// nothing real to show.
class BarChartCard extends StatelessWidget {
  const BarChartCard({
    super.key,
    required this.title,
    required this.bars,
    required this.emptyLabel,
    this.subtitle,
    this.color,
    this.height = 180,
  });

  final String title;
  final String? subtitle;
  final List<BarPoint> bars;
  final String emptyLabel;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final barColor = color ?? colors.accent;
    final hasData = bars.any((b) => b.value > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: TextStyle(color: colors.mut, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: !hasData
                  ? Center(
                      child: Text(
                        emptyLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.mut, fontSize: 12.5),
                      ),
                    )
                  : _buildChart(barColor, colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(Color barColor, AppColors colors) {
    final rawMaxY =
        bars.map((b) => b.value).reduce((a, b) => a > b ? a : b) * 1.2;
    final maxY = rawMaxY <= 0 ? 1.0 : rawMaxY;
    // Same fix as LineChartCard: an explicit shared interval for both the
    // gridlines and the left-axis labels, so a small maxY (e.g. every bar
    // near 0) can't make fl_chart auto-pick a sub-1 interval whose
    // fractional ticks then collapse into duplicate-looking whole-number
    // labels under toStringAsFixed(0).
    final interval = (maxY / 4).clamp(0.1, double.infinity);
    final labelDecimals = interval < 1 ? 1 : 0;
    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colors.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(labelDecimals),
                style: TextStyle(color: colors.mut, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(bars[i].label,
                      style: TextStyle(color: colors.mut, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colors.card2,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              rod.toY.toStringAsFixed(0),
              TextStyle(
                  color: colors.txt, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i].value,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [barColor, barColor.withValues(alpha: 0.55)],
                  ),
                  width: 16,
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
