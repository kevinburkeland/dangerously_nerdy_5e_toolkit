import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_race_parser.dart';

void main() {
  group('Community Compendium & Homebrew Race/Subrace Parser Tests', () {
    late CompendiumRaceParser parser;

    setUp(() {
      parser = CompendiumRaceParser();
    });

    test('parses lineage with multi-attribute bonuses and subraces', () {
      final raw = {
        'name': 'Astral Elf',
        'source': 'HOMEBREW',
        'size': ['M'],
        'speed': {'walk': 30, 'fly': 15},
        'ability': [
          {'dex': 2, 'int': 1}
        ],
        'darkvision': 60,
        'skillProficiencies': ['Perception', 'Astral Lore'],
        'additionalSpells': [
          {
            'ability': 'int',
            'known': {
              '1': ['{@spell dancing lights}'],
              '3': ['{@spell misty step}']
            }
          }
        ],
        'trait': [
          {'name': 'Starlight Step', 'entries': ['As a bonus action, you can magically teleport up to 30 feet.']},
          {'name': 'Astral Fire', 'entries': ['You know one cantrip of your choice from the cleric or wizard spell list.']}
        ],
        'subraces': [
          {
            'name': 'Solar Astral Elf',
            'ability': [{'cha': 1}],
            'trait': [
              {'name': 'Solar Wrath', 'entries': ['Deal extra radiant damage on your first hit each turn.']}
            ]
          }
        ],
        'lineageNotes': 'Inhabitants of the Astral Plane'
      };

      final race = parser.parseRace(raw);

      expect(race.name, equals('Astral Elf'));
      expect(race.id.slug, equals('astral-elf'));
      expect(race.size, equals('Medium'));
      expect(race.speed, contains('30 ft.'));
      expect(race.traitsMarkdown, contains('Starlight Step'));
      expect(race.traitsMarkdown, contains('Astral Fire'));

      expect(race.subraces.length, equals(1));
      final sub = race.subraces.first;
      expect(sub.name, equals('Solar Astral Elf'));
      expect(sub.raceSlug, equals('astral-elf'));
      expect(sub.traitsMarkdown, contains('Solar Wrath'));

      // 0% data loss
      expect(race.customProperties['lineageNotes'], equals('Inhabitants of the Astral Plane'));
      expect(race.customProperties['darkvision'], equals(60));
      expect(race.customProperties['additionalSpells'], isNotNull);
    });

    test('parses flexible ability score increases (e.g. choose 2 +1)', () {
      final raw = {
        'name': 'Custom Lineage',
        'source': 'TCE',
        'size': 'M',
        'ability': [
          {
            'choose': {'from': ['str', 'dex', 'con', 'int', 'wis', 'cha'], 'count': 1, 'amount': 2}
          }
        ],
        'trait': [
          {'name': 'Variable Trait', 'entries': ['You gain one feat of your choice for which you qualify.']}
        ]
      };

      final race = parser.parseRace(raw);

      expect(race.flexibleAbilityChoiceCount, equals(1));
      expect(race.flexibleAbilityBonusValue, equals(2));
    });
  });
}
