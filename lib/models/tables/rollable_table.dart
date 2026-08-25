import 'dart:math';
import 'package:flutter/material.dart';

/// Categories of rollable SRD tables in the Table Index.
enum TableCategory {
  loot('Loot & Treasure', Icons.monetization_on_outlined, Color(0xFFF59E0B)),
  magic('Magic & Chaos', Icons.auto_awesome, Color(0xFFC084FC)),
  dmGameplay('DM & Hazards', Icons.shield_outlined, Color(0xFFEF4444)),
  characterLore('NPC & Story', Icons.psychology_outlined, Color(0xFF38BDF8)),
  trinkets('Trinkets & Curios', Icons.stars_outlined, Color(0xFF10B981));

  final String label;
  final IconData icon;
  final Color accentColor;

  const TableCategory(this.label, this.icon, this.accentColor);
}

/// A single row / outcome in a rollable table.
class TableEntry {
  final int minRoll;
  final int maxRoll;
  final String label;
  final String? description;
  final String? itemRefId;
  final String? extraRollTableId;
  final String? coinFormula;

  const TableEntry({
    required this.minRoll,
    required this.maxRoll,
    required this.label,
    this.description,
    this.itemRefId,
    this.extraRollTableId,
    this.coinFormula,
  });

  bool matchesRoll(int roll) => roll >= minRoll && roll <= maxRoll;

  String get rangeDisplay => minRoll == maxRoll ? '$minRoll' : '$minRoll–$maxRoll';
}

/// A rollable table with defined dice formula and entries.
class RollableTable {
  final String id;
  final String name;
  final TableCategory category;
  final String diceFormula;
  final int diceSides;
  final int diceCount;
  final int diceModifier;
  final String description;
  final List<TableEntry> entries;

  const RollableTable({
    required this.id,
    required this.name,
    required this.category,
    required this.diceFormula,
    this.diceSides = 100,
    this.diceCount = 1,
    this.diceModifier = 0,
    required this.description,
    required this.entries,
  });

  /// Evaluates a roll on this table or generates a random result using [Random].
  TableRollResult roll([Random? rng]) {
    final random = rng ?? Random();
    int total = diceModifier;
    for (int i = 0; i < diceCount; i++) {
      total += random.nextInt(diceSides) + 1;
    }

    final landedEntry = entries.firstWhere(
      (e) => e.matchesRoll(total),
      orElse: () => entries.last,
    );

    return TableRollResult(
      tableId: id,
      tableName: name,
      diceFormula: diceFormula,
      rollValue: total,
      entry: landedEntry,
      timestamp: DateTime.now(),
    );
  }

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        category.label.toLowerCase().contains(q) ||
        entries.any((e) =>
            e.label.toLowerCase().contains(q) ||
            (e.description != null && e.description!.toLowerCase().contains(q)));
  }
}

/// Result of rolling on a [RollableTable].
class TableRollResult {
  final String tableId;
  final String tableName;
  final String diceFormula;
  final int rollValue;
  final TableEntry entry;
  final DateTime timestamp;
  final List<TableRollResult> subRolls;

  const TableRollResult({
    required this.tableId,
    required this.tableName,
    required this.diceFormula,
    required this.rollValue,
    required this.entry,
    required this.timestamp,
    this.subRolls = const [],
  });
}

/// A specific gemstone or art object with monetary gold piece value.
class GemArtItem {
  final String name;
  final int gpValue;
  final String category; // e.g. "10 gp Gemstone", "250 gp Art Object"
  final String? description;
  final int count;

  const GemArtItem({
    required this.name,
    required this.gpValue,
    required this.category,
    this.description,
    this.count = 1,
  });

  int get totalGp => gpValue * count;

  GemArtItem copyWithCount(int newCount) {
    return GemArtItem(
      name: name,
      gpValue: gpValue,
      category: category,
      description: description,
      count: newCount,
    );
  }
}

/// Calculated party share distribution.
class PartyShareBreakdown {
  final int partySize;
  final int cpPerPlayer;
  final int spPerPlayer;
  final int epPerPlayer;
  final int gpPerPlayer;
  final int ppPerPlayer;
  final double totalGpEquivalentPerPlayer;
  final Map<String, int> remainderCoins;
  final double remainderGpEquivalent;

  const PartyShareBreakdown({
    required this.partySize,
    required this.cpPerPlayer,
    required this.spPerPlayer,
    required this.epPerPlayer,
    required this.gpPerPlayer,
    required this.ppPerPlayer,
    required this.totalGpEquivalentPerPlayer,
    required this.remainderCoins,
    required this.remainderGpEquivalent,
  });
}

/// Complete generated treasure hoard or monster loot drop.
class TreasureDropResult {
  final String tierLabel;
  final bool isHoard;
  final int cp;
  final int sp;
  final int ep;
  final int gp;
  final int pp;
  final List<GemArtItem> gemstones;
  final List<GemArtItem> artObjects;
  final List<String> magicItemNames;
  final List<String> magicItemIds;
  final int d100Roll;
  final String rollSummary;

  const TreasureDropResult({
    required this.tierLabel,
    required this.isHoard,
    this.cp = 0,
    this.sp = 0,
    this.ep = 0,
    this.gp = 0,
    this.pp = 0,
    this.gemstones = const [],
    this.artObjects = const [],
    this.magicItemNames = const [],
    this.magicItemIds = const [],
    required this.d100Roll,
    required this.rollSummary,
  });

  /// Total standard coin value in Gold Pieces (GP).
  double get coinsGoldValue =>
      (cp * 0.01) + (sp * 0.1) + (ep * 0.5) + (gp * 1.0) + (pp * 10.0);

  /// Total value of all gemstones in GP.
  int get gemsGoldValue =>
      gemstones.fold(0, (sum, gem) => sum + gem.totalGp);

  /// Total value of all art objects in GP.
  int get artGoldValue =>
      artObjects.fold(0, (sum, art) => sum + art.totalGp);

  /// Grand total estimated gold value including coins, liquidated gems, and art objects.
  double get grandTotalGoldValue =>
      coinsGoldValue + gemsGoldValue + artGoldValue;

  /// Calculates party shares given [partyMembers] count.
  PartyShareBreakdown calculateShares(int partyMembers, {bool includeLiquidatedGemsAndArt = false}) {
    final count = partyMembers <= 0 ? 1 : partyMembers;

    if (includeLiquidatedGemsAndArt) {
      final totalGp = grandTotalGoldValue;
      final gpPer = (totalGp / count).floor();
      final remainderGp = totalGp - (gpPer * count);

      return PartyShareBreakdown(
        partySize: count,
        cpPerPlayer: 0,
        spPerPlayer: 0,
        epPerPlayer: 0,
        gpPerPlayer: gpPer,
        ppPerPlayer: 0,
        totalGpEquivalentPerPlayer: totalGp / count,
        remainderCoins: {'gp': remainderGp.round()},
        remainderGpEquivalent: remainderGp,
      );
    }

    final cpPer = cp ~/ count;
    final spPer = sp ~/ count;
    final epPer = ep ~/ count;
    final gpPer = gp ~/ count;
    final ppPer = pp ~/ count;

    final remCp = cp % count;
    final remSp = sp % count;
    final remEp = ep % count;
    final remGp = gp % count;
    final remPp = pp % count;

    final perPlayerGpEq = (cpPer * 0.01) +
        (spPer * 0.1) +
        (epPer * 0.5) +
        (gpPer * 1.0) +
        (ppPer * 10.0);

    final remGpEq = (remCp * 0.01) +
        (remSp * 0.1) +
        (remEp * 0.5) +
        (remGp * 1.0) +
        (remPp * 10.0);

    return PartyShareBreakdown(
      partySize: count,
      cpPerPlayer: cpPer,
      spPerPlayer: spPer,
      epPerPlayer: epPer,
      gpPerPlayer: gpPer,
      ppPerPlayer: ppPer,
      totalGpEquivalentPerPlayer: perPlayerGpEq,
      remainderCoins: {
        if (remPp > 0) 'pp': remPp,
        if (remGp > 0) 'gp': remGp,
        if (remEp > 0) 'ep': remEp,
        if (remSp > 0) 'sp': remSp,
        if (remCp > 0) 'cp': remCp,
      },
      remainderGpEquivalent: remGpEq,
    );
  }
}
