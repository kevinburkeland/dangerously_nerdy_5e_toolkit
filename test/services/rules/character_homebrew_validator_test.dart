import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_homebrew_validator.dart';

void main() {
  group('CharacterHomebrewValidator Tests', () {
    late Character baseSrdCharacter;

    setUp(() {
      baseSrdCharacter = CharacterFactory.createLevel1Character(
        const CharacterCreationRequest(
          characterName: 'Thorin Standard',
          speciesRef: EntityReference(
            refType: EntityType.species,
            slug: 'dwarf',
            displayName: 'Dwarf',
          ),
          startingClassSlug: 'fighter',
          startingClassDisplayName: 'Fighter',
          startingClassHitDie: 'd10',
          baseScores: AbilityScores.standardArray(),
          bonusScores: AbilityScores(constitution: 2),
        ),
      );
    });

    tearDown(() {
      // Clean up any custom entities added to libraries during tests
      SrdClassesLibrary.setCustomClasses([]);
      SrdClassesLibrary.setCustomSubclasses([]);
      SrdSpeciesLibrary.setCustomSpecies([]);
      SrdFeatsLibrary.setCustomFeats([]);
      SpellbookLibrary.setHomebrewSpells([]);
    });

    test('Standard SRD character has no missing homebrew', () {
      final report = CharacterHomebrewValidator.validate(baseSrdCharacter);
      expect(report.hasMissing, isFalse);
      expect(report.missingItems, isEmpty);
      expect(report.summary, equals('All homebrew loaded.'));
    });

    test('Detects missing custom class when not loaded in compendium', () {
      final customChar = baseSrdCharacter.copyWith(
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'blood-hunter',
                displayName: 'Blood Hunter',
                rulesetPreferred: RulesetVersion.homebrew,
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
      );

      final report = CharacterHomebrewValidator.validate(customChar);
      expect(report.hasMissing, isTrue);
      expect(report.count, equals(1));
      expect(report.missingItems.first.type, equals(HomebrewEntityType.classType));
      expect(report.missingItems.first.slug, equals('blood-hunter'));
      expect(report.missingItems.first.name, equals('Blood Hunter'));
    });

    test('Does NOT report missing class when custom class is loaded in compendium', () {
      // Register custom class into SrdClassesLibrary
      SrdClassesLibrary.addCustomClass(
        const CharacterClass(
          id: EntityId(slug: 'blood-hunter', ruleset: RulesetVersion.homebrew),
          name: 'Blood Hunter',
          hitDie: 'd10',
        ),
      );

      final customChar = baseSrdCharacter.copyWith(
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'blood-hunter',
                displayName: 'Blood Hunter',
                rulesetPreferred: RulesetVersion.homebrew,
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
      );

      final report = CharacterHomebrewValidator.validate(customChar);
      expect(report.hasMissing, isFalse);
    });

    test('Detects missing custom subclass on core class', () {
      final customChar = baseSrdCharacter.copyWith(
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'echo-knight',
                displayName: 'Echo Knight',
                rulesetPreferred: RulesetVersion.homebrew,
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
      );

      final report = CharacterHomebrewValidator.validate(customChar);
      expect(report.hasMissing, isTrue);
      expect(report.missingItems.any((i) => i.type == HomebrewEntityType.subclassType && i.slug == 'echo-knight'), isTrue);
    });

    test('Detects missing custom species', () {
      final customChar = baseSrdCharacter.copyWith(
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'plasmoid',
          displayName: 'Plasmoid',
          rulesetPreferred: RulesetVersion.homebrew,
        ),
      );

      final report = CharacterHomebrewValidator.validate(customChar);
      expect(report.hasMissing, isTrue);
      expect(report.missingItems.any((i) => i.type == HomebrewEntityType.speciesType && i.slug == 'plasmoid'), isTrue);
    });

    test('Detects missing custom feat', () {
      final customChar = baseSrdCharacter.copyWith(
        feats: [
          const EntityReference(
            refType: EntityType.feat,
            slug: 'custom_aberrant_dragonmark',
            displayName: 'Aberrant Dragonmark',
            rulesetPreferred: RulesetVersion.homebrew,
          ),
        ],
      );

      final report = CharacterHomebrewValidator.validate(customChar);
      expect(report.hasMissing, isTrue);
      expect(report.missingItems.any((i) => i.type == HomebrewEntityType.featType && i.slug == 'custom_aberrant_dragonmark'), isTrue);
    });

    test('Detects missing custom spell', () {
      final customChar = baseSrdCharacter.copyWith(
        cantrips: [
          const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'custom_gravity_sinkhole',
            displayName: 'Gravity Sinkhole',
            rulesetPreferred: RulesetVersion.homebrew,
          ),
        ],
      );

      final report = CharacterHomebrewValidator.validate(customChar);
      expect(report.hasMissing, isTrue);
      expect(report.missingItems.any((i) => i.type == HomebrewEntityType.spellType && i.slug == 'custom_gravity_sinkhole'), isTrue);
    });

    test('Detects missing custom equipment / item in inventory', () {
      final customChar = baseSrdCharacter.copyWith(
        inventory: [
          const InventoryItemInstance(
            instanceId: 'inst_sword_99',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'custom_blade_of_the_ruin',
              displayName: 'Blade of the Ruin',
              rulesetPreferred: RulesetVersion.homebrew,
            ),
          ),
        ],
      );

      final report = CharacterHomebrewValidator.validate(customChar);
      expect(report.hasMissing, isTrue);
      expect(report.missingItems.any((i) => i.type == HomebrewEntityType.itemType && i.slug == 'custom_blade_of_the_ruin'), isTrue);
    });

    test('Validates explicit usedHomebrew manifest recorded in customProperties', () {
      final customChar = baseSrdCharacter.copyWith(
        customProperties: {
          'usedHomebrew': [
            {
              'type': 'class',
              'slug': 'psion',
              'name': 'Psion',
              'details': 'Custom mystic psion class',
            },
            {
              'type': 'spell',
              'slug': 'custom_mind_thrust',
              'name': 'Mind Thrust',
            },
          ],
        },
      );

      final report = CharacterHomebrewValidator.validate(customChar);
      expect(report.hasMissing, isTrue);
      expect(report.count, equals(2));
      expect(report.summary, contains('1 Class'));
      expect(report.summary, contains('1 Spell'));
    });

    test('collectHomebrewDependencies gathers all homebrew references from character', () {
      final customChar = baseSrdCharacter.copyWith(
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'custom_grung',
          displayName: 'Grung',
          rulesetPreferred: RulesetVersion.homebrew,
        ),
        feats: [
          const EntityReference(
            refType: EntityType.feat,
            slug: 'custom_poisoner_expert',
            displayName: 'Poisoner Expert',
            rulesetPreferred: RulesetVersion.homebrew,
          ),
        ],
      );

      final deps = CharacterHomebrewValidator.collectHomebrewDependencies(customChar);
      expect(deps.length, equals(2));
      expect(deps.any((d) => d['type'] == 'speciesType' && d['slug'] == 'custom_grung'), isTrue);
      expect(deps.any((d) => d['type'] == 'featType' && d['slug'] == 'custom_poisoner_expert'), isTrue);
    });

    test('CharacterSheetController exposes missingHomebrewReport and hasMissingHomebrew', () {
      final customChar = baseSrdCharacter.copyWith(
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'custom_warforged',
          displayName: 'Warforged',
          rulesetPreferred: RulesetVersion.homebrew,
        ),
      );

      final controller = CharacterSheetController(character: customChar);
      expect(controller.hasMissingHomebrew, isTrue);
      expect(controller.missingHomebrewReport.count, equals(1));
      expect(controller.missingHomebrewReport.missingItems.first.slug, equals('custom_warforged'));
    });
  });
}
