import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_stat_calculator.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Rod of the Pact Keeper & Magic Item Spell Bonus Tests', () {
    // Level 5 Warlock (Proficiency +3, Charisma 16 (+3))
    // Base Spell DC = 8 + 3 + 3 = 14
    // Base Spell Attack = 3 + 3 = +6
    Character createTestWarlock({
      bool equipRod = false,
      bool attuneRod = false,
      int rodBonus = 1,
    }) {
      final rodItem = InventoryItemInstance(
        instanceId: 'rod-$rodBonus-123',
        itemRef: EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'item-rod-of-the-pact-keeper-plus-$rodBonus',
          displayName: 'Rod of the Pact Keeper +$rodBonus',
        ),
        isEquipped: equipRod,
        isAttuned: attuneRod,
        requiresAttunement: true,
      );

      return Character(
        id: const EntityId(slug: 'warlock-hero', ruleset: RulesetVersion.v2014),
        name: 'Warlock Hero',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'tiefling', displayName: 'Tiefling'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              level: 5,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 8, dexterity: 14, constitution: 14, intelligence: 10, wisdom: 12, charisma: 16),
        inventory: [rodItem],
        resources: const CharacterResourcePool(),
      );
    }

    test('Base Warlock without Rod has DC 14 and Attack +6', () {
      final warlock = createTestWarlock(equipRod: false, attuneRod: false);
      final stats = CharacterEvaluationEngine.evaluate(warlock);

      expect(stats.spellSaveDcs['Warlock'], equals(14));
      expect(stats.spellAttackBonuses['Warlock'], equals(6));
    });

    test('Rod of the Pact Keeper +1 when equipped and attuned boosts DC to 15 and Attack to +7', () {
      final warlock = createTestWarlock(equipRod: true, attuneRod: true, rodBonus: 1);
      final stats = CharacterEvaluationEngine.evaluate(warlock);

      // 14 + 1 = 15 Save DC; 6 + 1 = 7 Spell Attack
      expect(stats.spellSaveDcs['Warlock'], equals(15));
      expect(stats.spellAttackBonuses['Warlock'], equals(7));

      // Also verify slug lookup
      expect(stats.spellSaveDcs['warlock'], equals(15));
      expect(stats.spellAttackBonuses['warlock'], equals(7));

      // Stat calculator consistency
      final repository = LayeredPriorityRepository();
      final resolver = ReferenceResolver(repository);
      final calcStats = CharacterStatCalculator.compute(warlock, resolver);
      expect(calcStats.spellSaveDcs['warlock'], equals(15));
      expect(calcStats.spellAttackBonuses['warlock'], equals(7));
    });

    test('Rod of the Pact Keeper +2 boosts DC to 16 and Attack to +8', () {
      final warlock = createTestWarlock(equipRod: true, attuneRod: true, rodBonus: 2);
      final stats = CharacterEvaluationEngine.evaluate(warlock);

      expect(stats.spellSaveDcs['Warlock'], equals(16));
      expect(stats.spellAttackBonuses['Warlock'], equals(8));
    });

    test('Rod of the Pact Keeper +3 boosts DC to 17 and Attack to +9', () {
      final warlock = createTestWarlock(equipRod: true, attuneRod: true, rodBonus: 3);
      final stats = CharacterEvaluationEngine.evaluate(warlock);

      expect(stats.spellSaveDcs['Warlock'], equals(17));
      expect(stats.spellAttackBonuses['Warlock'], equals(9));
    });

    test('Equipped but UNATTUNED Rod does NOT grant bonus', () {
      final warlock = createTestWarlock(equipRod: true, attuneRod: false, rodBonus: 2);
      final stats = CharacterEvaluationEngine.evaluate(warlock);

      expect(stats.spellSaveDcs['Warlock'], equals(14));
      expect(stats.spellAttackBonuses['Warlock'], equals(6));
    });
  });
}
