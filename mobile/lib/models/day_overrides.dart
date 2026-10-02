/// Per-plan, per-ISO-date "show a different Day" override -- lets a user
/// reschedule a single day's session onto another calendar date (see
/// `widgets/move_day_sheet.dart` / `TrainStateProvider.moveDayOverride`)
/// without ever touching the saved [Program]/[Day] list itself. Stored
/// entirely separately from the plan (see `TrainStateProvider`, keyed under
/// its own `'ironpeak:dayOverrides'` kv entry) so plan export/import
/// (`services/plan_share_codec.dart`) never carries someone else's personal
/// reschedules, and switching plans never mixes up which plan an override
/// belongs to.
///
/// `-1` is a sentinel meaning "explicitly rest/skipped this date" (the
/// vacated source of a move); any other stored value is meant to be an
/// index into that plan's `days`, but is bounds-checked again at read time
/// by `resolveDayOverride` (see `data/constants.dart`) rather than trusted
/// blindly, since a hand-edited or foreign backup could contain a stale
/// index for a plan whose day count has since changed.
class DayOverrides {
  DayOverrides({Map<String, Map<String, int>>? byPlan})
      : byPlan = byPlan ?? {};

  /// planId -> { isoDate -> dayIdx }
  final Map<String, Map<String, int>> byPlan;

  int? get(String planId, String iso) => byPlan[planId]?[iso];

  void set(String planId, String iso, int value) {
    (byPlan[planId] ??= {})[iso] = value;
  }

  /// Removes only the one plan+date entry, leaving every other date (and
  /// every other plan) untouched.
  void clear(String planId, String iso) {
    final dates = byPlan[planId];
    if (dates == null) return;
    dates.remove(iso);
    if (dates.isEmpty) byPlan.remove(planId);
  }

  /// Drops every entry for one plan (e.g. once that plan itself is
  /// deleted) -- hygiene rather than a correctness requirement, since a
  /// leftover entry for a gone plan id is never looked up again anyway.
  void dropPlan(String planId) => byPlan.remove(planId);

  /// Drops every entry dated strictly before [todayIso], and any plan left
  /// with no remaining dates. ISO 'YYYY-MM-DD' strings sort lexicographically
  /// the same as the dates they represent, so a plain string compare is
  /// enough -- no need to parse them.
  void pruneBefore(String todayIso) {
    final emptyPlans = <String>[];
    for (final entry in byPlan.entries) {
      entry.value.removeWhere((iso, _) => iso.compareTo(todayIso) < 0);
      if (entry.value.isEmpty) emptyPlans.add(entry.key);
    }
    for (final planId in emptyPlans) {
      byPlan.remove(planId);
    }
  }

  Map<String, dynamic> toJson() => {
        for (final entry in byPlan.entries) entry.key: entry.value,
      };

  /// Defensive: missing/null/non-Map input yields an empty store rather
  /// than throwing -- this is exactly what happens on any install/backup
  /// predating this feature, since `'ironpeak:dayOverrides'` is a brand-new
  /// kv key they simply never wrote (no DB migration needed). A per-plan
  /// value that isn't itself a Map, or a per-date value that isn't a `num`,
  /// is skipped rather than failing the whole decode -- old-backup/foreign-
  /// data safe.
  factory DayOverrides.fromJson(dynamic json) {
    final byPlan = <String, Map<String, int>>{};
    if (json is Map) {
      for (final planEntry in json.entries) {
        final planId = planEntry.key;
        final rawDates = planEntry.value;
        if (planId is! String || rawDates is! Map) continue;
        final dates = <String, int>{};
        for (final dateEntry in rawDates.entries) {
          final iso = dateEntry.key;
          final value = dateEntry.value;
          if (iso is! String || value is! num) continue;
          dates[iso] = value.toInt();
        }
        if (dates.isNotEmpty) byPlan[planId] = dates;
      }
    }
    return DayOverrides(byPlan: byPlan);
  }
}
