import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dice_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/room_roll.dart';

void main() {
  group('RoomRoll Model Serialization Tests', () {
    test('fromDiceRollResult creates valid RoomRoll object', () {
      final diceResult = DiceRollResult.roll(
        dieType: DieType.d20,
        count: 1,
        modifier: 5,
        rollMode: RollMode.advantage,
      );

      final roomRoll = RoomRoll.fromDiceRollResult(
        id: 'roll_123',
        roomCode: 'ROOM-TEST',
        playerName: 'Gandalf',
        result: diceResult,
      );

      expect(roomRoll.id, 'roll_123');
      expect(roomRoll.roomCode, 'ROOM-TEST');
      expect(roomRoll.playerName, 'Gandalf');
      expect(roomRoll.total, diceResult.total);
      expect(roomRoll.formulaString, diceResult.formulaString);
    });

    test('toMap and fromMap JSON serialization roundtrip works', () {
      final original = RoomRoll(
        id: 'r1',
        roomCode: 'MAGIC-42',
        playerName: 'Legolas',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        formulaString: '2d6 + 4',
        total: 12,
        individualRolls: [4, 4],
        droppedRolls: null,
        isCrit: false,
        isFumble: false,
      );

      final map = original.toMap();
      final restored = RoomRoll.fromMap(map);

      expect(restored.id, 'r1');
      expect(restored.roomCode, 'MAGIC-42');
      expect(restored.playerName, 'Legolas');
      expect(restored.total, 12);
      expect(restored.individualRolls, [4, 4]);
      expect(restored.formulaString, '2d6 + 4');
    });
  });
}
