import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_screen_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('DmScreenScreen Widget Tests', () {
    testWidgets('renders DM Screen with title, quick roller, and cards', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmScreenScreen()));

      expect(find.text("DM's Screen"), findsOneWidget);
      expect(find.text('Quick Roller:'), findsOneWidget);
      expect(find.text('d20'), findsOneWidget);
      expect(find.text('d100'), findsOneWidget);
      expect(find.text('All Rules'), findsOneWidget);

      // Verify some cards are rendered
      expect(find.text('Attack Action & Extra Attack'), findsOneWidget);
      expect(find.text('Exhaustion (Fatigue)'), findsOneWidget);
    });

    testWidgets('toggling between 2014 and 2024 updates rule display', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmScreenScreen(initialEdition: DmRulesEdition.v2024)));

      expect(find.text('Active: 2024 Revised'), findsOneWidget);
      expect(find.text('2024 Revised 5e Rulebook'), findsOneWidget);

      // Tap 2014 button
      final btn2014 = find.text('2014');
      expect(btn2014, findsOneWidget);
      await tester.tap(btn2014);
      await tester.pumpAndSettle();

      expect(find.text('Active: 2014 5e RAW'), findsOneWidget);
      expect(find.text('2014 (SRD 5.1 RAW) Rulebook'), findsOneWidget);
    });

    testWidgets('filtering by search query filters cards dynamically', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmScreenScreen()));

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Exhaustion');
      await tester.pumpAndSettle();

      expect(find.text('Exhaustion (Fatigue)'), findsOneWidget);
      expect(find.text('Attack Action & Extra Attack'), findsNothing);
    });

    testWidgets('tapping quick dice rolls a result and displays banner', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmScreenScreen()));

      final d20Btn = find.text('d20');
      await tester.tap(d20Btn);
      await tester.pumpAndSettle();

      expect(find.textContaining('d20: '), findsOneWidget);
    });

    testWidgets('tapping card opens Compare 2014 vs 2024 dialog', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmScreenScreen()));

      final attackCard = find.text('Attack Action & Extra Attack');
      expect(attackCard, findsOneWidget);

      await tester.tap(attackCard);
      await tester.pumpAndSettle();

      expect(find.text('2014 vs 2024 Rule Comparison'), findsOneWidget);
      expect(find.text('2014 (5e RAW)'), findsOneWidget);
      expect(find.text('2024 (Revised 5e)'), findsOneWidget);

      // Close dialog
      final closeBtn = find.byIcon(Icons.close);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.text('2014 vs 2024 Rule Comparison'), findsNothing);
    });

    testWidgets('LandingScreen launches DmScreenScreen from card and AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const LandingScreen()));

      // Find DM screen tool card
      final dmCard = find.text("DM's Screen & Rulebook");
      expect(dmCard, findsOneWidget);

      await tester.ensureVisible(dmCard);
      await tester.pumpAndSettle();

      await tester.tap(dmCard);
      await tester.pumpAndSettle();

      expect(find.byType(DmScreenScreen), findsOneWidget);
      expect(find.text("DM's Screen"), findsOneWidget);
    });
  });
}
