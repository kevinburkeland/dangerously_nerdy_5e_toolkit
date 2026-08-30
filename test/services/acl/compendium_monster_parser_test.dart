import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_monster_parser.dart';

void main() {
  group('Community Compendium & Homebrew Monster Parser Tests', () {
    late CompendiumMonsterParser parser;

    setUp(() {
      parser = CompendiumMonsterParser();
    });

    test('parses complex monster with abbreviated size, alignment, action economy, and spellcasting', () {
      final raw = {
        'name': 'Void Dragon Wyrmling',
        'source': 'HOMEBREW',
        'size': ['M'],
        'type': {'type': 'dragon', 'tags': ['planar', 'void']},
        'alignment': ['C', 'E'],
        'ac': [
          {'ac': 17, 'from': ['natural armor']}
        ],
        'hp': {'average': 52, 'formula': '7d8 + 21'},
        'speed': {'walk': 30, 'fly': 60, 'canHover': true},
        'str': 16,
        'dex': 12,
        'con': 17,
        'int': 14,
        'wis': 11,
        'cha': 15,
        'save': {'dex': '+3', 'con': '+5', 'wis': '+2', 'cha': '+4'},
        'skill': {'perception': '+4', 'stealth': '+3'},
        'senses': ['darkvision 120 ft.', 'blindsight 30 ft.'],
        'passive': 14,
        'languages': ['Draconic', 'Void Speech'],
        'cr': '3',
        'immune': ['cold', 'radiant'],
        'conditionImmune': ['frightened', 'paralyzed'],
        'trait': [
          {
            'name': 'Void Aura',
            'entries': ['Bright light within 20 feet of the dragon becomes dim light.']
          }
        ],
        'action': [
          {
            'name': 'Bite',
            'entries': [
              '{@atk mw} {@hit 5} to hit, reach 5 ft., one target. *Hit:* 8 ({@damage 1d10 + 3|piercing}) damage plus 4 ({@damage 1d8|cold}) cold damage.'
            ]
          },
          {
            'name': 'Void Breath (Recharge 5-6)',
            'entries': [
              'The dragon exhales cosmic energy in a 15-foot cone. Each creature in that area must make a {@dc 13} Dexterity saving throw, taking 22 ({@damage 5d8|radiant}) radiant damage on a failed save, or half as much on a successful one.'
            ]
          }
        ],
        'bonus': [
          {
            'name': 'Shadow Slip',
            'entries': ['The dragon teleports up to 30 feet to an unoccupied space in dim light or darkness.']
          }
        ],
        'reaction': [
          {
            'name': 'Gravity Bend',
            'entries': ['When targeted by a ranged attack, the dragon imposes disadvantage on the attack roll.']
          }
        ],
        'spellcasting': [
          {
            'name': 'Innate Spellcasting',
            'headerEntries': ['The dragon\'s innate spellcasting ability is Charisma (spell save {@dc 12}).'],
            'daily': {
              '1': ['{@spell darkness}', '{@spell misty step}']
            }
          }
        ],
        'environment': ['Underdark', 'Space'],
      };

      final monster = parser.parseMonster(raw);

      expect(monster.name, equals('Void Dragon Wyrmling'));
      expect(monster.id.slug, equals('void-dragon-wyrmling'));
      expect(monster.size, equals('Medium'));
      expect(monster.monsterType, equals('dragon (planar, void)'));
      expect(monster.alignment, equals('Chaotic Evil'));
      expect(monster.armorClass, equals(17));
      expect(monster.hitPoints, equals(52));
      expect(monster.hitDieFormula, equals('7d8 + 21'));
      expect(monster.challengeRating, equals('3'));

      expect(monster.actionsMarkdown, contains('**Speed:** walk 30ft., fly 60ft., (hover)'));
      expect(monster.actionsMarkdown, contains('| STR | DEX | CON | INT | WIS | CHA |'));
      expect(monster.actionsMarkdown, contains('**Saving Throws:** DEX +3, CON +5, WIS +2, CHA +4'));
      expect(monster.actionsMarkdown, contains('**Damage Immunities:** cold, radiant'));
      expect(monster.actionsMarkdown, contains('### Traits'));
      expect(monster.actionsMarkdown, contains('**Void Aura**'));
      expect(monster.actionsMarkdown, contains('### Actions'));
      expect(monster.actionsMarkdown, contains('**Bite**'));
      expect(monster.actionsMarkdown, contains('### Bonus Actions'));
      expect(monster.actionsMarkdown, contains('**Shadow Slip**'));
      expect(monster.actionsMarkdown, contains('### Reactions'));
      expect(monster.actionsMarkdown, contains('**Gravity Bend**'));
      expect(monster.actionsMarkdown, contains('### Spellcasting'));

      // Attack Math extracted
      expect(monster.attackMath.any((m) => m.diceFormula.contains('1d10')), isTrue);
      expect(monster.attackMath.any((m) => m.damageType == DamageType.radiant), isTrue);

      // Innate spells extracted
      expect(monster.innateSpells.length, equals(2));
      expect(monster.innateSpells.first.slug, equals('darkness'));

      // 0% data loss in customProperties
      expect(monster.customProperties['environment'], equals(['Underdark', 'Space']));
      expect(monster.customProperties['passive'], equals(14));
      expect(monster.customProperties['str'], equals(16));
    });
  });
}
