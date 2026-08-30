import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_stat_calculator.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/interactive_roll_action_card.dart';

void main() {
  group('InteractiveRollActionCard Widget Tests', () {
    testWidgets('Renders weapon name, to-hit bonus, and damage formula with rollable semantics', (tester) async {
      const profile = ComputedAttackProfile(
        weaponName: 'Longsword +1',
        attackBonus: 7,
        attackBonusString: '+7',
        damageFormula: '1d8 + 4',
        damageType: DamageType.slashing,
        range: '5 ft',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveRollActionCard(
              attack: profile,
              characterName: 'Valeros',
            ),
          ),
        ),
      );

      expect(find.text('Longsword +1'), findsOneWidget);
      expect(find.text('+7'), findsOneWidget);
      expect(find.text('1d8 + 4'), findsOneWidget);

      // Tap to-hit roll button
      await tester.tap(find.text('+7'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap damage roll button
      await tester.tap(find.text('1d8 + 4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
