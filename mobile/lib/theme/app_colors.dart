import 'package:flutter/material.dart';

/// Light/dark hex pairs for the app's design tokens. Registered as a
/// [ThemeExtension] so screens can read
/// `Theme.of(context).extension<AppColors>()!` for tokens that don't map
/// onto a standard Material [ColorScheme] slot (teal/purple/yellow/green).
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
  final Color secondary;
  final Color teal;
  final Color purple;
  final Color yellow;
  final Color green;

  static const AppColors light = AppColors(
    bg: Color(0xFFF5F5F7),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFEEEEF1),
    line: Color(0xFFE3E3E8),
    txt: Color(0xFF16171B),
    mut: Color(0xFF84848C),
    accent: Color(0xFF2F6FEB),
    accentSoft: Color(0x1A2F6FEB), // rgba(47,111,235,.10)
    secondary: Color(0xFF0EA884),
    teal: Color(0xFF0EA884),
    purple: Color(0xFF6D5CE8),
    yellow: Color(0xFFC98A10),
    green: Color(0xFF1FA76A),
  );

  static const AppColors dark = AppColors(
    bg: Color(0xFF101114),
    card: Color(0xFF1A1B1F),
    card2: Color(0xFF232428),
    line: Color(0xFF2D2E34),
    txt: Color(0xFFF2F2F4),
    mut: Color(0xFF8D8D96),
    accent: Color(0xFF5588FF),
    accentSoft: Color(0x295588FF), // rgba(85,136,255,.16)
    secondary: Color(0xFF1FD6A8),
    teal: Color(0xFF1FD6A8),
    purple: Color(0xFF9585FF),
    yellow: Color(0xFFE0A83A),
    green: Color(0xFF35C98A),
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
      secondary: Color.lerp(secondary, other.secondary, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      green: Color.lerp(green, other.green, t)!,
    );
  }
}
