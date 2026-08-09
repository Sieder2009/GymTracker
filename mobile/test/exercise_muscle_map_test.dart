import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/exercise_muscle_map.dart';
import 'package:ironpeak_mobile/models/exercise_template.dart';
import 'package:ironpeak_mobile/models/muscle_group.dart';

void main() {
  group('exerciseWorksMuscle', () {
    test('true when the exercise significantly activates the target muscle',
        () {
      const benchPress = ExerciseTemplate(
          id: 'bench_press', name: 'Bankdrücken', category: 'chest');
      expect(exerciseWorksMuscle(benchPress, MuscleGroup.chest), isTrue);
    });

    test('false for a muscle the exercise barely/never trains', () {
      const benchPress = ExerciseTemplate(
          id: 'bench_press', name: 'Bankdrücken', category: 'chest');
      expect(exerciseWorksMuscle(benchPress, MuscleGroup.calves), isFalse);
    });

    test('unrecognized id falls back to the category default', () {
      const unknown = ExerciseTemplate(
          id: 'custom:123', name: 'Meine Übung', category: 'legs');
      // legs' category default includes quads at a meaningful intensity.
      expect(exerciseWorksMuscle(unknown, MuscleGroup.quads), isTrue);
    });

    test('threshold can be tightened/loosened by the caller', () {
      const benchPress = ExerciseTemplate(
          id: 'bench_press', name: 'Bankdrücken', category: 'chest');
      expect(exerciseWorksMuscle(benchPress, MuscleGroup.triceps, threshold: 1),
          isTrue);
      expect(
          exerciseWorksMuscle(benchPress, MuscleGroup.triceps, threshold: 99),
          isFalse);
    });
  });
}
