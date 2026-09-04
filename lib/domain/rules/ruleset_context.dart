enum RulesetVersion { v2014, v2024 }

enum ActionCost { action, bonusAction, reaction, free }

abstract class RulesetEngine {
  final RulesetVersion version;
  const RulesetEngine(this.version);

  factory RulesetEngine.forVersion(RulesetVersion version) {
    switch (version) {
      case RulesetVersion.v2014:
        return const RulesetEngine2014();
      case RulesetVersion.v2024:
        return const RulesetEngine2024();
    }
  }

  ActionCost get potionConsumptionCost;
  int calculateExhaustionD20Penalty(int level);
  int calculateExhaustionSpeedPenalty(int level);
  bool isExhaustionFatal(int level);
  bool supportsWeaponMasteries();
}

class RulesetEngine2014 extends RulesetEngine {
  const RulesetEngine2014() : super(RulesetVersion.v2014);

  @override
  ActionCost get potionConsumptionCost => ActionCost.action;

  @override
  int calculateExhaustionD20Penalty(int level) => 0;

  @override
  int calculateExhaustionSpeedPenalty(int level) {
    if (level >= 5) return 999;
    if (level >= 2) return 15;
    return 0;
  }

  @override
  bool isExhaustionFatal(int level) => level >= 6;

  @override
  bool supportsWeaponMasteries() => false;
}

class RulesetEngine2024 extends RulesetEngine {
  const RulesetEngine2024() : super(RulesetVersion.v2024);

  @override
  ActionCost get potionConsumptionCost => ActionCost.bonusAction;

  @override
  int calculateExhaustionD20Penalty(int level) => (level.clamp(0, 6)) * 2;

  @override
  int calculateExhaustionSpeedPenalty(int level) => (level.clamp(0, 6)) * 5;

  @override
  bool isExhaustionFatal(int level) => level >= 6;

  @override
  bool supportsWeaponMasteries() => true;
}
