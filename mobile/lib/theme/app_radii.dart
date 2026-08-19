/// Corner-radius scale for the whole app — every rounded corner anywhere in
/// the UI must come from one of these tokens, never a magic number, so a
/// single change here reshapes the entire app consistently.
///
/// Tuned tighter than a generic consumer-app scale on purpose: crisper,
/// more structured edges read as boutique/engineered rather than bubbly.
class AppRadii {
  static const double pill = 999; // fully rounded: buttons, chips, badges
  static const double lg = 16; // large cards, sheets
  static const double md = 12; // standard cards, inputs
  static const double sm = 10; // small containers (day pills, tiles)
  static const double xs = 6; // tiny elements (mini badges, thin bars)
}
