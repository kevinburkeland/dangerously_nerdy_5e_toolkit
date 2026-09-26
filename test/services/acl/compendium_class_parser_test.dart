import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';

void main() {
  group('Community Compendium & Homebrew Class/Subclass Parser Tests', () {
    late CompendiumClassParser parser;

    setUp(() {
      parser = CompendiumClassParser();
    });

    test(
        'parses full class progression with nested subclasses and feature tables',
        () {
      final raw = {
        'name': 'Warmage',
        'source': 'HOMEBREW',
        'hd': {'number': 1, 'faces': 8},
        'proficiency': ['con', 'int'],
        'primaryAbility': 'Intelligence',
        'spellcastingAbility': 'Intelligence',
        'startingProficiencies': {
          'armor': ['light', 'medium', 'shields'],
          'weapons': ['simple', 'martial']
        },
        'classTableGroups': [
          {
            'colLabels': [
              'Level',
              'Proficiency Bonus',
              'Cantrips Known',
              'Spell Slots'
            ],
            'rows': [
              [1, '+2', 3, '-'],
              [2, '+2', 3, '2'],
              [3, '+2', 3, '3']
            ]
          }
        ],
        'classFeatures': [
          'Arcane Vanguard: Add your INT modifier to initiative rolls.',
          'Battle Magic: When you cast a cantrip, you can make one weapon attack as a bonus action.'
        ],
        'subclasses': [
          {
            'name': 'House of Blades',
            'shortName': 'Blades',
            'subclassTitle': 'Warmage Archetype',
            'subclassFeatures': [
              'Whirling Steel: When you hit with a melee attack, gain +2 AC until your next turn.'
            ],
            'customSubclassTag': 'Sword-Dancer Variant'
          }
        ],
        'authorCredits': 'Mage Hand Press'
      };

      final cl = parser.parseClass(raw);

      expect(cl.name, equals('Warmage'));
      expect(cl.id.slug, equals('warmage'));
      expect(cl.hitDie, equals('d8'));
      expect(cl.savingThrows, contains('CON'));
      expect(cl.savingThrows, contains('INT'));
      expect(cl.primaryAbility, equals('Intelligence'));
      expect(cl.spellcastingAbility, equals('Intelligence'));
      expect(cl.armorProficiencies, contains('light'));
      expect(cl.weaponProficiencies, contains('martial'));
      expect(cl.featuresMarkdown, contains('Arcane Vanguard'));

      expect(cl.subclasses.length, equals(1));
      final sub = cl.subclasses.first;
      expect(sub.name, equals('House of Blades'));
      expect(sub.classSlug, equals('warmage'));
      expect(sub.shortName, equals('Blades'));
      expect(sub.featuresMarkdown, contains('Whirling Steel'));
      expect(sub.customProperties['customSubclassTag'],
          equals('Sword-Dancer Variant'));

      // Class 0% data loss preservation
      expect(cl.customProperties['authorCredits'], equals('Mage Hand Press'));
      expect(cl.customProperties['classTableGroups'], isNotNull);
    });

    test(
        'parses starting skill proficiencies from community choose.from schema',
        () {
      final raw = {
        'name': 'Scholar',
        'hd': {'number': 1, 'faces': 8},
        'proficiency': ['int', 'wis'],
        'startingProficiencies': {
          'skills': [
            {
              'choose': {
                'from': [
                  'arcana',
                  'history',
                  'investigation',
                  'nature',
                  'religion'
                ],
                'count': 3
              }
            }
          ]
        }
      };

      final cl = parser.parseClass(raw);
      expect(cl.allowedSkills.length, equals(5));
      expect(cl.allowedSkills, contains(SkillType.arcana));
      expect(cl.allowedSkills, contains(SkillType.history));
      expect(cl.allowedSkills, contains(SkillType.investigation));
      expect(cl.allowedSkills, contains(SkillType.nature));
      expect(cl.allowedSkills, contains(SkillType.religion));
      expect(cl.skillChoiceCount, equals(3));
    });

    test('parses starting skill proficiencies with any skill wildcard choice',
        () {
      final raw = {
        'name': 'Jack of All Trades Class',
        'hd': {'number': 1, 'faces': 8},
        'startingProficiencies': {
          'skills': [
            {'any': 4}
          ]
        }
      };

      final cl = parser.parseClass(raw);
      expect(cl.allowedSkills.length, equals(SkillType.values.length));
      expect(cl.skillChoiceCount, equals(4));
    });

    test('falls back to safe defaults when skills are omitted or unstructured',
        () {
      final raw = {
        'name': 'Minimal Class',
        'hd': {'number': 1, 'faces': 10},
      };

      final cl = parser.parseClass(raw);
      expect(cl.allowedSkills, equals(SkillType.values));
      expect(cl.skillChoiceCount, equals(2));
    });

    test(
        'parses startingProficiencies.tools without additionalSpells cleanly (Crafter, Monk, Druid, Rogue pattern)',
        () {
      final rawDruidLike = {
        'name': 'Shapeshifter Guardian',
        'source': 'PHB',
        'hd': {'number': 1, 'faces': 8},
        'proficiency': ['int', 'wis'],
        'startingProficiencies': {
          'armor': ['light', 'medium', 'shields'],
          'weapons': ['clubs', 'daggers'],
          'tools': ['{@item Herbalism kit|PHB}'],
        },
      };

      final parsed = parser.parseClass(rawDruidLike);
      expect(parsed.name, equals('Shapeshifter Guardian'));
      expect(parsed.grants.length, equals(1));
      expect(parsed.grants.first.label, equals('Herbalism kit Proficiency'));
      expect(parsed.grants.first.payload['tool'], equals('Herbalism kit'));

      final rawRogueLike = {
        'name': 'Shadow Infiltrator',
        'source': 'PHB',
        'hd': {'number': 1, 'faces': 8},
        'proficiency': ['dex', 'int'],
        'startingProficiencies': {
          'tools': ["{@item thieves' tools|PHB}"],
        },
      };

      final parsedRogue = parser.parseClass(rawRogueLike);
      expect(parsedRogue.name, equals('Shadow Infiltrator'));
      expect(parsedRogue.grants.length, equals(1));
      expect(
          parsedRogue.grants.first.label, equals("thieves' tools Proficiency"));

      final rawCrafterLike = {
        'name': 'Arcane Crafter',
        'source': 'HOMEBREW',
        'hd': {'number': 1, 'faces': 8},
        'proficiency': ['con', 'int'],
        'startingProficiencies': {
          'tools': [
            "{@item thieves' tools|PHB}",
            "{@item tinker's tools|PHB}",
            "one type of {@item artisan's tools|PHB} of your choice",
          ],
        },
      };

      final parsedCrafter = parser.parseClass(rawCrafterLike);
      expect(parsedCrafter.name, equals('Arcane Crafter'));
      expect(parsedCrafter.grants.length, equals(3));
    });
  });
}
