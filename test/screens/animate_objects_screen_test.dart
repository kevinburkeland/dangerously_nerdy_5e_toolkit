import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animate_objects_5e/screens/animate_objects_screen.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('AnimateObjectsScreen loads with default 10 Tiny silver coins preset', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const AnimateObjectsScreen()));

    expect(find.text('Animate Objects 5e'), findsOneWidget);
    expect(find.text('Active Squad'), findsOneWidget);
    expect(find.text('Spell Rules'), findsOneWidget);

    // Initial budget: 10 / 10 points used, 10 Objects
    expect(find.text('Point Budget: 10 / 10 points used'), findsOneWidget);
    expect(find.text('10 Objects'), findsOneWidget);
    expect(find.text('Silver Coin #1'), findsOneWidget);
  });

  testWidgets('Switching tabs displays Spell Rules', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const AnimateObjectsScreen()));

    final spellRulesTab = find.text('Spell Rules');
    await tester.tap(spellRulesTab);
    await tester.pumpAndSettle();

    expect(find.textContaining('5th-level Transmutation'), findsOneWidget);
  });

  testWidgets('Tapping BATCH ATTACK opens attack dialog', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const AnimateObjectsScreen()));

    final batchAttackBtn = find.text('BATCH ATTACK');
    expect(batchAttackBtn, findsOneWidget);

    await tester.tap(batchAttackBtn);
    await tester.pumpAndSettle();

    expect(find.text('Batch Attack Roller'), findsOneWidget);
    expect(find.textContaining('ROLL ALL'), findsOneWidget);
  });
}
