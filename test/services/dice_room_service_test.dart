import 'package:flutter_test/flutter_test.dart';
import 'package:animate_objects_5e/models/room_roll.dart';
import 'package:animate_objects_5e/services/dice_room_service.dart';

void main() {
  group('DiceRoomService Tests', () {
    test('generateRoomCode produces 4-character uppercase room format', () {
      final service = DiceRoomService();
      final code = service.generateRoomCode();

      expect(code, startsWith('ROOM-'));
      expect(code.length, 9); // 'ROOM-' (5) + 4 chars
    });

    test('broadcasting roll updates real-time stream subscriber', () async {
      final service = DiceRoomService();
      const roomCode = 'TEST-ROOM-99';

      final roll = RoomRoll(
        id: '1',
        roomCode: roomCode,
        playerName: 'Gimli',
        timestamp: DateTime.now(),
        formulaString: '1d20 + 3',
        total: 18,
        individualRolls: [15],
        isCrit: false,
        isFumble: false,
      );

      final stream = service.streamRoomRolls(roomCode);

      expectLater(
        stream,
        emits(predicate<List<RoomRoll>>((list) {
          return list.length == 1 && list.first.playerName == 'Gimli' && list.first.total == 18;
        })),
      );

      await service.broadcastRoll(roll);
    });

    test('joinRoom and leaveRoom manage active room session state reactively', () {
      final service = DiceRoomService();
      expect(service.activeRoomCode, isNull);
      expect(service.playerName, isNull);

      service.joinRoom('room-42', 'Legolas');
      expect(service.activeRoomCode, 'ROOM-42');
      expect(service.playerName, 'Legolas');
      expect(service.activeSessionNotifier.value, isNotNull);

      service.leaveRoom();
      expect(service.activeRoomCode, isNull);
      expect(service.playerName, isNull);
      expect(service.activeSessionNotifier.value, isNull);
    });
  });
}

