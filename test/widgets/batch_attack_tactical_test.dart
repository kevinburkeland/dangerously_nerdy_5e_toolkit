import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spell_session.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/batch_attack_dialog.dart';

void main() {
  testWidgets('BatchAttackDialog toggles tactical modifiers and updates roll mode', (WidgetTester tester) async {
    final session = SpellSession(activePreset: SrdSummonsLibrary.allPresets.first);
    session.addObject(ObjectSize.tiny, customName: 'Coin 1');
    session.addObject(ObjectSize.tiny, customName: 'Coin 2');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatchAttackDialog(session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Batch Attack Roller'), findsOneWidget);
    expect(find.text('Tactical Combat Conditions'), findsOneWidget);

    // Expand Tactical Conditions accordion
    await tester.tap(find.text('Tactical Combat Conditions'));
    await tester.pumpAndSettle();

    expect(find.text('Target Prone (Melee)'), findsOneWidget);
    expect(find.text('Pack Tactics (Ally 5ft)'), findsOneWidget);
    expect(find.text('Target Stunned/Restrained'), findsOneWidget);
    expect(find.text('Attacker Poisoned/Blinded'), findsOneWidget);

    // Tap Target Prone -> activates Advantage
    await tester.tap(find.text('Target Prone (Melee)'));
    await tester.pumpAndSettle();

    expect(find.text('Advantage Active'), findsOneWidget);

    // Tap Attacker Poisoned -> Cancels out Advantage (Normal)
    await tester.tap(find.text('Attacker Poisoned/Blinded'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled Out'), findsOneWidget);
  });
}
