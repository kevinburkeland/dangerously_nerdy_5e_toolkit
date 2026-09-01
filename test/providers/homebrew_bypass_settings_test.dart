import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';

void main() {
  group('Homebrew Bypass State Injection & SettingsProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AppSettings defaults bypassedHomebrewSlugs to empty set and supports copyWith / equals', () {
      const defaultSettings = AppSettings();
      expect(defaultSettings.bypassedHomebrewSlugs, isEmpty);

      final updated = defaultSettings.copyWith(
        bypassedHomebrewSlugs: {'custom-dragon-breath', 'fireball-homebrew'},
      );
      expect(updated.bypassedHomebrewSlugs, containsAll(['custom-dragon-breath', 'fireball-homebrew']));

      final matching = defaultSettings.copyWith(
        bypassedHomebrewSlugs: {'fireball-homebrew', 'custom-dragon-breath'},
      );
      expect(updated, equals(matching));
      expect(updated.hashCode, equals(matching.hashCode));
    });

    test('SettingsProvider toggles and queries homebrew bypass state correctly', () async {
      final provider = SettingsProvider(autoLoad: false);
      expect(provider.isHomebrewBypassed('eldritch-blast-mod'), isFalse);

      provider.toggleHomebrewBypass('eldritch-blast-mod');
      expect(provider.isHomebrewBypassed('eldritch-blast-mod'), isTrue);
      expect(provider.settings.bypassedHomebrewSlugs, contains('eldritch-blast-mod'));

      provider.toggleHomebrewBypass('eldritch-blast-mod');
      expect(provider.isHomebrewBypassed('eldritch-blast-mod'), isFalse);
      expect(provider.settings.bypassedHomebrewSlugs, isNot(contains('eldritch-blast-mod')));
    });

    test('hydrateFromPrefs reconstitutes bypassedHomebrewSlugs from storage', () async {
      SharedPreferences.setMockInitialValues({
        'setting_bypassed_homebrew_slugs': ['homebrew_shield_spell', 'custom_sword'],
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider.hydrateFromPrefs(prefs);

      expect(settings.bypassedHomebrewSlugs, containsAll(['homebrew_shield_spell', 'custom_sword']));
    });
  });
}
