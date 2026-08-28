import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/dpr/dpr_models.dart';

/// Pure 5e probabilistic mathematical calculation engine for DPR, Accuracy, and Break-Even Analysis.
class DprCalculatorEngine {
  DprCalculatorEngine._();

  /// Computes the expected value of a single die considering Great Weapon Fighting style rules.
  static double expectedDieValue(int sides, {GwfVersion gwf = GwfVersion.none}) {
    if (sides <= 0) return 0.0;
    final s = sides.toDouble();

    switch (gwf) {
      case GwfVersion.none:
        return (s + 1.0) / 2.0;

      case GwfVersion.v2014Reroll:
        // Formula: (sides + 3)/2 - 2/sides
        // For d6: (9/2) - (2/6) = 4.5 - 0.3333 = 4.1667 (2d6 = 8.3333)
        // For d8: (11/2) - (2/8) = 5.5 - 0.25 = 5.25
        // For d10: (13/2) - (2/10) = 6.5 - 0.20 = 6.30
        // For d12: (15/2) - (2/12) = 7.5 - 0.1667 = 7.3333
        return ((s + 3.0) / 2.0) - (2.0 / s);

      case GwfVersion.v2024Floor3:
        // Rolls of 1 and 2 are treated as 3.
        // Sum = 3 + 3 + (3 + 4 + ... + sides) = 6 + (sides^2 + sides - 6)/2 = (sides^2 + sides + 6)/2
        // Average = (sides + 1)/2 + 3/sides
        // For d6: 3.5 + 3/6 = 4.0 (2d6 = 8.0)
        // For d8: 4.5 + 3/8 = 4.875
        // For d10: 5.5 + 3/10 = 5.8
        // For d12: 6.5 + 3/12 = 6.75
        return ((s + 1.0) / 2.0) + (3.0 / s);
    }
  }

  /// Calculates the effective attack bonus including flat buffs and expected buff dice (like Bless).
  static double calculateEffectiveAttackBonus(DprAttackAction attack) {
    var bonus = attack.attackBonus.toDouble() + attack.attackBuffFlat.toDouble();
    if (attack.hasArchery) bonus += 2.0;
    if (attack.gwmMode == GwmMode.v2014PowerAttack) bonus -= 5.0;
    if (attack.attackBuffDiceSides > 0) {
      bonus += (attack.attackBuffDiceSides + 1.0) / 2.0; // e.g. +2.5 for Bless (1d4)
    }
    return bonus;
  }

  /// Calculates hit probability given effective attack bonus, target AC, and advantage state.
  static double calculateHitProbability(
    double effectiveAttackBonus,
    int targetAc,
    AdvantageType advantage, {
    bool hasHalflingLuck = false,
  }) {
    // 5e standard rule: Natural 1 always misses, Natural 20 always hits.
    // Minimum roll required on d20:
    final neededRoll = (targetAc - effectiveAttackBonus).ceil().clamp(2, 20);
    var baseSingleHitP = (21.0 - neededRoll) / 20.0;
    if (hasHalflingLuck) {
      // Halfling Luck: on rolling 1 (5% chance), reroll once with standard hit probability
      baseSingleHitP += 0.05 * baseSingleHitP;
    }
    final clampedBase = baseSingleHitP.clamp(0.05, 0.9975);

    switch (advantage) {
      case AdvantageType.normal:
        return clampedBase;
      case AdvantageType.advantage:
        return 1.0 - math.pow(1.0 - clampedBase, 2).toDouble();
      case AdvantageType.disadvantage:
        return math.pow(clampedBase, 2).toDouble();
      case AdvantageType.elvenAccuracy:
        return 1.0 - math.pow(1.0 - clampedBase, 3).toDouble();
    }
  }

  /// Calculates critical hit probability.
  static double calculateCritProbability(
    AdvantageType advantage, {
    int critThreshold = 20,
    bool hasHalflingLuck = false,
  }) {
    final clampedThreshold = critThreshold.clamp(1, 20);
    var baseCritP = (21.0 - clampedThreshold) / 20.0;
    if (hasHalflingLuck) {
      // Halfling Luck: on rolling 1 (5% chance), reroll once with standard crit probability
      baseCritP += 0.05 * baseCritP;
    }

    switch (advantage) {
      case AdvantageType.normal:
        return baseCritP;
      case AdvantageType.advantage:
        return 1.0 - math.pow(1.0 - baseCritP, 2).toDouble();
      case AdvantageType.disadvantage:
        return math.pow(baseCritP, 2).toDouble();
      case AdvantageType.elvenAccuracy:
        return 1.0 - math.pow(1.0 - baseCritP, 3).toDouble();
    }
  }

  /// Calculates saving throw failure probability for spells (Save-for-Half or Save-for-None).
  static double calculateSaveFailureProbability({
    required int saveDc,
    required int targetSaveBonus,
    bool targetHasAdvantage = false,
    bool targetHasDisadvantage = false,
  }) {
    // 5e standard saving throw rule: Target succeeds if d20 + saveBonus >= saveDc
    final neededRoll = (saveDc - targetSaveBonus).clamp(1, 20);
    final singlePassProb = ((21.0 - neededRoll) / 20.0).clamp(0.05, 0.95);

    double totalPassProb;
    if (targetHasAdvantage) {
      totalPassProb = 1.0 - math.pow(1.0 - singlePassProb, 2).toDouble();
    } else if (targetHasDisadvantage) {
      totalPassProb = math.pow(singlePassProb, 2).toDouble();
    } else {
      totalPassProb = singlePassProb;
    }

    return 1.0 - totalPassProb;
  }

  /// Calculates single attack expected DPR against target AC.
  static DprPoint calculateSingleAttackDpr(
    DprAttackAction attack,
    int targetAc,
    AdvantageType advantage, {
    int proficiencyBonus = 2,
    bool hasHalflingLuck = false,
    int? targetSaveBonusOverride,
  }) {
    // Utility / non-damaging actions
    if (attack.deliveryType == DprActionDeliveryType.utility ||
        (attack.diceCount == 0 &&
            attack.secondaryDiceCount == 0 &&
            attack.damageBonus == 0 &&
            attack.secondaryDamageBonus == 0 &&
            !attack.hasDueling &&
            !attack.hasThrownWeapon &&
            attack.gwmMode == GwmMode.none)) {
      return DprPoint(
        ac: targetAc,
        dpr: 0.0,
        hitChance: 0.0,
        critChance: 0.0,
        expectedDamageOnHit: 0.0,
        expectedDamageOnCrit: 0.0,
        expectedDamageOnMiss: 0.0,
      );
    }

    // Saving throw actions (Spells, Dragon Breaths, Save Cantrips)
    if (attack.deliveryType == DprActionDeliveryType.savingThrow) {
      final saveDc = attack.saveDc ?? (8 + proficiencyBonus + math.max(0, attack.damageBonus));
      final targetSaveBonus = targetSaveBonusOverride ?? ((targetAc - 13).clamp(-2, 12));

      final targetHasAdv = advantage == AdvantageType.disadvantage;
      final targetHasDisadv = advantage == AdvantageType.advantage || advantage == AdvantageType.elvenAccuracy;

      final failChance = calculateSaveFailureProbability(
        saveDc: saveDc,
        targetSaveBonus: targetSaveBonus,
        targetHasAdvantage: targetHasAdv,
        targetHasDisadvantage: targetHasDisadv,
      );
      final passChance = 1.0 - failChance;

      final primaryDieEv = expectedDieValue(attack.diceSides, gwf: attack.gwfVersion);
      final secDieEv = expectedDieValue(attack.secondaryDiceSides);
      final fullDamage = (attack.diceCount * primaryDieEv) +
          attack.damageBonus +
          (attack.secondaryDiceCount * secDieEv) +
          attack.secondaryDamageBonus;

      final damagePerTarget = attack.halfDamageOnSave
          ? (fullDamage * failChance) + ((fullDamage * 0.5) * passChance)
          : (fullDamage * failChance);

      final targets = attack.isAoe ? math.max(1, attack.targetCount) : 1;
      final totalDpr = damagePerTarget * targets * attack.attacksPerRound;

      return DprPoint(
        ac: targetAc,
        dpr: totalDpr,
        hitChance: failChance, // Probability target fails save
        critChance: 0.0,
        expectedDamageOnHit: fullDamage,
        expectedDamageOnCrit: fullDamage,
        expectedDamageOnMiss: attack.halfDamageOnSave ? (fullDamage * 0.5) : 0.0,
      );
    }

    // Standard attack roll actions (to-hit vs target AC)
    final effBonus = calculateEffectiveAttackBonus(attack);
    final luck = hasHalflingLuck || attack.hasHalflingLuck;
    final totalHitChance = calculateHitProbability(effBonus, targetAc, advantage, hasHalflingLuck: luck);
    final critChance = calculateCritProbability(advantage, critThreshold: attack.critThreshold, hasHalflingLuck: luck);

    // Regular hit chance is total hit chance minus critical hit chance (clamped to 0)
    final regularHitChance = math.max(0.0, totalHitChance - critChance);
    final missChance = math.max(0.0, 1.0 - totalHitChance);

    // Expected primary damage per die
    final primaryDieEv = expectedDieValue(attack.diceSides, gwf: attack.gwfVersion);
    final secDieEv = expectedDieValue(attack.secondaryDiceSides);

    // Flat damage modifiers
    var flatDamage = attack.damageBonus;
    if (attack.hasDueling) flatDamage += 2;
    if (attack.hasThrownWeapon) flatDamage += 2;
    if (attack.hasAgonizingBlast && attack.abilityModForAgonizing > 0) {
      flatDamage += attack.abilityModForAgonizing;
    }
    if (attack.gwmMode == GwmMode.v2014PowerAttack) flatDamage += 10;
    if (attack.gwmMode == GwmMode.v2024ProficiencyBonus) flatDamage += proficiencyBonus;
    if (attack.isOffhandWithoutTwf) {
      // Offhand without TWF removes ability modifier from damage
      flatDamage = math.max(0, flatDamage - attack.damageBonus);
    }

    final regularHitDamage = (attack.diceCount * primaryDieEv) +
        flatDamage +
        (attack.secondaryDiceCount * secDieEv) +
        attack.secondaryDamageBonus;

    // Critical hit damage: double base dice + double secondary dice + extra crit dice + flat bonus
    var extraCritDieEv = 0.0;
    if (attack.extraCritDiceCount > 0) {
      final extraSides = attack.extraCritDiceSides > 0 ? attack.extraCritDiceSides : attack.diceSides;
      extraCritDieEv = attack.extraCritDiceCount * expectedDieValue(extraSides, gwf: attack.gwfVersion);
    }

    final critDamage = (attack.diceCount * 2 * primaryDieEv) +
        extraCritDieEv +
        flatDamage +
        (attack.secondaryDiceCount * 2 * secDieEv) +
        attack.secondaryDamageBonus;

    // Miss damage (e.g. Graze 2024 mastery)
    var missDamage = 0.0;
    if (attack.weaponMastery == WeaponMastery.graze) {
      missDamage = math.max(0, attack.abilityModForGraze).toDouble();
    }

    final targetMult = attack.isAoe ? math.max(1, attack.targetCount) : 1;
    final dpr = ((regularHitChance * regularHitDamage) +
            (critChance * critDamage) +
            (missChance * missDamage)) *
        targetMult;

    return DprPoint(
      ac: targetAc,
      dpr: dpr * attack.attacksPerRound,
      hitChance: totalHitChance,
      critChance: critChance,
      expectedDamageOnHit: regularHitDamage,
      expectedDamageOnCrit: critDamage,
      expectedDamageOnMiss: missDamage,
    );
  }

  /// Calculates total round DPR for a complete combatant profile against target AC.
  static DprPoint calculateProfileDpr(
    DprCombatantProfile profile,
    int targetAc, {
    AdvantageType? advantageOverride,
  }) {
    final baseAdv = advantageOverride ?? profile.defaultAdvantage;
    double totalDpr = 0.0;
    double primaryHitChance = 0.0;
    double primaryCritChance = 0.0;
    double primaryDamageOnHit = 0.0;
    double primaryDamageOnCrit = 0.0;
    double primaryDamageOnMiss = 0.0;

    final hitChances = <double>[];
    final critChances = <double>[];

    AdvantageType currentAdv = baseAdv;

    for (int i = 0; i < profile.attacks.length; i++) {
      final attack = profile.attacks[i];

      for (int count = 0; count < attack.attacksPerRound; count++) {
        final pt = calculateSingleAttackDpr(
          attack.copyWith(attacksPerRound: 1),
          targetAc,
          currentAdv,
          proficiencyBonus: profile.proficiencyBonus,
          hasHalflingLuck: profile.hasHalflingLuck,
        );

        totalDpr += pt.dpr;
        hitChances.add(pt.hitChance);
        critChances.add(pt.critChance);

        if (i == 0 && count == 0) {
          primaryHitChance = pt.hitChance;
          primaryCritChance = pt.critChance;
          primaryDamageOnHit = pt.expectedDamageOnHit;
          primaryDamageOnCrit = pt.expectedDamageOnCrit;
          primaryDamageOnMiss = pt.expectedDamageOnMiss;
        }

        // 2024 Vex Mastery: Hitting grants Advantage on the subsequent attack
        if (attack.weaponMastery == WeaponMastery.vex && baseAdv == AdvantageType.normal) {
          currentAdv = AdvantageType.advantage;
        }
      }
    }

    // Rogue Sneak Attack: Calculated accurately across all attacks in the turn with Crits
    if (profile.sneakAttackDiceCount > 0 && hitChances.isNotEmpty) {
      final probMissAll = hitChances.fold<double>(1.0, (acc, p) => acc * (1.0 - p));
      final probAtLeastOneHit = 1.0 - probMissAll;

      final probNoCrit = critChances.fold<double>(1.0, (acc, c) => acc * (1.0 - c));
      final probAtLeastOneCrit = 1.0 - probNoCrit;

      final sneakDieEv = expectedDieValue(profile.sneakAttackDiceSides);
      final singleSneakDamage = profile.sneakAttackDiceCount * sneakDieEv;

      // EV = [P(>=1 Hit) + P(>=1 Crit)] * SneakDamage
      final sneakDpr = (probAtLeastOneHit + probAtLeastOneCrit) * singleSneakDamage;
      totalDpr += sneakDpr;
    }

    return DprPoint(
      ac: targetAc,
      dpr: totalDpr,
      hitChance: primaryHitChance,
      critChance: primaryCritChance,
      expectedDamageOnHit: primaryDamageOnHit,
      expectedDamageOnCrit: primaryDamageOnCrit,
      expectedDamageOnMiss: primaryDamageOnMiss,
    );
  }

  /// Generates the complete DPR curve across an AC range (e.g. AC 5 to 30).
  static DprCurveData generateCurve(
    DprCombatantProfile profile, {
    AdvantageType? advantageOverride,
    int minAc = 5,
    int maxAc = 30,
  }) {
    final adv = advantageOverride ?? profile.defaultAdvantage;
    final points = <int, DprPoint>{};

    for (int ac = minAc; ac <= maxAc; ac++) {
      points[ac] = calculateProfileDpr(profile, ac, advantageOverride: adv);
    }

    return DprCurveData(
      profile: profile,
      advantage: adv,
      points: points,
    );
  }

  /// Performs full Break-Even Analysis comparing baseline attacks vs Power Attack (GWM / Sharpshooter).
  static DprBreakEvenAnalysis calculateGwmBreakEven(
    DprCombatantProfile baselineProfile, {
    AdvantageType? advantage,
    int minAc = 5,
    int maxAc = 30,
  }) {
    final adv = advantage ?? baselineProfile.defaultAdvantage;

    // Create power attack profile copy with GWM 2014 (-5/+10) applied to all attacks
    final powerAttacks = baselineProfile.attacks.map((a) {
      return a.copyWith(gwmMode: GwmMode.v2014PowerAttack);
    }).toList();

    final powerProfile = baselineProfile.copyWith(
      id: '${baselineProfile.id}_gwm',
      name: '${baselineProfile.name} (GWM/SS Active)',
      attacks: powerAttacks,
    );

    final baselineCurve = generateCurve(baselineProfile, advantageOverride: adv, minAc: minAc, maxAc: maxAc);
    final powerCurve = generateCurve(powerProfile, advantageOverride: adv, minAc: minAc, maxAc: maxAc);

    int? maxOptimalAc;
    bool hadGwmAdvantage = false;

    for (int ac = minAc; ac <= maxAc; ac++) {
      final baseDpr = baselineCurve.pointAt(ac)?.dpr ?? 0;
      final gwmDpr = powerCurve.pointAt(ac)?.dpr ?? 0;

      if (gwmDpr >= baseDpr) {
        if (!hadGwmAdvantage || maxOptimalAc == ac - 1) {
          maxOptimalAc = ac;
          hadGwmAdvantage = true;
        }
      } else {
        if (hadGwmAdvantage) {
          // First time GWM falls below baseline - this establishes the standard break-even threshold
          break;
        }
      }
    }

    String rec;
    if (maxOptimalAc == null) {
      rec = 'Great Weapon Master / Sharpshooter is suboptimal across all evaluated ACs for this build.';
    } else if (maxOptimalAc >= maxAc) {
      rec = 'Great Weapon Master / Sharpshooter is optimal against ALL target ACs (up to AC $maxAc)!';
    } else {
      rec = 'Use GWM / Sharpshooter against target AC $maxOptimalAc or lower. Switch to Normal attacks against AC ${maxOptimalAc + 1}+.';
    }

    return DprBreakEvenAnalysis(
      baselineProfile: baselineProfile,
      powerAttackProfile: powerProfile,
      baselineCurve: baselineCurve,
      powerAttackCurve: powerCurve,
      maxOptimalAcForGwm: maxOptimalAc,
      recommendation: rec,
    );
  }

  // --- Isolate Runners & Async Interfaces ---

  static DprCurveData _isolateCurveRunner(_DprCurvePayload payload) {
    return generateCurve(
      payload.profile,
      advantageOverride: payload.advantageOverride,
      minAc: payload.minAc,
      maxAc: payload.maxAc,
    );
  }

  static DprBreakEvenAnalysis _isolateBreakEvenRunner(_DprBreakEvenPayload payload) {
    return calculateGwmBreakEven(
      payload.profile,
      advantage: payload.advantage,
      minAc: payload.minAc,
      maxAc: payload.maxAc,
    );
  }

  /// Offloads DPR curve computation across ACs to a background isolate.
  static Future<DprCurveData> generateCurveAsync(
    DprCombatantProfile profile, {
    AdvantageType? advantageOverride,
    int minAc = 5,
    int maxAc = 30,
  }) {
    final payload = _DprCurvePayload(
      profile: profile,
      advantageOverride: advantageOverride,
      minAc: minAc,
      maxAc: maxAc,
    );
    return compute(_isolateCurveRunner, payload);
  }

  /// Offloads Great Weapon Master break-even analysis to a background isolate.
  static Future<DprBreakEvenAnalysis> calculateGwmBreakEvenAsync(
    DprCombatantProfile baselineProfile, {
    AdvantageType? advantage,
    int minAc = 5,
    int maxAc = 30,
  }) {
    final payload = _DprBreakEvenPayload(
      profile: baselineProfile,
      advantage: advantage,
      minAc: minAc,
      maxAc: maxAc,
    );
    return compute(_isolateBreakEvenRunner, payload);
  }
}

class _DprCurvePayload {
  final DprCombatantProfile profile;
  final AdvantageType? advantageOverride;
  final int minAc;
  final int maxAc;

  const _DprCurvePayload({
    required this.profile,
    this.advantageOverride,
    required this.minAc,
    required this.maxAc,
  });
}

class _DprBreakEvenPayload {
  final DprCombatantProfile profile;
  final AdvantageType? advantage;
  final int minAc;
  final int maxAc;

  const _DprBreakEvenPayload({
    required this.profile,
    this.advantage,
    required this.minAc,
    required this.maxAc,
  });
}

