import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart' as domain_rules;
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/homebrew_ingestor.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';

void main() {
  group('Background Ingestion & Character Compilation Pipeline', () {
    test('Ingests custom background JSON and parses skills, equipment, and 2024 ASIs', () {
      final rawBackgroundJson = {
        'name': 'Wandering Herbalist',
        'entityType': 'background',
        'skills': ['Medicine', 'Nature'],
        'tools': ['Herbalism kit'],
        'languages': ['Common', 'Sylvan'],
        'startingEquipment': ['Herbalism kit', 'Poultice pouch', 'Traveler\'s clothes'],
        'ability': [
          {'wis': 2, 'con': 1}
        ],
        'entries': [
          'You spent seasons foraging in ancient groves and learning herbal lore.'
        ],
      };

      final parsedList = HomebrewIngestor.parseCustomBackgrounds(
        [rawBackgroundJson],
        ruleset: domain_rules.RulesetVersion.srd2024,
      );

      expect(parsedList, hasLength(1));
      final bg = parsedList.first;
      expect(bg.name, equals('Wandering Herbalist'));
      expect(bg.skillProficiencies, containsAll(['Medicine', 'Nature']));
      expect(bg.toolProficiencies, contains('Herbalism kit'));
      expect(bg.languages, containsAll(['Common', 'Sylvan']));
      expect(bg.customProperties['startingEquipment'], containsAll(['Herbalism kit', 'Poultice pouch', 'Traveler\'s clothes']));
      expect(bg.customProperties['abilities'], equals({'wis': 2, 'con': 1}));
      expect(bg.abilityScoreSummary, contains('WIS +2'));
      expect(bg.abilityScoreSummary, contains('CON +1'));
    });

    test('CharacterFactory.buildFromDraft grants background skills, equipment, and 2024 ASIs onto Character', () {
      final rawBackgroundJson = {
        'name': 'Wandering Herbalist',
        'entityType': 'background',
        'skills': ['Medicine', 'Nature'],
        'startingEquipment': ['Herbalism kit', 'Traveler\'s clothes'],
        'ability': [
          {'wis': 2, 'con': 1}
        ],
        'entries': ['Foraging and medicinal craft.'],
      };

      final parsedList = HomebrewIngestor.parseCustomBackgrounds(
        [rawBackgroundJson],
        ruleset: domain_rules.RulesetVersion.srd2024,
      );
      final bg = parsedList.first;

      final bgRef = EntityReference<DomainEntity>(
        refType: EntityType.background,
        slug: bg.id.slug,
        displayName: bg.name,
        customProperties: bg.customProperties,
      );

      final draft = CharacterDraft(
        characterName: 'Aria Greenleaf',
        rulesEdition: DmRulesEdition.v2024,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'druid',
          displayName: 'Druid',
        ),
        startingClassHitDie: 'd8',
        backgroundRef: bgRef,
        baseScores: const AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 13,
          intelligence: 12,
          wisdom: 15,
          charisma: 8,
        ),
        selectedSkills: {
          SkillType.survival: SkillProficiencyLevel.proficient,
        },
      );

      final character = CharacterFactory.buildFromDraft(draft);

      // 1. Skill Proficiencies: selected class skills + background skills
      expect(character.skillProficiencies[SkillType.survival], equals(SkillProficiencyLevel.proficient));
      expect(character.skillProficiencies[SkillType.medicine], equals(SkillProficiencyLevel.proficient));
      expect(character.skillProficiencies[SkillType.nature], equals(SkillProficiencyLevel.proficient));

      // 2. Starting Equipment: background items instantiated in inventory
      expect(character.inventory.any((i) => i.itemRef.displayName.contains('Herbalism kit')), isTrue);
      expect(character.inventory.any((i) => i.itemRef.displayName.contains('Traveler\'s clothes')), isTrue);

      // 3. 2024 ASIs: WIS +2 and CON +1 applied to bonusScores
      expect(character.bonusScores.wisdom, equals(2));
      expect(character.bonusScores.constitution, equals(1));

      // 4. Hit Points: base CON (13) + bonus CON (1) = 14 (+2 mod). Level 1 d8 HP = 8 + 2 = 10
      expect(character.resources.currentHp, equals(10));
    });
  });
}
