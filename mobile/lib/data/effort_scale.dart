/// The two effort scales the guided workout's per-set chip row can collect
/// -- see `state/effort_scale_provider.dart` for the global preference that
/// picks between them, and `models/exercise_set.dart` for how a set's
/// logged value is tagged with whichever scale it was collected in.
enum EffortScale { rpe, rir }

/// How an [EffortScale] is written to/read from a single-kv-key storage
/// setting (see `state/effort_scale_provider.dart`) -- deliberately its own
/// tiny format rather than the enum's `.name`, so a future rename of the
/// enum values can't silently change what's already on disk.
extension EffortScaleJson on EffortScale {
  String get storageValue => this == EffortScale.rir ? 'rir' : 'rpe';
}

/// Defensive: a missing key (every install before this feature), a
/// corrupted value, or a future scale this build doesn't know about all
/// read back as RPE -- matching today's only behavior and never crashing
/// on an unrecognized value.
EffortScale effortScaleFromStorage(String? value) =>
    value == 'rir' ? EffortScale.rir : EffortScale.rpe;

/// The chip values the guided workout's effort row offers for a scale --
/// RPE keeps its exact existing 5-10 range (unchanged behavior); RIR gets
/// 0-5, where 0 means the set was taken to failure. Both scales offer six
/// values.
List<int> effortValuesFor(EffortScale scale) =>
    scale == EffortScale.rir ? const [0, 1, 2, 3, 4, 5] : const [5, 6, 7, 8, 9, 10];
