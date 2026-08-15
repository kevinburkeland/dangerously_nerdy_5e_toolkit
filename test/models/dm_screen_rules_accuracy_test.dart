import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/dnd_5e_rules_engine.dart';

void main() {
  group('5e Rules Accuracy & 2014 vs 2024 Diffs', () {
    test('Exhaustion rules accurately capture 2014 tiers vs 2024 numeric penalties', () {
      final exhaustion = DmScreenLibrary.allItems.firstWhere((i) => i.id == 'cond_exhaustion');
      expect(exhaustion, isNotNull);

      // Verify 2014 has 6 distinct tiers
      expect(exhaustion.rules2014.any((r) => r.contains('Level 1: Disadvantage on ability checks')), isTrue);
      expect(exhaustion.rules2014.any((r) => r.contains('Level 6: Death')), isTrue);

      // Verify 2024 has the 2x exhaustion level D20 test penalty
      expect(exhaustion.rules2024.any((r) => r.contains('Subtract 2 × your exhaustion level from all D20 Tests')), isTrue);
      expect(exhaustion.rules2024.any((r) => r.contains('Reduce speed by 5 feet × your exhaustion level')), isTrue);
      expect(exhaustion.isChangedIn2024, isTrue);
    });

    test('Grappled condition captures 2014 vs 2024 save DC and escape mechanics', () {
      final grappled = DmScreenLibrary.allItems.firstWhere((i) => i.id == 'cond_grappled');
      expect(grappled, isNotNull);

      // Verify 2024 specifies end of turn save DC
      expect(grappled.rules2024.any((r) => r.contains('saving throw at the end of each of your turns')), isTrue);
      expect(grappled.isChangedIn2024, isTrue);
    });

    test('Surprise rule reflects disadvantage on initiative in 2024', () {
      final surprise = DmScreenLibrary.allItems.firstWhere((i) => i.id == 'cond_surprise');
      expect(surprise, isNotNull);

      expect(surprise.rules2014.any((r) => r.contains('cannot move or take an Action')), isTrue);
      expect(surprise.rules2024.any((r) => r.contains('Disadvantage on your Initiative roll')), isTrue);
      expect(surprise.isChangedIn2024, isTrue);
    });

    test('Drinking a potion changes from 1 Action (2014) to 1 Bonus Action (2024)', () {
      final potion = DmScreenLibrary.allItems.firstWhere((i) => i.id == 'action_potions');
      expect(potion, isNotNull);

      expect(potion.getCost(DmRulesEdition.v2014), equals('1 Action'));
      expect(potion.getCost(DmRulesEdition.v2024), equals('1 Bonus Action'));
      expect(potion.isChangedIn2024, isTrue);

      // Verify it appears in standardActions for 2014 and bonusActions for 2024
      final std2014 = DmScreenLibrary.standardActions(DmRulesEdition.v2014);
      final bonus2024 = DmScreenLibrary.bonusActions(DmRulesEdition.v2024);
      expect(std2014.any((i) => i.id == 'action_potions'), isTrue);
      expect(bonus2024.any((i) => i.id == 'action_potions'), isTrue);
    });

    test('Dnd5eScoreMath accurately computes ability modifiers across the entire standard range', () {
      expect(1.dndModifier, equals(-5));
      expect(3.dndModifier, equals(-4));
      expect(8.dndModifier, equals(-1));
      expect(9.dndModifier, equals(-1));
      expect(10.dndModifier, equals(0));
      expect(11.dndModifier, equals(0));
      expect(12.dndModifier, equals(1));
      expect(18.dndModifier, equals(4));
      expect(20.dndModifier, equals(5));
      expect(30.dndModifier, equals(10));

      expect(10.dndModifierString, equals('+0'));
      expect(14.dndModifierString, equals('+2'));
      expect(8.dndModifierString, equals('-1'));
    });

    test('Dnd5eScoreMath accurately scales proficiency bonus by character/minion level', () {
      // 1-4 => +2
      expect(1.dndProficiencyBonus, equals(2));
      expect(4.dndProficiencyBonus, equals(2));
      // 5-8 => +3
      expect(5.dndProficiencyBonus, equals(3));
      expect(8.dndProficiencyBonus, equals(3));
      // 9-12 => +4
      expect(9.dndProficiencyBonus, equals(4));
      expect(12.dndProficiencyBonus, equals(4));
      // 13-16 => +5
      expect(13.dndProficiencyBonus, equals(5));
      expect(16.dndProficiencyBonus, equals(5));
      // 17-20 => +6
      expect(17.dndProficiencyBonus, equals(6));
      expect(20.dndProficiencyBonus, equals(6));
    });
  });
}
