import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_feat_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/skill_trait_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/rules/ruleset_edition.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/homebrew_entity_dto.dart';

void main() {
  group('Homebrew Feats & Class Features Directives (SRD Compliant)', () {
    test('Feat parser extracts armor and tool proficiencies from homebrew JSON', () {
      final featJson = {
        'name': 'Ironclad Vanguard',
        'source': 'HomebrewCodex',
        'entries': [
          'You have trained extensively with defense equipment.',
        ],
        'armorProficiencies': [
          {'medium': true, 'shield': true},
        ],
        'toolProficiencies': [
          {'anyArtisansTool': 1},
          'Smith\'s Tools',
        ],
        'weaponProficiencies': [
          {'martial': true},
        ],
      };

      final feat = CompendiumFeatParser().parseFeat(featJson);
      expect(feat.name, 'Ironclad Vanguard');

      // Check grants
      final armorGrants = feat.grants.where((g) => g.type == GrantType.proficiency).toList();
      expect(armorGrants.isNotEmpty, isTrue);

      final toolGrants = feat.grants.where((g) => g.payload['tool'] != null || g.payload['proficiency'] != null).toList();
      expect(toolGrants.any((g) => (g.payload['tool'] ?? g.payload['proficiency']) == "Smith's Tools"), isTrue);

      // Check customProperties preservation
      expect(feat.customProperties['armorProficiencies'], isNotNull);
      expect(feat.customProperties['toolProficiencies'], isNotNull);
      expect(feat.customProperties['weaponProficiencies'], isNotNull);
    });

    test('HomebrewEntityDto recognizes armor, tool, and weapon proficiencies in feats', () {
      final dto = HomebrewEntityDto.fromJson({
        'name': 'Clockwork Craftsman',
        'source': 'HomebrewCodex',
        'entries': ['Master of mechanical craft.'],
        'toolProficiencies': [
          {'anyArtisansTool': 1},
        ],
        'armorProficiencies': ['light'],
      }, ruleset: RulesetEdition.v2014);

      expect(dto.entityType, 'feat');
      expect(dto.normalizedData['toolProficiencies'], isNotNull);
      expect(dto.normalizedData['armorProficiencies'], isNotNull);
    });

    test('SkillTraitResolver resolves armor and weapon proficiencies across feats', () {
      final armorProfs = SkillTraitResolver.resolveArmorProficiencies(
        classSlug: 'wizard',
        speciesSlug: 'human',
        featSlugs: const ['moderately-armored'],
        customProperties: {
          'armorProficiencies': ['Medium Armor', 'Shields'],
        },
      );

      expect(armorProfs.contains('Medium Armor'), isTrue);
      expect(armorProfs.contains('Shields'), isTrue);

      final weaponProfs = SkillTraitResolver.resolveWeaponProficiencies(
        classSlug: 'wizard',
        speciesSlug: 'human',
        featSlugs: const [],
        customProperties: {
          'weaponProficiencies': ['Martial Weapons'],
        },
      );

      expect(weaponProfs.contains('Martial Weapons'), isTrue);
    });

    test('CharacterSheetController.addFeat grants tools and armor/weapon proficiencies', () async {
      final testFeat = Feat(
        id: const EntityId(slug: 'ironclad-artisan', ruleset: RulesetVersion.v2014),
        name: 'Ironclad Artisan',
        descriptionMarkdown: 'Grants medium armor and artisan tools.',
        grants: [
          FeatureGrant.armorProficiency('Medium Armor', grantId: 'artisan-armor-1'),
          FeatureGrant.armorProficiency('Shields', grantId: 'artisan-armor-2'),
          FeatureGrant.bonusTool("Brewer's Supplies", grantId: 'artisan-tool-1'),
        ],
        customProperties: {
          'armorProficiencies': ['Medium Armor', 'Shields'],
          'toolProficiencies': ["Brewer's Supplies"],
        },
      );
      SrdFeatsLibrary.addCustomFeat(testFeat);

      const char = Character(
        id: EntityId(slug: 'test-hero', ruleset: RulesetVersion.v2014),
        name: 'Test Hero',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              level: 1,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 15, dexterity: 14, constitution: 13, intelligence: 12, wisdom: 10, charisma: 8),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: char);

      expect(controller.character.toolProficiencies.contains("Brewer's Supplies"), isFalse);

      await controller.addFeat(
        const EntityReference(refType: EntityType.feat, slug: 'ironclad-artisan', displayName: 'Ironclad Artisan'),
        toolGrant: "Cook's Utensils",
      );

      // Tool proficiencies should now include both Brewer's Supplies and Cook's Utensils
      expect(controller.character.toolProficiencies.contains("Brewer's Supplies"), isTrue);
      expect(controller.character.toolProficiencies.contains("Cook's Utensils"), isTrue);

      // Armor proficiencies should now include Medium Armor and Shields
      final armors = controller.character.customProperties['armorProficiencies'] as List;
      expect(armors.contains('Medium Armor'), isTrue);
      expect(armors.contains('Shields'), isTrue);

      // Now remove the feat and verify cleanup
      await controller.removeFeat('ironclad-artisan');
      expect(controller.character.toolProficiencies.contains("Brewer's Supplies"), isFalse);
    });

    test('Homebrew class with saving throws and restricted skill choices does NOT default to all 18 skills', () {
      final rawClassJson = {
        'name': 'Dungeon Delver Class',
        'source': 'HomebrewCodex',
        'hitDie': 8,
        'proficiency': ['con', 'int'], // Saving throws in community compendium format!
        'startingProficiencies': {
          'skills': [
            {
              'choose': {
                'from': ['athletics', 'investigation', 'perception', 'stealth'],
                'count': 2,
              },
            },
          ],
        },
      };

      final parsedClass = CompendiumClassParser().parseClass(rawClassJson);
      expect(parsedClass.name, 'Dungeon Delver Class');
      expect(parsedClass.allowedSkills.length, 4);
      expect(parsedClass.skillChoiceCount, 2);
      expect(parsedClass.allowedSkills.contains(SkillType.athletics), isTrue);
      expect(parsedClass.allowedSkills.contains(SkillType.investigation), isTrue);
      expect(parsedClass.allowedSkills.contains(SkillType.acrobatics), isFalse);
    });

    test('CharacterActionsResolver parses pipe-delimited feature strings into combat actions', () {
      // Register a custom class with pipe-delimited features in featuresMarkdown
      const customClass = CharacterClass(
        id: EntityId(slug: 'custom-expert', ruleset: RulesetVersion.v2014),
        name: 'Sidekick Expert',
        hitDie: 'd8',
        featuresMarkdown: 'Helpful|Sidekick Expert|TCoE|1\nCunning Action|Sidekick Expert|TCoE|2\nReliable Talent|Sidekick Expert|TCoE|11',
      );
      SrdClassesLibrary.addCustomClass(customClass);

      const hero = Character(
        id: EntityId(slug: 'expert-hero', ruleset: RulesetVersion.v2014),
        name: 'Expert Hero',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'custom-expert', displayName: 'Sidekick Expert'),
              level: 3,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 10, dexterity: 16, constitution: 14, intelligence: 12, wisdom: 10, charisma: 8),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: hero);
      final stats = CharacterEvaluationEngine.evaluate(hero);

      final resolvedWithCustom = CharacterActionsResolver.resolve(
        character: hero,
        stats: stats,
        controller: controller,
      );

      // Helpful should be extracted as a Bonus Action!
      final helpfulAction = resolvedWithCustom.bonusActions.where((a) => a.name.toLowerCase() == 'helpful').firstOrNull;
      expect(helpfulAction, isNotNull, reason: 'Helpful should be resolved as a bonus action');
      expect(helpfulAction?.description, contains('Help action as a bonus action'));

      // Cunning Action should also be resolved as a Bonus Action at level 2+
      final cunningAction = resolvedWithCustom.bonusActions.where((a) => a.name.toLowerCase() == 'cunning action').firstOrNull;
      expect(cunningAction, isNotNull, reason: 'Cunning Action should be resolved at level 3');

      // Reliable Talent requires Level 11, so at Level 3 it should be skipped
      final reliableTalent = resolvedWithCustom.allActions.where((a) => a.name.toLowerCase() == 'reliable talent').firstOrNull;
      expect(reliableTalent, isNull, reason: 'Reliable Talent should be level-gated at level 3');
    });
  });
}
