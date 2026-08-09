import 'package:flutter/material.dart';

import '../analytics/analytics_engine.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// A value with an up/down/flat trend arrow, or an honest "not enough
/// data yet" label when [stat.quality] is [DataQuality.insufficient] —
/// never a fabricated 0% or dash. Used everywhere a [TrendStat] is shown
/// (see analytics_engine.dart §101.21 "data quality indicators").
class TrendValue extends StatelessWidget {
  const TrendValue({
    super.key,
    required this.stat,
    required this.formatDelta,
    this.style,
  });

  final TrendStat stat;

  /// Formats the raw delta into display text, e.g. `(d) => '${d.toStringAsFixed(1)}%'`.
  /// Only called when [stat.delta] is non-null.
  final String Function(double delta) formatDelta;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final delta = stat.delta;

    if (delta == null) {
      return Text(t.insufficientDataShort, style: TextStyle(color: colors.mut, fontSize: 12.5));
    }

    final isUp = delta > 0;
    final isFlat = delta == 0;
    final color = isFlat ? colors.mut : (isUp ? colors.green : colors.accent);
    final arrow = isFlat ? '→' : (isUp ? '↑' : '↓');

    return Text(
      '$arrow ${formatDelta(delta.abs())}',
      style: (style ?? const TextStyle()).copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}
