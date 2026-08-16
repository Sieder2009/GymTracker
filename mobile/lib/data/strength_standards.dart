/// Bodyweight-relative strength classification for a single lift (Bench
/// Press / Squat / Deadlift) — "how good is this PR, in plain terms?"
///
/// [dotsScore] answers a different question: it's a bodyweight-normalized
/// *ranking* number, built for comparing competitive powerlifters against
/// each other. It means nothing to someone who has never heard of
/// Wilks/DOTS — a bare "your DOTS is 287" doesn't tell an untrained lifter
/// whether that's good. This file answers the more useful everyday
/// question instead: "Intermediate, 62% of the way to Advanced" is legible
/// to anyone, no powerlifting-federation background required.
///
/// The thresholds below are a flat bodyweight-multiplier table (PR ÷
/// bodyweight), the same convention most public strength-standards
/// calculators use. They're a deliberately simple approximation, not a
/// scientific or federation-sanctioned figure — real relative strength
/// doesn't scale perfectly linearly with bodyweight (that non-linearity is
/// exactly why DOTS uses a polynomial instead). Good enough to say
/// "roughly intermediate," not precise enough to argue over a single kg.
library;

enum StrengthLevel { beginner, novice, intermediate, advanced, elite }

class StrengthStandardResult {
  const StrengthStandardResult({
    required this.ratio,
    required this.level,
    required this.nextLevel,
    required this.progressToNext,
  });

  /// PR ÷ bodyweight, e.g. 1.5 for a 120kg squat at 80kg bodyweight.
  final double ratio;
  final StrengthLevel level;

  /// Null once [level] is already [StrengthLevel.elite].
  final StrengthLevel? nextLevel;

  /// 0..1 progress from [level]'s threshold toward [nextLevel]'s — for a
  /// progress bar. 1.0 (nothing left to show) when already elite.
  final double progressToNext;
}

// Ratio thresholds per level, lowest to highest. Index 0 ("beginner") is
// intentionally a low floor (someone who just started training), not zero
// — a ratio below it still classifies as "beginner" with 0 progress rather
// than needing a separate "untrained" tier nobody finds motivating to see.
const Map<String, List<double>> _kMaleThresholds = {
  'bench': [0.5, 0.75, 1.0, 1.5, 2.0],
  'squat': [0.5, 0.75, 1.25, 1.75, 2.25],
  'deadlift': [0.75, 1.0, 1.5, 2.0, 2.5],
};

const Map<String, List<double>> _kFemaleThresholds = {
  'bench': [0.25, 0.35, 0.5, 0.75, 1.15],
  'squat': [0.35, 0.5, 0.75, 1.25, 1.75],
  'deadlift': [0.5, 0.75, 1.0, 1.5, 2.0],
};

const List<StrengthLevel> _kLevels = [
  StrengthLevel.beginner,
  StrengthLevel.novice,
  StrengthLevel.intermediate,
  StrengthLevel.advanced,
  StrengthLevel.elite,
];

/// Null when [liftKg] or [bodyweightKg] isn't usable yet (mirrors how
/// [dotsScore] callers already handle "not enough data" — see
/// StrengthScreen's `_PowerliftingScoreCard`/`_LiftCard`).
StrengthStandardResult? classifyLift({
  required String liftKey,
  required double liftKg,
  required double bodyweightKg,
  required bool isMale,
}) {
  if (liftKg <= 0 || bodyweightKg <= 0) return null;
  final thresholds = (isMale ? _kMaleThresholds : _kFemaleThresholds)[liftKey];
  if (thresholds == null) return null;

  final ratio = liftKg / bodyweightKg;

  var levelIndex = 0;
  for (var i = 0; i < thresholds.length; i++) {
    if (ratio >= thresholds[i]) levelIndex = i;
  }

  final isElite = levelIndex == thresholds.length - 1;
  final nextLevel = isElite ? null : _kLevels[levelIndex + 1];
  final progress = isElite
      ? 1.0
      : ((ratio - thresholds[levelIndex]) / (thresholds[levelIndex + 1] - thresholds[levelIndex]))
          .clamp(0.0, 1.0);

  return StrengthStandardResult(
    ratio: ratio,
    level: _kLevels[levelIndex],
    nextLevel: nextLevel,
    progressToNext: progress,
  );
}
