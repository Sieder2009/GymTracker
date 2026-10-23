import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/models/muscle_group.dart';
import 'package:ironpeak_mobile/widgets/detailed_body_diagram.dart';

void main() {
  group('activationShares', () {
    int sum(Map<MuscleGroup, int> shares) => shares.values.fold(0, (s, v) => s + v);

    test('turns intensities into shares that add up to exactly 100', () {
      // Bench press: 100 + 40 + 40 would read as "180 %".
      expect(
        activationShares(const {
          MuscleGroup.chest: 100,
          MuscleGroup.frontDelts: 40,
          MuscleGroup.triceps: 40,
        }),
        {MuscleGroup.chest: 56, MuscleGroup.frontDelts: 22, MuscleGroup.triceps: 22},
      );
      final thirds = activationShares(const {
        MuscleGroup.quads: 50,
        MuscleGroup.glutes: 50,
        MuscleGroup.hamstrings: 50,
      });
      expect(sum(thirds), 100);
      expect(thirds.values, everyElement(inInclusiveRange(33, 34)));
    });

    test('leaves out unworked muscles; nothing worked is empty', () {
      expect(
        activationShares(const {MuscleGroup.biceps: 80, MuscleGroup.forearms: 0}),
        {MuscleGroup.biceps: 100},
      );
      expect(activationShares(const {}), isEmpty);
    });
  });

  group('preferFrontView', () {
    test('opens on the side of the hardest-worked muscle', () {
      // Squats: the back adds up to more, but the quads do the most work.
      expect(
        preferFrontView(const {
          MuscleGroup.quads: 90,
          MuscleGroup.glutes: 60,
          MuscleGroup.lowerBack: 30,
          MuscleGroup.hamstrings: 20,
        }),
        isTrue,
      );
      expect(
        preferFrontView(const {MuscleGroup.lats: 100, MuscleGroup.biceps: 50}),
        isFalse,
      );
    });

    test('a tied peak goes to the bigger total, a full tie to the front', () {
      expect(
        preferFrontView(const {
          MuscleGroup.chest: 60,
          MuscleGroup.triceps: 60,
          MuscleGroup.rearDelts: 30,
        }),
        isFalse,
      );
      expect(preferFrontView(const {}), isTrue);
    });
  });
}
