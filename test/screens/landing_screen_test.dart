import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/minion_tool_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dice_roller_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/monster_codex_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('LandingScreen renders branding, headers, and individual tool cards with DndGlyphs', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    expect(find.text('DangerouslyNerdy 5e Toolkit'), findsOneWidget);
    expect(find.text('Select a Tool'), findsOneWidget);
    expect(find.byType(DndGlyph), findsWidgets);

    // Hero quick launch badges
    expect(find.text('Bestiary Codex'), findsOneWidget);
    expect(find.text('Magic Items'), findsOneWidget);
    expect(find.text('Combat DPR'), findsOneWidget);
    expect(find.text('Dice & Party'), findsOneWidget);
    expect(find.text('Glyph Studio'), findsOneWidget);

    // Section headers
    expect(find.text('🔮 SPELL MINION COMPANIONS'), findsOneWidget);
    expect(find.text('📯 MAGIC ITEM ROLLERS & MINIONS'), findsOneWidget);
    expect(find.text('🎲 CORE UTILITIES'), findsOneWidget);

    // Dedicated tool cards
    expect(find.text('Animate Objects'), findsOneWidget);
    expect(find.text('Conjure Animals'), findsOneWidget);
    expect(find.text('Gray Bag of Tricks'), findsOneWidget);
    expect(find.text('Horn of Valhalla'), findsOneWidget);
    expect(find.text('Dice Roller & Party Rooms'), findsOneWidget);
  });

  testWidgets('Tapping Animate Objects launches Animate Objects tool screen', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final minionCard = find.text('Animate Objects');
    expect(minionCard, findsOneWidget);

    await tester.ensureVisible(minionCard);
    await tester.pumpAndSettle();

    await tester.tap(minionCard);
    await tester.pumpAndSettle();

    expect(find.byType(MinionToolScreen), findsOneWidget);
    expect(find.text('Animate Objects Companion'), findsOneWidget);
    expect(find.text('Active Squad'), findsOneWidget);
  });

  testWidgets('Tapping Conjure Animals launches Conjure Animals tool screen with 8 Wolves', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final conjureAnimalsCard = find.text('Conjure Animals');
    expect(conjureAnimalsCard, findsOneWidget);

    await tester.ensureVisible(conjureAnimalsCard);
    await tester.pumpAndSettle();

    await tester.tap(conjureAnimalsCard);
    await tester.pumpAndSettle();

    expect(find.byType(MinionToolScreen), findsOneWidget);
    expect(find.text('Conjure Animals Squad Manager'), findsOneWidget);
    expect(find.text('8 Objects'), findsOneWidget);
    expect(find.text('Wolf #1'), findsOneWidget);
  });

  testWidgets('Tapping Create Undead launches Create Undead tool screen with 3 Ghouls', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final createUndeadCard = find.text('Create Undead');
    expect(createUndeadCard, findsOneWidget);

    await tester.ensureVisible(createUndeadCard);
    await tester.pumpAndSettle();

    await tester.tap(createUndeadCard);
    await tester.pumpAndSettle();

    expect(find.byType(MinionToolScreen), findsOneWidget);
    expect(find.text('Create Undead Manager'), findsOneWidget);
    expect(find.text('3 Objects'), findsOneWidget);
    expect(find.text('Ghoul #1'), findsOneWidget);
  });

  testWidgets('Tapping Gray Bag of Tricks launches Gray Bag of Tricks tool screen', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final bagCard = find.text('Gray Bag of Tricks');
    expect(bagCard, findsOneWidget);

    await tester.ensureVisible(bagCard);
    await tester.pumpAndSettle();

    await tester.tap(bagCard);
    await tester.pumpAndSettle();

    expect(find.byType(MinionToolScreen), findsOneWidget);
    expect(find.text('Gray Bag of Tricks Roller'), findsOneWidget);
  });

  testWidgets('Tapping Dice Roller & Party Rooms launches DiceRollerScreen', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final diceRollerCard = find.text('Dice Roller & Party Rooms');
    expect(diceRollerCard, findsOneWidget);

    await tester.ensureVisible(diceRollerCard);
    await tester.pumpAndSettle();

    await tester.tap(diceRollerCard);
    await tester.pumpAndSettle();

    expect(find.byType(DiceRollerScreen), findsOneWidget);
    expect(find.text('Select Die'), findsOneWidget);
  });

  testWidgets('Tapping Monster Codex launches MonsterCodexScreen', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final codexCard = find.text('Monster Codex');
    expect(codexCard, findsOneWidget);

    await tester.ensureVisible(codexCard);
    await tester.pumpAndSettle();

    await tester.tap(codexCard);
    await tester.pumpAndSettle();

    expect(find.byType(MonsterCodexScreen), findsOneWidget);
    expect(find.text('Monster Codex'), findsOneWidget);
    expect(find.textContaining('entries'), findsOneWidget);
  });

  testWidgets('Entering search query filters tools dynamically and shows result count', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    // Search for "wolves"
    await tester.enterText(searchField, 'wolves');
    await tester.pumpAndSettle();

    // Results header shows 1 match
    expect(find.text('🔍 SEARCH RESULTS (1)'), findsOneWidget);
    expect(find.text('Conjure Animals'), findsOneWidget);
    expect(find.text('Animate Objects'), findsNothing);
    expect(find.text('Dice Roller & Party Rooms'), findsNothing);
  });

  testWidgets('Entering non-matching search query shows empty state with Clear Search button', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'spaceship');
    await tester.pumpAndSettle();

    expect(find.text('🔍 SEARCH RESULTS (0)'), findsOneWidget);
    expect(find.text('No tools found matching "spaceship"'), findsOneWidget);

    // Tap Clear Search button
    final clearButton = find.widgetWithText(ElevatedButton, 'Clear Search');
    expect(clearButton, findsOneWidget);
    await tester.ensureVisible(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    // Categories restored
    expect(find.text('🔮 SPELL MINION COMPANIONS'), findsOneWidget);
    expect(find.text('Animate Objects'), findsOneWidget);
  });
}
