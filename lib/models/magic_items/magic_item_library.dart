import 'items/armor_and_shields.dart';
import 'items/potions_and_oils.dart';
import 'items/rings.dart';
import 'items/rods.dart';
import 'items/scrolls.dart';
import 'items/staves.dart';
import 'items/wands.dart';
import 'items/weapons.dart';
import 'items/wondrous_items.dart';
import 'magic_item_data.dart';

export 'magic_item_data.dart';

/// Central SRD 5.1 & 5.2 Magic Item Registry and Query Engine
class MagicItemLibrary {
  MagicItemLibrary._();

  /// Complete list of all SRD 5.1 & 5.2 Magic Items in the toolkit.
  static const List<MagicItem> allItems = [
    ...SrdMagicWeapons.items,
    ...SrdArmorAndShields.items,
    ...SrdPotionsAndOils.items,
    ...SrdMagicRings.items,
    ...SrdMagicRods.items,
    ...SrdMagicScrolls.items,
    ...SrdMagicStaves.items,
    ...SrdMagicWands.items,
    ...SrdWondrousItems.items,
  ];

  /// Find an item by its unique identifier.
  static MagicItem? findById(String id) {
    try {
      return allItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find an item by its display name (case-insensitive).
  static MagicItem? findByName(String name) {
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
  static List<MagicItem> get diffItems =>
      allItems.where((item) => item.isChangedIn2024).toList();

  /// Retrieve all items belonging to a specific category.
  static List<MagicItem> getByCategory(ItemCategory category) =>
      allItems.where((item) => item.category == category).toList();

  /// Retrieve all items of a specific rarity tier.
  static List<MagicItem> getByRarity(ItemRarity rarity) =>
      allItems.where((item) => item.rarity == rarity).toList();
}
