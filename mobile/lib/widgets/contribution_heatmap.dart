import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../analytics/heatmap_engine.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// How [ContributionHeatmap] handles more week columns than fit its width.
enum HeatmapLayout {
  /// Every column of the range in a horizontal scroll view that opens on the
  /// newest week (or the selected day) -- what GitHub's graph does on a phone.
  scrollable,

  /// Only as many trailing week columns as fit the width, and no scrolling
  /// at all. For hosts that already own the horizontal swipe (the Analytics
  /// TabBarView, the app's page view), where a nested horizontal scrollable
  /// would fight the tab swipe.
  fitToWidth,
}

// GitHub's own graph uses 10px squares with 3px gaps; 11px keeps a cell
// tappable on a phone while still fitting about a quarter year on screen.
const double _cell = 11;
const double _gap = 3;
const double _pitch = _cell + _gap;
// A literal radius on purpose: GitHub's squares are 2px-rounded and every
// AppRadii token (8+) would melt an 11px cell into a blob. This graph is a
// deliberate exception to the "radii only from AppRadii" rule because it is
// meant to look exactly like GitHub's.
const double _cellRadius = 2;
// Room around the cells so the selection ring of the outermost cells isn't
// clipped by the scroll viewport.
const double _ringPad = 2.5;
const double _labelFontSize = 10;
// Gap between the weekday labels and the first column (on top of _ringPad).
const double _weekdayGap = 4;
// Minimum space between two month labels before the earlier one is dropped.
const double _monthLabelGap = 4;

/// GitHub's contribution-graph colours.
///
/// Deliberately NOT derived from [AppColors]: the previous version lerped
/// `card2` -> `teal` so the graph followed a custom accent, but the point of
/// this graph is to look exactly like GitHub's, and its fixed greens are what
/// make it recognizable at a glance. Dark mode uses GitHub's "dark dimmed"
/// ramp -- plain GitHub dark's empty-cell #161B22 would all but vanish on the
/// app's #1A1B1F dark cards.
class HeatmapPalette {
  const HeatmapPalette._({
    required this.levels,
    required this.outline,
    required this.tooltipBackground,
    required this.tooltipForeground,
  });

  static const light = HeatmapPalette._(
    levels: [Color(0xFFEBEDF0), Color(0xFF9BE9A8), Color(0xFF40C463), Color(0xFF30A14E), Color(0xFF216E39)],
    outline: Color(0x0F1B1F24), // rgba(27,31,36,0.06)
    tooltipBackground: Color(0xFF24292F),
    tooltipForeground: Color(0xFFFFFFFF),
  );

  static const dark = HeatmapPalette._(
    levels: [Color(0xFF2D333B), Color(0xFF0E4429), Color(0xFF006D32), Color(0xFF26A641), Color(0xFF39D353)],
    outline: Color(0x0DFFFFFF), // rgba(255,255,255,0.05)
    tooltipBackground: Color(0xFF636E7B),
    tooltipForeground: Color(0xFFFFFFFF),
  );

  static HeatmapPalette of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Level 0 (no workout) to 4 (top quartile).
  final List<Color> levels;

  /// GitHub's 1px inner cell outline.
  final Color outline;
  final Color tooltipBackground;
  final Color tooltipForeground;
}

/// GitHub-contribution-graph look-alike for logged workouts: one column per
/// week, one row per weekday (starting at the locale's first day of the
/// week, so Sunday-first like GitHub in English and Monday-first in German),
/// each day shaded in GitHub's five greens by its quartile among the
/// range's training days (see [computeHeatmapLevels]) -- so one huge day no
/// longer washes every other day out.
///
/// Tap a day to select it ([onSelectDate]); long-press (touch) or hover
/// (mouse) shows GitHub's "2 workouts on Oct 5, 2026" tooltip. All cells are
/// painted by one [CustomPainter] and hit-tested arithmetically, so a
/// ~371-cell year stays a single cheap render object; hover/long-press only
/// rebuild the floating tooltip.
class ContributionHeatmap extends StatelessWidget {
  const ContributionHeatmap({
    super.key,
    required this.days,
    this.range = const HeatmapRange.lastYear(),
    this.metric = HeatmapMetric.volume,
    this.selectedDate,
    this.onSelectDate,
    this.layout = HeatmapLayout.scrollable,
    this.hint,
    this.today,
  });

  /// Lets tests find the painted grid.
  @visibleForTesting
  static const gridKey = ValueKey<String>('contributionHeatmapGrid');

  /// Per-day totals keyed by ISO date -- [aggregateHeatmapDays] output, so
  /// a screen that also needs the header counts aggregates only once.
  final Map<String, HeatmapDay> days;
  final HeatmapRange range;
  final HeatmapMetric metric;

  /// Gets a clear ring when it's a drawn day of [range].
  final DateTime? selectedDate;

  /// Called with the tapped day (local midnight). Null = taps do nothing.
  final ValueChanged<DateTime>? onSelectDate;
  final HeatmapLayout layout;

  /// Optional explanation shown left of the legend, e.g. what the shade
  /// means for the current [metric].
  final String? hint;

  /// "Today" override for tests; defaults to the device clock.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final today = heatmapDateOnly(this.today ?? DateTime.now());
    final grid = HeatmapGrid(
      range: range,
      firstDayOfWeekIndex: MaterialLocalizations.of(context).firstDayOfWeekIndex,
      today: today,
    );
    final levels = computeHeatmapLevels(days, range: range, metric: metric, today: today);
    final selected = selectedDate;
    return _HeatmapView(
      grid: grid,
      days: days,
      cellLevels: grid.cellLevels(days, levels),
      selectedIndex: selected == null ? null : grid.indexOf(selected),
      todayIndex: grid.indexOf(today),
      onSelectDate: onSelectDate,
      layout: layout,
      hint: hint,
    );
  }
}

class _HeatmapView extends StatefulWidget {
  const _HeatmapView({
    required this.grid,
    required this.days,
    required this.cellLevels,
    required this.selectedIndex,
    required this.todayIndex,
    required this.onSelectDate,
    required this.layout,
    required this.hint,
  });

  final HeatmapGrid grid;
  final Map<String, HeatmapDay> days;

  /// Shade level per grid slot, -1 for blank slots.
  final List<int> cellLevels;
  final int? selectedIndex;
  final int? todayIndex;
  final ValueChanged<DateTime>? onSelectDate;
  final HeatmapLayout layout;
  final String? hint;

  @override
  State<_HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<_HeatmapView> {
  final _tooltip = OverlayPortalController();
  // Keeps the OverlayPortal (and so its attachment to [_tooltip]) alive when
  // the grid moves between the fit/scroll branches or the scroll view is
  // re-keyed for a new range. Without it the old portal is disposed after
  // the new one attached, detaching the shared controller and silently
  // killing every later tooltip.
  final _portalKey = GlobalKey(debugLabel: 'heatmapTooltipPortal');
  // A notifier instead of setState: moving the tooltip from cell to cell
  // (hover, long-press drag) only rebuilds the floating bubble, never the
  // grid, its labels or its text measurements.
  final _tooltipIndex = ValueNotifier<int?>(null);

  @override
  void didUpdateWidget(covariant _HeatmapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another range or week start re-maps every slot index, so an open
    // tooltip would suddenly describe a different day. Closed after this
    // frame -- hiding is a state change, which mustn't happen mid-build.
    if (oldWidget.grid.start != widget.grid.start || oldWidget.grid.slots.length != widget.grid.slots.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hideTooltip();
      });
    }
  }

  @override
  void dispose() {
    _tooltipIndex.dispose();
    super.dispose();
  }

  void _showTooltip(int? index) {
    if (index == null) {
      _hideTooltip();
      return;
    }
    _tooltipIndex.value = index;
    if (!_tooltip.isShowing) _tooltip.show();
  }

  void _hideTooltip() {
    _tooltipIndex.value = null;
    if (_tooltip.isShowing) _tooltip.hide();
  }

  /// The drawn slot nearest to [local] (a point on the painted grid), or
  /// null when that's a blank slot. Nearest-cell instead of exact hits, so
  /// the 3px gaps between the small cells still count as a hit.
  int? _slotAt(Offset local, int firstColumn, int columnCount) {
    final int column = math.min(math.max(((local.dx - _ringPad - _cell / 2) / _pitch).round(), 0), columnCount - 1);
    final int row = math.min(math.max(((local.dy - _ringPad - _cell / 2) / _pitch).round(), 0), 6);
    final index = (firstColumn + column) * 7 + row;
    return widget.cellLevels[index] >= 0 ? index : null;
  }

  String _describe(AppLocalizations t, String localeName, int index) {
    final slot = widget.grid.slots[index];
    final date = DateFormat.yMMMd(localeName).format(slot.date);
    final count = widget.days[slot.key]?.sessionCount ?? 0;
    return count == 0 ? t.heatmapDayNone(date) : t.heatmapDayCount(count, date);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final palette = HeatmapPalette.of(context);
    final localeName = Localizations.localeOf(context).toString();
    // The labels share rows/columns with fixed-size cells, so they may grow
    // with the system text size only so far before they'd overlap.
    final textScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final labelStyle = DefaultTextStyle.of(context).style.merge(TextStyle(
          color: colors.mut,
          fontSize: _labelFontSize,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ));
    final grid = widget.grid;

    // Mon/Wed/Fri only, like GitHub -- a label on every row of cells this
    // small is an unreadable stack. Formatted from a real slot date of that
    // weekday through the public DateFormat API.
    final weekdayFormat = DateFormat.E(localeName);
    final weekdayLabels = [
      for (final weekday in const [DateTime.monday, DateTime.wednesday, DateTime.friday])
        (
          row: grid.rowOfWeekday(weekday),
          text: weekdayFormat.format(grid.slotAt(0, grid.rowOfWeekday(weekday)).date),
        ),
    ];
    final labelHeight = _measure('Mg', labelStyle, textScaler).height;
    final weekdayColumnWidth =
        weekdayLabels.fold(0.0, (w, label) => math.max(w, _measure(label.text, labelStyle, textScaler).width));
    final monthRowHeight = labelHeight + 4;
    const gridHeight = 2 * _ringPad + 7 * _pitch - _gap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: weekdayColumnWidth,
              height: monthRowHeight + gridHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final label in weekdayLabels)
                    Positioned(
                      left: 0,
                      top: monthRowHeight + _ringPad + label.row * _pitch + (_cell - labelHeight) / 2,
                      child: Text(label.text, style: labelStyle, textScaler: textScaler, maxLines: 1, softWrap: false),
                    ),
                ],
              ),
            ),
            const SizedBox(width: _weekdayGap),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => _buildGridArea(
                  context,
                  maxWidth: constraints.maxWidth,
                  t: t,
                  colors: colors,
                  palette: palette,
                  localeName: localeName,
                  labelStyle: labelStyle,
                  textScaler: textScaler,
                  monthRowHeight: monthRowHeight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Legend(
          palette: palette,
          hint: widget.hint,
          less: t.heatmapLegendLess,
          more: t.heatmapLegendMore,
          style: DefaultTextStyle.of(context)
              .style
              .merge(TextStyle(color: colors.mut, fontSize: 11, fontWeight: FontWeight.w500)),
          textScaler: textScaler,
        ),
      ],
    );
  }

  Widget _buildGridArea(
    BuildContext context, {
    required double maxWidth,
    required AppLocalizations t,
    required AppColors colors,
    required HeatmapPalette palette,
    required String localeName,
    required TextStyle labelStyle,
    required TextScaler textScaler,
    required double monthRowHeight,
  }) {
    final grid = widget.grid;
    final fittingColumns = math.max(1, ((maxWidth - 2 * _ringPad + _gap) / _pitch).floor());
    final int firstColumn;
    final int columnCount;
    if (widget.layout == HeatmapLayout.fitToWidth) {
      // The newest weeks that fit -- ending at the last drawn day, so a
      // running year doesn't fill the card with blank future weeks.
      final lastColumn = grid.lastDrawnColumn;
      columnCount = math.min(fittingColumns, lastColumn + 1);
      firstColumn = lastColumn + 1 - columnCount;
    } else {
      firstColumn = 0;
      columnCount = grid.weekCount;
    }
    final contentWidth = 2 * _ringPad + columnCount * _pitch - _gap;

    final content = SizedBox(
      width: contentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: contentWidth,
            height: monthRowHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final label in _monthLabels(firstColumn, columnCount, localeName, labelStyle, textScaler))
                  Positioned(
                    left: _ringPad + (label.column - firstColumn) * _pitch,
                    top: 0,
                    child: Text(label.text, style: labelStyle, textScaler: textScaler, maxLines: 1, softWrap: false),
                  ),
              ],
            ),
          ),
          OverlayPortal.overlayChildLayoutBuilder(
            key: _portalKey,
            controller: _tooltip,
            overlayChildBuilder: (context, info) => ValueListenableBuilder<int?>(
              valueListenable: _tooltipIndex,
              builder: (context, index, _) =>
                  _buildTooltip(context, info, index, firstColumn, columnCount, t, palette, localeName),
            ),
            child: _buildGrid(context, t, colors, palette, localeName, firstColumn, columnCount),
          ),
        ],
      ),
    );

    if (widget.layout == HeatmapLayout.fitToWidth || contentWidth <= maxWidth) {
      return Align(alignment: AlignmentDirectional.centerStart, child: content);
    }

    // Open on the selected day's week (or the newest drawn week) near the
    // right edge, with one more column of context after it. reverse: true
    // makes offset 0 the newest end, like opening GitHub's graph.
    final selected = widget.selectedIndex;
    final anchorColumn = selected != null && widget.cellLevels[selected] >= 0 ? selected ~/ 7 : grid.lastDrawnColumn;
    final anchorRight = _ringPad + anchorColumn * _pitch + _cell;
    final initialOffset =
        (contentWidth - anchorRight - _pitch - _ringPad).clamp(0.0, math.max(0.0, contentWidth - maxWidth));

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (_) {
        _hideTooltip();
        return false;
      },
      child: _NewestFirstScrollView(
        // A new range gets a fresh scroll position (and initial offset).
        key: ValueKey(grid.range),
        initialOffset: initialOffset.toDouble(),
        child: content,
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    AppLocalizations t,
    AppColors colors,
    HeatmapPalette palette,
    String localeName,
    int firstColumn,
    int columnCount,
  ) {
    final onSelectDate = widget.onSelectDate;
    final size = Size(2 * _ringPad + columnCount * _pitch - _gap, 2 * _ringPad + 7 * _pitch - _gap);
    // A cancelled pointer (system gesture, scroll takeover, app switch) ends
    // a long-press without onLongPressEnd -- close the tooltip either way.
    return Listener(
      onPointerCancel: (_) => _hideTooltip(),
      child: MouseRegion(
        cursor: onSelectDate == null ? MouseCursor.defer : SystemMouseCursors.click,
        onHover: (event) => _showTooltip(_slotAt(event.localPosition, firstColumn, columnCount)),
        onExit: (_) => _hideTooltip(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onSelectDate == null
              ? null
              : (details) {
                  _hideTooltip();
                  final index = _slotAt(details.localPosition, firstColumn, columnCount);
                  if (index != null) onSelectDate(widget.grid.slots[index].date);
                },
          onLongPressStart: (details) {
            final index = _slotAt(details.localPosition, firstColumn, columnCount);
            if (index != null) Feedback.forLongPress(context);
            _showTooltip(index);
          },
          onLongPressMoveUpdate: (details) => _showTooltip(_slotAt(details.localPosition, firstColumn, columnCount)),
          onLongPressEnd: (_) => _hideTooltip(),
          onLongPressCancel: _hideTooltip,
          child: CustomPaint(
            key: ContributionHeatmap.gridKey,
            size: size,
            painter: _HeatmapPainter(
              cellLevels: widget.cellLevels,
              firstColumn: firstColumn,
              columnCount: columnCount,
              palette: palette,
              selectedIndex: widget.selectedIndex,
              todayIndex: widget.todayIndex,
              selectionColor: colors.accent,
              todayColor: colors.txt.withValues(alpha: 0.45),
              describe: (index) => _describe(t, localeName, index),
              onTapIndex: onSelectDate == null ? null : (index) => onSelectDate(widget.grid.slots[index].date),
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Month labels for the shown columns. GitHub skips a label that's too
  /// cramped -- typically the sliver of a month at either end of the graph
  /// -- rather than letting it overlap the next one or run off the edge;
  /// so does this, using the label's real rendered width.
  List<({int column, String text})> _monthLabels(
    int firstColumn,
    int columnCount,
    String localeName,
    TextStyle style,
    TextScaler textScaler,
  ) {
    // LLL (stand-alone abbreviated month) rather than MMM: a label on its
    // own needs the nominative form -- MMM is the in-a-date form, which is
    // e.g. genitive in Russian.
    final format = DateFormat.LLL(localeName);
    final starts = widget.grid.monthStarts(firstColumn: firstColumn, lastColumn: firstColumn + columnCount - 1);
    final rightEdge = 2 * _ringPad + columnCount * _pitch - _gap;
    final labels = <({int column, String text})>[];
    for (var i = 0; i < starts.length; i++) {
      final text = format.format(starts[i].month);
      final left = _ringPad + (starts[i].column - firstColumn) * _pitch;
      final limit =
          i + 1 < starts.length ? _ringPad + (starts[i + 1].column - firstColumn) * _pitch - _monthLabelGap : rightEdge;
      if (left + _measure(text, style, textScaler).width > limit) continue;
      labels.add((column: starts[i].column, text: text));
    }
    return labels;
  }

  Widget _buildTooltip(
    BuildContext context,
    OverlayChildLayoutInfo info,
    int? index,
    int firstColumn,
    int columnCount,
    AppLocalizations t,
    HeatmapPalette palette,
    String localeName,
  ) {
    final column = index == null ? -1 : index ~/ 7 - firstColumn;
    if (index == null || column < 0 || column >= columnCount) return const SizedBox.shrink();
    final cell = _cellRect(column, index % 7);
    final view = View.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _TooltipLayout(
            // Overlay coordinates of the cell, re-derived on every layout so
            // the bubble follows the cell if the content moves underneath.
            cellTop: MatrixUtils.transformPoint(info.childPaintTransform, cell.topCenter),
            cellBottom: MatrixUtils.transformPoint(info.childPaintTransform, cell.bottomCenter),
            topInset: view.padding.top / view.devicePixelRatio,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.tooltipBackground,
              borderRadius: BorderRadius.circular(AppRadii.xs),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                _describe(t, localeName, index),
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.tooltipForeground, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Rect _cellRect(int column, int row) => Rect.fromLTWH(_ringPad + column * _pitch, _ringPad + row * _pitch, _cell, _cell);

Size _measure(String text, TextStyle style, TextScaler textScaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

/// Horizontal scroll view whose offset 0 is the right (newest) end; the
/// initial offset is read once, so selecting another day later never yanks
/// the view around.
class _NewestFirstScrollView extends StatefulWidget {
  const _NewestFirstScrollView({super.key, required this.initialOffset, required this.child});

  final double initialOffset;
  final Widget child;

  @override
  State<_NewestFirstScrollView> createState() => _NewestFirstScrollViewState();
}

class _NewestFirstScrollViewState extends State<_NewestFirstScrollView> {
  late final ScrollController _controller = ScrollController(initialScrollOffset: widget.initialOffset);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: widget.child,
      );
}

/// Centres the tooltip above its cell (below when there's no room above)
/// and keeps it on screen at the edges.
class _TooltipLayout extends SingleChildLayoutDelegate {
  const _TooltipLayout({required this.cellTop, required this.cellBottom, required this.topInset});

  final Offset cellTop;
  final Offset cellBottom;
  final double topInset;

  static const double _margin = 8;
  static const double _distance = 6;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.max(0.0, constraints.maxWidth - 2 * _margin), maxHeight: constraints.maxHeight);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var y = cellTop.dy - _distance - childSize.height;
    if (y < topInset + _margin) y = cellBottom.dy + _distance;
    final maxX = math.max(_margin, size.width - _margin - childSize.width);
    final x = math.min(math.max(cellTop.dx - childSize.width / 2, _margin), maxX);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_TooltipLayout oldDelegate) =>
      oldDelegate.cellTop != cellTop || oldDelegate.cellBottom != cellBottom || oldDelegate.topInset != topInset;
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.cellLevels,
    required this.firstColumn,
    required this.columnCount,
    required this.palette,
    required this.selectedIndex,
    required this.todayIndex,
    required this.selectionColor,
    required this.todayColor,
    required this.describe,
    required this.onTapIndex,
    required this.textDirection,
  });

  final List<int> cellLevels;
  final int firstColumn;
  final int columnCount;
  final HeatmapPalette palette;
  final int? selectedIndex;
  final int? todayIndex;
  final Color selectionColor;
  final Color todayColor;
  final String Function(int index) describe;
  final ValueChanged<int>? onTapIndex;
  final TextDirection textDirection;

  int _indexOf(int column, int row) => (firstColumn + column) * 7 + row;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.outline;
    for (var c = 0; c < columnCount; c++) {
      for (var r = 0; r < 7; r++) {
        final level = cellLevels[_indexOf(c, r)];
        if (level < 0) continue; // outside the range / after today: not drawn
        final cell = RRect.fromRectAndRadius(_cellRect(c, r), const Radius.circular(_cellRadius));
        canvas.drawRRect(cell, fill..color = palette.levels[level]);
        // GitHub's 1px inner outline, which keeps empty cells visible on a
        // background of nearly the same colour.
        canvas.drawRRect(cell.deflate(0.5), outline);
      }
    }
    _ring(canvas, todayIndex, todayColor, strokeWidth: 1, inflate: 1);
    _ring(canvas, selectedIndex, selectionColor, strokeWidth: 2, inflate: 1.5);
  }

  void _ring(Canvas canvas, int? index, Color color, {required double strokeWidth, required double inflate}) {
    if (index == null || cellLevels[index] < 0) return;
    final column = index ~/ 7 - firstColumn;
    if (column < 0 || column >= columnCount) return;
    final rect = _cellRect(column, index % 7).inflate(inflate);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(_cellRadius + inflate)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  // Screen readers get one node per training day (plus today and the
  // selection) instead of 365 mostly-empty cells to swipe through.
  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) => [
        for (var c = 0; c < columnCount; c++)
          for (var r = 0; r < 7; r++)
            if (_announced(_indexOf(c, r)))
              CustomPainterSemantics(
                key: ValueKey<int>(_indexOf(c, r)),
                rect: _cellRect(c, r),
                properties: SemanticsProperties(
                  label: describe(_indexOf(c, r)),
                  textDirection: textDirection,
                  selected: _indexOf(c, r) == selectedIndex,
                  onTap: onTapIndex == null ? null : () => onTapIndex!(_indexOf(c, r)),
                ),
              ),
      ];

  bool _announced(int index) =>
      cellLevels[index] > 0 || (cellLevels[index] == 0 && (index == selectedIndex || index == todayIndex));

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) =>
      !identical(oldDelegate.cellLevels, cellLevels) ||
      oldDelegate.firstColumn != firstColumn ||
      oldDelegate.columnCount != columnCount ||
      oldDelegate.palette != palette ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.todayIndex != todayIndex ||
      oldDelegate.selectionColor != selectionColor ||
      oldDelegate.todayColor != todayColor;

  @override
  bool shouldRebuildSemantics(_HeatmapPainter oldDelegate) =>
      shouldRepaint(oldDelegate) || oldDelegate.textDirection != textDirection;
}

/// "Less ■■■■■ More", right-aligned like GitHub's, with an optional hint on
/// the left. When hint and legend don't fit on one line (narrow card, large
/// text) the hint moves below the legend instead of overflowing, and the
/// legend itself scales down if even it alone is too wide.
class _Legend extends StatelessWidget {
  const _Legend({
    required this.palette,
    required this.less,
    required this.more,
    required this.style,
    required this.textScaler,
    this.hint,
  });

  final HeatmapPalette palette;
  final String less;
  final String more;
  final TextStyle style;
  final TextScaler textScaler;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final swatches = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(less, style: style, textScaler: textScaler),
        const SizedBox(width: 4),
        for (var level = 0; level < palette.levels.length; level++) ...[
          if (level > 0) const SizedBox(width: _gap),
          Container(
            width: _cell,
            height: _cell,
            decoration: BoxDecoration(
              color: palette.levels[level],
              borderRadius: BorderRadius.circular(_cellRadius),
              border: Border.all(color: palette.outline),
            ),
          ),
        ],
        const SizedBox(width: 4),
        Text(more, style: style, textScaler: textScaler),
      ],
    );
    final legendWidth = _measure(less, style, textScaler).width +
        _measure(more, style, textScaler).width +
        8 +
        palette.levels.length * _cell +
        (palette.levels.length - 1) * _gap;
    final legend = Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerEnd, child: swatches),
    );
    final hint = this.hint;
    if (hint == null) return legend;

    return LayoutBuilder(builder: (context, constraints) {
      final hintWidth = _measure(hint, style, textScaler).width;
      if (hintWidth + 12 + legendWidth <= constraints.maxWidth) {
        return Row(
          children: [
            Expanded(child: Text(hint, style: style, textScaler: textScaler, maxLines: 1)),
            const SizedBox(width: 12),
            swatches,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          legend,
          const SizedBox(height: 4),
          Text(hint, style: style, textScaler: textScaler),
        ],
      );
    });
  }
}
