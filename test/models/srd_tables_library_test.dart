import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/rollable_table.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/srd_loot_tables.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/srd_tables_library.dart';

void main() {
  group('SrdTablesLibrary & RollableTable Tests', () {
    test('allTables contains all expected core SRD tables', () {
      expect(SrdTablesLibrary.allTables.isNotEmpty, isTrue);

      final ids = SrdTablesLibrary.allTables.map((t) => t.id).toSet();
      expect(ids.contains('magic_item_table_a'), isTrue);
      expect(ids.contains('magic_item_table_b'), isTrue);
      expect(ids.contains('magic_item_table_c'), isTrue);
      expect(ids.contains('magic_item_table_d'), isTrue);
      expect(ids.contains('magic_item_table_e'), isTrue);
      expect(ids.contains('magic_item_table_f'), isTrue);
      expect(ids.contains('magic_item_table_g'), isTrue);
      expect(ids.contains('magic_item_table_h'), isTrue);
      expect(ids.contains('magic_item_table_i'), isTrue);
      expect(ids.contains('srd_trinkets_table'), isTrue);
      // Cleanup slice 13: non-SRD table removed
      expect(ids.contains('confusion_behavior'), isTrue);
      expect(ids.contains('reincarnate_race'), isTrue);
      expect(ids.contains('short_term_madness'), isTrue);
      expect(ids.contains('long_term_madness'), isTrue);
      expect(ids.contains('indefinite_madness'), isTrue);
    });

    test('search filters tables by name and category accurately', () {
      final lootMatches = SrdTablesLibrary.search('Magic Item Table');
      expect(lootMatches.length, 9); // Tables A through I

      // Cleanup slice 13: non-SRD table removed
      final confusionMatches = SrdTablesLibrary.search('confusion');
      expect(confusionMatches.length, 1);
      expect(confusionMatches.first.id, 'confusion_behavior');

      final dmTables =
          SrdTablesLibrary.search('', category: TableCategory.dmGameplay);
      expect(dmTables.length, greaterThanOrEqualTo(5));
    });

    test('Trinkets table has complete 100 entries with no gaps', () {
      const table = SrdLootTables.trinketsTable;
      expect(table.entries.length, 100);
      for (int i = 1; i <= 100; i++) {
        final matches = table.entries.where((e) => e.matchesRoll(i));
        expect(matches.length, 1,
            reason: 'Roll $i should match exactly one trinket entry');
      }
    });

    test('Rolling on tables produces valid TableRollResult with landed entry',
        () {
      for (final table in SrdTablesLibrary.allTables) {
        final result = table.roll();
        expect(result.tableId, table.id);
        expect(result.rollValue, greaterThanOrEqualTo(1));
        expect(result.entry, isNotNull);
        expect(result.entry.label.isNotEmpty, isTrue);
      }
    });
  });
}
