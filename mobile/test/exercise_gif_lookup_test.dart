import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/exercise_gif_lookup.dart';
import 'package:ironpeak_mobile/data/exercise_gifs.dart';
import 'package:ironpeak_mobile/models/exercise_template.dart';

/// Expectations are read from kExerciseGifs rather than hardcoded, and the
/// "no animation" cases use synthetic ids, so these keep passing when the
/// mapping file is regenerated with hundreds of entries.
void main() {
  final benchGif = kExerciseGifs['bench_press']!;
  const bench = ExerciseTemplate(id: 'bench_press', name: 'Bankdrücken', category: 'chest');
  const unmapped = ExerciseTemplate(id: 'zz_not_real', name: 'Erfundene Übung', category: 'core');

  group('normalizeExerciseName', () {
    test('trims, lowercases and collapses whitespace', () {
      expect(normalizeExerciseName('  Bank   DRÜCKEN\t(eng) '), 'bank drücken (eng)');
    });
  });

  group('isValidExerciseGifBasename', () {
    test('accepts dataset basenames only', () {
      expect(isValidExerciseGifBasename('0025-EIeI8Vf'), isTrue);
      expect(isValidExerciseGifBasename('25-EIeI8Vf'), isFalse);
      expect(isValidExerciseGifBasename('0025-EIeI8V'), isFalse);
      expect(isValidExerciseGifBasename('../0025-EIeI8Vf'), isFalse);
      expect(isValidExerciseGifBasename(''), isFalse);
    });
  });

  group('exerciseGifForTemplate', () {
    test('mapped id -> its animation, unmapped/custom -> null', () {
      expect(exerciseGifForTemplate(bench), benchGif);
      expect(exerciseGifForTemplate(unmapped), isNull);
      expect(
          exerciseGifForTemplate(const ExerciseTemplate(id: 'custom:1', name: 'Bankdrücken', category: 'chest')),
          isNull);
    });
  });

  group('exerciseGifForName', () {
    test('matches the template name after normalization', () {
      expect(exerciseGifForName('Bankdrücken', [unmapped, bench]), benchGif);
      expect(exerciseGifForName('  BANKDRÜCKEN ', [unmapped, bench]), benchGif);
    });

    test('matches the id read as words', () {
      expect(exerciseGifForName('bench press', [bench]), benchGif);
      expect(exerciseGifForName('Bench   Press', [bench]), benchGif);
    });

    test('unknown, unmapped, empty or partial names -> null', () {
      expect(exerciseGifForName('Meine eigene Übung', [unmapped, bench]), isNull);
      expect(exerciseGifForName('Erfundene Übung', [unmapped, bench]), isNull);
      expect(exerciseGifForName('zz not real', [unmapped, bench]), isNull);
      expect(exerciseGifForName('Bankdrücken (eng)', [bench]), isNull);
      expect(exerciseGifForName('   ', [bench]), isNull);
      expect(exerciseGifForName('Bankdrücken', const []), isNull);
    });

    test('memoized index follows a changed template list', () {
      const renamed = ExerciseTemplate(id: 'bench_press', name: 'Flachbank', category: 'chest');
      expect(exerciseGifForName('Bankdrücken', [bench]), benchGif);
      // New list, different content: the old name must stop matching.
      expect(exerciseGifForName('Bankdrücken', [renamed]), isNull);
      expect(exerciseGifForName('Flachbank', [renamed]), benchGif);
      // New list instance with the same elements still works.
      expect(exerciseGifForName('Bankdrücken', List.unmodifiable([bench])), benchGif);
      // The same growable list mutated in place is noticed too.
      final list = <ExerciseTemplate>[unmapped];
      expect(exerciseGifForName('Bankdrücken', list), isNull);
      list.add(bench);
      expect(exerciseGifForName('Bankdrücken', list), benchGif);
    });
  });
}
