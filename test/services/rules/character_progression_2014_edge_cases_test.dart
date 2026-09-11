import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_stat_calculator.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/spellcasting_rules_engine.dart';

void main() {
  group('2014 Rules Character Lifecycle & Level Up Edge Cases', () {
    test('Subclass selection triggers at Level 2 for Wizard/Druid and Level 1 for Cleric in 2014', () {
      final wizardClass2014 = SrdClassesLibrary.findBySlug('wizard', ruleset: RulesetVersion.v2014);
      final druidClass2014 = SrdClassesLibrary.findBySlug('druid', ruleset: RulesetVersion.v2014);
      final clericClass2014 = SrdClassesLibrary.findBySlug('cleric', ruleset: RulesetVersion.v2014);
      final fighterClass2014 = SrdClassesLibrary.findBySlug('fighter', ruleset: RulesetVersion.v2014);

      // Wizard & Druid at Level 2 in 2014
      expect(
        CharacterProgressionEngine.isSubclassMilestone(
          'wizard',
          2,
          ruleset: RulesetVersion.v2014,
          characterClass: wizardClass2014,
        ),
        isTrue,
      );
      expect(
        CharacterProgressionEngine.isSubclassMilestone(
          'druid',
          2,
          ruleset: RulesetVersion.v2014,
          characterClass: druidClass2014,
        ),
        isTrue,
      );

      // Cleric at Level 1 in 2014
      expect(
        CharacterProgressionEngine.isSubclassMilestone(
          'cleric',
          1,
          ruleset: RulesetVersion.v2014,
          characterClass: clericClass2014,
        ),
        isTrue,
      );

      // Fighter at Level 3 in 2014
      expect(
        CharacterProgressionEngine.isSubclassMilestone(
          'fighter',
          2,
          ruleset: RulesetVersion.v2014,
          characterClass: fighterClass2014,
        ),
        isFalse,
      );
      expect(
        CharacterProgressionEngine.isSubclassMilestone(
          'fighter',
          3,
          ruleset: RulesetVersion.v2014,
          characterClass: fighterClass2014,
        ),
        isTrue,
      );

      // In 2024, all subclasses standardize to Level 3
      expect(
        CharacterProgressionEngine.isSubclassMilestone(
          'wizard',
          2,
          ruleset: RulesetVersion.v2024,
          characterClass: SrdClassesLibrary.findBySlug('wizard', ruleset: RulesetVersion.v2024),
        ),
        isFalse,
      );
    });

    test('Single-class half-caster (Paladin/Ranger) 2014 spell slot tables grant Level 2 slots at class level 5', () {
      const paladinChar = Character(
        id: EntityId(slug: 'holy-warrior', ruleset: RulesetVersion.v2014),
        name: 'Holy Warrior',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'paladin', displayName: 'Paladin'),
              level: 5,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2014,
      );

      final slots = MulticlassSlotMatrix.calculateSpellSlots(paladinChar);

      // Level 5 Paladin in 2014 RAW has 4 1st-level slots and 2 2nd-level slots
      expect(slots.maxSlots[1], equals(4));
      expect(slots.maxSlots[2], equals(2));
      expect(slots.maxSlots[3], isNull);
    });

    test('Single-class 1/3-caster (Eldritch Knight) grants 3 1st slots at L4 and 2nd slots at L7', () {
      const ekCharLevel4 = Character(
        id: EntityId(slug: 'arcane-fighter', ruleset: RulesetVersion.v2014),
        name: 'Arcane Fighter',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'eldritch_knight', displayName: 'Eldritch Knight'),
              level: 4,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2014,
      );

      final slotsL4 = MulticlassSlotMatrix.calculateSpellSlots(ekCharLevel4);
      expect(slotsL4.maxSlots[1], equals(3));
      expect(slotsL4.maxSlots[2], isNull);

      final ekCharLevel7 = ekCharLevel4.copyWith(
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'eldritch_knight', displayName: 'Eldritch Knight'),
              level: 7,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
      );

      final slotsL7 = MulticlassSlotMatrix.calculateSpellSlots(ekCharLevel7);
      expect(slotsL7.maxSlots[1], equals(4));
      expect(slotsL7.maxSlots[2], equals(2));
    });

    test('HP calculation accounts for Draconic Bloodline Sorcerer and Hill Dwarf bonuses', () {
      final repo = LayeredPriorityRepository();
      final resolver = ReferenceResolver(repo);

      // Hill Dwarf Draconic Sorcerer Level 5
      const character = Character(
        id: EntityId(slug: 'dwarf-sorcerer', ruleset: RulesetVersion.v2014),
        name: 'Dwarf Sorcerer',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'hill-dwarf', displayName: 'Hill Dwarf'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'sorcerer', displayName: 'Sorcerer'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'draconic_bloodline', displayName: 'Draconic Bloodline'),
              level: 5,
              hitDie: 'd6',
              hitPointsRolled: [4, 4, 4, 4], // L1 is 6, L2-5 are 4
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(constitution: 14), // +2 CON mod
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2014,
      );

      final stats = CharacterStatCalculator.compute(character, resolver);
      // Expected HP:
      // Level 1: 6 (d6 max) + 2 (CON) + 1 (Hill Dwarf) = 9
      // Level 2-5: 4 * (4 + 2 + 1) = 28
      // Draconic Resilience (+1 HP per sorcerer level): 5
      // Total = 9 + 28 + 5 = 42
      expect(stats.maxHp, equals(42));
    });

    test('ASI clamps inherent score to getAbilityScoreMaximum while preserving item overrides', () {
      // Character with base 19 Strength and a generic magical item setting effective Strength to 21
      const character = Character(
        id: EntityId(slug: 'mighty-hero', ruleset: RulesetVersion.v2014),
        name: 'Mighty Hero',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 19),
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2014,
        customProperties: {
          'abilityOverrides': {'strength': 21}, // e.g. generic magical belt
        },
      );

      expect(character.getAbilityScoreMaximum(AbilityType.strength), equals(20));
      expect(character.rawAbilityScores.strength, equals(19));
      expect(character.effectiveAbilityScores.strength, equals(21));

      // Level up to Level 4 with +2 Strength ASI
      final updated = CharacterProgressionEngine.applyLevelUp(
        character,
        const LevelUpRequest(
          targetClassSlug: 'fighter',
          asiOrFeat: AsiOrFeatChoice.asi({AbilityType.strength: 2}),
        ),
      );

      // Inherent raw Strength must clamp to 20 (not 21)
      expect(updated.rawAbilityScores.strength, equals(20));
      // Effective score remains at least 21 due to item override
      expect(updated.effectiveAbilityScores.strength, equals(21));
    });

    test('Inherent ability score maximum dynamically expands for Level 20 Barbarian capstone and custom treatises', () {
      const barbarian20 = Character(
        id: EntityId(slug: 'primal-warrior', ruleset: RulesetVersion.v2014),
        name: 'Primal Warrior',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'barbarian', displayName: 'Barbarian'),
              level: 20,
              hitDie: 'd12',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 20, constitution: 20),
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2014,
      );

      // Barbarian capstone raises inherent max to 24 for STR and CON
      expect(barbarian20.getAbilityScoreMaximum(AbilityType.strength), equals(24));
      expect(barbarian20.getAbilityScoreMaximum(AbilityType.constitution), equals(24));
      expect(barbarian20.getAbilityScoreMaximum(AbilityType.dexterity), equals(20));

      // Adding custom inherent treatises (e.g. Homebrew Treatise of Clear Thought: INT max 22)
      final withTreatise = barbarian20.copyWith(
        customProperties: {
          'abilityMaximums': {'intelligence': 22},
        },
      );
      expect(withTreatise.getAbilityScoreMaximum(AbilityType.intelligence), equals(22));
    });

    test('Unarmored Defense multiclass precedence respects class acquisition order', () {
      final repo = LayeredPriorityRepository();
      final resolver = ReferenceResolver(repo);

      // Started as Monk 1, multiclassed into Barbarian 1
      const monkFirst = Character(
        id: EntityId(slug: 'monk-barb', ruleset: RulesetVersion.v2014),
        name: 'Monk Barbarian',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'monk', displayName: 'Monk'),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'barbarian', displayName: 'Barbarian'),
              level: 1,
              hitDie: 'd12',
              isStartingClass: false,
            ),
          ],
        ),
        baseScores: AbilityScores(
          dexterity: 14, // +2
          constitution: 16, // +3
          wisdom: 12, // +1
        ),
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2014,
      );

      // Monk was first -> retains Monk Unarmored Defense: 10 + DEX (2) + WIS (1) = 13
      // Barbarian defense (10 + 2 + 3 = 15) is not gained per 2014 RAW PHB p. 164
      final statsMonk = CharacterStatCalculator.compute(monkFirst, resolver);
      expect(statsMonk.armorClass, equals(13));
      expect(statsMonk.armorClassBreakdown, contains('WIS Monk'));

      // Started as Barbarian 1, multiclassed into Monk 1
      final barbFirst = monkFirst.copyWith(
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'barbarian', displayName: 'Barbarian'),
              level: 1,
              hitDie: 'd12',
              isStartingClass: true,
            ),
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'monk', displayName: 'Monk'),
              level: 1,
              hitDie: 'd8',
              isStartingClass: false,
            ),
          ],
        ),
      );

      // Barbarian was first -> retains Barbarian Unarmored Defense: 10 + DEX (2) + CON (3) = 15
      final statsBarb = CharacterStatCalculator.compute(barbFirst, resolver);
      expect(statsBarb.armorClass, equals(15));
      expect(statsBarb.armorClassBreakdown, contains('CON Barbarian'));
    });
  });
}
