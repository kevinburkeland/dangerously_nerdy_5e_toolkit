import 'rollable_table.dart';
import 'srd_dm_tables.dart';
import 'srd_loot_tables.dart';
import 'srd_magic_tables.dart';

/// Central repository providing all 5e SRD rollable tables in the Table Index.
class SrdTablesLibrary {
  SrdTablesLibrary._();

  static final List<RollableTable> allTables = [
    // --- Loot & Magic Item Tables ---
    SrdLootTables.magicItemTableA,
    SrdLootTables.magicItemTableB,
    SrdLootTables.magicItemTableC,
    SrdLootTables.magicItemTableD,
    SrdLootTables.magicItemTableE,
    SrdLootTables.magicItemTableF,
    SrdLootTables.magicItemTableG,
    SrdLootTables.magicItemTableH,
    SrdLootTables.magicItemTableI,
    SrdLootTables.trinketsTable,

    // --- Magic & Chaos Tables ---
    SrdMagicTables.wildMagicSurge,
    SrdMagicTables.confusionBehavior,
    SrdMagicTables.reincarnateRace,
    SrdMagicTables.teleportationMishap,
    SrdMagicTables.prismaticSpray,
    SrdMagicTables.rodOfWonder,
    SrdMagicTables.bagOfTricksGray,
    SrdMagicTables.bagOfTricksRust,
    SrdMagicTables.bagOfTricksTan,

    // --- DM & Gameplay Tables ---
    SrdDmTables.shortTermMadness,
    SrdDmTables.longTermMadness,
    SrdDmTables.indefiniteMadness,
    SrdDmTables.trapSeverity,
    SrdDmTables.carousingComplications,
    SrdDmTables.npcAppearance,
    SrdDmTables.npcTalents,
    SrdDmTables.npcMannerisms,
  ];

  /// Finds a table by its unique identifier.
  static RollableTable? getTableById(String id) {
    try {
      return allTables.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Searches and filters tables by search query and category.
  static List<RollableTable> search(String query, {TableCategory? category}) {
    return allTables.where((table) {
      if (category != null && table.category != category) {
        return false;
      }
      return table.matches(query);
    }).toList();
  }

  /// Returns all tables matching the given category.
  static List<RollableTable> getByCategory(TableCategory category) {
    return allTables.where((t) => t.category == category).toList();
  }
}
