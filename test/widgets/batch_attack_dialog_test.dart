import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spell_session.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/batch_attack_dialog.dart';

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
    final roomService = DiceRoomService();
    roomService.joinRoom('DRAGON-99', 'Merlin');

    await tester.pumpWidget(
      createTestableWidget(
        BatchAttackDialog(
          session: session,
          roomService: roomService,
        ),
      ),
    );

    expect(find.text('Broadcasting to Room: DRAGON-99'), findsOneWidget);
  });

  testWidgets('Tapping Roll Attacks produces batch summary results', (WidgetTester tester) async {
    final session = SpellSession(spellLevel: 5);
    session.addObject(ObjectSize.tiny, customName: 'Coin #1');
    final roomService = DiceRoomService();
    roomService.joinRoom('DRAGON-99', 'Merlin');

    await tester.pumpWidget(
      createTestableWidget(
        BatchAttackDialog(
          session: session,
          roomService: roomService,
        ),
      ),
    );

    final rollButton = find.widgetWithText(ElevatedButton, 'ROLL ALL 1 ATTACKS');
    await tester.tap(rollButton);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL DAMAGE'), findsOneWidget);
    expect(find.text('HITS'), findsOneWidget);
  });

  testWidgets('BatchAttackDialog renders cleanly on mobile screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final session = SpellSession(spellLevel: 5);
    for (int i = 1; i <= 5; i++) {
      session.addObject(ObjectSize.tiny, customName: 'Silver Coin #$i with a very long name');
    }
    final roomService = DiceRoomService();
    roomService.joinRoom('MOBILE-99', 'Mobile Player Merlin');

    await tester.pumpWidget(
      createTestableWidget(
        BatchAttackDialog(
          session: session,
          roomService: roomService,
        ),
      ),
    );

    expect(find.text('Batch Attack Roller'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final rollButton = find.byType(ElevatedButton).first;
    await tester.tap(rollButton);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL DAMAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
