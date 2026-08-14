import 'dart:math';
import '../utils/secure_random.dart';

enum DieType {
  d4(4, 'd4'),
  d6(6, 'd6'),
  d8(8, 'd8'),
  d10(10, 'd10'),
  d12(12, 'd12'),
  d20(20, 'd20'),
  d100(100, 'd100'),
  custom(6, 'custom');

  final int sides;
  final String label;

  const DieType(this.sides, this.label);
}

enum RollMode { normal, advantage, disadvantage }

class DiceEntry {
  final DieType dieType;
  final int count;
  final int customSides;

  DiceEntry({
    required this.dieType,
    int count = 1,
    int customSides = 6,
  })  : count = count.clamp(1, 100),
        customSides = customSides.clamp(2, 1000);

  int get sides => dieType == DieType.custom ? customSides : dieType.sides;

  String get dieLabel => dieType == DieType.custom ? 'd$customSides' : dieType.label;

  String get formulaString => '$count$dieLabel';

  DiceEntry copyWith({
    DieType? dieType,
    int? count,
    int? customSides,
  }) {
    return DiceEntry(
      dieType: dieType ?? this.dieType,
      count: count ?? this.count,
      customSides: customSides ?? this.customSides,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dieType': dieType.name,
      'count': count,
      'customSides': customSides,
    };
  }

  factory DiceEntry.fromMap(Map<String, dynamic> map) {
    final dtStr = map['dieType'] as String? ?? 'd6';
    final dt = DieType.values.firstWhere(
      (d) => d.name == dtStr,
      orElse: () => DieType.d6,
    );
    return DiceEntry(
      dieType: dt,
      count: map['count'] as int? ?? 1,
      customSides: map['customSides'] as int? ?? 6,
    );
  }
}

class DiceGroupResult {
  final DiceEntry entry;
  final List<int> rolls;

  DiceGroupResult({
    required this.entry,
    required this.rolls,
  });
}

class DiceRollResult {
  final DateTime timestamp;
  final List<DiceEntry> diceEntries;
  final List<DiceGroupResult> groupResults;
  final int modifier;
  final RollMode rollMode;
  final List<int> individualRolls;
  final List<int>? droppedRolls; // For advantage / disadvantage on d20
  final int total;
  final bool isCrit; // Natural 20 on d20
  final bool isFumble; // Natural 1 on d20

  DiceRollResult({
    required this.timestamp,
    required this.diceEntries,
    required this.groupResults,
    required this.modifier,
    required this.rollMode,
    required this.individualRolls,
    this.droppedRolls,
    required this.total,
    required this.isCrit,
    required this.isFumble,
  });

  // Backwards compatibility getters
  DieType get dieType => diceEntries.isNotEmpty ? diceEntries.first.dieType : DieType.d20;
  int get count => diceEntries.isNotEmpty ? diceEntries.fold(0, (sum, e) => sum + e.count) : 1;
  static Random get _rng => SecureRng.instance;

  static DiceRollResult roll({
    required DieType dieType,
    int count = 1,
    int modifier = 0,
    int customSides = 6,
    RollMode rollMode = RollMode.normal,
  }) {
    return rollPool(
      diceEntries: [
        DiceEntry(
          dieType: dieType,
          count: count,
          customSides: customSides,
        ),
      ],
      modifier: modifier,
      rollMode: rollMode,
    );
  }

  static DiceRollResult rollPool({
    required List<DiceEntry> diceEntries,
    int modifier = 0,
    RollMode rollMode = RollMode.normal,
    bool isCritDamage = false,
  }) {
    List<DiceGroupResult> groupResults = [];
    List<int> allRolls = [];
    List<int>? dropped;
    bool crit = false;
    bool fumble = false;

    final effectiveEntries = isCritDamage
        ? diceEntries.map((e) => e.copyWith(count: e.count * 2)).toList()
        : diceEntries;

    final hasD20 = effectiveEntries.any((e) => e.dieType == DieType.d20);

    for (final entry in effectiveEntries) {
      List<int> groupRolls = [];
      final maxSides = max(2, entry.sides);

      if (entry.dieType == DieType.d20 && entry.count == 1 && rollMode != RollMode.normal && hasD20) {
        int r1 = _rng.nextInt(20) + 1;
        int r2 = _rng.nextInt(20) + 1;
        int kept, drop;
        if (rollMode == RollMode.advantage) {
          kept = max(r1, r2);
          drop = min(r1, r2);
        } else {
          kept = min(r1, r2);
          drop = max(r1, r2);
        }
        groupRolls.add(kept);
        allRolls.add(kept);
        dropped = [drop];

        if (kept == 20) crit = true;
        if (kept == 1) fumble = true;
      } else {
        for (int i = 0; i < entry.count; i++) {
          int r = _rng.nextInt(maxSides) + 1;
          groupRolls.add(r);
          allRolls.add(r);
        }

        // Check natural 20/1 for d20 roll
        if (entry.dieType == DieType.d20 && entry.count == 1) {
          if (groupRolls.first == 20) crit = true;
          if (groupRolls.first == 1) fumble = true;
        }
      }

      groupResults.add(DiceGroupResult(entry: entry, rolls: groupRolls));
    }

    int sum = allRolls.fold(0, (acc, val) => acc + val) + modifier;

    return DiceRollResult(
      timestamp: DateTime.now(),
      diceEntries: List.unmodifiable(effectiveEntries),
      groupResults: groupResults,
      modifier: modifier,
      rollMode: rollMode,
      individualRolls: allRolls,
      droppedRolls: dropped,
      total: sum,
      isCrit: crit,
      isFumble: fumble,
    );
  }

  String get formulaString {
    final dicePart = diceEntries.map((e) => e.formulaString).join(' + ');

    String modStr = '';
    if (modifier > 0) {
      modStr = ' + $modifier';
    } else if (modifier < 0) {
      modStr = ' - ${modifier.abs()}';
    }

    String advStr = '';
    if (rollMode == RollMode.advantage) advStr = ' (Adv)';
    if (rollMode == RollMode.disadvantage) advStr = ' (Dis)';

    return '$dicePart$modStr$advStr';
  }
}

