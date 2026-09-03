import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_stat_calculator.dart';

void main() {
  group('FeatAsiExtension Tests', () {
    test('Resilient feat has all 6 abilities, requires choice, and grants saving throw', () {
      const resilient = SrdFeatsLibrary.resilient;
      expect(resilient.hasAbilityScoreIncrease, isTrue);
      expect(resilient.requiresAbilityChoice, isTrue);
      expect(resilient.selectableAbilities.length, equals(6));
      expect(resilient.selectableAbilities, containsAll(AbilityType.values));
      expect(resilient.statIncreaseAmount, equals(1));
      expect(resilient.grantsSavingThrowProficiency, isTrue);
      expect(resilient.choiceRiderDescription, contains('saving throw'));
    });

    test('Athlete feat allows STR or DEX choice and does not grant saving throw', () {
      const athlete = SrdFeatsLibrary.athlete;
      expect(athlete.hasAbilityScoreIncrease, isTrue);
      expect(athlete.requiresAbilityChoice, isTrue);
      expect(athlete.selectableAbilities, equals([AbilityType.strength, AbilityType.dexterity]));
      expect(athlete.statIncreaseAmount, equals(1));
      expect(athlete.grantsSavingThrowProficiency, isFalse);
    });

    test('Observant feat allows INT or WIS choice', () {
      const observant = SrdFeatsLibrary.observant;
      expect(observant.hasAbilityScoreIncrease, isTrue);
      expect(observant.requiresAbilityChoice, isTrue);
      expect(observant.selectableAbilities, equals([AbilityType.intelligence, AbilityType.wisdom]));
      expect(observant.statIncreaseAmount, equals(1));
    });

    test('Actor feat has fixed single ability (CHA)', () {
      const actor = SrdFeatsLibrary.actor;
      expect(actor.hasAbilityScoreIncrease, isTrue);
      expect(actor.requiresAbilityChoice, isFalse);
      expect(actor.selectableAbilities, equals([AbilityType.charisma]));
      expect(actor.statIncreaseAmount, equals(1));
    });

    test('Heavy Armor Master has fixed single ability (STR)', () {
      const ham = SrdFeatsLibrary.heavyArmorMaster;
      expect(ham.hasAbilityScoreIncrease, isTrue);
      expect(ham.requiresAbilityChoice, isFalse);
      expect(ham.selectableAbilities, equals([AbilityType.strength]));
      expect(ham.statIncreaseAmount, equals(1));
    });

    test('Custom Homebrew Feat with dynamic customProperties works seamlessly', () {
      const customFeat = Feat(
        id: EntityId(slug: 'mind-over-matter', ruleset: RulesetVersion.v2024),
        name: 'Mind Over Matter',
        descriptionMarkdown: 'Increase INT or CON by 1 and gain saving throw proficiency.',
        customProperties: {
          'selectableAbilities': ['intelligence', 'constitution'],
          'statIncrease': 1,
          'grantsSavingThrowProficiency': true,
          'riderDescription': 'Grants saving throw proficiency in chosen stat.',
        },
      );

      expect(customFeat.hasAbilityScoreIncrease, isTrue);
      expect(customFeat.requiresAbilityChoice, isTrue);
      expect(customFeat.selectableAbilities, equals([AbilityType.intelligence, AbilityType.constitution]));
      expect(customFeat.statIncreaseAmount, equals(1));
      expect(customFeat.grantsSavingThrowProficiency, isTrue);
      expect(customFeat.choiceRiderDescription, contains('saving throw'));
    });
  });

  group('CharacterProgressionEngine with Feat ASIs & Riders', () {
    late LayeredPriorityRepository repository;
    late ReferenceResolver resolver;

    setUp(() {
      repository = LayeredPriorityRepository();
      resolver = ReferenceResolver(repository);
    });

    Character createBaseRogueLevel3() {
      return const Character(
        id: EntityId(slug: 'shadow-rogue', ruleset: RulesetVersion.v2024),
        name: 'Shadow',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        baseScores: AbilityScores(
          strength: 10,
          dexterity: 15,
          constitution: 13, // +1 modifier
          intelligence: 12,
          wisdom: 14,
          charisma: 8,
        ),
        bonusScores: AbilityScores(
          strength: 0,
          dexterity: 0,
          constitution: 0,
          intelligence: 0,
          wisdom: 0,
          charisma: 0,
        ),
        savingThrowProficiencies: {
          AbilityType.dexterity,
          AbilityType.intelligence,
        },
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'rogue',
                displayName: 'Rogue',
              ),
              level: 3,
              hitDie: 'd8',
              hitPointsRolled: [5, 5],
              isStartingClass: true,
            ),
          ],
          manualHpRolls: {1: 8, 2: 5, 3: 5},
        ),
        resources: CharacterResourcePool(
          currentHp: 21, // 8+1 + 5+1 + 5+1 = 21
          tempHp: 0,
          currentHitDice: {'d8': 3},
        ),
      );
    }

    test('Level 4: Taking Resilient (Constitution) increases CON, grants save, and retroactively updates HP', () {
      final rogue = createBaseRogueLevel3();
      expect(rogue.savingThrowProficiencies, isNot(contains(AbilityType.constitution)));

      const levelUpReq = LevelUpRequest(
        targetClassSlug: 'rogue',
        hpChoice: HpProgressionChoice.average(), // 5 for d8
        asiOrFeat: AsiOrFeatChoice.feat(
          EntityReference(
            refType: EntityType.feat,
            slug: 'resilient',
            displayName: 'Resilient',
          ),
          abilityIncreases: {AbilityType.constitution: 1},
          savingThrowGrants: {AbilityType.constitution},
          chosenFeatAbility: AbilityType.constitution,
        ),
      );

      final leveled = CharacterProgressionEngine.applyLevelUp(rogue, levelUpReq, resolver: resolver);

      expect(leveled.totalLevel, equals(4));
      // CON bonus increased from 0 to 1
      expect(leveled.bonusScores.constitution, equals(1));
      // Saving throws now include Constitution!
      expect(leveled.savingThrowProficiencies, contains(AbilityType.constitution));
      expect(leveled.savingThrowProficiencies, contains(AbilityType.dexterity));
      expect(leveled.savingThrowProficiencies, contains(AbilityType.intelligence));

      final stats = CharacterStatCalculator.compute(leveled, resolver);
      // Base CON 13 + 1 = 14 (+2 mod)
      expect(stats.effectiveScores.constitution, equals(14));
      expect(stats.abilityModifiers[AbilityType.constitution], equals(2));

      // Proficiency bonus at level 4 is +2
      expect(stats.proficiencyBonus, equals(2));
      // Saving throw for CON: +2 mod + 2 prof = +4!
      expect(stats.savingThrowModifiers[AbilityType.constitution], equals(4));

      // HP check:
      // Level 1: 8 + 2 = 10
      // Level 2: 5 + 2 = 7
      // Level 3: 5 + 2 = 7
      // Level 4: 5 + 2 = 7
      // Total HP = 10 + 7 + 7 + 7 = 31 (retroactive CON boost applied!)
      expect(stats.maxHp, equals(31));
      expect(leveled.resources.currentHp, equals(31));
    });

    test('Level 4: Taking Athlete (Dexterity) increases DEX by 1 without granting saving throws', () {
      final rogue = createBaseRogueLevel3();

      const levelUpReq = LevelUpRequest(
        targetClassSlug: 'rogue',
        hpChoice: HpProgressionChoice.average(),
        asiOrFeat: AsiOrFeatChoice.feat(
          EntityReference(
            refType: EntityType.feat,
            slug: 'athlete',
            displayName: 'Athlete',
          ),
          abilityIncreases: {AbilityType.dexterity: 1},
          chosenFeatAbility: AbilityType.dexterity,
        ),
      );

      final leveled = CharacterProgressionEngine.applyLevelUp(rogue, levelUpReq, resolver: resolver);

      expect(leveled.bonusScores.dexterity, equals(1));
      final stats = CharacterStatCalculator.compute(leveled, resolver);
      // Base DEX 15 + 1 = 16 (+3 mod)
      expect(stats.effectiveScores.dexterity, equals(16));
      expect(stats.abilityModifiers[AbilityType.dexterity], equals(3));
      // CON saving throw was not granted
      expect(leveled.savingThrowProficiencies, isNot(contains(AbilityType.constitution)));
    });

    test('Level 4: Taking custom homebrew feat with skill and saving throw grants', () {
      final rogue = createBaseRogueLevel3();

      const levelUpReq = LevelUpRequest(
        targetClassSlug: 'rogue',
        hpChoice: HpProgressionChoice.average(),
        asiOrFeat: AsiOrFeatChoice.feat(
          EntityReference(
            refType: EntityType.feat,
            slug: 'mystic-initiate',
            displayName: 'Mystic Initiate',
          ),
          abilityIncreases: {AbilityType.wisdom: 1},
          savingThrowGrants: {AbilityType.wisdom},
          skillGrants: {SkillType.arcana},
          chosenFeatAbility: AbilityType.wisdom,
        ),
      );

      final leveled = CharacterProgressionEngine.applyLevelUp(rogue, levelUpReq, resolver: resolver);

      expect(leveled.bonusScores.wisdom, equals(1));
      expect(leveled.savingThrowProficiencies, contains(AbilityType.wisdom));
      expect(leveled.skillProficiencies[SkillType.arcana], equals(SkillProficiencyLevel.proficient));
    });
  });
}
