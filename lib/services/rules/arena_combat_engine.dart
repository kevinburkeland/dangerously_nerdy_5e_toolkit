import 'dart:math';
import '../../models/arena/arena_action_result.dart';
import '../../models/arena/arena_combatant.dart';
import '../../models/arena/arena_simulation_models.dart';
import '../../models/dm_screen_data.dart';
import '../../models/dpr/dpr_models.dart';
import '../../models/spellbook_data.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../../utils/secure_random.dart';
import 'aoe_resolver.dart';

/// Comprehensive 5e Combat Resolution & Simulation Engine for the Monster Fighting Arena.
class ArenaCombatEngine {
  final Random _rng;

  ArenaCombatEngine({Random? rng}) : _rng = rng ?? secureRandom;

  /// Rolls 1d20 + initiative bonus for each combatant and returns sorted order.
  List<ArenaCombatant> rollInitiatives(
    List<ArenaCombatant> combatants,
  ) {
    for (final c in combatants) {
      final roll = _rollDie(20);
      c.initiative = roll + c.initiativeBonus;
    }

    // Sort descending by initiative, breaking ties with DEX bonus and max HP
    combatants.sort((a, b) {
      if (b.initiative != a.initiative) {
        return b.initiative.compareTo(a.initiative);
      }
      if (b.initiativeBonus != a.initiativeBonus) {
        return b.initiativeBonus.compareTo(a.initiativeBonus);
      }
      return b.maxHp.compareTo(a.maxHp);
    });

    return combatants;
  }

  /// Evaluates whether an attacker can physically reach/engage a target given reach, altitude, and flight.
  bool _canReachTarget(ArenaCombatant attacker, ArenaCombatant defender, [DprAttackAction? attack]) {
    if (!defender.isAirborne || defender.altitudeInFeet <= 0) {
      return true; // Target is grounded, always reachable
    }

    if (attacker.isAirborne) {
      return true; // Both in flight at aerial combat elevation
    }

    // Attacker is grounded, defender is airborne at altitudeInFeet (e.g. 20 ft)
    if (attack != null) {
      switch (attack.attackType) {
        case AttackType.rangedWeapon:
        case AttackType.rangedSpell:
          return true;
        case AttackType.meleeReach:
          return attacker.meleeReachInFeet >= defender.altitudeInFeet || attack.reachInFeet >= defender.altitudeInFeet;
        case AttackType.meleeStandard:
          return attacker.meleeReachInFeet >= defender.altitudeInFeet;
      }
    }

    return attacker.meleeReachInFeet >= defender.altitudeInFeet;
  }

  /// Selects the best target for an attacker based on chosen [ArenaTargetingStrategy] and reach validation.
  ArenaCombatant? selectTarget(
    ArenaCombatant attacker,
    List<ArenaCombatant> allCombatants,
    ArenaTargetingStrategy strategy, [
    DprAttackAction? attack,
  ]) {
    final livingEnemies = allCombatants
        .where((c) => c.team != attacker.team && c.isAlive)
        .toList();

    if (livingEnemies.isEmpty) return null;

    // Filter by reach validation if attack is specified
    final reachableEnemies = attack != null
        ? livingEnemies.where((e) => _canReachTarget(attacker, e, attack)).toList()
        : livingEnemies;
    final candidates = reachableEnemies.isNotEmpty ? reachableEnemies : livingEnemies;

    switch (strategy) {
      case ArenaTargetingStrategy.focusLowestHp:
        candidates.sort((a, b) {
          if (a.currentHp != b.currentHp) return a.currentHp.compareTo(b.currentHp);
          return a.ac.compareTo(b.ac);
        });
        return candidates.first;

      case ArenaTargetingStrategy.randomEnemy:
        return candidates[_rng.nextInt(candidates.length)];

      case ArenaTargetingStrategy.highestThreat:
        candidates.sort((a, b) {
          final crA = a.monster.challengeRating;
          final crB = b.monster.challengeRating;
          if (crA != crB) return crB.compareTo(crA);
          return b.maxHp.compareTo(a.maxHp);
        });
        return candidates.first;
    }
  }

  /// Executes a single combatant's turn, including recharge rolls, target selection,
  /// tactical spellcasting, multiattack sequencing, roll resolution, and damage application.
  ArenaTurnStep executeTurn({
    required int stepIndex,
    required int roundNumber,
    required ArenaCombatant attacker,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) {
    if (attacker.isDefeated) {
      return ArenaTurnStep(
        stepIndex: stepIndex,
        roundNumber: roundNumber,
        activeCombatant: attacker,
        attackEvents: const [],
        specialEventSummary: '${attacker.displayName} is defeated and skips their turn.',
        combatantHpSnapshot: {for (final c in allCombatants) c.id: c.currentHp},
      );
    }

    // Reset per-turn flags at the start of combatant's turn
    attacker.usedReactionThisRound = false;
    attacker.castBonusActionSpellThisTurn = false;
    attacker.temporaryAcBonus = 0;
    attacker.resetLegendaryActions();

    final events = <ArenaAttackEvent>[];
    String? specialSummary;

    // 1. Recharge Roll check if combatant has a recharge attack that is on cooldown
    final sb = attacker.getStatBlock(edition);
    final attacks = sb.extractDprAttacks();
    final hasRechargeAttack = attacks.any((a) => a.rechargeRoll != null);

    if (hasRechargeAttack && !attacker.isRechargeReady) {
      final rechargeD6 = _rollDie(6);
      final rechargeThreshold = attacks.firstWhere((a) => a.rechargeRoll != null).rechargeRoll ?? 5;
      if (rechargeD6 >= rechargeThreshold) {
        attacker.isRechargeReady = true;
        specialSummary = '${attacker.displayName} recharged their special ability (Rolled $rechargeD6 on d6)!';
      }
    }

    // 2. Tactical AI Spellcasting Evaluator (Priority tree prior to physical attacks)
    if (attacker.isSpellcaster) {
      final spellResult = _evaluateTacticalSpellcasting(
        attacker: attacker,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );

      if (spellResult != null && (spellResult.events.isNotEmpty || spellResult.specialSummary != null)) {
        events.addAll(spellResult.events);
        if (spellResult.specialSummary != null) {
          specialSummary = specialSummary != null
              ? '$specialSummary\n${spellResult.specialSummary}'
              : spellResult.specialSummary;
        }

        // If an Action spell (or cantrip) was cast, it consumed the combatant's Action
        if (events.isNotEmpty) {
          final expired = attacker.tickTurnConditions();
          if (expired.isNotEmpty) {
            final expireMsg = '${attacker.displayName} is no longer ${expired.map((c) => c.label).join(", ")}.';
            specialSummary = specialSummary != null ? '$specialSummary\n$expireMsg' : expireMsg;
          }

          // Off-turn Legendary Actions of opposing living legendary creatures
          final legEvents = executeOffTurnLegendaryActions(
            turnCombatant: attacker,
            allCombatants: allCombatants,
            strategy: strategy,
            edition: edition,
            environment: environment,
          );
          if (legEvents.isNotEmpty) {
            events.addAll(legEvents);
          }

          return ArenaTurnStep(
            stepIndex: stepIndex,
            roundNumber: roundNumber,
            activeCombatant: attacker,
            attackEvents: events,
            specialEventSummary: specialSummary,
            combatantHpSnapshot: {for (final c in allCombatants) c.id: c.currentHp},
          );
        }
      }
    }

    // 3. Physical Attack Routine (Fallback if no offensive spell was cast)
    final actionsToExecute = _selectAttacksForTurn(attacker, attacks, sb, environment: environment);

    for (final attack in actionsToExecute) {
      final isAoE = attack.isAoe ||
          attack.rechargeRoll != null ||
          attack.deliveryType == DprActionDeliveryType.savingThrow ||
          attack.name.toLowerCase().contains('breath') ||
          attack.name.toLowerCase().contains('cone') ||
          attack.name.toLowerCase().contains('burst');

      if (isAoE) {
        // Multi-target Area of Effect resolution using DMG p.249 Theater-of-the-Mind
        final aoeEvents = _resolveAoeAttack(
          attacker: attacker,
          attack: attack,
          allCombatants: allCombatants,
          strategy: strategy,
          edition: edition,
          environment: environment,
        );
        events.addAll(aoeEvents);
        if (aoeEvents.isNotEmpty && aoeEvents.length > 1) {
          final aoeNote = '${attacker.displayName} unleashed ${attack.name} catching ${aoeEvents.length} enemies in the area!';
          specialSummary = specialSummary != null ? '$specialSummary\n$aoeNote' : aoeNote;
        }
      } else {
        // Single target attack resolution with reach and aerial flight validation
        final target = selectTarget(attacker, allCombatants, strategy, attack);
        if (target == null) break; // All enemies defeated!

        // Reach Validation: If grounded attacker with standard melee cannot reach airborne target
        if (target.isAirborne && !attacker.isAirborne && attack.attackType == AttackType.meleeStandard && attacker.meleeReachInFeet < target.altitudeInFeet) {
          // Check for fallback ranged attack
          final rangedFallback = attacks.where((a) => a.attackType == AttackType.rangedWeapon || a.attackType == AttackType.rangedSpell).firstOrNull;
          if (rangedFallback != null) {
            final event = _resolveSingleAttack(
              attacker: attacker,
              defender: target,
              attack: rangedFallback,
              allCombatants: allCombatants,
              edition: edition,
              environment: environment,
            );
            events.add(event);
          } else {
            // Grounded attacker unable to reach airborne target
            final passNote = '${attacker.displayName} cannot reach airborne ${target.displayName} (${target.altitudeInFeet} ft. altitude) with melee reach (${attacker.meleeReachInFeet} ft.) and takes the Dodge action.';
            specialSummary = specialSummary != null ? '$specialSummary\n$passNote' : passNote;
          }
          continue;
        }

        final event = _resolveSingleAttack(
          attacker: attacker,
          defender: target,
          attack: attack,
          allCombatants: allCombatants,
          edition: edition,
          environment: environment,
        );

        events.add(event);
      }
    }

    // 4. End-of-turn condition duration ticking
    final expired = attacker.tickTurnConditions();
    if (expired.isNotEmpty) {
      final expireMsg = '${attacker.displayName} is no longer ${expired.map((c) => c.label).join(", ")}.';
      specialSummary = specialSummary != null ? '$specialSummary\n$expireMsg' : expireMsg;
    }

    // 5. Off-turn Legendary Actions of opposing living legendary creatures
    final legEvents = executeOffTurnLegendaryActions(
      turnCombatant: attacker,
      allCombatants: allCombatants,
      strategy: strategy,
      edition: edition,
      environment: environment,
    );
    if (legEvents.isNotEmpty) {
      events.addAll(legEvents);
    }

    return ArenaTurnStep(
      stepIndex: stepIndex,
      roundNumber: roundNumber,
      activeCombatant: attacker,
      attackEvents: events,
      specialEventSummary: specialSummary,
      combatantHpSnapshot: {for (final c in allCombatants) c.id: c.currentHp},
    );
  }

  // ============================================================================
  // TACTICAL AI SPELLCASTING EVALUATION
  // ============================================================================

  ({List<ArenaAttackEvent> events, String? specialSummary})? _evaluateTacticalSpellcasting({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    final livingEnemies = allCombatants
        .where((c) => c.team != attacker.team && c.isAlive)
        .toList();
    if (livingEnemies.isEmpty) return null;

    final livingAllies = allCombatants
        .where((c) => c.team == attacker.team && c.isAlive)
        .toList();

    final events = <ArenaAttackEvent>[];
    String? bonusSummary;

    // --- Bonus Action Spells ---
    // 1. Healing Word (spell_healing_word)
    if (attacker.hasSpell('spell_healing_word') && _hasSlotFor(attacker, 1)) {
      final injuredAllies = livingAllies.where((a) => a.currentHp < a.maxHp * 0.6).toList();
      if (injuredAllies.isNotEmpty) {
        injuredAllies.sort((a, b) => a.hpPercent.compareTo(b.hpPercent));
        final healTarget = injuredAllies.first;
        final slotLvl = _deductLowestSlot(attacker, 1)!;
        attacker.castBonusActionSpellThisTurn = true;

        final healAmount = _rollDice(slotLvl, 4) + attacker.spellAttackBonus;
        final actualHealed = min(healTarget.maxHp - healTarget.currentHp, healAmount);
        healTarget.currentHp += actualHealed;
        bonusSummary = '${attacker.displayName} cast Healing Word (Slot $slotLvl) on ${healTarget.displayName}, restoring $actualHealed HP!';
      }
    }
    // 2. Misty Step (spell_misty_step)
    else if (attacker.hasSpell('spell_misty_step') && _hasSlotFor(attacker, 2) && !attacker.castBonusActionSpellThisTurn) {
      if (attacker.hpPercent < 0.5) {
        final slotLvl = _deductLowestSlot(attacker, 2)!;
        attacker.castBonusActionSpellThisTurn = true;
        bonusSummary = '${attacker.displayName} cast Misty Step (Slot $slotLvl) to teleport to safety!';
      }
    }

    // --- Main Action Spells ---
    // 5e Action Economy: If a Bonus Action spell was cast, strictly Cantrips only for the main action!
    if (attacker.castBonusActionSpellThisTurn) {
      final cantripEvents = _evaluateCantrips(
        attacker: attacker,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );
      if (cantripEvents != null && cantripEvents.isNotEmpty) {
        events.addAll(cantripEvents);
        return (events: events, specialSummary: bonusSummary);
      }
      return bonusSummary != null ? (events: const [], specialSummary: bonusSummary) : null;
    }

    // Priority 1A: Large AoE Clustering (>= 3 living enemies)
    if (livingEnemies.length >= 3) {
      final aoeEvents = _evaluateAoeSpells(
        attacker: attacker,
        livingEnemies: livingEnemies,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );
      if (aoeEvents != null && aoeEvents.isNotEmpty) {
        events.addAll(aoeEvents);
        return (events: events, specialSummary: bonusSummary);
      }
    }

    // Priority 1B: Kill-Shot / Execution
    final killShotEvents = _evaluateKillShot(
      attacker: attacker,
      livingEnemies: livingEnemies,
      edition: edition,
      environment: environment,
    );
    if (killShotEvents != null && killShotEvents.isNotEmpty) {
      events.addAll(killShotEvents);
      return (events: events, specialSummary: bonusSummary);
    }

    // Priority 2: AoE Clustering (2 living enemies)
    if (livingEnemies.length >= 2) {
      final aoeEvents = _evaluateAoeSpells(
        attacker: attacker,
        livingEnemies: livingEnemies,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );
      if (aoeEvents != null && aoeEvents.isNotEmpty) {
        events.addAll(aoeEvents);
        return (events: events, specialSummary: bonusSummary);
      }
    }

    // Priority 3: Concentration Buff / Control (if not currently concentrating)
    if (attacker.activeConcentrationSpellId == null) {
      final controlResult = _evaluateConcentrationControl(
        attacker: attacker,
        livingEnemies: livingEnemies,
        livingAllies: livingAllies,
        edition: edition,
        environment: environment,
      );
      if (controlResult != null) {
        events.addAll(controlResult.events);
        final summary = [
          if (bonusSummary != null) bonusSummary,
          if (controlResult.summary != null) controlResult.summary,
        ].join('\n');
        return (events: events, specialSummary: summary.isNotEmpty ? summary : null);
      }
    }

    // Priority 4: Single-Target Burst
    final burstEvents = _evaluateSingleTargetBurst(
      attacker: attacker,
      livingEnemies: livingEnemies,
      allCombatants: allCombatants,
      strategy: strategy,
      edition: edition,
      environment: environment,
    );
    if (burstEvents != null && burstEvents.isNotEmpty) {
      events.addAll(burstEvents);
      return (events: events, specialSummary: bonusSummary);
    }

    // Priority 5: Cantrip Fallback
    final cantripEvents = _evaluateCantrips(
      attacker: attacker,
      allCombatants: allCombatants,
      strategy: strategy,
      edition: edition,
      environment: environment,
    );
    if (cantripEvents != null && cantripEvents.isNotEmpty) {
      events.addAll(cantripEvents);
      return (events: events, specialSummary: bonusSummary);
    }

    return bonusSummary != null ? (events: const [], specialSummary: bonusSummary) : null;
  }

  /// Priority 1: Kill-Shot Execution Spells
  List<ArenaAttackEvent>? _evaluateKillShot({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> livingEnemies,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    // 1. Power Word Kill (spell_power_word_kill) - Instantly slays target <= 100 HP
    if (attacker.hasSpell('spell_power_word_kill') && _hasSlotFor(attacker, 9)) {
      final killable = livingEnemies.where((e) => e.currentHp <= 100).toList();
      if (killable.isNotEmpty) {
        killable.sort((a, b) => b.maxHp.compareTo(a.maxHp));
        final target = killable.first;
        _deductHighestSlot(attacker, 9);

        attacker.attacksMade++;
        attacker.hitsLanded++;
        attacker.kills++;
        final dmg = target.currentHp;
        target.applyDamage(dmg);
        attacker.totalDamageDealt += dmg;

        return [
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Power Word Kill',
            d20Roll: 20,
            attackBonus: attacker.spellAttackBonus,
            totalAttack: 20 + attacker.spellAttackBonus,
            targetAc: target.effectiveAc,
            isHit: true,
            isCrit: false,
            isFumble: false,
            damageDealt: dmg,
            damageType: 'force',
            isKillShot: true,
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: 'EXECUTION! ${attacker.displayName} uttered Power Word Kill — ${target.displayName} is instantly slain (took $dmg force damage)!',
          ),
        ];
      }
    }

    // 2. Disintegrate (spell_disintegrate) - High force execution against low/moderate HP foes
    if (attacker.hasSpell('spell_disintegrate') && _hasSlotFor(attacker, 6)) {
      final lowHpFoes = livingEnemies.where((e) => e.currentHp <= 75).toList();
      if (lowHpFoes.isNotEmpty) {
        lowHpFoes.sort((a, b) => a.currentHp.compareTo(b.currentHp));
        final target = lowHpFoes.first;
        final slotLvl = _deductHighestSlot(attacker, 6)!;

        attacker.attacksMade++;
        final d20 = _rollDie(20);
        final saveBonus = target.getSavingThrowBonus('dex', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
        final saved = saveRes.saved;

        int damageDealt = 0;
        bool isKillShot = false;

        if (!saved) {
          attacker.hitsLanded++;
          final extraDice = (slotLvl - 6) * 3;
          final rawDmg = _rollDice(10 + extraDice, 6) + 40;
          damageDealt = _applyDefensiveModifiers(rawDmg, 'force', target, edition, environment);
          attacker.totalDamageDealt += damageDealt;
          target.applyDamage(damageDealt);

          if (target.isDefeated) {
            isKillShot = true;
            attacker.kills++;
          }
        }

        String summary;
        if (saved) {
          summary = 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} — avoided Disintegrate entirely!';
        } else {
          final fatal = isKillShot ? ' — DISINTEGRATED TO ASH!' : '';
          summary = 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full $damageDealt force damage$fatal';
        }

        // Concentration check on target
        if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
          final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
          if (conRes.broken) {
            final lostName = _getSpellDisplayName(conRes.lostSpellId);
            summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
          }
        }

        return [
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Disintegrate (Slot $slotLvl)',
            d20Roll: d20,
            attackBonus: saveBonus,
            totalAttack: totalSave,
            targetAc: target.effectiveAc,
            isHit: !saved,
            isSavingThrow: true,
            saveDc: attacker.spellSaveDc,
            saveRoll: totalSave,
            saved: saved,
            damageDealt: damageDealt,
            damageType: 'force',
            isKillShot: isKillShot,
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: summary,
          ),
        ];
      }
    }

    // 3. Finger of Death (spell_finger_of_death) - High 7th level necrotic execution
    if (attacker.hasSpell('spell_finger_of_death') && _hasSlotFor(attacker, 7)) {
      final lowHpFoes = livingEnemies.where((e) => e.currentHp <= 65).toList();
      if (lowHpFoes.isNotEmpty) {
        lowHpFoes.sort((a, b) => a.currentHp.compareTo(b.currentHp));
        final target = lowHpFoes.first;
        final slotLvl = _deductHighestSlot(attacker, 7)!;

        attacker.attacksMade++;
        final d20 = _rollDie(20);
        final saveBonus = target.getSavingThrowBonus('con', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
        final saved = saveRes.saved;

        final rawDmg = _rollDice(7, 8) + 30;
        int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
        damageDealt = _applyDefensiveModifiers(damageDealt, 'necrotic', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);
        if (damageDealt > 0) attacker.hitsLanded++;

        bool isKillShot = false;
        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }

        final fatal = isKillShot ? ' — SMITTEN WITH NECROTIC DEATH!' : '';
        String summary = saved
            ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} took half: $damageDealt necrotic damage$fatal'
            : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full: $damageDealt necrotic damage$fatal';

        if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
          final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
          if (conRes.broken) {
            final lostName = _getSpellDisplayName(conRes.lostSpellId);
            summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
          }
        }

        return [
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Finger of Death (Slot $slotLvl)',
            d20Roll: d20,
            attackBonus: saveBonus,
            totalAttack: totalSave,
            targetAc: target.effectiveAc,
            isHit: damageDealt > 0,
            isSavingThrow: true,
            saveDc: attacker.spellSaveDc,
            saveRoll: totalSave,
            saved: saved,
            damageDealt: damageDealt,
            damageType: 'necrotic',
            isKillShot: isKillShot,
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: summary,
          ),
        ];
      }
    }

    // 4. Blight (spell_blight) - Targeted necrotic execution
    if (attacker.hasSpell('spell_blight') && _hasSlotFor(attacker, 4)) {
      final lowHpFoes = livingEnemies.where((e) => e.currentHp <= 40).toList();
      if (lowHpFoes.isNotEmpty) {
        lowHpFoes.sort((a, b) => a.currentHp.compareTo(b.currentHp));
        final target = lowHpFoes.first;
        final slotLvl = _deductHighestSlot(attacker, 4)!;

        attacker.attacksMade++;
        final d20 = _rollDie(20);
        final saveBonus = target.getSavingThrowBonus('con', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
        final saved = saveRes.saved;

        final rawDmg = _rollDice(8 + (slotLvl - 4), 8);
        int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
        damageDealt = _applyDefensiveModifiers(damageDealt, 'necrotic', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);
        if (damageDealt > 0) attacker.hitsLanded++;

        bool isKillShot = false;
        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }

        final fatal = isKillShot ? ' — WITHERED & SLAIN!' : '';
        String summary = saved
            ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} took half: $damageDealt necrotic damage$fatal'
            : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full: $damageDealt necrotic damage$fatal';

        if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
          final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
          if (conRes.broken) {
            final lostName = _getSpellDisplayName(conRes.lostSpellId);
            summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
          }
        }

        return [
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Blight (Slot $slotLvl)',
            d20Roll: d20,
            attackBonus: saveBonus,
            totalAttack: totalSave,
            targetAc: target.effectiveAc,
            isHit: damageDealt > 0,
            isSavingThrow: true,
            saveDc: attacker.spellSaveDc,
            saveRoll: totalSave,
            saved: saved,
            damageDealt: damageDealt,
            damageType: 'necrotic',
            isKillShot: isKillShot,
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: summary,
          ),
        ];
      }
    }

    return null;
  }

  /// Priority 2: AoE Clustering Evaluation (DMG p.249 Theater-of-the-Mind with Box-Muller Gaussian clustering)
  List<ArenaAttackEvent>? _evaluateAoeSpells({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> livingEnemies,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    // Check known AoE spells from highest to lowest spell level with DMG p.249 shapes & sizes
    final aoeCandidates = <({
      String id,
      String name,
      int minLevel,
      String saveAbility,
      String damageType,
      AoeShape shape,
      double sizeInFeet,
      int Function(int slot) diceCount,
      int diceSides,
      int staticBonus
    })>[
      (id: 'spell_meteor_swarm', name: 'Meteor Swarm', minLevel: 9, saveAbility: 'dex', damageType: 'fire', shape: AoeShape.sphere, sizeInFeet: 40.0, diceCount: (_) => 40, diceSides: 6, staticBonus: 0),
      (id: 'spell_sunburst', name: 'Sunburst', minLevel: 8, saveAbility: 'con', damageType: 'radiant', shape: AoeShape.sphere, sizeInFeet: 60.0, diceCount: (_) => 12, diceSides: 6, staticBonus: 0),
      (id: 'spell_delayed_blast_fireball', name: 'Delayed Blast Fireball', minLevel: 7, saveAbility: 'dex', damageType: 'fire', shape: AoeShape.sphere, sizeInFeet: 20.0, diceCount: (s) => 12 + (s - 7), diceSides: 6, staticBonus: 0),
      (id: 'spell_fire_storm', name: 'Fire Storm', minLevel: 7, saveAbility: 'dex', damageType: 'fire', shape: AoeShape.cube, sizeInFeet: 100.0, diceCount: (_) => 7, diceSides: 10, staticBonus: 0),
      (id: 'spell_chain_lightning', name: 'Chain Lightning', minLevel: 6, saveAbility: 'dex', damageType: 'lightning', shape: AoeShape.line, sizeInFeet: 120.0, diceCount: (s) => 10 + (s - 6), diceSides: 8, staticBonus: 0),
      (id: 'spell_circle_of_death', name: 'Circle of Death', minLevel: 6, saveAbility: 'con', damageType: 'necrotic', shape: AoeShape.sphere, sizeInFeet: 60.0, diceCount: (s) => 8 + (s - 6) * 2, diceSides: 6, staticBonus: 0),
      (id: 'spell_cone_of_cold', name: 'Cone of Cold', minLevel: 5, saveAbility: 'con', damageType: 'cold', shape: AoeShape.cone, sizeInFeet: 60.0, diceCount: (s) => 8 + (s - 5), diceSides: 8, staticBonus: 0),
      (id: 'spell_cloudkill', name: 'Cloudkill', minLevel: 5, saveAbility: 'con', damageType: 'poison', shape: AoeShape.sphere, sizeInFeet: 20.0, diceCount: (s) => 5 + (s - 5), diceSides: 8, staticBonus: 0),
      (id: 'spell_flame_strike', name: 'Flame Strike', minLevel: 5, saveAbility: 'dex', damageType: 'fire', shape: AoeShape.cylinder, sizeInFeet: 10.0, diceCount: (s) => 8 + (s - 5) * 2, diceSides: 6, staticBonus: 0),
      (id: 'spell_ice_storm', name: 'Ice Storm', minLevel: 4, saveAbility: 'dex', damageType: 'cold', shape: AoeShape.cylinder, sizeInFeet: 20.0, diceCount: (s) => 6 + (s - 4), diceSides: 6, staticBonus: 0),
      (id: 'spell_fireball', name: 'Fireball', minLevel: 3, saveAbility: 'dex', damageType: 'fire', shape: AoeShape.sphere, sizeInFeet: 20.0, diceCount: (s) => 8 + (s - 3), diceSides: 6, staticBonus: 0),
      (id: 'spell_lightning_bolt', name: 'Lightning Bolt', minLevel: 3, saveAbility: 'dex', damageType: 'lightning', shape: AoeShape.line, sizeInFeet: 100.0, diceCount: (s) => 8 + (s - 3), diceSides: 6, staticBonus: 0),
      (id: 'spell_shatter', name: 'Shatter', minLevel: 2, saveAbility: 'con', damageType: 'thunder', shape: AoeShape.sphere, sizeInFeet: 10.0, diceCount: (s) => 3 + (s - 2), diceSides: 8, staticBonus: 0),
      (id: 'spell_burning_hands', name: 'Burning Hands', minLevel: 1, saveAbility: 'dex', damageType: 'fire', shape: AoeShape.cone, sizeInFeet: 15.0, diceCount: (s) => 3 + (s - 1), diceSides: 6, staticBonus: 0),
      (id: 'spell_thunderwave', name: 'Thunderwave', minLevel: 1, saveAbility: 'con', damageType: 'thunder', shape: AoeShape.cube, sizeInFeet: 15.0, diceCount: (s) => 2 + (s - 1), diceSides: 8, staticBonus: 0),
    ];

    for (final candidate in aoeCandidates) {
      if (attacker.hasSpell(candidate.id) && _hasSlotFor(attacker, candidate.minLevel)) {
        final slotLvl = _deductHighestSlot(attacker, candidate.minLevel)!;
        attacker.attacksMade++;

        // Resolve targets using DMG p.249 AoeResolver with natural Box-Muller Gaussian variance
        final caughtTargets = AoeResolver.selectTargets(
          livingEnemies: livingEnemies,
          shape: candidate.shape,
          sizeInFeet: candidate.sizeInFeet,
          rng: _rng,
          strategy: strategy,
        );

        final numDice = candidate.diceCount(slotLvl);
        final rawDamage = _rollDice(numDice, candidate.diceSides) + candidate.staticBonus;
        final events = <ArenaAttackEvent>[];

        for (final defender in caughtTargets) {
          final saveBonus = defender.getSavingThrowBonus(candidate.saveAbility, edition);
          final d20 = _rollDie(20);
          final totalSave = d20 + saveBonus;
          final saveRes = _evaluateSaveWithLegendaryResistance(defender: defender, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
          final saved = saveRes.saved;

          final hasEvasion = defender.hasEvasion(edition) && candidate.saveAbility.toLowerCase() == 'dex';
          bool evadedWithEvasion = false;
          int effectiveDamage;

          if (saved) {
            if (hasEvasion) {
              evadedWithEvasion = true;
              effectiveDamage = 0;
            } else {
              effectiveDamage = (rawDamage / 2).floor();
            }
          } else {
            if (hasEvasion) {
              effectiveDamage = (rawDamage / 2).floor();
            } else {
              effectiveDamage = rawDamage;
            }
          }

          effectiveDamage = _applyDefensiveModifiers(effectiveDamage, candidate.damageType, defender, edition, environment);
          attacker.totalDamageDealt += effectiveDamage;
          defender.applyDamage(effectiveDamage);
          if (effectiveDamage > 0) attacker.hitsLanded++;

          bool isKillShot = false;
          if (defender.isDefeated) {
            isKillShot = true;
            attacker.kills++;
            defender.applyCondition(ArenaCondition.unconscious, _rollDie, edition);
          }

          String summary;
          if (evadedWithEvasion) {
            summary = 'EVADED! (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took 0 ${candidate.damageType} damage via Evasion!';
          } else if (saved) {
            final fatal = isKillShot ? ' — SLAIN!' : '';
            summary = 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} took half: $effectiveDamage ${candidate.damageType} damage$fatal';
          } else {
            final fatal = isKillShot ? ' — SLAIN!' : '';
            summary = 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full: $effectiveDamage ${candidate.damageType} damage$fatal';
          }

          if (effectiveDamage > 0 && defender.activeConcentrationSpellId != null) {
            final conRes = defender.checkConcentration(effectiveDamage, _rollDie, edition);
            if (conRes.broken) {
              final lostName = _getSpellDisplayName(conRes.lostSpellId);
              summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
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
              attackName: '${candidate.name} (Slot $slotLvl)',
              d20Roll: d20,
              attackBonus: saveBonus,
              totalAttack: totalSave,
              targetAc: defender.effectiveAc,
              isHit: !saved || effectiveDamage > 0,
              isCrit: false,
              isFumble: false,
              isAoe: true,
              isSavingThrow: true,
              saveDc: attacker.spellSaveDc,
              saveRoll: totalSave,
              saved: saved,
              evadedWithEvasion: evadedWithEvasion,
              damageDealt: effectiveDamage,
              damageType: candidate.damageType,
              isKillShot: isKillShot,
              defenderRemainingHp: defender.currentHp,
              defenderMaxHp: defender.maxHp,
              summaryText: summary,
            ),
          );
        }

        return events;
      }
    }

    return null;
  }

  /// Priority 3: Concentration Buff & Crowd Control Evaluation
  ({List<ArenaAttackEvent> events, String? summary})? _evaluateConcentrationControl({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> livingEnemies,
    required List<ArenaCombatant> livingAllies,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    // 1. Hold Monster (spell_hold_monster, Level 5)
    if (attacker.hasSpell('spell_hold_monster') && _hasSlotFor(attacker, 5)) {
      livingEnemies.sort((a, b) => b.monster.challengeRating.compareTo(a.monster.challengeRating));
      final target = livingEnemies.first;
      final slotLvl = _deductHighestSlot(attacker, 5)!;
      attacker.activeConcentrationSpellId = 'spell_hold_monster';

      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus('wis', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      String note;
      if (saved) {
        note = '${target.displayName} resisted Hold Monster (Wis save $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote}';
      } else {
        final condRes = target.applyCondition(ArenaCondition.paralyzed, _rollDie, edition);
        note = '${target.displayName} failed Wis save ($totalSave vs DC ${attacker.spellSaveDc}) and is PARALYZED by Hold Monster!';
        if (condRes.fell && condRes.log != null) {
          note += ' [${condRes.log}]';
        }
      }

      return (
        events: [
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Hold Monster (Slot $slotLvl)',
            d20Roll: d20,
            attackBonus: saveBonus,
            totalAttack: totalSave,
            targetAc: target.effectiveAc,
            isHit: !saved,
            isSavingThrow: true,
            saveDc: attacker.spellSaveDc,
            saveRoll: totalSave,
            saved: saved,
            damageDealt: 0,
            damageType: 'psychic',
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: note,
          ),
        ],
        summary: '${attacker.displayName} is now concentrating on Hold Monster.',
      );
    }

    // 2. Banishment (spell_banishment, Level 4)
    if (attacker.hasSpell('spell_banishment') && _hasSlotFor(attacker, 4)) {
      livingEnemies.sort((a, b) => b.monster.challengeRating.compareTo(a.monster.challengeRating));
      final target = livingEnemies.first;
      final slotLvl = _deductHighestSlot(attacker, 4)!;
      attacker.activeConcentrationSpellId = 'spell_banishment';

      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus('cha', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final note = saved
          ? '${target.displayName} resisted Banishment (Cha save $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote}'
          : '${target.displayName} failed Cha save ($totalSave vs DC ${attacker.spellSaveDc}) and is BANISHED to a demiplane!';

      return (
        events: [
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Banishment (Slot $slotLvl)',
            d20Roll: d20,
            attackBonus: saveBonus,
            totalAttack: totalSave,
            targetAc: target.effectiveAc,
            isHit: !saved,
            isSavingThrow: true,
            saveDc: attacker.spellSaveDc,
            saveRoll: totalSave,
            saved: saved,
            damageDealt: 0,
            damageType: 'abjuration',
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: note,
          ),
        ],
        summary: '${attacker.displayName} is now concentrating on Banishment.',
      );
    }

    // 3. Slow (spell_slow, Level 3)
    if (attacker.hasSpell('spell_slow') && _hasSlotFor(attacker, 3)) {
      final slotLvl = _deductHighestSlot(attacker, 3)!;
      attacker.activeConcentrationSpellId = 'spell_slow';
      final events = <ArenaAttackEvent>[];

      for (final enemy in livingEnemies.take(6)) {
        final d20 = _rollDie(20);
        final saveBonus = enemy.getSavingThrowBonus('wis', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = _evaluateSaveWithLegendaryResistance(defender: enemy, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
        final saved = saveRes.saved;

        if (!saved) {
          enemy.temporaryAcBonus -= 2;
        }

        events.add(
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: enemy.id,
            defenderName: enemy.displayName,
            defenderTeam: enemy.team,
            attackName: 'Slow (Slot $slotLvl)',
            d20Roll: d20,
            attackBonus: saveBonus,
            totalAttack: totalSave,
            targetAc: enemy.effectiveAc,
            isHit: !saved,
            isSavingThrow: true,
            saveDc: attacker.spellSaveDc,
            saveRoll: totalSave,
            saved: saved,
            damageDealt: 0,
            damageType: 'transmutation',
            defenderRemainingHp: enemy.currentHp,
            defenderMaxHp: enemy.maxHp,
            summaryText: saved
                ? '${enemy.displayName} resisted Slow (Wis save $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote}'
                : '${enemy.displayName} failed Wis save ($totalSave vs DC ${attacker.spellSaveDc}) — SLOWED (-2 AC)!',
          ),
        );
      }

      return (events: events, summary: '${attacker.displayName} is concentrating on Slow.');
    }

    // 4. Faerie Fire (spell_faerie_fire, Level 1)
    if (attacker.hasSpell('spell_faerie_fire') && _hasSlotFor(attacker, 1)) {
      final slotLvl = _deductLowestSlot(attacker, 1)!;
      attacker.activeConcentrationSpellId = 'spell_faerie_fire';
      final events = <ArenaAttackEvent>[];

      for (final enemy in livingEnemies.take(4)) {
        final d20 = _rollDie(20);
        final saveBonus = enemy.getSavingThrowBonus('dex', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = _evaluateSaveWithLegendaryResistance(defender: enemy, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
        final saved = saveRes.saved;

        events.add(
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: enemy.id,
            defenderName: enemy.displayName,
            defenderTeam: enemy.team,
            attackName: 'Faerie Fire (Slot $slotLvl)',
            d20Roll: d20,
            attackBonus: saveBonus,
            totalAttack: totalSave,
            targetAc: enemy.effectiveAc,
            isHit: !saved,
            isSavingThrow: true,
            saveDc: attacker.spellSaveDc,
            saveRoll: totalSave,
            saved: saved,
            damageDealt: 0,
            damageType: 'evocation',
            defenderRemainingHp: enemy.currentHp,
            defenderMaxHp: enemy.maxHp,
            summaryText: saved
                ? '${enemy.displayName} avoided Faerie Fire (Dex save $totalSave vs DC ${attacker.spellSaveDc})'
                : '${enemy.displayName} is illuminated in colorful light (attacks gain advantage)!',
          ),
        );
      }

      return (events: events, summary: '${attacker.displayName} is concentrating on Faerie Fire.');
    }

    // 5. Shield of Faith (spell_shield_of_faith, Level 1)
    if (attacker.hasSpell('spell_shield_of_faith') && _hasSlotFor(attacker, 1)) {
      final slotLvl = _deductLowestSlot(attacker, 1)!;
      attacker.activeConcentrationSpellId = 'spell_shield_of_faith';
      attacker.temporaryAcBonus += 2;
      return (
        events: const [],
        summary: '${attacker.displayName} cast Shield of Faith (Slot $slotLvl) on themselves (+2 AC, concentrating)!',
      );
    }

    // 6. Bless (spell_bless, Level 1)
    if (attacker.hasSpell('spell_bless') && _hasSlotFor(attacker, 1)) {
      final slotLvl = _deductLowestSlot(attacker, 1)!;
      attacker.activeConcentrationSpellId = 'spell_bless';
      return (
        events: const [],
        summary: '${attacker.displayName} cast Bless (Slot $slotLvl) boosting allies with divine favor!',
      );
    }

    return null;
  }

  /// Priority 4: Single-Target Burst Spells
  List<ArenaAttackEvent>? _evaluateSingleTargetBurst({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> livingEnemies,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    final target = selectTarget(attacker, allCombatants, strategy);
    if (target == null) return null;

    // 1. Finger of Death (spell_finger_of_death, Level 7)
    if (attacker.hasSpell('spell_finger_of_death') && _hasSlotFor(attacker, 7)) {
      final slotLvl = _deductHighestSlot(attacker, 7)!;
      attacker.attacksMade++;

      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus('con', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final rawDmg = _rollDice(7, 8) + 30;
      int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
      damageDealt = _applyDefensiveModifiers(damageDealt, 'necrotic', target, edition, environment);
      attacker.totalDamageDealt += damageDealt;
      target.applyDamage(damageDealt);
      if (damageDealt > 0) attacker.hitsLanded++;

      bool isKillShot = false;
      if (target.isDefeated) {
        isKillShot = true;
        attacker.kills++;
      }

      final fatal = isKillShot ? ' — WITHERED & SLAIN BY FINGER OF DEATH!' : '';
      String summary = saved
          ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} took half: $damageDealt necrotic damage$fatal'
          : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full: $damageDealt necrotic damage$fatal';

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Finger of Death (Slot $slotLvl)',
          d20Roll: d20,
          attackBonus: saveBonus,
          totalAttack: totalSave,
          targetAc: target.effectiveAc,
          isHit: damageDealt > 0,
          isSavingThrow: true,
          saveDc: attacker.spellSaveDc,
          saveRoll: totalSave,
          saved: saved,
          damageDealt: damageDealt,
          damageType: 'necrotic',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 2. Harm (spell_harm, Level 6)
    if (attacker.hasSpell('spell_harm') && _hasSlotFor(attacker, 6)) {
      final slotLvl = _deductHighestSlot(attacker, 6)!;
      attacker.attacksMade++;

      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus('con', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final rawDmg = _rollDice(14, 6);
      int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
      damageDealt = _applyDefensiveModifiers(damageDealt, 'necrotic', target, edition, environment);
      attacker.totalDamageDealt += damageDealt;
      target.applyDamage(damageDealt);
      if (damageDealt > 0) attacker.hitsLanded++;

      bool isKillShot = false;
      if (target.isDefeated) {
        isKillShot = true;
        attacker.kills++;
      }

      final fatal = isKillShot ? ' — DESTROYED BY DISEASE!' : '';
      String summary = saved
          ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} took half: $damageDealt necrotic damage$fatal'
          : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full: $damageDealt necrotic damage$fatal';

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Harm (Slot $slotLvl)',
          d20Roll: d20,
          attackBonus: saveBonus,
          totalAttack: totalSave,
          targetAc: target.effectiveAc,
          isHit: damageDealt > 0,
          isSavingThrow: true,
          saveDc: attacker.spellSaveDc,
          saveRoll: totalSave,
          saved: saved,
          damageDealt: damageDealt,
          damageType: 'necrotic',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 3. Disintegrate (spell_disintegrate, Level 6)
    if (attacker.hasSpell('spell_disintegrate') && _hasSlotFor(attacker, 6)) {
      final slotLvl = _deductHighestSlot(attacker, 6)!;
      attacker.attacksMade++;

      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus('dex', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      int damageDealt = 0;
      bool isKillShot = false;

      if (!saved) {
        attacker.hitsLanded++;
        final extraDice = (slotLvl - 6) * 3;
        final rawDmg = _rollDice(10 + extraDice, 6) + 40;
        damageDealt = _applyDefensiveModifiers(rawDmg, 'force', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      final fatal = isKillShot ? ' — DISINTEGRATED TO ASH!' : '';
      String summary = saved
          ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} — avoided Disintegrate entirely!'
          : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full $damageDealt force damage$fatal';

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Disintegrate (Slot $slotLvl)',
          d20Roll: d20,
          attackBonus: saveBonus,
          totalAttack: totalSave,
          targetAc: target.effectiveAc,
          isHit: !saved,
          isSavingThrow: true,
          saveDc: attacker.spellSaveDc,
          saveRoll: totalSave,
          saved: saved,
          damageDealt: damageDealt,
          damageType: 'force',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 4. Blight (spell_blight, Level 4)
    if (attacker.hasSpell('spell_blight') && _hasSlotFor(attacker, 4)) {
      final slotLvl = _deductHighestSlot(attacker, 4)!;
      attacker.attacksMade++;

      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus('con', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final rawDmg = _rollDice(8 + (slotLvl - 4), 8);
      int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
      damageDealt = _applyDefensiveModifiers(damageDealt, 'necrotic', target, edition, environment);
      attacker.totalDamageDealt += damageDealt;
      target.applyDamage(damageDealt);
      if (damageDealt > 0) attacker.hitsLanded++;

      bool isKillShot = false;
      if (target.isDefeated) {
        isKillShot = true;
        attacker.kills++;
      }

      final fatal = isKillShot ? ' — WITHERED & SLAIN!' : '';
      String summary = saved
          ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} took half: $damageDealt necrotic damage$fatal'
          : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full: $damageDealt necrotic damage$fatal';

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Blight (Slot $slotLvl)',
          d20Roll: d20,
          attackBonus: saveBonus,
          totalAttack: totalSave,
          targetAc: target.effectiveAc,
          isHit: damageDealt > 0,
          isSavingThrow: true,
          saveDc: attacker.spellSaveDc,
          saveRoll: totalSave,
          saved: saved,
          damageDealt: damageDealt,
          damageType: 'necrotic',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 5. Scorching Ray (spell_scorching_ray, Level 2)
    if (attacker.hasSpell('spell_scorching_ray') && _hasSlotFor(attacker, 2)) {
      final slotLvl = _deductHighestSlot(attacker, 2)!;
      final rayCount = 3 + (slotLvl - 2);
      final events = <ArenaAttackEvent>[];

      for (int i = 0; i < rayCount; i++) {
        if (target.isDefeated) break;
        attacker.attacksMade++;

        final d20 = _rollDie(20);
        final isCrit = d20 == 20;
        final isFumble = d20 == 1;
        final totalAttack = d20 + attacker.spellAttackBonus;
        bool isHit = isCrit || (!isFumble && totalAttack >= target.effectiveAc);

        bool shielded = false;
        // Shield reaction check
        if (isHit && !isCrit && !target.usedReactionThisRound &&
            target.hasSpell('spell_shield') && target.hasAvailableSlots) {
          if (totalAttack < target.effectiveAc + 5) {
            _deductLowestSlot(target, 1);
            target.usedReactionThisRound = true;
            target.temporaryAcBonus += 5;
            shielded = true;
            isHit = false;
          }
        }

        int damageDealt = 0;
        bool isKillShot = false;

        if (isHit) {
          attacker.hitsLanded++;
          if (isCrit) attacker.critsLanded++;

          final dice = isCrit ? 4 : 2;
          final rawDmg = _rollDice(dice, 6);
          damageDealt = _applyDefensiveModifiers(rawDmg, 'fire', target, edition, environment);
          attacker.totalDamageDealt += damageDealt;
          target.applyDamage(damageDealt);

          if (target.isDefeated) {
            isKillShot = true;
            attacker.kills++;
          }
        }

        String summary;
        if (shielded) {
          summary = 'PARRIED BY SHIELD! ${target.displayName} cast Shield (+5 AC) deflecting Scorching Ray # ${i + 1} ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
        } else if (isCrit) {
          final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
          summary = 'CRITICAL HIT! (Nat 20) Scorching Ray # ${i + 1} dealt $damageDealt fire damage$fatal';
        } else if (isHit) {
          final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
          summary = 'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt fire damage$fatal';
        } else {
          summary = 'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
        }

        if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
          final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
          if (conRes.broken) {
            final lostName = _getSpellDisplayName(conRes.lostSpellId);
            summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
          }
        }

        events.add(
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Scorching Ray # ${i + 1} (Slot $slotLvl)',
            d20Roll: d20,
            attackBonus: attacker.spellAttackBonus,
            totalAttack: totalAttack,
            targetAc: target.effectiveAc,
            isHit: isHit,
            isCrit: isCrit,
            isFumble: isFumble,
            damageDealt: damageDealt,
            damageType: 'fire',
            isKillShot: isKillShot,
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: summary,
          ),
        );
      }

      return events;
    }

    // 3. Magic Missile (spell_magic_missile, Level 1)
    if (attacker.hasSpell('spell_magic_missile') && _hasSlotFor(attacker, 1)) {
      final slotLvl = _deductHighestSlot(attacker, 1)!;
      final dartCount = 3 + (slotLvl - 1);
      attacker.attacksMade++;
      attacker.hitsLanded++;

      // In 5e RAW Shield negates Magic Missile entirely
      if (!target.usedReactionThisRound && target.hasSpell('spell_shield') && target.hasAvailableSlots) {
        _deductLowestSlot(target, 1);
        target.usedReactionThisRound = true;
        target.temporaryAcBonus += 5;

        return [
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Magic Missile (Slot $slotLvl)',
            d20Roll: 20,
            attackBonus: attacker.spellAttackBonus,
            totalAttack: 20,
            targetAc: target.effectiveAc,
            isHit: false,
            damageDealt: 0,
            damageType: 'force',
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: 'SHIELD INTERCEPT! ${target.displayName} cast Shield as a reaction, completely neutralizing all $dartCount Magic Missile darts!',
          ),
        ];
      }

      final rawDmg = _rollDice(dartCount, 4) + dartCount;
      final damageDealt = _applyDefensiveModifiers(rawDmg, 'force', target, edition, environment);
      attacker.totalDamageDealt += damageDealt;
      target.applyDamage(damageDealt);

      bool isKillShot = false;
      if (target.isDefeated) {
        isKillShot = true;
        attacker.kills++;
      }

      final fatal = isKillShot ? ' — STRUCK DOWN BY FORCE DARTS!' : '';
      String summary = '$dartCount Magic Missiles automatically struck ${target.displayName} for $damageDealt force damage$fatal';

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Magic Missile (Slot $slotLvl)',
          d20Roll: 20,
          attackBonus: attacker.spellAttackBonus,
          totalAttack: 20,
          targetAc: target.effectiveAc,
          isHit: true,
          damageDealt: damageDealt,
          damageType: 'force',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 4. Guiding Bolt (spell_guiding_bolt, Level 1)
    if (attacker.hasSpell('spell_guiding_bolt') && _hasSlotFor(attacker, 1)) {
      final slotLvl = _deductHighestSlot(attacker, 1)!;
      attacker.attacksMade++;

      final d20 = _rollDie(20);
      final isCrit = d20 == 20;
      final isFumble = d20 == 1;
      final totalAttack = d20 + attacker.spellAttackBonus;
      bool isHit = isCrit || (!isFumble && totalAttack >= target.effectiveAc);

      bool shielded = false;
      if (isHit && !isCrit && !target.usedReactionThisRound &&
          target.hasSpell('spell_shield') && target.hasAvailableSlots) {
        if (totalAttack < target.effectiveAc + 5) {
          _deductLowestSlot(target, 1);
          target.usedReactionThisRound = true;
          target.temporaryAcBonus += 5;
          shielded = true;
          isHit = false;
        }
      }

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final dice = isCrit ? (4 + (slotLvl - 1)) * 2 : (4 + (slotLvl - 1));
        final rawDmg = _rollDice(dice, 6);
        damageDealt = _applyDefensiveModifiers(rawDmg, 'radiant', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      String summary;
      if (shielded) {
        summary = 'PARRIED BY SHIELD! ${target.displayName} cast Shield deflecting Guiding Bolt ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary = 'CRITICAL HIT! (Nat 20) Guiding Bolt dealt $damageDealt radiant damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary = 'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt radiant damage$fatal';
      } else {
        summary = 'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
      }

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Guiding Bolt (Slot $slotLvl)',
          d20Roll: d20,
          attackBonus: attacker.spellAttackBonus,
          totalAttack: totalAttack,
          targetAc: target.effectiveAc,
          isHit: isHit,
          isCrit: isCrit,
          isFumble: isFumble,
          damageDealt: damageDealt,
          damageType: 'radiant',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 5. Inflict Wounds (spell_inflict_wounds, Level 1)
    if (attacker.hasSpell('spell_inflict_wounds') && _hasSlotFor(attacker, 1)) {
      final slotLvl = _deductHighestSlot(attacker, 1)!;
      attacker.attacksMade++;

      final d20 = _rollDie(20);
      final isCrit = d20 == 20;
      final isFumble = d20 == 1;
      final totalAttack = d20 + attacker.spellAttackBonus;
      bool isHit = isCrit || (!isFumble && totalAttack >= target.effectiveAc);

      bool shielded = false;
      if (isHit && !isCrit && !target.usedReactionThisRound &&
          target.hasSpell('spell_shield') && target.hasAvailableSlots) {
        if (totalAttack < target.effectiveAc + 5) {
          _deductLowestSlot(target, 1);
          target.usedReactionThisRound = true;
          target.temporaryAcBonus += 5;
          shielded = true;
          isHit = false;
        }
      }

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final dice = isCrit ? (3 + (slotLvl - 1)) * 2 : (3 + (slotLvl - 1));
        final rawDmg = _rollDice(dice, 10);
        damageDealt = _applyDefensiveModifiers(rawDmg, 'necrotic', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      String summary;
      if (shielded) {
        summary = 'PARRIED BY SHIELD! ${target.displayName} cast Shield deflecting Inflict Wounds ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary = 'CRITICAL HIT! (Nat 20) Inflict Wounds dealt $damageDealt necrotic damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary = 'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt necrotic damage$fatal';
      } else {
        summary = 'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
      }

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Inflict Wounds (Slot $slotLvl)',
          d20Roll: d20,
          attackBonus: attacker.spellAttackBonus,
          totalAttack: totalAttack,
          targetAc: target.effectiveAc,
          isHit: isHit,
          isCrit: isCrit,
          isFumble: isFumble,
          damageDealt: damageDealt,
          damageType: 'necrotic',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 6. Acid Arrow (spell_acid_arrow / spell_melfs_acid_arrow, Level 2)
    if ((attacker.hasSpell('spell_acid_arrow') || attacker.hasSpell('spell_melfs_acid_arrow')) &&
        _hasSlotFor(attacker, 2)) {
      final slotLvl = _deductHighestSlot(attacker, 2)!;
      attacker.attacksMade++;

      final d20 = _rollDie(20);
      final isCrit = d20 == 20;
      final isFumble = d20 == 1;
      final totalAttack = d20 + attacker.spellAttackBonus;
      bool isHit = isCrit || (!isFumble && totalAttack >= target.effectiveAc);

      bool shielded = false;
      if (isHit &&
          !isCrit &&
          !target.usedReactionThisRound &&
          target.hasSpell('spell_shield') &&
          target.hasAvailableSlots) {
        if (totalAttack < target.effectiveAc + 5) {
          _deductLowestSlot(target, 1);
          target.usedReactionThisRound = true;
          target.temporaryAcBonus += 5;
          shielded = true;
          isHit = false;
        }
      }

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final baseDice = 4 + (slotLvl - 2);
        final dice = isCrit ? (baseDice * 2) : baseDice;
        // 4d4 initial acid (+ 2d4 secondary)
        final rawDmg = _rollDice(dice, 4) + _rollDice(2, 4);
        damageDealt = _applyDefensiveModifiers(rawDmg, 'acid', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      } else if (!shielded) {
        // Miss: takes half the initial 4d4 acid damage
        final rawDmg = (_rollDice(4, 4) / 2).floor();
        damageDealt = _applyDefensiveModifiers(rawDmg, 'acid', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);
        if (damageDealt > 0) attacker.hitsLanded++;
      }

      String summary;
      if (shielded) {
        summary = 'PARRIED BY SHIELD! ${target.displayName} cast Shield deflecting Acid Arrow ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — DEFENDER CORRODED & SLAIN!' : '';
        summary = 'CRITICAL HIT! (Nat 20) Acid Arrow splashed for $damageDealt acid damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary = 'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt acid damage$fatal';
      } else {
        summary = 'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) — splash dealt $damageDealt acid damage.';
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Acid Arrow (Slot $slotLvl)',
          d20Roll: d20,
          attackBonus: attacker.spellAttackBonus,
          totalAttack: totalAttack,
          targetAc: target.effectiveAc,
          isHit: isHit || damageDealt > 0,
          isCrit: isCrit,
          isFumble: isFumble,
          damageDealt: damageDealt,
          damageType: 'acid',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 7. Leveled AoE Fallback in Single Target (Fireball / Lightning Bolt / Cone of Cold / Cloudkill)
    // If no single-target leveled spell is available, direct an available 3rd+ slot at the single target!
    if ((attacker.hasSpell('spell_fireball') ||
            attacker.hasSpell('spell_lightning_bolt') ||
            attacker.hasSpell('spell_cone_of_cold') ||
            attacker.hasSpell('spell_cloudkill') ||
            attacker.hasSpell('spell_shatter')) &&
        _hasSlotFor(attacker, 2)) {
      final isFireball = attacker.hasSpell('spell_fireball') && _hasSlotFor(attacker, 3);
      final isLightning = attacker.hasSpell('spell_lightning_bolt') && _hasSlotFor(attacker, 3);
      final isConeOfCold = attacker.hasSpell('spell_cone_of_cold') && _hasSlotFor(attacker, 5);
      final isCloudkill = attacker.hasSpell('spell_cloudkill') && _hasSlotFor(attacker, 5);

      final spellName = isConeOfCold
          ? 'Cone of Cold'
          : (isCloudkill
              ? 'Cloudkill'
              : (isFireball ? 'Fireball' : (isLightning ? 'Lightning Bolt' : 'Shatter')));
      final minLvl = isConeOfCold || isCloudkill ? 5 : (isFireball || isLightning ? 3 : 2);
      final saveAbility = isConeOfCold || isCloudkill ? 'con' : (isFireball || isLightning ? 'dex' : 'con');
      final dmgType = isConeOfCold ? 'cold' : (isCloudkill ? 'poison' : (isFireball ? 'fire' : (isLightning ? 'lightning' : 'thunder')));

      final slotLvl = _deductHighestSlot(attacker, minLvl)!;
      attacker.attacksMade++;

      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus(saveAbility, edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final hasEvasion = target.hasEvasion(edition) && saveAbility == 'dex';
      bool evadedWithEvasion = false;

      final numDice = minLvl == 5 ? 8 + (slotLvl - 5) : (minLvl == 3 ? 8 + (slotLvl - 3) : 3 + (slotLvl - 2));
      final diceSides = minLvl == 5 ? 8 : (minLvl == 3 ? 6 : 8);
      final rawDmg = _rollDice(numDice, diceSides);

      int damageDealt;
      if (saved) {
        if (hasEvasion) {
          evadedWithEvasion = true;
          damageDealt = 0;
        } else {
          damageDealt = (rawDmg / 2).floor();
        }
      } else {
        if (hasEvasion) {
          damageDealt = (rawDmg / 2).floor();
        } else {
          damageDealt = rawDmg;
        }
      }

      damageDealt = _applyDefensiveModifiers(damageDealt, dmgType, target, edition, environment);
      attacker.totalDamageDealt += damageDealt;
      target.applyDamage(damageDealt);
      if (damageDealt > 0) attacker.hitsLanded++;

      bool isKillShot = false;
      if (target.isDefeated) {
        isKillShot = true;
        attacker.kills++;
      }

      final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
      String summary = evadedWithEvasion
          ? 'EVADED! $spellName dealt 0 $dmgType damage via Evasion!'
          : (saved
              ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} took half: $damageDealt $dmgType damage$fatal'
              : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full: $damageDealt $dmgType damage$fatal');

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: '$spellName (Slot $slotLvl)',
          d20Roll: d20,
          attackBonus: saveBonus,
          totalAttack: totalSave,
          targetAc: target.effectiveAc,
          isHit: damageDealt > 0 || !saved,
          isSavingThrow: true,
          saveDc: attacker.spellSaveDc,
          saveRoll: totalSave,
          saved: saved,
          evadedWithEvasion: evadedWithEvasion,
          damageDealt: damageDealt,
          damageType: dmgType,
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    return null;
  }

  /// Priority 5: Cantrip Fallback Evaluation
  List<ArenaAttackEvent>? _evaluateCantrips({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    final target = selectTarget(attacker, allCombatants, strategy);
    if (target == null) return null;

    final multiplier = _getCantripDiceMultiplier(attacker);

    // 1. Eldritch Blast (spell_eldritch_blast) - multiple beams
    if (attacker.hasSpell('spell_eldritch_blast')) {
      final events = <ArenaAttackEvent>[];
      for (int i = 0; i < multiplier; i++) {
        if (target.isDefeated) break;
        attacker.attacksMade++;

        final d20 = _rollDie(20);
        final isCrit = d20 == 20;
        final isFumble = d20 == 1;
        final totalAttack = d20 + attacker.spellAttackBonus;
        bool isHit = isCrit || (!isFumble && totalAttack >= target.effectiveAc);

        bool shielded = false;
        if (isHit &&
            !isCrit &&
            !target.usedReactionThisRound &&
            target.hasSpell('spell_shield') &&
            target.hasAvailableSlots) {
          if (totalAttack < target.effectiveAc + 5) {
            _deductLowestSlot(target, 1);
            target.usedReactionThisRound = true;
            target.temporaryAcBonus += 5;
            shielded = true;
            isHit = false;
          }
        }

        int damageDealt = 0;
        bool isKillShot = false;

        if (isHit) {
          attacker.hitsLanded++;
          if (isCrit) attacker.critsLanded++;

          final dice = isCrit ? 2 : 1;
          final rawDmg = _rollDice(dice, 10);
          damageDealt = _applyDefensiveModifiers(rawDmg, 'force', target, edition, environment);
          attacker.totalDamageDealt += damageDealt;
          target.applyDamage(damageDealt);

          if (target.isDefeated) {
            isKillShot = true;
            attacker.kills++;
          }
        }

        String summary;
        if (shielded) {
          summary = 'PARRIED BY SHIELD! ${target.displayName} deflected Eldritch Blast Beam # ${i + 1} ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
        } else if (isCrit) {
          final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
          summary = 'CRITICAL HIT! (Nat 20) Eldritch Blast Beam # ${i + 1} dealt $damageDealt force damage$fatal';
        } else if (isHit) {
          final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
          summary = 'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt force damage$fatal';
        } else {
          summary = 'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
        }

        if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
          final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
          if (conRes.broken) {
            final lostName = _getSpellDisplayName(conRes.lostSpellId);
            summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
          }
        }

        events.add(
          ArenaAttackEvent(
            attackerId: attacker.id,
            attackerName: attacker.displayName,
            attackerTeam: attacker.team,
            defenderId: target.id,
            defenderName: target.displayName,
            defenderTeam: target.team,
            attackName: 'Eldritch Blast (Beam ${i + 1})',
            d20Roll: d20,
            attackBonus: attacker.spellAttackBonus,
            totalAttack: totalAttack,
            targetAc: target.effectiveAc,
            isHit: isHit,
            isCrit: isCrit,
            isFumble: isFumble,
            damageDealt: damageDealt,
            damageType: 'force',
            isKillShot: isKillShot,
            defenderRemainingHp: target.currentHp,
            defenderMaxHp: target.maxHp,
            summaryText: summary,
          ),
        );
      }
      return events;
    }

    // 2. Fire Bolt (spell_fire_bolt)
    if (attacker.hasSpell('spell_fire_bolt')) {
      attacker.attacksMade++;
      final d20 = _rollDie(20);
      final isCrit = d20 == 20;
      final isFumble = d20 == 1;
      final totalAttack = d20 + attacker.spellAttackBonus;
      bool isHit = isCrit || (!isFumble && totalAttack >= target.effectiveAc);

      bool shielded = false;
      if (isHit &&
          !isCrit &&
          !target.usedReactionThisRound &&
          target.hasSpell('spell_shield') &&
          target.hasAvailableSlots) {
        if (totalAttack < target.effectiveAc + 5) {
          _deductLowestSlot(target, 1);
          target.usedReactionThisRound = true;
          target.temporaryAcBonus += 5;
          shielded = true;
          isHit = false;
        }
      }

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final dice = isCrit ? multiplier * 2 : multiplier;
        final rawDmg = _rollDice(dice, 10);
        damageDealt = _applyDefensiveModifiers(rawDmg, 'fire', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      String summary;
      if (shielded) {
        summary = 'PARRIED BY SHIELD! ${target.displayName} cast Shield deflecting Fire Bolt ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary = 'CRITICAL HIT! (Nat 20) Fire Bolt dealt $damageDealt fire damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary = 'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt fire damage$fatal';
      } else {
        summary = 'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
      }

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Fire Bolt',
          d20Roll: d20,
          attackBonus: attacker.spellAttackBonus,
          totalAttack: totalAttack,
          targetAc: target.effectiveAc,
          isHit: isHit,
          isCrit: isCrit,
          isFumble: isFumble,
          damageDealt: damageDealt,
          damageType: 'fire',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 3. Toll the Dead (spell_toll_the_dead)
    if (attacker.hasSpell('spell_toll_the_dead')) {
      attacker.attacksMade++;
      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus('wis', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      int damageDealt = 0;
      bool isKillShot = false;

      if (!saved) {
        attacker.hitsLanded++;
        final sides = (target.currentHp < target.maxHp) ? 12 : 8;
        final rawDmg = _rollDice(multiplier, sides);
        damageDealt = _applyDefensiveModifiers(rawDmg, 'necrotic', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      final fatal = isKillShot ? ' — KILLED BY DOLEFUL BELL!' : '';
      String summary = saved
          ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} — took 0 necrotic damage'
          : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took $damageDealt necrotic damage$fatal';

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Toll the Dead',
          d20Roll: d20,
          attackBonus: saveBonus,
          totalAttack: totalSave,
          targetAc: target.effectiveAc,
          isHit: !saved,
          isSavingThrow: true,
          saveDc: attacker.spellSaveDc,
          saveRoll: totalSave,
          saved: saved,
          damageDealt: damageDealt,
          damageType: 'necrotic',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 4. Ray of Frost (spell_ray_of_frost) or generic spellcaster Ray of Frost
    if (attacker.hasSpell('spell_ray_of_frost') ||
        (attacker.isSpellcaster && !attacker.hasSpell('spell_sacred_flame'))) {
      attacker.attacksMade++;
      final d20 = _rollDie(20);
      final isCrit = d20 == 20;
      final isFumble = d20 == 1;
      final totalAttack = d20 + attacker.spellAttackBonus;
      bool isHit = isCrit || (!isFumble && totalAttack >= target.effectiveAc);

      bool shielded = false;
      if (isHit &&
          !isCrit &&
          !target.usedReactionThisRound &&
          target.hasSpell('spell_shield') &&
          target.hasAvailableSlots) {
        if (totalAttack < target.effectiveAc + 5) {
          _deductLowestSlot(target, 1);
          target.usedReactionThisRound = true;
          target.temporaryAcBonus += 5;
          shielded = true;
          isHit = false;
        }
      }

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final dice = isCrit ? multiplier * 2 : multiplier;
        final rawDmg = _rollDice(dice, 8);
        damageDealt = _applyDefensiveModifiers(rawDmg, 'cold', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      String summary;
      if (shielded) {
        summary = 'PARRIED BY SHIELD! ${target.displayName} deflected Ray of Frost ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — FROZEN & SLAIN!' : '';
        summary = 'CRITICAL HIT! (Nat 20) Ray of Frost dealt $damageDealt cold damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — FROZEN & SLAIN!' : '';
        summary = 'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt cold damage$fatal';
      } else {
        summary = 'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
      }

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Ray of Frost',
          d20Roll: d20,
          attackBonus: attacker.spellAttackBonus,
          totalAttack: totalAttack,
          targetAc: target.effectiveAc,
          isHit: isHit,
          isCrit: isCrit,
          isFumble: isFumble,
          damageDealt: damageDealt,
          damageType: 'cold',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    // 5. Sacred Flame (spell_sacred_flame)
    if (attacker.hasSpell('spell_sacred_flame')) {
      attacker.attacksMade++;
      final d20 = _rollDie(20);
      final saveBonus = target.getSavingThrowBonus('dex', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      int damageDealt = 0;
      bool isKillShot = false;

      if (!saved) {
        attacker.hitsLanded++;
        final rawDmg = _rollDice(multiplier, 8);
        damageDealt = _applyDefensiveModifiers(rawDmg, 'radiant', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      final fatal = isKillShot ? ' — PURGED & SLAIN!' : '';
      String summary = saved
          ? 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} — took 0 radiant damage'
          : 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took $damageDealt radiant damage$fatal';

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes = target.checkConcentration(damageDealt, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
        }
      }

      return [
        ArenaAttackEvent(
          attackerId: attacker.id,
          attackerName: attacker.displayName,
          attackerTeam: attacker.team,
          defenderId: target.id,
          defenderName: target.displayName,
          defenderTeam: target.team,
          attackName: 'Sacred Flame',
          d20Roll: d20,
          attackBonus: saveBonus,
          totalAttack: totalSave,
          targetAc: target.effectiveAc,
          isHit: !saved,
          isSavingThrow: true,
          saveDc: attacker.spellSaveDc,
          saveRoll: totalSave,
          saved: saved,
          damageDealt: damageDealt,
          damageType: 'radiant',
          isKillShot: isKillShot,
          defenderRemainingHp: target.currentHp,
          defenderMaxHp: target.maxHp,
          summaryText: summary,
        ),
      ];
    }

    return null;
  }

  // --- Tactical Helper Methods ---

  /// Evaluates saving throw success and checks whether the defender chooses to expend
  /// a Legendary Resistance charge to convert a failed save into a success.
  ({bool saved, bool usedLegendaryResistance, String summaryNote}) _evaluateSaveWithLegendaryResistance({
    required ArenaCombatant defender,
    required int saveRoll,
    required int saveDc,
  }) {
    bool saved = saveRoll >= saveDc;
    bool usedLegendary = false;
    String note = '';

    if (!saved && defender.useLegendaryResistance()) {
      saved = true;
      usedLegendary = true;
      final remaining = defender.legendaryResistancesRemaining;
      note = ' [LEGENDARY RESISTANCE! ${defender.displayName} chose to succeed ($remaining left)]';
    }

    return (saved: saved, usedLegendaryResistance: usedLegendary, summaryNote: note);
  }

  int? _deductLowestSlot(ArenaCombatant combatant, int minLevel) {
    for (int lvl = minLevel; lvl <= 9; lvl++) {
      final count = combatant.currentSpellSlots[lvl] ?? 0;
      if (count > 0) {
        combatant.currentSpellSlots[lvl] = count - 1;
        return lvl;
      }
    }
    return null;
  }

  int? _deductHighestSlot(ArenaCombatant combatant, int minLevel) {
    for (int lvl = 9; lvl >= minLevel; lvl--) {
      final count = combatant.currentSpellSlots[lvl] ?? 0;
      if (count > 0) {
        combatant.currentSpellSlots[lvl] = count - 1;
        return lvl;
      }
    }
    return null;
  }

  bool _hasSlotFor(ArenaCombatant combatant, int minLevel) {
    for (int lvl = minLevel; lvl <= 9; lvl++) {
      if ((combatant.currentSpellSlots[lvl] ?? 0) > 0) return true;
    }
    return false;
  }

  int _getCantripDiceMultiplier(ArenaCombatant caster) {
    final cr = caster.monster.challengeRating;
    if (cr >= 17) return 4;
    if (cr >= 11) return 3;
    if (cr >= 5) return 2;
    return 1;
  }

  String _getSpellDisplayName(String? spellId) {
    if (spellId == null) return 'Spell';
    final spell = SpellbookLibrary.getSpellById(spellId);
    if (spell != null) return spell.name;
    return spellId
        .replaceAll('spell_', '')
        .split('_')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  /// Determines which attacks the monster uses during their action turn.
  List<DprAttackAction> _selectAttacksForTurn(
    ArenaCombatant attacker,
    List<DprAttackAction> allAttacks,
    MinionStatBlock sb, {
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
              (a.attackType != AttackType.rangedWeapon && a.attackType != AttackType.rangedSpell))
          .toList();
      if (meleeOptions.isNotEmpty) {
        candidateAttacks = meleeOptions;
      }
    }

    // Check if recharge attack is ready and available
    final rechargeAttack = candidateAttacks.where((a) => a.rechargeRoll != null).firstOrNull;
    if (rechargeAttack != null && attacker.isRechargeReady) {
      attacker.isRechargeReady = false;
      return [rechargeAttack];
    }

    // Standard turn attacks (excluding legendary action standalone triggers and recharge attacks)
    // Only select attacks that are part of the monster's active multiattack routine (attacksPerRound > 0)
    final activeAttacks = candidateAttacks
        .where((a) => !a.isLegendaryAction && a.rechargeRoll == null && a.attacksPerRound > 0)
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

    // Fallback: If no attack has attacksPerRound > 0, pick the single best standard attack
    final standardAttacks = candidateAttacks.where((a) => !a.isLegendaryAction && a.rechargeRoll == null).toList();
    if (standardAttacks.isNotEmpty) {
      return [standardAttacks.first.copyWith(attacksPerRound: 1)];
    }

    return candidateAttacks.take(1).map((a) => a.copyWith(attacksPerRound: 1)).toList();
  }

  /// Resolves an Area of Effect (AoE) attack hitting a dynamic number of opponents based on DMG p.249 Theater-of-the-Mind.
  List<ArenaAttackEvent> _resolveAoeAttack({
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
    final matchingAction = sb.actions.where((a) => a.name.toLowerCase() == attack.name.toLowerCase()).firstOrNull;
    final parsedShape = AoeResolver.parseShapeAndSize(attack.name, matchingAction?.description);
    final caughtDefenders = AoeResolver.selectTargets(
      livingEnemies: livingEnemies,
      shape: parsedShape.shape,
      sizeInFeet: parsedShape.sizeInFeet,
      rng: _rng,
      strategy: strategy,
    );

    // Roll base damage once for the AoE
    final rawDamage = _rollDice(attack.diceCount, attack.diceSides) + attack.damageBonus;
    final saveAbility = attack.saveAbility ?? 'dex';
    final saveDc = attack.saveDc ?? _computeSaveDc(attacker, edition);

    final events = <ArenaAttackEvent>[];

    for (final defender in caughtDefenders) {
      final saveBonus = defender.getSavingThrowBonus(saveAbility, edition);
      final d20 = _rollDie(20);
      final totalSave = d20 + saveBonus;
      final saveRes = _evaluateSaveWithLegendaryResistance(defender: defender, saveRoll: totalSave, saveDc: saveDc);
      final saved = saveRes.saved;

      final hasEvasion = defender.hasEvasion(edition) && saveAbility.toLowerCase() == 'dex';
      bool evadedWithEvasion = false;
      int effectiveDamage;

      if (saved) {
        if (hasEvasion) {
          evadedWithEvasion = true;
          effectiveDamage = 0;
        } else {
          effectiveDamage = (rawDamage / 2).floor();
        }
      } else {
        if (hasEvasion) {
          evadedWithEvasion = true;
          effectiveDamage = (rawDamage / 2).floor();
        } else {
          effectiveDamage = rawDamage;
        }
      }

      // Apply resistances, immunities & environmental modifiers
      effectiveDamage = _applyDefensiveModifiers(effectiveDamage, attack.damageType, defender, edition, environment);
      attacker.totalDamageDealt += effectiveDamage;
      defender.applyDamage(effectiveDamage);

      bool isKillShot = false;
      if (defender.isDefeated) {
        isKillShot = true;
        attacker.kills++;
        defender.applyCondition(ArenaCondition.unconscious, _rollDie, edition);
      }

      String summary;
      if (evadedWithEvasion) {
        summary = 'EVADED! (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc) took 0 ${attack.damageType} damage via Evasion!';
      } else if (saved) {
        final fatal = isKillShot ? ' — SLAIN!' : '';
        summary = 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc)${saveRes.summaryNote} took half: $effectiveDamage ${attack.damageType} damage$fatal';
      } else {
        final fatal = isKillShot ? ' — SLAIN!' : '';
        summary = 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc) took full: $effectiveDamage ${attack.damageType} damage$fatal';
      }

      // Concentration Check Pipeline for AoE attacks
      if (effectiveDamage > 0 && defender.activeConcentrationSpellId != null) {
        final conRes = defender.checkConcentration(effectiveDamage, _rollDie, edition);
        if (conRes.broken) {
          final lostName = _getSpellDisplayName(conRes.lostSpellId);
          summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
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
          evadedWithEvasion: evadedWithEvasion,
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

  /// Default DC calculation when not explicit (8 + proficiency + ability modifier).
  int _computeSaveDc(ArenaCombatant attacker, DmRulesEdition edition) {
    final cr = attacker.monster.challengeRating;
    int pb = 2;
    if (cr >= 5) pb = 3;
    if (cr >= 9) pb = 4;
    if (cr >= 13) pb = 5;
    if (cr >= 17) pb = 6;
    final sb = attacker.getStatBlock(edition);
    final mod = max(sb.conMod, max(sb.strMod, sb.chaMod));
    return 8 + pb + mod;
  }

  /// Resolves an individual single-target attack roll vs defender's AC,
  /// factoring in aerial/grounded mobility, underwater rules, cage constraints,
  /// Shield reactions, conditions, and concentration checks.
  ArenaAttackEvent _resolveSingleAttack({
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

    final isRangedAttack = attack.attackType == AttackType.rangedWeapon || attack.attackType == AttackType.rangedSpell;

    bool flightAdvantage = false;
    bool flightDisadvantage = false;

    if (attackerFlies && !defenderFlies && (isRangedAttack || attacker.hasFlyby(edition))) {
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

    if (defender.isParalyzed || defender.isStunned || defender.isUnconscious || defender.hasCondition(ArenaCondition.restrained)) {
      conditionAdvantage = true;
    }

    if (defender.isProne) {
      if (attack.attackType == AttackType.meleeStandard || attack.attackType == AttackType.meleeReach) {
        conditionAdvantage = true;
      } else {
        conditionDisadvantage = true;
      }
    }

    if (attacker.isProne || attacker.hasCondition(ArenaCondition.restrained) || attacker.hasCondition(ArenaCondition.blinded) || attacker.hasCondition(ArenaCondition.poisoned)) {
      conditionDisadvantage = true;
    }

    final hasAdvantage = (packTacticsAdvantage || flightAdvantage || aquaticAdvantage || conditionAdvantage) &&
        !flightDisadvantage &&
        !aquaticDisadvantage &&
        !conditionDisadvantage &&
        !cageMatchDisadvantage;
    final hasDisadvantage = (flightDisadvantage || aquaticDisadvantage || conditionDisadvantage || cageMatchDisadvantage) &&
        !packTacticsAdvantage &&
        !flightAdvantage &&
        !aquaticAdvantage &&
        !conditionAdvantage;

    // Roll d20
    final d20A = _rollDie(20);
    final d20B = (hasAdvantage || hasDisadvantage) ? _rollDie(20) : null;
    int naturalRoll = d20A;
    if (hasAdvantage && d20B != null) naturalRoll = max(d20A, d20B);
    if (hasDisadvantage && d20B != null) naturalRoll = min(d20A, d20B);

    final isFumble = naturalRoll == 1;
    final totalAttack = naturalRoll + attack.attackBonus;
    bool isHit = (naturalRoll == 20) || (!isFumble && totalAttack >= defender.effectiveAc);
    final isCrit = (naturalRoll == 20) || (isHit && (defender.isParalyzed || defender.isUnconscious) && attack.attackType == AttackType.meleeStandard);

    int damageDealt = 0;
    bool isKillShot = false;
    bool shielded = false;

    // Defensive Reaction Hook: Shield (spell_shield)
    if (isHit && !isCrit && !defender.usedReactionThisRound &&
        defender.hasSpell('spell_shield') && defender.hasAvailableSlots) {
      if (totalAttack < defender.effectiveAc + 5) {
        _deductLowestSlot(defender, 1);
        defender.usedReactionThisRound = true;
        defender.temporaryAcBonus += 5;
        shielded = true;
        isHit = false;
      }
    }

    if (isHit) {
      attacker.hitsLanded++;
      if (isCrit) attacker.critsLanded++;

      // Primary damage roll (double dice count on crit)
      final diceCount = isCrit ? attack.diceCount * 2 : attack.diceCount;
      int rawDamage = _rollDice(diceCount, attack.diceSides) + attack.damageBonus;

      // Secondary damage roll if any
      if (attack.secondaryDiceCount > 0 && attack.secondaryDiceSides > 0) {
        final secCount = isCrit ? attack.secondaryDiceCount * 2 : attack.secondaryDiceCount;
        rawDamage += _rollDice(secCount, attack.secondaryDiceSides);
      }

      // Apply resistances, immunities & environmental modifiers
      damageDealt = _applyDefensiveModifiers(rawDamage, attack.damageType, defender, edition, environment);
      attacker.totalDamageDealt += damageDealt;
      defender.applyDamage(damageDealt);

      if (defender.isDefeated) {
        isKillShot = true;
        attacker.kills++;
        defender.applyCondition(ArenaCondition.unconscious, _rollDie, edition);
      }
    }

    String summary;
    if (shielded) {
      final advTag = hasAdvantage ? ' (Adv)' : (hasDisadvantage ? ' (Disadv)' : '');
      summary = 'PARRIED BY SHIELD!$advTag ${defender.displayName} cast Shield (+5 AC) turning attack ($naturalRoll + ${attack.attackBonus} = $totalAttack vs AC ${defender.effectiveAc}) into a miss!';
    } else {
      summary = _formatAttackSummary(
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
      final conRes = defender.checkConcentration(damageDealt, _rollDie, edition);
      if (conRes.broken) {
        final lostName = _getSpellDisplayName(conRes.lostSpellId);
        summary += ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
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
      defenderMaxHp: defender.maxHp,
      summaryText: summary,
    );
  }

  /// Evaluates damage resistance, immunity, or vulnerability along with environmental arena rules.
  int _applyDefensiveModifiers(
    int rawDamage,
    String damageType,
    ArenaCombatant defender,
    DmRulesEdition edition, [
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  ]) {
    final sb = defender.getStatBlock(edition);
    final dmgLower = damageType.toLowerCase().trim();

    // Flooded Abyss: Submerged creatures have natural resistance to fire damage
    int workingDamage = rawDamage;
    if (environment == ArenaEnvironment.floodedAbyss && dmgLower == 'fire') {
      workingDamage = (workingDamage / 2).floor();
    }

    // Check Immunity (0 damage)
    final immunities = (sb.damageImmunities ?? '').toLowerCase();
    if (immunities.isNotEmpty && (immunities.contains(dmgLower) || immunities.contains('all'))) {
      return 0;
    }

    // Check Vulnerability (Double damage)
    final vulnerabilities = (sb.damageVulnerabilities ?? '').toLowerCase();
    if (vulnerabilities.isNotEmpty && vulnerabilities.contains(dmgLower)) {
      workingDamage = workingDamage * 2;
    }

    // Check Resistance (Half damage)
    final resistances = (sb.damageResistances ?? '').toLowerCase();
    if (resistances.isNotEmpty && (resistances.contains(dmgLower) || resistances.contains('all'))) {
      workingDamage = (workingDamage / 2).floor();
    }

    return max(0, workingDamage);
  }

  /// Evaluates and executes off-turn Legendary Actions for living opposing legendary combatants
  /// at the end of another creature's turn.
  List<ArenaAttackEvent> executeOffTurnLegendaryActions({
    required ArenaCombatant turnCombatant,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) {
    final opposingLegendaries = allCombatants.where((c) =>
        c.team != turnCombatant.team &&
        c.isAlive &&
        !c.isIncapacitated &&
        c.hasLegendaryActions &&
        c.legendaryActionsRemaining > 0).toList();

    if (opposingLegendaries.isEmpty) return const [];

    final events = <ArenaAttackEvent>[];

    for (final legendary in opposingLegendaries) {
      final livingEnemies = allCombatants
          .where((c) => c.team != legendary.team && c.isAlive)
          .toList();
      if (livingEnemies.isEmpty) break;

      final sb = legendary.getStatBlock(edition);
      final legActions = sb.legendaryActions;

      // 1. Disrupt Life (Costs 3 Actions)
      final hasDisruptLife = legActions.any((a) => a.name.toLowerCase().contains('disrupt life')) ||
          sb.traits.any((t) => t.description.toLowerCase().contains('disrupt life'));
      if (hasDisruptLife && legendary.legendaryActionsRemaining >= 3 && livingEnemies.length >= 2) {
        legendary.legendaryActionsRemaining -= 3;
        legendary.attacksMade++;

        for (final enemy in livingEnemies) {
          final d20 = _rollDie(20);
          final saveBonus = enemy.getSavingThrowBonus('con', edition);
          final totalSave = d20 + saveBonus;
          final dc = legendary.spellSaveDc > 10 ? legendary.spellSaveDc : 18;
          final saveRes = _evaluateSaveWithLegendaryResistance(defender: enemy, saveRoll: totalSave, saveDc: dc);
          final saved = saveRes.saved;

          final rawDmg = _rollDice(6, 6);
          int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
          damageDealt = _applyDefensiveModifiers(damageDealt, 'necrotic', enemy, edition, environment);
          legendary.totalDamageDealt += damageDealt;
          enemy.applyDamage(damageDealt);
          if (damageDealt > 0) legendary.hitsLanded++;

          bool isKillShot = false;
          if (enemy.isDefeated) {
            isKillShot = true;
            legendary.kills++;
          }

          final fatal = isKillShot ? ' — DESTROYED BY DISRUPT LIFE!' : '';
          final summary = saved
              ? '[Legendary Action (3 Actions)] Saved (Rolled $d20 + $saveBonus = $totalSave vs DC $dc)${saveRes.summaryNote} took half: $damageDealt necrotic damage$fatal'
              : '[Legendary Action (3 Actions)] Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC $dc) took full: $damageDealt necrotic damage$fatal';

          events.add(
            ArenaAttackEvent(
              attackerId: legendary.id,
              attackerName: legendary.displayName,
              attackerTeam: legendary.team,
              defenderId: enemy.id,
              defenderName: enemy.displayName,
              defenderTeam: enemy.team,
              attackName: 'Legendary Action: Disrupt Life (3 Actions)',
              d20Roll: d20,
              attackBonus: saveBonus,
              totalAttack: totalSave,
              targetAc: enemy.effectiveAc,
              isHit: damageDealt > 0 || !saved,
              isAoe: true,
              isSavingThrow: true,
              saveDc: dc,
              saveRoll: totalSave,
              saved: saved,
              damageDealt: damageDealt,
              damageType: 'necrotic',
              isKillShot: isKillShot,
              defenderRemainingHp: enemy.currentHp,
              defenderMaxHp: enemy.maxHp,
              summaryText: summary,
            ),
          );
        }
        continue;
      }

      // 2. Paralyzing Touch (Costs 2 Actions)
      final hasParalyzingTouch = legActions.any((a) => a.name.toLowerCase().contains('paralyzing touch'));
      if (hasParalyzingTouch && legendary.legendaryActionsRemaining >= 2) {
        final target = selectTarget(legendary, allCombatants, strategy);
        if (target != null) {
          legendary.legendaryActionsRemaining -= 2;
          legendary.attacksMade++;

          final d20 = _rollDie(20);
          final isCrit = d20 == 20;
          final isFumble = d20 == 1;
          final atkBonus = legendary.spellAttackBonus > 0 ? legendary.spellAttackBonus : sb.attackBonus;
          final totalAttack = d20 + atkBonus;
          final isHit = isCrit || (!isFumble && totalAttack >= target.effectiveAc);

          int damageDealt = 0;
          bool isKillShot = false;
          String paralyzeMsg = '';

          if (isHit) {
            legendary.hitsLanded++;
            if (isCrit) legendary.critsLanded++;

            final dice = isCrit ? 6 : 3;
            final rawDmg = _rollDice(dice, 6);
            damageDealt = _applyDefensiveModifiers(rawDmg, 'cold', target, edition, environment);
            legendary.totalDamageDealt += damageDealt;
            target.applyDamage(damageDealt);

            if (target.isDefeated) {
              isKillShot = true;
              legendary.kills++;
            } else {
              // Con save vs paralysis
              final saveD20 = _rollDie(20);
              final conBonus = target.getSavingThrowBonus('con', edition);
              final saveTotal = saveD20 + conBonus;
              final dc = legendary.spellSaveDc > 10 ? legendary.spellSaveDc : 18;
              final saveRes = _evaluateSaveWithLegendaryResistance(defender: target, saveRoll: saveTotal, saveDc: dc);
              if (!saveRes.saved) {
                target.applyCondition(ArenaCondition.paralyzed, _rollDie, edition, durationRounds: 10, source: 'Paralyzing Touch');
                paralyzeMsg = ' — FAILED Con Save ($saveTotal vs DC $dc) and is PARALYZED!';
              } else {
                paralyzeMsg = ' — Saved against paralysis ($saveTotal vs DC $dc)${saveRes.summaryNote}.';
              }
            }
          }

          final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
          final summary = isHit
              ? '[Legendary Action (2 Actions)] Hits (Roll $d20 + $atkBonus = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt cold damage$fatal$paralyzeMsg'
              : '[Legendary Action (2 Actions)] Misses (Roll $d20 + $atkBonus = $totalAttack vs AC ${target.effectiveAc}).';

          events.add(
            ArenaAttackEvent(
              attackerId: legendary.id,
              attackerName: legendary.displayName,
              attackerTeam: legendary.team,
              defenderId: target.id,
              defenderName: target.displayName,
              defenderTeam: target.team,
              attackName: 'Legendary Action: Paralyzing Touch (2 Actions)',
              d20Roll: d20,
              attackBonus: atkBonus,
              totalAttack: totalAttack,
              targetAc: target.effectiveAc,
              isHit: isHit,
              isCrit: isCrit,
              isFumble: isFumble,
              damageDealt: damageDealt,
              damageType: 'cold',
              isKillShot: isKillShot,
              defenderRemainingHp: target.currentHp,
              defenderMaxHp: target.maxHp,
              summaryText: summary,
            ),
          );
          continue;
        }
      }

      // 3. Cantrip (Costs 1 Action)
      final hasCantrip = legActions.any((a) => a.name.toLowerCase().contains('cantrip')) || legendary.isSpellcaster;
      if (hasCantrip && legendary.legendaryActionsRemaining >= 1) {
        final cantripEvents = _evaluateCantrips(
          attacker: legendary,
          allCombatants: allCombatants,
          strategy: strategy,
          edition: edition,
          environment: environment,
        );
        if (cantripEvents != null && cantripEvents.isNotEmpty) {
          legendary.legendaryActionsRemaining -= 1;
          for (final ev in cantripEvents) {
            events.add(
              ArenaAttackEvent(
                attackerId: ev.attackerId,
                attackerName: ev.attackerName,
                attackerTeam: ev.attackerTeam,
                defenderId: ev.defenderId,
                defenderName: ev.defenderName,
                defenderTeam: ev.defenderTeam,
                attackName: '[Legendary Action] ${ev.attackName}',
                d20Roll: ev.d20Roll,
                attackBonus: ev.attackBonus,
                totalAttack: ev.totalAttack,
                targetAc: ev.targetAc,
                isHit: ev.isHit,
                isCrit: ev.isCrit,
                isFumble: ev.isFumble,
                isAoe: ev.isAoe,
                isSavingThrow: ev.isSavingThrow,
                saveDc: ev.saveDc,
                saveRoll: ev.saveRoll,
                saved: ev.saved,
                evadedWithEvasion: ev.evadedWithEvasion,
                damageDealt: ev.damageDealt,
                damageType: ev.damageType,
                isKillShot: ev.isKillShot,
                defenderRemainingHp: ev.defenderRemainingHp,
                defenderMaxHp: ev.defenderMaxHp,
                summaryText: '[Legendary Action (1 Action)] ${ev.summaryText}',
              ),
            );
          }
          continue;
        }
      }

      // 4. Fallback: Standard Legendary Attack Action (Tail Attack, Wing Attack, Claw/Bite)
      final dprAttacks = sb.extractDprAttacks().where((a) => a.isLegendaryAction || legActions.any((la) => la.name.toLowerCase().contains(a.name.toLowerCase()))).toList();
      if (dprAttacks.isNotEmpty && legendary.legendaryActionsRemaining >= 1) {
        final attack = dprAttacks.first;
        final target = selectTarget(legendary, allCombatants, strategy, attack);
        if (target != null) {
          legendary.legendaryActionsRemaining -= 1;
          final event = _resolveSingleAttack(
            attacker: legendary,
            defender: target,
            attack: attack,
            allCombatants: allCombatants,
            edition: edition,
            environment: environment,
          );
          events.add(
            ArenaAttackEvent(
              attackerId: event.attackerId,
              attackerName: event.attackerName,
              attackerTeam: event.attackerTeam,
              defenderId: event.defenderId,
              defenderName: event.defenderName,
              defenderTeam: event.defenderTeam,
              attackName: '[Legendary Action] ${event.attackName}',
              d20Roll: event.d20Roll,
              attackBonus: event.attackBonus,
              totalAttack: event.totalAttack,
              targetAc: event.targetAc,
              isHit: event.isHit,
              isCrit: event.isCrit,
              isFumble: event.isFumble,
              damageDealt: event.damageDealt,
              damageType: event.damageType,
              isKillShot: event.isKillShot,
              defenderRemainingHp: event.defenderRemainingHp,
              defenderMaxHp: event.defenderMaxHp,
              summaryText: '[Legendary Action] ${event.summaryText}',
            ),
          );
        }
      }
    }

    return events;
  }

  /// Simulates an entire battle to the end, returning all round steps and final result.
  ArenaSimulationResult simulateMatch({
    required List<ArenaCombatant> initialTeamA,
    required List<ArenaCombatant> initialTeamB,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
    int maxRounds = 50,
  }) {
    // Clone combatants to avoid mutating original presets
    final combatants = [
      ...initialTeamA.map((c) => c.clone()),
      ...initialTeamB.map((c) => c.clone()),
    ];

    // Roll initiatives and sort turn order
    rollInitiatives(combatants);

    final steps = <ArenaTurnStep>[];
    int stepIndex = 0;
    int currentRound = 1;

    while (currentRound <= maxRounds) {
      bool anyActionThisRound = false;

      for (final combatant in combatants) {
        if (combatant.isDefeated) continue;

        // Check victory condition
        final livingA = combatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
        final livingB = combatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;
        if (livingA == 0 || livingB == 0) {
          break;
        }

        final step = executeTurn(
          stepIndex: stepIndex++,
          roundNumber: currentRound,
          attacker: combatant,
          allCombatants: combatants,
          strategy: strategy,
          edition: edition,
          environment: environment,
        );

        steps.add(step);
        anyActionThisRound = true;
      }

      final livingA = combatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
      final livingB = combatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;
      if (livingA == 0 || livingB == 0 || !anyActionThisRound) {
        break;
      }

      currentRound++;
    }

    final teamALiving = combatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
    final teamBLiving = combatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;

    ArenaTeam? winner;
    if (teamALiving > 0 && teamBLiving == 0) {
      winner = ArenaTeam.teamA;
    } else if (teamBLiving > 0 && teamALiving == 0) {
      winner = ArenaTeam.teamB;
    }

    // Calculate MVP (Highest damage + kills)
    ArenaCombatant? mvp;
    int highestScore = -1;
    for (final c in combatants) {
      final score = c.totalDamageDealt + (c.kills * 25);
      if (score > highestScore) {
        highestScore = score;
        mvp = c;
      }
    }

    final teamADamage = combatants
        .where((c) => c.team == ArenaTeam.teamA)
        .fold(0, (sum, c) => sum + c.totalDamageDealt);
    final teamBDamage = combatants
        .where((c) => c.team == ArenaTeam.teamB)
        .fold(0, (sum, c) => sum + c.totalDamageDealt);
    final teamAKills = combatants
        .where((c) => c.team == ArenaTeam.teamA)
        .fold(0, (sum, c) => sum + c.kills);
    final teamBKills = combatants
        .where((c) => c.team == ArenaTeam.teamB)
        .fold(0, (sum, c) => sum + c.kills);

    return ArenaSimulationResult(
      winner: winner,
      totalRounds: currentRound.clamp(1, maxRounds),
      steps: steps,
      finalCombatants: combatants,
      mvpCombatant: mvp,
      teamATotalDamage: teamADamage,
      teamBTotalDamage: teamBDamage,
      teamAKills: teamAKills,
      teamBKills: teamBKills,
    );
  }

  /// High-speed Monte Carlo simulation running [iterations] times to determine exact win rates.
  ArenaMonteCarloResult runMonteCarlo({
    required List<ArenaCombatant> teamA,
    required List<ArenaCombatant> teamB,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
    int iterations = 500,
    int maxRounds = 50,
  }) {
    final stopwatch = Stopwatch()..start();

    int teamAWins = 0;
    int teamBWins = 0;
    int draws = 0;
    int totalRoundsSum = 0;
    int minRounds = 9999;
    int maxRoundsObserved = 0;
    int totalTeamASurvivors = 0;
    int totalTeamBSurvivors = 0;
    double totalTeamAHpPercent = 0.0;
    double totalTeamBHpPercent = 0.0;

    final initialTeamAHpMax = teamA.fold(0, (sum, c) => sum + c.maxHp);
    final initialTeamBHpMax = teamB.fold(0, (sum, c) => sum + c.maxHp);

    for (int i = 0; i < iterations; i++) {
      final res = simulateMatch(
        initialTeamA: teamA,
        initialTeamB: teamB,
        strategy: strategy,
        edition: edition,
        environment: environment,
        maxRounds: maxRounds,
      );

      totalRoundsSum += res.totalRounds;
      if (res.totalRounds < minRounds) minRounds = res.totalRounds;
      if (res.totalRounds > maxRoundsObserved) maxRoundsObserved = res.totalRounds;

      if (res.winner == ArenaTeam.teamA) {
        teamAWins++;
      } else if (res.winner == ArenaTeam.teamB) {
        teamBWins++;
      } else {
        draws++;
      }

      final survivingA = res.survivingTeamA;
      final survivingB = res.survivingTeamB;

      totalTeamASurvivors += survivingA.length;
      totalTeamBSurvivors += survivingB.length;

      final remainingHpA = survivingA.fold(0, (sum, c) => sum + c.currentHp);
      final remainingHpB = survivingB.fold(0, (sum, c) => sum + c.currentHp);

      if (initialTeamAHpMax > 0) {
        totalTeamAHpPercent += (remainingHpA / initialTeamAHpMax);
      }
      if (initialTeamBHpMax > 0) {
        totalTeamBHpPercent += (remainingHpB / initialTeamBHpMax);
      }
    }

    stopwatch.stop();

    return ArenaMonteCarloResult(
      iterations: iterations,
      teamAWins: teamAWins,
      teamBWins: teamBWins,
      draws: draws,
      averageRounds: iterations > 0 ? (totalRoundsSum / iterations) : 0,
      minRounds: minRounds == 9999 ? 0 : minRounds,
      maxRounds: maxRoundsObserved,
      avgTeamASurvivors: iterations > 0 ? (totalTeamASurvivors / iterations) : 0,
      avgTeamBSurvivors: iterations > 0 ? (totalTeamBSurvivors / iterations) : 0,
      avgTeamASurvivingHpPercent: iterations > 0 ? (totalTeamAHpPercent / iterations) * 100 : 0,
      avgTeamBSurvivingHpPercent: iterations > 0 ? (totalTeamBHpPercent / iterations) * 100 : 0,
      calculationDuration: stopwatch.elapsed,
    );
  }

  // --- Internal Dice Helpers ---

  int _rollDie(int sides) {
    if (sides <= 1) return 1;
    return _rng.nextInt(sides) + 1;
  }

  int _rollDice(int count, int sides) {
    if (count <= 0 || sides <= 0) return 0;
    int total = 0;
    for (int i = 0; i < count; i++) {
      total += _rollDie(sides);
    }
    return total;
  }

  String _formatAttackSummary({
    required ArenaCombatant attacker,
    required ArenaCombatant defender,
    required DprAttackAction attack,
    required int naturalRoll,
    required int totalAttack,
    required bool isHit,
    required bool isCrit,
    required bool isFumble,
    required int damageDealt,
    required bool isKillShot,
    bool hadAdvantage = false,
    bool hadDisadvantage = false,
  }) {
    final advTag = hadAdvantage ? ' (Adv)' : (hadDisadvantage ? ' (Disadv)' : '');

    if (isCrit) {
      final killSuffix = isKillShot ? ' — DEFENDING FIGHTER SLAIN!' : '';
      return 'CRITICAL HIT!$advTag (Nat 20) vs AC ${defender.ac} for $damageDealt ${attack.damageType} damage$killSuffix';
    }
    if (isFumble) {
      return 'CRITICAL FUMBLE!$advTag (Nat 1) missed AC ${defender.ac}.';
    }
    if (isHit) {
      final killSuffix = isKillShot ? ' — DEFENDING FIGHTER SLAIN!' : '';
      return 'Hits$advTag (Roll $naturalRoll + ${attack.attackBonus} = $totalAttack vs AC ${defender.ac}) for $damageDealt ${attack.damageType} damage$killSuffix';
    }
    return 'Misses$advTag (Roll $naturalRoll + ${attack.attackBonus} = $totalAttack vs AC ${defender.ac}).';
  }
}
