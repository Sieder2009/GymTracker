/// Which plates to load on each side of a barbell to hit a target total
/// weight. Greedy from largest plate to smallest is exact (not just a good
/// guess) for the standard denominations below, because each is at least
/// double the next smallest — the same property that makes greedy coin-
/// change optimal for currencies like EUR/USD.
library;

const List<double> kStandardPlatesKg = [25, 20, 15, 10, 5, 2.5, 1.25, 0.5];
const List<double> kStandardPlatesLb = [45, 35, 25, 10, 5, 2.5];

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

/// Null when [targetKg] is lighter than [barWeightKg] alone, or the bar
/// weight itself isn't set — there's nothing meaningful to load.
PlateCalculatorResult? calculatePlates({
  required double targetKg,
  required double barWeightKg,
  List<double> availablePlates = kStandardPlatesKg,
}) {
  if (barWeightKg <= 0 || targetKg < barWeightKg) return null;

  var perSideRemaining = (targetKg - barWeightKg) / 2;
  final perSide = <double>[];
  final sortedPlates = [...availablePlates]..sort((a, b) => b.compareTo(a));
  for (final plate in sortedPlates) {
    if (plate <= 0) continue;
    while (perSideRemaining + 1e-9 >= plate) {
      perSide.add(plate);
      perSideRemaining -= plate;
    }
  }

  final achievedTotal = _round2(targetKg - perSideRemaining * 2);
  return PlateCalculatorResult(
    perSide: perSide,
    achievedTotal: achievedTotal,
    targetTotal: _round2(targetKg),
  );
}
