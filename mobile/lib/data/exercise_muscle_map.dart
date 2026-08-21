import '../models/exercise_template.dart';
import '../models/muscle_group.dart';

/// Which muscles [ex] trains and roughly how much (0-100 intensity) — the
/// data behind the detailed body diagram on the Exercises tab. Matched by
/// [ExerciseTemplate.id] against real exercise-science knowledge (which
/// muscles a given lift trains is a fact, not copyrightable content), with
/// a category-level fallback so any exercise the GitHub-hosted database
/// adds later — even one this table has never seen — still gets a
/// reasonable, non-empty diagram instead of a blank one.
Map<MuscleGroup, double> muscleActivationForExercise(ExerciseTemplate ex) {
  return _byId[ex.id] ?? _categoryDefault(ex.category);
}

/// Whether [ex] meaningfully trains [target] -- the query behind the
/// "tap a body part to filter" exercise browser. No precomputed reverse
/// index: [_byId] holds a couple hundred entries, already re-filtered on
/// every rebuild by category/search text, so one more linear scan here
/// costs nothing extra.
bool exerciseWorksMuscle(ExerciseTemplate ex, MuscleGroup target,
    {double threshold = 30}) {
  final activation = muscleActivationForExercise(ex);
  // Every entry here is tagged at the coarse level only (re-tagging ~1300
  // exercises to head-level granularity is out of scope -- see
  // MuscleGroup's doc comment), so a head-level filter tap (e.g. "triceps
  // long head") falls back to its parent's value: tapping a specific head
  // returns the same exercises as tapping its coarse muscle would.
  final direct = activation[target];
  final value = direct ?? activation[muscleGroupParent(target)] ?? 0;
  return value >= threshold;
}

Map<MuscleGroup, double> _categoryDefault(String category) {
  switch (category) {
    case 'chest':
      return const {
        MuscleGroup.chest: 100,
        MuscleGroup.frontDelts: 35,
        MuscleGroup.triceps: 35
      };
    case 'back':
      return const {
        MuscleGroup.lats: 80,
        MuscleGroup.upperBack: 55,
        MuscleGroup.biceps: 30
      };
    case 'shoulders':
      return const {
        MuscleGroup.frontDelts: 70,
        MuscleGroup.sideDelts: 60,
        MuscleGroup.triceps: 25
      };
    case 'legs':
      return const {
        MuscleGroup.quads: 80,
        MuscleGroup.glutes: 50,
        MuscleGroup.hamstrings: 25
      };
    case 'arms':
      return const {
        MuscleGroup.biceps: 60,
        MuscleGroup.triceps: 60,
        MuscleGroup.forearms: 30
      };
    case 'core':
      return const {MuscleGroup.abs: 90, MuscleGroup.obliques: 35};
    case 'cardio':
      return const {
        MuscleGroup.quads: 55,
        MuscleGroup.calves: 45,
        MuscleGroup.hamstrings: 30
      };
    default:
      return const {};
  }
}

const Map<String, Map<MuscleGroup, double>> _byId = {
  // --- Chest ---
  'bench_press': {
    MuscleGroup.chest: 100,
    MuscleGroup.frontDelts: 40,
    MuscleGroup.triceps: 40
  },
  'incline_bench_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 55,
    MuscleGroup.triceps: 35
  },
  'decline_bench_press': {
    MuscleGroup.chest: 100,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 25
  },
  'close_grip_bench_press': {
    MuscleGroup.chest: 75,
    MuscleGroup.triceps: 65,
    MuscleGroup.frontDelts: 30
  },
  'wide_grip_bench_press': {
    MuscleGroup.chest: 100,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.triceps: 30
  },
  'dumbbell_bench_press': {
    MuscleGroup.chest: 100,
    MuscleGroup.frontDelts: 40,
    MuscleGroup.triceps: 35
  },
  'incline_dumbbell_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 55,
    MuscleGroup.triceps: 30
  },
  'decline_dumbbell_press': {
    MuscleGroup.chest: 100,
    MuscleGroup.triceps: 40,
    MuscleGroup.frontDelts: 25
  },
  'smith_machine_bench_press': {
    MuscleGroup.chest: 95,
    MuscleGroup.frontDelts: 40,
    MuscleGroup.triceps: 40
  },
  'floor_press': {
    MuscleGroup.chest: 85,
    MuscleGroup.triceps: 55,
    MuscleGroup.frontDelts: 25
  },
  'chest_fly': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 15},
  'incline_chest_fly': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 20},
  'cable_fly': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 15},
  'low_cable_fly': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 10},
  'pec_deck': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 10},
  'chest_press_machine': {
    MuscleGroup.chest: 95,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.triceps: 30
  },
  'dips': {
    MuscleGroup.chest: 80,
    MuscleGroup.triceps: 60,
    MuscleGroup.frontDelts: 30
  },
  'weighted_dips': {
    MuscleGroup.chest: 80,
    MuscleGroup.triceps: 65,
    MuscleGroup.frontDelts: 30
  },
  'push_ups': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 40,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 15
  },
  'incline_push_ups': {
    MuscleGroup.chest: 80,
    MuscleGroup.triceps: 35,
    MuscleGroup.frontDelts: 25,
    MuscleGroup.abs: 10
  },
  'decline_push_ups': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 40,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.abs: 20
  },
  'pullover': {
    MuscleGroup.chest: 60,
    MuscleGroup.lats: 50,
    MuscleGroup.triceps: 20
  },
  'svend_press': {MuscleGroup.chest: 90, MuscleGroup.frontDelts: 20},
  'cable_crossover': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 20},
  'low_cable_crossover': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 25},
  'high_cable_crossover': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 10},
  'single_arm_cable_fly': {MuscleGroup.chest: 100, MuscleGroup.obliques: 10},
  'single_arm_cable_chest_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.triceps: 30,
    MuscleGroup.obliques: 15,
  },
  'neutral_grip_dumbbell_press': {
    MuscleGroup.chest: 95,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.triceps: 40
  },
  'one_arm_dumbbell_bench_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.triceps: 35,
    MuscleGroup.abs: 15,
  },
  'guillotine_bench_press': {
    MuscleGroup.chest: 100,
    MuscleGroup.frontDelts: 45,
    MuscleGroup.triceps: 30
  },
  'spoto_press': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 40,
    MuscleGroup.frontDelts: 30
  },
  'larsen_press': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 35,
    MuscleGroup.frontDelts: 30
  },
  'board_press': {
    MuscleGroup.triceps: 55,
    MuscleGroup.chest: 70,
    MuscleGroup.frontDelts: 25
  },
  'bench_press_with_chains': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 35
  },
  'bench_press_with_bands': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 35
  },
  'reverse_band_bench_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 30
  },
  'push_up_wide': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 30,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 15
  },
  'archer_push_up': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 35,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 20,
  },
  'hindu_push_up': {
    MuscleGroup.chest: 80,
    MuscleGroup.frontDelts: 60,
    MuscleGroup.triceps: 35
  },
  'clap_push_up': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.abs: 15
  },
  'plyo_push_up': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 35
  },
  'pseudo_planche_push_up': {
    MuscleGroup.chest: 70,
    MuscleGroup.frontDelts: 60,
    MuscleGroup.triceps: 30,
    MuscleGroup.abs: 20,
  },
  'medicine_ball_push_up': {
    MuscleGroup.chest: 85,
    MuscleGroup.triceps: 40,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 20,
  },
  'suspended_push_up': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 35,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 25,
  },
  'weighted_push_up': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 40,
    MuscleGroup.frontDelts: 30
  },
  'plate_squeeze_press': {MuscleGroup.chest: 100, MuscleGroup.triceps: 20},
  'dumbbell_floor_fly': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 15},
  'incline_cable_fly': {MuscleGroup.chest: 95, MuscleGroup.frontDelts: 25},
  'decline_cable_fly': {MuscleGroup.chest: 100, MuscleGroup.triceps: 15},
  'isometric_chest_squeeze': {MuscleGroup.chest: 90, MuscleGroup.triceps: 20},
  'landmine_chest_press': {
    MuscleGroup.chest: 80,
    MuscleGroup.frontDelts: 40,
    MuscleGroup.triceps: 35
  },
  'incline_smith_machine_bench_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 50,
    MuscleGroup.triceps: 35
  },
  'decline_smith_machine_bench_press': {
    MuscleGroup.chest: 100,
    MuscleGroup.triceps: 40,
    MuscleGroup.frontDelts: 25,
  },
  'resistance_band_chest_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.triceps: 35
  },
  'close_grip_incline_bench_press': {
    MuscleGroup.chest: 80,
    MuscleGroup.triceps: 50,
    MuscleGroup.frontDelts: 40
  },
  'cable_iron_cross': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 20},
  'explosive_bench_press': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 35
  },
  'cable_chest_press_standing': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.triceps: 30
  },
  'incline_dumbbell_fly_twist': {
    MuscleGroup.chest: 100,
    MuscleGroup.frontDelts: 20
  },
  'deficit_push_up': {
    MuscleGroup.chest: 95,
    MuscleGroup.triceps: 35,
    MuscleGroup.frontDelts: 30
  },
  'single_leg_push_up': {
    MuscleGroup.chest: 85,
    MuscleGroup.triceps: 35,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 25,
  },
  'wall_push_up': {
    MuscleGroup.chest: 70,
    MuscleGroup.triceps: 30,
    MuscleGroup.frontDelts: 25
  },
  'knee_push_up': {
    MuscleGroup.chest: 80,
    MuscleGroup.triceps: 30,
    MuscleGroup.frontDelts: 25
  },
  'dumbbell_around_the_world': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 40
  },
  'reverse_grip_bench_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 20
  },

  // --- Back ---
  'deadlift': {
    MuscleGroup.lowerBack: 90,
    MuscleGroup.hamstrings: 65,
    MuscleGroup.glutes: 70,
    MuscleGroup.traps: 45,
    MuscleGroup.forearms: 35,
    MuscleGroup.lats: 25,
  },
  'sumo_deadlift': {
    MuscleGroup.glutes: 80,
    MuscleGroup.hamstrings: 55,
    MuscleGroup.lowerBack: 80,
    MuscleGroup.traps: 40,
    MuscleGroup.forearms: 30,
    MuscleGroup.quads: 35,
  },
  'romanian_deadlift': {
    MuscleGroup.hamstrings: 90,
    MuscleGroup.glutes: 60,
    MuscleGroup.lowerBack: 60
  },
  'stiff_leg_deadlift': {
    MuscleGroup.hamstrings: 95,
    MuscleGroup.glutes: 55,
    MuscleGroup.lowerBack: 55
  },
  'deficit_deadlift': {
    MuscleGroup.lowerBack: 90,
    MuscleGroup.hamstrings: 70,
    MuscleGroup.glutes: 65,
    MuscleGroup.traps: 40,
  },
  'rack_pull': {
    MuscleGroup.lowerBack: 70,
    MuscleGroup.traps: 60,
    MuscleGroup.forearms: 50,
    MuscleGroup.lats: 30
  },
  'trap_bar_deadlift': {
    MuscleGroup.glutes: 70,
    MuscleGroup.hamstrings: 60,
    MuscleGroup.lowerBack: 75,
    MuscleGroup.quads: 40,
    MuscleGroup.traps: 35,
  },
  'pull_ups': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 50,
    MuscleGroup.upperBack: 35,
    MuscleGroup.rearDelts: 15
  },
  'chin_ups': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 65,
    MuscleGroup.upperBack: 30
  },
  'weighted_pull_ups': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 55,
    MuscleGroup.upperBack: 35
  },
  'assisted_pull_ups': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 45,
    MuscleGroup.upperBack: 30
  },
  'lat_pulldown': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 40,
    MuscleGroup.upperBack: 30
  },
  'close_grip_lat_pulldown': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 50,
    MuscleGroup.upperBack: 25
  },
  'wide_grip_lat_pulldown': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 30,
    MuscleGroup.upperBack: 35
  },
  'single_arm_lat_pulldown': {
    MuscleGroup.lats: 95,
    MuscleGroup.biceps: 40,
    MuscleGroup.obliques: 15
  },
  'barbell_row': {
    MuscleGroup.lats: 80,
    MuscleGroup.upperBack: 65,
    MuscleGroup.biceps: 35,
    MuscleGroup.rearDelts: 25
  },
  'pendlay_row': {
    MuscleGroup.upperBack: 75,
    MuscleGroup.lats: 70,
    MuscleGroup.biceps: 30,
    MuscleGroup.rearDelts: 25
  },
  'dumbbell_row': {
    MuscleGroup.lats: 85,
    MuscleGroup.upperBack: 55,
    MuscleGroup.biceps: 35,
    MuscleGroup.rearDelts: 20
  },
  'chest_supported_row': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 65,
    MuscleGroup.rearDelts: 30,
    MuscleGroup.biceps: 30
  },
  'seated_cable_row': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 65,
    MuscleGroup.biceps: 35,
    MuscleGroup.rearDelts: 20
  },
  'one_arm_cable_row': {
    MuscleGroup.lats: 75,
    MuscleGroup.upperBack: 60,
    MuscleGroup.biceps: 30,
    MuscleGroup.obliques: 15
  },
  't_bar_row': {
    MuscleGroup.upperBack: 75,
    MuscleGroup.lats: 70,
    MuscleGroup.biceps: 30,
    MuscleGroup.rearDelts: 20
  },
  'machine_row': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 60,
    MuscleGroup.biceps: 30
  },
  'inverted_row': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 60,
    MuscleGroup.biceps: 35,
    MuscleGroup.rearDelts: 20
  },
  'face_pull': {
    MuscleGroup.rearDelts: 85,
    MuscleGroup.upperBack: 45,
    MuscleGroup.traps: 30
  },
  'straight_arm_pulldown': {MuscleGroup.lats: 90, MuscleGroup.triceps: 20},
  'hyperextension': {
    MuscleGroup.lowerBack: 90,
    MuscleGroup.glutes: 45,
    MuscleGroup.hamstrings: 40
  },
  'good_morning': {
    MuscleGroup.lowerBack: 80,
    MuscleGroup.hamstrings: 60,
    MuscleGroup.glutes: 50
  },
  'shrugs': {MuscleGroup.traps: 100, MuscleGroup.forearms: 25},
  'dumbbell_shrugs': {MuscleGroup.traps: 100, MuscleGroup.forearms: 25},
  'back_extension_machine': {
    MuscleGroup.lowerBack: 90,
    MuscleGroup.glutes: 40,
    MuscleGroup.hamstrings: 30
  },
  'jefferson_deadlift': {
    MuscleGroup.lowerBack: 80,
    MuscleGroup.quads: 40,
    MuscleGroup.glutes: 50,
    MuscleGroup.hamstrings: 40,
    MuscleGroup.traps: 30,
  },
  'snatch_grip_deadlift': {
    MuscleGroup.lowerBack: 85,
    MuscleGroup.hamstrings: 60,
    MuscleGroup.traps: 50,
    MuscleGroup.upperBack: 40,
    MuscleGroup.forearms: 40,
  },
  'deadlift_with_bands': {
    MuscleGroup.lowerBack: 85,
    MuscleGroup.hamstrings: 60,
    MuscleGroup.glutes: 65,
    MuscleGroup.traps: 40,
  },
  'deadlift_with_chains': {
    MuscleGroup.lowerBack: 85,
    MuscleGroup.hamstrings: 60,
    MuscleGroup.glutes: 65,
    MuscleGroup.traps: 40,
  },
  'block_pull': {
    MuscleGroup.lowerBack: 75,
    MuscleGroup.traps: 55,
    MuscleGroup.forearms: 45,
    MuscleGroup.upperBack: 30,
  },
  'banded_good_morning': {
    MuscleGroup.lowerBack: 75,
    MuscleGroup.hamstrings: 55,
    MuscleGroup.glutes: 45
  },
  'seated_good_morning': {
    MuscleGroup.lowerBack: 80,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.glutes: 35
  },
  'wide_grip_pull_ups': {
    MuscleGroup.lats: 100,
    MuscleGroup.upperBack: 35,
    MuscleGroup.biceps: 25
  },
  'neutral_grip_pull_ups': {
    MuscleGroup.lats: 95,
    MuscleGroup.biceps: 55,
    MuscleGroup.upperBack: 30
  },
  'l_sit_pull_ups': {
    MuscleGroup.lats: 95,
    MuscleGroup.biceps: 50,
    MuscleGroup.abs: 40
  },
  'archer_pull_ups': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 40,
    MuscleGroup.upperBack: 30
  },
  'muscle_up': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 45,
    MuscleGroup.triceps: 40,
    MuscleGroup.chest: 30
  },
  'kipping_pull_ups': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 40,
    MuscleGroup.abs: 25
  },
  'scapular_pull_ups': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 60,
    MuscleGroup.traps: 40
  },
  'towel_pull_ups': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 55,
    MuscleGroup.forearms: 50
  },
  'behind_neck_pulldown': {
    MuscleGroup.lats: 95,
    MuscleGroup.upperBack: 35,
    MuscleGroup.biceps: 25
  },
  'v_bar_pulldown': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 40,
    MuscleGroup.upperBack: 20
  },
  'underhand_lat_pulldown': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 55,
    MuscleGroup.upperBack: 20
  },
  'kneeling_lat_pulldown': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 35,
    MuscleGroup.upperBack: 25
  },
  'meadows_row': {
    MuscleGroup.lats: 70,
    MuscleGroup.upperBack: 65,
    MuscleGroup.biceps: 30,
    MuscleGroup.rearDelts: 20,
  },
  'yates_row': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 65,
    MuscleGroup.biceps: 35
  },
  'seal_row': {
    MuscleGroup.upperBack: 75,
    MuscleGroup.lats: 60,
    MuscleGroup.biceps: 30
  },
  'landmine_row': {
    MuscleGroup.lats: 70,
    MuscleGroup.upperBack: 65,
    MuscleGroup.biceps: 30
  },
  'kroc_row': {
    MuscleGroup.lats: 80,
    MuscleGroup.upperBack: 55,
    MuscleGroup.biceps: 35,
    MuscleGroup.forearms: 30
  },
  'renegade_row': {
    MuscleGroup.lats: 60,
    MuscleGroup.upperBack: 55,
    MuscleGroup.abs: 40,
    MuscleGroup.biceps: 30
  },
  'cable_row_wide_grip': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 55,
    MuscleGroup.rearDelts: 30
  },
  'cable_row_close_grip': {
    MuscleGroup.lats: 65,
    MuscleGroup.upperBack: 65,
    MuscleGroup.biceps: 40
  },
  'gorilla_row': {
    MuscleGroup.lats: 75,
    MuscleGroup.upperBack: 55,
    MuscleGroup.biceps: 30,
    MuscleGroup.obliques: 15,
  },
  'suspension_row': {
    MuscleGroup.upperBack: 65,
    MuscleGroup.lats: 55,
    MuscleGroup.biceps: 30,
    MuscleGroup.abs: 15
  },
  'cambered_bar_row': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 60,
    MuscleGroup.biceps: 30
  },
  'smith_machine_row': {
    MuscleGroup.upperBack: 65,
    MuscleGroup.lats: 60,
    MuscleGroup.biceps: 25
  },
  'rack_pull_with_bands': {
    MuscleGroup.lowerBack: 65,
    MuscleGroup.traps: 60,
    MuscleGroup.forearms: 45
  },
  'barbell_shrug_behind_back': {
    MuscleGroup.traps: 100,
    MuscleGroup.forearms: 20
  },
  'cable_shrug': {MuscleGroup.traps: 100},
  'smith_machine_shrug': {MuscleGroup.traps: 100},
  'farmers_walk': {
    MuscleGroup.forearms: 70,
    MuscleGroup.traps: 55,
    MuscleGroup.abs: 30,
    MuscleGroup.upperBack: 25
  },
  'suitcase_carry': {
    MuscleGroup.obliques: 70,
    MuscleGroup.forearms: 45,
    MuscleGroup.abs: 35
  },
  'reverse_hyperextension': {
    MuscleGroup.lowerBack: 85,
    MuscleGroup.glutes: 55,
    MuscleGroup.hamstrings: 35
  },
  'rope_climb': {
    MuscleGroup.lats: 85,
    MuscleGroup.biceps: 55,
    MuscleGroup.forearms: 50
  },
  'sled_row': {
    MuscleGroup.upperBack: 65,
    MuscleGroup.lats: 50,
    MuscleGroup.biceps: 25
  },
  'band_assisted_pull_ups': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 40,
    MuscleGroup.upperBack: 30
  },
  'one_arm_pull_up': {
    MuscleGroup.lats: 100,
    MuscleGroup.biceps: 60,
    MuscleGroup.forearms: 45,
    MuscleGroup.obliques: 20,
  },
  'sternum_chin_ups': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 55,
    MuscleGroup.upperBack: 35
  },
  'resistance_band_row': {
    MuscleGroup.upperBack: 65,
    MuscleGroup.lats: 55,
    MuscleGroup.biceps: 30
  },
  'resistance_band_pulldown': {MuscleGroup.lats: 90, MuscleGroup.biceps: 35},
  'ring_rows': {
    MuscleGroup.upperBack: 65,
    MuscleGroup.lats: 55,
    MuscleGroup.biceps: 30,
    MuscleGroup.abs: 15
  },
  'weighted_hyperextension': {
    MuscleGroup.lowerBack: 95,
    MuscleGroup.glutes: 50,
    MuscleGroup.hamstrings: 40
  },
  'single_arm_landmine_row': {
    MuscleGroup.lats: 65,
    MuscleGroup.upperBack: 60,
    MuscleGroup.biceps: 30
  },
  'cable_high_row': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.rearDelts: 35,
    MuscleGroup.lats: 35
  },
  'barbell_pullover': {
    MuscleGroup.lats: 55,
    MuscleGroup.chest: 50,
    MuscleGroup.triceps: 20
  },
  'axle_deadlift': {
    MuscleGroup.lowerBack: 80,
    MuscleGroup.forearms: 55,
    MuscleGroup.traps: 45,
    MuscleGroup.hamstrings: 45,
  },
  'scapular_retraction_band': {
    MuscleGroup.upperBack: 75,
    MuscleGroup.rearDelts: 30
  },
  'yoke_walk': {
    MuscleGroup.traps: 60,
    MuscleGroup.upperBack: 40,
    MuscleGroup.abs: 35,
    MuscleGroup.quads: 30
  },
  'superman': {MuscleGroup.lowerBack: 80, MuscleGroup.glutes: 40},

  // --- Shoulders ---
  'overhead_press': {
    MuscleGroup.frontDelts: 90,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.triceps: 40,
    MuscleGroup.traps: 25
  },
  'dumbbell_shoulder_press': {
    MuscleGroup.frontDelts: 90,
    MuscleGroup.sideDelts: 45,
    MuscleGroup.triceps: 35
  },
  'seated_shoulder_press': {
    MuscleGroup.frontDelts: 90,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.triceps: 35
  },
  'machine_shoulder_press': {
    MuscleGroup.frontDelts: 90,
    MuscleGroup.sideDelts: 35,
    MuscleGroup.triceps: 30
  },
  'arnold_press': {
    MuscleGroup.frontDelts: 85,
    MuscleGroup.sideDelts: 55,
    MuscleGroup.triceps: 35
  },
  'push_press': {
    MuscleGroup.frontDelts: 90,
    MuscleGroup.sideDelts: 35,
    MuscleGroup.triceps: 40,
    MuscleGroup.quads: 20
  },
  'behind_neck_press': {
    MuscleGroup.sideDelts: 60,
    MuscleGroup.frontDelts: 60,
    MuscleGroup.triceps: 35,
    MuscleGroup.traps: 25
  },
  'lateral_raise': {MuscleGroup.sideDelts: 100, MuscleGroup.traps: 15},
  'cable_lateral_raise': {MuscleGroup.sideDelts: 100, MuscleGroup.traps: 15},
  'leaning_lateral_raise': {MuscleGroup.sideDelts: 100},
  'front_raise': {MuscleGroup.frontDelts: 100},
  'plate_front_raise': {MuscleGroup.frontDelts: 100, MuscleGroup.abs: 10},
  'rear_delt_fly': {MuscleGroup.rearDelts: 100, MuscleGroup.upperBack: 25},
  'cable_rear_delt_fly': {
    MuscleGroup.rearDelts: 100,
    MuscleGroup.upperBack: 25
  },
  'upright_row': {
    MuscleGroup.sideDelts: 70,
    MuscleGroup.traps: 60,
    MuscleGroup.biceps: 20
  },
  'cuban_press': {
    MuscleGroup.sideDelts: 60,
    MuscleGroup.rearDelts: 50,
    MuscleGroup.frontDelts: 40
  },
  'landmine_press': {
    MuscleGroup.frontDelts: 80,
    MuscleGroup.sideDelts: 30,
    MuscleGroup.triceps: 35,
    MuscleGroup.abs: 15
  },
  'z_press': {
    MuscleGroup.frontDelts: 90,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.triceps: 35,
    MuscleGroup.abs: 30
  },
  'bradford_press': {
    MuscleGroup.frontDelts: 75,
    MuscleGroup.sideDelts: 55,
    MuscleGroup.triceps: 30
  },
  'viking_press': {
    MuscleGroup.frontDelts: 85,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.triceps: 35
  },
  'single_arm_dumbbell_press': {
    MuscleGroup.frontDelts: 85,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.triceps: 35,
    MuscleGroup.obliques: 15,
  },
  'kettlebell_press': {
    MuscleGroup.frontDelts: 85,
    MuscleGroup.sideDelts: 35,
    MuscleGroup.triceps: 35
  },
  'bottoms_up_kettlebell_press': {
    MuscleGroup.frontDelts: 80,
    MuscleGroup.forearms: 45,
    MuscleGroup.sideDelts: 30,
    MuscleGroup.triceps: 30,
  },
  'lying_lateral_raise': {MuscleGroup.sideDelts: 100},
  'y_raise': {
    MuscleGroup.sideDelts: 60,
    MuscleGroup.traps: 55,
    MuscleGroup.rearDelts: 35
  },
  'scaption': {
    MuscleGroup.sideDelts: 70,
    MuscleGroup.frontDelts: 50,
    MuscleGroup.traps: 20
  },
  'reverse_pec_deck': {MuscleGroup.rearDelts: 100, MuscleGroup.upperBack: 25},
  'band_pull_apart': {
    MuscleGroup.rearDelts: 80,
    MuscleGroup.upperBack: 40,
    MuscleGroup.traps: 20
  },
  'external_rotation': {MuscleGroup.rearDelts: 70, MuscleGroup.sideDelts: 20},
  'external_rotation_cable': {
    MuscleGroup.rearDelts: 70,
    MuscleGroup.sideDelts: 20
  },
  'internal_rotation_cable': {
    MuscleGroup.frontDelts: 60,
    MuscleGroup.chest: 20
  },
  'barbell_front_raise': {MuscleGroup.frontDelts: 100},
  'incline_rear_delt_raise': {
    MuscleGroup.rearDelts: 100,
    MuscleGroup.upperBack: 20
  },
  'machine_lateral_raise': {MuscleGroup.sideDelts: 100},
  'handstand_push_up': {
    MuscleGroup.frontDelts: 90,
    MuscleGroup.triceps: 55,
    MuscleGroup.traps: 20
  },
  'pike_push_up': {
    MuscleGroup.frontDelts: 80,
    MuscleGroup.triceps: 40,
    MuscleGroup.chest: 20
  },
  'wall_walk': {
    MuscleGroup.frontDelts: 70,
    MuscleGroup.abs: 40,
    MuscleGroup.triceps: 30
  },
  'clean_and_press': {
    MuscleGroup.frontDelts: 70,
    MuscleGroup.traps: 40,
    MuscleGroup.quads: 35,
    MuscleGroup.glutes: 30,
    MuscleGroup.triceps: 30,
  },
  'thruster': {
    MuscleGroup.frontDelts: 70,
    MuscleGroup.quads: 60,
    MuscleGroup.glutes: 40,
    MuscleGroup.triceps: 30
  },
  'snatch': {
    MuscleGroup.frontDelts: 60,
    MuscleGroup.traps: 50,
    MuscleGroup.quads: 45,
    MuscleGroup.glutes: 45,
    MuscleGroup.hamstrings: 35,
  },
  'power_snatch': {
    MuscleGroup.frontDelts: 60,
    MuscleGroup.traps: 50,
    MuscleGroup.quads: 40,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.glutes: 35,
  },
  'push_jerk': {
    MuscleGroup.frontDelts: 75,
    MuscleGroup.triceps: 40,
    MuscleGroup.quads: 35,
    MuscleGroup.traps: 25
  },
  'split_jerk': {
    MuscleGroup.frontDelts: 75,
    MuscleGroup.triceps: 40,
    MuscleGroup.quads: 40,
    MuscleGroup.glutes: 25,
  },
  'clean_and_jerk': {
    MuscleGroup.frontDelts: 65,
    MuscleGroup.traps: 45,
    MuscleGroup.quads: 45,
    MuscleGroup.glutes: 35,
    MuscleGroup.triceps: 30,
  },
  'hang_clean': {
    MuscleGroup.traps: 55,
    MuscleGroup.quads: 45,
    MuscleGroup.glutes: 40,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.frontDelts: 30,
  },
  'power_clean': {
    MuscleGroup.traps: 55,
    MuscleGroup.quads: 45,
    MuscleGroup.glutes: 40,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.frontDelts: 30,
  },
  'clean_pull': {
    MuscleGroup.traps: 60,
    MuscleGroup.lowerBack: 45,
    MuscleGroup.hamstrings: 40,
    MuscleGroup.quads: 30,
  },
  'barbell_high_pull': {
    MuscleGroup.traps: 65,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.upperBack: 30
  },
  'dumbbell_high_pull': {
    MuscleGroup.traps: 60,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.upperBack: 25
  },
  'push_press_behind_neck': {
    MuscleGroup.sideDelts: 60,
    MuscleGroup.frontDelts: 50,
    MuscleGroup.triceps: 35,
    MuscleGroup.quads: 20,
  },
  'dumbbell_snatch': {
    MuscleGroup.frontDelts: 55,
    MuscleGroup.traps: 45,
    MuscleGroup.glutes: 40,
    MuscleGroup.quads: 35,
  },
  'kettlebell_snatch': {
    MuscleGroup.frontDelts: 55,
    MuscleGroup.traps: 45,
    MuscleGroup.glutes: 40,
    MuscleGroup.hamstrings: 35,
  },
  'smith_machine_shoulder_press': {
    MuscleGroup.frontDelts: 90,
    MuscleGroup.sideDelts: 35,
    MuscleGroup.triceps: 30
  },
  'resistance_band_lateral_raise': {MuscleGroup.sideDelts: 100},
  'devils_press': {
    MuscleGroup.frontDelts: 65,
    MuscleGroup.glutes: 45,
    MuscleGroup.chest: 30,
    MuscleGroup.triceps: 35,
    MuscleGroup.hamstrings: 30,
  },
  'kettlebell_thruster': {
    MuscleGroup.frontDelts: 65,
    MuscleGroup.quads: 55,
    MuscleGroup.glutes: 35,
    MuscleGroup.triceps: 30,
  },
  'cable_y_raise': {
    MuscleGroup.sideDelts: 55,
    MuscleGroup.traps: 50,
    MuscleGroup.rearDelts: 35
  },
  'bus_driver': {
    MuscleGroup.sideDelts: 60,
    MuscleGroup.frontDelts: 50,
    MuscleGroup.abs: 20
  },
  'egyptian_lateral_raise': {MuscleGroup.sideDelts: 100},
  'seated_dumbbell_lateral_raise': {MuscleGroup.sideDelts: 100},
  'single_arm_cable_lateral_raise': {MuscleGroup.sideDelts: 100},
  'behind_the_back_cable_lateral_raise': {
    MuscleGroup.sideDelts: 100,
    MuscleGroup.traps: 15
  },
  'shoulder_dislocates': {
    MuscleGroup.frontDelts: 30,
    MuscleGroup.rearDelts: 30,
    MuscleGroup.sideDelts: 20
  },
  'wall_slide': {
    MuscleGroup.rearDelts: 50,
    MuscleGroup.traps: 45,
    MuscleGroup.upperBack: 30
  },
  'ytwl_raise': {
    MuscleGroup.rearDelts: 70,
    MuscleGroup.traps: 50,
    MuscleGroup.sideDelts: 30
  },
  'trap_3_raise': {MuscleGroup.traps: 70, MuscleGroup.rearDelts: 40},

  // --- Legs ---
  'squats': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 60,
    MuscleGroup.lowerBack: 30,
    MuscleGroup.hamstrings: 20
  },
  'front_squat': {
    MuscleGroup.quads: 100,
    MuscleGroup.glutes: 45,
    MuscleGroup.abs: 25
  },
  'box_squat': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 65,
    MuscleGroup.lowerBack: 30
  },
  'pause_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 65,
    MuscleGroup.lowerBack: 30
  },
  'bulgarian_split_squat': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 65,
    MuscleGroup.hamstrings: 25
  },
  'goblet_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 50,
    MuscleGroup.abs: 15
  },
  'hack_squat': {MuscleGroup.quads: 100, MuscleGroup.glutes: 40},
  'smith_machine_squat': {MuscleGroup.quads: 90, MuscleGroup.glutes: 55},
  'leg_press': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 50,
    MuscleGroup.hamstrings: 20
  },
  'single_leg_press': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 55,
    MuscleGroup.hamstrings: 20
  },
  'lunges': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 65,
    MuscleGroup.hamstrings: 25
  },
  'walking_lunges': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 70,
    MuscleGroup.hamstrings: 25
  },
  'reverse_lunges': {
    MuscleGroup.quads: 80,
    MuscleGroup.glutes: 70,
    MuscleGroup.hamstrings: 30
  },
  'step_ups': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 65,
    MuscleGroup.calves: 20
  },
  'leg_extension': {MuscleGroup.quads: 100},
  'leg_curl': {MuscleGroup.hamstrings: 100, MuscleGroup.glutes: 15},
  'seated_leg_curl': {MuscleGroup.hamstrings: 100, MuscleGroup.glutes: 15},
  'nordic_curl': {MuscleGroup.hamstrings: 100, MuscleGroup.glutes: 20},
  'hip_thrust': {
    MuscleGroup.glutes: 100,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.lowerBack: 15
  },
  'glute_bridge': {MuscleGroup.glutes: 100, MuscleGroup.hamstrings: 30},
  'cable_kickback': {MuscleGroup.glutes: 90, MuscleGroup.hamstrings: 20},
  'hip_abduction': {MuscleGroup.glutes: 80},
  'hip_adduction': {MuscleGroup.quads: 35, MuscleGroup.glutes: 20},
  'calf_raise': {MuscleGroup.calves: 100},
  'seated_calf_raise': {MuscleGroup.calves: 100},
  'leg_press_calf_raise': {MuscleGroup.calves: 100},
  'donkey_calf_raise': {MuscleGroup.calves: 100},
  'sissy_squat': {MuscleGroup.quads: 100, MuscleGroup.abs: 15},
  'zercher_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 50,
    MuscleGroup.lowerBack: 35,
    MuscleGroup.abs: 25
  },
  'overhead_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 45,
    MuscleGroup.sideDelts: 30,
    MuscleGroup.abs: 30
  },
  'safety_bar_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 50,
    MuscleGroup.lowerBack: 25
  },
  'banded_squat': {MuscleGroup.quads: 90, MuscleGroup.glutes: 55},
  'chain_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 55,
    MuscleGroup.lowerBack: 25
  },
  'sumo_squat': {
    MuscleGroup.glutes: 65,
    MuscleGroup.quads: 70,
    MuscleGroup.hamstrings: 25
  },
  'cyclist_squat': {MuscleGroup.quads: 100, MuscleGroup.glutes: 25},
  'spanish_squat': {MuscleGroup.quads: 100},
  'wall_sit': {MuscleGroup.quads: 90, MuscleGroup.glutes: 25},
  'pistol_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 55,
    MuscleGroup.hamstrings: 20,
    MuscleGroup.abs: 20
  },
  'shrimp_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 55,
    MuscleGroup.hamstrings: 25
  },
  'cossack_squat': {
    MuscleGroup.quads: 75,
    MuscleGroup.glutes: 60,
    MuscleGroup.hamstrings: 30,
    MuscleGroup.abs: 15
  },
  'curtsy_lunge': {
    MuscleGroup.glutes: 70,
    MuscleGroup.quads: 70,
    MuscleGroup.hamstrings: 25
  },
  'lateral_lunge': {
    MuscleGroup.quads: 65,
    MuscleGroup.glutes: 60,
    MuscleGroup.hamstrings: 25
  },
  'step_up_lateral': {
    MuscleGroup.quads: 75,
    MuscleGroup.glutes: 65,
    MuscleGroup.calves: 20
  },
  'vertical_leg_press': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 50,
    MuscleGroup.hamstrings: 20
  },
  'narrow_stance_leg_press': {MuscleGroup.quads: 100, MuscleGroup.glutes: 30},
  'wide_stance_leg_press': {
    MuscleGroup.quads: 75,
    MuscleGroup.glutes: 60,
    MuscleGroup.hamstrings: 25
  },
  'belt_squat': {MuscleGroup.quads: 90, MuscleGroup.glutes: 50},
  'sled_push': {
    MuscleGroup.quads: 80,
    MuscleGroup.glutes: 45,
    MuscleGroup.calves: 30
  },
  'sled_pull': {
    MuscleGroup.quads: 70,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.glutes: 35
  },
  'prowler_sprint': {
    MuscleGroup.quads: 75,
    MuscleGroup.glutes: 50,
    MuscleGroup.calves: 30
  },
  'glute_ham_raise': {
    MuscleGroup.hamstrings: 100,
    MuscleGroup.glutes: 40,
    MuscleGroup.calves: 20
  },
  'reverse_nordic_curl': {MuscleGroup.quads: 100, MuscleGroup.abs: 20},
  'single_leg_deadlift': {
    MuscleGroup.hamstrings: 85,
    MuscleGroup.glutes: 60,
    MuscleGroup.lowerBack: 30,
    MuscleGroup.abs: 20,
  },
  'single_leg_romanian_deadlift': {
    MuscleGroup.hamstrings: 90,
    MuscleGroup.glutes: 55,
    MuscleGroup.lowerBack: 25
  },
  'kettlebell_swing': {
    MuscleGroup.glutes: 80,
    MuscleGroup.hamstrings: 60,
    MuscleGroup.lowerBack: 30
  },
  'single_leg_hip_thrust': {
    MuscleGroup.glutes: 100,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.abs: 15
  },
  'frog_pump': {MuscleGroup.glutes: 100},
  'banded_hip_thrust': {MuscleGroup.glutes: 100, MuscleGroup.hamstrings: 30},
  'cable_pull_through': {
    MuscleGroup.glutes: 85,
    MuscleGroup.hamstrings: 55,
    MuscleGroup.lowerBack: 20
  },
  'standing_hip_abduction_cable': {MuscleGroup.glutes: 85},
  'standing_hip_adduction_cable': {
    MuscleGroup.quads: 30,
    MuscleGroup.glutes: 20
  },
  'monster_walk': {MuscleGroup.glutes: 80, MuscleGroup.quads: 20},
  'lateral_band_walk': {MuscleGroup.glutes: 85},
  'clamshells': {MuscleGroup.glutes: 85},
  'copenhagen_plank': {
    MuscleGroup.quads: 40,
    MuscleGroup.abs: 35,
    MuscleGroup.glutes: 20
  },
  'smith_machine_calf_raise': {MuscleGroup.calves: 100},
  'single_leg_calf_raise': {MuscleGroup.calves: 100},
  'tibialis_raise': {MuscleGroup.quads: 30, MuscleGroup.calves: 15},
  'jump_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 45,
    MuscleGroup.calves: 30
  },
  'box_jump': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 50,
    MuscleGroup.calves: 35
  },
  'broad_jump': {
    MuscleGroup.quads: 80,
    MuscleGroup.glutes: 55,
    MuscleGroup.calves: 35
  },
  'depth_jump': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 45,
    MuscleGroup.calves: 40
  },
  'sled_drag': {
    MuscleGroup.quads: 75,
    MuscleGroup.glutes: 35,
    MuscleGroup.hamstrings: 25
  },
  'resistance_band_leg_curl': {MuscleGroup.hamstrings: 100},
  'skater_squat': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 55,
    MuscleGroup.hamstrings: 20
  },
  'adductor_side_plank': {
    MuscleGroup.quads: 30,
    MuscleGroup.abs: 40,
    MuscleGroup.obliques: 30
  },
  'hip_circles': {MuscleGroup.glutes: 40},
  'lateral_step_down': {MuscleGroup.quads: 80, MuscleGroup.glutes: 50},
  'bodyweight_squat': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 45,
    MuscleGroup.hamstrings: 20
  },
  'jump_lunge': {
    MuscleGroup.quads: 85,
    MuscleGroup.glutes: 55,
    MuscleGroup.calves: 30
  },
  'leg_press_toe_press': {MuscleGroup.calves: 100},

  // --- Arms ---
  'barbell_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 25},
  'ez_bar_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 25},
  'dumbbell_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 25},
  'alternating_dumbbell_curl': {
    MuscleGroup.biceps: 100,
    MuscleGroup.forearms: 25
  },
  'hammer_curl': {MuscleGroup.biceps: 80, MuscleGroup.forearms: 55},
  'preacher_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 15},
  'concentration_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 15},
  'cable_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 20},
  'spider_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 15},
  'drag_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 20},
  'reverse_curl': {MuscleGroup.biceps: 75, MuscleGroup.forearms: 60},
  'triceps_pushdown': {MuscleGroup.triceps: 100},
  'rope_pushdown': {MuscleGroup.triceps: 100},
  'overhead_triceps_extension': {MuscleGroup.triceps: 100},
  'skull_crushers': {MuscleGroup.triceps: 100},
  'close_grip_bench_triceps': {
    MuscleGroup.triceps: 75,
    MuscleGroup.chest: 45,
    MuscleGroup.frontDelts: 20
  },
  'close_grip_push_up': {
    MuscleGroup.triceps: 70,
    MuscleGroup.chest: 60,
    MuscleGroup.frontDelts: 25
  },
  'triceps_dip_machine': {MuscleGroup.triceps: 100, MuscleGroup.chest: 20},
  'wrist_curl': {MuscleGroup.forearms: 100},
  'reverse_wrist_curl': {MuscleGroup.forearms: 100},
  'forearm_training': {MuscleGroup.forearms: 100},
  'incline_dumbbell_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 15},
  'zottman_curl': {MuscleGroup.biceps: 85, MuscleGroup.forearms: 55},
  'cross_body_hammer_curl': {MuscleGroup.biceps: 75, MuscleGroup.forearms: 55},
  'cable_hammer_curl': {MuscleGroup.biceps: 75, MuscleGroup.forearms: 55},
  'bayesian_cable_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 15},
  'waiter_curl': {MuscleGroup.biceps: 90, MuscleGroup.forearms: 20},
  'preacher_curl_machine': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 15},
  'behind_the_back_cable_curl': {
    MuscleGroup.biceps: 100,
    MuscleGroup.forearms: 20
  },
  'lying_cable_curl': {MuscleGroup.biceps: 100},
  'twenty_one_curls': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 20},
  'wide_grip_barbell_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 15},
  'close_grip_ez_bar_curl': {MuscleGroup.biceps: 90, MuscleGroup.forearms: 30},
  'tricep_kickback': {MuscleGroup.triceps: 100},
  'overhead_cable_triceps_extension': {MuscleGroup.triceps: 100},
  'single_arm_overhead_triceps_extension': {MuscleGroup.triceps: 100},
  'jm_press': {MuscleGroup.triceps: 85, MuscleGroup.chest: 25},
  'tate_press': {MuscleGroup.triceps: 100, MuscleGroup.chest: 15},
  'triceps_dip_bench': {
    MuscleGroup.triceps: 85,
    MuscleGroup.chest: 20,
    MuscleGroup.frontDelts: 20
  },
  'single_arm_triceps_pushdown': {MuscleGroup.triceps: 100},
  'plate_pinch': {MuscleGroup.forearms: 100},
  'wrist_roller': {MuscleGroup.forearms: 100},
  'behind_back_wrist_curl': {MuscleGroup.forearms: 100},
  'finger_curls': {MuscleGroup.forearms: 100},
  'dead_hang': {MuscleGroup.forearms: 90, MuscleGroup.lats: 20},
  'resistance_band_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 20},
  'resistance_band_triceps_extension': {MuscleGroup.triceps: 100},
  'seated_dumbbell_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 15},
  'kettlebell_curl': {MuscleGroup.biceps: 95, MuscleGroup.forearms: 25},
  'single_arm_dumbbell_preacher_curl': {
    MuscleGroup.biceps: 100,
    MuscleGroup.forearms: 15
  },
  'incline_skull_crusher': {MuscleGroup.triceps: 100},
  'hercules_hold': {
    MuscleGroup.biceps: 60,
    MuscleGroup.triceps: 60,
    MuscleGroup.forearms: 50
  },
  'thick_bar_curl': {MuscleGroup.biceps: 95, MuscleGroup.forearms: 50},

  // --- Core ---
  'plank': {MuscleGroup.abs: 80, MuscleGroup.obliques: 50},
  'side_plank': {MuscleGroup.obliques: 90, MuscleGroup.abs: 40},
  'crunches': {MuscleGroup.abs: 100},
  'bicycle_crunches': {MuscleGroup.abs: 90, MuscleGroup.obliques: 60},
  'cable_crunch': {MuscleGroup.abs: 100},
  'sit_ups': {MuscleGroup.abs: 100},
  'leg_raise': {MuscleGroup.abs: 100, MuscleGroup.quads: 15},
  'hanging_leg_raise': {MuscleGroup.abs: 100, MuscleGroup.forearms: 20},
  'hanging_knee_raise': {MuscleGroup.abs: 100, MuscleGroup.forearms: 15},
  'russian_twist': {MuscleGroup.obliques: 100, MuscleGroup.abs: 40},
  'ab_wheel': {
    MuscleGroup.abs: 100,
    MuscleGroup.obliques: 30,
    MuscleGroup.lowerBack: 20
  },
  'mountain_climbers': {
    MuscleGroup.abs: 80,
    MuscleGroup.quads: 30,
    MuscleGroup.frontDelts: 20
  },
  'flutter_kicks': {MuscleGroup.abs: 100, MuscleGroup.quads: 15},
  'dead_bug': {MuscleGroup.abs: 85, MuscleGroup.obliques: 35},
  'pallof_press': {MuscleGroup.obliques: 90, MuscleGroup.abs: 40},
  'woodchopper': {MuscleGroup.obliques: 100, MuscleGroup.abs: 35},
  'reverse_crunch': {MuscleGroup.abs: 100},
  'weighted_crunch': {MuscleGroup.abs: 100},
  'decline_sit_up': {MuscleGroup.abs: 100, MuscleGroup.obliques: 20},
  'v_ups': {MuscleGroup.abs: 100, MuscleGroup.obliques: 25},
  'toe_touches': {MuscleGroup.abs: 100},
  'hollow_body_hold': {MuscleGroup.abs: 100, MuscleGroup.obliques: 20},
  'bird_dog': {
    MuscleGroup.abs: 70,
    MuscleGroup.lowerBack: 40,
    MuscleGroup.glutes: 30
  },
  'side_bend': {MuscleGroup.obliques: 100},
  'cable_side_bend': {MuscleGroup.obliques: 100},
  'landmine_rotation': {MuscleGroup.obliques: 90, MuscleGroup.abs: 35},
  'medicine_ball_slam': {
    MuscleGroup.abs: 60,
    MuscleGroup.lats: 30,
    MuscleGroup.sideDelts: 30
  },
  'medicine_ball_rotational_throw': {
    MuscleGroup.obliques: 85,
    MuscleGroup.abs: 35
  },
  'hanging_windshield_wipers': {MuscleGroup.obliques: 100, MuscleGroup.abs: 40},
  'l_sit': {
    MuscleGroup.abs: 90,
    MuscleGroup.quads: 30,
    MuscleGroup.triceps: 20
  },
  'toes_to_bar': {
    MuscleGroup.abs: 100,
    MuscleGroup.lats: 30,
    MuscleGroup.forearms: 25
  },
  'captains_chair_raise': {MuscleGroup.abs: 100},
  'stability_ball_rollout': {
    MuscleGroup.abs: 90,
    MuscleGroup.obliques: 25,
    MuscleGroup.lowerBack: 15
  },
  'stir_the_pot': {MuscleGroup.abs: 85, MuscleGroup.obliques: 40},
  'plank_shoulder_tap': {
    MuscleGroup.abs: 85,
    MuscleGroup.obliques: 35,
    MuscleGroup.frontDelts: 15
  },
  'sledgehammer_swing': {
    MuscleGroup.obliques: 70,
    MuscleGroup.abs: 40,
    MuscleGroup.forearms: 30
  },
  'turkish_get_up': {
    MuscleGroup.abs: 60,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.glutes: 30,
    MuscleGroup.quads: 25
  },
  'jackknife_situp': {MuscleGroup.abs: 100},
  'scissor_kicks': {MuscleGroup.abs: 90, MuscleGroup.quads: 15},
  'side_crunch': {MuscleGroup.obliques: 100},
  'weighted_plank': {MuscleGroup.abs: 85, MuscleGroup.obliques: 50},
  'stability_ball_pike': {MuscleGroup.abs: 90, MuscleGroup.frontDelts: 20},
  'cocoons': {MuscleGroup.abs: 95},
  'dragon_flag': {
    MuscleGroup.abs: 100,
    MuscleGroup.obliques: 35,
    MuscleGroup.lats: 15
  },
  'hanging_knee_to_elbow': {MuscleGroup.obliques: 90, MuscleGroup.abs: 50},
  'standing_cable_crunch': {MuscleGroup.abs: 100},
  'kneeling_cable_crunch': {MuscleGroup.abs: 100},
  'bosu_ball_crunch': {MuscleGroup.abs: 90, MuscleGroup.obliques: 20},
  'seated_knee_tuck': {MuscleGroup.abs: 100},
  'bear_crawl': {
    MuscleGroup.abs: 60,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.quads: 25
  },
  'plank_jacks': {
    MuscleGroup.abs: 80,
    MuscleGroup.obliques: 30,
    MuscleGroup.quads: 20
  },
  'side_plank_rotation': {MuscleGroup.obliques: 100, MuscleGroup.abs: 35},

  // --- Cardio ---
  'running': {
    MuscleGroup.quads: 60,
    MuscleGroup.calves: 60,
    MuscleGroup.hamstrings: 40,
    MuscleGroup.glutes: 30
  },
  'treadmill': {
    MuscleGroup.quads: 60,
    MuscleGroup.calves: 60,
    MuscleGroup.hamstrings: 40,
    MuscleGroup.glutes: 30
  },
  'rowing_machine': {
    MuscleGroup.lats: 60,
    MuscleGroup.quads: 40,
    MuscleGroup.upperBack: 40,
    MuscleGroup.biceps: 25
  },
  'cycling': {
    MuscleGroup.quads: 80,
    MuscleGroup.calves: 40,
    MuscleGroup.hamstrings: 25
  },
  'stationary_bike': {
    MuscleGroup.quads: 80,
    MuscleGroup.calves: 40,
    MuscleGroup.hamstrings: 25
  },
  'jump_rope': {MuscleGroup.calves: 90, MuscleGroup.quads: 30},
  'stair_climber': {
    MuscleGroup.quads: 70,
    MuscleGroup.glutes: 50,
    MuscleGroup.calves: 40
  },
  'elliptical': {
    MuscleGroup.quads: 55,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.glutes: 30
  },
  'battle_ropes': {
    MuscleGroup.frontDelts: 50,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.abs: 40,
    MuscleGroup.forearms: 30
  },
  'burpees': {
    MuscleGroup.quads: 50,
    MuscleGroup.chest: 40,
    MuscleGroup.abs: 40,
    MuscleGroup.frontDelts: 30
  },
  'swimming': {
    MuscleGroup.lats: 50,
    MuscleGroup.frontDelts: 40,
    MuscleGroup.abs: 30,
    MuscleGroup.quads: 25
  },
  'sprints': {
    MuscleGroup.quads: 70,
    MuscleGroup.hamstrings: 55,
    MuscleGroup.calves: 45,
    MuscleGroup.glutes: 35
  },
  'hiit': {MuscleGroup.quads: 55, MuscleGroup.calves: 40, MuscleGroup.abs: 30},
  'shadow_boxing': {
    MuscleGroup.frontDelts: 40,
    MuscleGroup.triceps: 35,
    MuscleGroup.abs: 30
  },
  'heavy_bag_boxing': {
    MuscleGroup.frontDelts: 45,
    MuscleGroup.triceps: 35,
    MuscleGroup.abs: 30
  },
  'assault_bike': {
    MuscleGroup.quads: 60,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.calves: 30
  },
  'ski_erg': {
    MuscleGroup.lats: 55,
    MuscleGroup.triceps: 35,
    MuscleGroup.abs: 30
  },
  'incline_treadmill_walk': {
    MuscleGroup.glutes: 55,
    MuscleGroup.quads: 50,
    MuscleGroup.calves: 40
  },
  'hiking': {
    MuscleGroup.quads: 55,
    MuscleGroup.glutes: 40,
    MuscleGroup.calves: 35
  },
  'stair_sprints': {
    MuscleGroup.quads: 65,
    MuscleGroup.glutes: 50,
    MuscleGroup.calves: 40
  },
  'jacobs_ladder': {
    MuscleGroup.quads: 55,
    MuscleGroup.glutes: 45,
    MuscleGroup.lats: 20
  },
  'versaclimber': {
    MuscleGroup.quads: 50,
    MuscleGroup.lats: 35,
    MuscleGroup.glutes: 30
  },
  'tire_flip': {
    MuscleGroup.quads: 55,
    MuscleGroup.glutes: 50,
    MuscleGroup.chest: 30,
    MuscleGroup.lowerBack: 30
  },
  'jumping_jacks': {
    MuscleGroup.quads: 35,
    MuscleGroup.calves: 35,
    MuscleGroup.sideDelts: 25
  },
  'high_knees': {
    MuscleGroup.quads: 55,
    MuscleGroup.abs: 30,
    MuscleGroup.calves: 30
  },
  'dancing': {
    MuscleGroup.quads: 35,
    MuscleGroup.calves: 30,
    MuscleGroup.abs: 20
  },
  'inline_skating': {
    MuscleGroup.quads: 55,
    MuscleGroup.glutes: 40,
    MuscleGroup.calves: 35
  },
  'cross_country_skiing': {
    MuscleGroup.quads: 45,
    MuscleGroup.glutes: 35,
    MuscleGroup.lats: 30
  },
  'walking': {
    MuscleGroup.quads: 30,
    MuscleGroup.calves: 30,
    MuscleGroup.glutes: 20
  },
  'nordic_walking': {
    MuscleGroup.quads: 35,
    MuscleGroup.calves: 30,
    MuscleGroup.triceps: 15
  },
  'water_aerobics': {
    MuscleGroup.quads: 35,
    MuscleGroup.abs: 25,
    MuscleGroup.frontDelts: 20
  },
  'agility_ladder': {MuscleGroup.quads: 40, MuscleGroup.calves: 35},
  'spin_class': {
    MuscleGroup.quads: 65,
    MuscleGroup.calves: 30,
    MuscleGroup.hamstrings: 25
  },
  'sandbag_carry': {
    MuscleGroup.quads: 50,
    MuscleGroup.glutes: 40,
    MuscleGroup.forearms: 40,
    MuscleGroup.abs: 30
  },
  'rucking': {
    MuscleGroup.quads: 45,
    MuscleGroup.glutes: 35,
    MuscleGroup.calves: 30,
    MuscleGroup.traps: 20
  },
  'zumba': {MuscleGroup.quads: 35, MuscleGroup.calves: 30, MuscleGroup.abs: 20},
  'kickboxing': {
    MuscleGroup.quads: 35,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.abs: 30
  },
  'atlas_stones': {
    MuscleGroup.lowerBack: 60,
    MuscleGroup.glutes: 45,
    MuscleGroup.quads: 40,
    MuscleGroup.forearms: 40,
  },
  'kettlebell_floor_press': {
    MuscleGroup.chest: 80,
    MuscleGroup.triceps: 55,
    MuscleGroup.frontDelts: 20
  },
  'trx_chest_press': {
    MuscleGroup.chest: 85,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.triceps: 30,
    MuscleGroup.abs: 15
  },
  'diamond_push_up': {
    MuscleGroup.triceps: 70,
    MuscleGroup.chest: 60,
    MuscleGroup.frontDelts: 20
  },
  'spiderman_push_up': {
    MuscleGroup.chest: 80,
    MuscleGroup.abs: 40,
    MuscleGroup.obliques: 35,
    MuscleGroup.triceps: 30
  },
  'one_arm_push_up': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 50,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 30
  },
  'machine_incline_press': {
    MuscleGroup.chest: 90,
    MuscleGroup.frontDelts: 50,
    MuscleGroup.triceps: 30
  },
  'hex_press': {MuscleGroup.chest: 100, MuscleGroup.triceps: 25},
  'guillotine_press': {
    MuscleGroup.chest: 100,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.triceps: 30
  },
  'cross_body_cable_fly': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 15},
  'resistance_band_fly': {MuscleGroup.chest: 100, MuscleGroup.frontDelts: 15},
  'medicine_ball_chest_pass': {
    MuscleGroup.chest: 75,
    MuscleGroup.triceps: 35,
    MuscleGroup.frontDelts: 25,
    MuscleGroup.abs: 15
  },
  'banded_push_up': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 25
  },
  'iso_lateral_chest_press_machine': {
    MuscleGroup.chest: 95,
    MuscleGroup.frontDelts: 35,
    MuscleGroup.triceps: 30
  },
  'ring_push_up': {
    MuscleGroup.chest: 90,
    MuscleGroup.triceps: 45,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 20
  },
  'ring_dip': {
    MuscleGroup.chest: 80,
    MuscleGroup.triceps: 65,
    MuscleGroup.frontDelts: 30
  },
  'assisted_dip_machine': {
    MuscleGroup.chest: 75,
    MuscleGroup.triceps: 55,
    MuscleGroup.frontDelts: 25
  },
  'kettlebell_clean': {
    MuscleGroup.traps: 50,
    MuscleGroup.lats: 35,
    MuscleGroup.glutes: 40,
    MuscleGroup.hamstrings: 35,
    MuscleGroup.forearms: 40,
  },
  'kettlebell_high_pull': {
    MuscleGroup.traps: 60,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.upperBack: 35
  },
  'single_arm_kettlebell_row': {
    MuscleGroup.lats: 80,
    MuscleGroup.upperBack: 55,
    MuscleGroup.biceps: 30
  },
  'atlas_stone_lift': {
    MuscleGroup.lowerBack: 60,
    MuscleGroup.glutes: 55,
    MuscleGroup.quads: 45,
    MuscleGroup.upperBack: 35,
    MuscleGroup.abs: 30,
  },
  'trx_row': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 55,
    MuscleGroup.biceps: 35
  },
  'batwing_row': {
    MuscleGroup.upperBack: 80,
    MuscleGroup.lats: 50,
    MuscleGroup.rearDelts: 30
  },
  'cable_pullover': {
    MuscleGroup.lats: 70,
    MuscleGroup.chest: 40,
    MuscleGroup.triceps: 20
  },
  'zercher_deadlift': {
    MuscleGroup.lowerBack: 70,
    MuscleGroup.quads: 40,
    MuscleGroup.glutes: 45,
    MuscleGroup.biceps: 25,
    MuscleGroup.abs: 30,
  },
  'commando_pull_up': {
    MuscleGroup.lats: 85,
    MuscleGroup.biceps: 50,
    MuscleGroup.obliques: 20
  },
  'typewriter_pull_up': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 45,
    MuscleGroup.upperBack: 30
  },
  'negative_pull_up': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 45,
    MuscleGroup.upperBack: 25
  },
  'ring_row': {
    MuscleGroup.upperBack: 65,
    MuscleGroup.lats: 45,
    MuscleGroup.biceps: 30
  },
  'ring_pull_up': {
    MuscleGroup.lats: 90,
    MuscleGroup.biceps: 50,
    MuscleGroup.upperBack: 30
  },
  'front_lever': {
    MuscleGroup.lats: 90,
    MuscleGroup.abs: 60,
    MuscleGroup.upperBack: 35
  },
  'tuck_front_lever': {
    MuscleGroup.lats: 80,
    MuscleGroup.abs: 55,
    MuscleGroup.upperBack: 30
  },
  'back_lever': {
    MuscleGroup.lats: 70,
    MuscleGroup.chest: 40,
    MuscleGroup.abs: 35,
    MuscleGroup.frontDelts: 25
  },
  'skin_the_cat': {
    MuscleGroup.lats: 60,
    MuscleGroup.abs: 50,
    MuscleGroup.upperBack: 30
  },
  'snatch_pull': {
    MuscleGroup.traps: 65,
    MuscleGroup.lowerBack: 55,
    MuscleGroup.hamstrings: 45,
    MuscleGroup.upperBack: 40
  },
  'towel_pull_up': {
    MuscleGroup.lats: 85,
    MuscleGroup.forearms: 60,
    MuscleGroup.biceps: 40
  },
  'iso_lateral_row_machine': {
    MuscleGroup.upperBack: 70,
    MuscleGroup.lats: 55,
    MuscleGroup.biceps: 25
  },
  'log_press': {
    MuscleGroup.frontDelts: 80,
    MuscleGroup.triceps: 45,
    MuscleGroup.sideDelts: 30,
    MuscleGroup.abs: 20
  },
  'axle_press': {
    MuscleGroup.frontDelts: 85,
    MuscleGroup.triceps: 45,
    MuscleGroup.sideDelts: 30
  },
  'kettlebell_push_press': {
    MuscleGroup.frontDelts: 80,
    MuscleGroup.triceps: 40,
    MuscleGroup.quads: 20
  },
  'single_arm_landmine_press': {
    MuscleGroup.frontDelts: 80,
    MuscleGroup.sideDelts: 30,
    MuscleGroup.triceps: 35,
    MuscleGroup.abs: 15
  },
  'band_front_raise': {MuscleGroup.frontDelts: 100},
  'lu_raise': {MuscleGroup.sideDelts: 90, MuscleGroup.frontDelts: 30},
  'w_raise': {
    MuscleGroup.rearDelts: 80,
    MuscleGroup.sideDelts: 30,
    MuscleGroup.upperBack: 20
  },
  'scarecrow': {MuscleGroup.rearDelts: 75, MuscleGroup.sideDelts: 25},
  'plate_raise_360': {
    MuscleGroup.sideDelts: 60,
    MuscleGroup.frontDelts: 60,
    MuscleGroup.rearDelts: 40
  },
  'trx_y_fly': {
    MuscleGroup.rearDelts: 70,
    MuscleGroup.sideDelts: 30,
    MuscleGroup.upperBack: 30
  },
  'incline_rear_delt_row': {
    MuscleGroup.rearDelts: 70,
    MuscleGroup.upperBack: 40
  },
  'kettlebell_arnold_press': {
    MuscleGroup.frontDelts: 80,
    MuscleGroup.sideDelts: 50,
    MuscleGroup.triceps: 30
  },
  'band_shoulder_press': {
    MuscleGroup.frontDelts: 85,
    MuscleGroup.sideDelts: 35,
    MuscleGroup.triceps: 30
  },
  'cable_shoulder_press': {
    MuscleGroup.frontDelts: 85,
    MuscleGroup.sideDelts: 40,
    MuscleGroup.triceps: 30
  },
  'powell_raise': {MuscleGroup.sideDelts: 90, MuscleGroup.frontDelts: 25},
  'javelin_press': {
    MuscleGroup.frontDelts: 80,
    MuscleGroup.sideDelts: 30,
    MuscleGroup.triceps: 30,
    MuscleGroup.forearms: 25
  },
  'tuck_jump': {
    MuscleGroup.quads: 65,
    MuscleGroup.calves: 45,
    MuscleGroup.abs: 25
  },
  'lateral_bound': {
    MuscleGroup.quads: 60,
    MuscleGroup.glutes: 60,
    MuscleGroup.calves: 35,
    MuscleGroup.obliques: 20
  },
  'kettlebell_front_squat': {
    MuscleGroup.quads: 90,
    MuscleGroup.glutes: 45,
    MuscleGroup.abs: 20
  },
  'landmine_squat': {MuscleGroup.quads: 85, MuscleGroup.glutes: 50},
  'deficit_reverse_lunge': {
    MuscleGroup.glutes: 75,
    MuscleGroup.quads: 60,
    MuscleGroup.hamstrings: 30
  },
  'band_lateral_walk': {MuscleGroup.glutes: 80, MuscleGroup.quads: 20},
  'banded_clamshell': {MuscleGroup.glutes: 85},
  'glute_kickback_machine': {
    MuscleGroup.glutes: 90,
    MuscleGroup.hamstrings: 20
  },
  'step_down': {MuscleGroup.quads: 75, MuscleGroup.glutes: 40},
  'jefferson_curl': {
    MuscleGroup.hamstrings: 60,
    MuscleGroup.lowerBack: 50,
    MuscleGroup.abs: 20
  },
  'v_squat_machine': {MuscleGroup.quads: 95, MuscleGroup.glutes: 45},
  'single_leg_glute_bridge': {
    MuscleGroup.glutes: 100,
    MuscleGroup.hamstrings: 25
  },
  'standing_hamstring_curl_machine': {MuscleGroup.hamstrings: 100},
  'kettlebell_lunge': {
    MuscleGroup.quads: 80,
    MuscleGroup.glutes: 65,
    MuscleGroup.hamstrings: 25
  },
  'smith_machine_lunge': {MuscleGroup.quads: 80, MuscleGroup.glutes: 60},
  'pogo_jump': {MuscleGroup.calves: 80, MuscleGroup.quads: 20},
  'kettlebell_step_up': {
    MuscleGroup.quads: 80,
    MuscleGroup.glutes: 60,
    MuscleGroup.calves: 20
  },
  'band_bicep_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 20},
  'bench_dip': {
    MuscleGroup.triceps: 85,
    MuscleGroup.chest: 25,
    MuscleGroup.frontDelts: 20
  },
  'kettlebell_overhead_triceps_extension': {MuscleGroup.triceps: 100},
  'grip_trainer': {MuscleGroup.forearms: 100},
  'preacher_hammer_curl': {MuscleGroup.biceps: 70, MuscleGroup.forearms: 55},
  'single_arm_dumbbell_overhead_extension': {MuscleGroup.triceps: 100},
  'overhead_cable_curl': {MuscleGroup.biceps: 100},
  'machine_bicep_curl': {MuscleGroup.biceps: 100},
  'machine_tricep_extension': {MuscleGroup.triceps: 100},
  'band_hammer_curl': {MuscleGroup.biceps: 75, MuscleGroup.forearms: 55},
  'windshield_wiper': {MuscleGroup.obliques: 90, MuscleGroup.abs: 40},
  'medicine_ball_russian_twist': {
    MuscleGroup.obliques: 90,
    MuscleGroup.abs: 30
  },
  'trx_pike': {
    MuscleGroup.abs: 85,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.quads: 15
  },
  'trx_mountain_climber': {
    MuscleGroup.abs: 75,
    MuscleGroup.quads: 25,
    MuscleGroup.frontDelts: 20
  },
  'trx_body_saw': {MuscleGroup.abs: 90, MuscleGroup.frontDelts: 20},
  'sit_up_weighted': {MuscleGroup.abs: 100},
  'plank_up_down': {
    MuscleGroup.abs: 75,
    MuscleGroup.triceps: 30,
    MuscleGroup.chest: 25
  },
  'captains_chair_leg_raise': {MuscleGroup.abs: 100},
  'swiss_ball_crunch': {MuscleGroup.abs: 90, MuscleGroup.obliques: 20},
  'kettlebell_windmill': {
    MuscleGroup.obliques: 70,
    MuscleGroup.sideDelts: 35,
    MuscleGroup.hamstrings: 30
  },
  'kettlebell_halo': {
    MuscleGroup.abs: 40,
    MuscleGroup.sideDelts: 45,
    MuscleGroup.frontDelts: 35
  },
  'shuttle_run': {
    MuscleGroup.quads: 55,
    MuscleGroup.hamstrings: 45,
    MuscleGroup.calves: 40
  },
  'arc_trainer': {
    MuscleGroup.quads: 60,
    MuscleGroup.glutes: 40,
    MuscleGroup.calves: 30
  },
  'recumbent_bike': {MuscleGroup.quads: 70, MuscleGroup.hamstrings: 25},
  'wall_ball': {
    MuscleGroup.quads: 55,
    MuscleGroup.glutes: 40,
    MuscleGroup.frontDelts: 30,
    MuscleGroup.abs: 30
  },
  // Neck training has no illustrated region of its own -- MuscleGroup.traps
  // (already drawn, on the back view) sits right where the neck attaches
  // and is the closest real muscle these exercises actually recruit, same
  // honest-approximation spirit as the geometric head/region splits noted
  // on MuscleGroup itself.
  'neck_curl': {MuscleGroup.traps: 70},
  'neck_extension': {MuscleGroup.traps: 80, MuscleGroup.upperBack: 20},
  'lateral_neck_flexion': {MuscleGroup.traps: 70},
  'neck_rotation': {MuscleGroup.traps: 60},
  'neck_harness_flexion': {MuscleGroup.traps: 75},
  'neck_harness_extension': {MuscleGroup.traps: 80, MuscleGroup.upperBack: 15},
  'four_way_neck_machine': {MuscleGroup.traps: 85},
  'wrestlers_bridge': {
    MuscleGroup.traps: 60,
    MuscleGroup.upperBack: 20,
    MuscleGroup.abs: 15
  },
  'single_leg_extension': {MuscleGroup.quads: 100},
  'reverse_hack_squat': {
    MuscleGroup.quads: 75,
    MuscleGroup.glutes: 55,
    MuscleGroup.hamstrings: 20
  },
  'single_arm_cable_curl': {MuscleGroup.biceps: 100, MuscleGroup.forearms: 20},
};
