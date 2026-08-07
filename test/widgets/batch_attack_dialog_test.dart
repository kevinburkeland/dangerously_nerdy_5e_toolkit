import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animate_objects_5e/models/animated_object.dart';
import 'package:animate_objects_5e/models/spell_session.dart';
import 'package:animate_objects_5e/widgets/batch_attack_dialog.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('BatchAttackDialog renders batch attack title and living count', (WidgetTester tester) async {
    final session = SpellSession(spellLevel: 5);
    session.addObject(ObjectSize.tiny, customName: 'Coin #1');

    await tester.pumpWidget(createTestableWidget(BatchAttackDialog(session: session)));

    expect(find.text('Batch Attack Roller'), findsOneWidget);
    expect(find.text('Target AC'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'ROLL ALL 1 ATTACKS'), findsOneWidget);
  });

  testWidgets('BatchAttackDialog displays broadcasting status when room code is set', (WidgetTester tester) async {
    final session = SpellSession(spellLevel: 5);
    session.addObject(ObjectSize.tiny, customName: 'Coin #1');

    await tester.pumpWidget(
      createTestableWidget(
        BatchAttackDialog(
          session: session,
          activeRoomCode: 'DRAGON-99',
          playerName: 'Merlin',
        ),
      ),
    );

    expect(find.text('Broadcasting to Room: DRAGON-99'), findsOneWidget);
  });

  testWidgets('Tapping Roll Attacks produces batch summary results', (WidgetTester tester) async {
    final session = SpellSession(spellLevel: 5);
    session.addObject(ObjectSize.tiny, customName: 'Coin #1');

    await tester.pumpWidget(
      createTestableWidget(
        BatchAttackDialog(
          session: session,
          activeRoomCode: 'DRAGON-99',
          playerName: 'Merlin',
        ),
      ),
    );

    final rollButton = find.widgetWithText(ElevatedButton, 'ROLL ALL 1 ATTACKS');
    await tester.tap(rollButton);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL DAMAGE'), findsOneWidget);
    expect(find.text('HITS'), findsOneWidget);
  });
}
