/// Maps a free-text exercise name to one of the "big three" lift keys used
/// by [BigLiftsProvider] (`bench`/`deadlift`/`squat`). Anchored at `^` so
/// grip/stance variants like "Bankdrücken (eng)" match while accessory
/// lifts merely containing the word (e.g. "Hack Squat") do not.
///
/// Shared by [ProgressScreen] (matching logged exercises against the big
/// three for the "start to now" list) and the guided workout's PR bridge
/// (matching a just-finished exercise against the big three to also update
/// [BigLiftsProvider], so a bench-press PR set during a guided session
/// shows up in both places).
library;

final RegExp bigThreePattern = RegExp(
  r'^(bench\s*press|bankdrücken|deadlift|kreuzheben|squats?)\b',
  caseSensitive: false,
);

class LiftCategory {
  const LiftCategory(this.key, this.pattern);

  /// Matches [BigLifts.byKey]'s key.
  final String key;
  final RegExp pattern;
}

final List<LiftCategory> liftCategories = [
  LiftCategory(
      'deadlift', RegExp(r'^(deadlift|kreuzheben)\b', caseSensitive: false)),
  LiftCategory(
      'bench', RegExp(r'^(bench\s*press|bankdrücken)\b', caseSensitive: false)),
  LiftCategory('squat', RegExp(r'^squats?\b', caseSensitive: false)),
];

LiftCategory? liftCategoryForName(String name) {
  for (final cat in liftCategories) {
    if (cat.pattern.hasMatch(name)) return cat;
  }
  return null;
}
