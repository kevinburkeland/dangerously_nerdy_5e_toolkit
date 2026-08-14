import 'package:flutter/material.dart';

@immutable
class TabletopColors extends ThemeExtension<TabletopColors> {
  final Color critGold;
  final Color fumbleRed;
  final Color hitGreen;
  final Color tempHpCyan;
  final Color cardBorder;
  final Color surfaceSubtle;
  final Color statPillBackground;

  const TabletopColors({
    required this.critGold,
    required this.fumbleRed,
    required this.hitGreen,
    required this.tempHpCyan,
    required this.cardBorder,
    required this.surfaceSubtle,
    required this.statPillBackground,
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
  }) {
    return TabletopColors(
      critGold: critGold ?? this.critGold,
      fumbleRed: fumbleRed ?? this.fumbleRed,
      hitGreen: hitGreen ?? this.hitGreen,
      tempHpCyan: tempHpCyan ?? this.tempHpCyan,
      cardBorder: cardBorder ?? this.cardBorder,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      statPillBackground: statPillBackground ?? this.statPillBackground,
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
    );
  }

  static const dark = TabletopColors(
    critGold: Color(0xFFFFD54F),
    fumbleRed: Color(0xFFFF5252),
    hitGreen: Color(0xFF69F0AE),
    tempHpCyan: Color(0xFF18FFFF),
    cardBorder: Color(0x2EFFFFFF),
    surfaceSubtle: Color(0xFF231F34),
    statPillBackground: Color(0x40000000),
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F0D17),
      primaryColor: Colors.amber,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFC107), // Amber 500
        onPrimary: Colors.black,
        secondary: Color(0xFF00E5FF), // Cyan Accent
        onSecondary: Colors.black,
        surface: Color(0xFF181524),
        onSurface: Color(0xFFF0EFF4), // High contrast off-white
        surfaceContainerHighest: Color(0xFF2B263E),
        error: Color(0xFFFF5252),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1B2E),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1A2E),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x2EFFFFFF), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFF0EFF4)),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE2E0EB)),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFD4D1E0), height: 1.4),
        bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFFAAA6BD), height: 1.3),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
      extensions: const [TabletopColors.dark],
    );
  }
}
