import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex/srd_monster_cr_bands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex/srd_monster_lists.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';

void main() {
  group('MonsterCodexLibrary', () {
    test('builds a non-empty deduplicated monster list from SRD presets', () {
      final monsters = MonsterCodexLibrary.allMonsters;
      expect(monsters.isNotEmpty, isTrue);

      expect(SrdMonsterLists.spellSummonEntries, isNotEmpty);
      expect(SrdMonsterLists.magicItemEntries, isNotEmpty);
      expect(
        SrdMonsterLists.allSourceEntries.length,
        SrdMonsterLists.spellSummonEntries.length +
            SrdMonsterLists.magicItemEntries.length,
      );

      final ids = monsters.map((m) => m.id).toSet();
      expect(ids.length, monsters.length,
          reason: 'Monster codex should not contain duplicate ids');

      // Spot checks from multiple preset families.
      expect(MonsterCodexLibrary.getMonsterByName('Wolf'), isNotNull);
      expect(MonsterCodexLibrary.getMonsterByName('Skeleton'), isNotNull);
      expect(MonsterCodexLibrary.getMonsterByName('Air Elemental'), isNotNull);
      expect(MonsterCodexLibrary.getMonsterByName('Giant Wasp'), isNotNull);
    });

    test('provides source-category and preset-specific lists', () {
      final spellMonsters = MonsterCodexLibrary.getSpellSummonedMonsters();
      final itemMonsters = MonsterCodexLibrary.getMagicItemMonsters();

      expect(spellMonsters, isNotEmpty);
      expect(itemMonsters, isNotEmpty);

      expect(
        spellMonsters.every((m) => m.sourceCategory.name == 'spell'),
        isTrue,
      );
      expect(
        itemMonsters.every((m) => m.sourceCategory.name == 'magicItem'),
        isTrue,
      );

      final animateDead =
          MonsterCodexLibrary.getMonstersBySourcePreset('animate_dead');
      expect(animateDead.map((m) => m.name).toSet(), containsAll(['Skeleton', 'Zombie']));
    });

    test('builds CR-band source lists with complete coverage', () {
      expect(SrdMonsterCrBands.cr0ToQuarter, isNotEmpty);
      expect(SrdMonsterCrBands.crHalfToOne, isNotEmpty);
      expect(SrdMonsterCrBands.crTwoToFour, isNotEmpty);
      expect(SrdMonsterCrBands.crFiveToEight, isNotEmpty);

      final totalBandEntries =
          SrdMonsterCrBands.cr0ToQuarter.length +
              SrdMonsterCrBands.crHalfToOne.length +
              SrdMonsterCrBands.crTwoToFour.length +
              SrdMonsterCrBands.crFiveToEight.length +
              SrdMonsterCrBands.crNinePlus.length;

      expect(totalBandEntries, SrdMonsterLists.allSourceEntries.length);
      expect(
        SrdMonsterCrBands.allEntriesByCrBand.length,
        SrdMonsterLists.allSourceEntries.length,
      );
    });

    test('provides codex-level CR band helper lists', () {
      final low = MonsterCodexLibrary.getCr0ToQuarterMonsters();
      final lowMid = MonsterCodexLibrary.getCrHalfToOneMonsters();
      final mid = MonsterCodexLibrary.getCrTwoToFourMonsters();
      final high = MonsterCodexLibrary.getCrFiveToEightMonsters();

      expect(low, isNotEmpty);
      expect(lowMid, isNotEmpty);
      expect(mid, isNotEmpty);
      expect(high, isNotEmpty);

      expect(low.every((m) => m.challengeRating >= 0 && m.challengeRating <= 0.25), isTrue);
      expect(lowMid.every((m) => m.challengeRating >= 0.5 && m.challengeRating <= 1), isTrue);
      expect(mid.every((m) => m.challengeRating >= 2 && m.challengeRating <= 4), isTrue);
      expect(high.every((m) => m.challengeRating >= 5 && m.challengeRating <= 8), isTrue);
    });

    test('parses challenge ratings and supports CR range filters', () {
      final wolves = MonsterCodexLibrary.search('wolf');
      expect(wolves.isNotEmpty, isTrue);

      final lowCr = MonsterCodexLibrary.getMonstersByCrRange(maxCr: 0.25);
      expect(lowCr.isNotEmpty, isTrue);
      expect(lowCr.every((m) => m.challengeRating <= 0.25), isTrue);

      final highCr = MonsterCodexLibrary.getMonstersByCrRange(minCr: 5);
      expect(highCr.isNotEmpty, isTrue);
      expect(highCr.every((m) => m.challengeRating >= 5), isTrue);
    });

    test('supports type, size, and free-text search filters', () {
      final undead = MonsterCodexLibrary.getMonstersByType('Undead');
      expect(undead.isNotEmpty, isTrue);
      expect(undead.every((m) => m.type.toLowerCase() == 'undead'), isTrue);

      final medium = MonsterCodexLibrary.getMonstersBySize('Medium');
      expect(medium.isNotEmpty, isTrue);
      expect(medium.every((m) => m.size.toLowerCase() == 'medium'), isTrue);

      final packTactics = MonsterCodexLibrary.search('pack tactics');
      expect(packTactics.isNotEmpty, isTrue);
      expect(
        packTactics.any(
          (m) => m.name.toLowerCase().contains('wolf') ||
              m.traits.any((t) => t.name.toLowerCase() == 'pack tactics'),
        ),
        isTrue,
      );
    });

    test('preserves action and trait details for codex entries', () {
      final giantScorpion = MonsterCodexLibrary.getMonsterByName('Giant Scorpion');
      expect(giantScorpion, isNotNull);

      expect(giantScorpion!.actions, isNotEmpty);
      expect(
        giantScorpion.actions.any((CreatureAction action) =>
            action.name.toLowerCase().contains('claw') ||
            action.name.toLowerCase().contains('sting')),
        isTrue,
      );
    });
  });
}
