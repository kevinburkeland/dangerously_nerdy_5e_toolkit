import 'package:flutter/foundation.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/loot_models.dart';
import '../../models/party/party_purse.dart';

/// Result container for atomic loot transactions
@immutable
class LootTransferResult {
  final LootContainer updatedContainer;
  final Character updatedCharacter;

  const LootTransferResult({
    required this.updatedContainer,
    required this.updatedCharacter,
  });
}

/// Inventory and Attunement Transaction Service
class InventoryTransactionService {
  /// Equips an item into a designated slot, managing slot conflicts
  static Character equipItem(
    Character character,
    String instanceId,
    EquipmentSlot slot,
  ) {
    final inventory = List<InventoryItemInstance>.from(character.inventory);
    final targetIndex = inventory.indexWhere((i) => i.instanceId == instanceId);
    if (targetIndex == -1) {
      throw ArgumentError('Item instance $instanceId not found in character inventory.');
    }

    final targetItem = inventory[targetIndex];

    // Handle slot conflicts and auto-unequip
    for (int i = 0; i < inventory.length; i++) {
      if (i == targetIndex) continue;
      final current = inventory[i];
      if (!current.isEquipped) continue;

      bool shouldUnequip = false;

      if (slot == EquipmentSlot.twoHand) {
        // Equipping two-handed weapon unequips main hand, off hand, and shields
        if (current.equippedSlot == EquipmentSlot.mainHand ||
            current.equippedSlot == EquipmentSlot.offHand ||
            current.equippedSlot == EquipmentSlot.twoHand ||
            current.equippedSlot == EquipmentSlot.shield) {
          shouldUnequip = true;
        }
      } else if (slot == EquipmentSlot.mainHand ||
          slot == EquipmentSlot.offHand ||
          slot == EquipmentSlot.shield) {
        // Equipping 1-hand or shield unequips any 2-hand weapon
        if (current.equippedSlot == EquipmentSlot.twoHand ||
            current.equippedSlot == slot) {
          shouldUnequip = true;
        }
      } else {
        // Armor, rings, head, boots, cloak: unequip anything in the exact same slot
        if (current.equippedSlot == slot) {
          shouldUnequip = true;
        }
      }

      if (shouldUnequip) {
        inventory[i] = current.copyWith(
          isEquipped: false,
          equippedSlot: null,
        );
      }
    }

    // Equip target item
    inventory[targetIndex] = targetItem.copyWith(
      isEquipped: true,
      equippedSlot: slot,
    );

    return character.copyWith(inventory: inventory);
  }

  /// Unequips an item from the character
  static Character unequipItem(Character character, String instanceId) {
    final inventory = List<InventoryItemInstance>.from(character.inventory);
    final index = inventory.indexWhere((i) => i.instanceId == instanceId);
    if (index == -1) {
      throw ArgumentError('Item instance $instanceId not found in character inventory.');
    }

    inventory[index] = inventory[index].copyWith(
      isEquipped: false,
      equippedSlot: null,
    );

    return character.copyWith(inventory: inventory);
  }

  /// Attunes or unattunes a magic item, enforcing the max attunement limit
  static Character attuneItem(
    Character character,
    String instanceId,
    bool attune,
  ) {
    final inventory = List<InventoryItemInstance>.from(character.inventory);
    final index = inventory.indexWhere((i) => i.instanceId == instanceId);
    if (index == -1) {
      throw ArgumentError('Item instance $instanceId not found in character inventory.');
    }

    final item = inventory[index];

    if (attune) {
      if (!item.requiresAttunement) {
        throw ArgumentError('Item "${item.displayName}" does not require attunement.');
      }
      if (item.isAttuned) {
        return character; // Already attuned
      }
      if (character.attunedItemCount >= character.maxAttunementSlots) {
        throw StateError(
          'Cannot attune to "${item.displayName}": All ${character.maxAttunementSlots} attunement slots are in use.',
        );
      }

      inventory[index] = item.copyWith(isAttuned: true);
    } else {
      inventory[index] = item.copyWith(isAttuned: false);
    }

    return character.copyWith(inventory: inventory);
  }

  /// Atomically transfers an item and/or currency from a LootContainer to a Character
  static LootTransferResult transferFromContainerToCharacter({
    required LootContainer sourceContainer,
    required Character destinationCharacter,
    required String instanceId,
    int quantity = 1,
    PartyPurse? currency,
  }) {
    final containerItems = List<InventoryItemInstance>.from(sourceContainer.items);
    final itemIndex = containerItems.indexWhere((i) => i.instanceId == instanceId);
    if (itemIndex == -1) {
      throw ArgumentError('Item instance $instanceId not found in container "${sourceContainer.name}".');
    }

    final sourceItem = containerItems[itemIndex];
    if (quantity > sourceItem.quantity) {
      throw ArgumentError('Requested quantity $quantity exceeds container quantity ${sourceItem.quantity}.');
    }

    // Deduct from container
    if (quantity == sourceItem.quantity) {
      containerItems.removeAt(itemIndex);
    } else {
      containerItems[itemIndex] = sourceItem.copyWith(quantity: sourceItem.quantity - quantity);
    }

    // Add to character
    final charInventory = List<InventoryItemInstance>.from(destinationCharacter.inventory);
    charInventory.add(sourceItem.copyWith(
      quantity: quantity,
      isEquipped: false,
      equippedSlot: null,
      isAttuned: false,
    ));

    // Handle currency transfer
    var updatedContainerPurse = sourceContainer.purse;
    var updatedCharPurse = destinationCharacter.purse;
    if (currency != null && currency.totalGpEquivalent > 0) {
      updatedContainerPurse = updatedContainerPurse.deduct(currency);
      updatedCharPurse = updatedCharPurse.add(currency);
    }

    final updatedContainer = sourceContainer.copyWith(
      items: containerItems,
      purse: updatedContainerPurse,
    );

    final updatedChar = destinationCharacter.copyWith(
      inventory: charInventory,
      purse: updatedCharPurse,
    );

    return LootTransferResult(
      updatedContainer: updatedContainer,
      updatedCharacter: updatedChar,
    );
  }

  /// Atomically transfers an item and/or currency from a Character to a LootContainer
  static LootTransferResult transferFromCharacterToContainer({
    required Character sourceCharacter,
    required LootContainer destinationContainer,
    required String instanceId,
    int quantity = 1,
    PartyPurse? currency,
  }) {
    final charInventory = List<InventoryItemInstance>.from(sourceCharacter.inventory);
    final itemIndex = charInventory.indexWhere((i) => i.instanceId == instanceId);
    if (itemIndex == -1) {
      throw ArgumentError('Item instance $instanceId not found in character inventory.');
    }

    final sourceItem = charInventory[itemIndex];
    if (quantity > sourceItem.quantity) {
      throw ArgumentError('Requested quantity $quantity exceeds character quantity ${sourceItem.quantity}.');
    }

    // Deduct from character
    if (quantity == sourceItem.quantity) {
      charInventory.removeAt(itemIndex);
    } else {
      charInventory[itemIndex] = sourceItem.copyWith(quantity: sourceItem.quantity - quantity);
    }

    // Add to container
    final containerItems = List<InventoryItemInstance>.from(destinationContainer.items);
    containerItems.add(sourceItem.copyWith(
      quantity: quantity,
      isEquipped: false,
      equippedSlot: null,
      isAttuned: false,
    ));

    // Handle currency transfer
    var updatedContainerPurse = destinationContainer.purse;
    var updatedCharPurse = sourceCharacter.purse;
    if (currency != null && currency.totalGpEquivalent > 0) {
      updatedCharPurse = updatedCharPurse.deduct(currency);
      updatedContainerPurse = updatedContainerPurse.add(currency);
    }

    final updatedContainer = destinationContainer.copyWith(
      items: containerItems,
      purse: updatedContainerPurse,
    );

    final updatedChar = sourceCharacter.copyWith(
      inventory: charInventory,
      purse: updatedCharPurse,
    );

    return LootTransferResult(
      updatedContainer: updatedContainer,
      updatedCharacter: updatedChar,
    );
  }
}
