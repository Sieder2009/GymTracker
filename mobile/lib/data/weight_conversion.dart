/// Converts between a barbell's total weight and what's loaded on just one
/// side — the same `total = bar + 2 * perSide` relationship
/// `plate_calculator.dart` already uses, extracted here so weight-entry UI
/// can offer a "total vs. per side" toggle without duplicating the math.
library;

double perSideToTotal({required double perSideKg, required double barWeightKg}) =>
    barWeightKg + 2 * perSideKg;

double totalToPerSide({required double totalKg, required double barWeightKg}) =>
    (totalKg - barWeightKg) / 2;
