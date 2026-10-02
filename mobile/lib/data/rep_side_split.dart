/// Pure helpers for a unilateral (logged-per-side) [Exercise] -- see the doc
/// comment on `Exercise.unilateral`. The user always logs the TOTAL reps
/// across both sides; these just derive the per-side number for display and
/// pick the right step size so a total can never drift to a number that
/// can't split evenly across both sides.
library;

/// The per-side split of a logged TOTAL rep count, shown exactly as it
/// falls -- e.g. 7 -> 3.5 -- rather than rounded away. A manually-typed
/// total is intentionally never forced to be even, so an odd split is a
/// real, worth-seeing number here, not a bug.
double repsPerSide(int totalReps) => totalReps / 2;

/// The rep stepper/suggestion increment for an exercise: 2 at a time for a
/// unilateral exercise (so its total always stays even), 1 otherwise.
int repStepFor({required bool unilateral}) => unilateral ? 2 : 1;

/// Snaps a possibly-odd rep count up to the nearest even number -- e.g. a
/// total logged before the exercise was marked unilateral, or a target
/// range's odd low bound. This is what actually makes "never lands on an
/// odd total" true: blindly adding [repStepFor]'s +2 to an already-odd
/// number would keep it odd forever (15 + 2 = 17).
int nextEvenReps(int reps) => reps.isOdd ? reps + 1 : reps;
