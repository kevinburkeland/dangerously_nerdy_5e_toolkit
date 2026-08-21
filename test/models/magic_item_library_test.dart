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

    test('verifies all 10 item categories are populated', () {
      expect(ItemCategory.values.length, equals(10));
      for (final cat in ItemCategory.values) {
        final itemsInCat = MagicItemLibrary.getByCategory(cat);
        expect(itemsInCat, isNotEmpty, reason: 'Category ${cat.name} should have items');
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
  });
}
