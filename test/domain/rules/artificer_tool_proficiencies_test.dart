import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/skill_trait_resolver.dart';

void main() {
  group('Artificer Tool Proficiencies Tests', () {
    test('CharacterDraft.reconcile seeds Thieves Tools and Tinkers Tools for Artificer', () {
      final draft = CharacterDraft(
        characterName: 'Gearwright',
        rulesEdition: DmRulesEdition.v2014,
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'artificer',
          displayName: 'Artificer',
        ),
      );

      expect(draft.toolProficiencies, contains("Thieves' Tools"));
      expect(draft.toolProficiencies, contains("Tinker's Tools"));
    });

    test('SkillTraitResolver.resolveTools ensures starting tools for Artificer, Rogue, and Druid', () {
      final artificerTools = SkillTraitResolver.resolveTools(
        classSlug: 'artificer',
        draftTools: ["Alchemist's Supplies"],
      );
      expect(artificerTools, contains("Thieves' Tools"));
      expect(artificerTools, contains("Tinker's Tools"));
      expect(artificerTools, contains("Alchemist's Supplies"));

      final rogueTools = SkillTraitResolver.resolveTools(classSlug: 'rogue');
      expect(rogueTools, contains("Thieves' Tools"));

      final druidTools = SkillTraitResolver.resolveTools(classSlug: 'druid');
      expect(druidTools, contains("Herbalism Kit"));
    });

    test('CharacterFactory.buildFromDraft compiles Artificer tools including selected artisan tool', () {
      final draft = CharacterDraft(
        characterName: 'Tinkering Artificer',
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
          slug: 'artificer',
          displayName: 'Artificer',
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
