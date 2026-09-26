import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/room_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DiceRoomService Tests', () {
    test('generateRoomCode produces 6-character uppercase room format', () {
      final service = DiceRoomService();
      final code = service.generateRoomCode();

      expect(code, startsWith('ROOM-'));
      expect(code.length, 11); // 'ROOM-' (5) + 6 chars
    });

    test('broadcasting roll updates real-time stream subscriber', () async {
      final service = DiceRoomService();
      const roomCode = 'TEST-ROOM-99';

      final roll = RoomRoll(
        id: '1',
        roomCode: roomCode,
        playerName: 'Dain',
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
          return list.length == 1 &&
              list.first.playerName == 'Dain' &&
              list.first.total == 18;
        })),
      );

      await service.broadcastRoll(roll);
    });

    test(
        'joinRoom and leaveRoom manage active room session state and persistence',
        () {
      final service = DiceRoomService();
      expect(service.activeRoomCode, isNull);
      expect(service.playerName, isNull);

      service.joinRoom('room-42', 'Sylas', remember: true);
      expect(service.activeRoomCode, 'ROOM-42');
      expect(service.playerName, 'Sylas');
      expect(service.isSessionRemembered, isTrue);
      expect(service.activeSessionNotifier.value, isNotNull);

      service.leaveRoom();
      expect(service.activeRoomCode, isNull);
      expect(service.playerName, isNull);
      expect(service.isSessionRemembered, isFalse);
      expect(service.activeSessionNotifier.value, isNull);
    });

    test(
        'getCachedRolls returns rolls and streamRoomRolls immediately yields cached rolls',
        () async {
      final service = DiceRoomService.newInstance();
      const roomCode = 'ROOM-CACHE-1';

      final roll = RoomRoll(
        id: 'c-1',
        roomCode: roomCode,
        playerName: 'Kaelen',
        timestamp: DateTime.now(),
        formulaString: '1d12 + 4',
        total: 15,
        individualRolls: [11],
        isCrit: false,
        isFumble: false,
      );

      // Ingest roll into cache first
      service.ingestRemoteRoll(roll);

      // Verify synchronous getter returns roll immediately
      final cached = service.getCachedRolls(roomCode);
      expect(cached.length, 1);
      expect(cached.first.playerName, 'Kaelen');

      // Now create stream subscriber AFTER the roll was already ingested
      final stream = service.streamRoomRolls(roomCode);

      // The new subscriber must receive the cached roll immediately without needing a new roll event
      expectLater(
        stream,
        emits(predicate<List<RoomRoll>>((list) {
          return list.length == 1 &&
              list.first.id == 'c-1' &&
              list.first.playerName == 'Kaelen';
        })),
      );
    });

    test('rolls are persisted to SharedPreferences and restored upon room join',
        () async {
      final service = DiceRoomService.newInstance();
      const roomCode = 'ROOM-PERSIST-1';

      final roll = RoomRoll(
        id: 'p-1',
        roomCode: roomCode,
        playerName: 'Corin',
        timestamp: DateTime.now(),
        formulaString: '1d4',
        total: 3,
        individualRolls: [3],
        isCrit: false,
        isFumble: false,
      );

      await service.broadcastRoll(roll);
      await pumpEventQueue();

      // Check SharedPreferences raw value was written
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('dice_room_rolls_$roomCode');
      expect(saved, isNotNull);
      expect(saved, contains('Corin'));
      expect(saved, contains('p-1'));

      // Simulate a brand new service instance (app reload)
      final newService = DiceRoomService.newInstance();
      expect(newService.getCachedRolls(roomCode), isEmpty);

      // Joining the room should restore the rolls from disk
      newService.joinRoom(roomCode, 'Rowan');
      await pumpEventQueue();

      final restored = newService.getCachedRolls(roomCode);
      expect(restored.length, 1);
      expect(restored.first.playerName, 'Corin');
      expect(restored.first.total, 3);
    });
  });
}
