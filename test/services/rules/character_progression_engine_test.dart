import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_stat_calculator.dart';

void main() {
  group('CharacterProgressionEngine Unit Tests', () {
    late LayeredPriorityRepository repository;
    late ReferenceResolver resolver;

    setUp(() {
      repository = LayeredPriorityRepository();
      resolver = ReferenceResolver(repository);
    });

    test('Single-class progression (Fighter 1 -> 2 -> 3 Battle Master -> 4 ASI)', () {
      var fighter = const Character(
        id: EntityId(slug: 'warrior', ruleset: RulesetVersion.v2024),
        name: 'Warrior',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'fighter',
              displayName: 'Fighter',
            ),
            level: 1,
            hitDie: 'd10',
            hitPointsRolled: [],
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(
          strength: 16,
          dexterity: 14,
          constitution: 14, // +2 mod
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        resources: CharacterResourcePool(
          currentHp: 12, // 10 + 2 CON
          currentHitDice: {'d10': 1},
        ),
      );

      expect(fighter.totalLevel, equals(1));
      expect(fighter.proficiencyBonus, equals(2));

      // Level 2 (d10 avg is 6, +2 CON = +8 HP)
      fighter = CharacterProgressionEngine.applyLevelUp(
        fighter,
        const LevelUpRequest(
          targetClassSlug: 'fighter',
          hpChoice: HpProgressionChoice.average(),
        ),
        resolver: resolver,
      );

      expect(fighter.totalLevel, equals(2));
      expect(fighter.resources.currentHitDice['d10'], equals(2));
      var stats = CharacterStatCalculator.compute(fighter, resolver);
      // Level 1: 10 + 2 = 12. Level 2: 6 + 2 = 8 -> Total 20
      expect(stats.maxHp, equals(20));

      // Level 3 (Battle Master Subclass)
      fighter = CharacterProgressionEngine.applyLevelUp(
        fighter,
        const LevelUpRequest(
          targetClassSlug: 'fighter',
          hpChoice: HpProgressionChoice.average(),
          subclassRef: EntityReference(
            refType: EntityType.subclass,
            slug: 'battle_master',
            displayName: 'Battle Master',
          ),
        ),
        resolver: resolver,
      );

      expect(fighter.totalLevel, equals(3));
      expect(fighter.progression.classes.first.subclassRef?.slug, equals('battle_master'));
      stats = CharacterStatCalculator.compute(fighter, resolver);
      // Level 3: +8 HP -> Total 28
      expect(stats.maxHp, equals(28));

      // Level 4 (ASI +2 STR)
      fighter = CharacterProgressionEngine.applyLevelUp(
        fighter,
        const LevelUpRequest(
          targetClassSlug: 'fighter',
          hpChoice: HpProgressionChoice.average(),
          asiOrFeat: AsiOrFeatChoice.asi({AbilityType.strength: 2}),
        ),
        resolver: resolver,
      );

      expect(fighter.totalLevel, equals(4));
      expect(fighter.bonusScores.strength, equals(2));
      stats = CharacterStatCalculator.compute(fighter, resolver);
      expect(stats.effectiveScores.strength, equals(18));
      expect(stats.abilityModifiers[AbilityType.strength], equals(4));
      // Level 4: +8 HP -> Total 36
      expect(stats.maxHp, equals(36));
      expect(fighter.resources.currentHitDice['d10'], equals(4));
    });

    test('Retroactive CON HP recalculation when CON score increases at Level 4', () {
      // Wizard with base CON 12 (+1 mod)
      var wizard = const Character(
        id: EntityId(slug: 'mage', ruleset: RulesetVersion.v2024),
        name: 'Mage',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 1,
            hitDie: 'd6',
            hitPointsRolled: [],
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(
          strength: 8,
          dexterity: 14,
          constitution: 12, // +1 mod
          intelligence: 16,
          wisdom: 12,
          charisma: 10,
        ),
        resources: CharacterResourcePool(
          currentHp: 7, // 6 + 1 CON
          currentHitDice: {'d6': 1},
        ),
      );

      // Level 2 (d6 avg = 4 + 1 CON = +5 HP -> Total 12)
      wizard = CharacterProgressionEngine.applyLevelUp(
        wizard,
        const LevelUpRequest(
          targetClassSlug: 'wizard',
          hpChoice: HpProgressionChoice.average(),
        ),
        resolver: resolver,
      );
      expect(CharacterStatCalculator.compute(wizard, resolver).maxHp, equals(12));

      // Level 3 (d6 avg = 4 + 1 CON = +5 HP -> Total 17)
      wizard = CharacterProgressionEngine.applyLevelUp(
        wizard,
        const LevelUpRequest(
          targetClassSlug: 'wizard',
          hpChoice: HpProgressionChoice.average(),
        ),
        resolver: resolver,
      );
      expect(CharacterStatCalculator.compute(wizard, resolver).maxHp, equals(17));

      // Level 4: ASI +2 to CON (CON becomes 14 -> +2 mod)
      // HP calculation with retroactive CON:
      // Level 1: 6 + 2 = 8
      // Level 2: 4 + 2 = 6
      // Level 3: 4 + 2 = 6
      // Level 4: 4 + 2 = 6
      // Total Max HP = 8 + 6 + 6 + 6 = 26!
      wizard = CharacterProgressionEngine.applyLevelUp(
        wizard,
        const LevelUpRequest(
          targetClassSlug: 'wizard',
          hpChoice: HpProgressionChoice.average(),
          asiOrFeat: AsiOrFeatChoice.asi({AbilityType.constitution: 2}),
        ),
        resolver: resolver,
      );

      expect(wizard.bonusScores.constitution, equals(2));
      final stats = CharacterStatCalculator.compute(wizard, resolver);
      expect(stats.effectiveScores.constitution, equals(14));
      expect(stats.abilityModifiers[AbilityType.constitution], equals(2));
      expect(stats.maxHp, equals(26));
      expect(wizard.resources.currentHp, equals(26));
    });

    test('Multiclass Progression & Slot Pooling (Paladin 2 / Sorcerer 3)', () {
      // Paladin 2 base
      var paladin = const Character(
        id: EntityId(slug: 'gish', ruleset: RulesetVersion.v2024),
        name: 'Holy Sorcerer',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'paladin',
              displayName: 'Paladin',
            ),
            level: 2,
            hitDie: 'd10',
            hitPointsRolled: [6],
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(
          strength: 16,
          dexterity: 10,
          constitution: 14,
          intelligence: 10,
          wisdom: 10,
          charisma: 16,
        ),
        resources: CharacterResourcePool(
          currentHp: 20,
          currentHitDice: {'d10': 2},
        ),
      );

      // Multiclass into Sorcerer Level 1
      var gish = CharacterProgressionEngine.applyLevelUp(
        paladin,
        const LevelUpRequest(
          targetClassSlug: 'sorcerer',
          targetClassDisplayName: 'Sorcerer',
          targetClassHitDie: 'd6',
          isMulticlass: true,
          hpChoice: HpProgressionChoice.average(),
        ),
        resolver: resolver,
      );

      // Level 2 Sorcerer
      gish = CharacterProgressionEngine.applyLevelUp(
        gish,
        const LevelUpRequest(
          targetClassSlug: 'sorcerer',
          hpChoice: HpProgressionChoice.average(),
        ),
        resolver: resolver,
      );

      // Level 3 Sorcerer
      gish = CharacterProgressionEngine.applyLevelUp(
        gish,
        const LevelUpRequest(
          targetClassSlug: 'sorcerer',
          hpChoice: HpProgressionChoice.average(),
        ),
        resolver: resolver,
      );

      expect(gish.totalLevel, equals(5));
      expect(gish.resources.currentHitDice['d10'], equals(2));
      expect(gish.resources.currentHitDice['d6'], equals(3));

      // ECL = floor(Paladin 2 / 2 = 1) + Sorcerer 3 = 4
      final stats = CharacterStatCalculator.compute(gish, resolver);
      // Level 4 full caster slots: 4 1st-level, 3 2nd-level
      expect(stats.computedSpellSlots.maxSlots[1], equals(4));
      expect(stats.computedSpellSlots.maxSlots[2], equals(3));
    });

    test('Warlock Pact Magic slots are pooled correctly with standard slots', () {
      const warlockSorcerer = Character(
        id: EntityId(slug: 'coffelock', ruleset: RulesetVersion.v2024),
        name: 'Coffeelock',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'tiefling',
          displayName: 'Tiefling',
        ),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'sorcerer',
              displayName: 'Sorcerer',
            ),
            level: 3,
            hitDie: 'd6',
            isStartingClass: true,
          ),
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'warlock',
              displayName: 'Warlock',
            ),
            level: 2,
            hitDie: 'd8',
          ),
        ]),
        baseScores: AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 14,
          intelligence: 10,
          wisdom: 10,
          charisma: 16,
        ),
        resources: CharacterResourcePool(currentHp: 30),
      );

      final stats = CharacterStatCalculator.compute(warlockSorcerer, resolver);
      // Sorcerer 3 gives: 4 1st-level, 2 2nd-level standard slots
      expect(stats.computedSpellSlots.maxSlots[1], equals(4));
      expect(stats.computedSpellSlots.maxSlots[2], equals(2));
      // Warlock 2 gives: 2 1st-level separate Pact Magic slots
      expect(stats.computedSpellSlots.pactMagicSlotLevel, equals(1));
      expect(stats.computedSpellSlots.pactMagicMax, equals(2));
    });

    test('ASI milestones detected for Fighter (levels 4, 6, 8, 12, 14, 16, 19) and Rogue (10)', () {
      expect(CharacterProgressionEngine.isAsiMilestone('fighter', 4), isTrue);
      expect(CharacterProgressionEngine.isAsiMilestone('fighter', 6), isTrue);
      expect(CharacterProgressionEngine.isAsiMilestone('fighter', 14), isTrue);
      expect(CharacterProgressionEngine.isAsiMilestone('wizard', 6), isFalse);

      expect(CharacterProgressionEngine.isAsiMilestone('rogue', 10), isTrue);
      expect(CharacterProgressionEngine.isAsiMilestone('cleric', 10), isFalse);
    });

    test('Multiclass validation rejects if attribute score is below 13', () {
      const weakMage = Character(
        id: EntityId(slug: 'weak_mage', ruleset: RulesetVersion.v2024),
        name: 'Weak Mage',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 2,
            hitDie: 'd6',
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(
          strength: 8,
          dexterity: 12,
          constitution: 12,
          intelligence: 16,
          wisdom: 10,
          charisma: 10,
        ),
        resources: CharacterResourcePool(currentHp: 12),
      );

      // Barbarian requires STR 13
      final barbValidation = CharacterProgressionEngine.validateMulticlass(weakMage, 'barbarian');
      expect(barbValidation.isValid, isFalse);

      // Paladin requires STR 13 & CHA 13
      final paladinValidation = CharacterProgressionEngine.validateMulticlass(weakMage, 'paladin');
      expect(paladinValidation.isValid, isFalse);

      // Rogue requires DEX 13 (current DEX 12)
      final rogueValidation = CharacterProgressionEngine.validateMulticlass(weakMage, 'rogue');
      expect(rogueValidation.isValid, isFalse);
    });

    test('Level 1 Character creation populates starting spell slots for spellcasters', () {
      const wizardCreation = CharacterCreationRequest(
        characterName: 'Elminster',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        startingClassSlug: 'wizard',
        startingClassDisplayName: 'Wizard',
        startingClassHitDie: 'd6',
        baseScores: AbilityScores(strength: 8, dexterity: 14, constitution: 14, intelligence: 16, wisdom: 12, charisma: 10),
        bonusScores: AbilityScores(),
        cantrips: [
          EntityReference(refType: EntityType.spell, slug: 'fire_bolt', displayName: 'Fire Bolt'),
          EntityReference(refType: EntityType.spell, slug: 'mage_hand', displayName: 'Mage Hand'),
        ],
        spellsKnown: [
          EntityReference(refType: EntityType.spell, slug: 'magic_missile', displayName: 'Magic Missile'),
          EntityReference(refType: EntityType.spell, slug: 'shield', displayName: 'Shield'),
        ],
        spellsPrepared: [
          EntityReference(refType: EntityType.spell, slug: 'magic_missile', displayName: 'Magic Missile'),
          EntityReference(refType: EntityType.spell, slug: 'shield', displayName: 'Shield'),
        ],
      );

      final wizard = CharacterFactory.createLevel1Character(wizardCreation);
      expect(wizard.cantrips.length, equals(2));
      expect(wizard.spellsKnown.length, equals(2));
      expect(wizard.spellsPrepared.length, equals(2));
      // Full caster Level 1 has 2 Level-1 spell slots
      expect(wizard.resources.spellSlots.maxSlots[1], equals(2));
      expect(wizard.resources.spellSlots.currentSlots[1], equals(2));

      // Level up to Level 3 (gains 2nd level slots: 4 Level-1, 2 Level-2)
      final leveledWizard = CharacterProgressionEngine.applyLevelUp(
        wizard,
        const LevelUpRequest(
          targetClassSlug: 'wizard',
          newSpells: [
            EntityReference(refType: EntityType.spell, slug: 'misty_step', displayName: 'Misty Step'),
            EntityReference(refType: EntityType.spell, slug: 'scorching_ray', displayName: 'Scorching Ray'),
          ],
        ),
      );

      final level3Wizard = CharacterProgressionEngine.applyLevelUp(
        leveledWizard,
        const LevelUpRequest(targetClassSlug: 'wizard'),
      );

      expect(level3Wizard.totalLevel, equals(3));
      expect(level3Wizard.spellsKnown.length, equals(4));
      expect(level3Wizard.spellsPrepared.length, equals(4));
      expect(level3Wizard.resources.spellSlots.maxSlots[1], equals(4));
      expect(level3Wizard.resources.spellSlots.maxSlots[2], equals(2));
    });

    test('applyLevelUp merges newToolProficiencies and newLanguages without duplicates', () {
      const initialCharacter = Character(
        id: EntityId(slug: 'rogue-hero', ruleset: RulesetVersion.v2024),
        name: 'Shadow',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        languages: ['Common', 'Elvish'],
        toolProficiencies: ["Thieves' Tools"],
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'rogue',
              displayName: 'Rogue',
            ),
            level: 2,
            hitDie: 'd8',
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(dexterity: 16),
        resources: CharacterResourcePool(currentHp: 16),
      );

      final leveled = CharacterProgressionEngine.applyLevelUp(
        initialCharacter,
        const LevelUpRequest(
          targetClassSlug: 'rogue',
          newToolProficiencies: ["Poisoner's Kit", "Disguise Kit", "Thieves' Tools"],
          newLanguages: ['Thieves\' Cant', 'elvish', 'Undercommon'],
        ),
      );

      expect(leveled.totalLevel, equals(3));
      expect(leveled.toolProficiencies, equals([
        "Thieves' Tools",
        "Poisoner's Kit",
        "Disguise Kit",
      ]));
      expect(leveled.languages, equals([
        'Common',
        'Elvish',
        "Thieves' Cant",
        'Undercommon',
      ]));
    });
  });
}
