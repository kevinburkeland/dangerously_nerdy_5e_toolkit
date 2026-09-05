import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

class _FakePersistenceService implements CharacterPersistenceService {
  Character? savedCharacter;

  @override
  Future<List<Character>> saveCharacter(Character character) async {
    savedCharacter = character;
    return [character];
  }

  @override
  Future<List<Character>> loadCharacters() async => savedCharacter != null ? [savedCharacter!] : [];

  @override
  Future<String?> loadActiveCharacterId() async => savedCharacter?.id.slug;

  @override
  Future<void> saveActiveCharacterId(String slug) async {}

  @override
  Future<void> saveRoster(List<Character> roster) async {}

  @override
  Future<List<Character>> deleteCharacter(String slug) async => [];
}

void main() {
  late Character testCharacter;
  late _FakePersistenceService fakePersistence;
  late CharacterSheetController controller;

  setUp(() {
    testCharacter = const Character(
      id: EntityId(slug: 'hero-test', ruleset: RulesetVersion.v2024),
      name: 'Valeros',
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
            level: 4,
            hitDie: 'd10',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: AbilityScores(
        strength: 16,
        dexterity: 14,
        constitution: 14,
        intelligence: 10,
        wisdom: 12,
        charisma: 8,
      ),
      resources: CharacterResourcePool(
        currentHp: 10,
        tempHp: 4,
        currentHitDice: {'d10': 1},
        deathSaveSuccesses: 2,
        deathSaveFailures: 1,
        exhaustionLevel: 2,
      ),
      inventory: [
        InventoryItemInstance(
          instanceId: 'item-1',
          itemRef: EntityReference<EquipmentItem>(
            refType: EntityType.equipment,
            slug: 'ring-of-protection',
            displayName: 'Ring of Protection',
          ),
          requiresAttunement: true,
          isAttuned: true,
        ),
        InventoryItemInstance(
          instanceId: 'item-2',
          itemRef: EntityReference<EquipmentItem>(
            refType: EntityType.equipment,
            slug: 'cloak-of-elvenkind',
            displayName: 'Cloak of Elvenkind',
          ),
          requiresAttunement: true,
          isAttuned: true,
        ),
        InventoryItemInstance(
          instanceId: 'item-3',
          itemRef: EntityReference<EquipmentItem>(
            refType: EntityType.equipment,
            slug: 'boots-of-speed',
            displayName: 'Boots of Speed',
          ),
          requiresAttunement: true,
          isAttuned: true,
        ),
        InventoryItemInstance(
          instanceId: 'item-4',
          itemRef: EntityReference<EquipmentItem>(
            refType: EntityType.equipment,
            slug: 'amulet-of-health',
            displayName: 'Amulet of Health',
          ),
          requiresAttunement: true,
          isAttuned: false,
        ),
      ],
    );

    fakePersistence = _FakePersistenceService();
    controller = CharacterSheetController(
      character: testCharacter,
      persistenceService: fakePersistence,
    );
  });

  group('CharacterSheetController Live Mechanics Tests', () {
    test('applyShortRest spends hit dice and applies healing', () async {
      final initialHp = controller.character.resources.currentHp;
      await controller.applyShortRest(
        hitDiceSpent: {'d10': 1},
        healingRolled: 8,
      );

      expect(controller.character.resources.currentHitDice['d10'], equals(0));
      expect(controller.character.resources.currentHp, equals(initialHp + 8));
    });

    test('applyLongRest resets HP, tempHp, clears death saves, recovers half hit dice, and removes 1 exhaustion', () async {
      await controller.applyLongRest();

      final res = controller.character.resources;
      expect(res.currentHp, equals(controller.stats.maxHp));
      expect(res.tempHp, equals(0));
      expect(res.deathSaveSuccesses, equals(0));
      expect(res.deathSaveFailures, equals(0));
      // Started with 1/4 d10, level 4 => recovers 2 d10 => now 3 d10
      expect(res.currentHitDice['d10'], equals(3));
      // Exhaustion reduced from 2 to 1
      expect(res.exhaustionLevel, equals(1));
    });

    test('toggleAttuneItem strictly enforces attunement limit', () async {
      expect(controller.stats.effectiveMaxAttunementSlots, equals(3));
      expect(controller.character.inventory.where((i) => i.isAttuned).length, equals(3));

      // Attempting to attune 4th item should fail and return false
      final result = await controller.toggleAttuneItem('item-4');
      expect(result, isFalse);
      expect(controller.character.inventory.firstWhere((i) => i.instanceId == 'item-4').isAttuned, isFalse);

      // Unattune item-1 first
      final unattuneResult = await controller.toggleAttuneItem('item-1');
      expect(unattuneResult, isTrue);
      expect(controller.character.inventory.firstWhere((i) => i.instanceId == 'item-1').isAttuned, isFalse);

      // Now attuning item-4 should succeed
      final attuneResult = await controller.toggleAttuneItem('item-4');
      expect(attuneResult, isTrue);
      expect(controller.character.inventory.firstWhere((i) => i.instanceId == 'item-4').isAttuned, isTrue);
    });

    test('death save and exhaustion modifiers work correctly', () async {
      await controller.setDeathSaves(successes: 3, failures: 0);
      expect(controller.character.resources.deathSaveSuccesses, equals(3));
      expect(controller.character.resources.deathSaveFailures, equals(0));

      await controller.setExhaustionLevel(3);
      expect(controller.character.resources.exhaustionLevel, equals(3));

      await controller.toggleInspiration();
      expect(controller.hasInspiration, isTrue);
      await controller.toggleInspiration();
      expect(controller.hasInspiration, isFalse);
    });

    test('takeDamage strictly depletes tempHp before reducing currentHp, clamping at 0', () async {
      // testCharacter has currentHp: 10, tempHp: 4
      expect(controller.character.resources.currentHp, equals(10));
      expect(controller.character.resources.tempHp, equals(4));

      // 1. Partial damage absorbed by tempHp
      await controller.takeDamage(3);
      expect(controller.character.resources.tempHp, equals(1));
      expect(controller.character.resources.currentHp, equals(10));

      // 2. Damage exceeding remaining tempHp
      await controller.takeDamage(5); // 1 tempHp absorbed, remaining 4 damages currentHp (10 - 4 = 6)
      expect(controller.character.resources.tempHp, equals(0));
      expect(controller.character.resources.currentHp, equals(6));

      // 3. Overkill damage clamps currentHp at 0
      await controller.takeDamage(20);
      expect(controller.character.resources.tempHp, equals(0));
      expect(controller.character.resources.currentHp, equals(0));
    });

    test('heal increases currentHp clamped at stats.maxHp', () async {
      // Bring HP down to 0 then heal 5
      await controller.takeDamage(100);
      await controller.heal(5);
      expect(controller.character.resources.currentHp, equals(5));

      // Heal beyond maxHp
      final maxHp = controller.stats.maxHp;
      await controller.heal(maxHp + 50);
      expect(controller.character.resources.currentHp, equals(maxHp));
    });

    test('Short Rest explicitly recovers Warlock Pact Magic slots, but not standard spell slots', () async {
      final warlockMage = controller.character.copyWith(
        resources: controller.character.resources.copyWith(
          spellSlots: const SpellSlotPool(
            maxSlots: {1: 4, 2: 3},
            currentSlots: {1: 1, 2: 0},
            pactMagicMax: 2,
            pactMagicCurrent: 0,
            pactMagicSlotLevel: 2,
          ),
        ),
      );
      await controller.setCharacter(warlockMage);

      expect(controller.character.resources.spellSlots.pactMagicCurrent, equals(0));
      expect(controller.character.resources.spellSlots.currentSlots[1], equals(1));
      expect(controller.character.resources.spellSlots.currentSlots[2], equals(0));

      // Take short rest
      await controller.applyShortRest(hitDiceSpent: {}, healingRolled: 0);

      // Pact magic slots should be fully restored to pactMagicMax (2)
      expect(controller.character.resources.spellSlots.pactMagicCurrent, equals(2));
      // Standard spell slots should remain unchanged
      expect(controller.character.resources.spellSlots.currentSlots[1], equals(1));
      expect(controller.character.resources.spellSlots.currentSlots[2], equals(0));
    });

    test('Long Rest restores all standard spell slots and pact magic slots to maximum', () async {
      final warlockMage = controller.character.copyWith(
        resources: controller.character.resources.copyWith(
          spellSlots: const SpellSlotPool(
            maxSlots: {1: 4, 2: 3},
            currentSlots: {1: 1, 2: 0},
            pactMagicMax: 2,
            pactMagicCurrent: 0,
            pactMagicSlotLevel: 2,
          ),
        ),
      );
      await controller.setCharacter(warlockMage);

      await controller.applyLongRest();

      final pool = controller.character.resources.spellSlots;
      expect(pool.pactMagicCurrent, equals(2));
      expect(pool.currentSlots[1], equals(4));
      expect(pool.currentSlots[2], equals(3));
    });

    group('Languages & Tool Proficiencies Management', () {
      test('addLanguage adds unique language and avoids duplicates', () {
        expect(controller.character.languages, equals(['Common']));

        controller.addLanguage('Elvish');
        expect(controller.character.languages, contains('Elvish'));
        expect(controller.character.languages.length, equals(2));

        // Adding duplicate should not duplicate entry
        controller.addLanguage('elvish');
        expect(controller.character.languages.length, equals(2));

        controller.addLanguage('Dwarvish');
        expect(controller.character.languages.length, equals(3));
        expect(controller.character.languages, contains('Dwarvish'));
      });

      test('removeLanguage removes target language', () {
        controller.setLanguages(['Common', 'Elvish', 'Draconic']);
        expect(controller.character.languages.length, equals(3));

        controller.removeLanguage('Elvish');
        expect(controller.character.languages, isNot(contains('Elvish')));
        expect(controller.character.languages.length, equals(2));
      });

      test('setLanguages sets entire list without duplicates', () {
        controller.setLanguages(['Common', 'elvish', 'Elvish', 'Orc']);
        expect(controller.character.languages, equals(['Common', 'elvish', 'Orc']));
      });

      test('addToolProficiency adds unique tool and avoids duplicates', () {
        expect(controller.character.toolProficiencies, isEmpty);

        controller.addToolProficiency("Thieves' Tools");
        expect(controller.character.toolProficiencies, contains("Thieves' Tools"));
        expect(controller.character.toolProficiencies.length, equals(1));

        // Duplicate
        controller.addToolProficiency("thieves' tools");
        expect(controller.character.toolProficiencies.length, equals(1));

        controller.addToolProficiency("Smith's Tools");
        expect(controller.character.toolProficiencies.length, equals(2));
      });

      test('removeToolProficiency removes target tool', () {
        controller.setToolProficiencies(["Thieves' Tools", "Smith's Tools", 'Lute']);
        expect(controller.character.toolProficiencies.length, equals(3));

        controller.removeToolProficiency("Smith's Tools");
        expect(controller.character.toolProficiencies, isNot(contains("Smith's Tools")));
        expect(controller.character.toolProficiencies.length, equals(2));
      });

      test('setToolProficiencies sets list and trims items', () {
        controller.setToolProficiencies(["  Thieves' Tools  ", "Lute", "Lute"]);
        expect(controller.character.toolProficiencies, equals(["Thieves' Tools", "Lute"]));
      });
    });
  });
}

