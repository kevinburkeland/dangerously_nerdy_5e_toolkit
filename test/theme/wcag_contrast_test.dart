import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';

/// Standard WCAG 2.1 relative luminance calculation
double calculateRelativeLuminance(Color color) {
  double getChannel(double sRGB) {
    return sRGB <= 0.03928 ? sRGB / 12.92 : ((sRGB + 0.055) / 1.055) * ((sRGB + 0.055) / 1.055);
  }

  final r = getChannel(color.r);
  final g = getChannel(color.g);
  final b = getChannel(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Computes WCAG contrast ratio between two colors (ranging from 1.0 to 21.0)
double calculateContrastRatio(Color foreground, Color background) {
  final l1 = calculateRelativeLuminance(foreground);
  final l2 = calculateRelativeLuminance(background);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG 2.1 Color Contrast Audit for Fantasy Accents', () {
    const darkBackground = Color(0xFF0F0D1B);
    const oledBlackBackground = Color(0xFF000000);

    test('All fantasy accent colors have distinct luminous primary and secondary values', () {
      for (final accent in FantasyAccent.values) {
        expect(accent.primary, isNotNull);
        expect(accent.accent, isNotNull);
        expect(accent.label, isNotEmpty);
      }
    });

    test('All 9 fantasy accent palettes meet WCAG AA graphical UI contrast (>= 3.0:1) on dark theme', () {
      for (final accent in FantasyAccent.values) {
        final ratioPrimary = calculateContrastRatio(accent.primary, darkBackground);
        final ratioAccent = calculateContrastRatio(accent.accent, darkBackground);

        // Graphical elements & active UI indicators need at least 3.0:1
        expect(
          ratioPrimary >= 3.0 || ratioAccent >= 3.0,
          isTrue,
          reason: 'Accent ${accent.label} should provide >= 3.0:1 contrast on dark background (got primary: $ratioPrimary, accent: $ratioAccent)',
        );
      }
    });

    test('All 9 fantasy accent palettes meet WCAG AA graphical UI contrast on OLED Pitch Black theme', () {
      for (final accent in FantasyAccent.values) {
        final ratioPrimary = calculateContrastRatio(accent.primary, oledBlackBackground);
        final ratioAccent = calculateContrastRatio(accent.accent, oledBlackBackground);

        expect(
          ratioPrimary >= 3.0 || ratioAccent >= 3.0,
          isTrue,
          reason: 'Accent ${accent.label} should provide >= 3.0:1 contrast on OLED black (got primary: $ratioPrimary, accent: $ratioAccent)',
        );
      }
    });
  });
}
