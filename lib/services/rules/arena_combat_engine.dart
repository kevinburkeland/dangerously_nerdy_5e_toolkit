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
      final isAoE = attack.isAoe ||
          attack.rechargeRoll != null ||
          attack.deliveryType == DprActionDeliveryType.savingThrow ||
          attack.name.toLowerCase().contains('breath') ||
          attack.name.toLowerCase().contains('cone') ||
          attack.name.toLowerCase().contains('burst');

      if (isAoE) {
        // Multi-target Area of Effect resolution
        final aoeEvents = _resolveAoeAttack(
          attacker: attacker,
          attack: attack,
          allCombatants: allCombatants,
          edition: edition,
          environment: environment,
        );
        events.addAll(aoeEvents);
        if (aoeEvents.isNotEmpty && aoeEvents.length > 1) {
          specialSummary = '${attacker.displayName} unleashed ${attack.name} catching ${aoeEvents.length} enemies in the area!';
        }
      } else {
        // Single target attack resolution
        final target = selectTarget(attacker, allCombatants, strategy);
        if (target == null) break; // All enemies defeated!

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

  /// Resolves an Area of Effect (AoE) attack hitting a dynamic number of opponents based on AoE size/shape.
  List<ArenaAttackEvent> _resolveAoeAttack({
    required ArenaCombatant attacker,
    required DprAttackAction attack,
    required List<ArenaCombatant> allCombatants,
    required DmRulesEdition edition,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) {
    final livingEnemies = allCombatants
        .where((c) => c.team != attacker.team && c.isAlive)
        .toList();

    if (livingEnemies.isEmpty) return const [];

    attacker.attacksMade++;

    // Determine number of targets caught based on AoE footprint
    final targetCount = _calculateAoeTargetCount(attack, livingEnemies.length);

    // Pick random subset of living enemies to be caught in the blast
    livingEnemies.shuffle(_rng);
    final caughtDefenders = livingEnemies.take(targetCount).toList();

    // Roll base damage once for the AoE
    final rawDamage = _rollDice(attack.diceCount, attack.diceSides) + attack.damageBonus;
    final saveAbility = attack.saveAbility ?? 'dex';
    final saveDc = attack.saveDc ?? _computeSaveDc(attacker, edition);

    final events = <ArenaAttackEvent>[];

    for (final defender in caughtDefenders) {
      final saveBonus = defender.getSavingThrowBonus(saveAbility, edition);
      final d20 = _rollDie(20);
      final totalSave = d20 + saveBonus;
      final saved = totalSave >= saveDc;

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
      }

      String summary;
      if (evadedWithEvasion) {
        summary = 'EVADED! (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc) took 0 ${attack.damageType} damage via Evasion!';
      } else if (saved) {
        final fatal = isKillShot ? ' — SLAIN!' : '';
        summary = 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc) took half: $effectiveDamage ${attack.damageType} damage$fatal';
      } else {
        final fatal = isKillShot ? ' — SLAIN!' : '';
        summary = 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc) took full: $effectiveDamage ${attack.damageType} damage$fatal';
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
          targetAc: defender.ac,
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

  /// Calculates dynamic AoE target count based on AoE radius/cone/line size.
  int _calculateAoeTargetCount(DprAttackAction attack, int totalEnemies) {
    if (totalEnemies <= 1) return 1;

    final nameLower = attack.name.toLowerCase();
    final isBreath = nameLower.contains('breath');
    int minTargets = 1;
    int maxTargets = 2;

    if (nameLower.contains('60') || nameLower.contains('90') || nameLower.contains('100')) {
      // Large AoE (60ft cone, 100ft line)
      minTargets = 3;
      maxTargets = 6;
    } else if (nameLower.contains('30') || isBreath || nameLower.contains('sphere') || nameLower.contains('cube')) {
      // Medium AoE (30ft cone, breath weapon, 20ft sphere)
      minTargets = 2;
      maxTargets = 4;
    } else if (nameLower.contains('15')) {
      // Small AoE (15ft cone, 10ft radius)
      minTargets = 1;
      maxTargets = 3;
    } else {
      minTargets = 2;
      maxTargets = 4;
    }

    final maxPossible = min(totalEnemies, maxTargets);
    final minPossible = min(totalEnemies, minTargets);

    if (maxPossible <= minPossible) return maxPossible;
    return minPossible + _rng.nextInt(maxPossible - minPossible + 1);
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
  /// factoring in aerial/grounded mobility, underwater rules, and cage constraints.
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

    // Environmental mobility checks
    // 1. In a Cage Match, flight is completely grounded
    final flightEnabled = environment != ArenaEnvironment.cageMatch;
    final attackerFlies = flightEnabled && attacker.canFly(edition);
    final defenderFlies = flightEnabled && defender.canFly(edition);

    final isRangedAttack = attack.name.toLowerCase().contains('bow') ||
        attack.name.toLowerCase().contains('ranged') ||
        attack.name.toLowerCase().contains('javelin') ||
        attack.name.toLowerCase().contains('ray') ||
        attack.name.toLowerCase().contains('sling') ||
        attack.name.toLowerCase().contains('dart') ||
        attack.name.toLowerCase().contains('blast') ||
        attack.name.toLowerCase().contains('bolt');

    bool flightAdvantage = false;
    bool flightDisadvantage = false;

    if (attackerFlies && !defenderFlies && (isRangedAttack || attacker.hasFlyby(edition))) {
      // Flying attacker strafing grounded enemy from safe range/flyby
      flightAdvantage = true;
    } else if (!attackerFlies && defenderFlies && !isRangedAttack) {
      // Grounded attacker attempting to strike a flying creature with standard melee
      flightDisadvantage = true;
    }

    // 2. In Flooded Abyss (Water Match), swimming speed rules apply
    bool aquaticAdvantage = false;
    bool aquaticDisadvantage = false;
    if (environment == ArenaEnvironment.floodedAbyss) {
      final attackerSwims = attacker.canSwim(edition);
      final defenderSwims = defender.canSwim(edition);

      if (attackerSwims && !defenderSwims) {
        // Swimmer attacking clumsy non-swimmer in deep water
        aquaticAdvantage = true;
      } else if (!attackerSwims) {
        // Non-swimmer flailing in water has disadvantage on attacks
        aquaticDisadvantage = true;
      }
    }

    final hasAdvantage = (packTacticsAdvantage || flightAdvantage || aquaticAdvantage) &&
        !flightDisadvantage &&
        !aquaticDisadvantage;
    final hasDisadvantage = (flightDisadvantage || aquaticDisadvantage) &&
        !packTacticsAdvantage &&
        !flightAdvantage &&
        !aquaticAdvantage;

    // Roll d20
    final d20A = _rollDie(20);
    final d20B = (hasAdvantage || hasDisadvantage) ? _rollDie(20) : null;
    int naturalRoll = d20A;
    if (hasAdvantage && d20B != null) naturalRoll = max(d20A, d20B);
    if (hasDisadvantage && d20B != null) naturalRoll = min(d20A, d20B);

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

      // Apply resistances, immunities & environmental modifiers
      damageDealt = _applyDefensiveModifiers(rawDamage, attack.damageType, defender, edition, environment);
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
      hadAdvantage: hasAdvantage,
      hadDisadvantage: hasDisadvantage,
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
