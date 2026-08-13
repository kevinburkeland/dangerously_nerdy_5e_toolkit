import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spell_session.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons.dart';

void main() {
  group('Summoning Spells Upcasting & Roll Rules Audit', () {
    test('Animate Objects scales point budget correctly with spell slot level', () {
      final session = SpellSession(
        activePreset: AnimateObjectsSummon.preset,
        spellLevel: 5,
      );
      expect(session.maxPoints, equals(10));

      session.spellLevel = 6;
      expect(session.maxPoints, equals(12));

      session.spellLevel = 7;
      expect(session.maxPoints, equals(14));

      session.spellLevel = 8;
      expect(session.maxPoints, equals(16));

      session.spellLevel = 9;
      expect(session.maxPoints, equals(18));
    });

    test('Conjure Animals scales beast capacity correctly with upcasting slots', () {
      final session = SpellSession(
        activePreset: BeastSummons.conjureAnimalsPreset,
        spellLevel: 3,
      );
      expect(session.maxPoints, equals(8));

      session.spellLevel = 5;
      expect(session.maxPoints, equals(16));

      session.spellLevel = 7;
      expect(session.maxPoints, equals(24));

      session.spellLevel = 9;
      expect(session.maxPoints, equals(32));
    });

    test('Animate Dead scales undead capacity by +2 per slot level above 3rd', () {
      final session = SpellSession(
        activePreset: UndeadSummons.animateDeadPreset,
        spellLevel: 3,
      );
      expect(session.maxPoints, equals(1));

      session.spellLevel = 4;
      expect(session.maxPoints, equals(3));

      session.spellLevel = 5;
      expect(session.maxPoints, equals(5));

      session.spellLevel = 9;
      expect(session.maxPoints, equals(13));
    });

    test('Create Undead scales Ghoul/undead capacity with slot level', () {
      final session = SpellSession(
        activePreset: UndeadSummons.createUndeadPreset,
        spellLevel: 6,
      );
      expect(session.maxPoints, equals(3));

      session.spellLevel = 7;
      expect(session.maxPoints, equals(4));

      session.spellLevel = 8;
      expect(session.maxPoints, equals(5));

      session.spellLevel = 9;
      expect(session.maxPoints, equals(6));
    });

    test('Conjure Minor Elementals scales mephit capacity with upcast slots', () {
      final session = SpellSession(
        activePreset: ElementalSummons.conjureMinorElementalsPreset,
        spellLevel: 4,
      );
      expect(session.maxPoints, equals(8));

      session.spellLevel = 6;
      expect(session.maxPoints, equals(16));

      session.spellLevel = 8;
      expect(session.maxPoints, equals(24));
    });

    test('Creature statblocks include appropriate roll formulas and special traits', () {
      // Wolf - Pack Tactics & Trip
      expect(BeastSummons.wolf.attackBonus, equals(4));
      expect(BeastSummons.wolf.fullDamageFormula, equals('2d4+2 Piercing'));
      expect(BeastSummons.wolf.hasPackTactics, isTrue);

      // Giant Spider - Bite + Poison Secondary Damage
      expect(BeastSummons.giantSpider.secondaryDamageDiceCount, equals(2));
      expect(BeastSummons.giantSpider.secondaryDamageDiceSides, equals(8));
      expect(BeastSummons.giantSpider.secondaryDamageType, equals('Poison'));
      expect(BeastSummons.giantSpider.fullDamageFormula, contains('+ 2d8 Poison'));

      // Mummy - Rotting Fist + Necrotic Secondary Damage
      expect(UndeadSummons.mummy.secondaryDamageDiceCount, equals(3));
      expect(UndeadSummons.mummy.secondaryDamageDiceSides, equals(6));
      expect(UndeadSummons.mummy.secondaryDamageType, equals('Necrotic'));
      expect(UndeadSummons.mummy.fullDamageFormula, contains('+ 3d6 Necrotic'));

      // Air Elemental
      expect(ElementalSummons.airElemental.attackBonus, equals(8));
      expect(ElementalSummons.airElemental.fullDamageFormula, equals('2d8+5 Bludgeoning'));
    });

    test('Batch attack roller calculates primary and secondary damage rolls correctly', () {
      final session = SpellSession(
        activePreset: BeastSummons.conjureAnimalsPreset,
        spellLevel: 3,
      );
      session.addMinionFromStatBlock(BeastSummons.giantSpider);
      session.addMinionFromStatBlock(BeastSummons.wolf);

      final summary = session.performBatchAttack(targetAc: 10);
      expect(summary.totalAttacks, equals(2));
      expect(summary.results.length, equals(2));

      final spiderResult = summary.results.firstWhere((r) => r.object.name.startsWith('Giant Spider'));
      expect(spiderResult.object.secondaryDamageDiceCount, equals(2));
      expect(spiderResult.object.secondaryDamageType, equals('Poison'));
    });
  });
}
