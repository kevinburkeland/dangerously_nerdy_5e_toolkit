import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';

void main() {
  group('MagicItemLibrary Tests', () {
    test('allItems contains a large comprehensive catalog of items', () {
      expect(MagicItemLibrary.allItems.length, greaterThanOrEqualTo(100));
      // Ensure all item IDs are unique
      final seen = <String>{};
      final duplicates = <String>[];
      for (final item in MagicItemLibrary.allItems) {
        if (!seen.add(item.id)) {
          duplicates.add(item.id);
        }
      }
      expect(duplicates, isEmpty, reason: 'Duplicate item IDs found: $duplicates');
    });

    test('verifies all 10 item categories are populated with substantial depth', () {
      expect(ItemCategory.values.length, equals(10));
      for (final cat in ItemCategory.values) {
        final itemsInCat = MagicItemLibrary.getByCategory(cat);
        expect(itemsInCat, isNotEmpty, reason: 'Category ${cat.name} should have items');
        expect(itemsInCat.length, greaterThanOrEqualTo(5),
            reason: 'Category ${cat.name} should have rich SRD coverage');
        for (final item in itemsInCat) {
          expect(item.id, isNotEmpty);
          expect(item.name, isNotEmpty);
          expect(item.rules2014.summary, isNotEmpty);
          expect(item.rules2024.summary, isNotEmpty);
          expect(item.tags, isNotEmpty);
        }
      }
    });

    test('verifies nonmagical items and specific armor/weapon types exist', () {
      final fullPlate = MagicItemLibrary.findById('armor_plate');
      expect(fullPlate, isNotNull);
      expect(fullPlate!.rarity, equals(ItemRarity.nonmagical));

      final platePlus3 = MagicItemLibrary.findById('plate_plus_3');
      expect(platePlus3, isNotNull);
      expect(platePlus3!.name, equals('Plate Armor +3'));

      final backpack = MagicItemLibrary.findById('backpack');
      expect(backpack, isNotNull);
      expect(backpack!.category, equals(ItemCategory.adventuringGear));
    });

    test('Bag of Tricks variants exist with distinct colors and tables', () {
      final grayBag = MagicItemLibrary.findById('item_bag_of_tricks_gray');
      expect(grayBag, isNotNull);
      expect(grayBag!.name, equals('Bag of Tricks (Gray)'));
      expect(grayBag.effectiveGlyphColor, equals(const Color(0xFF94A3B8)));
      expect(grayBag.rules2014.summary, contains('Weasel'));

      final rustBag = MagicItemLibrary.findById('item_bag_of_tricks_rust');
      expect(rustBag, isNotNull);
      expect(rustBag!.name, equals('Bag of Tricks (Rust)'));
      expect(rustBag.effectiveGlyphColor, equals(const Color(0xFFC2410C)));
      expect(rustBag.rules2014.summary, contains('Brown Bear'));

      final tanBag = MagicItemLibrary.findById('item_bag_of_tricks_tan');
      expect(tanBag, isNotNull);
      expect(tanBag!.name, equals('Bag of Tricks (Tan)'));
      expect(tanBag.effectiveGlyphColor, equals(const Color(0xFFD4A373)));
      expect(tanBag.rules2014.summary, contains('Tiger'));
    });

    test('explicit item color resolution applies to colored armor and Ioun stones', () {
      final redDragonArmor = MagicItemLibrary.findById('item_red_dragon_scale_mail');
      expect(redDragonArmor, isNotNull);
      expect(redDragonArmor!.effectiveGlyphColor, equals(const Color(0xFFEF4444)));

      final blueDragonArmor = MagicItemLibrary.findById('item_blue_dragon_scale_mail');
      expect(blueDragonArmor, isNotNull);
      expect(blueDragonArmor!.effectiveGlyphColor, equals(const Color(0xFF38BDF8)));

      final iounDeepRed = MagicItemLibrary.findById('item_ioun_stone_deep_red');
      expect(iounDeepRed, isNotNull);
      expect(iounDeepRed!.effectiveGlyphColor, equals(const Color(0xFFEF4444)));

      final iounPaleGreen = MagicItemLibrary.findById('item_ioun_stone_pale_green');
      expect(iounPaleGreen, isNotNull);
      expect(iounPaleGreen!.effectiveGlyphColor, equals(const Color(0xFF10B981)));

      final iounDustyRose = MagicItemLibrary.findById('item_ioun_stone_dusty_rose');
      expect(iounDustyRose, isNotNull);
      expect(iounDustyRose!.effectiveGlyphColor, equals(const Color(0xFFFB7185)));
    });

    test('findById and findByName lookups work accurately', () {
      final flameTongue = MagicItemLibrary.findById('item_flame_tongue');
      expect(flameTongue, isNotNull);
      expect(flameTongue!.name, equals('Flame Tongue'));

      final byName = MagicItemLibrary.findByName('staff of power');
      expect(byName, isNotNull);
      expect(byName!.id, equals('item_staff_of_power'));
    });

    test('diffItems correctly extracts items with 2024 differences', () {
      final diffs = MagicItemLibrary.diffItems;
      expect(diffs, isNotEmpty);
      for (final item in diffs) {
        expect(item.isChangedIn2024, isTrue);
      }
    });

    test('verifies effective price resolution for nonmagical, magic items, and consumables', () {
      final dagger = MagicItemLibrary.findById('weapon_dagger');
      expect(dagger, isNotNull);
      expect(dagger!.getEffectivePrice(), equals('2 gp'));

      final potionOfHealing = MagicItemLibrary.findByName('Potion of Healing');
      expect(potionOfHealing, isNotNull);
      expect(potionOfHealing!.isConsumable, isTrue);
      expect(potionOfHealing.getEffectivePrice(), equals('25–50 gp'));

      final flameTongue = MagicItemLibrary.findById('item_flame_tongue');
      expect(flameTongue, isNotNull);
      expect(flameTongue!.rarity, equals(ItemRarity.rare));
      expect(flameTongue.isConsumable, isFalse);
      expect(flameTongue.getEffectivePrice(), equals('500–5,000 gp'));
    });

    test('verifies crafting details resolution across categories and rarities', () {
      // 1. Potion of Healing -> Herbalism Kit, 25 gp, 2.5-3 days 2024, CR 1-3
      final potionOfHealing = MagicItemLibrary.findByName('Potion of Healing');
      expect(potionOfHealing, isNotNull);
      final potionCrafting = potionOfHealing!.getCraftingDetails();
      expect(potionCrafting.primaryTool, equals('Herbalism Kit'));
      expect(potionCrafting.goldCost, equals(25));
      expect(potionCrafting.isConsumable, isTrue);
      expect(potionCrafting.bastionFacility, contains('Laboratory'));
      expect(potionCrafting.minimumCharacterLevel, equals(3));
      expect(potionCrafting.exoticIngredientCr, contains('CR 1–3'));

      // 2. Flame Tongue (Rare Weapon) -> Smith's Tools, 2,000 gp, 200 days 2024, Level 6, CR 9-12
      final flameTongue = MagicItemLibrary.findById('item_flame_tongue');
      expect(flameTongue, isNotNull);
      final ftCrafting = flameTongue!.getCraftingDetails();
      expect(ftCrafting.primaryTool, equals('Smith\'s Tools'));
      expect(ftCrafting.goldCost, equals(2000));
      expect(ftCrafting.craftingDays2024, equals(200));
      expect(ftCrafting.minimumCharacterLevel, equals(6));
      expect(ftCrafting.exoticIngredientCr, contains('CR 9–12'));
      expect(ftCrafting.bastionFacility, contains('Smithy'));

      // 3. Scroll of Fireball (Uncommon Scroll) -> Calligrapher's Supplies, 100 gp, Level 3
      final scroll = MagicItemLibrary.findById('item_spell_scroll_level_3');
      if (scroll != null) {
        final scrollCrafting = scroll.getCraftingDetails();
        expect(scrollCrafting.primaryTool, equals('Calligrapher\'s Supplies'));
        expect(scrollCrafting.isConsumable, isTrue);
        expect(scrollCrafting.bastionFacility, contains('Arcane Study'));
      }
    });

    test('matches method searches by price strings and crafting tools', () {
      final smithItems = MagicItemLibrary.allItems
          .where((i) => i.matches('smith\'s tools'))
          .toList();
      expect(smithItems, isNotEmpty);

      final potionItems = MagicItemLibrary.allItems
          .where((i) => i.matches('herbalism kit'))
          .toList();
      expect(potionItems, isNotEmpty);
    });
  });
}
