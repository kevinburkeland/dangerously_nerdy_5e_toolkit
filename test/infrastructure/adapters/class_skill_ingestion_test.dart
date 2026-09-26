import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/homebrew/value_objects/ruleset_version.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/homebrew_entity_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/homebrew_ingestor.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';

void main() {
  group('Class Skill Ingestion & Normalization Tests', () {
    test(
        'Detects class entity from hitDie and startingProficiencies without explicit entityType',
        () {
      final json = <String, dynamic>{
        'name': 'Warlord',
        'hitDie': 10,
        'startingProficiencies': {
          'armor': ['light', 'medium', 'shields'],
          'weapons': ['simple', 'martial'],
          'skills': [
            {
              'choose': {
                'from': [
                  'athletics',
                  'history',
                  'insight',
                  'intimidation',
                  'persuasion'
                ],
                'count': 2,
              },
            },
          ],
        },
      };

      final dto =
          HomebrewEntityDto.fromJson(json, ruleset: RulesetVersion.srd2014);
      expect(dto.entityType, 'class');
      expect(dto.normalizedData['skillChoiceCount'], 2);
      expect(dto.normalizedData['flexibleSkills'], isNotNull);
      final flex = dto.normalizedData['flexibleSkills'] as Map<String, dynamic>;
      expect(flex['count'], 2);
      expect(
          flex['from'],
          containsAll([
            'athletics',
            'history',
            'insight',
            'intimidation',
            'persuasion'
          ]));
      expect(
          dto.normalizedData['allowedSkills'],
          containsAll([
            'athletics',
            'history',
            'insight',
            'intimidation',
            'persuasion'
          ]));
    });

    test(
        'Prevents startingProficiencies and class skill keys from leaking into unparsedPayload',
        () {
      final json = <String, dynamic>{
        'name': 'Scholar',
        'hd': 6,
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
                'count': 3,
              },
            },
          ],
        },
        'proficiencyChoices': [
          {'type': 'skill'},
        ],
        'flexibleSkills': {'count': 3},
        'skillProficiencies': ['arcana'],
        'allowedSkills': ['arcana', 'history'],
        'skillChoiceCount': 3,
        'classFeatures': ['Feature 1'],
        'customCampaignNote': 'Secret Lore',
      };

      final dto =
          HomebrewEntityDto.fromJson(json, ruleset: RulesetVersion.srd2024);
      expect(dto.entityType, 'class');
      expect(dto.unparsedPayload.containsKey('startingProficiencies'), isFalse);
      expect(dto.unparsedPayload.containsKey('proficiencyChoices'), isFalse);
      expect(dto.unparsedPayload.containsKey('flexibleSkills'), isFalse);
      expect(dto.unparsedPayload.containsKey('skillProficiencies'), isFalse);
      expect(dto.unparsedPayload.containsKey('allowedSkills'), isFalse);
      expect(dto.unparsedPayload.containsKey('skillChoiceCount'), isFalse);
      expect(dto.unparsedPayload.containsKey('classFeatures'), isFalse);
      // Unrecognized keys are retained
      expect(dto.unparsedPayload['customCampaignNote'], 'Secret Lore');
    });

    test('Extracts fixed skills and choice pools simultaneously', () {
      final json = <String, dynamic>{
        'name': 'Inquisitor',
        'hitDie': 8,
        'skills': ['investigation', 'insight'],
        'startingProficiencies': {
          'skills': [
            {
              'choose': {
                'from': ['perception', 'religion', 'stealth'],
                'count': 1,
              },
            },
          ],
        },
      };

      final dto =
          HomebrewEntityDto.fromJson(json, ruleset: RulesetVersion.srd2014);
      expect(dto.normalizedData['skillProficiencies'],
          containsAll(['investigation', 'insight']));
      expect(dto.normalizedData['flexibleSkills']?['count'], 1);
      expect(dto.normalizedData['flexibleSkills']?['from'],
          containsAll(['perception', 'religion', 'stealth']));
    });

    test('Parses natural language skill selection string', () {
      final json = <String, dynamic>{
        'name': 'Duelist',
        'hitDie': 10,
        'startingProficiencies': {
          'skills':
              'Choose two from Acrobatics, Athletics, Deception, Insight, Perception, and Sleight of Hand',
        },
      };

      final dto =
          HomebrewEntityDto.fromJson(json, ruleset: RulesetVersion.srd2014);
      expect(dto.normalizedData['skillChoiceCount'], 2);
      final flex =
          dto.normalizedData['flexibleSkills'] as Map<String, dynamic>?;
      expect(flex, isNotNull);
      expect(flex!['count'], 2);
      expect(
          flex['from'],
          containsAll([
            'acrobatics',
            'athletics',
            'deception',
            'insight',
            'perception',
            'sleight of hand'
          ]));
    });

    test('Maps HomebrewEntityDto into domain ClassDefinition / CharacterClass',
        () {
      final json = <String, dynamic>{
        'name': 'Warlord',
        'hitDie': 10,
        'savingThrows': ['str', 'con'],
        'startingProficiencies': {
          'armor': ['light', 'medium'],
          'weapons': ['simple', 'martial'],
          'skills': [
            {
              'choose': {
                'from': ['athletics', 'intimidation', 'persuasion'],
                'count': 2,
              },
            },
          ],
        },
      };

      final dto =
          HomebrewEntityDto.fromJson(json, ruleset: RulesetVersion.srd2014);
      final domainClass = HomebrewIngestor.mapClassFromDto(dto);

      expect(domainClass.name, 'Warlord');
      expect(domainClass.hitDie, 'd10');
      expect(domainClass.savingThrows, ['str', 'con']);
      expect(domainClass.armorProficiencies, ['light', 'medium']);
      expect(domainClass.weaponProficiencies, ['simple', 'martial']);
      expect(domainClass.skillChoiceCount, 2);
      expect(
          domainClass.allowedSkills,
          containsAll([
            SkillType.athletics,
            SkillType.intimidation,
            SkillType.persuasion,
          ]));
    });

    test('parseCustomClasses parses batch of classes with error isolation', () {
      final rawList = [
        {
          'name': 'Valid Class',
          'hitDie': 8,
          'startingProficiencies': {
            'skills': [
              {
                'choose': {
                  'from': ['athletics', 'acrobatics'],
                  'count': 1,
                },
              },
            ],
          },
        },
        {
          'malformed': 'Missing name',
        },
        {
          'name': 'Second Valid Class',
          'hitDie': 12,
        },
      ];

      final classes = HomebrewIngestor.parseCustomClasses(
        rawList,
        ruleset: RulesetVersion.srd2014,
      );

      expect(classes.length, 2);
      expect(classes[0].name, 'Valid Class');
      expect(classes[1].name, 'Second Valid Class');
    });
  });
}
