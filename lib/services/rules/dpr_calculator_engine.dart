import 'dart:math' as math;
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

  /// Calculates hit probability (including crits) against target AC for given advantage state.
  static double calculateHitProbability(
    double effectiveAttackBonus,
    int targetAc,
    AdvantageType advantage,
  ) {
    // 5e standard rule: Natural 1 always misses, Natural 20 always hits.
    // Minimum roll required on d20:
    final neededRoll = (targetAc - effectiveAttackBonus).ceil().clamp(2, 20);
    final baseSingleHitP = (21.0 - neededRoll) / 20.0;
    final clampedBase = baseSingleHitP.clamp(0.05, 0.95);

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
  }) {
    final clampedThreshold = critThreshold.clamp(1, 20);
    final baseCritP = (21.0 - clampedThreshold) / 20.0;

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

  /// Calculates single attack expected DPR against target AC.
  static DprPoint calculateSingleAttackDpr(
    DprAttackAction attack,
    int targetAc,
    AdvantageType advantage, {
    int proficiencyBonus = 2,
  }) {
    final effBonus = calculateEffectiveAttackBonus(attack);
    final totalHitChance = calculateHitProbability(effBonus, targetAc, advantage);
    final critChance = calculateCritProbability(advantage, critThreshold: attack.critThreshold);

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

    final dpr = (regularHitChance * regularHitDamage) +
        (critChance * critDamage) +
        (missChance * missDamage);

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
    final adv = advantageOverride ?? profile.defaultAdvantage;
    double totalDpr = 0.0;
    double primaryHitChance = 0.0;
    double primaryCritChance = 0.0;
    double primaryDamageOnHit = 0.0;
    double primaryDamageOnCrit = 0.0;
    double primaryDamageOnMiss = 0.0;

    final hitChances = <double>[];

    for (int i = 0; i < profile.attacks.length; i++) {
      final attack = profile.attacks[i];
      final pt = calculateSingleAttackDpr(
        attack,
        targetAc,
        adv,
        proficiencyBonus: profile.proficiencyBonus,
      );

      totalDpr += pt.dpr;

      // Track hit chances for once-per-turn procs (Sneak Attack)
      for (int count = 0; count < attack.attacksPerRound; count++) {
        hitChances.add(pt.hitChance);
      }

      if (i == 0) {
        primaryHitChance = pt.hitChance;
        primaryCritChance = pt.critChance;
        primaryDamageOnHit = pt.expectedDamageOnHit;
        primaryDamageOnCrit = pt.expectedDamageOnCrit;
        primaryDamageOnMiss = pt.expectedDamageOnMiss;
      }
    }

    // Process once-per-turn damage procs like Rogue Sneak Attack
    if (profile.sneakAttackDiceCount > 0 && hitChances.isNotEmpty) {
      // Probability of landing AT LEAST ONE hit in the turn
      final probMissAll = hitChances.fold<double>(1.0, (acc, p) => acc * (1.0 - p));
      final probAtLeastOneHit = 1.0 - probMissAll;

      final sneakDieEv = expectedDieValue(profile.sneakAttackDiceSides);
      final sneakDamage = profile.sneakAttackDiceCount * sneakDieEv;

      totalDpr += probAtLeastOneHit * sneakDamage;
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

  /// Curated list of popular archetypal 5e player build presets.
  static List<DprCombatantProfile> get defaultPresets => const [
        // 1. Level 5 Greatsword Barbarian (Reckless + GWM)
        DprCombatantProfile(
          id: 'barbarian_gwm',
          name: 'Level 5 Barbarian (Greatsword + Reckless)',
          description: '2d6+4 Slashing, 2 attacks, +2 Rage damage, GWF style, Reckless Advantage.',
          level: 5,
          abilityScore: 18, // +4 STR
          proficiencyBonus: 3,
          defaultAdvantage: AdvantageType.advantage,
          attacks: [
            DprAttackAction(
              id: 'barb_greatsword',
              name: 'Greatsword',
              attackBonus: 7, // +4 STR + 3 PB
              diceCount: 2,
              diceSides: 6,
              damageBonus: 6, // +4 STR + 2 Rage
              damageType: 'slashing',
              gwfVersion: GwfVersion.v2014Reroll,
              attacksPerRound: 2,
              weaponMastery: WeaponMastery.graze,
              abilityModForGraze: 4,
            ),
          ],
        ),

        // 2. Level 5 Crossbow Expert / Sharpshooter Fighter (Archery)
        DprCombatantProfile(
          id: 'fighter_cbe_ss',
          name: 'Level 5 Fighter (Crossbow Expert + Sharpshooter)',
          description: '1d6+4 Piercing, 2 main attacks + 1 bonus action hand crossbow attack, Archery +2.',
          level: 5,
          abilityScore: 18, // +4 DEX
          proficiencyBonus: 3,
          defaultAdvantage: AdvantageType.normal,
          attacks: [
            DprAttackAction(
              id: 'fighter_hand_crossbow',
              name: 'Hand Crossbow (Action + BA)',
              attackBonus: 7, // +4 DEX + 3 PB (+2 from Archery applied)
              diceCount: 1,
              diceSides: 6,
              damageBonus: 4,
              damageType: 'piercing',
              hasArchery: true,
              attacksPerRound: 3, // 2 Extra Attacks + 1 CBE Bonus Action
              weaponMastery: WeaponMastery.vex,
            ),
          ],
        ),

        // 3. Level 5 Paladin (Longsword + Dueling + Smite)
        DprCombatantProfile(
          id: 'paladin_smite',
          name: 'Level 5 Paladin (Longsword + Dueling + Smite)',
          description: '1d8+4 Slashing + 2 Dueling + 2d8 Radiant Smite, 2 attacks.',
          level: 5,
          abilityScore: 18,
          proficiencyBonus: 3,
          defaultAdvantage: AdvantageType.normal,
          attacks: [
            DprAttackAction(
              id: 'paladin_longsword',
              name: 'Longsword + Smite',
              attackBonus: 7,
              diceCount: 1,
              diceSides: 8,
              damageBonus: 4,
              damageType: 'slashing',
              hasDueling: true, // +2 damage
              secondaryDiceCount: 2, // 2d8 Level 1 Smite
              secondaryDiceSides: 8,
              secondaryDamageType: 'radiant',
              attacksPerRound: 2,
            ),
          ],
        ),

        // 4. Level 5 Rogue (Sneak Attack + Shortbow + Advantage)
        DprCombatantProfile(
          id: 'rogue_sneak_attack',
          name: 'Level 5 Rogue (Shortbow Sneak Attack)',
          description: '1d6+4 Piercing Shortbow + 3d6 Sneak Attack (once per turn proc).',
          level: 5,
          abilityScore: 18,
          proficiencyBonus: 3,
          defaultAdvantage: AdvantageType.advantage,
          sneakAttackDiceCount: 3, // 3d6 Sneak Attack at Level 5
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
        ),

        // 5. Level 5 Ranger (Dual Wielder + Hunter\'s Mark)
        DprCombatantProfile(
          id: 'ranger_dual_wield',
          name: 'Level 5 Ranger (Dual Shortswords + Hunter\'s Mark)',
          description: '1d6+4 Piercing + 1d6 Hunter\'s Mark, 2 main attacks + 1 Nick off-hand attack.',
          level: 5,
          abilityScore: 18,
          proficiencyBonus: 3,
          defaultAdvantage: AdvantageType.normal,
          attacks: [
            DprAttackAction(
              id: 'ranger_shortswords',
              name: 'Shortswords (Two-Weapon)',
              attackBonus: 7,
              diceCount: 1,
              diceSides: 6,
              damageBonus: 4,
              damageType: 'piercing',
              secondaryDiceCount: 1,
              secondaryDiceSides: 6,
              secondaryDamageType: 'force', // Hunter's Mark 1d6
              attacksPerRound: 3, // 2 Extra attacks + 1 TWF/Nick
              weaponMastery: WeaponMastery.nick,
            ),
          ],
        ),

        // 6. Level 5 Monk (Quarterstaff + Flurry of Blows)
        DprCombatantProfile(
          id: 'monk_flurry',
          name: 'Level 5 Monk (Quarterstaff + Flurry of Blows)',
          description: '2x 1d8+4 2H Quarterstaff + 2x 1d6+4 Unarmed Strikes (Flurry of Blows).',
          level: 5,
          abilityScore: 18,
          proficiencyBonus: 3,
          defaultAdvantage: AdvantageType.normal,
          attacks: [
            DprAttackAction(
              id: 'monk_staff',
              name: '2H Quarterstaff',
              attackBonus: 7,
              diceCount: 1,
              diceSides: 8,
              damageBonus: 4,
              damageType: 'bludgeoning',
              attacksPerRound: 2,
            ),
            DprAttackAction(
              id: 'monk_unarmed',
              name: 'Flurry of Blows',
              attackBonus: 7,
              diceCount: 1,
              diceSides: 6,
              damageBonus: 4,
              damageType: 'bludgeoning',
              attacksPerRound: 2,
              isBonusActionAttack: true,
            ),
          ],
        ),
      ];
}
