import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Spell Pinning Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('pins and unpins spells correctly', () async {
      final provider = SettingsProvider();

      expect(provider.isSpellPinned('spell_fireball'), isFalse);
      expect(provider.settings.pinnedSpellIds, isEmpty);

      provider.pinSpell('spell_fireball');
      expect(provider.isSpellPinned('spell_fireball'), isTrue);
      expect(provider.settings.pinnedSpellIds.contains('spell_fireball'), isTrue);

      provider.togglePinSpell('spell_cure_wounds');
      expect(provider.isSpellPinned('spell_cure_wounds'), isTrue);
      expect(provider.settings.pinnedSpellIds.length, 2);

      provider.unpinSpell('spell_fireball');
      expect(provider.isSpellPinned('spell_fireball'), isFalse);
      expect(provider.settings.pinnedSpellIds.length, 1);

      provider.clearPinnedSpells();
      expect(provider.settings.pinnedSpellIds, isEmpty);
    });

    test('restores pinned spells from shared preferences', () async {
      SharedPreferences.setMockInitialValues({
        'setting_pinned_spell_ids': ['spell_counterspell', 'spell_shield'],
      });

      final provider = SettingsProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.isSpellPinned('spell_counterspell'), isTrue);
      expect(provider.isSpellPinned('spell_shield'), isTrue);
      expect(provider.isSpellPinned('spell_fireball'), isFalse);
    });
  });
}
