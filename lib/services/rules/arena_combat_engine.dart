import 'dart:math';
import '../../models/arena/arena_action_result.dart';
import '../../models/arena/arena_combatant.dart';
import '../../models/arena/arena_simulation_models.dart';
import '../../models/dm_screen_data.dart';
import '../../models/dpr/dpr_models.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../../utils/secure_random.dart';

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

  /// Selects the best target for an attacker based on chosen [ArenaTargetingStrategy].
  ArenaCombatant? selectTarget(
    ArenaCombatant attacker,
    List<ArenaCombatant> allCombatants,
    ArenaTargetingStrategy strategy,
  ) {
    final livingEnemies = allCombatants
        .where((c) => c.team != attacker.team && c.isAlive)
        .toList();

    if (livingEnemies.isEmpty) return null;

    switch (strategy) {
      case ArenaTargetingStrategy.focusLowestHp:
        livingEnemies.sort((a, b) {
          if (a.currentHp != b.currentHp) return a.currentHp.compareTo(b.currentHp);
          return a.ac.compareTo(b.ac);
        });
        return livingEnemies.first;

      case ArenaTargetingStrategy.randomEnemy:
        return livingEnemies[_rng.nextInt(livingEnemies.length)];

      case ArenaTargetingStrategy.highestThreat:
        livingEnemies.sort((a, b) {
          final crA = a.monster.challengeRating;
          final crB = b.monster.challengeRating;
          if (crA != crB) return crB.compareTo(crA);
          return b.maxHp.compareTo(a.maxHp);
        });
        return livingEnemies.first;
    }
  }

  /// Executes a single combatant's turn, including recharge rolls, target selection,
  /// multiattack sequencing, roll resolution, and damage application.
  ArenaTurnStep executeTurn({
    required int stepIndex,
    required int roundNumber,
    required ArenaCombatant attacker,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    DmRulesEdition edition = DmRulesEdition.v2024,
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

    // 2. Select actions to execute this turn
    final actionsToExecute = _selectAttacksForTurn(attacker, attacks, sb);

    // 3. Resolve each attack against targets
    for (final attack in actionsToExecute) {
      // Find active target (if previous target was killed, re-acquire target)
      final target = selectTarget(attacker, allCombatants, strategy);
      if (target == null) break; // All enemies defeated!

      final event = _resolveSingleAttack(
        attacker: attacker,
        defender: target,
        attack: attack,
        allCombatants: allCombatants,
        edition: edition,
      );

      events.add(event);
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

  /// Determines which attacks the monster uses during their action turn.
  List<DprAttackAction> _selectAttacksForTurn(
    ArenaCombatant attacker,
    List<DprAttackAction> allAttacks,
    MinionStatBlock sb,
  ) {
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

    // Check if recharge attack is ready and available
    final rechargeAttack = allAttacks.where((a) => a.rechargeRoll != null).firstOrNull;
    if (rechargeAttack != null && attacker.isRechargeReady) {
      attacker.isRechargeReady = false;
      return [rechargeAttack];
    }

    // Standard turn multiattacks (excluding legendary action standalone triggers)
    final standardAttacks = allAttacks.where((a) => !a.isLegendaryAction && a.rechargeRoll == null).toList();
    if (standardAttacks.isEmpty) return allAttacks.take(1).toList();

    final result = <DprAttackAction>[];
    for (final atk in standardAttacks) {
      final count = atk.attacksPerRound > 0 ? atk.attacksPerRound : 1;
      for (int i = 0; i < count; i++) {
        result.add(atk.copyWith(attacksPerRound: 1));
      }
    }
    return result;
  }

  /// Resolves an individual attack roll vs defender's AC.
  ArenaAttackEvent _resolveSingleAttack({
    required ArenaCombatant attacker,
    required ArenaCombatant defender,
    required DprAttackAction attack,
    required List<ArenaCombatant> allCombatants,
    required DmRulesEdition edition,
  }) {
    attacker.attacksMade++;

    // Check advantage (e.g. Pack Tactics: if another living ally is active)
    final hasPackTactics = attacker.getStatBlock(edition).hasPackTactics;
    final otherAllyPresent = allCombatants.any(
      (c) => c.team == attacker.team && c.id != attacker.id && c.isAlive,
    );
    final hasAdvantage = hasPackTactics && otherAllyPresent;

    // Roll d20
    final d20A = _rollDie(20);
    final d20B = hasAdvantage ? _rollDie(20) : null;
    final naturalRoll = hasAdvantage ? max(d20A, d20B!) : d20A;

    final isCrit = naturalRoll == 20;
    final isFumble = naturalRoll == 1;
    final totalAttack = naturalRoll + attack.attackBonus;
    final isHit = isCrit || (!isFumble && totalAttack >= defender.ac);

    int damageDealt = 0;
    bool isKillShot = false;

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

      // Apply resistances & immunities
      damageDealt = _applyDefensiveModifiers(rawDamage, attack.damageType, defender, edition);
      attacker.totalDamageDealt += damageDealt;
      defender.applyDamage(damageDealt);

      if (defender.isDefeated) {
        isKillShot = true;
        attacker.kills++;
      }
    }

    final summary = _formatAttackSummary(
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
    );

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
      targetAc: defender.ac,
      isHit: isHit,
      isCrit: isCrit,
      isFumble: isFumble,
      hadAdvantage: hasAdvantage,
      damageDealt: damageDealt,
      damageType: attack.damageType,
      isKillShot: isKillShot,
      defenderRemainingHp: defender.currentHp,
      defenderMaxHp: defender.maxHp,
      summaryText: summary,
    );
  }

  /// Evaluates damage resistance, immunity, or vulnerability.
  int _applyDefensiveModifiers(
    int rawDamage,
    String damageType,
    ArenaCombatant defender,
    DmRulesEdition edition,
  ) {
    if (rawDamage <= 0) return 0;
    final sb = defender.getStatBlock(edition);
    final dt = damageType.toLowerCase().trim();

    // Damage Immunity check
    final immunities = sb.damageImmunities?.toLowerCase() ?? '';
    if (immunities.contains(dt) && dt.isNotEmpty) {
      return 0;
    }

    // Damage Resistance check (half damage)
    final resistances = sb.damageResistances?.toLowerCase() ?? '';
    if (resistances.contains(dt) && dt.isNotEmpty) {
      return (rawDamage / 2).floor();
    }

    // Damage Vulnerability check (double damage)
    final vulnerabilities = sb.damageVulnerabilities?.toLowerCase() ?? '';
    if (vulnerabilities.contains(dt) && dt.isNotEmpty) {
      return rawDamage * 2;
    }

    return rawDamage;
  }

  /// Simulates a complete battle from start to finish.
  ArenaSimulationResult simulateMatch({
    required List<ArenaCombatant> initialTeamA,
    required List<ArenaCombatant> initialTeamB,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    int maxRounds = 50,
  }) {
    // Clone combatants so originals are not mutated
    final combatants = [
      ...initialTeamA.map((c) => c.reset()),
      ...initialTeamB.map((c) => c.reset()),
    ];

    rollInitiatives(combatants);

    final steps = <ArenaTurnStep>[];
    int currentRound = 1;
    int stepCounter = 0;

    while (currentRound <= maxRounds) {
      bool anyActionThisRound = false;

      for (final combatant in combatants) {
        if (!combatant.isAlive) continue;

        // Check if opposing team is already fully defeated
        final hasLivingEnemies = combatants.any(
          (c) => c.team != combatant.team && c.isAlive,
        );
        if (!hasLivingEnemies) break;

        final step = executeTurn(
          stepIndex: stepCounter++,
          roundNumber: currentRound,
          attacker: combatant,
          allCombatants: combatants,
          strategy: strategy,
          edition: edition,
        );

        steps.add(step);
        anyActionThisRound = true;

        // Check if victory condition reached right after this turn
        final livingA = combatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
        final livingB = combatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;
        if (livingA == 0 || livingB == 0) break;
      }

      final livingTeamA = combatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
      final livingTeamB = combatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;

      if (livingTeamA == 0 || livingTeamB == 0 || !anyActionThisRound) {
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
  }) {
    if (isCrit) {
      final killSuffix = isKillShot ? ' — DEFENDING FIGHTER SLAIN!' : '';
      return 'CRITICAL HIT! (Nat 20) vs AC ${defender.ac} for $damageDealt ${attack.damageType} damage$killSuffix';
    }
    if (isFumble) {
      return 'CRITICAL FUMBLE! (Nat 1) missed AC ${defender.ac}.';
    }
    if (isHit) {
      final killSuffix = isKillShot ? ' — DEFENDING FIGHTER SLAIN!' : '';
      return 'Hits (Roll $naturalRoll + ${attack.attackBonus} = $totalAttack vs AC ${defender.ac}) for $damageDealt ${attack.damageType} damage$killSuffix';
    }
    return 'Misses (Roll $naturalRoll + ${attack.attackBonus} = $totalAttack vs AC ${defender.ac}).';
  }
}
