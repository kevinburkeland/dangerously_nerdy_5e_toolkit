import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_comparison_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_dpr_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpellDprView Widget & Math Tests', () {
    testWidgets('renders SpellDprView for Fireball with upcasting controls and AoE multiplier', (tester) async {
      final fireball = SpellbookLibrary.getSpellByName('Fireball');
      expect(fireball, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpellDprView(
              spell: fireball!,
              edition: DmRulesEdition.v2024,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header damage info
      expect(find.textContaining('EXPECTED OUTPUT'), findsOneWidget);
      expect(find.textContaining('AVG DMG'), findsOneWidget);
      expect(find.textContaining('8d6 Fire'), findsOneWidget);
      expect(find.textContaining('2 targets'), findsWidgets);

      // Verify upcast chips
      expect(find.text('Level 3 (Base)'), findsOneWidget);
      expect(find.text('Level 4'), findsOneWidget);
      expect(find.text('Level 5'), findsOneWidget);

      // Tap Level 5 upcast chip
      await tester.tap(find.text('Level 5'));
      await tester.pumpAndSettle();

      // Fireball at 5th level is 10d6 (3rd: 8d6, 4th: 9d6, 5th: 10d6)
      expect(find.textContaining('10d6 Fire'), findsOneWidget);
    });

    testWidgets('SpellComparisonDialog displays Damage / DPR tab for damaging spells', (tester) async {
      final fireball = SpellbookLibrary.getSpellByName('Fireball');
      expect(fireball, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  SpellComparisonDialog.show(
                    ctx,
                    spell: fireball!,
                    edition: DmRulesEdition.v2024,
                    isPinned: false,
                    onTogglePin: () {},
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify tabs exist
      expect(find.text('Spell Details'), findsOneWidget);
      expect(find.text('Damage / DPR'), findsOneWidget);

      // Switch to Damage / DPR tab
      await tester.tap(find.text('Damage / DPR'));
      await tester.pumpAndSettle();

      expect(find.byType(SpellDprView), findsOneWidget);
    });
  });
}
