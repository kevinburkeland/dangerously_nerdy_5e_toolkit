import 'dart:math';
import '../../models/tables/rollable_table.dart';
import '../../models/tables/srd_loot_tables.dart';

/// Supported Challenge Rating (CR) tiers for loot and treasure hoards.
enum TreasureTier {
  cr0To4('CR 0–4 (Tier 1: Levels 1–4)', '1–4'),
  cr5To10('CR 5–10 (Tier 2: Levels 5–10)', '5–10'),
  cr11To16('CR 11–16 (Tier 3: Levels 11–16)', '11–16'),
  cr17Plus('CR 17+ (Tier 4: Levels 17–20)', '17+');

  final String label;
  final String shortLabel;

  const TreasureTier(this.label, this.shortLabel);
}

/// 5e SRD Combat Loot & Treasure Hoard Generation Engine.
class TreasureGeneratorEngine {
  final Random _random;

  TreasureGeneratorEngine([Random? random]) : _random = random ?? Random();

  int _rollDice(int count, int sides) {
    int total = 0;
    for (int i = 0; i < count; i++) {
      total += _random.nextInt(sides) + 1;
    }
    return total;
  }

  // ==========================================
  // INDIVIDUAL TREASURE DROPS
  // ==========================================

  TreasureDropResult generateIndividualTreasure(TreasureTier tier) {
    final d100 = _random.nextInt(100) + 1;

    switch (tier) {
      case TreasureTier.cr0To4:
        if (d100 <= 30) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            cp: _rollDice(5, 6),
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 5d6 CP',
          );
        } else if (d100 <= 60) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            sp: _rollDice(4, 6),
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 4d6 SP',
          );
        } else if (d100 <= 70) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            ep: _rollDice(3, 6),
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 3d6 EP',
          );
        } else if (d100 <= 95) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            gp: _rollDice(3, 6),
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 3d6 GP',
          );
        } else {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            pp: _rollDice(1, 6),
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 1d6 PP',
          );
        }

      case TreasureTier.cr5To10:
        if (d100 <= 30) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            cp: _rollDice(4, 6) * 100,
            ep: _rollDice(1, 6) * 10,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 4d6×100 CP + 1d6×10 EP',
          );
        } else if (d100 <= 60) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            sp: _rollDice(6, 6) * 10,
            gp: _rollDice(2, 6) * 10,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 6d6×10 SP + 2d6×10 GP',
          );
        } else if (d100 <= 70) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            ep: _rollDice(1, 6) * 100,
            gp: _rollDice(2, 6) * 10,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 1d6×100 EP + 2d6×10 GP',
          );
        } else if (d100 <= 95) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            gp: _rollDice(4, 6) * 10,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 4d6×10 GP',
          );
        } else {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            gp: _rollDice(2, 6) * 10,
            pp: _rollDice(3, 6),
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 2d6×10 GP + 3d6 PP',
          );
        }

      case TreasureTier.cr11To16:
        if (d100 <= 20) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            sp: _rollDice(4, 6) * 100,
            gp: _rollDice(1, 6) * 100,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 4d6×100 SP + 1d6×100 GP',
          );
        } else if (d100 <= 35) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            ep: _rollDice(1, 6) * 100,
            gp: _rollDice(1, 6) * 100,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 1d6×100 EP + 1d6×100 GP',
          );
        } else if (d100 <= 75) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            gp: _rollDice(2, 6) * 100,
            pp: _rollDice(1, 6) * 10,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 2d6×100 GP + 1d6×10 PP',
          );
        } else {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            gp: _rollDice(2, 6) * 100,
            pp: _rollDice(2, 6) * 10,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 2d6×100 GP + 2d6×10 PP',
          );
        }

      case TreasureTier.cr17Plus:
        if (d100 <= 15) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            ep: _rollDice(2, 6) * 1000,
            gp: _rollDice(8, 6) * 100,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 2d6×1000 EP + 8d6×100 GP',
          );
        } else if (d100 <= 55) {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            gp: _rollDice(1, 6) * 1000,
            pp: _rollDice(1, 6) * 100,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 1d6×1000 GP + 1d6×100 PP',
          );
        } else {
          return TreasureDropResult(
            tierLabel: tier.label,
            isHoard: false,
            gp: _rollDice(1, 6) * 1000,
            pp: _rollDice(2, 6) * 100,
            d100Roll: d100,
            rollSummary: 'Individual Drop (d100: $d100) -> 1d6×1000 GP + 2d6×100 PP',
          );
        }
    }
  }

  // ==========================================
  // TREASURE HOARDS
  // ==========================================

  TreasureDropResult generateTreasureHoard(TreasureTier tier) {
    final d100 = _random.nextInt(100) + 1;

    switch (tier) {
      case TreasureTier.cr0To4:
        return _generateHoardCr0To4(d100);
      case TreasureTier.cr5To10:
        return _generateHoardCr5To10(d100);
      case TreasureTier.cr11To16:
        return _generateHoardCr11To16(d100);
      case TreasureTier.cr17Plus:
        return _generateHoardCr17Plus(d100);
    }
  }

  TreasureDropResult _generateHoardCr0To4(int d100) {
    final cp = _rollDice(6, 6) * 100;
    final sp = _rollDice(3, 6) * 100;
    final gp = _rollDice(2, 6) * 10;

    final gems = <GemArtItem>[];
    final art = <GemArtItem>[];
    final magicItemNames = <String>[];
    final magicItemIds = <String>[];

    String summary = 'CR 0–4 Hoard (d100: $d100)';

    if (d100 >= 7 && d100 <= 16) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones10gp, _rollDice(2, 6)));
      summary += ' • 2d6 10gp Gems';
    } else if (d100 >= 17 && d100 <= 26) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      summary += ' • 2d4 25gp Art Objects';
    } else if (d100 >= 27 && d100 <= 36) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(2, 6)));
      summary += ' • 2d6 50gp Gems';
    } else if (d100 >= 37 && d100 <= 44) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones10gp, _rollDice(2, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 2d6 10gp Gems + 1d6 Table A items';
    } else if (d100 >= 45 && d100 <= 52) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1d6 Table A items';
    } else if (d100 >= 53 && d100 <= 60) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(2, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 2d6 50gp Gems + 1d6 Table A items';
    } else if (d100 >= 61 && d100 <= 65) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones10gp, _rollDice(2, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d6 10gp Gems + 1d4 Table B items';
    } else if (d100 >= 66 && d100 <= 70) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1d4 Table B items';
    } else if (d100 >= 71 && d100 <= 75) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(2, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d6 50gp Gems + 1d4 Table B items';
    } else if (d100 >= 76 && d100 <= 78) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones10gp, _rollDice(2, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d6 10gp Gems + 1d4 Table C items';
    } else if (d100 >= 79 && d100 <= 80) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1d4 Table C items';
    } else if (d100 >= 81 && d100 <= 85) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(2, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d6 50gp Gems + 1d4 Table C items';
    } else if (d100 >= 86 && d100 <= 92) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableF, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1d4 Table F items';
    } else if (d100 >= 93 && d100 <= 97) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(2, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableF, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d6 50gp Gems + 1d4 Table F items';
    } else if (d100 >= 98 && d100 <= 99) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableG, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1 Table G item';
    } else if (d100 == 100) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(2, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableG, 1, magicItemNames, magicItemIds);
      summary += ' • 2d6 50gp Gems + 1 Table G item';
    }

    return TreasureDropResult(
      tierLabel: TreasureTier.cr0To4.label,
      isHoard: true,
      cp: cp,
      sp: sp,
      gp: gp,
      gemstones: gems,
      artObjects: art,
      magicItemNames: magicItemNames,
      magicItemIds: magicItemIds,
      d100Roll: d100,
      rollSummary: summary,
    );
  }

  TreasureDropResult _generateHoardCr5To10(int d100) {
    final cp = _rollDice(2, 6) * 100;
    final sp = _rollDice(2, 6) * 1000;
    final gp = _rollDice(6, 6) * 100;
    final pp = _rollDice(3, 6) * 10;

    final gems = <GemArtItem>[];
    final art = <GemArtItem>[];
    final magicItemNames = <String>[];
    final magicItemIds = <String>[];

    String summary = 'CR 5–10 Hoard (d100: $d100)';

    if (d100 >= 5 && d100 <= 10) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      summary += ' • 2d4 25gp Art';
    } else if (d100 >= 11 && d100 <= 16) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(3, 6)));
      summary += ' • 3d6 50gp Gems';
    } else if (d100 >= 17 && d100 <= 22) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones100gp, _rollDice(3, 6)));
      summary += ' • 3d6 100gp Gems';
    } else if (d100 >= 23 && d100 <= 28) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      summary += ' • 2d4 250gp Art';
    } else if (d100 >= 29 && d100 <= 32) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1d6 Table A';
    } else if (d100 >= 33 && d100 <= 36) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 3d6 50gp Gems + 1d6 Table A';
    } else if (d100 >= 37 && d100 <= 40) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones100gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 3d6 100gp Gems + 1d6 Table A';
    } else if (d100 >= 41 && d100 <= 44) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1d6 Table A';
    } else if (d100 >= 45 && d100 <= 49) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1d4 Table B';
    } else if (d100 >= 50 && d100 <= 54) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 50gp Gems + 1d4 Table B';
    } else if (d100 >= 55 && d100 <= 59) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones100gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 100gp Gems + 1d4 Table B';
    } else if (d100 >= 60 && d100 <= 63) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1d4 Table B';
    } else if (d100 >= 64 && d100 <= 66) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1d4 Table C';
    } else if (d100 >= 67 && d100 <= 69) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 50gp Gems + 1d4 Table C';
    } else if (d100 >= 70 && d100 <= 72) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones100gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 100gp Gems + 1d4 Table C';
    } else if (d100 >= 73 && d100 <= 74) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1d4 Table C';
    } else if (d100 >= 75 && d100 <= 76) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableD, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1 Table D';
    } else if (d100 >= 77 && d100 <= 78) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableD, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 50gp Gems + 1 Table D';
    } else if (d100 == 79) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones100gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableD, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 100gp Gems + 1 Table D';
    } else if (d100 == 80) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableD, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1 Table D';
    } else if (d100 >= 81 && d100 <= 84) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects25gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableF, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 25gp Art + 1d4 Table F';
    } else if (d100 >= 85 && d100 <= 88) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones50gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableF, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 50gp Gems + 1d4 Table F';
    } else if (d100 >= 89 && d100 <= 91) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones100gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableF, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 100gp Gems + 1d4 Table F';
    } else if (d100 >= 92 && d100 <= 94) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableF, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1d4 Table F';
    } else if (d100 >= 95 && d100 <= 96) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones100gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 100gp Gems + 1d4 Table G';
    } else if (d100 >= 97 && d100 <= 98) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1d4 Table G';
    } else if (d100 == 99) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones100gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableH, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 100gp Gems + 1 Table H';
    } else if (d100 == 100) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableH, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1 Table H';
    }

    return TreasureDropResult(
      tierLabel: TreasureTier.cr5To10.label,
      isHoard: true,
      cp: cp,
      sp: sp,
      gp: gp,
      pp: pp,
      gemstones: gems,
      artObjects: art,
      magicItemNames: magicItemNames,
      magicItemIds: magicItemIds,
      d100Roll: d100,
      rollSummary: summary,
    );
  }

  TreasureDropResult _generateHoardCr11To16(int d100) {
    final gp = _rollDice(4, 6) * 1000;
    final pp = _rollDice(5, 6) * 100;

    final gems = <GemArtItem>[];
    final art = <GemArtItem>[];
    final magicItemNames = <String>[];
    final magicItemIds = <String>[];

    String summary = 'CR 11–16 Hoard (d100: $d100)';

    if (d100 >= 4 && d100 <= 9) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      summary += ' • 2d4 250gp Art';
    } else if (d100 >= 10 && d100 <= 15) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects750gp, _rollDice(2, 4)));
      summary += ' • 2d4 750gp Art';
    } else if (d100 >= 16 && d100 <= 22) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones500gp, _rollDice(3, 6)));
      summary += ' • 3d6 500gp Gems';
    } else if (d100 >= 23 && d100 <= 29) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      summary += ' • 3d6 1,000gp Gems';
    } else if (d100 >= 30 && d100 <= 35) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 4), magicItemNames, magicItemIds);
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + Table A & B';
    } else if (d100 >= 36 && d100 <= 40) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects750gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 4), magicItemNames, magicItemIds);
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 2d4 750gp Art + Table A & B';
    } else if (d100 >= 41 && d100 <= 45) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones500gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 4), magicItemNames, magicItemIds);
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 3d6 500gp Gems + Table A & B';
    } else if (d100 >= 46 && d100 <= 50) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableA, _rollDice(1, 4), magicItemNames, magicItemIds);
      _rollMagicItems(SrdLootTables.magicItemTableB, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + Table A & B';
    } else if (d100 >= 51 && d100 <= 54) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1d4 Table C';
    } else if (d100 >= 55 && d100 <= 58) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects750gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 750gp Art + 1d4 Table C';
    } else if (d100 >= 59 && d100 <= 62) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones500gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 500gp Gems + 1d4 Table C';
    } else if (d100 >= 63 && d100 <= 66) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1d4 Table C';
    } else if (d100 >= 67 && d100 <= 68) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableD, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1 Table D';
    } else if (d100 >= 69 && d100 <= 70) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects750gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableD, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 750gp Art + 1 Table D';
    } else if (d100 >= 71 && d100 <= 72) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones500gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableD, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 500gp Gems + 1 Table D';
    } else if (d100 >= 73 && d100 <= 74) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableD, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1 Table D';
    } else if (d100 >= 75 && d100 <= 76) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableF, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1 Table F';
    } else if (d100 >= 77 && d100 <= 78) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects750gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableF, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 750gp Art + 1 Table F';
    } else if (d100 >= 79 && d100 <= 80) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones500gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableF, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 500gp Gems + 1 Table F';
    } else if (d100 >= 81 && d100 <= 82) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableF, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1 Table F';
    } else if (d100 >= 83 && d100 <= 85) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1d4 Table G';
    } else if (d100 >= 86 && d100 <= 88) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects750gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 2d4 750gp Art + 1d4 Table G';
    } else if (d100 >= 89 && d100 <= 90) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones500gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 500gp Gems + 1d4 Table G';
    } else if (d100 >= 91 && d100 <= 92) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1d4 Table G';
    } else if (d100 >= 93 && d100 <= 94) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects250gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableH, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 250gp Art + 1 Table H';
    } else if (d100 >= 95 && d100 <= 96) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects750gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableH, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 750gp Art + 1 Table H';
    } else if (d100 >= 97 && d100 <= 98) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones500gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableH, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 500gp Gems + 1 Table H';
    } else if (d100 == 99) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableH, 1, magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1 Table H';
    } else if (d100 == 100) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects750gp, _rollDice(2, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableI, 1, magicItemNames, magicItemIds);
      summary += ' • 2d4 750gp Art + 1 Table I';
    }

    return TreasureDropResult(
      tierLabel: TreasureTier.cr11To16.label,
      isHoard: true,
      gp: gp,
      pp: pp,
      gemstones: gems,
      artObjects: art,
      magicItemNames: magicItemNames,
      magicItemIds: magicItemIds,
      d100Roll: d100,
      rollSummary: summary,
    );
  }

  TreasureDropResult _generateHoardCr17Plus(int d100) {
    final gp = _rollDice(12, 6) * 1000;
    final pp = _rollDice(8, 6) * 1000;

    final gems = <GemArtItem>[];
    final art = <GemArtItem>[];
    final magicItemNames = <String>[];
    final magicItemIds = <String>[];

    String summary = 'CR 17+ Hoard (d100: $d100)';

    if (d100 >= 3 && d100 <= 5) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 8), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1d8 Table C';
    } else if (d100 >= 6 && d100 <= 8) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects2500gp, _rollDice(1, 10)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 8), magicItemNames, magicItemIds);
      summary += ' • 1d10 2500gp Art + 1d8 Table C';
    } else if (d100 >= 9 && d100 <= 11) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects7500gp, _rollDice(1, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 8), magicItemNames, magicItemIds);
      summary += ' • 1d4 7500gp Art + 1d8 Table C';
    } else if (d100 >= 12 && d100 <= 14) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones5000gp, _rollDice(1, 8)));
      _rollMagicItems(SrdLootTables.magicItemTableC, _rollDice(1, 8), magicItemNames, magicItemIds);
      summary += ' • 1d8 5000gp Gems + 1d8 Table C';
    } else if (d100 >= 15 && d100 <= 22) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableD, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1d6 Table D';
    } else if (d100 >= 23 && d100 <= 30) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects2500gp, _rollDice(1, 10)));
      _rollMagicItems(SrdLootTables.magicItemTableD, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 1d10 2500gp Art + 1d6 Table D';
    } else if (d100 >= 31 && d100 <= 38) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects7500gp, _rollDice(1, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableD, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 1d4 7500gp Art + 1d6 Table D';
    } else if (d100 >= 39 && d100 <= 46) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones5000gp, _rollDice(1, 8)));
      _rollMagicItems(SrdLootTables.magicItemTableD, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 1d8 5000gp Gems + 1d6 Table D';
    } else if (d100 >= 47 && d100 <= 52) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableE, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1d6 Table E';
    } else if (d100 >= 53 && d100 <= 58) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects2500gp, _rollDice(1, 10)));
      _rollMagicItems(SrdLootTables.magicItemTableE, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 1d10 2500gp Art + 1d6 Table E';
    } else if (d100 >= 59 && d100 <= 63) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects7500gp, _rollDice(1, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableE, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 1d4 7500gp Art + 1d6 Table E';
    } else if (d100 >= 64 && d100 <= 68) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones5000gp, _rollDice(1, 8)));
      _rollMagicItems(SrdLootTables.magicItemTableE, _rollDice(1, 6), magicItemNames, magicItemIds);
      summary += ' • 1d8 5000gp Gems + 1d6 Table E';
    } else if (d100 == 69) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1d4 Table G';
    } else if (d100 == 70) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects2500gp, _rollDice(1, 10)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d10 2500gp Art + 1d4 Table G';
    } else if (d100 == 71) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects7500gp, _rollDice(1, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d4 7500gp Art + 1d4 Table G';
    } else if (d100 == 72) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones5000gp, _rollDice(1, 8)));
      _rollMagicItems(SrdLootTables.magicItemTableG, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d8 5000gp Gems + 1d4 Table G';
    } else if (d100 >= 73 && d100 <= 74) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableH, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1d4 Table H';
    } else if (d100 >= 75 && d100 <= 76) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects2500gp, _rollDice(1, 10)));
      _rollMagicItems(SrdLootTables.magicItemTableH, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d10 2500gp Art + 1d4 Table H';
    } else if (d100 >= 77 && d100 <= 78) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects7500gp, _rollDice(1, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableH, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d4 7500gp Art + 1d4 Table H';
    } else if (d100 >= 79 && d100 <= 80) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones5000gp, _rollDice(1, 8)));
      _rollMagicItems(SrdLootTables.magicItemTableH, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d8 5000gp Gems + 1d4 Table H';
    } else if (d100 >= 81 && d100 <= 85) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones1000gp, _rollDice(3, 6)));
      _rollMagicItems(SrdLootTables.magicItemTableI, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 3d6 1000gp Gems + 1d4 Table I';
    } else if (d100 >= 86 && d100 <= 90) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects2500gp, _rollDice(1, 10)));
      _rollMagicItems(SrdLootTables.magicItemTableI, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d10 2500gp Art + 1d4 Table I';
    } else if (d100 >= 91 && d100 <= 95) {
      art.addAll(_pickRandomItems(SrdLootTables.artObjects7500gp, _rollDice(1, 4)));
      _rollMagicItems(SrdLootTables.magicItemTableI, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d4 7500gp Art + 1d4 Table I';
    } else if (d100 >= 96 && d100 <= 100) {
      gems.addAll(_pickRandomItems(SrdLootTables.gemstones5000gp, _rollDice(1, 8)));
      _rollMagicItems(SrdLootTables.magicItemTableI, _rollDice(1, 4), magicItemNames, magicItemIds);
      summary += ' • 1d8 5000gp Gems + 1d4 Table I';
    }

    return TreasureDropResult(
      tierLabel: TreasureTier.cr17Plus.label,
      isHoard: true,
      gp: gp,
      pp: pp,
      gemstones: gems,
      artObjects: art,
      magicItemNames: magicItemNames,
      magicItemIds: magicItemIds,
      d100Roll: d100,
      rollSummary: summary,
    );
  }

  List<GemArtItem> _pickRandomItems(List<GemArtItem> pool, int count) {
    if (pool.isEmpty || count <= 0) return [];
    final countsByName = <String, int>{};
    final itemsByName = <String, GemArtItem>{};

    for (int i = 0; i < count; i++) {
      final item = pool[_random.nextInt(pool.length)];
      countsByName[item.name] = (countsByName[item.name] ?? 0) + 1;
      itemsByName[item.name] = item;
    }

    return countsByName.entries.map((entry) {
      final base = itemsByName[entry.key]!;
      return base.copyWithCount(entry.value);
    }).toList();
  }

  void _rollMagicItems(
    RollableTable table,
    int count,
    List<String> namesOut,
    List<String> idsOut,
  ) {
    for (int i = 0; i < count; i++) {
      final res = table.roll(_random);
      namesOut.add(res.entry.label);
      if (res.entry.itemRefId != null) {
        idsOut.add(res.entry.itemRefId!);
      }
    }
  }

  /// Formats a complete drop result into clean Markdown for Discord, Foundry VTT, or DM notes.
  String formatMarkdownSummary(
    TreasureDropResult drop, {
    int? partySize,
    bool includeLiquidatedShares = false,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('### 💰 5e Treasure Drop: ${drop.isHoard ? 'Hoard' : 'Loot'} (${drop.tierLabel})');
    buffer.writeln('*${drop.rollSummary}*');
    buffer.writeln();

    buffer.writeln('**Coins & Currency:**');
    final coinList = <String>[];
    if (drop.pp > 0) coinList.add('${drop.pp} PP');
    if (drop.gp > 0) coinList.add('${drop.gp} GP');
    if (drop.ep > 0) coinList.add('${drop.ep} EP');
    if (drop.sp > 0) coinList.add('${drop.sp} SP');
    if (drop.cp > 0) coinList.add('${drop.cp} CP');
    if (coinList.isEmpty) {
      buffer.writeln('- None');
    } else {
      buffer.writeln('- ${coinList.join(', ')} *(Total Coin Value: ${drop.coinsGoldValue.toStringAsFixed(1)} GP)*');
    }
    buffer.writeln();

    if (drop.gemstones.isNotEmpty) {
      buffer.writeln('**Gemstones:**');
      for (final gem in drop.gemstones) {
        buffer.writeln('- ${gem.count}x ${gem.name} (${gem.gpValue} GP each -> ${gem.totalGp} GP total)');
      }
      buffer.writeln('*(Total Gems: ${drop.gemsGoldValue} GP)*');
      buffer.writeln();
    }

    if (drop.artObjects.isNotEmpty) {
      buffer.writeln('**Art Objects:**');
      for (final art in drop.artObjects) {
        buffer.writeln('- ${art.count}x ${art.name} (${art.gpValue} GP each -> ${art.totalGp} GP total)');
      }
      buffer.writeln('*(Total Art: ${drop.artGoldValue} GP)*');
      buffer.writeln();
    }

    if (drop.magicItemNames.isNotEmpty) {
      buffer.writeln('**Magic Items:**');
      for (final item in drop.magicItemNames) {
        buffer.writeln('- ✨ $item');
      }
      buffer.writeln();
    }

    buffer.writeln('**Total Estimated Hoard Value:** **${drop.grandTotalGoldValue.toStringAsFixed(1)} GP**');

    if (partySize != null && partySize > 1) {
      final share = drop.calculateShares(partySize, includeLiquidatedGemsAndArt: includeLiquidatedShares);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('**Party Distribution (${share.partySize} Players):**');
      if (includeLiquidatedShares) {
        buffer.writeln('- Each player receives: **${share.gpPerPlayer} GP** *(Liquidated all gems & art)*');
        if (share.remainderGpEquivalent > 0) {
          buffer.writeln('- Party Fund / Remainder: ${share.remainderCoins['gp'] ?? 0} GP');
        }
      } else {
        final sharesList = <String>[];
        if (share.ppPerPlayer > 0) sharesList.add('${share.ppPerPlayer} PP');
        if (share.gpPerPlayer > 0) sharesList.add('${share.gpPerPlayer} GP');
        if (share.epPerPlayer > 0) sharesList.add('${share.epPerPlayer} EP');
        if (share.spPerPlayer > 0) sharesList.add('${share.spPerPlayer} SP');
        if (share.cpPerPlayer > 0) sharesList.add('${share.cpPerPlayer} CP');

        if (sharesList.isNotEmpty) {
          buffer.writeln('- Coin Share per Player: **${sharesList.join(', ')}** *(~${share.totalGpEquivalentPerPlayer.toStringAsFixed(2)} GP value)*');
        }
        if (share.remainderCoins.isNotEmpty) {
          final remList = share.remainderCoins.entries.map((e) => '${e.value} ${e.key.toUpperCase()}').join(', ');
          buffer.writeln('- Leftover to Party Fund: $remList');
        }
      }
    }

    return buffer.toString();
  }
}
