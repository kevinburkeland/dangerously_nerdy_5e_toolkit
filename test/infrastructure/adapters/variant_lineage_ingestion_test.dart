import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/homebrew_entity_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/homebrew_ingestor.dart';

void main() {
  group('Variant Lineage & Nested Species Ability Ingestion Tests', () {
    final markOfMakingJson = <String, dynamic>{
      'name': 'Human (Lineage of Artifice)',
      'source': 'CUSTOM_LINEAGE',
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
        'An ancient lineage mark conferring innate magical utility and craft intuition.',
        {
          'name': "Artisan's Intuition",
          'entries': ['When you make an Arcana check or an ability check with artisan tools, you can add 1d4.'],
        },
      ],
      'customTrait': "Artisan's Intuition",
      'lineageType': 'Artifice',
    };

    final markOfSentinelJson = <String, dynamic>{
      'name': 'Human (Lineage of Warding)',
      'source': 'CUSTOM_LINEAGE',
      'raceName': 'Human',
      'raceSource': 'PHB',
      'ability': [
        {
          'con': 2,
          'wis': 1,
        },
      ],
      'entries': [
        "Warden's Intuition: When you roll Initiative or make an Insight or Perception check, add 1d4.",
      ],
    };

    final hybridRootAndNestedJson = <String, dynamic>{
      'name': 'Lineage Hybrid Custom',
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
      final dtoArtifice = HomebrewEntityDto.fromJson(
        markOfMakingJson,
        ruleset: RulesetVersion.srd2014,
      );
      expect(dtoArtifice.entityType, equals('race'));

      final dtoWarding = HomebrewEntityDto.fromJson(
        markOfSentinelJson,
        ruleset: RulesetVersion.srd2014,
      );
      expect(dtoWarding.entityType, equals('race'));

      final dtoHybrid = HomebrewEntityDto.fromJson(
        hybridRootAndNestedJson,
        ruleset: RulesetVersion.srd2014,
      );
      expect(dtoHybrid.entityType, equals('race'));
    });

    test('extracts nested static stat bonuses and choice pools into normalizedData', () {
      final dtoArtifice = HomebrewEntityDto.fromJson(
        markOfMakingJson,
        ruleset: RulesetVersion.srd2014,
      );

      // Verify static ability bonuses in normalizedData
      expect(dtoArtifice.normalizedData['abilities'], isNotNull);
      final abilities = dtoArtifice.normalizedData['abilities'] as Map<String, dynamic>;
      expect(abilities['int'], equals(2));

      // Verify flexible ability choices in normalizedData
      expect(dtoArtifice.normalizedData['flexibleAbilities'], isNotNull);
      final flex = dtoArtifice.normalizedData['flexibleAbilities'] as Map<String, dynamic>;
      expect(flex['count'], equals(1));
      expect(flex['amount'], equals(1));
      expect(flex['from'], containsAll(['str', 'dex', 'con', 'wis', 'cha']));
      expect(flex['choices'], isNotEmpty);

      // Verify 0% data loss preservation of unparsed custom keys
      expect(dtoArtifice.unparsedPayload['customTrait'], equals("Artisan's Intuition"));
      expect(dtoArtifice.unparsedPayload['lineageType'], equals('Artifice'));
    });

    test('extracts multiple fixed ability modifiers from nested ability map', () {
      final dtoWarding = HomebrewEntityDto.fromJson(
        markOfSentinelJson,
        ruleset: RulesetVersion.srd2014,
      );

      expect(dtoWarding.normalizedData['abilities'], isNotNull);
      final abilities = dtoWarding.normalizedData['abilities'] as Map<String, dynamic>;
      expect(abilities['con'], equals(2));
      expect(abilities['wis'], equals(1));
      expect(dtoWarding.normalizedData['flexibleAbilities'], isNull);
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
      final dtoArtifice = HomebrewEntityDto.fromJson(
        markOfMakingJson,
        ruleset: RulesetVersion.srd2014,
      );

      final race = HomebrewIngestor.mapRaceFromDto(dtoArtifice);

      expect(race.name, equals('Human (Lineage of Artifice)'));
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
      expect(races[0].name, equals('Human (Lineage of Artifice)'));
      expect(races[0].fixedAbilityBonuses['int'], equals(2));
      expect(races[1].name, equals('Human (Lineage of Warding)'));
      expect(races[1].fixedAbilityBonuses['con'], equals(2));
      expect(races[2].name, equals('Lineage Hybrid Custom'));
      expect(races[2].fixedAbilityBonuses['str'], equals(1));
    });
  });
}
