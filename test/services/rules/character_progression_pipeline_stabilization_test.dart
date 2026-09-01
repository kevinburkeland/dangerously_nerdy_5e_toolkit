import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/spell_allocation_validator.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/spellcasting_rules_engine.dart';

void main() {
  group('Character Builder & Progression Pipeline Stabilization Tests', () {
    // Helper to create a base Barbarian character
    Character createBarbarian({
      int baseStr = 15,
      int baseDex = 14,
      int baseCon = 14,
      int baseInt = 8,
      int baseWis = 10,
      int baseCha = 8,
      List<InventoryItemInstance> inventory = const [],
      Map<String, dynamic> customProperties = const {},
      DmRulesEdition edition = DmRulesEdition.v2014,
    }) {
      return Character(
        id: const EntityId(slug: 'barbarian-hero', ruleset: RulesetVersion.v2014),
        name: 'Conan',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'barbarian',
                displayName: 'Barbarian',
              ),
              level: 4,
              hitDie: 'd12',
              hitPointsRolled: [7, 7, 7],
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
          strength: baseStr,
          dexterity: baseDex,
          constitution: baseCon,
          intelligence: baseInt,
          wisdom: baseWis,
          charisma: baseCha,
        ),
        resources: const CharacterResourcePool(
          currentHp: 45,
        ),
        inventory: inventory,
        customProperties: customProperties,
        rulesEdition: edition,
      );
    }

    test('Phase 1: Magic items (Headband of Intellect) affect effective scores but NOT multiclassing prerequisites', () {
      const headbandItem = InventoryItemInstance(
        instanceId: 'item-headband-1',
        itemRef: EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'headband-of-intellect',
          displayName: 'Headband of Intellect',
        ),
        isEquipped: true,
        isAttuned: true,
        requiresAttunement: true,
        customProperties: {
          'abilityOverrides': {
            'intelligence': 19,
          },
        },
      );

      final barbarian = createBarbarian(
        baseInt: 8,
        inventory: const [headbandItem],
      );

      // Raw INT should remain 8, but Effective INT becomes 19
      expect(barbarian.rawAbilityScores.intelligence, equals(8));
      expect(barbarian.effectiveAbilityScores.intelligence, equals(19));

      // Attempting to multiclass into Wizard (which requires INT 13+)
      final validation = CharacterProgressionEngine.validateMulticlass(barbarian, 'wizard');
      expect(validation.isValid, isFalse);
      expect(validation.errors.any((e) => e.contains('wizard') && e.contains('attribute prerequisite')), isTrue);
    });

    test('Phase 2: Origin-keyed spell allocations track grants and detect orphan spells', () {
      const cantripRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'fire-bolt',
        displayName: 'Fire Bolt',
      );
      const wizardCantripRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'mage-hand',
        displayName: 'Mage Hand',
      );

      const character = Character(
        id: EntityId(slug: 'elf-wizard', ruleset: RulesetVersion.v2014),
        name: 'Elrond',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'high-elf',
          displayName: 'High Elf',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'wizard',
                displayName: 'Wizard',
              ),
              level: 1,
              hitDie: 'd6',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(),
        allocatedSpells: {
          'high-elf-cantrip': [cantripRef],
          'class-wizard-cantrips': [wizardCantripRef],
        },
      );

      // Backwards-compatible getters work
      expect(character.cantrips, contains(cantripRef));
      expect(character.cantrips, contains(wizardCantripRef));

      // Active grants matching
      final activeGrants = [
        FeatureGrant.bonusCantrips(
          count: 1,
          grantId: 'high-elf-cantrip',
          label: 'High Elf Cantrip',
        ),
      ];

      final validation = SpellAllocationValidator.validateSpellAllocations(character, activeGrants);
      expect(validation.isValid, isTrue);

      // If species changes and high-elf-cantrip is removed from active grants
      final invalidValidation = SpellAllocationValidator.validateSpellAllocations(character, []);
      expect(invalidValidation.isValid, isFalse);
      expect(invalidValidation.errors.any((e) => e.contains('Orphan spell allocation key "high-elf-cantrip"')), isTrue);
    });

    test('Phase 3: Historical ledger (manualHpRolls) preserves exact rolls across character modifications', () {
      var char = const Character(
        id: EntityId(slug: 'fighter-hero', ruleset: RulesetVersion.v2014),
        name: 'Arthur',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 1,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
          manualHpRolls: {1: 10},
        ),
        baseScores: AbilityScores(constitution: 14), // +2 CON
        resources: CharacterResourcePool(currentHp: 12),
      );

      // Level up to Level 2 with manual roll 9
      char = CharacterProgressionEngine.applyLevelUp(
        char,
        const LevelUpRequest(
          targetClassSlug: 'fighter',
          hpChoice: HpProgressionChoice.rolled(9),
        ),
      );

      // Level up to Level 3 with manual roll 4
      char = CharacterProgressionEngine.applyLevelUp(
        char,
        const LevelUpRequest(
          targetClassSlug: 'fighter',
          hpChoice: HpProgressionChoice.rolled(4),
        ),
      );

      expect(char.progression.manualHpRolls[1], equals(10));
      expect(char.progression.manualHpRolls[2], equals(9));
      expect(char.progression.manualHpRolls[3], equals(4));

      // Max HP: (10 + 2) + (9 + 2) + (4 + 2) = 12 + 11 + 6 = 29
      expect(char.resources.currentHp, equals(29));
    });

    test('Phase 4: Ruleset-aware spell slot math rounds half-casters differently in 2014 vs 2024 and isolates Warlock', () {
      // 1 Paladin / 1 Sorcerer in 2014 vs 2024
      const multiclassChar2014 = Character(
        id: EntityId(slug: 'palsorc-2014', ruleset: RulesetVersion.v2014),
        name: 'Gish 2014',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'paladin',
                displayName: 'Paladin',
              ),
              level: 1,
              hitDie: 'd10',
              isStartingClass: true,
            ),
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'sorcerer',
                displayName: 'Sorcerer',
              ),
              level: 1,
              hitDie: 'd6',
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2014,
      );

      final slots2014 = MulticlassSlotMatrix.calculateSpellSlots(multiclassChar2014);
      // 2014: Full (1) + Paladin (1 ~/ 2 = 0) = ECL 1 -> [2 Level 1 slots]
      expect(slots2014.maxSlots[1], equals(2));
      expect(slots2014.maxSlots[2], isNull);

      final multiclassChar2024 = multiclassChar2014.copyWith(rulesEdition: DmRulesEdition.v2024);
      final slots2024 = MulticlassSlotMatrix.calculateSpellSlots(multiclassChar2024);
      // 2024: Full (1) + Paladin ((1 + 1) ~/ 2 = 1) = ECL 2 -> [3 Level 1 slots]
      expect(slots2024.maxSlots[1], equals(3));

      // With Warlock 2 added:
      final withWarlock = multiclassChar2024.copyWith(
        progression: CharacterProgression(
          classes: [
            ...multiclassChar2024.progression.classes,
            const ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 2,
              hitDie: 'd8',
            ),
          ],
        ),
      );

      final slotsWithWarlock = MulticlassSlotMatrix.calculateSpellSlots(withWarlock);
      // ECL remains 2 for standard slots
      expect(slotsWithWarlock.maxSlots[1], equals(3));
      // Pact Magic is isolated: 2 slots of Level 1
      expect(slotsWithWarlock.pactMagicMax, equals(2));
      expect(slotsWithWarlock.pactMagicSlotLevel, equals(1));
    });

    test('Phase 5: Deep immutability enforces unmodifiable collections and value equality', () {
      const initialChar = Character(
        id: EntityId(slug: 'hero-1', ruleset: RulesetVersion.v2014),
        name: 'Hero',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'rogue',
                displayName: 'Rogue',
              ),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(),
        inventory: [
          InventoryItemInstance(
            instanceId: 'item-dagger',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'dagger',
              displayName: 'Dagger',
            ),
          ),
        ],
      );

      final updatedChar = initialChar.copyWith(
        languages: ['Common', 'Elvish'],
      );

      // Attempting to mutate updated collections must throw UnsupportedError
      expect(() => (updatedChar.languages as dynamic).add('Draconic'), throwsA(isA<UnsupportedError>()));
      expect(() => (updatedChar.inventory as dynamic).add(
        const InventoryItemInstance(
          instanceId: 'item-2',
          itemRef: EntityReference<EquipmentItem>(
            refType: EntityType.equipment,
            slug: 'shortsword',
            displayName: 'Shortsword',
          ),
        ),
      ), throwsA(isA<UnsupportedError>()));

      // Value Equality check
      final clonedChar = updatedChar.copyWith();
      expect(clonedChar == updatedChar, isTrue);
      expect(clonedChar.hashCode, equals(updatedChar.hashCode));
    });
  });
}
