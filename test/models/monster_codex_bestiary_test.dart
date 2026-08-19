import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';

void main() {
  group('MonsterCodexLibrary Bestiary Ingestion Tests', () {
    test('allMonsters contains populated bestiary entries', () {
      final monsters = MonsterCodexLibrary.allMonsters;
      expect(monsters.isNotEmpty, isTrue);
      expect(monsters.length, greaterThanOrEqualTo(50));
    });

    test('retrieves iconic monsters across CR spectrum', () {
      final goblin = MonsterCodexLibrary.getMonsterByName('Goblin');
      expect(goblin, isNotNull);
      expect(goblin!.crDisplay, 'CR 1/4');
      expect(goblin.ac, 15);
      expect(goblin.actions.any((a) => a.name == 'Scimitar'), isTrue);

      final gelCube = MonsterCodexLibrary.getMonsterByName('Gelatinous Cube');
      expect(gelCube, isNotNull);
      expect(gelCube!.type, 'Ooze');
      expect(gelCube.crDisplay, 'CR 2');

      final hydra = MonsterCodexLibrary.getMonsterByName('Hydra');
      expect(hydra, isNotNull);
      expect(hydra!.crDisplay, 'CR 8');
      expect(hydra.hp, 172);

      final lich = MonsterCodexLibrary.getMonsterByName('Lich');
      expect(lich, isNotNull);
      expect(lich!.crDisplay, 'CR 21');
      expect(lich.type, 'Undead');

      final tarrasque = MonsterCodexLibrary.getMonsterByName('Tarrasque');
      expect(tarrasque, isNotNull);
      expect(tarrasque!.crDisplay, 'CR 30');
      expect(tarrasque.hp, 676);
      expect(tarrasque.ac, 25);
    });

    test('filters properly by CR bands', () {
      final cr0ToQuarter = MonsterCodexLibrary.getCr0ToQuarterMonsters();
      expect(cr0ToQuarter.isNotEmpty, isTrue);
      expect(cr0ToQuarter.every((m) => m.challengeRating <= 0.25), isTrue);

      final crHalfToOne = MonsterCodexLibrary.getCrHalfToOneMonsters();
      expect(crHalfToOne.isNotEmpty, isTrue);
      expect(crHalfToOne.every((m) => m.challengeRating >= 0.5 && m.challengeRating <= 1.0), isTrue);

      final crTwoToFour = MonsterCodexLibrary.getCrTwoToFourMonsters();
      expect(crTwoToFour.isNotEmpty, isTrue);
      expect(crTwoToFour.every((m) => m.challengeRating >= 2.0 && m.challengeRating <= 4.0), isTrue);

      final crFiveToEight = MonsterCodexLibrary.getCrFiveToEightMonsters();
      expect(crFiveToEight.isNotEmpty, isTrue);
      expect(crFiveToEight.every((m) => m.challengeRating >= 5.0 && m.challengeRating <= 8.0), isTrue);

      final crNinePlus = MonsterCodexLibrary.getCrNinePlusMonsters();
      expect(crNinePlus.isNotEmpty, isTrue);
      expect(crNinePlus.every((m) => m.challengeRating >= 9.0), isTrue);
    });

    test('supports searching by name, type, action, and trait keywords', () {
      final packTacticsMonsters = MonsterCodexLibrary.search('pack tactics');
      expect(packTacticsMonsters.isNotEmpty, isTrue);
      expect(packTacticsMonsters.any((m) => m.name == 'Wolf'), isTrue);

      final dragonMonsters = MonsterCodexLibrary.search('', typeFilter: 'Dragon');
      expect(dragonMonsters.isNotEmpty, isTrue);
      expect(dragonMonsters.any((m) => m.name.contains('Dragon')), isTrue);
    });

    test('edition-aware stat blocks return valid models for 2014 and 2024', () {
      for (final monster in MonsterCodexLibrary.allMonsters) {
        final stat2014 = monster.getStatBlock(DmRulesEdition.v2014);
        final stat2024 = monster.getStatBlock(DmRulesEdition.v2024);

        expect(stat2014.name.isNotEmpty, isTrue);
        expect(stat2024.name.isNotEmpty, isTrue);
        expect(stat2014.ac, greaterThan(0));
        expect(stat2024.ac, greaterThan(0));
        expect(stat2014.maxHp, greaterThan(0));
        expect(stat2024.maxHp, greaterThan(0));
      }
    });
  });
}
