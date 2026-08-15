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

    test('RoomRoll with to-hit attack details preserves papertrail in JSON serialization', () {
      final batchRoll = RoomRoll(
        id: 'batch_99',
        roomCode: 'ARENA-1',
        playerName: 'Aragorn',
        timestamp: DateTime.now(),
        formulaString: 'Batch Attack (8/10 Hits vs AC 15)',
        total: 42,
        individualRolls: [6, 4, 8, 5, 0, 7, 6, 0, 6],
        details: [
          'Silver Coin #1: d20 [18] + 8 = 26 vs AC 15 [HIT] -> 6 dmg',
          'Silver Coin #2: d20 [20] -> MAX CRIT! -> 8 dmg',
          'Silver Coin #3: d20 [4] + 8 = 12 vs AC 15 [MISS]',
        ],
        isCrit: true,
        isFumble: false,
      );

      final map = batchRoll.toMap();
      final restored = RoomRoll.fromMap(map);

      expect(restored.id, 'batch_99');
      expect(restored.details, isNotNull);
      expect(restored.details!.length, 3);
      expect(restored.details!.first, contains('Silver Coin #1: d20 [18]'));
      expect(restored.details![1], contains('MAX CRIT!'));
    });
  });
}
