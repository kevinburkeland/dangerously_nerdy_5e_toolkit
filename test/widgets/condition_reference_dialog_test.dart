import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/condition_reference_dialog.dart';

void main() {
  Widget createTestWidget() {
    return const MaterialApp(
      home: Scaffold(
        body: ConditionReferenceDialog(),
      ),
    );
  }

  testWidgets('ConditionReferenceDialog displays conditions and categories', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('5e Status Effects & Conditions'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Incapacitating'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Movement'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Combat / Checks'), findsOneWidget);

    expect(find.widgetWithText(Card, 'Blinded'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Charmed'), findsOneWidget);
  });

  testWidgets('ConditionReferenceDialog filter category chips work', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Select "Movement" category
    await tester.tap(find.widgetWithText(FilterChip, 'Movement'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Card, 'Grappled'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Prone'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Restrained'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Blinded'), findsNothing);

    // Scroll to and select "Exhaustion" category
    final exhaustionChip = find.widgetWithText(FilterChip, 'Exhaustion');
    await tester.ensureVisible(exhaustionChip);
    await tester.tap(exhaustionChip);
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsOneWidget);
    expect(find.widgetWithText(Card, 'Grappled'), findsNothing);
  });

  testWidgets('ConditionReferenceDialog toggles between 2014 and 2024 editions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Select Exhaustion category so card is front and center
    final exhaustionChip = find.widgetWithText(FilterChip, 'Exhaustion');
    await tester.ensureVisible(exhaustionChip);
    await tester.tap(exhaustionChip);
    await tester.pumpAndSettle();

    // Default 2024: Exhaustion shows cumulative 10 total levels
    expect(find.textContaining('Cumulative penalty across 10 total levels'), findsOneWidget);

    // Switch to 2014
    await tester.tap(find.text('2014'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Level 1: Disadvantage on ability checks'), findsOneWidget);
  });

  testWidgets('ConditionReferenceDialog search filters conditions by name or mechanic', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Search "Critical Hit"
    await tester.enterText(find.byType(TextField), 'Critical Hit');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Card, 'Paralyzed'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Unconscious'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Blinded'), findsNothing);
  });
}
