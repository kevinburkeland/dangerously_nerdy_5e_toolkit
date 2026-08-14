import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppSettings Tests', () {
    test('default settings has expected values', () {
      const settings = AppSettings();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.fantasyAccent, FantasyAccent.paladinGold);
      expect(settings.oledPitchBlack, isFalse);
      expect(settings.hapticLevel, HapticFeedbackLevel.light);
      expect(settings.enableCritFumbleFx, isTrue);
      expect(settings.enableSpellParticles, isTrue);
      expect(settings.enable3dDiceOverlays, isTrue);
      expect(settings.performanceMode, isFalse);
      expect(settings.areParticlesAllowed, isTrue);
      expect(settings.areCritFxAllowed, isTrue);
      expect(settings.rulesEdition, DmRulesEdition.v2024);
    });

    test('performanceMode disables particle and crit effects getters', () {
      const settings = AppSettings(performanceMode: true);
      expect(settings.areParticlesAllowed, isFalse);
      expect(settings.areCritFxAllowed, isFalse);
    });
  });

  group('SettingsProvider Tests', () {
    test('initializes and updates settings correctly', () async {
      final provider = SettingsProvider();
      expect(provider.settings.themeMode, ThemeMode.dark);
      expect(provider.settings.rulesEdition, DmRulesEdition.v2024);

      provider.setThemeMode(ThemeMode.light);
      expect(provider.settings.themeMode, ThemeMode.light);

      provider.setFantasyAccent(FantasyAccent.eldritchPurple);
      expect(provider.settings.fantasyAccent, FantasyAccent.eldritchPurple);

      provider.setOledMode(true);
      expect(provider.settings.oledPitchBlack, isTrue);

      provider.setHapticLevel(HapticFeedbackLevel.heavy);
      expect(provider.settings.hapticLevel, HapticFeedbackLevel.heavy);

      provider.setPerformanceMode(true);
      expect(provider.settings.performanceMode, isTrue);
      expect(provider.settings.areParticlesAllowed, isFalse);

      provider.setRulesEdition(DmRulesEdition.v2014);
      expect(provider.settings.rulesEdition, DmRulesEdition.v2014);
    });

    test('hydrates preferences from stored values', () async {
      SharedPreferences.setMockInitialValues({
        'setting_theme_mode': ThemeMode.light.index,
        'setting_fantasy_accent': FantasyAccent.rangerEmerald.index,
        'setting_oled_pitch_black': true,
        'setting_haptic_level': HapticFeedbackLevel.off.index,
        'setting_crit_fumble_fx': false,
        'setting_spell_particles': false,
        'setting_3d_dice': false,
        'setting_performance_mode': true,
        'setting_rules_edition': DmRulesEdition.v2014.index,
      });

      final provider = SettingsProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.settings.themeMode, ThemeMode.light);
      expect(provider.settings.fantasyAccent, FantasyAccent.rangerEmerald);
      expect(provider.settings.oledPitchBlack, isTrue);
      expect(provider.settings.hapticLevel, HapticFeedbackLevel.off);
      expect(provider.settings.enableCritFumbleFx, isFalse);
      expect(provider.settings.performanceMode, isTrue);
      expect(provider.settings.rulesEdition, DmRulesEdition.v2014);
    });
  });
}
