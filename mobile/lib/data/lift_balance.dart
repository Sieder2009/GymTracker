/// "Are your three lifts proportionate to each other?" — a quick read
/// using commonly-cited powerlifting ratio guidelines (bench press
/// typically lands around 0.65-0.85x squat, deadlift around 1.1-1.35x
/// squat) as a rough reference band, the same "useful approximation, not
/// a scientific claim" spirit as [classifyLift] in strength_standards.dart.
/// Only meaningful once all three PRs are actually logged — a single
/// missing lift makes every ratio meaningless, not just imprecise.
library;

enum LiftBalanceFlag { low, balanced, high }

class LiftBalanceResult {
  const LiftBalanceResult({
    required this.benchToSquat,
    required this.deadliftToSquat,
    required this.benchFlag,
    required this.deadliftFlag,
  });

  final double benchToSquat;
  final double deadliftToSquat;
  final LiftBalanceFlag benchFlag;
  final LiftBalanceFlag deadliftFlag;
}

const double _kBenchToSquatLow = 0.65;
const double _kBenchToSquatHigh = 0.85;
const double _kDeadliftToSquatLow = 1.1;
const double _kDeadliftToSquatHigh = 1.35;

LiftBalanceFlag _flag(double ratio, double low, double high) {
  if (ratio < low) return LiftBalanceFlag.low;
  if (ratio > high) return LiftBalanceFlag.high;
  return LiftBalanceFlag.balanced;
}

/// Null when any of the three PRs isn't logged yet (or is 0) — a ratio
/// against a missing lift isn't a "rough estimate", it's meaningless.
LiftBalanceResult? computeLiftBalance({
  required double benchPr,
  required double squatPr,
  required double deadliftPr,
}) {
  if (benchPr <= 0 || squatPr <= 0 || deadliftPr <= 0) return null;

  final benchRatio = benchPr / squatPr;
  final deadliftRatio = deadliftPr / squatPr;

  return LiftBalanceResult(
    benchToSquat: benchRatio,
    deadliftToSquat: deadliftRatio,
    benchFlag: _flag(benchRatio, _kBenchToSquatLow, _kBenchToSquatHigh),
    deadliftFlag: _flag(deadliftRatio, _kDeadliftToSquatLow, _kDeadliftToSquatHigh),
  );
}
