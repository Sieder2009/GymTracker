/// DOTS score: a bodyweight-normalized powerlifting total, the modern
/// successor to Wilks (used by USA Powerlifting and others). Same
/// public-domain polynomial coefficients as the official calculators.
double dotsScore({required double bodyweightKg, required double totalKg, required bool isMale}) {
  if (bodyweightKg <= 0 || totalKg <= 0) return 0;
  final bw = bodyweightKg.clamp(isMale ? 40.0 : 40.0, isMale ? 210.0 : 150.0);
  final coeffs = isMale
      ? const [-307.75076, 24.0900756, -0.1918759221, 0.0007391293, -0.000001093]
      : const [-57.96288, 13.6175032, -0.1126655495, 0.0005158568, -0.0000010706];
  final denominator = coeffs[0] +
      coeffs[1] * bw +
      coeffs[2] * bw * bw +
      coeffs[3] * bw * bw * bw +
      coeffs[4] * bw * bw * bw * bw;
  if (denominator <= 0) return 0;
  return totalKg * 500 / denominator;
}

/// Epley formula: the standard, widely-used estimate of a one-rep max from
/// a lighter set taken close to failure. Returns the raw weight if reps<=1.
double estimateOneRepMax({required double weight, required int reps}) {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}
