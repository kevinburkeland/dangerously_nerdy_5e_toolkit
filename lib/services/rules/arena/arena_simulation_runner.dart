import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/dpr/dpr_models.dart';
import 'arena_attack_resolver.dart';
import 'arena_cantrip_resolver.dart';
import 'arena_challenge_rating_validator.dart';
import 'arena_combat_context.dart';
import 'arena_legendary_action_resolver.dart';
import 'arena_spellcasting_ai.dart';

/// Executes turns, full arena matches, and synchronous Monte Carlo batches.
class ArenaSimulationRunner {
  final ArenaCombatContext ctx;
  final ArenaSpellcastingAi _spellcastingAi;
  final ArenaAttackResolver _attacks;
  final ArenaLegendaryActionResolver _legendary;

  ArenaSimulationRunner(this.ctx)
      : _spellcastingAi = ArenaSpellcastingAi(ctx),
        _attacks = ArenaAttackResolver(ctx),
        _legendary = ArenaLegendaryActionResolver(
          ctx,
          ArenaAttackResolver(ctx),
          ArenaCantripResolver(ctx),
        );

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
        specialEventSummary:
            '${attacker.displayName} is defeated and skips their turn.',
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
      final rechargeD6 = ctx.rollDie(6);
      final rechargeThreshold =
          attacks.firstWhere((a) => a.rechargeRoll != null).rechargeRoll ?? 5;
      if (rechargeD6 >= rechargeThreshold) {
        attacker.isRechargeReady = true;
        specialSummary =
            '${attacker.displayName} recharged their special ability (Rolled $rechargeD6 on d6)!';
      }
    }

    // 2. Tactical AI Spellcasting Evaluator (Priority tree prior to physical attacks)
    if (attacker.isSpellcaster) {
      final spellResult = _spellcastingAi.evaluateTacticalSpellcasting(
        attacker: attacker,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );

      if (spellResult != null &&
          (spellResult.events.isNotEmpty ||
              spellResult.specialSummary != null)) {
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
            final expireMsg =
                '${attacker.displayName} is no longer ${expired.map((c) => c.label).join(", ")}.';
            specialSummary = specialSummary != null
                ? '$specialSummary\n$expireMsg'
                : expireMsg;
          }

          // Off-turn Legendary Actions of opposing living legendary creatures
          final legEvents = _legendary.executeOffTurnLegendaryActions(
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
            combatantHpSnapshot: {
              for (final c in allCombatants) c.id: c.currentHp
            },
          );
        }
      }
    }

    // 3. Physical Attack Routine (Fallback if no offensive spell was cast)
    final actionsToExecute =
        _attacks.selectAttacksForTurn(attacker, attacks, sb, environment: environment);

    for (final attack in actionsToExecute) {
      final isAoE = attack.isAoe ||
          attack.rechargeRoll != null ||
          attack.deliveryType == DprActionDeliveryType.savingThrow ||
          attack.name.toLowerCase().contains('breath') ||
          attack.name.toLowerCase().contains('cone') ||
          attack.name.toLowerCase().contains('burst');

      if (isAoE) {
        // Multi-target Area of Effect resolution using DMG p.249 Theater-of-the-Mind
        final aoeEvents = _attacks.resolveAoeAttack(
          attacker: attacker,
          attack: attack,
          allCombatants: allCombatants,
          strategy: strategy,
          edition: edition,
          environment: environment,
        );
        events.addAll(aoeEvents);
        if (aoeEvents.isNotEmpty && aoeEvents.length > 1) {
          final aoeNote =
              '${attacker.displayName} unleashed ${attack.name} catching ${aoeEvents.length} enemies in the area!';
          specialSummary =
              specialSummary != null ? '$specialSummary\n$aoeNote' : aoeNote;
        }
      } else {
        // Single target attack resolution with reach and aerial flight validation
        final target = ctx.selectTarget(attacker, allCombatants, strategy, attack);
        if (target == null) break; // All enemies defeated!

        // Reach Validation: If grounded attacker with standard melee cannot reach airborne target
        if (target.isAirborne &&
            !attacker.isAirborne &&
            attack.attackType == AttackType.meleeStandard &&
            attacker.meleeReachInFeet < target.altitudeInFeet) {
          // Check for fallback ranged attack
          final rangedFallback = attacks
              .where((a) =>
                  a.attackType == AttackType.rangedWeapon ||
                  a.attackType == AttackType.rangedSpell)
              .firstOrNull;
          if (rangedFallback != null) {
            final event = _attacks.resolveSingleAttack(
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
            final passNote =
                '${attacker.displayName} cannot reach airborne ${target.displayName} (${target.altitudeInFeet} ft. altitude) with melee reach (${attacker.meleeReachInFeet} ft.) and takes the Dodge action.';
            specialSummary = specialSummary != null
                ? '$specialSummary\n$passNote'
                : passNote;
          }
          continue;
        }

        final event = _attacks.resolveSingleAttack(
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
      final expireMsg =
          '${attacker.displayName} is no longer ${expired.map((c) => c.label).join(", ")}.';
      specialSummary =
          specialSummary != null ? '$specialSummary\n$expireMsg' : expireMsg;
    }

    // 5. Off-turn Legendary Actions of opposing living legendary creatures
    final legEvents = _legendary.executeOffTurnLegendaryActions(
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


  ArenaSimulationResult simulateMatch({
    required List<ArenaCombatant> initialTeamA,
    required List<ArenaCombatant> initialTeamB,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
    int maxRounds = 50,
  }) {
    validateArenaCombatantsChallengeRatings([...initialTeamA, ...initialTeamB]);
    // Clone combatants to avoid mutating original presets
    final combatants = [
      ...initialTeamA.map((c) => c.clone()),
      ...initialTeamB.map((c) => c.clone()),
    ];

    // Roll initiatives and sort turn order
    ctx.rollInitiatives(combatants);

    final steps = <ArenaTurnStep>[];
    int stepIndex = 0;
    int currentRound = 1;

    while (currentRound <= maxRounds) {
      bool anyActionThisRound = false;

      for (final combatant in combatants) {
        if (combatant.isDefeated) continue;

        // Check victory condition
        final livingA = combatants
            .where((c) => c.team == ArenaTeam.teamA && c.isAlive)
            .length;
        final livingB = combatants
            .where((c) => c.team == ArenaTeam.teamB && c.isAlive)
            .length;
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

      final livingA = combatants
          .where((c) => c.team == ArenaTeam.teamA && c.isAlive)
          .length;
      final livingB = combatants
          .where((c) => c.team == ArenaTeam.teamB && c.isAlive)
          .length;
      if (livingA == 0 || livingB == 0 || !anyActionThisRound) {
        break;
      }

      currentRound++;
    }

    final teamALiving =
        combatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
    final teamBLiving =
        combatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;

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
    validateArenaCombatantsChallengeRatings([...teamA, ...teamB]);
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
      if (res.totalRounds > maxRoundsObserved)
        maxRoundsObserved = res.totalRounds;

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
      avgTeamASurvivors:
          iterations > 0 ? (totalTeamASurvivors / iterations) : 0,
      avgTeamBSurvivors:
          iterations > 0 ? (totalTeamBSurvivors / iterations) : 0,
      avgTeamASurvivingHpPercent:
          iterations > 0 ? (totalTeamAHpPercent / iterations) * 100 : 0,
      avgTeamBSurvivingHpPercent:
          iterations > 0 ? (totalTeamBHpPercent / iterations) * 100 : 0,
      calculationDuration: stopwatch.elapsed,
    );
  }

  /// Background isolate runner for Monte Carlo simulation.

}
