import 'package:flutter/material.dart';

/// Light/dark hex pairs for the app's design tokens. Registered as a
/// [ThemeExtension] so screens can read
/// `Theme.of(context).extension<AppColors>()!` for tokens that don't map
/// onto a standard Material [ColorScheme] slot (teal/purple/yellow/green).
///
/// Palette language: deep bottle-green/near-black surfaces with a warm
/// metallic-gold accent and ivory text — a boutique/horology look rather
/// than a stock Material blue app.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.card,
    required this.card2,
    required this.line,
    required this.txt,
    required this.mut,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.secondary,
    required this.teal,
    required this.purple,
    required this.yellow,
    required this.green,
  });

  final Color bg;
  final Color card;
  final Color card2;
  final Color line;
  final Color txt;
  final Color mut;
  final Color accent;
  final Color accentSoft;
  // Text/icon color for content painted on top of a solid [accent] fill.
  // Gold reads too light for white-on-accent contrast, so this is its own
  // token instead of assuming Colors.white like the old blue accent did.
  final Color onAccent;
  final Color secondary;
  final Color teal;
  final Color purple;
  final Color yellow;
  final Color green;

  static const AppColors light = AppColors(
    bg: Color(0xFFF6F1E4),
    card: Color(0xFFFFFCF5),
    card2: Color(0xFFEFE7D2),
    line: Color(0xFFE1D6B8),
    txt: Color(0xFF17150C),
    mut: Color(0xFF86795C),
    accent: Color(0xFFA9821E),
    accentSoft: Color(0x22A9821E), // rgba(169,130,30,.13)
    onAccent: Color(0xFFFFFBF0),
    secondary: Color(0xFF0B5C3F),
    teal: Color(0xFF0E7F63),
    purple: Color(0xFF6C4F9E),
    yellow: Color(0xFFB4811C),
    green: Color(0xFF1E7A4D),
  );

  static const AppColors dark = AppColors(
    bg: Color(0xFF0A0D0A),
    card: Color(0xFF141810),
    card2: Color(0xFF1D2317),
    line: Color(0xFF332E1D),
    txt: Color(0xFFF4EEDD),
    mut: Color(0xFFA79878),
    accent: Color(0xFFD4AF37),
    accentSoft: Color(0x29D4AF37), // rgba(212,175,55,.16)
    onAccent: Color(0xFF191307),
    secondary: Color(0xFF167A55),
    teal: Color(0xFF1C9C7C),
    purple: Color(0xFF9B7FC7),
    yellow: Color(0xFFE3B34A),
    green: Color(0xFF2FA872),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? card,
    Color? card2,
    Color? line,
    Color? txt,
    Color? mut,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? secondary,
    Color? teal,
    Color? purple,
    Color? yellow,
    Color? green,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      card2: card2 ?? this.card2,
      line: line ?? this.line,
      txt: txt ?? this.txt,
      mut: mut ?? this.mut,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      secondary: secondary ?? this.secondary,
      teal: teal ?? this.teal,
      purple: purple ?? this.purple,
      yellow: yellow ?? this.yellow,
      green: green ?? this.green,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      card2: Color.lerp(card2, other.card2, t)!,
      line: Color.lerp(line, other.line, t)!,
      txt: Color.lerp(txt, other.txt, t)!,
      mut: Color.lerp(mut, other.mut, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      green: Color.lerp(green, other.green, t)!,
    );
  }
}
