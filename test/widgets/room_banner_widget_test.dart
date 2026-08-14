import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/room_banner_widget.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('RoomBannerWidget renders Solo Mode when disconnected', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(
        activeRoomCode: null,
        playerName: null,
        onJoinRoom: (r, p) {},
        onLeaveRoom: () {},
      ),
    ));

    expect(find.text('Solo Mode'), findsOneWidget);
    expect(find.text('Join / Create Room'), findsOneWidget);
  });

  testWidgets('RoomBannerWidget renders Room Code and Player Name when connected', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(
        activeRoomCode: 'ROOM-1234',
        playerName: 'Gandalf',
        onJoinRoom: (r, p) {},
        onLeaveRoom: () {},
      ),
    ));

    expect(find.text('ROOM-1234'), findsOneWidget);
    expect(find.text('Player: Gandalf'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
  });

  testWidgets('Tapping Join / Create Room opens dialog modal and handles cancel action', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(
        activeRoomCode: null,
        playerName: null,
        onJoinRoom: (r, p) {},
        onLeaveRoom: () {},
      ),
    ));

    await tester.tap(find.text('Join / Create Room'));
    await tester.pumpAndSettle();

    expect(find.text('Shared Dice Room'), findsOneWidget);
    expect(find.text('Your Display Name'), findsOneWidget);
    expect(find.text('Room Code'), findsOneWidget);
    expect(find.text('Enter Room'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Shared Dice Room'), findsNothing);
  });

  testWidgets('RoomBannerWidget updates automatically when DiceRoomService session changes', (WidgetTester tester) async {
    final roomService = DiceRoomService();
    roomService.leaveRoom();

    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(roomService: roomService),
    ));

    expect(find.text('Solo Mode'), findsOneWidget);

    roomService.joinRoom('ROOM-TEST99', 'Aragorn');
    await tester.pumpAndSettle();

    expect(find.text('ROOM-TEST99'), findsOneWidget);
    expect(find.text('Player: Aragorn'), findsOneWidget);

    roomService.leaveRoom();
    await tester.pumpAndSettle();

    expect(find.text('Solo Mode'), findsOneWidget);
  });

  testWidgets('JoinCreateRoomDialog submits and joins room when Enter key is pressed', (WidgetTester tester) async {
    final roomService = DiceRoomService();
    roomService.leaveRoom();

    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(roomService: roomService),
    ));

    await tester.tap(find.text('Join / Create Room'));
    await tester.pumpAndSettle();

    // Enter name
    await tester.enterText(find.widgetWithText(TextField, 'Your Display Name'), 'Legolas');
    // Enter room code and submit via Enter (onSubmitted)
    await tester.enterText(find.widgetWithText(TextField, 'Room Code'), 'ROOM-ELVEN');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('ROOM-ELVEN'), findsOneWidget);
    expect(find.text('Player: Legolas'), findsOneWidget);
    expect(roomService.activeRoomCode, 'ROOM-ELVEN');
    expect(roomService.playerName, 'Legolas');

    roomService.leaveRoom();
  });
}
