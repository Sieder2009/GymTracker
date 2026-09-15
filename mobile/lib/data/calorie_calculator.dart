/// How active someone is outside of deliberate training -- the standard
/// PAL (physical activity level) multiplier scale used by most TDEE
/// calculators.
enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum CalorieGoal { lose, maintain, gain }

double _activityMultiplier(ActivityLevel level) => switch (level) {
      ActivityLevel.sedentary => 1.2,
      ActivityLevel.light => 1.375,
      ActivityLevel.moderate => 1.55,
      ActivityLevel.active => 1.725,
      ActivityLevel.veryActive => 1.9,
    };

double _goalCalorieMultiplier(CalorieGoal goal) => switch (goal) {
      CalorieGoal.lose => 0.8,
      CalorieGoal.maintain => 1.0,
      CalorieGoal.gain => 1.1,
    };

// Higher on [CalorieGoal.lose] than the other two -- more protein per kg is
// what protects muscle while eating in a deficit; there's no equivalent
// reason to go above the general-fitness baseline at maintenance or in a
// surplus.
double _proteinPerKg(CalorieGoal goal) => switch (goal) {
      CalorieGoal.lose => 2.2,
      CalorieGoal.maintain => 1.8,
      CalorieGoal.gain => 1.8,
    };

class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
}

/// Mifflin-St Jeor -- the BMR formula with the best accuracy for the
/// general population among the widely-used ones (better than the older
/// Harris-Benedict equation it replaced).
double basalMetabolicRate({
  required double weightKg,
  required double heightCm,
  required int age,
  required bool isMale,
}) {
  if (weightKg <= 0 || heightCm <= 0 || age <= 0) return 0;
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return isMale ? base + 5 : base - 161;
}

double totalDailyEnergyExpenditure({required double bmr, required ActivityLevel activity}) {
  if (bmr <= 0) return 0;
  return bmr * _activityMultiplier(activity);
}

/// Daily calorie + macro targets for [goal], built from [tdee]. Protein is
/// set per kg bodyweight (see [_proteinPerKg]), fat as 25% of target
/// calories, and carbs fill whatever's left -- the standard "protein and
/// fat first, carbs as the remainder" order most nutrition calculators use.
MacroTargets macroTargets({
  required double weightKg,
  required double tdee,
  required CalorieGoal goal,
}) {
  if (weightKg <= 0 || tdee <= 0) {
    return const MacroTargets(calories: 0, proteinG: 0, carbsG: 0, fatG: 0);
  }
  final calories = tdee * _goalCalorieMultiplier(goal);
  final proteinG = weightKg * _proteinPerKg(goal);
  final fatG = calories * 0.25 / 9;
  final rawCarbsG = (calories - proteinG * 4 - fatG * 9) / 4;
  return MacroTargets(
    calories: calories,
    proteinG: proteinG,
    carbsG: rawCarbsG < 0 ? 0 : rawCarbsG,
    fatG: fatG,
  );
}
