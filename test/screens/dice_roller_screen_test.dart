import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animate_objects_5e/screens/dice_roller_screen.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('DiceRollerScreen displays die choices and initial state', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    expect(find.text('Dice Roller'), findsOneWidget);
    expect(find.text('Select Die'), findsOneWidget);
    expect(find.text('D20'), findsOneWidget);
    expect(find.text('D6'), findsOneWidget);

    expect(find.text('Tap ROLL to roll the dice!'), findsOneWidget);
  });

  testWidgets('Tapping ROLL generates a result and populates Roll History', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    // Tap ROLL button
    final rollButton = find.widgetWithText(ElevatedButton, 'ROLL 1D20');
    expect(rollButton, findsOneWidget);

    await tester.ensureVisible(rollButton);
    await tester.tap(rollButton);
    await tester.pumpAndSettle();

    // Initial hint text is gone
    expect(find.text('Tap ROLL to roll the dice!'), findsNothing);

    // History section is present
    expect(find.text('Roll History'), findsOneWidget);
    expect(find.text('1 rolls'), findsOneWidget);
  });

  testWidgets('Increasing quantity updates ROLL button text', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    // Add quantity
    final addIcon = find.byIcon(Icons.add_circle_outline).first;
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'ROLL 2D20'), findsOneWidget);
  });

  testWidgets('Switching die to d6 updates ROLL button text', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    final d6Chip = find.text('D6');
    await tester.tap(d6Chip);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'ROLL 1D6'), findsOneWidget);
  });
}
