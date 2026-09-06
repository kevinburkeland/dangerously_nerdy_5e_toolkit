import 'package:flutter/foundation.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/loot_models.dart';
import '../../models/domain/spell_monster_equipment.dart';
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
  /// Resolves the intended [EquipmentSlot] for an item based on its slot property,
  /// category, tags, or name.
  static EquipmentSlot resolveDefaultSlot(
    InventoryItemInstance instance, {
    EquipmentItem? resolvedItem,
  }) {
    if (instance.equippedSlot != null) {
      return instance.equippedSlot!;
    }

    final props = {
      ...instance.customProperties,
      if (resolvedItem != null) ...resolvedItem.customProperties,
    };

    // 1. Explicit defaultSlot in properties
    if (props['defaultSlot'] != null) {
      final ds = props['defaultSlot'];
      if (ds is EquipmentSlot) return ds;
      if (ds is String) {
        final match = EquipmentSlot.values.where(
          (s) => s.name.toLowerCase() == ds.toLowerCase(),
        );
        if (match.isNotEmpty) return match.first;
      }
    }

    final nameLower = instance.displayName.toLowerCase();
    final slugLower = instance.itemRef.slug.toLowerCase();
    final categoryLower = (props['category']?.toString() ??
            resolvedItem?.itemType ??
            '')
        .toLowerCase();
    final tags = (props['tags'] is List
            ? (props['tags'] as List).map((e) => e.toString().toLowerCase()).toList()
            : <String>[]);

    // 2. Shield check
    if (props['isShield'] == true ||
        categoryLower == 'shield' ||
        tags.contains('shield') ||
        nameLower.contains('shield') ||
        slugLower.contains('shield')) {
      return EquipmentSlot.shield;
    }

    // 3. Armor check
    if (categoryLower == 'armor' ||
        categoryLower.contains('armor') ||
        props['armorType'] != null ||
        props['baseAc'] != null ||
        tags.contains('armor') ||
        tags.contains('heavy') ||
        tags.contains('medium') ||
        tags.contains('light') ||
        nameLower.contains('armor') ||
        nameLower.contains('plate') ||
        nameLower.contains('chain mail') ||
        nameLower.contains('ring mail') ||
        nameLower.contains('splint') ||
        nameLower.contains('leather') ||
        nameLower.contains('padded') ||
        nameLower.contains('hide') ||
        nameLower.contains('breastplate') ||
        slugLower.contains('armor') ||
        slugLower.contains('plate') ||
        slugLower.contains('breastplate')) {
      return EquipmentSlot.armor;
    }

    // 4. Ring check
    if (categoryLower == 'ring' ||
        tags.contains('ring') ||
        nameLower.startsWith('ring of') ||
        nameLower.contains(' ring')) {
      return EquipmentSlot.ring1;
    }

    // 5. Cloak check
    if (categoryLower == 'cloak' ||
        tags.contains('cloak') ||
        nameLower.contains('cloak') ||
        nameLower.contains('cape') ||
        nameLower.contains('mantle')) {
      return EquipmentSlot.cloak;
    }

    // 6. Boots / Footwear
    if (categoryLower == 'boots' ||
        tags.contains('boots') ||
        nameLower.contains('boots') ||
        nameLower.contains('slippers') ||
        nameLower.contains('shoes')) {
      return EquipmentSlot.boots;
    }

    // 7. Headgear
    if (categoryLower == 'head' ||
        categoryLower == 'helmet' ||
        tags.contains('head') ||
        tags.contains('helmet') ||
        nameLower.contains('helm') ||
        nameLower.contains('circlet') ||
        nameLower.contains('hat') ||
        nameLower.contains('crown')) {
      return EquipmentSlot.head;
    }

    // 8. Weapons (Two-handed or One-handed)
    final isTwoHand = props['twoHanded'] == true ||
        tags.contains('two-handed') ||
        tags.contains('twohanded') ||
        tags.contains('2h') ||
        nameLower.contains('greatsword') ||
        nameLower.contains('greataxe') ||
        nameLower.contains('maul') ||
        nameLower.contains('halberd') ||
        nameLower.contains('glaive') ||
        nameLower.contains('heavy crossbow') ||
        nameLower.contains('longbow') ||
        nameLower.contains('shortbow') ||
        nameLower.contains('light crossbow') ||
        nameLower.contains('pike');

    if (isTwoHand) {
      return EquipmentSlot.twoHand;
    }

    final isWeapon = categoryLower == 'weapon' ||
        categoryLower.contains('weapon') ||
        props['isWeapon'] == true ||
        props['weaponType'] != null ||
        props['damageDice'] != null ||
        tags.contains('weapon') ||
        tags.contains('melee') ||
        tags.contains('ranged') ||
        nameLower.contains('sword') ||
        nameLower.contains('dagger') ||
        nameLower.contains('axe') ||
        nameLower.contains('bow') ||
        nameLower.contains('mace') ||
        nameLower.contains('spear') ||
        nameLower.contains('crossbow') ||
        nameLower.contains('hammer') ||
        nameLower.contains('flail') ||
        nameLower.contains('scimitar') ||
        nameLower.contains('rapier') ||
        nameLower.contains('quarterstaff') ||
        nameLower.contains('trident') ||
        nameLower.contains('morningstar') ||
        nameLower.contains('whip') ||
        nameLower.contains('warhammer') ||
        nameLower.contains('club');

    if (isWeapon) {
      return EquipmentSlot.mainHand;
    }

    return EquipmentSlot.wondrous;
  }

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

    var effectiveSlot = slot;
    if (slot == EquipmentSlot.ring1) {
      final ring1Occupied = inventory.any((i) =>
          i.instanceId != instanceId &&
          i.isEquipped &&
          i.equippedSlot == EquipmentSlot.ring1);
      final ring2Occupied = inventory.any((i) =>
          i.instanceId != instanceId &&
          i.isEquipped &&
          i.equippedSlot == EquipmentSlot.ring2);
      if (ring1Occupied && !ring2Occupied) {
        effectiveSlot = EquipmentSlot.ring2;
      }
    }

    // Handle slot conflicts and auto-unequip
    for (int i = 0; i < inventory.length; i++) {
      if (i == targetIndex) continue;
      final current = inventory[i];
      if (!current.isEquipped) continue;

      bool shouldUnequip = false;

      if (effectiveSlot == EquipmentSlot.twoHand) {
        // Equipping two-handed weapon unequips main hand, off hand, and shields
        if (current.equippedSlot == EquipmentSlot.mainHand ||
            current.equippedSlot == EquipmentSlot.offHand ||
            current.equippedSlot == EquipmentSlot.twoHand ||
            current.equippedSlot == EquipmentSlot.shield) {
          shouldUnequip = true;
        }
      } else if (effectiveSlot == EquipmentSlot.mainHand ||
          effectiveSlot == EquipmentSlot.offHand ||
          effectiveSlot == EquipmentSlot.shield) {
        // Equipping 1-hand or shield unequips any 2-hand weapon
        if (current.equippedSlot == EquipmentSlot.twoHand ||
            current.equippedSlot == effectiveSlot) {
          shouldUnequip = true;
        }
      } else if (effectiveSlot == EquipmentSlot.wondrous) {
        // In 5e RAW (DMG p. 141), wondrous items do not occupy a mutually exclusive single equipment slot.
        // A character can wear/equip multiple wondrous items simultaneously (subject to attunement).
        shouldUnequip = false;
      } else {
        // Armor, rings, head, boots, cloak: unequip anything in the exact same slot
        if (current.equippedSlot == effectiveSlot) {
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
      equippedSlot: effectiveSlot,
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
