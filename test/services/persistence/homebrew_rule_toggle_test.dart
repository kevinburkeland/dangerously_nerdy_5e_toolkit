import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/srd_tables_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/homebrew_studio_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/dm_rule_comparison_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/dm_rule_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  tearDown(() async {
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  group('Homebrew Rule Toggle Tests', () {
    test(
        'toggleOtherEntryEnabled flips state in persistence and library hydration',
        () async {
      final service = HomebrewPersistenceService();

      const customRule = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'chronal-initiative-variant', ruleset: RulesetVersion.v2014),
        name: 'Chronal Initiative Variant',
        category: 'Variant Rule',
        descriptionMarkdown:
            'Combatants roll initiative at the start of every combat round.',
        isEnabled: true,
      );

      const customTable = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'starlight-calamity-table', ruleset: RulesetVersion.v2014),
        name: 'Starlight Calamity Table',
        category: 'Table',
        descriptionMarkdown:
            '| d4 | Event |\n| 1 | Solar Flare |\n| 2 | Nova Pulse |\n| 3 | Lunar Glow |\n| 4 | Astral Rift |',
        customProperties: {
          'colLabels': ['d4', 'Event'],
          'rows': [
            ['1', 'Solar Flare'],
            ['2', 'Nova Pulse'],
            ['3', 'Lunar Glow'],
            ['4', 'Astral Rift'],
          ],
        },
        isEnabled: true,
      );

      await service.saveCustomOtherEntry(customRule);
      await service.saveCustomOtherEntry(customTable);

      // Initially active
      expect(
          DmScreenLibrary.allItems
              .any((i) => i.id == 'chronal-initiative-variant'),
          isTrue);
      expect(
          SrdTablesLibrary.allTables
              .any((t) => t.id == 'starlight-calamity-table'),
          isTrue);

      // Toggle rule off
      final state1 = await service.toggleOtherEntryEnabled(
          'chronal-initiative-variant',
          isEnabled: false);
      expect(state1, isFalse);

      // Rule is disabled: omitted from DmScreenLibrary
      expect(
          DmScreenLibrary.allItems
              .any((i) => i.id == 'chronal-initiative-variant'),
          isFalse);
      // Table remains active
      expect(
          SrdTablesLibrary.allTables
              .any((t) => t.id == 'starlight-calamity-table'),
          isTrue);

      // Verify persistence returns disabled entry
      final loadedOthers = await service.loadCustomOtherEntries();
      final disabledRule = loadedOthers
          .firstWhere((e) => e.id.slug == 'chronal-initiative-variant');
      expect(disabledRule.isEnabled, isFalse);

      // Toggle table off using auto-toggle (passing null flips current state)
      final state2 =
          await service.toggleOtherEntryEnabled('starlight-calamity-table');
      expect(state2, isFalse);
      expect(
          SrdTablesLibrary.allTables
              .any((t) => t.id == 'starlight-calamity-table'),
          isFalse);

      // Re-enable rule
      final state3 = await service.toggleOtherEntryEnabled(
          'chronal-initiative-variant',
          isEnabled: true);
      expect(state3, isTrue);
      expect(
          DmScreenLibrary.allItems
              .any((i) => i.id == 'chronal-initiative-variant'),
          isTrue);
    });

    test('character options are excluded from SrdFeatureOptions when disabled',
        () async {
      final service = HomebrewPersistenceService();

      const customBoon = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'boon-of-the-sun-weaver', ruleset: RulesetVersion.v2014),
        name: 'Boon of the Sun Weaver',
        category: 'Optional Feature',
        descriptionMarkdown: 'You radiate blinding starlight.',
        customProperties: {'prerequisite': '20th level'},
        isEnabled: true,
      );

      await service.saveCustomOtherEntry(customBoon);
      expect(
          SrdFeatureOptions.allOptions
              .any((o) => o.id == 'boon-of-the-sun-weaver'),
          isTrue);

      // Disable boon
      await service.toggleOtherEntryEnabled('boon-of-the-sun-weaver',
          isEnabled: false);
      expect(
          SrdFeatureOptions.allOptions
              .any((o) => o.id == 'boon-of-the-sun-weaver'),
          isFalse);

      // Re-enable boon
      await service.toggleOtherEntryEnabled('boon-of-the-sun-weaver',
          isEnabled: true);
      expect(
          SrdFeatureOptions.allOptions
              .any((o) => o.id == 'boon-of-the-sun-weaver'),
          isTrue);
    });

    testWidgets(
        'HomebrewStudioScreen UI allows toggling rules and filtering by active/disabled',
        (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = HomebrewPersistenceService();

      const ruleA = HomebrewCompendiumEntry(
        id: EntityId(slug: 'rule-alpha', ruleset: RulesetVersion.v2014),
        name: 'Rule Alpha',
        category: 'Variant Rule',
        descriptionMarkdown: 'Alpha mechanics.',
        isEnabled: true,
      );

      const ruleB = HomebrewCompendiumEntry(
        id: EntityId(slug: 'rule-beta', ruleset: RulesetVersion.v2014),
        name: 'Rule Beta',
        category: 'Variant Rule',
        descriptionMarkdown: 'Beta mechanics.',
        isEnabled: false,
      );

      await service.saveCustomOtherEntry(ruleA);
      await service.saveCustomOtherEntry(ruleB);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomebrewStudioScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Tab 7 (Codex & Rules)
      final tabFinder = find.textContaining('Codex & Rules');
      expect(tabFinder, findsOneWidget);
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();

      // Verify Rule Alpha is shown with switch active and Rule Beta has Disabled badge
      expect(find.text('Rule Alpha'), findsOneWidget);
      expect(find.text('Rule Beta'), findsOneWidget);
      expect(find.text('Disabled'), findsAtLeastNWidgets(1));

      // Check Active / Disabled filter chips
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Disabled (1)'), findsOneWidget);

      // Tap "Active (1)" filter chip
      await tester.tap(find.text('Active (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Rule Alpha'), findsOneWidget);
      expect(find.text('Rule Beta'), findsNothing);

      // Tap "Disabled (1)" filter chip
      await tester.tap(find.text('Disabled (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Rule Alpha'), findsNothing);
      expect(find.text('Rule Beta'), findsOneWidget);

      // Toggle Rule Beta back ON
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Now both are active, verify in persistence
      final refreshed = await service.loadCustomOtherEntries();
      final updatedB = refreshed.firstWhere((e) => e.id.slug == 'rule-beta');
      expect(updatedB.isEnabled, isTrue);
    });

    testWidgets('DmRuleComparisonDialog displays homebrew rule disable button',
        (tester) async {
      final service = HomebrewPersistenceService();

      const homebrewRule = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'solar-overdrive-rule', ruleset: RulesetVersion.v2014),
        name: 'Solar Overdrive Rule',
        category: 'Variant Rule',
        descriptionMarkdown:
            'Allows expending extra spell slots for solar bursts.',
        isEnabled: true,
      );
      await service.saveCustomOtherEntry(homebrewRule);

      final item = DmScreenLibrary.allItems
          .firstWhere((i) => i.id == 'solar-overdrive-rule');
      expect(item.isHomebrew, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DmRuleComparisonDialog.show(
                  context,
                  item: item,
                  isPinned: false,
                  onTogglePin: () {},
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Header indicates 'Homebrew Rule'
      expect(find.text('Homebrew Rule'), findsOneWidget);

      // Verify disable button exists with tooltip
      final disableButton = find.byTooltip('Disable this homebrew rule');
      expect(disableButton, findsOneWidget);

      await tester.tap(disableButton);
      await tester.pumpAndSettle();

      // Dialog closed and rule disabled in persistence & library
      expect(find.byType(DmRuleComparisonDialog), findsNothing);
      expect(
          DmScreenLibrary.allItems.any((i) => i.id == 'solar-overdrive-rule'),
          isFalse);
    });

    testWidgets('DmRuleCard displays Homebrew badge for homebrew items',
        (tester) async {
      const homebrewItem = DmReferenceItem(
        id: 'astral-tides-rule',
        title: 'Astral Tides Rule',
        category: DmCategory.actions,
        summary: 'Astral tides push creatures 10 feet.',
        rules2014: ['Astral tides push creatures 10 feet.'],
        rules2024: ['Astral tides push creatures 10 feet.'],
        tags: ['Homebrew', 'Movement'],
      );

      expect(homebrewItem.isHomebrew, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DmRuleCard(
              item: homebrewItem,
              edition: DmRulesEdition.v2014,
              isPinned: false,
              onTogglePin: () {},
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Homebrew'), findsOneWidget);
    });

    testWidgets(
        'DmRuleCard renders markdown tables and shows Rollable badge with Table Roller button',
        (tester) async {
      const rollableTableItem = DmReferenceItem(
        id: 'wild-magic-surge-table',
        title: 'Wild Magic Surge Table',
        category: DmCategory.tables,
        subCategory: 'Rollable Tables',
        summary: 'Rollable table with 50 outcomes.',
        rules2014: [
          '| d100 | Effect |',
          '| :--- | :--- |',
          '| 01-02 | Roll on this table at start of turn. |',
          '| 03-04 | For next minute, you can see any invisible creature. |',
        ],
        rules2024: [
          '| d100 | Effect |',
          '| :--- | :--- |',
          '| 01-02 | Roll on this table at start of turn. |',
          '| 03-04 | For next minute, you can see any invisible creature. |',
        ],
        tags: ['Homebrew', 'Table', 'Rollable Tables'],
        linkedTableQuery: 'Wild Magic Surge Table',
        linkedTableLabel: 'Roll on Table',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DmRuleCard(
              item: rollableTableItem,
              edition: DmRulesEdition.v2014,
              isPinned: false,
              onTogglePin: () {},
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rollable'), findsOneWidget);
      expect(find.text('Roll on Table'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
    });

    testWidgets(
        'DmRuleCard renders static data tables without Table Roller button and shows Data Table badge',
        (tester) async {
      const dataTableItem = DmReferenceItem(
        id: 'armor-don-doff-table',
        title: 'Armor Donning & Doffing Table',
        category: DmCategory.tables,
        subCategory: 'Data & Reference Tables',
        summary: 'Data and reference table with 3 rows.',
        rules2014: [
          '| Armor | Don | Doff |',
          '| :--- | :--- | :--- |',
          '| Light | 1 min | 1 min |',
          '| Medium | 5 min | 1 min |',
          '| Heavy | 10 min | 5 min |',
        ],
        rules2024: [
          '| Armor | Don | Doff |',
          '| :--- | :--- | :--- |',
          '| Light | 1 min | 1 min |',
          '| Medium | 5 min | 1 min |',
          '| Heavy | 10 min | 5 min |',
        ],
        tags: ['Homebrew', 'Table', 'Data & Reference Tables'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DmRuleCard(
              item: dataTableItem,
              edition: DmRulesEdition.v2014,
              isPinned: false,
              onTogglePin: () {},
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data Table'), findsOneWidget);
      // Roller button must not be shown for reference data tables
      expect(find.text('Roll on Table'), findsNothing);
      expect(find.text('Open in Table Roller'), findsNothing);
      expect(find.byType(Table), findsOneWidget);
    });

    testWidgets(
        'DmRuleCard renders wide multi-column tables in narrow viewport with horizontal scrolling and no overflow',
        (tester) async {
      const wideRuleTableItem = DmReferenceItem(
        id: 'armor-comprehensive-table',
        title: 'Comprehensive Armor Matrix',
        category: DmCategory.tables,
        subCategory: 'Data & Reference Tables',
        summary: 'Full armor matrix with 6 columns.',
        rules2014: [
          '| Armor | Cost | AC | Strength | Stealth | Weight |',
          '| :--- | :--- | :--- | :--- | :--- | :--- |',
          '| Padded | 5 gp | 11 + Dex | — | Disadvantage | 8 lb. |',
          '| Plate | 1,500 gp | 18 | Str 15 | Disadvantage | 65 lb. |',
        ],
        rules2024: [
          '| Armor | Cost | AC | Strength | Stealth | Weight |',
          '| :--- | :--- | :--- | :--- | :--- | :--- |',
          '| Padded | 5 gp | 11 + Dex | — | Disadvantage | 8 lb. |',
          '| Plate | 1,500 gp | 18 | Str 15 | Disadvantage | 65 lb. |',
        ],
        tags: ['Homebrew', 'Table', 'Data & Reference Tables'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: DmRuleCard(
                  item: wideRuleTableItem,
                  edition: DmRulesEdition.v2014,
                  isPinned: false,
                  onTogglePin: () {},
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Table), findsOneWidget);

      final scrollableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(scrollableFinder, findsOneWidget);

      // Verify table width exceeds 320dp container
      final tableSize = tester.getSize(find.byType(Table));
      expect(tableSize.width, greaterThan(320.0));

      // Scroll left to right
      await tester.drag(scrollableFinder, const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(find.textContaining('65 lb.', findRichText: true), findsOneWidget);
    });

    testWidgets(
        'DmRuleComparisonDialog renders markdown tables with native Table widgets and no bullet prefixes',
        (tester) async {
      const comparisonTableItem = DmReferenceItem(
        id: 'exhaustion-comparison-table',
        title: 'Exhaustion Effects',
        category: DmCategory.conditions,
        summary: 'Exhaustion rules comparison',
        tags: ['Condition', 'Exhaustion'],
        isChangedIn2024: true,
        diffSummary:
            'Exhaustion was revised from 6 discrete tiers to a linear -2 penalty per level (max 10).',
        rules2014: [
          '| Level | Effect |',
          '| :--- | :--- |',
          '| 1 | Disadvantage on ability checks |',
          '| 2 | Speed halved |',
        ],
        rules2024: [
          '| Level | Effect |',
          '| :--- | :--- |',
          '| 1-10 | -2 to D20 Tests per level |',
          '| 10 | Death |',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  DmRuleComparisonDialog.show(
                    ctx,
                    item: comparisonTableItem,
                    isPinned: false,
                    onTogglePin: () {},
                  );
                },
                child: const Text('Open Comparison'),
              ),
            ),
          ),
        ),
      );

      // Open the comparison dialog
      await tester.tap(find.text('Open Comparison'));
      await tester.pumpAndSettle();

      // Expect 2 Table widgets rendered (one for 2014 edition box, one for 2024 edition box)
      expect(find.byType(Table), findsNWidgets(2));
      expect(
          find.textContaining('Disadvantage on ability checks',
              findRichText: true),
          findsOneWidget);
      expect(
          find.textContaining('-2 to D20 Tests per level', findRichText: true),
          findsOneWidget);

      // Verify no raw pipe bullets like "• | Level |" exist
      expect(find.textContaining('• |'), findsNothing);
    });
  });
}
