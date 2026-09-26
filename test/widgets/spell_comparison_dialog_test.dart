import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_comparison_dialog.dart';

void main() {
  group('SpellComparisonDialog Widget Tests', () {
    testWidgets(
        'shows only the active rules edition unless diff mode is toggled',
        (tester) async {
      final spell = SpellbookLibrary.getSpellById('spell_counterspell')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SpellComparisonDialog.show(
                    context,
                    spell: spell,
                    edition: DmRulesEdition.v2014,
                    isPinned: false,
                    onTogglePin: () {},
                  );
                },
                child: const Text('Open 2014 Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open 2014 Dialog'));
      await tester.pump();

      expect(find.text('Counterspell'), findsOneWidget);
      expect(find.text('2014 (5e RAW)'), findsOneWidget);
      expect(find.text('2024 (Revised 5e)'), findsNothing);

      if (find.text('View Diff').evaluate().isNotEmpty) {
        await tester.tap(find.text('View Diff'));
        await tester.pump();
        expect(find.text('2024 (Revised 5e)'), findsOneWidget);
      }
    });

    testWidgets('renders side-by-side 2014 vs 2024 comparison and toggles pin',
        (tester) async {
      final counterspell = SpellbookLibrary.getSpellById('spell_counterspell')!;
      bool pinToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SpellComparisonDialog.show(
                    context,
                    spell: counterspell,
                    edition: DmRulesEdition.v2024,
                    isPinned: false,
                    onTogglePin: () => pinToggled = true,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();

      expect(find.text('Counterspell'), findsOneWidget);
      expect(find.textContaining('2024 Revised View'), findsOneWidget);
      expect(find.text('2024 (Revised 5e)'), findsOneWidget);
      expect(find.text('2014 (5e RAW)'), findsNothing);

      if (find.text('View Diff').evaluate().isNotEmpty) {
        await tester.tap(find.text('View Diff'));
        await tester.pump();
        expect(find.text('2014 (5e RAW)'), findsOneWidget);
        expect(find.text('2024 (Revised 5e)'), findsOneWidget);
      }

      // Diff summary exists
      expect(find.textContaining('Constitution saving throw'), findsWidgets);

      // Pin button inside dialog
      final pinButton = find.byTooltip('Pin to Personal Spellbook');
      expect(pinButton, findsOneWidget);
      await tester.tap(pinButton);
      expect(pinToggled, isTrue);

      // Close dialog
      final closeButton = find.byTooltip('Close comparison dialog');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump();

      expect(find.text('Counterspell'), findsNothing);
    });
  });
}
