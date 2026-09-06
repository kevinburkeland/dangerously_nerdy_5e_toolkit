import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/loot_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/inventory_transaction_service.dart';

void main() {
  group('InventoryTransactionService Tests', () {
    late Character baseCharacter;

    setUp(() {
      baseCharacter = const Character(
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
          ),
        ]),
        baseScores: AbilityScores.standardArray(),
        inventory: [
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
        resources: CharacterResourcePool(currentHp: 12),
        purse: PartyPurse(gp: 50),
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

    test('equipping multiple wondrous items does not unequip existing wondrous items', () {
      final charWithWondrous = baseCharacter.copyWith(
        inventory: [
          ...baseCharacter.inventory,
          const InventoryItemInstance(
            instanceId: 'inst-bag-of-holding',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'bag-of-holding',
              displayName: 'Bag of Holding',
            ),
            isEquipped: false,
            customProperties: {'category': 'wondrous'},
          ),
          const InventoryItemInstance(
            instanceId: 'inst-periapt',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'periapt-of-wound-closure',
              displayName: 'Periapt of Wound Closure',
            ),
            isEquipped: false,
            customProperties: {'category': 'wondrous'},
          ),
          const InventoryItemInstance(
            instanceId: 'inst-bracers',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'bracers-of-defense',
              displayName: 'Bracers of Defense',
            ),
            isEquipped: false,
            customProperties: {'category': 'wondrous'},
          ),
        ],
      );

      // Equip first wondrous item
      final step1 = InventoryTransactionService.equipItem(
        charWithWondrous,
        'inst-bag-of-holding',
        EquipmentSlot.wondrous,
      );
      final bag1 = step1.inventory.firstWhere((i) => i.instanceId == 'inst-bag-of-holding');
      expect(bag1.isEquipped, isTrue);
      expect(bag1.equippedSlot, equals(EquipmentSlot.wondrous));

      // Equip second wondrous item
      final step2 = InventoryTransactionService.equipItem(
        step1,
        'inst-periapt',
        EquipmentSlot.wondrous,
      );
      final bag2 = step2.inventory.firstWhere((i) => i.instanceId == 'inst-bag-of-holding');
      final periapt2 = step2.inventory.firstWhere((i) => i.instanceId == 'inst-periapt');
      expect(bag2.isEquipped, isTrue, reason: 'First wondrous item should remain equipped');
      expect(periapt2.isEquipped, isTrue, reason: 'Second wondrous item should be equipped');
      expect(bag2.equippedSlot, equals(EquipmentSlot.wondrous));
      expect(periapt2.equippedSlot, equals(EquipmentSlot.wondrous));

      // Equip third wondrous item
      final step3 = InventoryTransactionService.equipItem(
        step2,
        'inst-bracers',
        EquipmentSlot.wondrous,
      );
      final bag3 = step3.inventory.firstWhere((i) => i.instanceId == 'inst-bag-of-holding');
      final periapt3 = step3.inventory.firstWhere((i) => i.instanceId == 'inst-periapt');
      final bracers3 = step3.inventory.firstWhere((i) => i.instanceId == 'inst-bracers');
      expect(bag3.isEquipped, isTrue);
      expect(periapt3.isEquipped, isTrue);
      expect(bracers3.isEquipped, isTrue);
    });

    test('equipping a second ring automatically fills ring2 when ring1 is occupied', () {
      // Equip ring 1 into default ring slot (ring1)
      final step1 = InventoryTransactionService.equipItem(
        baseCharacter,
        'inst-ring1',
        EquipmentSlot.ring1,
      );
      final r1Step1 = step1.inventory.firstWhere((i) => i.instanceId == 'inst-ring1');
      expect(r1Step1.isEquipped, isTrue);
      expect(r1Step1.equippedSlot, equals(EquipmentSlot.ring1));

      // Equip ring 2 into default ring slot (ring1) -> should automatically allocate ring2
      final step2 = InventoryTransactionService.equipItem(
        step1,
        'inst-ring2',
        EquipmentSlot.ring1,
      );
      final r1Step2 = step2.inventory.firstWhere((i) => i.instanceId == 'inst-ring1');
      final r2Step2 = step2.inventory.firstWhere((i) => i.instanceId == 'inst-ring2');
      expect(r1Step2.isEquipped, isTrue, reason: 'Ring 1 should still be equipped in ring1');
      expect(r1Step2.equippedSlot, equals(EquipmentSlot.ring1));
      expect(r2Step2.isEquipped, isTrue, reason: 'Ring 2 should be equipped in ring2');
      expect(r2Step2.equippedSlot, equals(EquipmentSlot.ring2));
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
