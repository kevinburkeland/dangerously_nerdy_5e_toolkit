import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/homebrew_entity_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/homebrew_ingestor.dart';

void main() {
  group('Eberron Dragonmark & Nested Species Ability Ingestion Tests', () {
    final markOfMakingJson = <String, dynamic>{
      'name': 'Human (Mark of Making)',
      'source': 'ERLW',
      'raceName': 'Human',
      'raceSource': 'PHB',
      'ability': [
        {
          'int': 2,
          'choose': {
            'from': ['str', 'dex', 'con', 'wis', 'cha'],
            'count': 1,
            'amount': 1,
          },
        },
      ],
      'size': ['M'],
      'speed': 30,
      'entries': [
        'A dragonmark is a symbol on the skin that gives mystical power to the person who possesses it.',
        {
          'name': "Artisan's Intuition",
          'entries': ['When you make an Arcana check or an ability check with artisan tools, you can add 1d4.'],
        },
      ],
      'customTrait': "Artisan's Intuition",
      'dragonmarkType': 'Making',
    };

    final markOfSentinelJson = <String, dynamic>{
      'name': 'Human (Mark of Sentinel)',
      'source': 'ERLW',
      'raceName': 'Human',
      'raceSource': 'PHB',
      'ability': [
        {
          'con': 2,
          'wis': 1,
        },
      ],
      'entries': [
        "Sentinel's Intuition: When you roll Initiative or make an Insight or Perception check, add 1d4.",
      ],
    };

    final hybridRootAndNestedJson = <String, dynamic>{
      'name': 'Dragonmark Hybrid Custom',
      'subrace': 'true',
      'str': 1,
      'ability': [
        {
          'choose': {
            'from': ['dex', 'int'],
            'count': 1,
            'amount': 1,
          },
        },
      ],
      'entries': ['Custom hybrid species.'],
    };

    test('correctly classifies subraces and entries with raceName/subrace as race', () {
      final dtoMaking = HomebrewEntityDto.fromJson(
        markOfMakingJson,
        ruleset: RulesetVersion.srd2014,
      );
      expect(dtoMaking.entityType, equals('race'));

      final dtoSentinel = HomebrewEntityDto.fromJson(
        markOfSentinelJson,
        ruleset: RulesetVersion.srd2014,
      );
      expect(dtoSentinel.entityType, equals('race'));

      final dtoHybrid = HomebrewEntityDto.fromJson(
        hybridRootAndNestedJson,
        ruleset: RulesetVersion.srd2014,
      );
      expect(dtoHybrid.entityType, equals('race'));
    });

    test('extracts nested static stat bonuses and choice pools into normalizedData', () {
      final dto = HomebrewEntityDto.fromJson(
        markOfMakingJson,
        ruleset: RulesetVersion.srd2014,
      );

      // Verify static ability bonuses in normalizedData
      expect(dto.normalizedData['abilities'], isNotNull);
      final abilities = dto.normalizedData['abilities'] as Map<String, dynamic>;
      expect(abilities['int'], equals(2));

      // Verify flexible ability choices in normalizedData
      expect(dto.normalizedData['flexibleAbilities'], isNotNull);
      final flex = dto.normalizedData['flexibleAbilities'] as Map<String, dynamic>;
      expect(flex['count'], equals(1));
      expect(flex['amount'], equals(1));
      expect(flex['from'], containsAll(['str', 'dex', 'con', 'wis', 'cha']));
      expect(flex['choices'], isNotEmpty);

      // Verify 0% data loss preservation of unparsed custom keys
      expect(dto.unparsedPayload['customTrait'], equals("Artisan's Intuition"));
      expect(dto.unparsedPayload['dragonmarkType'], equals('Making'));
    });

    test('extracts multiple fixed ability modifiers from nested ability map', () {
      final dto = HomebrewEntityDto.fromJson(
        markOfSentinelJson,
        ruleset: RulesetVersion.srd2014,
      );

      expect(dto.normalizedData['abilities'], isNotNull);
      final abilities = dto.normalizedData['abilities'] as Map<String, dynamic>;
      expect(abilities['con'], equals(2));
      expect(abilities['wis'], equals(1));
      expect(dto.normalizedData['flexibleAbilities'], isNull);
    });

    test('combines root-level stats and nested choice pools seamlessly', () {
      final dto = HomebrewEntityDto.fromJson(
        hybridRootAndNestedJson,
        ruleset: RulesetVersion.srd2014,
      );

      expect(dto.normalizedData['abilities'], isNotNull);
      final abilities = dto.normalizedData['abilities'] as Map<String, dynamic>;
      expect(abilities['str'], equals(1));

      expect(dto.normalizedData['flexibleAbilities'], isNotNull);
      final flex = dto.normalizedData['flexibleAbilities'] as Map<String, dynamic>;
      expect(flex['count'], equals(1));
      expect(flex['from'], containsAll(['dex', 'int']));
    });

    test('HomebrewIngestor maps DTO into Domain Race with accurate bonuses and choice pools', () {
      final dto = HomebrewEntityDto.fromJson(
        markOfMakingJson,
        ruleset: RulesetVersion.srd2014,
      );

      final race = HomebrewIngestor.mapRaceFromDto(dto);

      expect(race.name, equals('Human (Mark of Making)'));
      expect(race.fixedAbilityBonuses, isNotNull);
      expect(race.fixedAbilityBonuses['int'], equals(2));
      expect(race.fixedAbilityBonuses['intelligence'], equals(2));
      expect(race.flexibleAbilityCount, equals(1));
      expect(race.flexibleAbilityBonus, equals(1));

      // Choice pool preserved in customProperties
      expect(race.customProperties['flexibleAbilities'], isNotNull);
      final flexProp = race.customProperties['flexibleAbilities'] as Map<String, dynamic>;
      expect(flexProp['from'], containsAll(['str', 'dex', 'con', 'wis', 'cha']));

      // Ability summary formatted accurately
      expect(race.abilityScoreSummary, isNotNull);
      expect(race.abilityScoreSummary, contains('INT +2'));

      // Traits and custom fields preserved
      expect(race.customProperties['raceName'], equals('Human'));
      expect(race.traitsMarkdown, contains("Artisan's Intuition"));
    });

    test('HomebrewIngestor.parseCustomRaces batch ingests multiple species without error', () {
      final batch = [
        markOfMakingJson,
        markOfSentinelJson,
        hybridRootAndNestedJson,
      ];

      final races = HomebrewIngestor.parseCustomRaces(batch);

      expect(races.length, equals(3));
      expect(races[0].name, equals('Human (Mark of Making)'));
      expect(races[0].fixedAbilityBonuses['int'], equals(2));
      expect(races[1].name, equals('Human (Mark of Sentinel)'));
      expect(races[1].fixedAbilityBonuses['con'], equals(2));
      expect(races[2].name, equals('Dragonmark Hybrid Custom'));
      expect(races[2].fixedAbilityBonuses['str'], equals(1));
    });
  });
}
