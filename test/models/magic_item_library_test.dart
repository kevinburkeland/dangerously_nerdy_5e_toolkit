import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';

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

    test('verifies all 13 item categories are populated with substantial depth', () {
      expect(ItemCategory.values.length, equals(13));
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

    test('verifies SRD loot items (gemstones, art objects, trinkets) are in the Item Codex', () {
      final diamond = MagicItemLibrary.findById('gem_diamond');
      expect(diamond, isNotNull);
      expect(diamond!.category, equals(ItemCategory.gemstone));
      expect(diamond.cost, equals('5000 GP'));

      final goldChain = MagicItemLibrary.findById('art_fine_gold_chain_with_fire_opal_pendant');
      expect(goldChain, isNotNull);
      expect(goldChain!.category, equals(ItemCategory.artObject));
      expect(goldChain.cost, equals('2500 GP'));

      final trinket01 = MagicItemLibrary.findById('trinket_01');
      expect(trinket01, isNotNull);
      expect(trinket01!.category, equals(ItemCategory.trinket));
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

    test('all 9 official SRD Figurines of Wondrous Power exist with correct data', () {
      const figurineIds = [
        'item_figurine_bronze_griffon',
        'item_figurine_ebony_fly',
        'item_figurine_golden_lions',
        'item_figurine_ivory_goats',
        'item_figurine_marble_elephant',
        'item_figurine_obsidian_steed',
        'item_figurine_onyx_dog',
        'item_figurine_serpentine_owl',
        'item_figurine_silver_raven',
      ];

      for (final id in figurineIds) {
        final item = MagicItemLibrary.findById(id);
        expect(item, isNotNull, reason: 'Figurine $id should exist in MagicItemLibrary');
        expect(item!.name, startsWith('Figurine of Wondrous Power ('));
        expect(item.category, equals(ItemCategory.wondrousItem));
        expect(item.tags, contains('figurine'));
      }

      // Check minion preset covers all 9 figurines (with 11 stat blocks including 3 ivory goats)
      expect(FigurinesSummons.figurinesPreset.statBlocks.length, equals(11));
      final statBlockIds = FigurinesSummons.figurinesPreset.statBlocks.map((s) => s.id).toList();
      expect(statBlockIds, containsAll([
        'item_griffon',
        'item_ebony_fly',
        'item_golden_lion',
        'item_ivory_goat_traveling',
        'item_ivory_goat_travail',
        'item_ivory_goat_terror',
        'item_elephant',
        'item_obsidian_steed',
        'item_onyx_dog',
        'item_serpentine_owl',
        'item_silver_raven',
      ]));
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

    test('CurrencyCoinType accurately resolves and color-codes cp, sp, ep, gp, pp', () {
      expect(CurrencyCoinType.resolve('5 cp'), equals(CurrencyCoinType.cp));
      expect(CurrencyCoinType.resolve('1 sp'), equals(CurrencyCoinType.sp));
      expect(CurrencyCoinType.resolve('5 ep'), equals(CurrencyCoinType.ep));
      expect(CurrencyCoinType.resolve('500 gp'), equals(CurrencyCoinType.gp));
      expect(CurrencyCoinType.resolve('10 pp'), equals(CurrencyCoinType.pp));

      expect(getCurrencyColor('5 cp', true), equals(const Color(0xFFFB923C)));
      expect(getCurrencyColor('1 sp', true), equals(const Color(0xFF94A3B8)));
      expect(getCurrencyColor('500 gp', true), equals(const Color(0xFFFBBF24)));
      expect(getCurrencyColor('10 pp', true), equals(const Color(0xFF38BDF8)));
    });

    test('verifies all 59 newly added SRD wondrous items exist and resolve crafting correctly', () {
      final keyWondrousItems = [
        'Manual of Bodily Health',
        'Manual of Gainful Exercise',
        'Manual of Quickness of Action',
        'Manual of Golems (Clay)',
        'Manual of Golems (Flesh)',
        'Manual of Golems (Iron)',
        'Manual of Golems (Stone)',
        'Tome of Clear Thought',
        'Tome of Leadership and Influence',
        'Tome of Understanding',
        'Cloak of Arachnida',
        'Mantle of Spell Resistance',
        'Robe of Eyes',
        'Robe of Scintillating Colors',
        'Robe of Stars',
        'Cap of Water Breathing',
        'Eyes of Charming',
        'Eyes of Minute Seeing',
        'Helm of Brilliance',
        'Helm of Comprehending Languages',
        'Helm of Telepathy',
        'Medallion of Thoughts',
        'Amulet of Proof against Detection and Location',
        'Amulet of the Planes',
        'Necklace of Prayer Beads',
        'Periapt of Health',
        'Periapt of Proof against Poison',
        'Talisman of Pure Good',
        'Talisman of the Sphere',
        'Talisman of Ultimate Evil',
        'Belt of Dwarvenkind',
        'Boots of Striding and Springing',
        'Bracers of Armor',
        'Gloves of Swimming and Climbing',
        'Horseshoes of a Zephyr',
        'Horseshoes of Speed',
        'Bag of Beans',
        'Bag of Devouring',
        'Crystal Ball',
        'Cubic Gate',
        'Deck of Illusions',
        'Dimensional Shackles',
        'Iron Bands of Binding',
        'Iron Flask',
        'Mirror of Life Trapping',
        'Well of Many Worlds',
        'Bowl of Commanding Water Elementals',
        'Brazier of Commanding Fire Elementals',
        'Censer of Controlling Air Elementals',
        'Stone of Controlling Earth Elementals',
        'Horn of Blasting',
        'Pipes of Haunting',
        'Pipes of the Sewers',
        'Wind Fan',
        'Bead of Force',
        'Dust of Disappearance',
        'Dust of Dryness',
        'Dust of Sneezing and Choking',
        'Incense of Obsession',
        'Restorative Ointment',
        'Sovereign Glue',
        'Universal Solvent',
      ];

      for (final name in keyWondrousItems) {
        final item = MagicItemLibrary.findByName(name);
        expect(item, isNotNull, reason: 'Expected $name to exist in MagicItemLibrary');
        final crafting = item!.getCraftingDetails();
        expect(crafting.goldCost, greaterThan(0), reason: 'Expected $name to have gold cost');
        expect(crafting.primaryTool, isNotEmpty, reason: 'Expected $name to have primary crafting tool');
      }
    });
  });
}
