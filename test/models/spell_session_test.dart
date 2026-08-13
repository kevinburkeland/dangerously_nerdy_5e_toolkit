import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spell_session.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons.dart';

void main() {
  group('SpellSession Budget & Point Tests', () {
    test('5th level spell slot max points is 10 for Animate Objects', () {
      final session = SpellSession(spellLevel: 5);
      expect(session.maxPoints, 10);
      expect(session.usedPoints, 0);
      expect(session.remainingPoints, 10);
    });

    test('Higher spell level increases max points', () {
      final s6 = SpellSession(spellLevel: 6);
      expect(s6.maxPoints, 12);

      final s9 = SpellSession(spellLevel: 9);
      expect(s9.maxPoints, 18);
    });

    test('canAddObject checks remaining point budget', () {
      final session = SpellSession(spellLevel: 5); // 10 points
      expect(session.canAddObject(ObjectSize.tiny), true); // 1 pt
      expect(session.canAddObject(ObjectSize.huge), true); // 8 pts

      // Add Huge object (8 pts)
      session.addObject(ObjectSize.huge);
      expect(session.usedPoints, 8);
      expect(session.remainingPoints, 2);

      expect(session.canAddObject(ObjectSize.huge), false); // Needs 8, only 2 left
      expect(session.canAddObject(ObjectSize.medium), true); // Needs 2, 2 left
    });

    test('addObject rejects object if budget exceeded', () {
      final session = SpellSession(spellLevel: 5);
      session.addObject(ObjectSize.huge); // 8 pts
      session.addObject(ObjectSize.huge); // Should be ignored (8 > 2 remaining)

      expect(session.activeObjects.length, 1);
      expect(session.usedPoints, 8);
    });

    test('healAll and applyGroupDamage affect active objects', () {
      final session = SpellSession(spellLevel: 5);
      session.addObject(ObjectSize.tiny, customName: 'Coin 1');
      session.addObject(ObjectSize.tiny, customName: 'Coin 2');

      expect(session.activeObjects.length, 2);

      session.applyGroupDamage(5);
      for (var obj in session.activeObjects) {
        expect(obj.currentHp, 15);
      }

      session.healAll();
      for (var obj in session.activeObjects) {
        expect(obj.currentHp, 20);
      }
    });

    test('performBatchAttack generates results for all active non-dead objects', () {
      final session = SpellSession(spellLevel: 5);
      session.addObject(ObjectSize.tiny);
      session.addObject(ObjectSize.tiny);
      session.addObject(ObjectSize.small);

      final summary = session.performBatchAttack(targetAc: 15);
      expect(summary.totalAttacks, 3);
      expect(summary.results.length, 3);
      expect(summary.targetAc, 15);
    });

    test('Dead objects do not attack in batch attack', () {
      final session = SpellSession(spellLevel: 5);
      session.addObject(ObjectSize.tiny);
      session.addObject(ObjectSize.tiny);

      // Kill first object
      session.activeObjects.first.takeDamage(100);
      expect(session.activeObjects.first.isDead, true);

      final summary = session.performBatchAttack(targetAc: 10);
      expect(summary.totalAttacks, 1);
      expect(summary.results.length, 1);
    });

    test('performBatchAttack supports useMaximizedCrits toggle', () {
      final session = SpellSession(spellLevel: 5);
      session.addObject(ObjectSize.tiny);

      final summaryNormal = session.performBatchAttack(targetAc: 15, useMaximizedCrits: false);
      expect(summaryNormal.useMaximizedCrits, false);

      final summaryMax = session.performBatchAttack(targetAc: 15, useMaximizedCrits: true);
      expect(summaryMax.useMaximizedCrits, true);
    });

    test('SRD Summons support: addMinionFromStatBlock & rollBagOfTricks', () {
      final session = SpellSession(spellLevel: 5);
      session.addMinionFromStatBlock(SrdSummonsLibrary.wolf);
      session.addMinionFromStatBlock(SrdSummonsLibrary.direWolf);
      session.addMinionFromStatBlock(SrdSummonsLibrary.giantSpider);

      expect(session.activeObjects.length, 3);
      expect(session.activeObjects[0].hasPackTactics, true);
      expect(session.activeObjects[2].secondaryDamageDiceCount, 2);

      // Test Bag of Tricks pull
      final pulled = session.rollBagOfTricks();
      expect(session.activeObjects.length, 4);
      expect(pulled.name.isNotEmpty, true);
    });

    test('rollHornOfValhalla generates correct Berserker counts per variant', () {
      final session = SpellSession(spellLevel: 5);
      
      // Silver: 2d4+2 (range 4 to 10)
      final countSilver = session.rollHornOfValhalla('silver');
      expect(countSilver >= 4 && countSilver <= 10, true);
      expect(session.activeObjects.length, countSilver);
      session.clearAll();

      // Brass: 3d4+3 (range 6 to 15)
      final countBrass = session.rollHornOfValhalla('brass');
      expect(countBrass >= 6 && countBrass <= 15, true);
      expect(session.activeObjects.length, countBrass);
      session.clearAll();

      // Bronze: 4d4+4 (range 8 to 20)
      final countBronze = session.rollHornOfValhalla('bronze');
      expect(countBronze >= 8 && countBronze <= 20, true);
      expect(session.activeObjects.length, countBronze);
      session.clearAll();

      // Iron: 5d4+5 (range 10 to 25)
      final countIron = session.rollHornOfValhalla('iron');
      expect(countIron >= 10 && countIron <= 25, true);
      expect(session.activeObjects.length, countIron);
    });
  });
}
