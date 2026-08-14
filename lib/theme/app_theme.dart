import 'package:flutter/material.dart';
import '../models/app_settings.dart';

@immutable
class TabletopColors extends ThemeExtension<TabletopColors> {
  final Color critGold;
  final Color fumbleRed;
  final Color hitGreen;
  final Color tempHpCyan;
  final Color cardBorder;
  final Color surfaceSubtle;
  final Color statPillBackground;
  final Color glowAccent;

  const TabletopColors({
    required this.critGold,
    required this.fumbleRed,
    required this.hitGreen,
    required this.tempHpCyan,
    required this.cardBorder,
    required this.surfaceSubtle,
    required this.statPillBackground,
    required this.glowAccent,
  });

  @override
  TabletopColors copyWith({
    Color? critGold,
    Color? fumbleRed,
    Color? hitGreen,
    Color? tempHpCyan,
    Color? cardBorder,
    Color? surfaceSubtle,
    Color? statPillBackground,
    Color? glowAccent,
  }) {
    return TabletopColors(
      critGold: critGold ?? this.critGold,
      fumbleRed: fumbleRed ?? this.fumbleRed,
      hitGreen: hitGreen ?? this.hitGreen,
      tempHpCyan: tempHpCyan ?? this.tempHpCyan,
      cardBorder: cardBorder ?? this.cardBorder,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      statPillBackground: statPillBackground ?? this.statPillBackground,
      glowAccent: glowAccent ?? this.glowAccent,
    );
  }

  @override
  TabletopColors lerp(ThemeExtension<TabletopColors>? other, double t) {
    if (other is! TabletopColors) return this;
    return TabletopColors(
      critGold: Color.lerp(critGold, other.critGold, t)!,
      fumbleRed: Color.lerp(fumbleRed, other.fumbleRed, t)!,
      hitGreen: Color.lerp(hitGreen, other.hitGreen, t)!,
      tempHpCyan: Color.lerp(tempHpCyan, other.tempHpCyan, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      statPillBackground: Color.lerp(statPillBackground, other.statPillBackground, t)!,
      glowAccent: Color.lerp(glowAccent, other.glowAccent, t)!,
    );
  }

  static TabletopColors createDark(FantasyAccent accent, {bool oled = false}) {
    return TabletopColors(
      critGold: const Color(0xFFFFD54F),
      fumbleRed: const Color(0xFFFF5252),
      hitGreen: const Color(0xFF69F0AE),
      tempHpCyan: const Color(0xFF18FFFF),
      cardBorder: oled ? const Color(0x40FFFFFF) : const Color(0x2EFFFFFF),
      surfaceSubtle: oled ? const Color(0xFF121212) : const Color(0xFF231F34),
      statPillBackground: const Color(0x40000000),
      glowAccent: accent.accent,
    );
  }

  static TabletopColors createLight(FantasyAccent accent) {
    return TabletopColors(
      critGold: const Color(0xFFFFA000),
      fumbleRed: const Color(0xFFD32F2F),
      hitGreen: const Color(0xFF388E3C),
      tempHpCyan: const Color(0xFF0097A7),
      cardBorder: const Color(0x1F000000),
      surfaceSubtle: const Color(0xFFF1EFF6),
      statPillBackground: const Color(0x10000000),
      glowAccent: accent.primary,
    );
  }

  // Backwards compatibility default
  static const dark = TabletopColors(
    critGold: Color(0xFFFFD54F),
    fumbleRed: Color(0xFFFF5252),
    hitGreen: Color(0xFF69F0AE),
    tempHpCyan: Color(0xFF18FFFF),
    cardBorder: Color(0x2EFFFFFF),
    surfaceSubtle: Color(0xFF231F34),
    statPillBackground: Color(0x40000000),
    glowAccent: Color(0xFFFFD54F),
  );

  /// Convenience alias for container/card background — mirrors [surfaceSubtle].
  Color get cardBackground => surfaceSubtle;
}

class AppTheme {
  static ThemeData buildTheme({
    required Brightness brightness,
    required FantasyAccent accent,
    bool oledPitchBlack = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark
        ? (oledPitchBlack ? const Color(0xFF000000) : const Color(0xFF0F0D17))
        : const Color(0xFFF8F7FA);

    final surface = isDark
        ? (oledPitchBlack ? const Color(0xFF0D0D0D) : const Color(0xFF181524))
        : Colors.white;

    final cardBg = isDark
        ? (oledPitchBlack ? const Color(0xFF141414) : const Color(0xFF1E1A2E))
        : Colors.white;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: accent.primary,
            onPrimary: Colors.black,
            secondary: accent.accent,
            onSecondary: Colors.black,
            surface: surface,
            onSurface: const Color(0xFFF0EFF4),
            surfaceContainerHighest: oledPitchBlack ? const Color(0xFF1C1C1C) : const Color(0xFF2B263E),
            error: const Color(0xFFFF5252),
          )
        : ColorScheme.light(
            primary: accent.primary,
            onPrimary: Colors.white,
            secondary: accent.accent,
            onSecondary: Colors.white,
            surface: surface,
            onSurface: const Color(0xFF1E1B2E),
            surfaceContainerHighest: const Color(0xFFE6E3EE),
            error: const Color(0xFFD32F2F),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? (oledPitchBlack ? Colors.black : const Color(0xFF1E1B2E)) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E1B2E),
        elevation: isDark ? 4 : 1,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: oledPitchBlack ? 0 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? (oledPitchBlack ? const Color(0x38FFFFFF) : const Color(0x2EFFFFFF))
                : const Color(0x1F000000),
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? (oledPitchBlack ? const Color(0xFF121212) : const Color(0xFF1E1B2E)) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: isDark ? Colors.white : const Color(0xFF1A1A24),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF1A1A24),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF0EFF4) : const Color(0xFF262338),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE2E0EB) : const Color(0xFF3B3750),
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: isDark ? const Color(0xFFD4D1E0) : const Color(0xFF4A4660),
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: isDark ? const Color(0xFFAAA6BD) : const Color(0xFF6E6A85),
          height: 1.3,
        ),
        labelLarge: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      extensions: [
        isDark ? TabletopColors.createDark(accent, oled: oledPitchBlack) : TabletopColors.createLight(accent),
      ],
    );
  }

  /// Default dark theme for backward compatibility
  static ThemeData get darkTheme => buildTheme(
        brightness: Brightness.dark,
        accent: FantasyAccent.paladinGold,
      );
}
