import '../data/constants.dart';
import '../models/program.dart';
import '../state/programs_provider.dart';
import '../state/train_state_provider.dart';

/// [plan]'s planned rest days as a date test for [computeConsistency]: the
/// day the plan shows for that weekday is marked rest, or a moved-away day
/// left that date empty -- the same date-scoped override resolution the
/// Training screen uses ([resolveDayOverride]), so the streak agrees with
/// what the plan showed. Applied to past dates with the plan as it is now.
///
/// Null -- no rest-day grace -- for rotation plans, whose rest days follow
/// the rotation and aren't tied to calendar dates.
bool Function(DateTime day)? planRestDays(
  Program plan, {
  required int? Function(String planId, String iso) overrideFor,
}) {
  if (plan.mode != 'weekday' || plan.days.isEmpty) return null;
  return (day) {
    final idx = resolveDayOverride(
      defaultIdx: day.weekday - 1, // Dart Mon=1..Sun=7 -> Mon=0..Sun=6
      daysLength: plan.days.length,
      overrideIdx: overrideFor(plan.id, isoOf(day)),
    );
    // A weekday the plan has no day for counts as rest, as on the
    // Training screen.
    return idx < 0 || idx >= plan.days.length || plan.days[idx].rest;
  };
}

/// [planRestDays] for the plan the Training screen shows (the active one,
/// else the first), or null when there's no plan.
bool Function(DateTime day)? activePlanRestDays(ProgramsProvider programs, TrainStateProvider trainState) {
  final all = programs.programs;
  if (all.isEmpty) return null;
  final plan = programs.byId(trainState.activePlanId) ?? all.first;
  return planRestDays(plan, overrideFor: trainState.dayOverride);
}
