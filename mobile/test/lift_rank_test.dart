import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/lift_rank.dart';

void main() {
  // Male bench thresholds (PR ÷ bodyweight): 0.5, 0.75, 1.0, 1.5, 2.0 -- so
  // at 100 kg bodyweight: iron < 50 kg, bronze 50-75, silver 75-100,
  // gold 100-150, platinum 150-200, diamond 200-250, champion from 250.
  LiftRank bench(double kg) => rankLift(liftKey: 'bench', liftKg: kg, bodyweightKg: 100, isMale: true)!;

  group('rankLift', () {
    test('tiers follow the strength-standard thresholds', () {
      expect(bench(30).tier, RankTier.iron);
      expect(bench(50).tier, RankTier.bronze);
      expect(bench(80).tier, RankTier.silver);
      expect(bench(120).tier, RankTier.gold);
      expect(bench(160).tier, RankTier.platinum);
      expect(bench(210).tier, RankTier.diamond);
      expect(bench(250).tier, RankTier.champion);
    });

    test('each tier splits into III, II, I', () {
      // Gold spans 100-150 kg: III from 100, II from ~116.7, I from ~133.3.
      expect(bench(100).division, 3);
      expect(bench(120).division, 2);
      expect(bench(140).division, 1);
      expect(bench(149.5).division, 1);
    });

    test('knows the kilos to the next division, rounded up to a half', () {
      final rank = bench(120); // gold II; gold I from 133.33 kg
      expect(rank.kgToNext, 13.5);
      expect(rank.next, (RankTier.gold, 1));
      expect(rank.progress, closeTo(0.2, 1e-9));
      // Gold I leads into platinum III.
      expect(bench(140).next, (RankTier.platinum, 3));
    });

    test('champion is the top: no division, nothing next', () {
      final rank = bench(300);
      expect(rank.division, isNull);
      expect(rank.next, isNull);
      expect(rank.kgToNext, isNull);
    });

    test('no PR or no bodyweight, no rank', () {
      expect(rankLift(liftKey: 'bench', liftKg: 0, bodyweightKg: 80, isMale: true), isNull);
      expect(rankLift(liftKey: 'bench', liftKg: 80, bodyweightKg: 0, isMale: true), isNull);
      expect(rankLift(liftKey: 'curl', liftKg: 40, bodyweightKg: 80, isMale: true), isNull);
    });
  });

  test('tierStartRatio lists where each tier begins', () {
    double? start(RankTier tier) => tierStartRatio(liftKey: 'bench', tier: tier, isMale: true);
    expect([for (final tier in RankTier.values) start(tier)], [0.0, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5]);
    // ...and agrees with rankLift right at a boundary.
    expect(bench(100).tier, RankTier.gold);
    expect(bench(99.5).tier, RankTier.silver);
    expect(tierStartRatio(liftKey: 'curl', tier: RankTier.gold, isMale: true), isNull);
  });

  group('overallRank', () {
    test('averages the lifts and maps back to a rank', () {
      // gold II (score 10.2), silver III (6.2), platinum III (12.2) -> 9.53: gold III.
      final overall = overallRank([bench(120), bench(80), bench(160)])!;
      expect(overall.tier, RankTier.gold);
      expect(overall.division, 3);
      expect(overall.kgToNext, isNull);
    });

    test('score and fromScore are inverse', () {
      for (final kg in [30.0, 64.0, 99.0, 130.0, 175.0, 230.0]) {
        final rank = bench(kg);
        final back = LiftRank.fromScore(rank.score);
        expect((back.tier, back.division), (rank.tier, rank.division), reason: '$kg kg');
      }
      expect(LiftRank.fromScore(18).tier, RankTier.champion);
    });

    test('nothing ranked, nothing overall', () {
      expect(overallRank(const [null, null]), isNull);
    });
  });
}
