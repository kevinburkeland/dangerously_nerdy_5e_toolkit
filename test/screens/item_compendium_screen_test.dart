import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/item_compendium_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/rules_edition_toggle.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/item_compendium/item_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/item_compendium/item_comparison_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestScreen({SettingsProvider? provider, DmRulesEdition? edition}) {
    final settingsProvider = provider ?? SettingsProvider();
    return SettingsScope(
      notifier: settingsProvider,
      child: MaterialApp(
        home: ItemCompendiumScreen(initialEdition: edition),
      ),
    );
  }

  group('ItemCompendiumScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders search bar, view segments, and list of items', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Magic Item Compendium'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('All Items'), findsOneWidget);
      expect(find.textContaining('Personal Reliquary'), findsOneWidget);
      expect(find.textContaining('2024 Diffs'), findsOneWidget);

      // Check items exist
      expect(find.text('Longsword'), findsOneWidget);
      expect(find.text('Greatsword'), findsOneWidget);
    });

    testWidgets('filters items when entering query into search bar', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Flame Tongue');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ItemCard, 'Flame Tongue'), findsOneWidget);
      expect(find.widgetWithText(ItemCard, 'Frost Brand'), findsNothing);

      // Clear search
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ItemCard, 'Longsword'), findsOneWidget);
    });

    testWidgets('switches to Personal Reliquary tab and shows empty state until pinned', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final reliquarySegment = find.descendant(
        of: find.byType(SegmentedButton<ItemCompendiumViewMode>),
        matching: find.textContaining('Personal Reliquary'),
      );

      final allItemsSegment = find.descendant(
        of: find.byType(SegmentedButton<ItemCompendiumViewMode>),
        matching: find.textContaining('All Items'),
      );

      // Switch to Personal Reliquary tab
      await tester.tap(reliquarySegment);
      await tester.pumpAndSettle();

      expect(find.text('Your Personal Reliquary is empty'), findsOneWidget);

      // Switch back to All Items and pin Weapon +1
      await tester.tap(allItemsSegment);
      await tester.pumpAndSettle();

      final pinButton = find.byTooltip('Pin to Personal Reliquary').first;
      await tester.tap(pinButton);
      await tester.pumpAndSettle();

      // Switch to Personal Reliquary tab again
      await tester.tap(reliquarySegment);
      await tester.pumpAndSettle();

      expect(find.text('Your Personal Reliquary is empty'), findsNothing);
      expect(find.widgetWithText(ItemCard, 'Longsword'), findsOneWidget);
    });

    testWidgets('switches to 2024 Diffs view mode and opens ItemComparisonDialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final diffsSegment = find.descendant(
        of: find.byType(SegmentedButton<ItemCompendiumViewMode>),
        matching: find.textContaining('2024 Diffs'),
      );

      // Switch to 2024 Diffs
      await tester.tap(diffsSegment);
      await tester.pumpAndSettle();

      // Verify diff items appear (e.g. Longsword with 2024 Sap Weapon Mastery)
      expect(find.widgetWithText(ItemCard, 'Longsword'), findsOneWidget);

      // Tap the 2024 Diff badge to open comparison dialog
      final diffBadge = find.text('2024 Diff').first;
      await tester.tap(diffBadge);
      await tester.pumpAndSettle();

      expect(find.byType(ItemComparisonDialog), findsOneWidget);
      expect(find.text('2014 RAW Rules'), findsOneWidget);
      expect(find.text('2024 Revised Rules'), findsOneWidget);

      // Close dialog
      final closeButton = find.byIcon(Icons.close);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(ItemComparisonDialog), findsNothing);
    });

    testWidgets('toggles rules edition between 2014 and 2024', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen(edition: DmRulesEdition.v2014));
      await tester.pumpAndSettle();

      expect(find.textContaining('2014 SRD magic items'), findsOneWidget);

      final editionToggle = find.byType(RulesEditionToggle);
      expect(editionToggle, findsOneWidget);

      await tester.tap(editionToggle);
      await tester.pumpAndSettle();

      expect(find.textContaining('2024 SRD magic items'), findsOneWidget);
    });

    testWidgets('opens filter sheet and applies item filters', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final filterButton = find.byTooltip('Filter Magic Items');
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      expect(find.text('Filter Magic Items'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);

      // Tap Reset All
      await tester.tap(find.text('Reset All'));
      await tester.pumpAndSettle();

      expect(find.byType(ItemCard), findsWidgets);
    });
  });
}
