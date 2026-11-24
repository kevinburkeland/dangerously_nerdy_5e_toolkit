import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/dpr/dpr_models.dart';
import 'arena_attack_resolver.dart';
import 'arena_cantrip_resolver.dart';
import 'arena_combat_context.dart';

/// Resolves off-turn legendary actions in the arena.
class ArenaLegendaryActionResolver {
  final ArenaCombatContext ctx;
  final ArenaAttackResolver _attacks;
  final ArenaCantripResolver _cantrips;

  const ArenaLegendaryActionResolver(this.ctx, this._attacks, this._cantrips);

  List<ArenaAttackEvent> executeOffTurnLegendaryActions({
    required ArenaCombatant turnCombatant,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) {
    final opposingLegendaries = allCombatants
        .where((c) =>
            c.team != turnCombatant.team &&
            c.isAlive &&
            !c.isIncapacitated &&
            c.hasLegendaryActions &&
            c.legendaryActionsRemaining > 0)
        .toList();

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
      final hasDisruptLife = legActions
              .any((a) => a.name.toLowerCase().contains('disrupt life')) ||
          sb.traits
              .any((t) => t.description.toLowerCase().contains('disrupt life'));
      if (hasDisruptLife &&
          legendary.legendaryActionsRemaining >= 3 &&
          livingEnemies.length >= 2) {
        legendary.legendaryActionsRemaining -= 3;
        legendary.attacksMade++;

        for (final enemy in livingEnemies) {
          final d20 = ctx.rollDie(20);
          final saveBonus = enemy.getSavingThrowBonus('con', edition);
          final totalSave = d20 + saveBonus;
          final dc = legendary.spellSaveDc > 10 ? legendary.spellSaveDc : 18;
          final saveRes = ctx.evaluateSaveWithLegendaryResistance(
              defender: enemy, saveRoll: totalSave, saveDc: dc);
          final saved = saveRes.saved;

          final rawDmg = ctx.rollDice(6, 6);
          int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
          damageDealt = ctx.applyDefensiveModifiers(
              damageDealt, 'necrotic', enemy, edition, environment);
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
      final hasParalyzingTouch = legActions
          .any((a) => a.name.toLowerCase().contains('paralyzing touch'));
      if (hasParalyzingTouch && legendary.legendaryActionsRemaining >= 2) {
        final target = ctx.selectTarget(legendary, allCombatants, strategy);
        if (target != null) {
          legendary.legendaryActionsRemaining -= 2;
          legendary.attacksMade++;

          final d20 = ctx.rollDie(20);
          final atkBonus = legendary.spellAttackBonus > 0
              ? legendary.spellAttackBonus
              : sb.attackBonus;
          final totalAttack = d20 + atkBonus;
          final rollOutcome = classifyAttackRoll(
            naturalRoll: d20,
            totalToHit: totalAttack,
            targetAc: target.effectiveAc,
          );
          final isCrit = rollOutcome == AttackOutcomeType.criticalHit;
          final isFumble = rollOutcome == AttackOutcomeType.criticalMiss;
          final isHit = rollOutcome == AttackOutcomeType.hit || isCrit;

          int damageDealt = 0;
          bool isKillShot = false;
          String paralyzeMsg = '';

          if (isHit) {
            legendary.hitsLanded++;
            if (isCrit) legendary.critsLanded++;

            final dice = isCrit ? 6 : 3;
            final rawDmg = ctx.rollDice(dice, 6);
            damageDealt = ctx.applyDefensiveModifiers(
                rawDmg, 'cold', target, edition, environment);
            legendary.totalDamageDealt += damageDealt;
            target.applyDamage(damageDealt);

            if (target.isDefeated) {
              isKillShot = true;
              legendary.kills++;
            } else {
              // Con save vs paralysis
              final saveD20 = ctx.rollDie(20);
              final conBonus = target.getSavingThrowBonus('con', edition);
              final saveTotal = saveD20 + conBonus;
              final dc =
                  legendary.spellSaveDc > 10 ? legendary.spellSaveDc : 18;
              final saveRes = ctx.evaluateSaveWithLegendaryResistance(
                  defender: target, saveRoll: saveTotal, saveDc: dc);
              if (!saveRes.saved) {
                target.applyCondition(
                    ArenaCondition.paralyzed, ctx.rollDie, edition,
                    durationRounds: 10, source: 'Paralyzing Touch');
                paralyzeMsg =
                    ' — FAILED Con Save ($saveTotal vs DC $dc) and is PARALYZED!';
              } else {
                paralyzeMsg =
                    ' — Saved against paralysis ($saveTotal vs DC $dc)${saveRes.summaryNote}.';
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
      final hasCantrip =
          legActions.any((a) => a.name.toLowerCase().contains('cantrip')) ||
              legendary.isSpellcaster;
      if (hasCantrip && legendary.legendaryActionsRemaining >= 1) {
        final cantripEvents = _cantrips.evaluateCantrips(
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
      final dprAttacks = sb
          .extractDprAttacks()
          .where((a) =>
              a.isLegendaryAction ||
              legActions.any(
                  (la) => la.name.toLowerCase().contains(a.name.toLowerCase())))
          .toList();
      if (dprAttacks.isNotEmpty && legendary.legendaryActionsRemaining >= 1) {
        final attack = dprAttacks.first;
        final target = ctx.selectTarget(legendary, allCombatants, strategy, attack);
        if (target != null) {
          legendary.legendaryActionsRemaining -= 1;
          final event = _attacks.resolveSingleAttack(
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
              summaryText: '[Legendary Action] ${event.baseSummaryText}',
              appliedRiderLogs: event.appliedRiderLogs,
            ),
          );
        }
      }
    }

    return events;
  }

  /// Simulates an entire battle to the end, returning all round steps and final result.

}
