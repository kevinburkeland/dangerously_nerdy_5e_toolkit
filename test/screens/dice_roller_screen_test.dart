import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/room_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dice_roller_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('DiceRollerScreen displays die choices and initial state', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    expect(find.text('Dice Roller'), findsOneWidget);
    expect(find.text('Select Die'), findsOneWidget);
    expect(find.text('D20'), findsWidgets);
    expect(find.text('D6'), findsOneWidget);
    expect(find.text('CUSTOM (d7)'), findsOneWidget);

    expect(find.text('Tap ROLL to roll the dice!'), findsOneWidget);
  });

  testWidgets('Tapping ROLL generates a result and populates Roll History', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    // Tap ROLL button
    final rollButton = find.widgetWithText(ElevatedButton, 'ROLL 1D20');
    expect(rollButton, findsOneWidget);

    await tester.ensureVisible(rollButton);
    await tester.tap(rollButton);
    await tester.pumpAndSettle();

    // Initial hint text is gone
    expect(find.text('Tap ROLL to roll the dice!'), findsNothing);

    // History section is present
    expect(find.text('Roll History'), findsOneWidget);
    expect(find.text('1 rolls'), findsOneWidget);
  });

  testWidgets('Increasing quantity updates ROLL button text', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    // Add quantity
    final addIcon = find.byIcon(Icons.add_circle_outline).first;
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'ROLL 2D20'), findsOneWidget);
  });

  testWidgets('Switching die to d6 updates ROLL button text', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    final d6Chip = find.text('D6');
    await tester.tap(d6Chip);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'ROLL 1D6'), findsOneWidget);
  });

  testWidgets('Building a multi-dice pool combines multiple dice types', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    // Tap D6 (replaces initial 1d20 with 1d6)
    final d6Chip = find.text('D6');
    await tester.tap(d6Chip);
    await tester.pumpAndSettle();

    // Tap D8 (adds 1d8 to the pool -> 1d6 + 1d8)
    final d8Chip = find.text('D8');
    await tester.tap(d8Chip);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'ROLL 1D6 + 1D8'), findsOneWidget);
  });

  testWidgets('Opening Custom Die dialog adds custom sided die to pool', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const DiceRollerScreen()));

    // Tap Custom Die chip
    final customChip = find.text('CUSTOM (d7)');
    await tester.tap(customChip);
    await tester.pumpAndSettle();

    // Dialog title
    expect(find.text('Custom Sided Die'), findsOneWidget);

    // Enter 14
    final textField = find.byType(TextField);
    await tester.enterText(textField, '14');
    await tester.pumpAndSettle();

    // Tap Add Die
    final addDieButton = find.widgetWithText(ElevatedButton, 'Add Die');
    await tester.tap(addDieButton);
    await tester.pumpAndSettle();

    // Roll button now shows 1d14
    expect(find.widgetWithText(ElevatedButton, 'ROLL 1D14'), findsOneWidget);
  });

  testWidgets('Joining a room in DiceRollerScreen immediately activates Live Feed without manual state trigger', (WidgetTester tester) async {
    final roomService = DiceRoomService();
    roomService.leaveRoom();

    await tester.pumpWidget(createTestableWidget(
      DiceRollerScreen(roomService: roomService),
    ));

    // Initially no live feed
    expect(find.textContaining('Live Feed:'), findsNothing);

    // Join room via room service
    roomService.joinRoom('ROOM-ALPHA', 'Frodo');
    await tester.pumpAndSettle();

    // Live room feed appears immediately without requiring any other user interaction
    expect(find.text('Live Feed: ROOM-ALPHA'), findsOneWidget);
    expect(find.text('Real-Time Sync'), findsOneWidget);

    roomService.leaveRoom();
    await tester.pumpAndSettle();

    expect(find.textContaining('Live Feed:'), findsNothing);
  });

  testWidgets('LiveRoomRollFeed renders batch roll and toggles to-hit papertrail', (WidgetTester tester) async {
    final roomService = DiceRoomService();
    roomService.leaveRoom();
    roomService.joinRoom('ROOM-BETA', 'Gimli');

    await tester.pumpWidget(createTestableWidget(
      DiceRollerScreen(roomService: roomService),
    ));

    // Broadcast a batch attack roll with details
    final batchRoll = RoomRoll(
      id: 'batch_test_1',
      roomCode: 'ROOM-BETA',
      playerName: 'Gimli',
      timestamp: DateTime.now(),
      formulaString: 'Batch Attack (2/2 Hits vs AC 14)',
      total: 18,
      individualRolls: [9, 9],
      details: [
        'Axe #1 (Small): d20 [16] + 5 = 21 vs AC 14 [HIT] -> 9 dmg',
        'Axe #2 (Small): d20 [19] + 5 = 24 vs AC 14 [HIT] -> 9 dmg',
      ],
      isCrit: false,
      isFumble: false,
    );

    await roomService.broadcastRoll(batchRoll);
    await tester.pumpAndSettle();

    expect(find.text('Batch Attack (2/2 Hits vs AC 14)'), findsOneWidget);
    expect(find.text('Papertrail (2)'), findsOneWidget);
    expect(find.text('To-Hit & Damage Papertrail:'), findsNothing);

    // Scroll to and tap Papertrail toggle
    await tester.ensureVisible(find.text('Papertrail (2)'));
    await tester.tap(find.text('Papertrail (2)'));
    await tester.pumpAndSettle();

    // Papertrail is now expanded
    expect(find.text('To-Hit & Damage Papertrail:'), findsOneWidget);
    expect(find.textContaining('Axe #1 (Small): d20 [16] + 5 = 21 vs AC 14 [HIT] -> 9 dmg'), findsOneWidget);
    expect(find.textContaining('Axe #2 (Small): d20 [19] + 5 = 24 vs AC 14 [HIT] -> 9 dmg'), findsOneWidget);

    // Scroll to and tap Hide
    await tester.ensureVisible(find.text('Hide'));
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();

    expect(find.text('To-Hit & Damage Papertrail:'), findsNothing);

    roomService.leaveRoom();
  });
}

