import 'dart:math';

import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/dpr/dpr_models.dart';
import '../../../models/spellbook_data.dart';
import '../../../utils/secure_random.dart';

/// Shared RNG, targeting, slot management, defense, and summary helpers for the arena engine.
class ArenaCombatContext {
  final Random rng;

  ArenaCombatContext({Random? rng}) : rng = rng ?? secureRandom;

  static String formatSaveDamageSummary(
    SaveDamageOutcome outcome,
    bool saved,
    bool hasEvasion,
    int d20,
    int saveBonus,
    int totalSave,
    int saveDc,
    String summaryNote,
    int damageApplied,
    String damageType,
    String fatal, [
    String? evadedSpellName,
  ]) {
    if (outcome == SaveDamageOutcome.none && hasEvasion) {
      return evadedSpellName != null
          ? 'EVADED! $evadedSpellName dealt $damageApplied $damageType damage via Evasion!'
          : 'EVADED! (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc) took $damageApplied $damageType damage via Evasion!';
    }
    if (saved) return 'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc)$summaryNote took half: $damageApplied $damageType damage$fatal';
    if (outcome == SaveDamageOutcome.half && hasEvasion) return 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc) took half: $damageApplied $damageType damage (Evasion)$fatal';
    return 'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC $saveDc) took full: $damageApplied $damageType damage$fatal';
  }

  /// Rolls 1d20 + initiative bonus for each combatant and returns sorted order.
  List<ArenaCombatant> rollInitiatives(
    List<ArenaCombatant> combatants,
  ) {
    for (final c in combatants) {
      final roll = rollDie(20);
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
  bool canReachTarget(ArenaCombatant attacker, ArenaCombatant defender,
      [DprAttackAction? attack]) {
    if (!defender.isAirborne || defender.altitudeInFeet <= 0) {
      return true; // Target is grounded, always reachable
    }

    if (attacker.isAirborne) {
      return true; // Both in flight at aerial combat elevation
    }

    // Attacker is grounded, defender is airborne at altitudeInFeet (e.g. 20 ft)
    if (attack != null) {
      return switch (attack.attackType) {
        AttackType.rangedWeapon || AttackType.rangedSpell => true,
        AttackType.meleeReach =>
          attacker.meleeReachInFeet >= defender.altitudeInFeet ||
              attack.reachInFeet >= defender.altitudeInFeet,
        AttackType.meleeStandard =>
          attacker.meleeReachInFeet >= defender.altitudeInFeet,
      };
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
        ? livingEnemies
            .where((e) => canReachTarget(attacker, e, attack))
            .toList()
        : livingEnemies;
    final candidates =
        reachableEnemies.isNotEmpty ? reachableEnemies : livingEnemies;

    switch (strategy) {
      case ArenaTargetingStrategy.focusLowestHp:
        candidates.sort((a, b) {
          if (a.currentHp != b.currentHp)
            return a.currentHp.compareTo(b.currentHp);
          return a.ac.compareTo(b.ac);
        });
        return candidates.first;

      case ArenaTargetingStrategy.randomEnemy:
        return candidates[rng.nextInt(candidates.length)];

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

  ({bool saved, bool usedLegendaryResistance, String summaryNote})
      evaluateSaveWithLegendaryResistance({
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
      note =
          ' [LEGENDARY RESISTANCE! ${defender.displayName} chose to succeed ($remaining left)]';
    }

    return (
      saved: saved,
      usedLegendaryResistance: usedLegendary,
      summaryNote: note
    );
  }

  int? deductLowestSlot(ArenaCombatant combatant, int minLevel) {
    for (int lvl = minLevel; lvl <= 9; lvl++) {
      final count = combatant.currentSpellSlots[lvl] ?? 0;
      if (count > 0) {
        combatant.setSpellSlot(lvl, count - 1);
        return lvl;
      }
    }
    return null;
  }

  int? deductHighestSlot(ArenaCombatant combatant, int minLevel) {
    for (int lvl = 9; lvl >= minLevel; lvl--) {
      final count = combatant.currentSpellSlots[lvl] ?? 0;
      if (count > 0) {
        combatant.setSpellSlot(lvl, count - 1);
        return lvl;
      }
    }
    return null;
  }

  bool hasSlotFor(ArenaCombatant combatant, int minLevel) {
    for (int lvl = minLevel; lvl <= 9; lvl++) {
      if ((combatant.currentSpellSlots[lvl] ?? 0) > 0) return true;
    }
    return false;
  }

  int getCantripDiceMultiplier(ArenaCombatant caster) {
    final cr = caster.monster.challengeRating;
    if (cr >= 17) return 4;
    if (cr >= 11) return 3;
    if (cr >= 5) return 2;
    return 1;
  }

  String getSpellDisplayName(String? spellId) {
    if (spellId == null) return 'Spell';
    final spell = SpellbookLibrary.getSpellById(spellId);
    if (spell != null) return spell.name;
    return spellId
        .replaceAll('spell_', '')
        .split('_')
        .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  /// Determines which attacks the monster uses during their action turn.

  ({
    int d20,
    int totalAttack,
    bool isHit,
    bool isCrit,
    bool isFumble,
    bool shielded,
  }) rollSpellAttackWithShield(
    ArenaCombatant attacker,
    ArenaCombatant target,
  ) {
    final d20 = rollDie(20);
    final totalAttack = d20 + attacker.spellAttackBonus;
    final rollOutcome = classifyAttackRoll(
      naturalRoll: d20,
      totalToHit: totalAttack,
      targetAc: target.effectiveAc,
    );
    final isCrit = rollOutcome == AttackOutcomeType.criticalHit;
    final isFumble = rollOutcome == AttackOutcomeType.criticalMiss;
    var isHit = rollOutcome == AttackOutcomeType.hit || isCrit;
    var shielded = false;
    if (isHit &&
        !target.usedReactionThisRound &&
        target.hasSpell('spell_shield') &&
        target.hasAvailableSlots &&
        doesShieldBlockAttack(
          totalToHit: totalAttack,
          targetAc: target.effectiveAc,
          isCriticalHit: isCrit,
        )) {
      deductLowestSlot(target, 1);
      target.usedReactionThisRound = true;
      target.temporaryAcBonus += 5;
      shielded = true;
      isHit = false;
    }
    return (
      d20: d20,
      totalAttack: totalAttack,
      isHit: isHit,
      isCrit: isCrit,
      isFumble: isFumble,
      shielded: shielded,
    );
  }

  /// Default DC calculation when not explicit (8 + proficiency + ability modifier).
  int computeDefaultSaveDc(ArenaCombatant attacker, DmRulesEdition edition) {
    final rawPb = proficiencyBonusForChallengeRating(
      attacker.monster.challengeRating,
    );
    final pb = rawPb > 6 ? 6 : rawPb;
    final sb = attacker.getStatBlock(edition);
    final mod = max(sb.conMod, max(sb.strMod, sb.chaMod));
    return computeSaveDc(proficiencyBonus: pb, abilityModifier: mod);
  }

  /// Resolves an individual single-target attack roll vs defender's AC,
  /// factoring in aerial/grounded mobility, underwater rules, cage constraints,
  /// Shield reactions, conditions, and concentration checks.

  int applyDefensiveModifiers(
    int rawDamage,
    String damageType,
    ArenaCombatant defender,
    DmRulesEdition edition, [
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  ]) {
    final sb = defender.getStatBlock(edition);
    final dmgLower = damageType.toLowerCase().trim();
    final defenses = DamageDefenses.fromStatBlockText(
      immunities: sb.damageImmunities,
      resistances: sb.damageResistances,
      vulnerabilities: sb.damageVulnerabilities,
    );

    final immune = defenses.isImmune(dmgLower);
    var resistant = defenses.isResistant(dmgLower);
    if (environment == ArenaEnvironment.floodedAbyss && dmgLower == 'fire') {
      resistant = true;
    }
    final vulnerable = defenses.isVulnerable(dmgLower);

    return adjustDamageForDefenses(
      rawDamage,
      immune: immune,
      resistant: resistant,
      vulnerable: vulnerable,
    );
  }

  /// Evaluates and executes off-turn Legendary Actions for living opposing legendary combatants
  /// at the end of another creature's turn.

  int rollDie(int sides) {
    if (sides <= 1) return 1;
    return rng.nextInt(sides) + 1;
  }

  int rollDice(int count, int sides) {
    if (count <= 0 || sides <= 0) return 0;
    int total = 0;
    for (int i = 0; i < count; i++) {
      total += rollDie(sides);
    }
    return total;
  }

  String formatAttackSummary({
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
    final advTag =
        hadAdvantage ? ' (Adv)' : (hadDisadvantage ? ' (Disadv)' : '');

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
