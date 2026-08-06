import 'package:flutter_test/flutter_test.dart';
import 'package:animate_objects_5e/models/dice_roll.dart';

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
  });
}
