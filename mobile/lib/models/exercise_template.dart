/// One entry from the shared exercise database (`assets/exercises.json`,
/// normally fetched fresh from GitHub — see `services/exercise_database_service.dart`).
/// Purely a picker convenience: choosing one just fills in a name, nothing
/// links a plan's [Exercise] back to its [id] afterwards.
class ExerciseTemplate {
  const ExerciseTemplate({required this.id, required this.name, required this.category});

  final String id;
  final String name;
  final String category;

  factory ExerciseTemplate.fromJson(Map<String, dynamic> json) => ExerciseTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'category': category};
}
