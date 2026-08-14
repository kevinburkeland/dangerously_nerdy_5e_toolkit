import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/action_economy_dialog.dart';

void main() {
  Widget createTestWidget() {
    return const MaterialApp(
      home: Scaffold(
        body: ActionEconomyDialog(),
      ),
    );
  }

  testWidgets('ActionEconomyDialog renders tabs and actions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('5e Combat Action Economy'), findsOneWidget);
    expect(find.text('1 Action (Standard)'), findsOneWidget);
    expect(find.text('Bonus Action'), findsOneWidget);
    expect(find.text('Reaction'), findsOneWidget);
    expect(find.text('Cover Rules'), findsOneWidget);

    // Standard action items visible
    expect(find.text('Attack & Weapon Swapping'), findsOneWidget);
    expect(find.text('Dash'), findsOneWidget);
    expect(find.text('Disengage'), findsOneWidget);
  });

  testWidgets('ActionEconomyDialog search filters combat actions dynamically', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Type "Dodge" into search bar
    await tester.enterText(find.byType(TextField), 'Dodge');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Card, 'Dodge'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Dash'), findsNothing);
    expect(find.widgetWithText(Card, 'Attack & Weapon Swapping'), findsNothing);

    // Clear search
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Card, 'Dash'), findsOneWidget);
  });

  testWidgets('ActionEconomyDialog switches to Bonus Action and Reaction tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Bonus Action tab
    await tester.tap(find.text('Bonus Action'));
    await tester.pumpAndSettle();

    expect(find.text('Drink or Administer a Potion (2024)'), findsOneWidget);
    expect(find.text('Bonus Action Spells'), findsOneWidget);

    // Tap Reaction tab
    await tester.tap(find.text('Reaction'));
    await tester.pumpAndSettle();

    expect(find.text('Opportunity Attack'), findsOneWidget);
    expect(find.text('Reaction Spells'), findsOneWidget);
  });

  testWidgets('ActionEconomyDialog toggles to 2014 edition', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Default 2024: Attack card is "Attack & Weapon Swapping"
    expect(find.text('Attack & Weapon Swapping'), findsOneWidget);

    // Toggle 2014
    await tester.tap(find.text('2014'));
    await tester.pumpAndSettle();

    // In 2014: Attack card title is "Attack"
    expect(find.text('Attack'), findsOneWidget);
    expect(find.text('Attack & Weapon Swapping'), findsNothing);
  });
}
