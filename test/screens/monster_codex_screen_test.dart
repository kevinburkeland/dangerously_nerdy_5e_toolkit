import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/monster_codex_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/monster_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestScreen({SettingsProvider? provider}) {
    final settingsProvider = provider ?? SettingsProvider();
    return SettingsScope(
      notifier: settingsProvider,
      child: const MaterialApp(
        home: MonsterCodexScreen(),
      ),
    );
  }

  group('MonsterCodexScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders codex title, search, view segments, and monster cards',
        (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Monster Codex'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('All Monsters'), findsOneWidget);
      expect(find.textContaining('My Bestiary'), findsOneWidget);
      expect(find.textContaining('2024 Diffs'), findsOneWidget);
      expect(find.textContaining('entries'), findsOneWidget);
      expect(find.byType(MonsterCard), findsWidgets);
    });

    testWidgets('filters list with search query', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Air Elemental');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(MonsterCard, 'Air Elemental'), findsOneWidget);
      expect(find.byType(MonsterCard), findsOneWidget);

      // Clear search
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.byType(MonsterCard), findsWidgets);
    });

    testWidgets('applies CR-band chips with search filtering', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('CR 0-1/4'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Air Elemental');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(MonsterCard, 'Air Elemental'), findsNothing);
      expect(find.text('No Monsters Found'), findsOneWidget);

      final cr5to8 = find.textContaining('CR 5-8');
      await tester.ensureVisible(cr5to8);
      await tester.tap(cr5to8);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(MonsterCard, 'Air Elemental'), findsOneWidget);
    });

    testWidgets('shows CR band counts and enables CR 9+ legendary band',
        (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('All CR ('), findsOneWidget);

      final chipFinder = find.textContaining('CR 9+ (');
      await tester.ensureVisible(chipFinder);
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Bone Devil'), findsOneWidget);
      expect(find.byType(MonsterCard), findsWidgets);
    });

    testWidgets(
        'switches to My Bestiary tab and shows empty state until pinned',
        (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Switch to My Bestiary tab
      await tester.tap(find.textContaining('My Bestiary'));
      await tester.pumpAndSettle();

      expect(find.text('Your Personal Bestiary is Empty'), findsOneWidget);

      // Switch back to All Monsters and pin the first creature
      await tester.tap(find.textContaining('All Monsters'));
      await tester.pumpAndSettle();

      final pinButton = find.byTooltip('Pin to My Bestiary').first;
      await tester.tap(pinButton);
      await tester.pumpAndSettle();

      // Switch to My Bestiary tab again
      await tester.tap(find.textContaining('My Bestiary'));
      await tester.pumpAndSettle();

      expect(find.text('Your Personal Bestiary is Empty'), findsNothing);
      expect(find.byType(MonsterCard), findsOneWidget);
    });

    testWidgets('opens filter sheet and resets filters', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final filterButton = find.byTooltip('Filter Bestiary');
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Filter & Sort Monster Codex'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);

      // Tap Reset All
      await tester.tap(find.text('Reset All'));
      await tester.pumpAndSettle();

      // Close filter sheet
      final applyButton = find.text('Apply Filters');
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(find.byType(MonsterCard), findsWidgets);
    });

    testWidgets('supports sorting by DPR and alphabetical order from filter sheet',
        (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Open filter & sort sheet
      final filterButton = find.byTooltip('Filter Bestiary');
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      // Verify Sort Order options
      expect(find.text('Sort Order'), findsOneWidget);
      expect(find.text('DPR: High to Low'), findsOneWidget);
      expect(find.text('Name: A to Z'), findsOneWidget);

      // Select DPR: High to Low
      await tester.tap(find.text('DPR: High to Low'));
      await tester.pumpAndSettle();

      // Apply
      final applyButton = find.text('Apply Filters');
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Verify DPR tier header is visible
      expect(find.textContaining('Strike'), findsWidgets);
      expect(find.byType(MonsterCard), findsWidgets);

      // Re-open and switch to Alphabetical
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Name: A to Z'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Verify Letter header is visible
      expect(find.textContaining('Letter'), findsWidgets);
    });

    testWidgets('switches to 2024 Diffs tab and opens MonsterComparisonDialog',
        (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Switch to 2024 Diffs tab
      final diffTab = find.textContaining('2024 Diffs');
      expect(diffTab, findsOneWidget);
      await tester.tap(diffTab);
      await tester.pumpAndSettle();

      expect(find.byType(MonsterCard), findsWidgets);
      expect(find.text('2024 Diff'), findsWidgets);

      // Tap 2024 Diff badge to open MonsterComparisonDialog
      await tester.tap(find.text('2024 Diff').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('2024 REVISED RULES DIFF HIGHLIGHTS'), findsOneWidget);
      expect(find.textContaining('2024 Revised View'), findsOneWidget);

      // Toggle Compare Diff / Single View
      final compareButton = find.text('Compare Diff');
      if (compareButton.evaluate().isNotEmpty) {
        await tester.tap(compareButton);
        await tester.pumpAndSettle();
        expect(find.textContaining('2014 RAW RULES'), findsOneWidget);
        expect(find.textContaining('2024 REVISED RULES'), findsWidgets);
      }

      // Close dialog
      await tester.tap(find.byTooltip('Close comparison dialog'));
      await tester.pumpAndSettle();
    });
  });
}

