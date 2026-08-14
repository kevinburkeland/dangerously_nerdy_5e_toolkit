import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/dice_formatters.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/dnd_5e_rules_engine.dart';

void main() {
  group('DiceFormatters Tests', () {
    test('formatBonus formats positive, negative, and zero values correctly', () {
      expect(DiceFormatters.formatBonus(3), '+3');
      expect(DiceFormatters.formatBonus(-2), '-2');
      expect(DiceFormatters.formatBonus(0), '');
      expect(DiceFormatters.formatBonus(0, includeZero: true), '+0');
    });

    test('formatFormula formats complete dice expressions with damage types', () {
      expect(DiceFormatters.formatFormula(count: 1, sides: 4, bonus: 4, damageType: 'Bludgeoning'), '1d4+4 Bludgeoning');
      expect(DiceFormatters.formatFormula(count: 2, sides: 6, bonus: -1, damageType: 'Slashing'), '2d6-1 Slashing');
      expect(DiceFormatters.formatFormula(count: 8, sides: 6), '8d6');
      expect(DiceFormatters.formatFormula(count: 1, sides: 20, bonus: 5), '1d20+5');
    });
  });

  group('Dnd5eScoreMath and Dnd5eRulesEngine Tests', () {
    test('dndModifier calculates accurate 5e modifiers', () {
      expect(10.dndModifier, 0);
      expect(11.dndModifier, 0);
      expect(12.dndModifier, 1);
      expect(13.dndModifier, 1);
      expect(18.dndModifier, 4);
      expect(20.dndModifier, 5);
      expect(9.dndModifier, -1);
      expect(8.dndModifier, -1);
      expect(1.dndModifier, -5);
    });

    test('dndModifierString formats signed modifier strings', () {
      expect(18.dndModifierString, '+4');
      expect(10.dndModifierString, '+0');
      expect(8.dndModifierString, '-1');
    });

    test('dndProficiencyBonus scales according to 5e tiers', () {
      expect(1.dndProficiencyBonus, 2);
      expect(4.dndProficiencyBonus, 2);
      expect(5.dndProficiencyBonus, 3);
      expect(8.dndProficiencyBonus, 3);
      expect(9.dndProficiencyBonus, 4);
      expect(13.dndProficiencyBonus, 5);
      expect(17.dndProficiencyBonus, 6);
      expect(20.dndProficiencyBonus, 6);
    });
  });
}

