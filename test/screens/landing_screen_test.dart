import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animate_objects_5e/screens/landing_screen.dart';
import 'package:animate_objects_5e/screens/animate_objects_screen.dart';
import 'package:animate_objects_5e/screens/dice_roller_screen.dart';

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

    expect(find.text('Animate Objects 5e'), findsOneWidget);
    expect(find.text('Dice Roller'), findsOneWidget);
  });

  testWidgets('Tapping Animate Objects 5e launches AnimateObjectsScreen', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const LandingScreen()));

    final animateObjectsCard = find.text('Animate Objects 5e');
    expect(animateObjectsCard, findsOneWidget);

    await tester.tap(animateObjectsCard);
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
