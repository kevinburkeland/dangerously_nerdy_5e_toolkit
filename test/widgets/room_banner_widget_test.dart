import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('Tapping Join / Create Room opens dialog modal', (WidgetTester tester) async {
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
  });
}
