import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_adapters.dart';

void main() {
  group('CommunityCompendiumAdapters', () {
    late CommunityCompendiumAdapters adapters;

    setUp(() {
      adapters = CommunityCompendiumAdapters();
    });

    test('parses 2014 and 2024 Spells with distinct rulesets', () {
      final json2014 = {
        'name': 'Fireball',
        'source': 'PHB',
        'level': 3,
        'school': 'V',
        'time': [
          {'number': 1, 'unit': 'action'}
        ],
        'range': {
          'type': 'point',
          'distance': {'type': 'feet', 'amount': 150}
        },
        'components': {
          'v': true,
          's': true,
          'm': 'a tiny ball of bat guano and sulfur'
        },
        'duration': [
          {'type': 'instant'}
        ],
        'entries': [
          'A bright streak flashes from your pointing finger to a point you choose within range and then blossoms with a low roar into an explosion of flame. Each creature in a 20-foot-radius sphere centered on that point must make a Dexterity saving throw. A target takes {@damage 8d6|fire} damage on a failed save, or half as much damage on a successful one.'
        ],
      };

      final json2024 = {
        'name': 'Fireball',
        'source': 'XPHB',
        'level': 3,
        'school': 'V',
        'time': [
          {'number': 1, 'unit': 'action'}
        ],
        'range': {
          'type': 'point',
          'distance': {'type': 'feet', 'amount': 150}
        },
        'components': {'v': true, 's': true, 'm': 'bat guano and sulfur'},
        'duration': [
          {'type': 'instant'}
        ],
        'entries': [
          'A bright streak flashes from you to a point within range and blossoms into an explosion. Creatures take {@damage 8d6|fire} damage.'
        ],
      };

      final spell2014 = adapters.parseSpell(json2014);
      final spell2024 = adapters.parseSpell(json2024);

      expect(spell2014.id.slug, equals('fireball'));
      expect(spell2014.id.ruleset, equals(RulesetVersion.v2014));
      expect(spell2024.id.slug, equals('fireball'));
      expect(spell2024.id.ruleset, equals(RulesetVersion.v2024));
      expect(spell2014.id, isNot(equals(spell2024.id)));
      expect(spell2014.level, equals(3));
      expect(spell2014.school, equals('Evocation'));
      expect(spell2014.components.v, isTrue);
      expect(spell2014.components.m, isTrue);
      expect(spell2014.damageMath.first.damageType, equals(DamageType.fire));
    });

    test('parses Monster with attacks and hit points', () {
      final jsonMonster = {
        'name': 'Goblin',
        'source': 'MM',
        'size': ['S'],
        'type': 'humanoid (goblinoid)',
        'alignment': ['N', 'E'],
        'ac': [15],
        'hp': {'average': 7, 'formula': '2d6'},
        'cr': '1/4',
        'action': [
          {
            'name': 'Scimitar',
            'entries': [
              'Melee Weapon Attack: {@hit 4} to hit, reach 5 ft., one target. Hit: {@damage 1d6+2|slashing} damage.'
            ]
          }
        ]
      };

      final monster = adapters.parseMonster(jsonMonster);

      expect(monster.id.slug, equals('goblin'));
      expect(monster.id.ruleset, equals(RulesetVersion.v2014));
      expect(monster.size, equals('Small'));
      expect(monster.armorClass, equals(15));
      expect(monster.hitPoints, equals(7));
      expect(monster.challengeRating, equals('1/4'));
      expect(monster.attackMath.length, equals(1));
      expect(monster.attackMath.first.damageType, equals(DamageType.slashing));
    });

    test('parses Equipment Item with attunement and rarity', () {
      final jsonItem = {
        'name': 'Flame Tongue Longsword',
        'source': 'DMG',
        'type': 'M',
        'rarity': 'Rare',
        'reqAttune': true,
        'entries': [
          'You can use a bonus action to speak this magic sword command word, causing flames to erupt from the blade. These flames shed bright light in a 40-foot radius. While the sword is ablaze, it deals an extra {@damage 2d6|fire} damage to any target it hits.'
        ]
      };

      final item = adapters.parseItem(jsonItem);

      expect(item.id.slug, equals('flame-tongue-longsword'));
      expect(item.id.ruleset, equals(RulesetVersion.v2014));
      expect(item.rarity, equals('Rare'));
      expect(item.requiresAttunement, isTrue);
      expect(item.itemType, equals('Weapon'));
    });

    test('parses Class and Subclass', () {
      final jsonClass = {
        'name': 'Wizard',
        'source': 'XPHB',
        'hd': {'number': 1, 'faces': 6},
        'classFeatures': ['Spellcasting', 'Arcane Recovery'],
      };

      final jsonSubclass = {
        'name': 'Evoker',
        'className': 'Wizard',
        'source': 'XPHB',
        'subclassFeatures': ['Sculpt Spells', 'Potent Cantrip'],
      };

      final charClass = adapters.parseClass(jsonClass);
      final subclass = adapters.parseSubclass(jsonSubclass);

      expect(charClass.id.slug, equals('wizard'));
      expect(charClass.id.ruleset, equals(RulesetVersion.v2024));
      expect(charClass.hitDie, equals('d6'));

      expect(subclass.id.slug, equals('wizard-evoker'));
      expect(subclass.classSlug, equals('wizard'));
      expect(subclass.id.ruleset, equals(RulesetVersion.v2024));
    });
  });
}
