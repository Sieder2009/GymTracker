import 'exercise_template.dart';
import 'muscle_group.dart';

/// A user-authored exercise, reusable across every plan (unlike typing a
/// free-text name into a single plan's exercise row, which previously
/// vanished into just that one [Exercise] with no way to reuse it or its
/// configured muscles elsewhere). [template.id] is namespaced with a
/// `custom:` prefix so it can never collide with a GitHub-sourced id from
/// `assets/exercises.json` -- that matters because [_byId] in
/// `exercise_muscle_map.dart` is a `const` map keyed by exactly this
/// string; a collision would silently borrow another exercise's data.
class CustomExercise {
  CustomExercise({required this.template, this.activation});

  final ExerciseTemplate template;

  /// Fine-grained `MuscleGroup -> 0-100` override, or null to fall back to
  /// the category-level default the same way any unrecognized id already
  /// does via `muscleActivationForExercise`'s existing fallback chain.
  final Map<MuscleGroup, double>? activation;

  Map<String, dynamic> toJson() => {
        'id': template.id,
        'name': template.name,
        'category': template.category,
        if (activation != null)
          'activation': {
            for (final e in activation!.entries) e.key.name: e.value
          },
      };

  factory CustomExercise.fromJson(Map<String, dynamic> json) {
    final rawActivation = json['activation'] as Map<String, dynamic>?;
    return CustomExercise(
      template: ExerciseTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
      ),
      activation: rawActivation == null
          ? null
          : {
              for (final e in rawActivation.entries)
                if (muscleGroupFromKey(e.key) != null)
                  muscleGroupFromKey(e.key)!: (e.value as num).toDouble(),
            },
    );
  }
}
