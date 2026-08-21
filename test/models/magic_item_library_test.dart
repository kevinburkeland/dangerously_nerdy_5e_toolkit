import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';

void main() {
  group('MagicItemLibrary Tests', () {
    test('allItems contains a large comprehensive catalog of items', () {
      expect(MagicItemLibrary.allItems.length, greaterThanOrEqualTo(100));
      // Ensure all item IDs are unique
      final ids = MagicItemLibrary.allItems.map((e) => e.id).toSet();
      expect(ids.length, equals(MagicItemLibrary.allItems.length));
    });

    test('verifies all 9 item categories are populated', () {
      for (final cat in ItemCategory.values) {
        final itemsInCat = MagicItemLibrary.getByCategory(cat);
        expect(itemsInCat, isNotEmpty, reason: 'Category ${cat.name} should have items');
      }
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
