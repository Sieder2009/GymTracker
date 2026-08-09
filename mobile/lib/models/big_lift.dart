class BigLiftPoint {
  BigLiftPoint({required this.l, required this.v, this.isoDate});

  String l; // unpadded 'D.M' date label (today's day.month at time of entry)
  double v;

  /// 'YYYY-MM-DD' — added alongside [l] so analytics can compute real
  /// date-windowed trends (e.g. "last 30 days") without re-parsing the
  /// display-only, year-less [l] label. Null for entries logged before
  /// this field existed.
  String? isoDate;

  Map<String, dynamic> toJson() => {'l': l, 'v': v, 'isoDate': isoDate};

  factory BigLiftPoint.fromJson(Map<String, dynamic> json) => BigLiftPoint(
        l: json['l'] as String,
        v: (json['v'] as num).toDouble(),
        isoDate: json['isoDate'] as String?,
      );
}

class BigLift {
  BigLift({this.pr = 0, this.prDate, List<BigLiftPoint>? history})
      : history = history ?? [];

  double pr;
  String? prDate; // ISO 'YYYY-MM-DD', or null if never set with a known date
  List<BigLiftPoint> history;

  Map<String, dynamic> toJson() => {
        'pr': pr,
        'prDate': prDate,
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory BigLift.fromJson(Map<String, dynamic> json) => BigLift(
        pr: (json['pr'] as num?)?.toDouble() ?? 0,
        prDate: json['prDate'] as String?,
        history: (json['history'] as List? ?? [])
            .map((h) => BigLiftPoint.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}

class BigLifts {
  BigLifts({BigLift? bench, BigLift? deadlift, BigLift? squat})
      : bench = bench ?? BigLift(),
        deadlift = deadlift ?? BigLift(),
        squat = squat ?? BigLift();

  BigLift bench;
  BigLift deadlift;
  BigLift squat;

  static const List<String> keys = ['bench', 'deadlift', 'squat'];

  BigLift byKey(String key) {
    switch (key) {
      case 'bench':
        return bench;
      case 'deadlift':
        return deadlift;
      case 'squat':
        return squat;
      default:
        throw ArgumentError('unknown lift key: $key');
    }
  }

  Map<String, dynamic> toJson() => {
        'bench': bench.toJson(),
        'deadlift': deadlift.toJson(),
        'squat': squat.toJson(),
      };

  factory BigLifts.fromJson(Map<String, dynamic> json) => BigLifts(
        bench: json['bench'] != null
            ? BigLift.fromJson(json['bench'] as Map<String, dynamic>)
            : null,
        deadlift: json['deadlift'] != null
            ? BigLift.fromJson(json['deadlift'] as Map<String, dynamic>)
            : null,
        squat: json['squat'] != null
            ? BigLift.fromJson(json['squat'] as Map<String, dynamic>)
            : null,
      );
}
