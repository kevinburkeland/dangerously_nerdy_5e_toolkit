import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/rules/ruleset_context.dart';

void main() {
  group('RulesetEngine arbitration', () {
    test('RulesetEngine2014 designates potion consumption as ActionCost.action', () {
      final engine = RulesetEngine.forVersion(RulesetVersion.v2014);
      expect(engine.potionConsumptionCost, equals(ActionCost.action));
      expect(engine.supportsWeaponMasteries(), isFalse);
    });

    test('RulesetEngine2024 designates potion consumption as ActionCost.bonusAction', () {
      final engine = RulesetEngine.forVersion(RulesetVersion.v2024);
      expect(engine.potionConsumptionCost, equals(ActionCost.bonusAction));
      expect(engine.supportsWeaponMasteries(), isTrue);
    });

    test('RulesetEngine2014 exhaustion speed reductions and fatal threshold', () {
      final engine = RulesetEngine.forVersion(RulesetVersion.v2014);

      expect(engine.calculateExhaustionD20Penalty(0), equals(0));
      expect(engine.calculateExhaustionD20Penalty(3), equals(0));
      expect(engine.calculateExhaustionSpeedPenalty(1), equals(0));
      expect(engine.calculateExhaustionSpeedPenalty(2), equals(15));
      expect(engine.calculateExhaustionSpeedPenalty(4), equals(15));
      expect(engine.calculateExhaustionSpeedPenalty(5), equals(999));
      expect(engine.isExhaustionFatal(5), isFalse);
      expect(engine.isExhaustionFatal(6), isTrue);
      expect(engine.isExhaustionFatal(7), isTrue);
    });

    test('RulesetEngine2024 scales d20 penalty linearly by -2 per level and triggers death at level 6', () {
      final engine = RulesetEngine.forVersion(RulesetVersion.v2024);

      expect(engine.calculateExhaustionD20Penalty(0), equals(0));
      expect(engine.calculateExhaustionD20Penalty(1), equals(2));
      expect(engine.calculateExhaustionD20Penalty(2), equals(4));
      expect(engine.calculateExhaustionD20Penalty(3), equals(6));
      expect(engine.calculateExhaustionD20Penalty(4), equals(8));
      expect(engine.calculateExhaustionD20Penalty(5), equals(10));
      expect(engine.calculateExhaustionD20Penalty(6), equals(12));

      expect(engine.calculateExhaustionSpeedPenalty(0), equals(0));
      expect(engine.calculateExhaustionSpeedPenalty(1), equals(5));
      expect(engine.calculateExhaustionSpeedPenalty(3), equals(15));
      expect(engine.calculateExhaustionSpeedPenalty(6), equals(30));

      expect(engine.isExhaustionFatal(5), isFalse);
      expect(engine.isExhaustionFatal(6), isTrue);
      expect(engine.isExhaustionFatal(10), isTrue);
    });
  });
}
