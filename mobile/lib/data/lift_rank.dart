import 'dart:math' as math;

import 'strength_standards.dart';

/// A game-style rank for the big three, built on the same bodyweight-
/// relative standards as [classifyLift] (PR ÷ bodyweight): each tier spans
/// one gap between two level thresholds and splits into three divisions,
/// III (lowest) to I. Iron sits below the beginner threshold; diamond spans
/// from the elite threshold as far again as the step below it; anything
/// above that is champion, which has no divisions.
///
/// The names are internal; users see epic titles instead, the same in every
/// language -- Mortal, Warrior, Spartan, Hero, Demigod, Titan, Olympian (see
/// `rankLabel`) -- on crystal badges with a symbol from Greek myth each
/// (`RankEmblem`).
enum RankTier { iron, bronze, silver, gold, platinum, diamond, champion }

class LiftRank {
  const LiftRank({
    required this.tier,
    required this.division,
    required this.progress,
    required this.kgToNext,
  });

  final RankTier tier;

  /// 3, 2 or 1 (I is the best); null for [RankTier.champion].
  final int? division;

  /// 0..1 through the current division toward the next one; 1 for champion.
  final double progress;

  /// Kilograms still missing to the next division (null for champion).
  final double? kgToNext;

  /// The rank after this one -- (tier, division) -- or null for champion.
  (RankTier, int?)? get next {
    final division = this.division;
    if (division == null) return null;
    if (division > 1) return (tier, division - 1);
    final nextTier = RankTier.values[tier.index + 1];
    return (nextTier, nextTier == RankTier.champion ? null : 3);
  }

  /// A single number for averaging ranks: 0 at iron III, +1 per division,
  /// plus the progress through it (champion = 18).
  double get score {
    final division = this.division;
    if (division == null) return RankTier.champion.index * 3.0;
    return tier.index * 3.0 + (3 - division) + progress;
  }

  /// The rank a [score] stands for (inverse of [score], progress kept).
  factory LiftRank.fromScore(double score) {
    final clamped = score.clamp(0.0, RankTier.champion.index * 3.0);
    if (clamped >= RankTier.champion.index * 3.0) {
      return const LiftRank(tier: RankTier.champion, division: null, progress: 1, kgToNext: null);
    }
    final step = clamped.floor();
    return LiftRank(
      tier: RankTier.values[step ~/ 3],
      division: 3 - step % 3,
      progress: clamped - step,
      kgToNext: null,
    );
  }
}

/// Where each tier starts as PR ÷ bodyweight, iron (0) to champion: one
/// tier per threshold gap, diamond as wide as the platinum step before it.
/// Null for a lift without standards.
List<double>? _tierStarts(String liftKey, bool isMale) {
  final t = strengthThresholds(liftKey: liftKey, isMale: isMale);
  if (t == null || t.length < 5) return null;
  return [0.0, ...t, t[4] + (t[4] - t[3])];
}

/// PR ÷ bodyweight at which [tier] (its division III) starts -- 0 for
/// iron; null for a lift without standards.
double? tierStartRatio({required String liftKey, required RankTier tier, required bool isMale}) =>
    _tierStarts(liftKey, isMale)?[tier.index];

/// Null without a PR, a bodyweight, or standards for [liftKey].
LiftRank? rankLift({
  required String liftKey,
  required double liftKg,
  required double bodyweightKg,
  required bool isMale,
}) {
  if (liftKg <= 0 || bodyweightKg <= 0) return null;
  final bounds = _tierStarts(liftKey, isMale);
  if (bounds == null) return null;
  final ratio = liftKg / bodyweightKg;
  if (ratio >= bounds.last) {
    return const LiftRank(tier: RankTier.champion, division: null, progress: 1, kgToNext: null);
  }
  var tier = 0;
  while (ratio >= bounds[tier + 1]) {
    tier++;
  }
  final lo = bounds[tier];
  final span = (bounds[tier + 1] - lo) / 3;
  final step = math.min(2, ((ratio - lo) / span).floor());
  final nextAt = lo + (step + 1) * span;
  return LiftRank(
    tier: RankTier.values[tier],
    division: 3 - step,
    progress: ((ratio - (lo + step * span)) / span).clamp(0.0, 1.0),
    // Up to the next half kilo a plate setup can actually load.
    kgToNext: math.max(0.5, ((nextAt * bodyweightKg - liftKg) * 2).ceil() / 2),
  );
}

/// The overall rank: the average of the lifts' ranks ([LiftRank.score]),
/// or null when none is ranked yet.
LiftRank? overallRank(Iterable<LiftRank?> ranks) {
  final ranked = ranks.whereType<LiftRank>().toList();
  if (ranked.isEmpty) return null;
  return LiftRank.fromScore(ranked.fold(0.0, (sum, r) => sum + r.score) / ranked.length);
}
