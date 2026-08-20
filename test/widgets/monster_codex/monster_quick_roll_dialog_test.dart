import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/monster_quick_roll_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonsterQuickRollDialog Multiattack Tests', () {
    testWidgets('resolves and executes multiattack with multiple strikes and combined damage',
        (tester) async {
      final dragon = MonsterCodexLibrary.allMonsters.firstWhere(
        (m) => m.actions.any((a) => a.name.toLowerCase().contains('multiattack')),
        orElse: () => MonsterCodexLibrary.allMonsters.first,
      );

      final multiAction = dragon.actions.firstWhere(
        (a) => a.name.toLowerCase().contains('multiattack'),
      );

      MonsterActionResult? receivedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MonsterQuickRollDialog.show(
                  context,
                  monster: dragon,
                  initialAction: multiAction,
                  onRollCompleted: (res, name) => receivedResult = res,
                ),
                child: const Text('Open Multiattack'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Multiattack'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Action & Attack Roller'), findsOneWidget);
      expect(find.textContaining('Roll Multiattack'), findsOneWidget);

      // Execute Multiattack Roll
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(receivedResult, isNotNull);
      expect(receivedResult!.isMultiattack, isTrue);
      expect(receivedResult!.attackRolls.length, greaterThanOrEqualTo(2));
      expect(find.textContaining('MULTIATTACK'), findsWidgets);
      expect(find.textContaining('dmg'), findsWidgets);
    });
  });
}
