import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_item_parser.dart';

void main() {
  group('Community Compendium & Homebrew Equipment/Item Parser Tests', () {
    late CompendiumItemParser parser;

    setUp(() {
      parser = CompendiumItemParser();
    });

    test('parses versatile magic weapon with attunement requirement string and properties', () {
      final raw = {
        'name': 'Sunblade of the Dawn',
        'source': 'HOMEBREW',
        'type': 'M', // Melee weapon
        'rarity': 'VR', // Very Rare
        'reqAttune': 'by a creature of good alignment',
        'weight': 3,
        'value': 50000,
        'weaponCategory': 'martial',
        'property': ['F', 'V'], // Finesse, Versatile
        'dmg1': '1d8',
        'dmgType': 'radiant',
        'dmg2': '1d10',
        'bonusWeapon': '+2',
        'charges': 10,
        'recharge': 'dawn',
        'rechargeAmount': '1d6 + 4',
        'entries': [
          'This weapon emits bright sunlight in a 15-foot radius.',
          'You gain a +2 bonus to attack and damage rolls made with this magic weapon.'
        ],
        'curse': false,
      };

      final item = parser.parseItem(raw);

      expect(item.name, equals('Sunblade of the Dawn'));
      expect(item.id.slug, equals('sunblade-of-the-dawn'));
      expect(item.itemType, equals('Melee Weapon'));
      expect(item.rarity, equals('Very Rare'));
      expect(item.requiresAttunement, isTrue);
      expect(item.descriptionMarkdown, contains('emits bright sunlight'));

      // Mechanics preserved in customProperties
      expect(item.customProperties['weight'], equals(3));
      expect(item.customProperties['value'], equals(50000));
      expect(item.customProperties['weaponCategory'], equals('martial'));
      expect(item.customProperties['property'], equals(['F', 'V']));
      expect(item.customProperties['dmg1'], equals('1d8'));
      expect(item.customProperties['dmgType'], equals('radiant'));
      expect(item.customProperties['dmg2'], equals('1d10'));
      expect(item.customProperties['bonusWeapon'], equals('+2'));
      expect(item.customProperties['charges'], equals(10));
      expect(item.customProperties['recharge'], equals('dawn'));
      expect(item.customProperties['curse'], isFalse);
    });

    test('parses armor item with dex cap and strength requirements', () {
      final raw = {
        'name': 'Adamantine Plate of Resettlement',
        'source': 'HOMEBREW',
        'type': 'HA',
        'rarity': 'Rare',
        'reqAttune': false,
        'ac': 18,
        'armor': true,
        'strength': 15,
        'stealth': true, // Disadvantage
        'entries': ['While you wear this armor, any critical hit against you becomes a normal hit.']
      };

      final item = parser.parseItem(raw);

      expect(item.name, equals('Adamantine Plate of Resettlement'));
      expect(item.itemType, equals('Heavy Armor'));
      expect(item.rarity, equals('Rare'));
      expect(item.requiresAttunement, isFalse);
      expect(item.customProperties['ac'], equals(18));
      expect(item.customProperties['strength'], equals(15));
      expect(item.customProperties['stealth'], isTrue);
    });
  });
}
