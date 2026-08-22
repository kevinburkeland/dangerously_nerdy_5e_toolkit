import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex/srd_monster_cr_bands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex/srd_monster_lists.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';

void main() {
  setUp(() {
    MonsterItem.clearCaches();
  });

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

    test('calculates baseline DPR and sorts monsters logically by offensive output', () {
      final wolf = MonsterCodexLibrary.getMonsterByName('Wolf');
      final brownBear = MonsterCodexLibrary.getMonsterByName('Brown Bear');
      final fireElemental = MonsterCodexLibrary.getMonsterByName('Fire Elemental');

      expect(wolf, isNotNull);
      expect(brownBear, isNotNull);
      expect(fireElemental, isNotNull);

      final wolfDpr = wolf!.calculateBaselineDpr();
      final bearDpr = brownBear!.calculateBaselineDpr();
      final fireDpr = fireElemental!.calculateBaselineDpr();

      expect(wolfDpr > 0, isTrue);
      expect(bearDpr > wolfDpr, isTrue, reason: 'Brown Bear multiattack should deal more DPR than single wolf bite');
      expect(fireDpr > bearDpr, isTrue, reason: 'Fire Elemental multiattack should out-damage Brown Bear');

      expect(MonsterSortMode.values.length, 4);
      expect(MonsterSortMode.dprDescending.label, contains('DPR'));
    });

    test('extractDprAttacks does not double up attacks for creatures with alternative weapons or single actions', () {
      final skeleton = MonsterCodexLibrary.getMonsterByName('Skeleton');
      if (skeleton != null) {
        final attacks = skeleton.statBlock2014.extractDprAttacks();
        final activeAttacks = attacks.fold<int>(0, (sum, a) => sum + a.attacksPerRound);
        expect(activeAttacks, 1, reason: 'Skeleton without multiattack should have exactly 1 active attack per round');
      }

      final knight = MonsterCodexLibrary.getMonsterByName('Knight');
      if (knight != null) {
        final attacks = knight.statBlock2014.extractDprAttacks();
        final activeAttacks = attacks.fold<int>(0, (sum, a) => sum + a.attacksPerRound);
        expect(activeAttacks, 2, reason: 'Knight with two melee attacks should have exactly 2 active attacks per round');
      }

      final brownBear = MonsterCodexLibrary.getMonsterByName('Brown Bear');
      if (brownBear != null) {
        final attacks = brownBear.statBlock2014.extractDprAttacks();
        final activeAttacks = attacks.fold<int>(0, (sum, a) => sum + a.attacksPerRound);
        expect(activeAttacks, 2, reason: 'Brown Bear with 1 bite + 1 claws should have 2 active attacks per round');
      }

      final roper = MonsterCodexLibrary.getMonsterByName('Roper');
      expect(roper, isNotNull);
      if (roper != null) {
        final attacks = roper.statBlock2014.extractDprAttacks();
        final biteAttack = attacks.firstWhere((a) => a.name.toLowerCase() == 'bite');
        final tendrilAttack = attacks.firstWhere((a) => a.name.toLowerCase() == 'tendril');

        expect(biteAttack.attacksPerRound, 1, reason: 'Roper makes exactly 1 bite attack in its multiattack routine');
        expect(tendrilAttack.attacksPerRound, 4, reason: 'Roper makes 4 tendril attacks in its multiattack routine');

        final roperDpr = roper.calculateBaselineDpr();
        expect(roperDpr > 10 && roperDpr < 25, isTrue,
            reason: 'Roper baseline DPR: $roperDpr should reflect 1 bite (4d8+4 = 22 avg dmg), not 4 bites!');
      }
    });
  });
}



