import 'minion_stat_block.dart';

typedef BudgetCalculator = int Function(int spellLevel);

class SummonPreset {
  final String id;
  final String name;
  final SummonCategory category;
  final String levelDisplay; // e.g. "5th-level Transmutation", "Wondrous Item (Rare)"
  final String castingTime;
  final String range;
  final String components;
  final String duration;
  final String description;
  final String upcastRules;
  final List<MinionStatBlock> statBlocks;
  final bool isRandomTable; // e.g., Bag of Tricks
  final BudgetCalculator? budgetCalculator;
  final int defaultMinionCount;

  const SummonPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.levelDisplay,
    required this.castingTime,
    required this.range,
    required this.components,
    required this.duration,
    required this.description,
    required this.upcastRules,
    required this.statBlocks,
    this.isRandomTable = false,
    this.budgetCalculator,
    this.defaultMinionCount = 1,
  });

  int calculateMaxPoints(int spellLevel) {
    if (budgetCalculator != null) {
      return budgetCalculator!(spellLevel);
    }
    return 50;
  }
}

