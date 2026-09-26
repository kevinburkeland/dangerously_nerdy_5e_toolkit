import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_other_category.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/rollable_table.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/srd_tables_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/table_index_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/rules_compendium_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  tearDown(() async {
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  group('Homebrew Cross-Tool Propagation Tests', () {
    test('imported custom table propagates to SrdTablesLibrary and is rollable',
        () async {
      final service = HomebrewPersistenceService();

      const customTableEntry = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'wandering-celestial-encounters',
            ruleset: RulesetVersion.v2014),
        name: 'Wandering Celestial Encounters',
        category: 'Table',
        descriptionMarkdown:
            '| d4 | Encounter |\n| :--- | :--- |\n| 1 | A shower of falling starlight |\n| 2 | An astral courier gliding through the sky |\n| 3 | A dormant beacon of ancient silver |\n| 4 | A planar boundary shimmering faintly |',
        customProperties: {
          'colLabels': ['d4', 'Encounter'],
          'rows': [
            ['1', 'A shower of falling starlight'],
            ['2', 'An astral courier gliding through the sky'],
            ['3', 'A dormant beacon of ancient silver'],
            ['4', 'A planar boundary shimmering faintly'],
          ],
        },
      );

      await service.saveCustomOtherEntry(customTableEntry);

      // Verify presence in SrdTablesLibrary
      final allTables = SrdTablesLibrary.allTables;
      expect(allTables.any((t) => t.id == 'wandering-celestial-encounters'),
          isTrue);

      final foundTable =
          SrdTablesLibrary.getTableById('wandering-celestial-encounters');
      expect(foundTable, isNotNull);
      expect(foundTable!.category, equals(TableCategory.custom));
      expect(foundTable.entries.length, equals(4));
      expect(foundTable.diceFormula, equals('1d4'));

      // Roll test
      final result = foundTable.roll();
      expect(result.rollValue, inInclusiveRange(1, 4));
      expect(result.entry.label.isNotEmpty, isTrue);

      // Search test with category filter
      final customSearchResults =
          SrdTablesLibrary.search('', category: TableCategory.custom);
      expect(
          customSearchResults
              .any((t) => t.id == 'wandering-celestial-encounters'),
          isTrue);
    });

    test(
        'imported deity, trap, hazard, and condition propagate to DmScreenLibrary',
        () async {
      final service = HomebrewPersistenceService();

      const deityEntry = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'solas-the-dawnbringer', ruleset: RulesetVersion.v2014),
        name: 'Solas the Dawnbringer',
        category: 'Deity',
        descriptionMarkdown:
            '**Pantheon:** Solar Expanse | **Domains:** Light, Life\n\nSolas embodies the unyielding light of truth.',
        customProperties: {'pantheon': 'Solar Expanse'},
      );

      const trapEntry = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'obsidian-scythe-pendulum', ruleset: RulesetVersion.v2014),
        name: 'Obsidian Scythe Pendulum',
        category: 'Trap',
        descriptionMarkdown:
            'A razor-sharp obsidian scythe swings from the vaulted ceiling.',
        customProperties: {'trapType': 'Mechanical'},
      );

      const conditionEntry = HomebrewCompendiumEntry(
        id: EntityId(slug: 'sand-rot', ruleset: RulesetVersion.v2014),
        name: 'Sand Rot',
        category: 'Disease',
        descriptionMarkdown:
            'A desiccating affliction that causes joints to calcify and crack.',
        customProperties: {},
      );

      await service.saveCustomOtherEntriesBatch([
        deityEntry,
        trapEntry,
        conditionEntry,
      ]);

      final allRefItems = DmScreenLibrary.allItems;
      expect(allRefItems.any((i) => i.id == 'solas-the-dawnbringer'), isTrue);
      expect(
          allRefItems.any((i) => i.id == 'obsidian-scythe-pendulum'), isTrue);
      expect(allRefItems.any((i) => i.id == 'sand-rot'), isTrue);

      final foundDeity =
          allRefItems.firstWhere((i) => i.id == 'solas-the-dawnbringer');
      expect(foundDeity.category, equals(DmCategory.exploration));
      expect(foundDeity.subCategory, equals('Pantheon & Deities'));

      final foundTrap =
          allRefItems.firstWhere((i) => i.id == 'obsidian-scythe-pendulum');
      expect(foundTrap.category, equals(DmCategory.environment));
      expect(foundTrap.subCategory, equals('Traps'));

      final foundDisease = allRefItems.firstWhere((i) => i.id == 'sand-rot');
      expect(foundDisease.category, equals(DmCategory.conditions));
      expect(foundDisease.subCategory, equals('Diseases'));
    });

    test('imported character options propagate to SrdFeatureOptions', () async {
      final service = HomebrewPersistenceService();

      const maneuver = HomebrewCompendiumEntry(
        id: EntityId(slug: 'whirlwind-cleave', ruleset: RulesetVersion.v2014),
        name: 'Whirlwind Cleave',
        category: 'Maneuver',
        descriptionMarkdown:
            'When you hit with a melee weapon, spend a superiority die to strike all adjacent foes.',
        customProperties: {'featureType': 'MV'},
      );

      await service.saveCustomOtherEntry(maneuver);

      expect(
          SrdFeatureOptions.customCharacterOptions
              .any((o) => o.id == 'whirlwind-cleave'),
          isTrue);
      expect(
          SrdFeatureOptions.allOptions.any((o) => o.id == 'whirlwind-cleave'),
          isTrue);
    });

    test(
        'granular clearing prunes only selected category from runtime libraries',
        () async {
      final service = HomebrewPersistenceService();

      const table = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'desert-hazards-table', ruleset: RulesetVersion.v2014),
        name: 'Desert Hazards Table',
        category: 'Table',
        descriptionMarkdown:
            '| d6 | Hazard |\n| :--- | :--- |\n| 1 | Quicksand |',
        customProperties: {
          'rows': [
            ['1', 'Quicksand']
          ]
        },
      );

      const deity = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'aethelgard-the-iron-watcher', ruleset: RulesetVersion.v2014),
        name: 'Aethelgard the Iron Watcher',
        category: 'Deity',
        descriptionMarkdown: 'Guardian of unyielding mountain strongholds.',
        customProperties: {'pantheon': 'Stone Pantheon'},
      );

      await service.saveCustomOtherEntriesBatch([table, deity]);

      expect(
          SrdTablesLibrary.allTables.any((t) => t.id == 'desert-hazards-table'),
          isTrue);
      expect(
          DmScreenLibrary.allItems
              .any((i) => i.id == 'aethelgard-the-iron-watcher'),
          isTrue);

      // Prune only tables
      await service
          .clearOtherEntriesByCategories({HomebrewOtherCategory.tables});

      expect(
          SrdTablesLibrary.allTables.any((t) => t.id == 'desert-hazards-table'),
          isFalse);
      expect(
          DmScreenLibrary.allItems
              .any((i) => i.id == 'aethelgard-the-iron-watcher'),
          isTrue);
    });

    testWidgets(
        'TableIndexScreen renders custom category chip and imported homebrew table',
        (tester) async {
      final service = HomebrewPersistenceService();

      const table = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'planar-anomalies-table', ruleset: RulesetVersion.v2014),
        name: 'Planar Anomalies Table',
        category: 'Table',
        descriptionMarkdown:
            '| d4 | Event |\n| :--- | :--- |\n| 1 | Gravity Inversion |\n| 2 | Time Dilation |\n| 3 | Astral Wind |\n| 4 | Void Rift |',
        customProperties: {
          'colLabels': ['d4', 'Event'],
          'rows': [
            ['1', 'Gravity Inversion'],
            ['2', 'Time Dilation'],
            ['3', 'Astral Wind'],
            ['4', 'Void Rift'],
          ],
        },
      );

      await service.saveCustomOtherEntry(table);

      await tester.pumpWidget(
        const MaterialApp(
          home: TableIndexScreen(
            initialTabIndex: 1,
            initialCategory: TableCategory.custom,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom table is listed under the filtered category
      expect(find.text('Planar Anomalies Table'), findsOneWidget);
    });

    testWidgets(
        'RulesCompendiumScreen searches and displays custom imported DM reference item',
        (tester) async {
      final service = HomebrewPersistenceService();

      const trap = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'obsidian-scythe-pendulum', ruleset: RulesetVersion.v2014),
        name: 'Obsidian Scythe Pendulum',
        category: 'Trap',
        descriptionMarkdown:
            'A razor-sharp obsidian scythe swings from the vaulted ceiling.',
        customProperties: {'trapType': 'Mechanical'},
      );

      await service.saveCustomOtherEntry(trap);

      await tester.pumpWidget(
        const MaterialApp(
          home: RulesCompendiumScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField).first, 'Obsidian Scythe');
      await tester.pumpAndSettle();

      // Verify custom item is found and displayed
      expect(find.text('Obsidian Scythe Pendulum'), findsOneWidget);
    });
  });
}
