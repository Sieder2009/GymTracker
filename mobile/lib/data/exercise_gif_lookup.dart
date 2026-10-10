import '../models/exercise_template.dart';
import 'exercise_gifs.dart';

/// Shape of every media basename in the exercises dataset (`0025-EIeI8Vf`):
/// four digits, a dash, seven alphanumerics. Checked before a basename is
/// ever turned into a URL or a cache file name, so a malformed map entry
/// can't produce a path like `../x`.
final RegExp _kBasenamePattern = RegExp(r'^\d{4}-[A-Za-z0-9]{7}$');

bool isValidExerciseGifBasename(String basename) =>
    _kBasenamePattern.hasMatch(basename);

/// Trimmed, lowercased, inner whitespace collapsed to single spaces -- the
/// only fuzziness [exerciseGifForName] allows. Everything else (umlauts,
/// punctuation, word order) must match exactly.
String normalizeExerciseName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String? _validated(String? basename) =>
    basename != null && isValidExerciseGifBasename(basename) ? basename : null;

/// The animation for an entry of the shared exercise database, or null when
/// it has none (custom exercises, ids not in [kExerciseGifs]).
String? exerciseGifForTemplate(ExerciseTemplate template) =>
    _validated(kExerciseGifs[template.id]);

/// The animation for a plan exercise, which is linked to the shared
/// database only by its name (see `exercise_template.dart`): [name] must
/// match a template's name, or its id read as words (`bench_press` ->
/// "bench press"), after [normalizeExerciseName]. Anything renamed, custom
/// or CSV-imported under a name the database doesn't know gets null, which
/// callers treat as "no animation" rather than an error.
String? exerciseGifForName(String name, List<ExerciseTemplate> templates) {
  final key = normalizeExerciseName(name);
  if (key.isEmpty) return null;
  return _indexFor(templates)[key];
}

// One-slot memo of the normalized-name index. Keyed on the template list's
// *elements* rather than the list object: `ExerciseDatabaseProvider
// .exercises` hands out a fresh `List.unmodifiable` copy on every call, so
// list identity alone would never hit, and the guided workout screen asks
// once per second. The provider only ever swaps in freshly parsed
// templates, so "same length, every element identical" means "same
// database" -- a cheap pointer comparison per entry (which also notices a
// list changed in place), versus re-normalizing ~550 names.
List<ExerciseTemplate> _indexedElements = const [];
Map<String, String> _index = const {};

Map<String, String> _indexFor(List<ExerciseTemplate> templates) {
  if (!_sameElements(templates)) {
    _index = _buildIndex(templates);
    _indexedElements = List.of(templates, growable: false);
  }
  return _index;
}

bool _sameElements(List<ExerciseTemplate> templates) {
  if (templates.length != _indexedElements.length) return false;
  for (var i = 0; i < templates.length; i++) {
    if (!identical(templates[i], _indexedElements[i])) return false;
  }
  return true;
}

/// Normalized name -> basename, holding only templates that actually have
/// an animation. Real names are indexed before the ids-as-words, so a real
/// name always wins over another template's id that happens to read the
/// same; within each pass the first template wins.
Map<String, String> _buildIndex(List<ExerciseTemplate> templates) {
  final index = <String, String>{};
  for (final t in templates) {
    final gif = exerciseGifForTemplate(t);
    if (gif != null) index.putIfAbsent(normalizeExerciseName(t.name), () => gif);
  }
  for (final t in templates) {
    final gif = exerciseGifForTemplate(t);
    if (gif != null) {
      index.putIfAbsent(normalizeExerciseName(t.id.replaceAll('_', ' ')), () => gif);
    }
  }
  index.remove('');
  return index;
}
