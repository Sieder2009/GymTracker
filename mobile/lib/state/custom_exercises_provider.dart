import 'package:flutter/foundation.dart';

import '../models/custom_exercise.dart';
import '../models/exercise_template.dart';
import '../models/muscle_group.dart';
import '../services/storage_service.dart';

const String _kCustomExercisesKey = 'ironpeak:customExercises';

/// User-authored exercises the app remembers and offers everywhere the
/// shared GitHub-sourced database does (search, plan editor's exercise
/// picker) -- the fix for custom exercises previously being a one-off
/// free-text field that vanished into a single plan with no way to reuse
/// it, or its configured muscles, anywhere else.
class CustomExercisesProvider extends ChangeNotifier {
  CustomExercisesProvider(this._storage) : _items = _initial(_storage);

  final StorageService _storage;
  final List<CustomExercise> _items;

  List<CustomExercise> get items => List.unmodifiable(_items);

  /// The same shape [ExerciseDatabaseProvider.exercises] exposes, so
  /// callers (the exercise list/picker) can simply concatenate both lists.
  List<ExerciseTemplate> get templates => [for (final c in _items) c.template];

  static List<CustomExercise> _initial(StorageService storage) {
    final decoded = storage.readJson<List<CustomExercise>>(
      _kCustomExercisesKey,
      (raw) => (raw as List)
          .map((e) => CustomExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return decoded ?? [];
  }

  void _persist() {
    _storage.writeJson(
      _kCustomExercisesKey,
      () => _items.map((c) => c.toJson()).toList(),
    );
  }

  /// Fine-grained activation configured for a custom exercise id, or null
  /// if it has none (falls back to the category default like any other
  /// unrecognized id) -- null is also returned for a non-custom id.
  Map<MuscleGroup, double>? activationFor(String id) {
    for (final c in _items) {
      if (c.template.id == id) return c.activation;
    }
    return null;
  }

  /// Guarantees a unique id even across two calls within the same
  /// millisecond -- a bare timestamp collided in testing when two `add`s
  /// fired back-to-back with no `await` between them.
  int _idSequence = 0;

  void add(String name, String category,
      {Map<MuscleGroup, double>? activation}) {
    final id =
        'custom:${DateTime.now().millisecondsSinceEpoch}_${_idSequence++}';
    _items.add(CustomExercise(
      template: ExerciseTemplate(id: id, name: name, category: category),
      activation: activation,
    ));
    _persist();
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((c) => c.template.id == id);
    _persist();
    notifyListeners();
  }
}
