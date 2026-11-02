/// The seven broad categories every exercise belongs to: the shared exercise
/// database's `category` values, and what a plan's [Exercise.muscle] holds
/// when set (the plan editors' "muscle group" dropdown). Plain data, so
/// services can use it without importing a widget.
const List<String> kExerciseCategories = [
  'chest',
  'back',
  'shoulders',
  'legs',
  'arms',
  'core',
  'cardio',
];
