import '../magic_item_data.dart';
import '../../tables/srd_loot_tables.dart';

/// SRD Loot & Treasure Items catalog (Gemstones, Art Objects, and 100 Trinkets)
/// surfaced inside the Item Codex.
class SrdLootItems {
  SrdLootItems._();

  static List<MagicItem> get items => [
        ..._buildGemstones(),
        ..._buildArtObjects(),
        ..._buildTrinkets(),
      ];

  static List<MagicItem> _buildGemstones() {
    final allGems = [
      ...SrdLootTables.gemstones10gp,
      ...SrdLootTables.gemstones50gp,
      ...SrdLootTables.gemstones100gp,
      ...SrdLootTables.gemstones500gp,
      ...SrdLootTables.gemstones1000gp,
      ...SrdLootTables.gemstones5000gp,
    ];

    return allGems.map((gem) {
      final id = 'gem_${gem.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
      final rarity = switch (gem.gpValue) {
        <= 50 => ItemRarity.common,
        <= 500 => ItemRarity.uncommon,
        <= 1000 => ItemRarity.rare,
        _ => ItemRarity.veryRare,
      };

      final desc = '${gem.name} is a precious gemstone valued at ${gem.gpValue} gold pieces in standard 5e trade.';

      return MagicItem(
        id: id,
        name: gem.name,
        category: ItemCategory.gemstone,
        rarity: rarity,
        cost: '${gem.gpValue} GP',
        cost2014: '${gem.gpValue} GP',
        cost2024: '${gem.gpValue} GP',
        requiresAttunement: false,
        rules2014: ItemEditionDetails(
          summary: '${gem.category} (${gem.gpValue} GP)',
          description: desc,
          properties: [
            'Value: ${gem.gpValue} GP',
            'Type: ${gem.category}',
            'Mundane or spell component use (e.g. Revivify, Identify)',
          ],
        ),
        rules2024: ItemEditionDetails(
          summary: '${gem.category} (${gem.gpValue} GP)',
          description: desc,
          properties: [
            'Value: ${gem.gpValue} GP',
            'Type: ${gem.category}',
            'Mundane trade currency or spell component material',
          ],
        ),
        tags: ['gem', 'gemstone', 'loot', 'treasure', 'trade', '${gem.gpValue}gp'],
      );
    }).toList();
  }

  static List<MagicItem> _buildArtObjects() {
    final allArt = [
      ...SrdLootTables.artObjects25gp,
      ...SrdLootTables.artObjects250gp,
      ...SrdLootTables.artObjects750gp,
      ...SrdLootTables.artObjects2500gp,
      ...SrdLootTables.artObjects7500gp,
    ];

    return allArt.map((art) {
      final id = 'art_${art.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
      final rarity = switch (art.gpValue) {
        <= 25 => ItemRarity.common,
        <= 250 => ItemRarity.uncommon,
        <= 750 => ItemRarity.rare,
        <= 2500 => ItemRarity.veryRare,
        _ => ItemRarity.legendary,
      };

      final desc = '${art.name} is an exquisite art object valued at ${art.gpValue} gold pieces in standard 5e treasure hoards.';

      return MagicItem(
        id: id,
        name: art.name,
        category: ItemCategory.artObject,
        rarity: rarity,
        cost: '${art.gpValue} GP',
        cost2014: '${art.gpValue} GP',
        cost2024: '${art.gpValue} GP',
        requiresAttunement: false,
        rules2014: ItemEditionDetails(
          summary: '${art.category} (${art.gpValue} GP)',
          description: desc,
          properties: [
            'Value: ${art.gpValue} GP',
            'Type: ${art.category}',
            'Thematic hoard treasure and collector heirloom',
          ],
        ),
        rules2024: ItemEditionDetails(
          summary: '${art.category} (${art.gpValue} GP)',
          description: desc,
          properties: [
            'Value: ${art.gpValue} GP',
            'Type: ${art.category}',
            'Thematic hoard treasure and collector heirloom',
          ],
        ),
        tags: ['art', 'art object', 'loot', 'treasure', 'heirloom', '${art.gpValue}gp'],
      );
    }).toList();
  }

  static List<MagicItem> _buildTrinkets() {
    final entries = SrdLootTables.trinketsTable.entries;

    return entries.map((entry) {
      final numStr = entry.minRoll.toString().padLeft(2, '0');
      final id = 'trinket_$numStr';
      final name = entry.label;
      final desc = entry.description ?? name;

      return MagicItem(
        id: id,
        name: 'Trinket: $name',
        category: ItemCategory.trinket,
        rarity: ItemRarity.common,
        cost: '1 GP',
        cost2014: '1 GP',
        cost2024: '1 GP',
        requiresAttunement: false,
        rules2014: ItemEditionDetails(
          summary: '100 SRD Trinket #$numStr',
          description: desc,
          properties: [
            'Roll: d100 result ${entry.minRoll}',
            'Category: Character Trinket / Curious Oddity',
          ],
        ),
        rules2024: ItemEditionDetails(
          summary: '100 SRD Trinket #$numStr',
          description: desc,
          properties: [
            'Roll: d100 result ${entry.minRoll}',
            'Category: Character Trinket / Curious Oddity',
          ],
        ),
        tags: ['trinket', 'curio', 'oddity', 'character', 'flavor', 'loot'],
      );
    }).toList();
  }
}
