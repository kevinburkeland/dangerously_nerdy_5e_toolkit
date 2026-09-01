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
  });
}
