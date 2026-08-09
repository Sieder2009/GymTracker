class GymPhoto {
  GymPhoto({required this.id, required this.date});

  /// Filename (incl. extension) inside the app's `gym_photos` directory —
  /// doubles as the unique id, so no separate path bookkeeping is needed.
  final String id;
  final String date; // 'YYYY-MM-DD'

  Map<String, dynamic> toJson() => {'id': id, 'date': date};

  factory GymPhoto.fromJson(Map<String, dynamic> json) => GymPhoto(
        id: json['id'] as String,
        date: json['date'] as String,
      );
}
