import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart'
    show parseChallengeRating;

import 'srd_monster_lists.dart';

class SrdMonsterCrBands {
  SrdMonsterCrBands._();

  /// CR 0 through 1/4.
  static final List<MonsterSourceEntry> cr0ToQuarter = _entriesInRange(
    minCr: 0,
    maxCr: 0.25,
  );

  /// CR 1/2 through 1.
  static final List<MonsterSourceEntry> crHalfToOne = _entriesInRange(
    minCr: 0.5,
    maxCr: 1,
  );

  /// CR 2 through 4.
  static final List<MonsterSourceEntry> crTwoToFour = _entriesInRange(
    minCr: 2,
    maxCr: 4,
  );

  /// CR 5 through 8.
  static final List<MonsterSourceEntry> crFiveToEight = _entriesInRange(
    minCr: 5,
    maxCr: 8,
  );

  /// CR 9+.
  static final List<MonsterSourceEntry> crNinePlus = _entriesInRange(
    minCr: 9,
    maxCr: double.infinity,
  );

  /// Full SRD source list grouped and merged by challenge rating bands.
  static final List<MonsterSourceEntry> allEntriesByCrBand = [
    ...cr0ToQuarter,
    ...crHalfToOne,
    ...crTwoToFour,
    ...crFiveToEight,
    ...crNinePlus,
  ];

  static List<MonsterSourceEntry> _entriesInRange({
    required double minCr,
    required double maxCr,
  }) {
    return SrdMonsterLists.allSourceEntries.where((entry) {
      final cr = parseChallengeRating(entry.statBlock.crDisplay) ?? 0;
      return cr >= minCr && cr <= maxCr;
    }).toList(growable: false);
  }
}
