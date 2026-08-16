import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/spellbook_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestScreen({SettingsProvider? provider}) {
    final settingsProvider = provider ?? SettingsProvider();
    return SettingsScope(
      notifier: settingsProvider,
      child: const MaterialApp(
        home: SpellbookScreen(),
      ),
    );
  }

  group('SpellbookScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders search bar, view segments, and list of spells', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Spellbook Companion'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('All Spells'), findsOneWidget);
      expect(find.textContaining('My Spellbook'), findsOneWidget);
      expect(find.textContaining('2024 Diffs'), findsOneWidget);

      // Check iconic spells exist
      expect(find.text('Fireball'), findsOneWidget);
      expect(find.text('Cure Wounds'), findsOneWidget);
    });

    testWidgets('filters spells when entering query into search bar', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Fireball');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SpellCard, 'Fireball'), findsOneWidget);
      expect(find.widgetWithText(SpellCard, 'Cure Wounds'), findsNothing);

      // Clear search
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SpellCard, 'Cure Wounds'), findsOneWidget);
    });

    testWidgets('switches to My Spellbook tab and shows empty state until pinned', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Switch to Personal Spellbook tab
      await tester.tap(find.textContaining('My Spellbook'));
      await tester.pumpAndSettle();

      expect(find.text('Your Personal Spellbook is Empty'), findsOneWidget);

      // Switch back to All Spells and pin Fireball
      await tester.tap(find.textContaining('All Spells'));
      await tester.pumpAndSettle();

      final pinFireball = find.byTooltip('Pin to Personal Spellbook').first;
      await tester.tap(pinFireball);
      await tester.pumpAndSettle();

      // Switch to Personal Spellbook tab again
      await tester.tap(find.textContaining('My Spellbook'));
      await tester.pumpAndSettle();

      expect(find.text('Your Personal Spellbook is Empty'), findsNothing);
    });

    testWidgets('opens filter sheet and resets filters', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final filterButton = find.byTooltip('Filter Spells');
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      expect(find.text('Filter Spellbook'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);

      // Tap Reset All
      await tester.tap(find.text('Reset All'));
      await tester.pumpAndSettle();
    });

    testWidgets('displays newly added high-level spells and costly component badges', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Search for Wish
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Wish');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SpellCard, 'Wish'), findsOneWidget);
      expect(find.textContaining('9th Level'), findsOneWidget);

      // Search for Revivify with costly diamond component
      await tester.enterText(searchField, 'Revivify');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SpellCard, 'Revivify'), findsOneWidget);
      expect(find.textContaining('300 gp'), findsOneWidget);
    });
  });
}
