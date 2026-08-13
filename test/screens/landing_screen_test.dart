import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/animate_objects_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dice_roller_screen.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('LandingScreen renders branding and tool cards', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    expect(find.text('DangerouslyNerdy 5e Toolkit'), findsOneWidget);
    expect(find.text('Select a Tool'), findsOneWidget);

    expect(find.text('5e Minion Squad Manager'), findsOneWidget);
    expect(find.text('Dice Roller'), findsOneWidget);
  });

  testWidgets('Tapping 5e Minion Squad Manager launches AnimateObjectsScreen', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final minionCard = find.text('5e Minion Squad Manager');
    expect(minionCard, findsOneWidget);

    await tester.tap(minionCard);
    await tester.pumpAndSettle();

    expect(find.byType(AnimateObjectsScreen), findsOneWidget);
    expect(find.text('Active Squad'), findsOneWidget);
  });

  testWidgets('Tapping Dice Roller launches DiceRollerScreen', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final diceRollerCard = find.text('Dice Roller');
    expect(diceRollerCard, findsOneWidget);

    await tester.tap(diceRollerCard);
    await tester.pumpAndSettle();

    expect(find.byType(DiceRollerScreen), findsOneWidget);
    expect(find.text('Select Die'), findsOneWidget);
  });
}
