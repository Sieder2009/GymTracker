import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/data/calorie_calculator.dart';

void main() {
  group('basalMetabolicRate', () {
    test('returns 0 for non-positive weight, height, or age', () {
      expect(basalMetabolicRate(weightKg: 0, heightCm: 180, age: 30, isMale: true), 0);
      expect(basalMetabolicRate(weightKg: 80, heightCm: 0, age: 30, isMale: true), 0);
      expect(basalMetabolicRate(weightKg: 80, heightCm: 180, age: 0, isMale: true), 0);
    });

    test('Mifflin-St Jeor for a male', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5
      expect(basalMetabolicRate(weightKg: 80, heightCm: 180, age: 30, isMale: true), 1780);
    });

    test('Mifflin-St Jeor for a female', () {
      // 10*80 + 6.25*180 - 5*30 - 161 = 800 + 1125 - 150 - 161
      expect(basalMetabolicRate(weightKg: 80, heightCm: 180, age: 30, isMale: false), 1614);
    });

    test('the male/female offset is a constant 166kcal for identical inputs', () {
      final male = basalMetabolicRate(weightKg: 65, heightCm: 165, age: 45, isMale: true);
      final female = basalMetabolicRate(weightKg: 65, heightCm: 165, age: 45, isMale: false);
      expect(male - female, closeTo(166, 0.001));
    });
  });

  group('totalDailyEnergyExpenditure', () {
    test('returns 0 for a non-positive BMR', () {
      expect(totalDailyEnergyExpenditure(bmr: 0, activity: ActivityLevel.moderate), 0);
    });

    test('a more active level scales the same BMR higher', () {
      const bmr = 1600.0;
      final sedentary = totalDailyEnergyExpenditure(bmr: bmr, activity: ActivityLevel.sedentary);
      final veryActive = totalDailyEnergyExpenditure(bmr: bmr, activity: ActivityLevel.veryActive);
      expect(veryActive, greaterThan(sedentary));
    });
  });

  group('macroTargets', () {
    test('returns all-zero targets for non-positive weight or TDEE', () {
      final byWeight = macroTargets(weightKg: 0, tdee: 2500, goal: CalorieGoal.maintain);
      final byTdee = macroTargets(weightKg: 80, tdee: 0, goal: CalorieGoal.maintain);
      expect(byWeight.calories, 0);
      expect(byTdee.calories, 0);
    });

    test('a surplus goal targets more calories than a deficit goal at the same TDEE', () {
      const tdee = 2500.0;
      final lose = macroTargets(weightKg: 80, tdee: tdee, goal: CalorieGoal.lose);
      final gain = macroTargets(weightKg: 80, tdee: tdee, goal: CalorieGoal.gain);
      expect(gain.calories, greaterThan(lose.calories));
    });

    test('protein per kg is higher on a cut than at maintenance', () {
      final lose = macroTargets(weightKg: 80, tdee: 2500, goal: CalorieGoal.lose);
      final maintain = macroTargets(weightKg: 80, tdee: 2500, goal: CalorieGoal.maintain);
      expect(lose.proteinG, greaterThan(maintain.proteinG));
    });

    test('protein + carbs + fat account for the full calorie target', () {
      final result = macroTargets(weightKg: 75, tdee: 2400, goal: CalorieGoal.maintain);
      final rebuilt = result.proteinG * 4 + result.carbsG * 4 + result.fatG * 9;
      expect(rebuilt, closeTo(result.calories, 0.01));
    });

    test('carbs never go negative even if protein alone would exceed the target', () {
      // 300kg at "lose" -> 300*2.2 = 660g protein -> 2640kcal from protein
      // alone, well above a deliberately tiny TDEE.
      final result = macroTargets(weightKg: 300, tdee: 50, goal: CalorieGoal.lose);
      expect(result.carbsG, 0);
    });
  });
}
