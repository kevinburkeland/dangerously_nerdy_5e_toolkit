import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_generic_entry_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/entry_node_transformer.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  group('Homebrew Box Formatting & Cleanup Tests', () {
    test(
        'CompendiumJsonIngestionPipeline.cleanRawTags cleans tags and nested tags',
        () {
      const input =
          'A cult of {@creature Ancient Lich|CUSTOM} serves a {@creature cyclops} messiah. {@note Cast {@spell contagion|phb} now.}';
      final cleaned = CompendiumJsonIngestionPipeline.cleanRawTags(input);

      expect(cleaned, isNot(contains('{@')));
      expect(cleaned,
          contains('A cult of Ancient Lich serves a cyclops messiah.'));
      expect(cleaned, contains('> **Note:** Cast contagion now.'));
    });

    test(
        'CompendiumGenericEntryParser cleans tags inside customProperties.rows and colLabels',
        () {
      final parser = CompendiumGenericEntryParser();
      final raw = {
        'name': 'Cult Encounters',
        'type': 'table',
        'colLabels': ['d6', '{@b Encounter}'],
        'rows': [
          [1, 'A cult of {@creature Ancient Lich|CUSTOM} murders innocents.'],
          [
            2,
            'A {@creature doppelganger} kidnaps commoners ({@creature commoner}).'
          ],
        ],
      };

      final entry = parser.parseGenericEntry(raw);
      expect(entry.name, 'Cult Encounters');
      expect(entry.category, 'Table');
      expect(entry.descriptionMarkdown, isNot(contains('{@')));
      expect(entry.descriptionMarkdown, contains('Ancient Lich'));
      expect(entry.descriptionMarkdown, contains('doppelganger'));

      final rows = entry.customProperties['rows'] as List;
      final row0 = rows[0] as List;
      expect(row0[1], isNot(contains('{@')));
      expect(row0[1], contains('Ancient Lich'));

      final row1 = rows[1] as List;
      expect(row1[1], isNot(contains('{@')));
      expect(row1[1], contains('doppelganger'));
      expect(row1[1], contains('commoner'));
    });

    test(
        'compendiumEntryToRollableTable produces clean labels without raw tags or markdown links',
        () {
      const entry = HomebrewCompendiumEntry(
        id: EntityId(slug: 'cult-encounters', ruleset: RulesetVersion.homebrew),
        name: 'Cult Encounters',
        category: 'Table',
        descriptionMarkdown: '',
        customProperties: {
          'colLabels': ['d100', 'Encounter'],
          'rows': [
            ['1-50', 'A cult of {@creature Ancient Lich|CUSTOM} gathers.'],
            ['51-100', 'Meet a [Noble](ref://monster/noble) at night.'],
          ],
        },
      );

      final table =
          HomebrewPersistenceService.compendiumEntryToRollableTable(entry);
      expect(table.entries.length, 2);
      expect(table.entries[0].label, 'A cult of Ancient Lich gathers.');
      expect(table.entries[0].label, isNot(contains('{@')));
      expect(table.entries[1].label, 'Meet a Noble at night.');
      expect(table.entries[1].label, isNot(contains('ref://')));
    });

    test(
        'CompendiumJsonIngestionPipeline rejects and filters corrupted 100k-character entries',
        () {
      final pipeline = CompendiumJsonIngestionPipeline();
      final giantCorruptedName =
          '[{name: Dragonborn, source: CUSTOM, page: 175, tables: ' * 500;
      final malformedMap = {
        'name': giantCorruptedName,
        'source': 'CUSTOM',
      };

      final result = pipeline.ingestJsonMap(malformedMap);
      expect(result.otherEntries.isEmpty, isTrue);
      expect(result.totalEntities, 0);
    });

    test('EntryNodeTransformer handles table cells that are Lists or AST Maps',
        () {
      final transformer = EntryNodeTransformer();
      final node = {
        'type': 'table',
        'caption': 'Sample Table',
        'colLabels': ['Roll', 'Result'],
        'rows': [
          [
            {
              'type': 'cell',
              'roll': {'min': 1, 'max': 50}
            },
            [
              'Found ',
              {'type': 'cell', 'entry': '{@item potion of healing|phb}'}
            ]
          ]
        ]
      };

      final result = transformer.transformEntries([node]);
      expect(result.markdown, isNot(contains('{@')));
      expect(result.markdown, contains('1–50'));
      expect(result.markdown, contains('potion of healing'));
    });
  });
}
