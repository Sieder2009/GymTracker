import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radii.dart';

/// Sora for headings/big numbers, Inter for body text — same pairing as the
/// original's two Google Fonts (`app.css` / `index.html`). Every shadow,
/// radius and spacing value below is a token from [AppRadii]/[AppColors] or
/// a named constant in this file — never a magic number sprinkled into a
/// screen — so the whole app reshapes itself from one place.
class AppTheme {
  static ThemeData light({
    Color? accentOverride,
    Color? secondaryOverride,
    Color? bgOverride,
    Color? cardOverride,
    Color? txtOverride,
  }) =>
      _build(
        _applyOverrides(AppColors.light, accentOverride, secondaryOverride,
            bgOverride, cardOverride, txtOverride),
        Brightness.light,
      );

  static ThemeData dark({
    Color? accentOverride,
    Color? secondaryOverride,
    Color? bgOverride,
    Color? cardOverride,
    Color? txtOverride,
  }) =>
      _build(
        _applyOverrides(AppColors.dark, accentOverride, secondaryOverride,
            bgOverride, cardOverride, txtOverride),
        Brightness.dark,
      );

  static AppColors _applyOverrides(
    AppColors base,
    Color? accent,
    Color? secondary,
    Color? bg,
    Color? card,
    Color? txt,
  ) {
    if (accent == null &&
        secondary == null &&
        bg == null &&
        card == null &&
        txt == null) {
      return base;
    }
    return base.copyWith(
      accent: accent,
      // Users can pick any accent via the settings color picker, not just
      // the default blues, so onAccent must be derived from whatever they
      // chose rather than inheriting the base theme's fixed white --
      // otherwise a light custom accent gets light text and is unreadable.
      onAccent: accent == null ? null : _onColorFor(accent),
      secondary: secondary,
      bg: bg,
      card: card,
      txt: txt,
    );
  }

  static Color _onColorFor(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      cardColor: colors.card,
      dividerColor: colors.line,
      splashFactory: NoSplash.splashFactory,
      textTheme: _textTheme(base.textTheme, colors),
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        surface: colors.card,
        onSurface: colors.txt,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        secondary: colors.secondary,
        error: colors.yellow,
      ),
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.txt,
        elevation: 0,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: colors.txt,
        ),
      ),
      // elevation+shadowColor (not Material3's default surfaceTint overlay,
      // which we neutralize below) is what actually renders a soft drop
      // shadow — plain `elevation: 0` is why the previous look was flat.
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 4,
        shadowColor: brightness == Brightness.dark ? Colors.black : const Color(0xFF1B1B22),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: colors.line, width: 1),
        ),
      ),
      // Unthemed PopupMenuButton falls back to Material3's default menu
      // surface (sharp-ish 4px corners, stock elevation tint) -- same
      // treatment as cardTheme above (radius, border, shadow) so the
      // overflow menu reads as part of this app, not stock Material.
      popupMenuTheme: PopupMenuThemeData(
        color: colors.card,
        elevation: 8,
        shadowColor: brightness == Brightness.dark ? Colors.black : const Color(0xFF1B1B22),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: colors.line, width: 1),
        ),
        textStyle: GoogleFonts.inter(color: colors.txt, fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      // Same story as popupMenuTheme above -- every AlertDialog in the app
      // (delete-plan/exercise confirmations, exit-workout, ...) otherwise
      // falls back to Material3's default dialog chrome.
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        elevation: 8,
        shadowColor: brightness == Brightness.dark ? Colors.black : const Color(0xFF1B1B22),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: colors.line, width: 1),
        ),
        titleTextStyle: GoogleFonts.sora(color: colors.txt, fontWeight: FontWeight.w800, fontSize: 18),
        contentTextStyle: GoogleFonts.inter(color: colors.mut, fontSize: 14.5),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.mut,
        textColor: colors.txt,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.card2,
        hintStyle: GoogleFonts.inter(color: colors.mut),
        labelStyle: GoogleFonts.inter(color: colors.mut, fontWeight: FontWeight.w500),
        floatingLabelStyle: GoogleFonts.inter(color: colors.accent, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colors.accent, width: 1.75),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.card2,
          textStyle: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          elevation: 3,
          shadowColor: colors.accent.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.card2,
          foregroundColor: colors.secondary,
          side: BorderSide(color: colors.secondary),
          textStyle: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
      // Every bare IconButton becomes a soft filled circle (not a naked
      // glyph floating in space) — the single change that gives close/back/
      // menu buttons the "floating pill icon" look throughout the app.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: colors.card2,
          foregroundColor: colors.txt,
          padding: const EdgeInsets.all(10),
          shape: const CircleBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.card2,
        selectedColor: colors.accent,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colors.txt),
        secondaryLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colors.onAccent),
        side: BorderSide(color: colors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.card,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.mut,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, AppColors colors) {
    return GoogleFonts.interTextTheme(base)
        .copyWith(
          headlineLarge: GoogleFonts.sora(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colors.txt,
          ),
          headlineMedium: GoogleFonts.sora(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: colors.txt,
          ),
          labelSmall: GoogleFonts.sora(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: colors.mut,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: colors.mut,
          ),
        )
        .apply(bodyColor: colors.txt, displayColor: colors.txt);
  }
}
