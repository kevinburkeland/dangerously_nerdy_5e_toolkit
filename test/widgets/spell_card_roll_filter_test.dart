import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_card.dart';

void main() {
  group('SpellCard Roll Filter Tests', () {
    testWidgets('Renders quick roll button when spell has a valid roll formula (Fireball)', (tester) async {
      final fireball = SpellbookLibrary.getSpellById('fireball');
      expect(fireball, isNotNull);

      bool rollOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpellCard(
              spell: fireball!,
              edition: DmRulesEdition.v2024,
              isPinned: false,
              onTogglePin: () {},
              onTap: () {},
              onOpenQuickRoll: () => rollOpened = true,
            ),
          ),
        ),
      );

      expect(find.text('8d6'), findsOneWidget);
      expect(find.byIcon(Icons.casino), findsOneWidget);

      await tester.tap(find.text('8d6'));
      await tester.pump();
      expect(rollOpened, isTrue);
    });

    testWidgets('Does NOT render quick roll button when spell has no roll formula (Shield)', (tester) async {
      final shield = SpellbookLibrary.getSpellById('shield');
      expect(shield, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpellCard(
              spell: shield!,
              edition: DmRulesEdition.v2024,
              isPinned: false,
              onTogglePin: () {},
              onTap: () {},
              onOpenQuickRoll: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.casino), findsNothing);
      expect(find.text('Shield'), findsOneWidget);
    });
  });
}
