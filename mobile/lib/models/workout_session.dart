class WorkoutSession {
  WorkoutSession({
    required this.date,
    required this.durationMinutes,
    required this.planName,
    this.totalVolumeKg = 0,
    this.totalSets = 0,
  });

  final String date; // 'YYYY-MM-DD'
  final int durationMinutes;
  final String planName;

  /// Sum of weight × reps across every set completed in this session
  /// (reps = the set's TARGET rep count, since the guided workout doesn't
  /// collect actual-reps-performed per set — a reasonable approximation
  /// for a fixed-program session, not a claim of logged rep-perfect data).
  final double totalVolumeKg;
  final int totalSets;

  Map<String, dynamic> toJson() => {
        'date': date,
        'durationMinutes': durationMinutes,
        'planName': planName,
        'totalVolumeKg': totalVolumeKg,
        'totalSets': totalSets,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        date: json['date'] as String,
        durationMinutes: (json['durationMinutes'] as num).toInt(),
        planName: json['planName'] as String,
        totalVolumeKg: (json['totalVolumeKg'] as num?)?.toDouble() ?? 0,
        totalSets: (json['totalSets'] as num?)?.toInt() ?? 0,
      );
}
