import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_card.dart';

void main() {
  group('SpellCard Widget Tests', () {
    testWidgets('renders spell details, 2024 diff badge, and handles pin/roll clicks', (tester) async {
      final trueStrike = SpellbookLibrary.getSpellById('spell_true_strike')!;
      bool pinToggled = false;
      bool cardTapped = false;
      String? rolledFormula;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpellCard(
              spell: trueStrike,
              edition: DmRulesEdition.v2024,
              isPinned: false,
              onTogglePin: () => pinToggled = true,
              onTap: () => cardTapped = true,
              onQuickRoll: (formula, label) => rolledFormula = formula,
            ),
          ),
        ),
      );

      expect(find.text('True Strike'), findsOneWidget);
      expect(find.text('Cantrip Divination'), findsOneWidget);
      expect(find.text('2024 Diff'), findsOneWidget);

      // Pin button
      final pinButton = find.byTooltip('Pin to Personal Spellbook');
      expect(pinButton, findsOneWidget);
      await tester.tap(pinButton);
      expect(pinToggled, isTrue);

      // Tap card
      await tester.tap(find.text('True Strike'));
      expect(cardTapped, isTrue);

      // Quick roll button if present
      final rollButton = find.text('1d6 Radiant (at 5th lvl)');
      if (rollButton.evaluate().isNotEmpty) {
        await tester.tap(rollButton);
        expect(rolledFormula, contains('1d6'));
      }
    });
  });
}
