import 'dart:math';

import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import 'package:vtt_engine_core/simulation/precomputed_attack.dart';
import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/dpr/dpr_models.dart';
import '../aoe_resolver.dart';
import 'arena_combat_context.dart';

/// Resolves weapon/natural attack selection, single-target attacks, and monster AoE attacks.
class ArenaAttackResolver {
  final ArenaCombatContext ctx;

  const ArenaAttackResolver(this.ctx);

  List<DprAttackAction> selectAttacksForTurn(
    ArenaCombatant attacker,
    List<DprAttackAction> allAttacks,
    MonsterStatBlock sb, {
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) {
    if (allAttacks.isEmpty) {
      // Fallback to basic stat block attacks if DPR extraction was empty
      return [
        DprAttackAction(
          id: 'basic_attack',
          name: 'Strike',
          attackBonus: sb.attackBonus,
          diceCount: sb.damageDiceCount > 0 ? sb.damageDiceCount : 1,
          diceSides: sb.damageDiceSides > 0 ? sb.damageDiceSides : 6,
          damageBonus: sb.damageBonus,
          damageType: sb.damageType,
          attacksPerRound: 1,
        ),
      ];
    }

    // Cage Match Environmental Filter:
    // In an enclosed 10-ft Iron Cage Match, combatants are locked in point-blank melee.
    // If the monster has melee weapon options (e.g. Scimitar vs Shortbow), prioritize melee attacks.
    var candidateAttacks = allAttacks;
    if (environment == ArenaEnvironment.cageMatch) {
      final meleeOptions = allAttacks
          .where((a) =>
              a.attackType == AttackType.meleeStandard ||
              a.attackType == AttackType.meleeReach ||
              (a.attackType != AttackType.rangedWeapon &&
                  a.attackType != AttackType.rangedSpell))
          .toList();
      if (meleeOptions.isNotEmpty) {
        candidateAttacks = meleeOptions;
      }
    }

    // Check if recharge attack is ready and available
    final rechargeAttack =
        candidateAttacks.where((a) => a.rechargeRoll != null).firstOrNull;
    if (rechargeAttack != null && attacker.isRechargeReady) {
      attacker.isRechargeReady = false;
      return [rechargeAttack];
    }

    // Standard turn attacks (excluding legendary action standalone triggers and recharge attacks)
    // Only select attacks that are part of the monster's active multiattack routine (attacksPerRound > 0)
    final activeAttacks = candidateAttacks
        .where((a) =>
            !a.isLegendaryAction &&
            a.rechargeRoll == null &&
            a.attacksPerRound > 0)
        .toList();

    if (activeAttacks.isNotEmpty) {
      final result = <DprAttackAction>[];
      for (final atk in activeAttacks) {
        for (int i = 0; i < atk.attacksPerRound; i++) {
          result.add(atk.copyWith(attacksPerRound: 1));
        }
      }
      return result;
    }

    // Fallback: If no attack has attacksPerRound > 0, pick the single most efficient standard attack
    final standardAttacks = candidateAttacks
        .where((a) => !a.isLegendaryAction && a.rechargeRoll == null)
        .toList();
    if (standardAttacks.isNotEmpty) {
      standardAttacks.sort(
          (a, b) => _estimateAttackDpr(b).compareTo(_estimateAttackDpr(a)));
      return [standardAttacks.first.copyWith(attacksPerRound: 1)];
    }

    final sortedCandidates = List<DprAttackAction>.from(candidateAttacks);
    sortedCandidates
        .sort((a, b) => _estimateAttackDpr(b).compareTo(_estimateAttackDpr(a)));
    return sortedCandidates
        .take(1)
        .map((a) => a.copyWith(attacksPerRound: 1))
        .toList();
  }

  double _estimateAttackDpr(DprAttackAction a) {
    final primaryAvg = (a.diceCount * (a.diceSides + 1) / 2.0) + a.damageBonus;
    final secAvg = (a.secondaryDiceCount * (a.secondaryDiceSides + 1) / 2.0) +
        a.secondaryDamageBonus;
    final totalHitDmg = primaryAvg + secAvg;

    if (a.deliveryType == DprActionDeliveryType.savingThrow) {
      final dc = a.saveDc ?? 13;
      final failProb = ((dc - 2) / 20.0).clamp(0.05, 0.95);
      final successFactor = a.halfDamageOnSave ? 0.5 : 0.0;
      final aoeMultiplier = a.isAoe ? 2.0 : 1.0;
      return (totalHitDmg * (failProb + (1.0 - failProb) * successFactor)) *
          aoeMultiplier;
    } else {
      final neededRoll = (15 - a.attackBonus).clamp(2, 20);
      final hitProb = (21.0 - neededRoll) / 20.0;
      const critProb = 1.0 / 20.0;
      final critDmg = (a.diceCount * (a.diceSides + 1) / 2.0) +
          (a.secondaryDiceCount * (a.secondaryDiceSides + 1) / 2.0);
      return (totalHitDmg * hitProb) + (critDmg * critProb);
    }
  }

  /// Resolves an Area of Effect (AoE) attack hitting a dynamic number of opponents based on DMG p.249 Theater-of-the-Mind.
  List<ArenaAttackEvent> resolveAoeAttack({
    required ArenaCombatant attacker,
    required DprAttackAction attack,
    required List<ArenaCombatant> allCombatants,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) {
    final livingEnemies = allCombatants
        .where((c) => c.team != attacker.team && c.isAlive)
        .toList();

    if (livingEnemies.isEmpty) return const [];

    attacker.attacksMade++;

    // Parse AoE shape and dimensions and resolve targets via AoeResolver
    final sb = attacker.getStatBlock(edition);
    final matchingAction = sb.actions
        .where((a) => a.name.toLowerCase() == attack.name.toLowerCase())
        .firstOrNull;
    final parsedShape =
        AoeResolver.parseShapeAndSize(attack.name, matchingAction?.description);
    final caughtDefenders = AoeResolver.selectTargets(
      livingEnemies: livingEnemies,
      shape: parsedShape.shape,
      sizeInFeet: parsedShape.sizeInFeet,
      rng: ctx.rng,
      strategy: strategy,
    );

    // Roll base damage once for the AoE
    final rawDamage =
        ctx.rollDice(attack.diceCount, attack.diceSides) + attack.damageBonus;
    final saveAbility = attack.saveAbility ?? 'dex';
    final saveDc = attack.saveDc ?? ctx.computeDefaultSaveDc(attacker, edition);

    final events = <ArenaAttackEvent>[];

    for (final defender in caughtDefenders) {
      final saveBonus = defender.getSavingThrowBonus(saveAbility, edition);
      final d20 = ctx.rollDie(20);
      final totalSave = d20 + saveBonus;
      final saveRes = ctx.evaluateSaveWithLegendaryResistance(
          defender: defender, saveRoll: totalSave, saveDc: saveDc);
      final saved = saveRes.saved;

      final hasEvasion =
          defender.hasEvasion(edition) && saveAbility.toLowerCase() == 'dex';
      final saveDamage = computeSaveDamage(
        rawDamage: rawDamage,
        saved: saved,
        halfOnSuccess: true,
        hasEvasion: hasEvasion,
      );
      int effectiveDamage = saveDamage.damageTaken;

      // Apply resistances, immunities & environmental modifiers
      effectiveDamage = ctx.applyDefensiveModifiers(
          effectiveDamage, attack.damageType, defender, edition, environment);
      attacker.totalDamageDealt += effectiveDamage;
      defender.applyDamage(effectiveDamage);

      bool isKillShot = false;
      if (defender.isDefeated) {
        isKillShot = true;
        attacker.kills++;
        defender.applyCondition(ArenaCondition.unconscious, ctx.rollDie, edition);
      }

      final fatal = isKillShot ? ' — SLAIN!' : '';
      String summary = ArenaCombatContext.formatSaveDamageSummary(
          saveDamage.outcome, saved, hasEvasion, d20, saveBonus, totalSave,
          saveDc, saveRes.summaryNote, effectiveDamage, attack.damageType,
          fatal);

      // Concentration Check Pipeline for AoE attacks
      if (effectiveDamage > 0 && defender.activeConcentrationSpellId != null) {
        final conRes =
            defender.checkConcentration(effectiveDamage, ctx.rollDie, edition);
        if (conRes.broken) {
          final lostName = ctx.getSpellDisplayName(conRes.lostSpellId);
          summary +=
              ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      events.add(
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: defender.id,
          defenderName: defender.displayName,
          defenderTeam: defender.team,
          attackName: attack.name,
          d20Roll: d20,
          attackBonus: saveBonus,
          totalAttack: totalSave,
          targetAc: defender.effectiveAc,
          isHit: !saved || effectiveDamage > 0,
          isCrit: false,
          isFumble: false,
          isAoe: true,
          isSavingThrow: true,
          saveDc: saveDc,
          saveRoll: totalSave,
          saved: saved,
          evadedWithEvasion: saveDamage.outcome == SaveDamageOutcome.none && hasEvasion,
          damageDealt: effectiveDamage,
          damageType: attack.damageType,
          isKillShot: isKillShot,
          defenderRemainingHp: defender.currentHp,
          defenderMaxHp: defender.maxHp,
          summaryText: summary,
        ),
      );
    }

    if (events.any((e) => e.isHit)) attacker.hitsLanded++;

    return events;
  }


  ArenaAttackEvent resolveSingleAttack({
    required ArenaCombatant attacker,
    required ArenaCombatant defender,
    required DprAttackAction attack,
    required List<ArenaCombatant> allCombatants,
    required DmRulesEdition edition,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) {
    attacker.attacksMade++;

    // Check Pack Tactics
    final hasPackTactics = attacker.getStatBlock(edition).hasPackTactics;
    final otherAllyPresent = allCombatants.any(
      (c) => c.team == attacker.team && c.id != attacker.id && c.isAlive,
    );
    final packTacticsAdvantage = hasPackTactics && otherAllyPresent;

    // Environmental & Aerial mobility checks
    final flightEnabled = environment != ArenaEnvironment.cageMatch;
    final attackerFlies = flightEnabled && attacker.isAirborne;
    final defenderFlies = flightEnabled && defender.isAirborne;

    final isRangedAttack = attack.attackType == AttackType.rangedWeapon ||
        attack.attackType == AttackType.rangedSpell;

    bool flightAdvantage = false;
    bool flightDisadvantage = false;

    if (attackerFlies &&
        !defenderFlies &&
        (isRangedAttack || attacker.hasFlyby(edition))) {
      // Flying attacker strafing grounded enemy from safe range/flyby
      flightAdvantage = true;
    } else if (!attackerFlies && defenderFlies && !isRangedAttack) {
      // Grounded attacker attempting to strike a flying creature with standard melee
      flightDisadvantage = true;
    }

    // Flooded Abyss (Water Match), swimming speed rules
    bool aquaticAdvantage = false;
    bool aquaticDisadvantage = false;
    if (environment == ArenaEnvironment.floodedAbyss) {
      final attackerSwims = attacker.canSwim(edition);
      final defenderSwims = defender.canSwim(edition);

      if (attackerSwims && !defenderSwims) {
        aquaticAdvantage = true;
      } else if (!attackerSwims) {
        aquaticDisadvantage = true;
      }
    }

    // Condition advantages & disadvantages
    bool conditionAdvantage = false;
    bool conditionDisadvantage = false;

    // Cage Match (10-ft enclosed cage) close-quarters disadvantage for ranged attacks
    bool cageMatchDisadvantage = false;
    if (environment == ArenaEnvironment.cageMatch && isRangedAttack) {
      cageMatchDisadvantage = true;
    }

    if (defender.isParalyzed ||
        defender.isStunned ||
        defender.isUnconscious ||
        defender.hasCondition(ArenaCondition.restrained)) {
      conditionAdvantage = true;
    }

    if (defender.isProne) {
      if (attack.attackType == AttackType.meleeStandard ||
          attack.attackType == AttackType.meleeReach) {
        conditionAdvantage = true;
      } else {
        conditionDisadvantage = true;
      }
    }

    if (attacker.isProne ||
        attacker.hasCondition(ArenaCondition.restrained) ||
        attacker.hasCondition(ArenaCondition.blinded) ||
        attacker.hasCondition(ArenaCondition.poisoned)) {
      conditionDisadvantage = true;
    }

    final hasAdvantage = (packTacticsAdvantage ||
            flightAdvantage ||
            aquaticAdvantage ||
            conditionAdvantage) &&
        !flightDisadvantage &&
        !aquaticDisadvantage &&
        !conditionDisadvantage &&
        !cageMatchDisadvantage;
    final hasDisadvantage = (flightDisadvantage ||
            aquaticDisadvantage ||
            conditionDisadvantage ||
            cageMatchDisadvantage) &&
        !packTacticsAdvantage &&
        !flightAdvantage &&
        !aquaticAdvantage &&
        !conditionAdvantage;

    // Roll d20
    final d20A = ctx.rollDie(20);
    final d20B = (hasAdvantage || hasDisadvantage) ? ctx.rollDie(20) : null;
    int naturalRoll = d20A;
    if (hasAdvantage && d20B != null) naturalRoll = max(d20A, d20B);
    if (hasDisadvantage && d20B != null) naturalRoll = min(d20A, d20B);

    final totalAttack = naturalRoll + attack.attackBonus;
    final rollOutcome = classifyAttackRoll(
      naturalRoll: naturalRoll,
      totalToHit: totalAttack,
      targetAc: defender.effectiveAc,
    );
    final isFumble = rollOutcome == AttackOutcomeType.criticalMiss;
    bool isHit = rollOutcome == AttackOutcomeType.hit ||
        rollOutcome == AttackOutcomeType.criticalHit;
    final isCrit = (rollOutcome == AttackOutcomeType.criticalHit) ||
        (isHit &&
            (defender.isParalyzed || defender.isUnconscious) &&
            attack.attackType == AttackType.meleeStandard);

    int damageDealt = 0;
    bool isKillShot = false;
    bool shielded = false;
    List<String> appliedRiderLogs = const [];

    // Defensive Reaction Hook: Shield (spell_shield)
    if (isHit &&
        !defender.usedReactionThisRound &&
        defender.hasSpell('spell_shield') &&
        defender.hasAvailableSlots &&
        doesShieldBlockAttack(
          totalToHit: totalAttack,
          targetAc: defender.effectiveAc,
          isCriticalHit: isCrit,
        )) {
      ctx.deductLowestSlot(defender, 1);
      defender.usedReactionThisRound = true;
      defender.temporaryAcBonus += 5;
      shielded = true;
      isHit = false;
    }

    if (isHit) {
      attacker.hitsLanded++;
      if (isCrit) attacker.critsLanded++;

      // 1. Look up the precomputed attack:
      final actionId = attack.name.toLowerCase().trim();
      final profileAttacks = attacker.monster.getCombatProfile(edition).attacks;
      final precomputedAttack = profileAttacks[actionId] ??
          profileAttacks[attack.id.toLowerCase().trim()] ??
          profileAttacks.values
              .where(
                (pa) =>
                    pa.attackId == attack.id.toLowerCase().trim() ||
                    pa.attackId ==
                        actionId.replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
              )
              .firstOrNull ??
          PrecomputedAttack(
            attackId: attack.id.isNotEmpty ? attack.id : actionId,
            attackBonus: attack.attackBonus,
            flatBonus: attack.damageBonus + attack.secondaryDamageBonus,
            damageGroups: [
              if (attack.diceCount > 0)
                DamageDieGroup(
                    count: attack.diceCount, faces: attack.diceSides),
              if (attack.secondaryDiceCount > 0)
                DamageDieGroup(
                    count: attack.secondaryDiceCount,
                    faces: attack.secondaryDiceSides),
            ],
          );

      // 2. Apply attack hit against defender:
      final hitResult = defender.applyAttackHit(
        precomputedAttack,
        rng: ctx.rng,
        isCrit: isCrit,
        edition: edition,
        damageModifier: (raw) => ctx.applyDefensiveModifiers(
          raw,
          attack.damageType,
          defender,
          edition,
          environment,
        ),
      );

      damageDealt = hitResult.damageDealt;
      appliedRiderLogs = hitResult.riderLogs;
      attacker.totalDamageDealt += damageDealt;

      if (defender.isDefeated) {
        isKillShot = true;
        attacker.kills++;
        defender.applyCondition(ArenaCondition.unconscious, ctx.rollDie, edition);
      }
    }

    String summary;
    if (shielded) {
      final advTag =
          hasAdvantage ? ' (Adv)' : (hasDisadvantage ? ' (Disadv)' : '');
      summary =
          'PARRIED BY SHIELD!$advTag ${defender.displayName} cast Shield (+5 AC) turning attack ($naturalRoll + ${attack.attackBonus} = $totalAttack vs AC ${defender.effectiveAc}) into a miss!';
    } else {
      summary = ctx.formatAttackSummary(
        attacker: attacker,
        defender: defender,
        attack: attack,
        naturalRoll: naturalRoll,
        totalAttack: totalAttack,
        isHit: isHit,
        isCrit: isCrit,
        isFumble: isFumble,
        damageDealt: damageDealt,
        isKillShot: isKillShot,
        hadAdvantage: hasAdvantage,
        hadDisadvantage: hasDisadvantage,
      );
    }

    // Concentration Check Pipeline for single target attack
    if (damageDealt > 0 && defender.activeConcentrationSpellId != null) {
      final conRes =
          defender.checkConcentration(damageDealt, ctx.rollDie, edition);
      if (conRes.broken) {
        final lostName = ctx.getSpellDisplayName(conRes.lostSpellId);
        summary +=
            ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
      }
    }

    return ArenaAttackEvent(
      attackerId: attacker.id,
      attackerName: attacker.displayName,
      attackerTeam: attacker.team,
      defenderId: defender.id,
      defenderName: defender.displayName,
      defenderTeam: defender.team,
      attackName: attack.name,
      d20Roll: naturalRoll,
      attackBonus: attack.attackBonus,
      totalAttack: totalAttack,
      targetAc: defender.effectiveAc,
      isHit: isHit,
      isCrit: isCrit,
      isFumble: isFumble,
      hadAdvantage: hasAdvantage,
      hadDisadvantage: hasDisadvantage,
      damageDealt: damageDealt,
      damageType: attack.damageType,
      isKillShot: isKillShot,
      defenderRemainingHp: defender.currentHp,
      defenderMaxHp: defender.effectiveMaxHp,
      summaryText: summary,
      appliedRiderLogs: appliedRiderLogs,
    );
  }

  /// Evaluates damage resistance, immunity, or vulnerability along with environmental arena rules.

}
