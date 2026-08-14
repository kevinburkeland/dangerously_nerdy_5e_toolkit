import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/dnd_5e_rules_engine.dart';

void main() {
  group('Dnd5eRulesEngine Tests', () {
    test('Ability Modifier calculation matches 5e RAW floor((score-10)/2)', () {
      expect(Dnd5eRulesEngine.calculateModifier(1), -5);
      expect(Dnd5eRulesEngine.calculateModifier(3), -4);
      expect(Dnd5eRulesEngine.calculateModifier(8), -1);
      expect(Dnd5eRulesEngine.calculateModifier(9), -1);
      expect(Dnd5eRulesEngine.calculateModifier(10), 0);
      expect(Dnd5eRulesEngine.calculateModifier(11), 0);
      expect(Dnd5eRulesEngine.calculateModifier(12), 1);
      expect(Dnd5eRulesEngine.calculateModifier(13), 1);
      expect(Dnd5eRulesEngine.calculateModifier(14), 2);
      expect(Dnd5eRulesEngine.calculateModifier(18), 4);
      expect(Dnd5eRulesEngine.calculateModifier(20), 5);
      expect(Dnd5eRulesEngine.calculateModifier(24), 7);
      expect(Dnd5eRulesEngine.calculateModifier(30), 10);
    });

    test('Proficiency Bonus scales correctly from Level 1 to 20', () {
      // Level 1-4: +2
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(1), 2);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(4), 2);

      // Level 5-8: +3
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(5), 3);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(8), 3);

      // Level 9-12: +4
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(9), 4);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(12), 4);

      // Level 13-16: +5
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(13), 5);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(16), 5);

      // Level 17-20: +6
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(17), 6);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(20), 6);
    });

    test('Dnd5eScoreMath extension getters match rules calculation', () {
      expect(10.dndModifier, 0);
      expect(18.dndModifier, 4);
      expect(1.dndModifier, -5);
      expect(1.dndProficiencyBonus, 2);
      expect(5.dndProficiencyBonus, 3);
      expect(20.dndProficiencyBonus, 6);
    });
  });
}
