import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';

void main() {
  group('AppTheme Dynamic Palette & OLED Tests', () {
    test('buildTheme generates valid dark theme with TabletopColors extension', () {
      final theme = AppTheme.buildTheme(
        brightness: Brightness.dark,
        accent: FantasyAccent.paladinGold,
      );

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, FantasyAccent.paladinGold.primary);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0F0D17));

      final extension = theme.extension<TabletopColors>();
      expect(extension, isNotNull);
      expect(extension?.critGold, const Color(0xFFFFD54F));
      expect(extension?.fumbleRed, const Color(0xFFFF5252));
    });

    test('buildTheme generates OLED pitch-black background when requested', () {
      final theme = AppTheme.buildTheme(
        brightness: Brightness.dark,
        accent: FantasyAccent.eldritchPurple,
        oledPitchBlack: true,
      );

      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.colorScheme.primary, FantasyAccent.eldritchPurple.primary);
    });

    test('buildTheme generates valid light theme for all accents', () {
      for (final accent in FantasyAccent.values) {
        final theme = AppTheme.buildTheme(
          brightness: Brightness.light,
          accent: accent,
        );

        expect(theme.brightness, Brightness.light);
        expect(theme.colorScheme.primary, accent.getPrimary(false));
        expect(theme.extension<TabletopColors>(), isNotNull);
      }
    });

    test('buildTheme generates valid dark and OLED themes for all accents', () {
      for (final accent in FantasyAccent.values) {
        final darkTheme = AppTheme.buildTheme(
          brightness: Brightness.dark,
          accent: accent,
          oledPitchBlack: false,
        );
        expect(darkTheme.brightness, Brightness.dark);
        expect(darkTheme.colorScheme.primary, accent.primary);
        expect(darkTheme.extension<TabletopColors>()?.glowAccent, accent.accent);

        final oledTheme = AppTheme.buildTheme(
          brightness: Brightness.dark,
          accent: accent,
          oledPitchBlack: true,
        );
        expect(oledTheme.scaffoldBackgroundColor, const Color(0xFF000000));
        expect(oledTheme.colorScheme.primary, accent.primary);
      }
    });

    test('TabletopColors lerp operates cleanly', () {
      final dark = TabletopColors.createDark(FantasyAccent.paladinGold);
      final light = TabletopColors.createLight(FantasyAccent.paladinGold);

      final lerped = dark.lerp(light, 0.5);
      expect(lerped.critGold, isNotNull);
      expect(lerped.fumbleRed, isNotNull);
    });
  });
}
