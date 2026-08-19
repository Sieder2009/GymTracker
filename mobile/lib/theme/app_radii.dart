/// Corner-radius scale for the whole app — every rounded corner anywhere in
/// the UI must come from one of these tokens, never a magic number, so a
/// single change here reshapes the entire app consistently.
class AppRadii {
  static const double pill = 999; // fully rounded: buttons, chips, badges
  static const double lg = 22; // large cards, sheets
  static const double md = 16; // standard cards, inputs
  static const double sm = 12; // small containers (day pills, tiles)
  static const double xs = 8; // tiny elements (mini badges, thin bars)
}
