class BodyWeightEntry {
  BodyWeightEntry({required this.date, required this.weight});

  final String date; // 'YYYY-MM-DD'
  final double weight;

  Map<String, dynamic> toJson() => {'date': date, 'weight': weight};

  factory BodyWeightEntry.fromJson(Map<String, dynamic> json) => BodyWeightEntry(
        date: json['date'] as String,
        weight: (json['weight'] as num).toDouble(),
      );
}
