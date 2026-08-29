import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/loot_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/inventory_transaction_service.dart';

void main() {
  group('InventoryTransactionService Tests', () {
    late Character baseCharacter;

    setUp(() {
      baseCharacter = Character(
        id: const EntityId(slug: 'warrior', ruleset: RulesetVersion.v2024),
        name: 'Warrior',
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'fighter',
              displayName: 'Fighter',
            ),
            level: 1,
            hitDie: 'd10',
          ),
        ]),
        baseScores: const AbilityScores.standardArray(),
        inventory: const [
          InventoryItemInstance(
            instanceId: 'inst-sword',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'longsword',
              displayName: 'Longsword',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.mainHand,
          ),
          InventoryItemInstance(
            instanceId: 'inst-shield',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.shield,
          ),
          InventoryItemInstance(
            instanceId: 'inst-greatsword',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'greatsword',
              displayName: 'Greatsword',
            ),
            isEquipped: false,
          ),
          InventoryItemInstance(
            instanceId: 'inst-ring1',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'ring-1',
              displayName: 'Ring of Warmth',
            ),
            requiresAttunement: true,
            isAttuned: false,
          ),
          InventoryItemInstance(
            instanceId: 'inst-ring2',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'ring-2',
              displayName: 'Ring of Feather Falling',
            ),
            requiresAttunement: true,
            isAttuned: true,
          ),
          InventoryItemInstance(
            instanceId: 'inst-ring3',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'ring-3',
              displayName: 'Ring of Mind Shielding',
            ),
            requiresAttunement: true,
            isAttuned: true,
          ),
          InventoryItemInstance(
            instanceId: 'inst-ring4',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'ring-4',
              displayName: 'Ring of Invisibility',
            ),
            requiresAttunement: true,
            isAttuned: true,
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 12),
        purse: const PartyPurse(gp: 50),
      );
    });

    test('equipping a two-handed weapon auto-unequips main hand and shield', () {
      final equipped = InventoryTransactionService.equipItem(
        baseCharacter,
        'inst-greatsword',
        EquipmentSlot.twoHand,
      );

      final sword = equipped.inventory.firstWhere((i) => i.instanceId == 'inst-sword');
      final shield = equipped.inventory.firstWhere((i) => i.instanceId == 'inst-shield');
      final greatsword = equipped.inventory.firstWhere((i) => i.instanceId == 'inst-greatsword');

      expect(greatsword.isEquipped, isTrue);
      expect(greatsword.equippedSlot, equals(EquipmentSlot.twoHand));
      expect(sword.isEquipped, isFalse);
      expect(sword.equippedSlot, isNull);
      expect(shield.isEquipped, isFalse);
      expect(shield.equippedSlot, isNull);
    });

    test('attunement cap validation allows up to max (3) and rejects 4th', () {
      // Current attuned count is 3 (ring2, ring3, ring4)
      expect(baseCharacter.attunedItemCount, equals(3));

      // Attempting to attune ring1 should throw StateError
      expect(
        () => InventoryTransactionService.attuneItem(baseCharacter, 'inst-ring1', true),
        throwsStateError,
      );

      // Unattuning ring2
      final unattuned = InventoryTransactionService.attuneItem(baseCharacter, 'inst-ring2', false);
      expect(unattuned.attunedItemCount, equals(2));

      // Now attuning ring1 succeeds
      final reAttuned = InventoryTransactionService.attuneItem(unattuned, 'inst-ring1', true);
      expect(reAttuned.attunedItemCount, equals(3));
      final ring1 = reAttuned.inventory.firstWhere((i) => i.instanceId == 'inst-ring1');
      expect(ring1.isAttuned, isTrue);
    });

    test('atomic loot transfer from LootContainer to Character', () {
      const chest = LootContainer(
        containerId: 'chest-01',
        name: 'Dungeon Chest',
        items: [
          InventoryItemInstance(
            instanceId: 'chest-item-potion',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'potion-of-healing',
              displayName: 'Potion of Healing',
            ),
            quantity: 3,
          ),
        ],
        purse: PartyPurse(gp: 100, sp: 50),
      );

      final result = InventoryTransactionService.transferFromContainerToCharacter(
        sourceContainer: chest,
        destinationCharacter: baseCharacter,
        instanceId: 'chest-item-potion',
        quantity: 2,
        currency: const PartyPurse(gp: 40),
      );

      // Chest has 1 potion left and 60 gp
      expect(result.updatedContainer.items.first.quantity, equals(1));
      expect(result.updatedContainer.purse.gp, equals(60));

      // Character has +2 potions and +40 gp (50 + 40 = 90 gp)
      final transferredItem = result.updatedCharacter.inventory.last;
      expect(transferredItem.itemRef.slug, equals('potion-of-healing'));
      expect(transferredItem.quantity, equals(2));
      expect(result.updatedCharacter.purse.gp, equals(90));
    });
  });
}
