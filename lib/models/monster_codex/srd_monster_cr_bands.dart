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
      final cr = _parseChallengeRating(entry.statBlock.crDisplay);
      return cr >= minCr && cr <= maxCr;
    }).toList(growable: false);
  }

  static double _parseChallengeRating(String crDisplay) {
    final cleaned = crDisplay.replaceAll(RegExp(r'[^0-9/]'), '');
    if (cleaned.isEmpty) return 0;

    if (cleaned.contains('/')) {
      final pieces = cleaned.split('/');
      if (pieces.length != 2) return 0;
      final numerator = double.tryParse(pieces[0]) ?? 0;
      final denominator = double.tryParse(pieces[1]) ?? 1;
      if (denominator == 0) return 0;
      return numerator / denominator;
    }

    return double.tryParse(cleaned) ?? 0;
  }
}
