import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_quick_roll_dialog.dart';

void main() {
  group('SpellQuickRollDialog Widget Tests', () {
    testWidgets('shows SnackBar error when formula is not dice notation',
        (tester) async {
      const badDetails = SpellEditionDetails(
        castingTime: '1 Action',
        range: '30 feet',
        components: 'V, S',
        duration: 'Instantaneous',
        description: ['Fires a burst of unparsed fire.'],
        classes: [SpellClass.wizard],
        rollFormula: '2d6 fire',
      );

      const testSpell = SpellItem(
        id: 'test_bad_roll_spell',
        name: 'Invalid Roll Spell',
        level: 1,
        school: SpellSchool.evocation,
        rules2014: badDetails,
        rules2024: badDetails,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SpellQuickRollDialog.show(
                    context,
                    spell: testSpell,
                    edition: DmRulesEdition.v2024,
                  );
                },
                child: const Text('Open Quick Roll'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Quick Roll'));
      await tester.pumpAndSettle();

      expect(find.byType(SpellQuickRollDialog), findsOneWidget);

      final rollButton = find.text('ROLL SPELL');
      expect(rollButton, findsOneWidget);

      await tester.tap(rollButton);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Can\'t roll "2d6 fire"'),
        findsOneWidget,
      );
    });
  });
}
