import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/dpr_calculator_engine.dart';

void main() {
  group('DprCalculatorEngine Math & Probabilities', () {
    test('expectedDieValue computes exact 5e dice expectations', () {
      // Standard dice
      expect(DprCalculatorEngine.expectedDieValue(6), closeTo(3.5, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(8), closeTo(4.5, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(10), closeTo(5.5, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(12), closeTo(6.5, 0.001));

      // GWF 2014 rerolls (1s & 2s rerolled)
      expect(DprCalculatorEngine.expectedDieValue(6, gwf: GwfVersion.v2014Reroll), closeTo(4.1667, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(8, gwf: GwfVersion.v2014Reroll), closeTo(5.25, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(10, gwf: GwfVersion.v2014Reroll), closeTo(6.30, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(12, gwf: GwfVersion.v2014Reroll), closeTo(7.3333, 0.001));

      // GWF 2024 floor 3 (1s & 2s treated as 3)
      expect(DprCalculatorEngine.expectedDieValue(6, gwf: GwfVersion.v2024Floor3), closeTo(4.0, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(8, gwf: GwfVersion.v2024Floor3), closeTo(4.875, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(10, gwf: GwfVersion.v2024Floor3), closeTo(5.8, 0.001));
      expect(DprCalculatorEngine.expectedDieValue(12, gwf: GwfVersion.v2024Floor3), closeTo(6.75, 0.001));
    });

    test('calculateHitProbability correctly evaluates roll requirements and advantage states', () {
      // +7 attack bonus vs AC 15 -> needs roll of 8 -> 13/20 = 0.65 base hit chance
      final pNormal = DprCalculatorEngine.calculateHitProbability(7, 15, AdvantageType.normal);
      expect(pNormal, closeTo(0.65, 0.001));

      // Advantage: 1 - (1 - 0.65)^2 = 1 - 0.1225 = 0.8775
      final pAdv = DprCalculatorEngine.calculateHitProbability(7, 15, AdvantageType.advantage);
      expect(pAdv, closeTo(0.8775, 0.001));

      // Disadvantage: 0.65^2 = 0.4225
      final pDis = DprCalculatorEngine.calculateHitProbability(7, 15, AdvantageType.disadvantage);
      expect(pDis, closeTo(0.4225, 0.001));

      // Elven Accuracy: 1 - (1 - 0.65)^3 = 1 - 0.042875 = 0.957125
      final pElven = DprCalculatorEngine.calculateHitProbability(7, 15, AdvantageType.elvenAccuracy);
      expect(pElven, closeTo(0.9571, 0.001));

      // Clamped limits: Nat 1 always misses (max 95%), Nat 20 always hits (min 5%)
      expect(DprCalculatorEngine.calculateHitProbability(25, 5, AdvantageType.normal), closeTo(0.95, 0.001));
      expect(DprCalculatorEngine.calculateHitProbability(-10, 30, AdvantageType.normal), closeTo(0.05, 0.001));
    });

    test('calculateCritProbability correctly evaluates expanded crit ranges', () {
      expect(DprCalculatorEngine.calculateCritProbability(AdvantageType.normal, critThreshold: 20), closeTo(0.05, 0.001));
      expect(DprCalculatorEngine.calculateCritProbability(AdvantageType.normal, critThreshold: 19), closeTo(0.10, 0.001));
      expect(DprCalculatorEngine.calculateCritProbability(AdvantageType.normal, critThreshold: 18), closeTo(0.15, 0.001));

      // Crit with Advantage
      expect(DprCalculatorEngine.calculateCritProbability(AdvantageType.advantage, critThreshold: 20), closeTo(0.0975, 0.001));
      expect(DprCalculatorEngine.calculateCritProbability(AdvantageType.advantage, critThreshold: 19), closeTo(0.19, 0.001));
    });

    test('calculateSingleAttackDpr evaluates basic weapon attack DPR', () {
      // 1d8 + 3 (mod +3, to-hit +5) vs AC 15
      // Hit prob = (21 - 10)/20 = 0.55. Crit prob = 0.05. Regular hit prob = 0.50.
      // Reg damage = 4.5 + 3 = 7.5. Crit damage = 9.0 + 3 = 12.0.
      // DPR = (0.50 * 7.5) + (0.05 * 12.0) = 3.75 + 0.60 = 4.35.
      const attack = DprAttackAction(
        id: 'test_sword',
        name: 'Longsword',
        attackBonus: 5,
        diceCount: 1,
        diceSides: 8,
        damageBonus: 3,
      );

      final pt = DprCalculatorEngine.calculateSingleAttackDpr(attack, 15, AdvantageType.normal);
      expect(pt.dpr, closeTo(4.35, 0.01));
      expect(pt.hitChance, closeTo(0.55, 0.01));
      expect(pt.critChance, closeTo(0.05, 0.01));
    });

    test('calculateGwmBreakEven identifies crossover AC for power attack feats', () {
      const barbarian = DprCombatantProfile(
        id: 'barbarian_gwm',
        name: 'Barbarian GWM',
        level: 5,
        abilityScore: 18,
        proficiencyBonus: 3,
        defaultAdvantage: AdvantageType.advantage,
        attacks: [
          DprAttackAction(
            id: 'barb_greatsword',
            name: 'Greatsword',
            attackBonus: 7,
            diceCount: 2,
            diceSides: 6,
            damageBonus: 6,
            damageType: 'slashing',
            gwfVersion: GwfVersion.v2014Reroll,
            attacksPerRound: 2,
          ),
        ],
      );
      final analysis = DprCalculatorEngine.calculateGwmBreakEven(barbarian);

      // Barbarian with Reckless Advantage should have a high break-even AC (typically around AC 16-19)
      expect(analysis.maxOptimalAcForGwm, isNotNull);
      expect(analysis.maxOptimalAcForGwm!, greaterThanOrEqualTo(14));
      expect(analysis.maxOptimalAcForGwm!, lessThanOrEqualTo(22));

      // Verify GWM DPR is higher than Normal DPR at low AC (e.g. AC 10)
      final gwmLowAc = analysis.powerAttackCurve.pointAt(10)!.dpr;
      final baseLowAc = analysis.baselineCurve.pointAt(10)!.dpr;
      expect(gwmLowAc, greaterThan(baseLowAc));

      // Verify Normal DPR is higher than GWM DPR at very high AC (e.g. AC 25)
      final gwmHighAc = analysis.powerAttackCurve.pointAt(25)!.dpr;
      final baseHighAc = analysis.baselineCurve.pointAt(25)!.dpr;
      expect(baseHighAc, greaterThan(gwmHighAc));
    });

    test('WeaponMastery.graze deals ability modifier damage on miss', () {
      const attackWithGraze = DprAttackAction(
        id: 'graze_sword',
        name: 'Greatsword',
        attackBonus: 5,
        diceCount: 2,
        diceSides: 6,
        damageBonus: 4,
        weaponMastery: WeaponMastery.graze,
        abilityModForGraze: 4,
      );

      const attackWithoutGraze = DprAttackAction(
        id: 'normal_sword',
        name: 'Greatsword',
        attackBonus: 5,
        diceCount: 2,
        diceSides: 6,
        damageBonus: 4,
      );

      final ptGraze = DprCalculatorEngine.calculateSingleAttackDpr(attackWithGraze, 20, AdvantageType.normal);
      final ptNormal = DprCalculatorEngine.calculateSingleAttackDpr(attackWithoutGraze, 20, AdvantageType.normal);

      // Against high AC 20 (frequent miss), Graze DPR must be significantly higher
      expect(ptGraze.dpr, greaterThan(ptNormal.dpr));
      expect(ptGraze.expectedDamageOnMiss, equals(4.0));
      expect(ptNormal.expectedDamageOnMiss, equals(0.0));
    });

    test('Sneak Attack is factored in once per turn across multiple attacks', () {
      const rogue = DprCombatantProfile(
        id: 'rogue_sneak_attack',
        name: 'Rogue Sneak Attack',
        level: 5,
        abilityScore: 18,
        proficiencyBonus: 3,
        defaultAdvantage: AdvantageType.advantage,
        sneakAttackDiceCount: 3,
        sneakAttackDiceSides: 6,
        attacks: [
          DprAttackAction(
            id: 'rogue_shortbow',
            name: 'Shortbow',
            attackBonus: 7,
            diceCount: 1,
            diceSides: 6,
            damageBonus: 4,
            damageType: 'piercing',
            attacksPerRound: 1,
            weaponMastery: WeaponMastery.vex,
          ),
        ],
      );
      final curve = DprCalculatorEngine.generateCurve(rogue, minAc: 10, maxAc: 20);

      final pt = curve.pointAt(15);
      expect(pt, isNotNull);
      expect(pt!.dpr, greaterThan(10.0)); // 1d6+4 + 3d6 sneak attack with advantage
    });

    test('Agonizing Blast adds ability modifier to cantrip damage', () {
      const ebWithoutAgonizing = DprAttackAction(
        id: 'eb_1',
        name: 'Eldritch Blast',
        attackBonus: 7,
        diceCount: 1,
        diceSides: 10,
        damageBonus: 0,
        damageType: 'force',
        hasAgonizingBlast: false,
      );

      const ebWithAgonizing = DprAttackAction(
        id: 'eb_2',
        name: 'Eldritch Blast',
        attackBonus: 7,
        diceCount: 1,
        diceSides: 10,
        damageBonus: 0,
        damageType: 'force',
        hasAgonizingBlast: true,
        abilityModForAgonizing: 4,
      );

      final ptWithout = DprCalculatorEngine.calculateSingleAttackDpr(ebWithoutAgonizing, 15, AdvantageType.normal);
      final ptWith = DprCalculatorEngine.calculateSingleAttackDpr(ebWithAgonizing, 15, AdvantageType.normal);

      // Hit chance = 0.65 (need 8+ on d20). Expected hit damage increases by 4.
      expect(ptWith.expectedDamageOnHit, equals(ptWithout.expectedDamageOnHit + 4.0));
      expect(ptWith.dpr, greaterThan(ptWithout.dpr));
    });

    test('Halfling Luck rerolls natural 1s and boosts accuracy and crit chances', () {
      const attack = DprAttackAction(
        id: 'halfling_dagger',
        name: 'Dagger',
        attackBonus: 5,
        diceCount: 1,
        diceSides: 4,
        damageBonus: 3,
      );

      final standardPt = DprCalculatorEngine.calculateSingleAttackDpr(attack, 15, AdvantageType.normal, hasHalflingLuck: false);
      final luckyPt = DprCalculatorEngine.calculateSingleAttackDpr(attack, 15, AdvantageType.normal, hasHalflingLuck: true);

      expect(luckyPt.hitChance, greaterThan(standardPt.hitChance));
      expect(luckyPt.critChance, greaterThan(standardPt.critChance));
      expect(luckyPt.dpr, greaterThan(standardPt.dpr));
    });

    test('DprWeaponPreset contains Shillelagh, Magic Stone, and Shadow Blade presets', () {
      final shillelagh = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'shillelagh');
      expect(shillelagh.name, contains('Shillelagh'));
      expect(shillelagh.diceSides, equals(8));
      expect(shillelagh.isCantrip, isTrue);

      final magicStone = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'magic_stone');
      expect(magicStone.name, contains('Magic Stone'));
      expect(magicStone.isRanged, isTrue);
      expect(magicStone.isCantrip, isTrue);

      final shadowBlade = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'shadow_blade_2');
      expect(shadowBlade.name, contains('Shadow Blade'));
      expect(shadowBlade.diceCount, equals(2));
      expect(shadowBlade.diceSides, equals(8));
      expect(shadowBlade.damageType, equals('psychic'));
    });

    test('MonsterItem adapter cleanly parses monster actions for future monster arena reuse', () {
      final monster = MonsterCodexLibrary.allMonsters.firstWhere(
        (m) => m.name.toLowerCase().contains('goblin'),
        orElse: () => MonsterCodexLibrary.allMonsters.first,
      );

      final profile = DprCombatantProfile.fromMonsterItem(monster);
      expect(profile.name, isNotEmpty);
      expect(profile.attacks, isNotEmpty);

      final curve = DprCalculatorEngine.generateCurve(profile, minAc: 10, maxAc: 20);
      expect(curve.points.length, equals(11));
      expect(curve.pointAt(15)!.dpr, greaterThan(0));
    });
  });
}
