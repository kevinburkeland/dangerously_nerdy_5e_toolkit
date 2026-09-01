import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_adapters.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_stat_calculator.dart';

void main() {
  group('Class Progression & Feature Choice Engine Tests', () {
    late LayeredPriorityRepository repository;
    late PriorityLayer baseLayer;
    late ReferenceResolver resolver;

    setUp(() {
      repository = LayeredPriorityRepository();
      baseLayer = PriorityLayer(
        layerId: 'base',
        name: 'Base Layer',
        priority: LayerPriority.baseRuleset,
      );
      repository.addLayer(baseLayer);
      resolver = ReferenceResolver(repository);
    });

    group('1. Declarative Schema & Serialization Contracts', () {
      test('FeatureOption serializes and deserializes correctly', () {
        const option = FeatureOption(
          id: 'defense',
          name: 'Defense',
          descriptionMarkdown: 'Gain +1 AC when wearing armor',
          grants: {'acBonus': 1, 'requiresArmor': true},
        );

        final map = option.toMap();
        final reconstructed = FeatureOption.fromMap(map);

        expect(reconstructed.id, equals('defense'));
        expect(reconstructed.name, equals('Defense'));
        expect(reconstructed.grants['acBonus'], equals(1));
        expect(reconstructed.grants['requiresArmor'], isTrue);
      });

      test('ClassFeatureDecision validates min and max selections', () {
        const decision = ClassFeatureDecision(
          id: 'fighting-style-1',
          name: 'Fighting Style',
          prompt: 'Choose 1 style',
          levelRequired: 1,
          type: FeatureChoiceType.fightingStyle,
          minSelections: 1,
          maxSelections: 1,
          availableOptions: [
            FeatureOption(id: 'archery', name: 'Archery', descriptionMarkdown: '+2 ranged attacks'),
            FeatureOption(id: 'defense', name: 'Defense', descriptionMarkdown: '+1 AC'),
          ],
        );

        expect(decision.isValidSelection([]), isFalse);
        expect(decision.isValidSelection(['archery']), isTrue);
        expect(decision.isValidSelection(['archery', 'defense']), isFalse);

        final map = decision.toMap();
        final reconstructed = ClassFeatureDecision.fromMap(map);
        expect(reconstructed.id, equals('fighting-style-1'));
        expect(reconstructed.type, equals(FeatureChoiceType.fightingStyle));
        expect(reconstructed.availableOptions.length, equals(2));
      });

      test('ClassLevelProgression serializes selectedFeatureOptions', () {
        const slice = ClassLevelProgression(
          classRef: EntityReference(
            refType: EntityType.classDefinition,
            slug: 'fighter',
            displayName: 'Fighter',
          ),
          level: 1,
          hitDie: 'd10',
          selectedFeatureOptions: {
            'fighter-fighting-style-1': ['defense'],
          },
        );

        final map = slice.toMap();
        final reconstructed = ClassLevelProgression.fromMap(map);

        expect(reconstructed.selectedFeatureOptions['fighter-fighting-style-1'], equals(['defense']));
      });
    });

    group('2. Ruleset-Aware Subclass Selection Matrix', () {
      test('2014 Ruleset Subclass Milestones: Cleric, Sorcerer, Warlock at Level 1, Druid/Wizard at Level 2, Fighter at Level 3', () {
        const cleric = SrdClassesLibrary.cleric;
        const sorcerer = SrdClassesLibrary.sorcerer;
        final warlock = SrdClassesLibrary.warlock;
        const druid = SrdClassesLibrary.druid;
        const wizard = SrdClassesLibrary.wizard;
        const fighter = SrdClassesLibrary.fighter;

        // Subclass level inquiry under 2014
        expect(cleric.getSubclassLevel(RulesetVersion.v2014), equals(1));
        expect(sorcerer.getSubclassLevel(RulesetVersion.v2014), equals(1));
        expect(warlock.getSubclassLevel(RulesetVersion.v2014), equals(1));
        expect(druid.getSubclassLevel(RulesetVersion.v2014), equals(2));
        expect(wizard.getSubclassLevel(RulesetVersion.v2014), equals(2));
        expect(fighter.getSubclassLevel(RulesetVersion.v2014), equals(3));

        // Engine milestone checks
        expect(CharacterProgressionEngine.isSubclassMilestone('warlock', 1, ruleset: RulesetVersion.v2014), isTrue);
        expect(CharacterProgressionEngine.isSubclassMilestone('warlock', 2, ruleset: RulesetVersion.v2014), isFalse);
        expect(CharacterProgressionEngine.isSubclassMilestone('druid', 2, ruleset: RulesetVersion.v2014), isTrue);
        expect(CharacterProgressionEngine.isSubclassMilestone('fighter', 3, ruleset: RulesetVersion.v2014), isTrue);
      });

      test('2024 Ruleset Subclass Milestones: Standardized across all classes at Level 3', () {
        const cleric = SrdClassesLibrary.cleric;
        const sorcerer = SrdClassesLibrary.sorcerer;
        final warlock = SrdClassesLibrary.warlock;
        const druid = SrdClassesLibrary.druid;
        const fighter = SrdClassesLibrary.fighter;

        expect(cleric.getSubclassLevel(RulesetVersion.v2024), equals(3));
        expect(sorcerer.getSubclassLevel(RulesetVersion.v2024), equals(3));
        expect(warlock.getSubclassLevel(RulesetVersion.v2024), equals(3));
        expect(druid.getSubclassLevel(RulesetVersion.v2024), equals(3));
        expect(fighter.getSubclassLevel(RulesetVersion.v2024), equals(3));

        expect(CharacterProgressionEngine.isSubclassMilestone('warlock', 1, ruleset: RulesetVersion.v2024), isFalse);
        expect(CharacterProgressionEngine.isSubclassMilestone('warlock', 3, ruleset: RulesetVersion.v2024), isTrue);
        expect(CharacterProgressionEngine.isSubclassMilestone('cleric', 1, ruleset: RulesetVersion.v2024), isFalse);
        expect(CharacterProgressionEngine.isSubclassMilestone('cleric', 3, ruleset: RulesetVersion.v2024), isTrue);
      });
    });

    group('3. 2024 Level 1 Class Decisions Engine', () {
      test('2024 Cleric presents Divine Order choices (Protector vs Thaumaturge)', () {
        const cleric = SrdClassesLibrary.cleric;
        final decisions = cleric.getDecisionsForLevel(1, ruleset: RulesetVersion.v2024);

        expect(decisions, isNotEmpty);
        final orderDecision = decisions.firstWhere((d) => d.type == FeatureChoiceType.divineOrder);
        expect(orderDecision.availableOptions.map((o) => o.id), containsAll(['protector', 'thaumaturge']));
      });

      test('2024 Druid presents Primal Order choices (Magician vs Warden)', () {
        const druid = SrdClassesLibrary.druid;
        final decisions = druid.getDecisionsForLevel(1, ruleset: RulesetVersion.v2024);

        expect(decisions, isNotEmpty);
        final orderDecision = decisions.firstWhere((d) => d.type == FeatureChoiceType.primalOrder);
        expect(orderDecision.availableOptions.map((o) => o.id), containsAll(['magician', 'warden']));
      });

      test('2024 Warlock presents Eldritch Invocations / Pact Boon choices at Level 1', () {
        final warlock = SrdClassesLibrary.warlock;
        final decisions = warlock.getDecisionsForLevel(1, ruleset: RulesetVersion.v2024);

        expect(decisions, isNotEmpty);
        final invocationDecision = decisions.firstWhere((d) => d.type == FeatureChoiceType.invocations);
        expect(invocationDecision.availableOptions.map((o) => o.id), containsAll(['pact_of_the_blade', 'pact_of_the_tome', 'pact_of_the_chain', 'armor_of_shadows']));
      });

      test('Fighter presents Fighting Style at Level 1 in both 2014 and 2024', () {
        const fighter = SrdClassesLibrary.fighter;
        final decisions2024 = fighter.getDecisionsForLevel(1, ruleset: RulesetVersion.v2024);
        final decisions2014 = fighter.getDecisionsForLevel(1, ruleset: RulesetVersion.v2014);

        expect(decisions2024, isNotEmpty);
        expect(decisions2014, isNotEmpty);
        expect(decisions2024.first.availableOptions.map((o) => o.id), contains('defense'));
      });
    });

    group('4. Homebrew Ingestion & ACL Normalization', () {
      test('Community compendium parser extracts custom subclass selection level and feature decisions', () {
        final adapter = CommunityCompendiumAdapters();
        final rawClassJson = {
          'name': 'Blood Hunter',
          'source': 'HOMEBREW',
          'hd': {'number': 1, 'faces': 10},
          'subclassSelectionLevel': 3,
          'featureDecisions': [
            {
              'id': 'blood-hunter-order-3',
              'name': 'Blood Hunter Order',
              'prompt': 'Select your Order archetype',
              'levelRequired': 3,
              'type': 'subclassSelection',
              'availableOptions': [
                {'id': 'order-of-the-ghostslayer', 'name': 'Order of the Ghostslayer', 'descriptionMarkdown': 'Ghost hunter'},
                {'id': 'order-of-the-lycan', 'name': 'Order of the Lycan', 'descriptionMarkdown': 'Werewolf shape'}
              ]
            }
          ]
        };

        final parsed = adapter.parseClass(rawClassJson);
        expect(parsed.name, equals('Blood Hunter'));
        expect(parsed.subclassSelectionLevel, equals(3));
        expect(parsed.featureDecisions.length, equals(1));
        expect(parsed.featureDecisions.first.availableOptions.length, equals(2));
      });

      test('Compendium ingestion pipeline normalizes custom classes with bespoke level 1 choices', () {
        final pipeline = CompendiumJsonIngestionPipeline();
        final rawCompendium = {
          'name': 'Psion',
          'source': 'HOMEBREW',
          'hd': {'faces': 8},
          'subclassLevel': 1,
          'subclasses': [
            {
              'name': 'Telepath',
              'source': 'HOMEBREW',
              'entries': ['Telepathic link powers.']
            }
          ],
          'featureDecisions': [
            {
              'id': 'psion-discipline-1',
              'name': 'Psionic Discipline',
              'prompt': 'Choose your primary discipline',
              'levelRequired': 1,
              'type': 'customOption',
              'availableOptions': [
                {'id': 'telekinesis', 'name': 'Telekinesis', 'descriptionMarkdown': 'Move objects with your mind'},
                {'id': 'psychokinesis', 'name': 'Psychokinesis', 'descriptionMarkdown': 'Energy projection'}
              ]
            }
          ]
        };

        final result = pipeline.ingestJsonString(jsonEncode(rawCompendium));
        expect(result.classes.length, equals(1));
        final psion = result.classes.first;
        expect(psion.name, equals('Psion'));
        expect(psion.subclassSelectionLevel, equals(1));
        expect(psion.subclasses.length, equals(1));
        expect(psion.featureDecisions.length, equals(1));
        expect(psion.featureDecisions.first.availableOptions.first.id, equals('telekinesis'));
      });
    });

    group('5. Mechanical Grants & Live Character Sheet Evaluation', () {
      test('Defense Fighting Style grants +1 AC only when armor is equipped', () {
        const leatherArmor = EquipmentItem(
          id: EntityId(slug: 'leather-armor', ruleset: RulesetVersion.v2024),
          name: 'Leather Armor',
          itemType: 'Armor',
          rarity: 'common',
          requiresAttunement: false,
          descriptionMarkdown: 'Standard light leather armor.',
          customProperties: {
            'baseAc': 11,
            'armorType': 'light',
          },
        );
        baseLayer.registerEntity(leatherArmor);

        const characterWithoutArmor = Character(
          id: EntityId(slug: 'fighter-hero', ruleset: RulesetVersion.v2024),
          name: 'Fighter Hero',
          speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
          progression: CharacterProgression(classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              level: 1,
              hitDie: 'd10',
              selectedFeatureOptions: {
                'fighter-fighting-style-1': ['defense'],
              },
            ),
          ]),
          baseScores: AbilityScores(strength: 16, dexterity: 14, constitution: 14, intelligence: 10, wisdom: 10, charisma: 10),
          inventory: [],
          resources: CharacterResourcePool(currentHp: 12, currentHitDice: {'d10': 1}),
        );

        final unarmoredStats = CharacterStatCalculator.compute(characterWithoutArmor, resolver);
        // Unarmored: 10 + 2 (DEX) = 12 (Defense style is inactive without armor)
        expect(unarmoredStats.armorClass, equals(12));

        final characterWithArmor = characterWithoutArmor.copyWith(
          inventory: [
            const InventoryItemInstance(
              instanceId: 'armor-1',
              itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
              isEquipped: true,
              equippedSlot: EquipmentSlot.armor,
            ),
          ],
        );

        final armoredStats = CharacterStatCalculator.compute(characterWithArmor, resolver);
        // Armored: 11 (Leather) + 2 (DEX) + 1 (Defense style) = 14
        expect(armoredStats.armorClass, equals(14));
        expect(armoredStats.activeBuffNotes, contains('Defense Fighting Style: +1 AC'));
      });

      test('Draconic Sorcerer subclass grants base AC 13 + DEX when unarmored', () {
        const sorcerer = Character(
          id: EntityId(slug: 'draconic-sorc', ruleset: RulesetVersion.v2024),
          name: 'Dragon Sorcerer',
          speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
          progression: CharacterProgression(classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'sorcerer', displayName: 'Sorcerer'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'draconic-sorcery', displayName: 'Draconic Sorcery'),
              level: 1,
              hitDie: 'd6',
            ),
          ]),
          baseScores: AbilityScores(strength: 10, dexterity: 16, constitution: 14, intelligence: 10, wisdom: 10, charisma: 16),
          inventory: [],
          resources: CharacterResourcePool(currentHp: 8, currentHitDice: {'d6': 1}),
        );

        final stats = CharacterStatCalculator.compute(sorcerer, resolver);
        // Draconic Resilience: 13 + 3 (DEX) = 16
        expect(stats.armorClass, equals(16));
        expect(stats.armorClassBreakdown, contains('13 (Draconic Resilience)'));
      });

      test('LevelUpRequest preserves and aggregates selectedFeatureOptions across level ups', () {
        const baseFighter = Character(
          id: EntityId(slug: 'fighter-prog', ruleset: RulesetVersion.v2024),
          name: 'Fighter Progression',
          speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
          progression: CharacterProgression(classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              level: 1,
              hitDie: 'd10',
              selectedFeatureOptions: {
                'fighter-fighting-style-1': ['defense'],
              },
            ),
          ]),
          baseScores: AbilityScores.standardArray(),
          inventory: [],
          resources: CharacterResourcePool(currentHp: 12, currentHitDice: {'d10': 1}),
        );

        // Advance to Level 2
        final level2 = CharacterProgressionEngine.applyLevelUp(
          baseFighter,
          const LevelUpRequest(
            targetClassSlug: 'fighter',
            hpChoice: HpProgressionChoice.average(),
          ),
        );

        expect(level2.totalLevel, equals(2));
        final fighterSlice = level2.progression.getClass('fighter')!;
        expect(fighterSlice.selectedFeatureOptions['fighter-fighting-style-1'], equals(['defense']));
      });
    });
  });
}
