import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dice_roll.dart';

void main() {
  group('DiceRollResult Model Tests', () {
    test('Standard single d6 roll produces result within range [1, 6]', () {
      for (int i = 0; i < 50; i++) {
        final result = DiceRollResult.roll(dieType: DieType.d6, count: 1);
        expect(result.count, 1);
        expect(result.modifier, 0);
        expect(result.individualRolls.length, 1);
        expect(result.individualRolls.first, greaterThanOrEqualTo(1));
        expect(result.individualRolls.first, lessThanOrEqualTo(6));
        expect(result.total, result.individualRolls.first);
      }
    });

    test('Multi-dice roll with modifier calculates correct total', () {
      final result = DiceRollResult.roll(
        dieType: DieType.d6,
        count: 8,
        modifier: 4,
      );

      expect(result.individualRolls.length, 8);
      int rollSum = result.individualRolls.fold(0, (acc, val) => acc + val);
      expect(result.total, rollSum + 4);
      expect(result.formulaString, '8d6 + 4');
    });

    test('Negative modifier formula formatting', () {
      final result = DiceRollResult.roll(
        dieType: DieType.d20,
        count: 1,
        modifier: -2,
      );

      expect(result.formulaString, '1d20 - 2');
    });

    test('Advantage roll keeps highest die and stores dropped die', () {
      for (int i = 0; i < 50; i++) {
        final result = DiceRollResult.roll(
          dieType: DieType.d20,
          count: 1,
          modifier: 0,
          rollMode: RollMode.advantage,
        );

        expect(result.individualRolls.length, 1);
        expect(result.droppedRolls, isNotNull);
        expect(result.droppedRolls!.length, 1);
        expect(result.individualRolls.first, greaterThanOrEqualTo(result.droppedRolls!.first));
        expect(result.formulaString, contains('(Adv)'));
      }
    });

    test('Disadvantage roll keeps lowest die and stores dropped die', () {
      for (int i = 0; i < 50; i++) {
        final result = DiceRollResult.roll(
          dieType: DieType.d20,
          count: 1,
          modifier: 0,
          rollMode: RollMode.disadvantage,
        );

        expect(result.individualRolls.length, 1);
        expect(result.droppedRolls, isNotNull);
        expect(result.droppedRolls!.length, 1);
        expect(result.individualRolls.first, lessThanOrEqualTo(result.droppedRolls!.first));
        expect(result.formulaString, contains('(Dis)'));
      }
    });

    test('Custom sided die rolls within expected range [1, customSides]', () {
      for (int i = 0; i < 50; i++) {
        final result = DiceRollResult.roll(
          dieType: DieType.custom,
          count: 2,
          customSides: 7,
          modifier: 3,
        );

        expect(result.individualRolls.length, 2);
        for (final roll in result.individualRolls) {
          expect(roll, greaterThanOrEqualTo(1));
          expect(roll, lessThanOrEqualTo(7));
        }
        int sum = result.individualRolls.fold(0, (acc, val) => acc + val);
        expect(result.total, sum + 3);
        expect(result.formulaString, '2d7 + 3');
      }
    });

    test('Multi-dice pool roll combines multiple different die types correctly', () {
      final pool = [
        DiceEntry(dieType: DieType.d6, count: 2),
        DiceEntry(dieType: DieType.d8, count: 1),
        DiceEntry(dieType: DieType.custom, count: 1, customSides: 14),
      ];

      final result = DiceRollResult.rollPool(
        diceEntries: pool,
        modifier: 5,
      );

      expect(result.diceEntries.length, 3);
      expect(result.groupResults.length, 3);
      expect(result.individualRolls.length, 4); // 2 + 1 + 1 = 4 rolls
      expect(result.groupResults[0].rolls.length, 2);
      expect(result.groupResults[1].rolls.length, 1);
      expect(result.groupResults[2].rolls.length, 1);

      int sum = result.individualRolls.fold(0, (acc, val) => acc + val);
      expect(result.total, sum + 5);
      expect(result.formulaString, '2d6 + 1d8 + 1d14 + 5');
    });

    test('DiceEntry clamps count to [1, 100] and customSides to [2, 1000]', () {
      final entryOverflow = DiceEntry(dieType: DieType.custom, count: 999, customSides: 9999);
      expect(entryOverflow.count, 100);
      expect(entryOverflow.customSides, 1000);

      final entryUnderflow = DiceEntry(dieType: DieType.custom, count: -10, customSides: -5);
      expect(entryUnderflow.count, 1);
      expect(entryUnderflow.customSides, 2);
    });
  });
}

