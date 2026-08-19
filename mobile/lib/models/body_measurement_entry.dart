import '../l10n/app_localizations.dart';

/// The six trackable circumference points -- shared between the entry form/
/// chart picker (`progress_screen.dart`) and the approximate shape overlay
/// (`body_shape_diagram.dart`), so both always agree on the same field set.
enum BodyMeasurementField { chest, waist, hips, arm, thigh, calf }

double? bodyMeasurementFieldValue(BodyMeasurementEntry e, BodyMeasurementField f) {
  switch (f) {
    case BodyMeasurementField.chest:
      return e.chestCm;
    case BodyMeasurementField.waist:
      return e.waistCm;
    case BodyMeasurementField.hips:
      return e.hipsCm;
    case BodyMeasurementField.arm:
      return e.armCm;
    case BodyMeasurementField.thigh:
      return e.thighCm;
    case BodyMeasurementField.calf:
      return e.calfCm;
  }
}

String bodyMeasurementFieldLabel(AppLocalizations t, BodyMeasurementField f) {
  switch (f) {
    case BodyMeasurementField.chest:
      return t.labelChest;
    case BodyMeasurementField.waist:
      return t.labelWaist;
    case BodyMeasurementField.hips:
      return t.labelHips;
    case BodyMeasurementField.arm:
      return t.labelArm;
    case BodyMeasurementField.thigh:
      return t.labelThigh;
    case BodyMeasurementField.calf:
      return t.labelCalf;
  }
}

/// One body-measurement logging pass. Every field is independently
/// nullable -- unlike [BodyWeightEntry]'s single required weight, a user
/// typically measures whichever subset of these they have a tape measure
/// handy for on a given day, not all six every time.
class BodyMeasurementEntry {
  BodyMeasurementEntry({
    required this.date,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.armCm,
    this.thighCm,
    this.calfCm,
  });

  final String date; // 'YYYY-MM-DD'
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? armCm;
  final double? thighCm;
  final double? calfCm;

  Map<String, dynamic> toJson() => {
        'date': date,
        'chestCm': chestCm,
        'waistCm': waistCm,
        'hipsCm': hipsCm,
        'armCm': armCm,
        'thighCm': thighCm,
        'calfCm': calfCm,
      };

  factory BodyMeasurementEntry.fromJson(Map<String, dynamic> json) =>
      BodyMeasurementEntry(
        date: json['date'] as String,
        chestCm: (json['chestCm'] as num?)?.toDouble(),
        waistCm: (json['waistCm'] as num?)?.toDouble(),
        hipsCm: (json['hipsCm'] as num?)?.toDouble(),
        armCm: (json['armCm'] as num?)?.toDouble(),
        thighCm: (json['thighCm'] as num?)?.toDouble(),
        calfCm: (json['calfCm'] as num?)?.toDouble(),
      );
}
