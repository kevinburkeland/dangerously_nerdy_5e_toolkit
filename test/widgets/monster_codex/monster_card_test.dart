import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/monster_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/monster_quick_roll_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMonster = MonsterCodexLibrary.allMonsters.first;

  group('MonsterCard Widget Tests', () {
    testWidgets('renders creature name, glyph, stat chips, and preset badge',
        (tester) async {
      bool pinned = false;
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonsterCard(
              monster: testMonster,
              isPinned: pinned,
              onTogglePin: () => pinned = !pinned,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(testMonster.name), findsOneWidget);
      expect(find.byType(DndGlyph), findsOneWidget);
      expect(find.textContaining('CR '), findsOneWidget);
      expect(find.textContaining('AC '), findsOneWidget);
      expect(find.textContaining('HP '), findsOneWidget);
      expect(find.text(testMonster.sourcePresetName), findsOneWidget);

      // Tap card
      await tester.tap(find.byType(MonsterCard));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      // Tap pin
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      expect(pinned, isTrue);
    });

    testWidgets('opens quick roll dialog and executes roll', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MonsterQuickRollDialog.show(
                  context,
                  monster: testMonster,
                ),
                child: const Text('Open Roller'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Roller'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Action & Attack Roller'), findsOneWidget);
      expect(find.textContaining('Roll '), findsWidgets);

      // Tap roll button
      final rollButton = find.widgetWithText(FilledButton, find.textContaining('Roll ').evaluate().last.widget.toString().contains('Roll') ? 'Roll ${testMonster.actions.first.name}' : 'Roll Action');
      if (rollButton.evaluate().isNotEmpty) {
        await tester.tap(rollButton);
      } else {
        await tester.tap(find.byType(FilledButton));
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('To Hit:'), findsOneWidget);
    });
  });
}
