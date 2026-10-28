import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/analytics/progression_engine.dart';
import 'package:ironpeak_mobile/l10n/app_localizations.dart';
import 'package:ironpeak_mobile/models/exercise.dart';
import 'package:ironpeak_mobile/models/exercise_log_mode.dart';
import 'package:ironpeak_mobile/models/exercise_set.dart';
import 'package:ironpeak_mobile/models/history_entry.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:ironpeak_mobile/widgets/progression_notice.dart';

void main() {
  Exercise exercise(
    String reps,
    List<HistoryEntry> history, {
    String muscle = 'chest',
    double weight = 50,
    bool unilateral = false,
  }) =>
      Exercise.fresh('Bench Press', muscle, 90, [ExerciseSet(w: weight, r: reps)],
          history: history, unilateral: unilateral);

  group('suggestNextSession', () {
    test('no suggestion without any logged history', () {
      expect(suggestNextSession(exercise('8-10', [])), isNull);
    });

    test('no suggestion when the rep field has no numeric target', () {
      final ex = exercise('AMRAP', [HistoryEntry(weight: 50, reps: [10, 10])]);
      expect(suggestNextSession(ex), isNull);
    });

    test('no suggestion when the last session logged only markers', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: ['✓', 'x'])]);
      expect(suggestNextSession(ex), isNull);
    });

    test('a few reps short of the target holds the weight and asks for one more rep per set', () {
      // 100 kg for 8 and 7 with a target of 10: keep going at 100 kg.
      final ex = exercise('10', [HistoryEntry(weight: 100, reps: [8, 7])], weight: 100);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.holdWeight);
      expect(s.weightKg, 100);
      expect(s.lastReps, [8, 7]);
      expect(s.target, '10');
      expect(s.nextReps, [9, 8]);
    });

    test('the same few reps short twice in a row still holds -- no lighter weight', () {
      final ex = exercise('10', [
        HistoryEntry(weight: 100, reps: [8, 7]),
        HistoryEntry(weight: 100, reps: [8, 7]),
      ], weight: 100);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.holdWeight);
      expect(s.weightKg, 100);
    });

    test('every set at or above the top of the range -> increase weight by 2.5kg', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [10, 10, 10])]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseWeight);
      expect(s.weightKg, 52.5);
      expect(s.lastWeightKg, 50);
      expect(s.target, '8-10');
      expect(s.nextReps, isEmpty);
    });

    test('leg exercises get a 5kg jump on a clean clear', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 100, reps: [10, 10])], muscle: 'legs', weight: 100);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseWeight);
      expect(s.weightKg, 105);
    });

    test('a fixed (non-range) rep target of "5" also clears at 5', () {
      final ex = exercise('5', [HistoryEntry(weight: 50, reps: [5, 5, 5])]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseWeight);
    });

    test('inside the range but short of the top -> same weight, one more rep per set', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [9, 8, 8])]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.holdWeight);
      expect(s.weightKg, 50);
      expect(s.nextReps, [10, 9, 9]);
    });

    test('a set already at the top of the range stays there', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [10, 9, 8])]);
      expect(suggestNextSession(ex)!.nextReps, [10, 10, 9]);
    });

    test('empty sets (saved as 0) are left out, so they never block a clear', () {
      final ex = exercise('8-10', [HistoryEntry(weight: 50, reps: [10, 10, 0])]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.increaseWeight);
      expect(s.lastReps, [10, 10]);
    });

    test('each set is judged against its own planned target', () {
      Exercise pyramid(List<Object> reps) => Exercise.fresh('Bench Press', 'chest', 90, [
            ExerciseSet(w: 80, r: '5'),
            ExerciseSet(w: 80, r: '8'),
            ExerciseSet(w: 80, r: '12'),
          ], history: [HistoryEntry(weight: 80, reps: reps)]);

      expect(suggestNextSession(pyramid([5, 8, 12]))!.action, ProgressionAction.increaseWeight);
      final s = suggestNextSession(pyramid([5, 8, 10]))!;
      expect(s.action, ProgressionAction.holdWeight);
      expect(s.nextReps, [5, 8, 11]);
    });

    test('one clearly-too-heavy session still holds the weight', () {
      final ex = exercise('8-10', [
        HistoryEntry(weight: 50, reps: [10, 10]),
        HistoryEntry(weight: 50, reps: [5, 5]),
      ]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.holdWeight);
      expect(s.nextReps, [6, 6]);
    });

    test('two clearly-too-heavy sessions in a row -> the weight that fits the target', () {
      final ex = exercise('8-10', [
        HistoryEntry(weight: 100, reps: [5, 5]),
        HistoryEntry(weight: 100, reps: [5, 4]),
      ], weight: 100);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.reduceWeight);
      // Epley: 100 x 5 ~ 116.7 kg 1RM -> ~92.1 kg for 8 reps -> 90 kg.
      expect(s.weightKg, 90);
      expect(s.lastReps, [5, 4]);
    });

    test('a lighter weight is always a real step down', () {
      // 4 reps under a floor of 8 at 50 kg -> 42.5 kg by Epley.
      final ex = exercise('8-10', [
        HistoryEntry(weight: 50, reps: [5, 5]),
        HistoryEntry(weight: 50, reps: [4, 4]),
      ]);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.reduceWeight);
      expect(s.weightKg, 42.5);
    });

    test('a prior session that only has markers does not count toward a lighter weight', () {
      final ex = exercise('8-10', [
        HistoryEntry(weight: 50, reps: ['✓']),
        HistoryEntry(weight: 50, reps: [5, 5]),
      ]);
      expect(suggestNextSession(ex)!.action, ProgressionAction.holdWeight);
    });

    test('a bilateral exercise counts up one rep at a time', () {
      final ex = exercise('8-20', [HistoryEntry(weight: 50, reps: [16, 14, 12])]);
      final s = suggestNextSession(ex)!;
      expect(s.unilateral, isFalse);
      expect(s.nextReps, [17, 15, 13]);
    });

    test('a unilateral exercise aims for even totals on every set', () {
      final ex = exercise('8-20', [HistoryEntry(weight: 50, reps: [16, 14, 12])], unilateral: true);
      final s = suggestNextSession(ex)!;
      expect(s.action, ProgressionAction.holdWeight);
      expect(s.unilateral, isTrue);
      // 17/15/13 snap up to the next even total, so both sides get the same.
      expect(s.nextReps, [18, 16, 14]);
      expect(s.nextReps.every((r) => r.isEven), isTrue);
    });

    test('a unilateral exercise increase or lighter weight uses the same math', () {
      final up = exercise('8-10', [HistoryEntry(weight: 50, reps: [10, 10, 10])], unilateral: true);
      expect(suggestNextSession(up)!.weightKg, 52.5);
      final down = exercise('8-10', [
        HistoryEntry(weight: 50, reps: [5, 5]),
        HistoryEntry(weight: 50, reps: [4, 4]),
      ], unilateral: true);
      expect(suggestNextSession(down)!.weightKg, 42.5);
    });

    test('returns null for a Timed exercise even with rich, clearly-clearing history', () {
      final ex = Exercise.fresh(
        'Plank',
        'core',
        60,
        [ExerciseSet(w: 20, r: '8-10')],
        history: [
          HistoryEntry(weight: 20, reps: [10, 10, 10]),
        ],
        logMode: ExerciseLogMode.timed,
      );
      expect(suggestNextSession(ex), isNull);
    });

    test('returns null for a Cardio exercise even with rich, clearly-clearing history', () {
      final ex = Exercise.fresh(
        'Treadmill',
        '',
        0,
        [ExerciseSet(w: 0, r: '8-10')],
        history: [
          HistoryEntry(weight: 0, reps: [10, 10, 10]),
        ],
        logMode: ExerciseLogMode.cardio,
      );
      expect(suggestNextSession(ex), isNull);
    });
  });

  group('ProgressionNotice', () {
    Future<String> sentence(WidgetTester tester, Exercise ex) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Scaffold(body: ProgressionNotice(suggestion: suggestNextSession(ex)!, compact: true)),
      ));
      await tester.pumpAndSettle();
      return tester.widget<Text>(find.byType(Text)).data!;
    }

    testWidgets('says why the weight stays, with last time, the target and the next reps', (tester) async {
      final ex = exercise('10', [HistoryEntry(weight: 100, reps: [8, 7])], weight: 100);
      expect(await sentence(tester, ex),
          'Bleib bei 100,0 kg. Letztes Mal 8 · 7, Ziel 10 — versuch nächstes Mal 9 · 8.');
    });

    testWidgets('names the reps that earned more weight', (tester) async {
      final ex = exercise('8-10', [HistoryEntry(weight: 100, reps: [10, 10, 10])], weight: 100);
      expect(await sentence(tester, ex),
          'Ziel geschafft (10 · 10 · 10 bei 100,0 kg) — nächstes Mal 102,5 kg, Ziel wieder 8-10 Wdh.');
    });

    testWidgets('a unilateral hold also shows the per-side split', (tester) async {
      final ex = exercise('8-12', [HistoryEntry(weight: 20, reps: [10, 9])], weight: 20, unilateral: true);
      expect(await sentence(tester, ex),
          'Bleib bei 20,0 kg. Letztes Mal 10 · 9, Ziel 8-12 — versuch nächstes Mal 12 · 10 '
          '(beide Seiten zusammen, 6 · 5 pro Seite).');
    });
  });
}
