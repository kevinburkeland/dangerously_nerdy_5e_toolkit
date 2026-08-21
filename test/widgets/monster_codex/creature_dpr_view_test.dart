import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/creature_dpr_view.dart';

void main() {
  group('CreatureDprView Widget Tests', () {
    testWidgets('renders DPR calculations and Pack Tactics badge for Wolf', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreatureDprView(
              statBlock: SrdSummonsLibrary.wolf,
            ),
          ),
        ),
      );

      // Verify Pack Tactics badge is displayed for Wolf
      expect(find.textContaining('Pack Tactics'), findsWidgets);

      // Verify Hero card header and DPR unit
      expect(find.text('EXPECTED DAMAGE / ROUND'), findsOneWidget);
      expect(find.text('DPR'), findsWidgets);

      // Verify Combat controls
      expect(find.text('Target Armor Class: '), findsOneWidget);
      expect(find.text('AC 15'), findsWidgets);
      expect(find.text('Normal (1d20)'), findsOneWidget);
      expect(find.text('Advantage'), findsOneWidget);
      expect(find.text('Disadvantage'), findsOneWidget);

      // Verify Routine breakdown
      expect(find.text('ATTACK ROUTINE IN ROUND'), findsOneWidget);
      expect(find.text('Bite'), findsOneWidget);

      // Verify AC Benchmark Curve
      expect(find.text('AC BENCHMARK CURVE'), findsOneWidget);
      expect(find.text('Standard (AC 15)'), findsOneWidget);
      expect(find.text('Heavy/Shield (AC 18)'), findsOneWidget);
    });

    testWidgets('supports switching target AC chips and stepping AC +/-', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreatureDprView(
              statBlock: SrdSummonsLibrary.wolf,
            ),
          ),
        ),
      );

      // Tap AC 18 chip
      await tester.tap(find.text('AC 18'));
      await tester.pumpAndSettle();

      expect(find.text('Target AC 18'), findsOneWidget);

      // Tap decrease AC button
      await tester.tap(find.byTooltip('Decrease AC'));
      await tester.pumpAndSettle();

      expect(find.text('Target AC 17'), findsOneWidget);

      // Tap increase AC button twice
      await tester.tap(find.byTooltip('Increase AC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Increase AC'));
      await tester.pumpAndSettle();

      expect(find.text('Target AC 19'), findsOneWidget);
    });

    testWidgets('supports toggling roll modifiers (Normal, Advantage, Disadvantage)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreatureDprView(
              statBlock: SrdSummonsLibrary.skeleton,
            ),
          ),
        ),
      );

      // Tap Disadvantage
      await tester.tap(find.text('Disadvantage'));
      await tester.pumpAndSettle();

      // Tap Normal
      await tester.tap(find.text('Normal (1d20)'));
      await tester.pumpAndSettle();

      // Tap Advantage
      await tester.tap(find.text('Advantage'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders Multiattack routine with multiple actions for Brown Bear', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreatureDprView(
              statBlock: SrdSummonsLibrary.brownBear,
            ),
          ),
        ),
      );

      expect(find.text('Bite'), findsOneWidget);
      expect(find.text('Claws'), findsOneWidget);

      // Add another bite to the turn routine
      final addButtons = find.byTooltip('Add one attack');
      expect(addButtons, findsWidgets);

      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('3 attacks in turn'), findsOneWidget);
    });
  });
}
