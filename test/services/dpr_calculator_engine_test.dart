import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
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

      final eb1 = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'eldritch_blast_1');
      final eb2 = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'eldritch_blast_2');
      final eb3 = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'eldritch_blast_3');
      final eb4 = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'eldritch_blast_4');

      expect(eb1.defaultAttacksPerRound, equals(1));
      expect(eb2.defaultAttacksPerRound, equals(2));
      expect(eb3.defaultAttacksPerRound, equals(3));
      expect(eb4.defaultAttacksPerRound, equals(4));

      final fb4 = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'fire_bolt_4');
      expect(fb4.diceCount, equals(4));
      expect(fb4.diceSides, equals(10));

      final shadowBlade = DprWeaponPreset.allPresets.firstWhere((p) => p.id == 'shadow_blade_2');
      expect(shadowBlade.name, contains('Shadow Blade'));
      expect(shadowBlade.diceCount, equals(2));
      expect(shadowBlade.diceSides, equals(8));
      expect(shadowBlade.damageType, equals('psychic'));
    });

    test('calculateSaveFailureProbability computes exact 5e save failure rates', () {
      // DC 15 vs +2 Save -> needs 13 on d20 -> pass prob = (21-13)/20 = 8/20 = 0.40 -> fail prob = 0.60
      final failNormal = DprCalculatorEngine.calculateSaveFailureProbability(saveDc: 15, targetSaveBonus: 2);
      expect(failNormal, closeTo(0.60, 0.001));

      // With Advantage on Save: Pass prob = 1 - (1 - 0.40)^2 = 1 - 0.36 = 0.64 -> fail prob = 0.36
      final failAdv = DprCalculatorEngine.calculateSaveFailureProbability(saveDc: 15, targetSaveBonus: 2, targetHasAdvantage: true);
      expect(failAdv, closeTo(0.36, 0.001));

      // With Disadvantage on Save: Pass prob = 0.40^2 = 0.16 -> fail prob = 0.84
      final failDis = DprCalculatorEngine.calculateSaveFailureProbability(saveDc: 15, targetSaveBonus: 2, targetHasDisadvantage: true);
      expect(failDis, closeTo(0.84, 0.001));
    });

    test('Sneak Attack EV properly factors in crit multiplier on sneak dice', () {
      // 1 attack with +7 vs AC 15 (Hit: 0.65, Crit: 0.05). Sneak Attack: 2d6 (EV = 7.0)
      // Base attack: 1d6+4 (EV Hit = 7.5, EV Crit = 11.0, DPR = 0.60*7.5 + 0.05*11.0 = 4.5 + 0.55 = 5.05)
      // Sneak Attack EV: [P(Hit) + P(Crit)] * 7.0 = [0.65 + 0.05] * 7.0 = 0.70 * 7.0 = 4.90
      // Total DPR = 5.05 + 4.90 = 9.95
      const rogue = DprCombatantProfile(
        id: 'rogue_math_test',
        name: 'Rogue',
        level: 3,
        abilityScore: 18,
        proficiencyBonus: 3,
        sneakAttackDiceCount: 2,
        sneakAttackDiceSides: 6,
        attacks: [
          DprAttackAction(
            id: 'shortbow',
            name: 'Shortbow',
            attackBonus: 7,
            diceCount: 1,
            diceSides: 6,
            damageBonus: 4,
            attacksPerRound: 1,
          ),
        ],
      );

      final pt = DprCalculatorEngine.calculateProfileDpr(rogue, 15);
      expect(pt.dpr, closeTo(9.95, 0.01));
    });

    test('Vex Mastery chains advantage to subsequent attack in multi-attack rounds', () {
      const dualWielderWithVex = DprCombatantProfile(
        id: 'vex_fighter',
        name: 'Vex Fighter',
        level: 5,
        abilityScore: 18,
        proficiencyBonus: 3,
        attacks: [
          DprAttackAction(
            id: 'rapier_vex',
            name: 'Rapier (Vex)',
            attackBonus: 7,
            diceCount: 1,
            diceSides: 8,
            damageBonus: 4,
            weaponMastery: WeaponMastery.vex,
            attacksPerRound: 2,
          ),
        ],
      );

      const dualWielderWithoutVex = DprCombatantProfile(
        id: 'normal_fighter',
        name: 'Normal Fighter',
        level: 5,
        abilityScore: 18,
        proficiencyBonus: 3,
        attacks: [
          DprAttackAction(
            id: 'rapier_normal',
            name: 'Rapier (Normal)',
            attackBonus: 7,
            diceCount: 1,
            diceSides: 8,
            damageBonus: 4,
            weaponMastery: WeaponMastery.none,
            attacksPerRound: 2,
          ),
        ],
      );

      final vexPt = DprCalculatorEngine.calculateProfileDpr(dualWielderWithVex, 15);
      final normalPt = DprCalculatorEngine.calculateProfileDpr(dualWielderWithoutVex, 15);

      // Second attack with Vex gains Advantage -> total round DPR must be higher than without Vex
      expect(vexPt.dpr, greaterThan(normalPt.dpr));
    });

    test('Saving Throw AoE damage accurately calculates half-on-save and target multipliers', () {
      // Fireball spell: 8d6 fire (28 avg damage), DC 15 Dex save for half
      // Against target with +2 Dex save: target needs 13+ to pass (40% pass, 60% fail)
      // Per target damage = (28 * 0.60) + ((28 * 0.5) * 0.40) = 16.8 + 5.6 = 22.4 damage
      // Against 2 targets = 22.4 * 2 = 44.8 DPR
      const fireball = DprAttackAction(
        id: 'fireball_spell',
        name: 'Fireball',
        attackBonus: 0,
        diceCount: 8,
        diceSides: 6,
        damageBonus: 0,
        damageType: 'fire',
        deliveryType: DprActionDeliveryType.savingThrow,
        saveDc: 15,
        saveAbility: 'dex',
        halfDamageOnSave: true,
        isAoe: true,
        targetCount: 2,
      );

      final pt = DprCalculatorEngine.calculateSingleAttackDpr(
        fireball,
        15,
        AdvantageType.normal,
        targetSaveBonusOverride: 2,
      );

      expect(pt.dpr, closeTo(44.8, 0.05));
      expect(pt.hitChance, closeTo(0.60, 0.01)); // 60% fail rate
      expect(pt.expectedDamageOnHit, closeTo(28.0, 0.01));
      expect(pt.expectedDamageOnMiss, closeTo(14.0, 0.01)); // half on successful save
    });

    test('Save-or-suck (no half damage) deals 0 damage on successful save', () {
      // Cantrip: Sacred Flame / Toll the Dead (1d8 radiant, DC 15 Dex, no half damage on save)
      // Fail chance = 0.60 vs +2 save (needs 13+ to pass). Damage on fail = 4.5.
      // Expected DPR = 4.5 * 0.60 = 2.70.
      const sacredFlame = DprAttackAction(
        id: 'sacred_flame',
        name: 'Sacred Flame',
        attackBonus: 0,
        diceCount: 1,
        diceSides: 8,
        damageBonus: 0,
        damageType: 'radiant',
        deliveryType: DprActionDeliveryType.savingThrow,
        saveDc: 15,
        halfDamageOnSave: false,
        isAoe: false,
        targetCount: 1,
      );

      final pt = DprCalculatorEngine.calculateSingleAttackDpr(
        sacredFlame,
        15,
        AdvantageType.normal,
        targetSaveBonusOverride: 2,
      );

      expect(pt.dpr, closeTo(2.70, 0.01));
      expect(pt.expectedDamageOnMiss, equals(0.0));
    });

    test('DprMonsterAcPreset contains all standard CR benchmarks', () {
      expect(DprMonsterAcPreset.standardPresets.length, greaterThanOrEqualTo(8));
      final cr5 = DprMonsterAcPreset.standardPresets.firstWhere((p) => p.crDisplay == '5');
      expect(cr5.typicalAc, equals(15));
      expect(cr5.examples, contains('Troll'));

      final cr30 = DprMonsterAcPreset.standardPresets.firstWhere((p) => p.crDisplay == '30');
      expect(cr30.typicalAc, equals(25));
      expect(cr30.examples, contains('Tarrasque'));
    });

    test('generateCurveAsync runs in background isolate and returns valid points', () async {
      const profile = DprCombatantProfile(
        id: 'hero_test',
        name: 'Hero',
        level: 5,
        abilityScore: 18,
        proficiencyBonus: 3,
        attacks: [
          DprAttackAction(
            id: 'longsword',
            name: 'Longsword',
            attackBonus: 7,
            diceCount: 1,
            diceSides: 8,
            damageBonus: 4,
            damageType: 'slashing',
          ),
        ],
      );

      final curve = await DprCalculatorEngine.generateCurveAsync(profile, minAc: 10, maxAc: 20);
      expect(curve.points.length, 11);
      expect(curve.pointAt(10)?.dpr, greaterThan(curve.pointAt(20)?.dpr ?? 0));
    });

    test('calculateGwmBreakEvenAsync runs in background isolate', () async {
      const profile = DprCombatantProfile(
        id: 'gwm_hero',
        name: 'GWM Hero',
        level: 5,
        abilityScore: 18,
        proficiencyBonus: 3,
        attacks: [
          DprAttackAction(
            id: 'greatsword',
            name: 'Greatsword',
            attackBonus: 7,
            diceCount: 2,
            diceSides: 6,
            damageBonus: 4,
            damageType: 'slashing',
          ),
        ],
      );

      final result = await DprCalculatorEngine.calculateGwmBreakEvenAsync(profile, minAc: 10, maxAc: 20);
      expect(result.baselineCurve.points.length, 11);
      expect(result.powerAttackCurve.points.length, 11);
    });
  });
}


