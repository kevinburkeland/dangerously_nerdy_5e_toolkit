import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_stat_calculator.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/dnd_ruleset_strategy.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/spellcasting_rules_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/debounced_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dual-Ruleset Divergence: Multiclass Spellcasting Math', () {
    test('Paladin 3 / Sorcerer 4 spell slot progression divergence (2014 vs 2024)', () {
      // 2014: Paladin 3 ~/ 2 = 1, Sorcerer = 4 => ECL 5 (Slots: 4, 3, 2)
      final ecl2014 = MulticlassSlotMatrix.calculateEffectiveCasterLevel(
        fullCasterLevels: 4,
        paladinLevels: 3,
        edition: DmRulesEdition.v2014,
      );
      expect(ecl2014, 5);
      final slots2014 = MulticlassSlotMatrix.getSpellSlots(ecl2014);
      expect(slots2014[0], 4); // 1st level
      expect(slots2014[1], 3); // 2nd level
      expect(slots2014[2], 2); // 3rd level
      expect(slots2014[3], 0); // 4th level

      // 2024: Paladin ceil(3/2) = 2, Sorcerer = 4 => ECL 6 (Slots: 4, 3, 3)
      final ecl2024 = MulticlassSlotMatrix.calculateEffectiveCasterLevel(
        fullCasterLevels: 4,
        paladinLevels: 3,
        edition: DmRulesEdition.v2024,
      );
      expect(ecl2024, 6);
      final slots2024 = MulticlassSlotMatrix.getSpellSlots(ecl2024);
      expect(slots2024[0], 4);
      expect(slots2024[1], 3);
      expect(slots2024[2], 3);
    });

    test('Paladin 1 / Sorcerer 4 multiclass: 2014 gives ECL 4 while 2024 gives ECL 5', () {
      final ecl2014 = MulticlassSlotMatrix.calculateEffectiveCasterLevel(
        fullCasterLevels: 4,
        paladinLevels: 1,
        edition: DmRulesEdition.v2014,
      );
      expect(ecl2014, 4);

      final ecl2024 = MulticlassSlotMatrix.calculateEffectiveCasterLevel(
        fullCasterLevels: 4,
        paladinLevels: 1,
        edition: DmRulesEdition.v2024,
      );
      expect(ecl2024, 5);
    });

    test('Warlock Pact Magic slots remain completely separate from multiclass pool', () {
      const classes = [
        ClassLevelProgression(
          classRef: EntityReference(refType: EntityType.classDefinition, slug: 'sorcerer', displayName: 'Sorcerer'),
          level: 4,
          hitDie: 'd6',
        ),
        ClassLevelProgression(
          classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
          level: 3,
          hitDie: 'd8',
        ),
      ];

      final pool = CharacterProgressionEngine.computeSpellSlots(classes, edition: DmRulesEdition.v2014);
      // Sorcerer 4 standard slots
      expect(pool.maxSlots[1], 4);
      expect(pool.maxSlots[2], 3);
      expect(pool.maxSlots[3] ?? 0, 0);

      // Warlock 3 pact magic slots: 2 x 2nd level
      expect(pool.pactMagicMax, 2);
      expect(pool.pactMagicSlotLevel, 2);
      expect(pool.pactMagicCurrent, 2);
    });
  });

  group('Retroactive HP Scaling & Constitution Updates', () {
    test('Constitution increase from 14 (+2) to 16 (+3) retroactively scales all Hit Dice', () {
      const fighter = Character(
        id: EntityId(slug: 'fighter_hero', ruleset: RulesetVersion.v2024),
        name: 'Valeros',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
            level: 5,
            hitDie: 'd10',
            hitPointsRolled: [6, 6, 6, 6], // Fixed average for d10 is 6
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(
          strength: 16,
          dexterity: 12,
          constitution: 14, // +2 mod
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        resources: CharacterResourcePool(currentHp: 44),
      );

      final repo = LayeredPriorityRepository();
      final resolver = ReferenceResolver(repo);
      final statsL14 = CharacterStatCalculator.compute(fighter, resolver);
      // Level 1: 10 + 2 = 12. Levels 2-5: 4 * (6 + 2) = 32. Total = 44.
      expect(statsL14.maxHp, 44);

      // ASI: CON increased to 16 (+3 mod)
      final fighterWithCon16 = fighter.copyWith(
        bonusScores: const AbilityScores(strength: 0, dexterity: 0, constitution: 2, intelligence: 0, wisdom: 0, charisma: 0),
      );
      final statsL16 = CharacterStatCalculator.compute(fighterWithCon16, resolver);
      // Level 1: 10 + 3 = 13. Levels 2-5: 4 * (6 + 3) = 36. Total = 49 (+5 HP).
      expect(statsL16.maxHp, 49);
    });

    test('Equipping and attuning Amulet of Health (CON 19 = +4) dynamically scales HP', () {
      const amuletItem = EquipmentItem(
        id: EntityId(slug: 'amulet_of_health', ruleset: RulesetVersion.v2024),
        name: 'Amulet of Health',
        itemType: 'Wondrous Item',
        rarity: 'Rare',
        requiresAttunement: true,
        descriptionMarkdown: 'Sets Constitution to 19.',
        customProperties: {
          'abilityOverrides': {'constitution': 19},
        },
      );

      final repo = LayeredPriorityRepository();
      final baseLayer = PriorityLayer(
        layerId: 'base',
        name: 'Base',
        priority: LayerPriority.baseRuleset,
      );
      baseLayer.registerEntity(amuletItem);
      repo.addLayer(baseLayer);
      final resolver = ReferenceResolver(repo);

      const wizard = Character(
        id: EntityId(slug: 'fragile_wizard', ruleset: RulesetVersion.v2024),
        name: 'Raistlin',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'elf', displayName: 'Elf'),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'wizard', displayName: 'Wizard'),
            level: 4,
            hitDie: 'd6',
            hitPointsRolled: [4, 4, 4], // average d6 is 4
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(
          strength: 8,
          dexterity: 14,
          constitution: 10, // +0 mod
          intelligence: 16,
          wisdom: 12,
          charisma: 10,
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'item_amulet_1',
            itemRef: EntityReference<EquipmentItem>(refType: EntityType.equipment, slug: 'amulet_of_health', displayName: 'Amulet of Health'),
            isEquipped: true,
            isAttuned: true,
            requiresAttunement: true,
          ),
        ],
        resources: CharacterResourcePool(currentHp: 18),
      );

      final stats = CharacterStatCalculator.compute(wizard, resolver);
      // CON is overridden to 19 (+4 mod)
      expect(stats.effectiveScores.constitution, 19);
      expect(stats.abilityModifiers[AbilityType.constitution], 4);
      // Level 1: 6 + 4 = 10. Levels 2-4: 3 * (4 + 4) = 24. Total Max HP = 34 (vs 18 without amulet).
      expect(stats.maxHp, 34);
    });

    test('Tough feat correctly adds 2 HP per total level', () {
      const hero = Character(
        id: EntityId(slug: 'tough_barb', ruleset: RulesetVersion.v2024),
        name: 'Conan',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'barbarian', displayName: 'Barbarian'),
            level: 3,
            hitDie: 'd12',
            hitPointsRolled: [7, 7], // avg 7
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(constitution: 14), // +2
        feats: [
          EntityReference(refType: EntityType.feat, slug: 'tough', displayName: 'Tough'),
        ],
        resources: CharacterResourcePool(currentHp: 30),
      );

      final repo = LayeredPriorityRepository();
      final stats = CharacterStatCalculator.compute(hero, ReferenceResolver(repo));
      // Base: (12+2) + 2*(7+2) = 14 + 18 = 32.
      // Tough feat: 3 levels * 2 = +6. Total = 38.
      expect(stats.maxHp, 38);
    });
  });

  group('Exhaustion & Status Mechanics (2014 vs 2024)', () {
    test('2014 discrete exhaustion tiers evaluate speed, HP, and disadvantage correctly', () {
      const strategy = Ruleset2014Strategy();

      // Tier 1: Disadvantage on ability checks
      final t1 = strategy.evaluateExhaustion(1);
      expect(t1.hasDisadvantageOnAbilityChecks, true);
      expect(t1.speedMultiplier, 1.0);
      expect(t1.maxHpMultiplier, 1.0);

      // Tier 2: Speed halved
      final t2 = strategy.evaluateExhaustion(2);
      expect(t2.speedMultiplier, 0.5);

      // Tier 3: Disadvantage on attacks & saves
      final t3 = strategy.evaluateExhaustion(3);
      expect(t3.hasDisadvantageOnAttacksAndSaves, true);

      // Tier 4: Max HP halved
      final t4 = strategy.evaluateExhaustion(4);
      expect(t4.maxHpMultiplier, 0.5);

      // Tier 5: Speed 0
      final t5 = strategy.evaluateExhaustion(5);
      expect(t5.speedMultiplier, 0.0);

      // Tier 6: Dead
      final t6 = strategy.evaluateExhaustion(6);
      expect(t6.isDead, true);
    });

    test('2024 cumulative exhaustion inflicts -2 per stack to d20 tests and -5 ft speed', () {
      const strategy = Ruleset2024Strategy();

      // Stack 1: -2 d20, -5 ft speed
      final s1 = strategy.evaluateExhaustion(1);
      expect(s1.d20TestPenalty, -2);
      expect(s1.speedReductionFeet, 5);

      // Stack 3: -6 d20, -15 ft speed
      final s3 = strategy.evaluateExhaustion(3);
      expect(s3.d20TestPenalty, -6);
      expect(s3.speedReductionFeet, 15);

      // Stack 6: Dead
      final s6 = strategy.evaluateExhaustion(6);
      expect(s6.d20TestPenalty, -12);
      expect(s6.speedReductionFeet, 30);
      expect(s6.isDead, true);
    });

    test('CharacterStatCalculator applies 2024 exhaustion penalties to speed and attack/skill rolls', () {
      const character = Character(
        id: EntityId(slug: 'exhausted_rogue', ruleset: RulesetVersion.v2024),
        name: 'Shadow',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'elf', displayName: 'Elf'),
        rulesEdition: DmRulesEdition.v2024,
        baseSpeedFeet: 30,
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'rogue', displayName: 'Rogue'),
            level: 2,
            hitDie: 'd8',
          ),
        ]),
        baseScores: AbilityScores(strength: 10, dexterity: 16, constitution: 12),
        conditions: [
          CharacterCondition(conditionName: 'exhaustion', parameters: {'level': 2}),
        ],
        resources: CharacterResourcePool(currentHp: 15),
      );

      final repo = LayeredPriorityRepository();
      final stats = CharacterStatCalculator.compute(character, ReferenceResolver(repo));
      // 2 stacks of exhaustion in 2024: -10 ft speed => 20 ft
      expect(stats.speedFeet, 20);
      expect(stats.exhaustion.d20TestPenalty, -4);
      // Dexterity mod = +3, Exhaustion = -4 => Initiative = -1
      expect(stats.initiativeBonus, -1);
      // Stealth skill mod: +3 (DEX) + 0 (prof) - 4 = -1
      expect(stats.skillModifiers[SkillType.stealth], -1);
    });
  });

  group('Derived DCs, Weapon Masteries & Dynamic Encumbrance', () {
    test('Grapple & Shove calculates contested check for 2014 vs Save DC for 2024', () {
      const s2014 = Ruleset2014Strategy();
      final g2014 = s2014.calculateGrappleShoveDc(strengthModifier: 3, dexterityModifier: 1, proficiencyBonus: 2);
      expect(g2014.dc, isNull);
      expect(g2014.formulaDescription, contains('Contested Athletics (+5)'));

      const s2024 = Ruleset2024Strategy();
      final g2024 = s2024.calculateGrappleShoveDc(strengthModifier: 3, dexterityModifier: 1, proficiencyBonus: 2);
      // 8 + PB(2) + STR(3) = DC 13
      expect(g2024.dc, 13);
      expect(g2024.formulaDescription, contains('DC 13'));
    });

    test('2024 Weapon Mastery validation succeeds for eligible classes and matching property', () {
      const s2024 = Ruleset2024Strategy();

      const fighterChar = Character(
        id: EntityId(slug: 'f1', ruleset: RulesetVersion.v2024),
        name: 'Knight',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        rulesEdition: DmRulesEdition.v2024,
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
            level: 1,
            hitDie: 'd10',
          ),
        ]),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(currentHp: 10),
      );

      const greatsword = EquipmentItem(
        id: EntityId(slug: 'greatsword', ruleset: RulesetVersion.v2024),
        name: 'Greatsword',
        itemType: 'Martial Melee Weapon',
        rarity: 'Common',
        requiresAttunement: false,
        descriptionMarkdown: '2d6 slashing damage.',
        customProperties: {'mastery': 'graze'},
      );

      expect(s2024.canUseWeaponMastery(character: fighterChar, weapon: greatsword, mastery: WeaponMasteryProperty.graze), true);
      expect(s2024.canUseWeaponMastery(character: fighterChar, weapon: greatsword, mastery: WeaponMasteryProperty.topple), false);

      const wizardChar = Character(
        id: EntityId(slug: 'w1', ruleset: RulesetVersion.v2024),
        name: 'Mage',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        rulesEdition: DmRulesEdition.v2024,
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'wizard', displayName: 'Wizard'),
            level: 1,
            hitDie: 'd6',
          ),
        ]),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(currentHp: 6),
      );

      // Wizard does not have Weapon Mastery class feature
      expect(s2024.canUseWeaponMastery(character: wizardChar, weapon: greatsword, mastery: WeaponMasteryProperty.graze), false);
    });

    test('Dynamic Encumbrance calculates weight, capacities, and variant encumbrance speed penalties', () {
      const strategy = Ruleset2014Strategy();

      // STR 10: Carry Capacity = 150 lbs, Encumbered > 50 lbs, Heavily Encumbered > 100 lbs
      const inventory = [
        InventoryItemInstance(
          instanceId: 'armor_plate',
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'plate', displayName: 'Plate Armor'),
          quantity: 1,
          customProperties: {'weightLbs': 65.0},
        ),
      ];

      // Purse with 250 coins = 5.0 lbs
      final encumbrance = strategy.calculateEncumbrance(
        strengthScore: 10,
        inventory: inventory,
        totalCoinCount: 250,
      );

      expect(encumbrance.totalWeightLbs, 70.0); // 65 + 5
      expect(encumbrance.carryCapacityLbs, 150.0);
      expect(encumbrance.pushDragLiftLbs, 300.0);
      expect(encumbrance.variantTier, EncumbranceTier.encumbered);
      expect(encumbrance.speedPenaltyFeet, 10);
      expect(encumbrance.hasDisadvantageOnD20, false);
    });
  });

  group('Schema Hydration, State Immutability & Controller Persistence', () {
    test('Character serialization toMap and fromMap preserves rulesEdition and custom properties', () {
      const original = Character(
        id: EntityId(slug: 'schema_test_char', ruleset: RulesetVersion.v2024),
        name: 'Elminster',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        rulesEdition: DmRulesEdition.v2024,
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'wizard', displayName: 'Wizard'),
            level: 20,
            hitDie: 'd6',
          ),
        ]),
        baseScores: AbilityScores(intelligence: 20),
        resources: CharacterResourcePool(currentHp: 80),
      );

      final map = original.toMap();
      expect(map['rulesEdition'], 'v2024');

      final deserialized = Character.fromMap(map);
      expect(deserialized.rulesEdition, DmRulesEdition.v2024);
      expect(deserialized.name, 'Elminster');
      expect(deserialized.totalLevel, 20);
    });

    test('Legacy character map without rulesEdition defaults gracefully to v2014', () {
      final legacyMap = {
        'id': {'slug': 'old_char', 'ruleset': 'v2014'},
        'name': 'Old Hero',
        'speciesRef': {'slug': 'dwarf', 'refType': 'species', 'displayName': 'Dwarf'},
        'progression': {
          'classes': [
            {'classRef': {'slug': 'fighter', 'refType': 'classDefinition', 'displayName': 'Fighter'}, 'level': 1, 'hitDie': 'd10'}
          ]
        },
        'baseScores': {'strength': 15},
        'resources': {'currentHp': 12},
      };

      final character = Character.fromMap(legacyMap);
      expect(character.rulesEdition, DmRulesEdition.v2014);
      expect(character.name, 'Old Hero');
    });

    test('CharacterSheetController manages ruleset switching, HP modification, and debounced saving', () async {
      const char = Character(
        id: EntityId(slug: 'controller_test', ruleset: RulesetVersion.v2014),
        name: 'Grom',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'orc', displayName: 'Orc'),
        rulesEdition: DmRulesEdition.v2014,
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'barbarian', displayName: 'Barbarian'),
            level: 1,
            hitDie: 'd12',
          ),
        ]),
        baseScores: AbilityScores(constitution: 16),
        resources: CharacterResourcePool(currentHp: 15),
      );

      final debouncedStorage = DebouncedStorageService();
      final controller = CharacterSheetController(
        character: char,
        debouncedStorage: debouncedStorage,
      );

      expect(controller.rulesEdition, DmRulesEdition.v2014);
      expect(controller.stats.maxHp, 15);

      // Modify HP
      await controller.modifyHp(-5);
      expect(controller.character.resources.currentHp, 10);

      // Switch to 2024 rules
      await controller.setRulesEdition(DmRulesEdition.v2024);
      expect(controller.rulesEdition, DmRulesEdition.v2024);
      expect(controller.character.rulesEdition, DmRulesEdition.v2024);

      // Flush persistence
      await controller.flush();
    });
  });
}
