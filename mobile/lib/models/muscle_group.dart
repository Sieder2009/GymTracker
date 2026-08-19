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
  // Finer sub-regions of some muscles above, for the Exercises tab's
  // filter diagram -- full peer values (taggable, hit-testable, everything
  // the coarse groups above can do), not a restricted special case. Only
  // ever *added* to a diagram alongside their coarse parent -- see
  // [muscleGroupParent] -- since the ~1300 hand-tagged exercises in
  // `exercise_muscle_map.dart` are tagged at the coarse level only and
  // that's out of scope to re-tag. Geometric bounding-box splits (see
  // `body_atlas.dart`'s `_splitTriceps`/`_splitBiceps`/`_splitChest`), not
  // medically traced boundaries -- same honest-approximation spirit as the
  // existing `frontDelts`/`sideDelts`/`upperBack`/`lats` splits.
  tricepsLongHead,
  tricepsLateralHead,
  tricepsMedialHead,
  bicepsLongHead,
  bicepsShortHead,
  chestUpper,
  chestMid,
  chestLower,
  // Quads already ship as 3 separate traced shapes in the source
  // illustration (no clipping needed) -- see `body_atlas.dart`.
  quadRectusFemoris,
  quadVastusLateralis,
  quadVastusMedialis,
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
  MuscleGroup.bicepsLongHead,
  MuscleGroup.bicepsShortHead,
  MuscleGroup.chestUpper,
  MuscleGroup.chestMid,
  MuscleGroup.chestLower,
  MuscleGroup.quadRectusFemoris,
  MuscleGroup.quadVastusLateralis,
  MuscleGroup.quadVastusMedialis,
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
  MuscleGroup.tricepsLongHead,
  MuscleGroup.tricepsLateralHead,
  MuscleGroup.tricepsMedialHead,
];

/// The coarse group a fine-grained head/region belongs to, or null for a
/// group that's already coarse. Used to fall back to the parent's
/// hand-tagged activation/exercise data wherever a head-level value is
/// looked up but the real data only ever exists at the coarse level (see
/// `detailed_body_diagram.dart` and `exercise_muscle_map.dart`).
const Map<MuscleGroup, MuscleGroup> _kMuscleGroupParent = {
  MuscleGroup.tricepsLongHead: MuscleGroup.triceps,
  MuscleGroup.tricepsLateralHead: MuscleGroup.triceps,
  MuscleGroup.tricepsMedialHead: MuscleGroup.triceps,
  MuscleGroup.bicepsLongHead: MuscleGroup.biceps,
  MuscleGroup.bicepsShortHead: MuscleGroup.biceps,
  MuscleGroup.chestUpper: MuscleGroup.chest,
  MuscleGroup.chestMid: MuscleGroup.chest,
  MuscleGroup.chestLower: MuscleGroup.chest,
  MuscleGroup.quadRectusFemoris: MuscleGroup.quads,
  MuscleGroup.quadVastusLateralis: MuscleGroup.quads,
  MuscleGroup.quadVastusMedialis: MuscleGroup.quads,
};

MuscleGroup? muscleGroupParent(MuscleGroup m) => _kMuscleGroupParent[m];

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
    case MuscleGroup.tricepsLongHead:
      return t.muscleTricepsLongHead;
    case MuscleGroup.tricepsLateralHead:
      return t.muscleTricepsLateralHead;
    case MuscleGroup.tricepsMedialHead:
      return t.muscleTricepsMedialHead;
    case MuscleGroup.bicepsLongHead:
      return t.muscleBicepsLongHead;
    case MuscleGroup.bicepsShortHead:
      return t.muscleBicepsShortHead;
    case MuscleGroup.chestUpper:
      return t.muscleChestUpper;
    case MuscleGroup.chestMid:
      return t.muscleChestMid;
    case MuscleGroup.chestLower:
      return t.muscleChestLower;
    case MuscleGroup.quadRectusFemoris:
      return t.muscleQuadRectusFemoris;
    case MuscleGroup.quadVastusLateralis:
      return t.muscleQuadVastusLateralis;
    case MuscleGroup.quadVastusMedialis:
      return t.muscleQuadVastusMedialis;
  }
}
