import 'items/adventuring_gear.dart';
import 'items/armor_and_shields.dart';
import 'items/potions_and_oils.dart';
import 'items/rings.dart';
import 'items/rods.dart';
import 'items/scrolls.dart';
import 'items/staves.dart';
import 'items/wands.dart';
import 'items/weapons.dart';
import 'items/wondrous_items.dart';
import 'items/srd_loot_items.dart';
import 'magic_item_data.dart';

export 'magic_item_data.dart';

/// Central SRD 5.1 & 5.2 Magic Item Registry and Query Engine
class MagicItemLibrary {
  MagicItemLibrary._();

  /// Complete list of all SRD 5.1 & 5.2 Magic Items and Equipment in the toolkit.
  static final List<EquipmentItem> _baseItems = [
    ...SrdMagicWeapons.items,
    ...SrdArmorAndShields.items,
    ...SrdPotionsAndOils.items,
    ...SrdMagicRings.items,
    ...SrdMagicRods.items,
    ...SrdMagicScrolls.items,
    ...SrdMagicStaves.items,
    ...SrdMagicWands.items,
    ...SrdWondrousItems.items,
    ...SrdAdventuringGear.items,
    ...SrdLootItems.items,
  ];

  static List<EquipmentItem> _homebrewItems = [];

  /// Base SRD 5.1 & 5.2 Magic Items unpolluted by homebrew items.
  static List<EquipmentItem> get baseItems => _baseItems;

  /// Combined list of all SRD and Homebrew Magic Items and Equipment in the toolkit.
  static List<EquipmentItem> get allItems => [..._baseItems, ..._homebrewItems];

  /// Sets the list of custom/homebrew items in the library.
  static void setHomebrewItems(List<EquipmentItem> items) {
    _homebrewItems = List<EquipmentItem>.from(items);
  }

  /// Adds or replaces a custom homebrew item in the library.
  static void addHomebrewItem(EquipmentItem item) {
    _homebrewItems.removeWhere((i) => i.id.slug == item.id.slug);
    _homebrewItems.add(item);
  }

  /// Removes a custom homebrew item by id.
  static void removeHomebrewItem(String id) {
    _homebrewItems.removeWhere((i) => i.id.slug == id);
  }

  /// Find an item by its unique identifier.
  static EquipmentItem? findById(String id) {
    try {
      return allItems.firstWhere((item) => item.id.slug == id);
    } catch (_) {
      return null;
    }
  }

  /// Find an item by its display name (case-insensitive).
  static EquipmentItem? findByName(String name) {
    final q = name.trim().toLowerCase();
    try {
      return allItems.firstWhere(
        (item) =>
            item.name.toLowerCase() == q ||
            (item.name2014?.toLowerCase() == q) ||
            (item.name2024?.toLowerCase() == q),
      );
    } catch (_) {
      return null;
    }
  }

  /// All items that have mechanical differences between 2014 RAW and 2024 Revised rules.
  static List<EquipmentItem> get diffItems =>
      allItems.where((item) => item.isChangedIn2024).toList();

  /// Retrieve all items belonging to a specific category.
  static List<EquipmentItem> getByCategory(ItemCategory category) =>
      allItems.where((item) => item.category == category).toList();

  /// Retrieve all items of a specific rarity tier.
  static List<EquipmentItem> getByRarity(ItemRarity rarity) =>
      allItems.where((item) => item.rarityTier == rarity).toList();
}
