import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_comparison_dialog.dart';

void main() {
  group('SpellComparisonDialog Widget Tests', () {
    testWidgets('renders side-by-side 2014 vs 2024 comparison and toggles pin', (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.text('Counterspell'), findsOneWidget);
      expect(find.textContaining('2014 vs 2024 Comparison'), findsOneWidget);
      expect(find.text('2014 (5e RAW)'), findsOneWidget);
      expect(find.text('2024 (Revised 5e)'), findsOneWidget);

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
      await tester.pumpAndSettle();

      expect(find.text('Counterspell'), findsNothing);
    });
  });
}
