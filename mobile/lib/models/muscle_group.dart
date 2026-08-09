import '../l10n/app_localizations.dart';

/// Individual muscles a custom exercise can be tagged against, each with
/// its own 0-100 activation intensity — a finer breakdown than the 7 broad
/// [ExerciseTemplate] categories (chest/back/shoulders/...), used only for
/// user-authored custom exercises where that level of detail is worth the
/// extra taps. Split front/back to match how [MuscleActivationEditor]
/// draws them (a muscle only belongs to one view).
enum MuscleGroup {
  chest,
  abs,
  obliques,
  frontDelts,
  sideDelts,
  biceps,
  forearms,
  quads,
  calves,
  upperBack,
  lowerBack,
  lats,
  traps,
  rearDelts,
  triceps,
  glutes,
  hamstrings,
}

const List<MuscleGroup> kFrontMuscles = [
  MuscleGroup.chest,
  MuscleGroup.abs,
  MuscleGroup.obliques,
  MuscleGroup.frontDelts,
  MuscleGroup.sideDelts,
  MuscleGroup.biceps,
  MuscleGroup.forearms,
  MuscleGroup.quads,
  MuscleGroup.calves,
];

const List<MuscleGroup> kBackMuscles = [
  MuscleGroup.upperBack,
  MuscleGroup.lowerBack,
  MuscleGroup.lats,
  MuscleGroup.traps,
  MuscleGroup.rearDelts,
  MuscleGroup.triceps,
  MuscleGroup.glutes,
  MuscleGroup.hamstrings,
];

String muscleGroupKey(MuscleGroup m) => m.name;

MuscleGroup? muscleGroupFromKey(String key) {
  for (final m in MuscleGroup.values) {
    if (m.name == key) return m;
  }
  return null;
}

String muscleGroupLabel(AppLocalizations t, MuscleGroup m) {
  switch (m) {
    case MuscleGroup.chest:
      return t.muscleChest;
    case MuscleGroup.abs:
      return t.muscleAbs;
    case MuscleGroup.obliques:
      return t.muscleObliques;
    case MuscleGroup.frontDelts:
      return t.muscleFrontDelts;
    case MuscleGroup.sideDelts:
      return t.muscleSideDelts;
    case MuscleGroup.biceps:
      return t.muscleBiceps;
    case MuscleGroup.forearms:
      return t.muscleForearms;
    case MuscleGroup.quads:
      return t.muscleQuads;
    case MuscleGroup.calves:
      return t.muscleCalves;
    case MuscleGroup.upperBack:
      return t.muscleUpperBack;
    case MuscleGroup.lowerBack:
      return t.muscleLowerBack;
    case MuscleGroup.lats:
      return t.muscleLats;
    case MuscleGroup.traps:
      return t.muscleTraps;
    case MuscleGroup.rearDelts:
      return t.muscleRearDelts;
    case MuscleGroup.triceps:
      return t.muscleTriceps;
    case MuscleGroup.glutes:
      return t.muscleGlutes;
    case MuscleGroup.hamstrings:
      return t.muscleHamstrings;
  }
}
