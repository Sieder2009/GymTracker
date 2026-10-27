/// Which plates to load on each side of a barbell, EZ bar, dumbbell or leg
/// press to hit a target total weight. Not greedy: once some plates can be
/// switched off (a gym without 20s, say), largest-first misses real
/// answers -- with only 25s and 15s, 30 per side is 15+15, not "25 and
/// stuck". So it searches exactly, like coin change: the fewest plates
/// that make the per-side load, ties going to the larger plates.
library;

import 'dart:math' as math;

const List<double> kStandardPlatesKg = [25, 20, 15, 10, 5, 2.5, 1.25, 0.5];
const List<double> kStandardPlatesLb = [45, 35, 25, 10, 5, 2.5];

/// Plate weights are whole multiples of this (0.5 kg, 1.25 kg, 2.5 lb, …),
/// so the search runs on whole steps of it instead of doubles.
const double _step = 0.05;

/// The heaviest load per side the search goes up to -- far beyond any real
/// bar or sled, and it keeps a typo like 99999 from stalling the sheet.
const double _maxPerSide = 1000;

class PlateCalculatorResult {
  const PlateCalculatorResult({
    required this.perSide,
    required this.achievedTotal,
    required this.targetTotal,
  });

  /// Plates for ONE side of the bar, largest first — load the same stack
  /// on the other side too.
  final List<double> perSide;
  final double achievedTotal;
  final double targetTotal;

  /// True when [achievedTotal] falls short of [targetTotal] — the leftover
  /// can't be made with the given plate set (e.g. asking for a 0.1kg step
  /// with 0.5kg as the smallest plate available).
  bool get isApproximate => (targetTotal - achievedTotal).abs() > 0.001;
}

double _round2(double v) => (v * 100).round() / 100;

/// Null when [targetKg] is lighter than [barWeightKg] alone, or the empty
/// weight is negative -- there's nothing meaningful to load. An empty
/// weight of 0 is fine: a leg press whose sled isn't counted.
PlateCalculatorResult? calculatePlates({
  required double targetKg,
  required double barWeightKg,
  List<double> availablePlates = kStandardPlatesKg,
}) {
  if (barWeightKg < 0 || targetKg < barWeightKg) return null;

  final perSideTarget = math.min((targetKg - barWeightKg) / 2, _maxPerSide);
  final goal = (perSideTarget / _step + 1e-6).floor();
  final plates = [
    for (final plate in {...availablePlates})
      if (plate > 0) plate,
  ]..sort((a, b) => b.compareTo(a));
  final steps = [for (final plate in plates) (plate / _step).round()];

  // fewest[a]: fewest plates that make exactly `a` steps (-1: impossible);
  // last[a]: index of the plate added last to get there. Plates are tried
  // largest first and only a strictly smaller count replaces a found one,
  // so ties keep the larger plates.
  final fewest = List<int>.filled(goal + 1, -1)..[0] = 0;
  final last = List<int>.filled(goal + 1, -1);
  for (var a = 1; a <= goal; a++) {
    for (var i = 0; i < steps.length; i++) {
      final rest = a - steps[i];
      if (rest < 0 || fewest[rest] < 0) continue;
      if (fewest[a] < 0 || fewest[rest] + 1 < fewest[a]) {
        fewest[a] = fewest[rest] + 1;
        last[a] = i;
      }
    }
  }

  // The heaviest load the plates can make without going over.
  var reached = goal;
  while (fewest[reached] < 0) {
    reached--;
  }
  final perSide = <double>[];
  for (var a = reached; a > 0; a -= steps[last[a]]) {
    perSide.add(plates[last[a]]);
  }
  perSide.sort((a, b) => b.compareTo(a));

  return PlateCalculatorResult(
    perSide: perSide,
    achievedTotal: _round2(barWeightKg + 2 * reached * _step),
    targetTotal: _round2(targetKg),
  );
}
