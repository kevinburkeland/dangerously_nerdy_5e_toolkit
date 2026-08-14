import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/creature_stat_block_dialog.dart';

void main() {
  group('CreatureStatBlockDialog Tests', () {
    testWidgets('renders full 5e SRD stat block fields for Wolf', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatureStatBlockDialog(
              statBlock: SrdSummonsLibrary.wolf,
            ),
          ),
        ),
      );

      // Verify header and core stats
      expect(find.text('5E SRD CREATURE STAT BLOCK'), findsOneWidget);
      expect(find.text('Wolf'), findsOneWidget);
      expect(find.text('Medium beast, unaligned'), findsOneWidget);
      expect(find.text('STR'), findsOneWidget);
      expect(find.text('12 (+1)'), findsWidgets); // STR, CON, WIS
      expect(find.text('15 (+2)'), findsOneWidget); // DEX
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);
    });

    testWidgets('renders elemental traits and special actions for Fire Elemental', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatureStatBlockDialog(
              statBlock: SrdSummonsLibrary.fireElemental,
            ),
          ),
        ),
      );

      expect(find.text('Fire Elemental'), findsOneWidget);
      expect(find.text('Large elemental, neutral'), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);
    });

    testWidgets('onAddToSquad callback fires when ADD TO SQUAD tapped', (WidgetTester tester) async {
      bool added = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatureStatBlockDialog(
              statBlock: SrdSummonsLibrary.skeleton,
              onAddToSquad: () {
                added = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('ADD TO SQUAD'), findsOneWidget);
      await tester.tap(find.text('ADD TO SQUAD'));
      await tester.pumpAndSettle();

      expect(added, isTrue);
    });
  });
}
