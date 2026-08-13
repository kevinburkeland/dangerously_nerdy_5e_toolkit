import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/minion_tool_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dice_roller_screen.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('LandingScreen renders branding, headers, and individual tool cards', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    expect(find.text('DangerouslyNerdy 5e Toolkit'), findsOneWidget);
    expect(find.text('Select a Tool'), findsOneWidget);

    // Section headers
    expect(find.text('🔮 SPELL MINION COMPANIONS'), findsOneWidget);
    expect(find.text('📯 MAGIC ITEM ROLLERS & MINIONS'), findsOneWidget);
    expect(find.text('🎲 CORE UTILITIES'), findsOneWidget);

    // Dedicated tool cards
    expect(find.text('Animate Objects'), findsOneWidget);
    expect(find.text('Conjure Animals'), findsOneWidget);
    expect(find.text('Bag of Tricks'), findsOneWidget);
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

  testWidgets('Tapping Bag of Tricks launches Bag of Tricks tool screen', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final bagCard = find.text('Bag of Tricks');
    expect(bagCard, findsOneWidget);

    await tester.ensureVisible(bagCard);
    await tester.pumpAndSettle();

    await tester.tap(bagCard);
    await tester.pumpAndSettle();

    expect(find.byType(MinionToolScreen), findsOneWidget);
    expect(find.text('Bag of Tricks Roller'), findsOneWidget);
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
}
