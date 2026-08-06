import 'dart:math';

enum DieType {
  d4(4, 'd4'),
  d6(6, 'd6'),
  d8(8, 'd8'),
  d10(10, 'd10'),
  d12(12, 'd12'),
  d20(20, 'd20'),
  d100(100, 'd100');

  final int sides;
  final String label;

  const DieType(this.sides, this.label);
}

enum RollMode { normal, advantage, disadvantage }

class DiceRollResult {
  final DateTime timestamp;
  final DieType dieType;
  final int count;
  final int modifier;
  final RollMode rollMode;
  final List<int> individualRolls;
  final List<int>? droppedRolls; // For advantage / disadvantage on d20
  final int total;
  final bool isCrit; // Natural 20 on d20
  final bool isFumble; // Natural 1 on d20

  DiceRollResult({
    required this.timestamp,
    required this.dieType,
    required this.count,
    required this.modifier,
    required this.rollMode,
    required this.individualRolls,
    this.droppedRolls,
    required this.total,
    required this.isCrit,
    required this.isFumble,
  });

  static final Random _rng = Random();

  static DiceRollResult roll({
    required DieType dieType,
    int count = 1,
    int modifier = 0,
    RollMode rollMode = RollMode.normal,
  }) {
    List<int> rolls = [];
    List<int>? dropped;
    bool crit = false;
    bool fumble = false;

    if (dieType == DieType.d20 && count == 1 && rollMode != RollMode.normal) {
      int r1 = _rng.nextInt(20) + 1;
      int r2 = _rng.nextInt(20) + 1;
      if (rollMode == RollMode.advantage) {
        int kept = max(r1, r2);
        int drop = min(r1, r2);
        rolls = [kept];
        dropped = [drop];
      } else {
        int kept = min(r1, r2);
        int drop = max(r1, r2);
        rolls = [kept];
        dropped = [drop];
      }
      crit = rolls.first == 20;
      fumble = rolls.first == 1;
    } else {
      for (int i = 0; i < count; i++) {
        int r = _rng.nextInt(dieType.sides) + 1;
        rolls.add(r);
      }
      if (dieType == DieType.d20 && count == 1) {
        crit = rolls.first == 20;
        fumble = rolls.first == 1;
      }
    }

    int sum = rolls.fold(0, (acc, val) => acc + val) + modifier;

    return DiceRollResult(
      timestamp: DateTime.now(),
      dieType: dieType,
      count: count,
      modifier: modifier,
      rollMode: rollMode,
      individualRolls: rolls,
      droppedRolls: dropped,
      total: sum,
      isCrit: crit,
      isFumble: fumble,
    );
  }

  String get formulaString {
    String modStr = '';
    if (modifier > 0) {
      modStr = ' + $modifier';
    } else if (modifier < 0) {
      modStr = ' - ${modifier.abs()}';
    }

    String advStr = '';
    if (rollMode == RollMode.advantage) advStr = ' (Adv)';
    if (rollMode == RollMode.disadvantage) advStr = ' (Dis)';

    return '$count${dieType.label}$modStr$advStr';
  }
}
