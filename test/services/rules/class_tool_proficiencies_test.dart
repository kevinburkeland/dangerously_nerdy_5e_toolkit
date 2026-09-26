import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/skill_trait_resolver.dart';

void main() {
  group('Class Tool Proficiencies Tests', () {
    test(
        'CharacterDraft.reconcile seeds Thieves Tools for Rogue and Herbalism Kit for Druid',
        () {
      final rogueDraft = CharacterDraft(
        characterName: 'Shadow Walker',
        rulesEdition: DmRulesEdition.v2014,
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'rogue',
          displayName: 'Rogue',
        ),
      );
      expect(rogueDraft.toolProficiencies, contains("Thieves' Tools"));

      final druidDraft = CharacterDraft(
        characterName: 'Verdant Keeper',
        rulesEdition: DmRulesEdition.v2014,
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'druid',
          displayName: 'Druid',
        ),
      );
      expect(druidDraft.toolProficiencies, contains("Herbalism Kit"));
    });

    test(
        'CharacterDraft.reconcile dynamically seeds tools from startingClassRef customProperties',
        () {
      final customDraft = CharacterDraft(
        characterName: 'Gearwright',
        rulesEdition: DmRulesEdition.v2014,
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'arcane-crafter',
          displayName: 'Arcane Crafter',
          customProperties: {
            'tools': ["Thieves' Tools", "Tinker's Tools"],
          },
        ),
      );

      expect(customDraft.toolProficiencies, contains("Thieves' Tools"));
      expect(customDraft.toolProficiencies, contains("Tinker's Tools"));
    });

    test(
        'SkillTraitResolver.resolveTools ensures starting tools for SRD and custom classes',
        () {
      final rogueTools = SkillTraitResolver.resolveTools(classSlug: 'rogue');
      expect(rogueTools, contains("Thieves' Tools"));

      final druidTools = SkillTraitResolver.resolveTools(classSlug: 'druid');
      expect(druidTools, contains("Herbalism Kit"));

      final customTools = SkillTraitResolver.resolveTools(
        classSlug: 'arcane-crafter',
        draftTools: ["Alchemist's Supplies"],
        customProperties: {
          'startingTools': ["Thieves' Tools", "Tinker's Tools"],
        },
      );
      expect(customTools, contains("Thieves' Tools"));
      expect(customTools, contains("Tinker's Tools"));
      expect(customTools, contains("Alchemist's Supplies"));
    });

    test(
        'CharacterFactory.buildFromDraft compiles tools including background and custom class tools',
        () {
      final draft = CharacterDraft(
        characterName: 'Tinkering Crafter',
        rulesEdition: DmRulesEdition.v2024,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'artisan',
          displayName: 'Guild Artisan',
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'arcane-crafter',
          displayName: 'Arcane Crafter',
          customProperties: {
            'tools': ["Thieves' Tools", "Tinker's Tools"],
          },
        ),
        baseScores: const AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 14,
          intelligence: 16,
          wisdom: 12,
          charisma: 8,
        ),
        toolProficiencies: ["Smith's Tools"],
      );

      final character = CharacterFactory.buildFromDraft(draft);

      expect(character.toolProficiencies, contains("Thieves' Tools"));
      expect(character.toolProficiencies, contains("Tinker's Tools"));
      expect(character.toolProficiencies, contains("Smith's Tools"));
    });
  });
}
