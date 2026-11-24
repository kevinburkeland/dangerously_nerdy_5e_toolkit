import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import 'arena_combat_context.dart';

/// Resolves Priority 5 cantrip fallback spells (Eldritch Blast, Fire Bolt, Sacred Flame, Ray of Frost).
class ArenaCantripResolver {
  final ArenaCombatContext ctx;

  const ArenaCantripResolver(this.ctx);

  List<ArenaAttackEvent>? evaluateCantrips({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    final target = ctx.selectTarget(attacker, allCombatants, strategy);
    if (target == null) return null;

    final multiplier = ctx.getCantripDiceMultiplier(attacker);

    // 1. Eldritch Blast (spell_eldritch_blast) - multiple beams
    if (attacker.hasSpell('spell_eldritch_blast')) {
      final events = <ArenaAttackEvent>[];
      for (int i = 0; i < multiplier; i++) {
        if (target.isDefeated) break;
        attacker.attacksMade++;

        final (:d20, :totalAttack, :isHit, :isCrit, :isFumble, :shielded) =
            ctx.rollSpellAttackWithShield(attacker, target);

        int damageDealt = 0;
        bool isKillShot = false;

        if (isHit) {
          attacker.hitsLanded++;
          if (isCrit) attacker.critsLanded++;

          final dice = isCrit ? 2 : 1;
          final rawDmg = ctx.rollDice(dice, 10);
          damageDealt = ctx.applyDefensiveModifiers(
              rawDmg, 'force', target, edition, environment);
          attacker.totalDamageDealt += damageDealt;
          target.applyDamage(damageDealt);

          if (target.isDefeated) {
            isKillShot = true;
            attacker.kills++;
          }
        }

        String summary;
        if (shielded) {
          summary =
              'PARRIED BY SHIELD! ${target.displayName} deflected Eldritch Blast Beam # ${i + 1} ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
        } else if (isCrit) {
          final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
          summary =
              'CRITICAL HIT! (Nat 20) Eldritch Blast Beam # ${i + 1} dealt $damageDealt force damage$fatal';
        } else if (isHit) {
          final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
          summary =
              'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt force damage$fatal';
        } else {
          summary =
              'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
        }

        if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
          final conRes =
              target.checkConcentration(damageDealt, ctx.rollDie, edition);
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
      final (:d20, :totalAttack, :isHit, :isCrit, :isFumble, :shielded) =
          ctx.rollSpellAttackWithShield(attacker, target);

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final dice = isCrit ? multiplier * 2 : multiplier;
        final rawDmg = ctx.rollDice(dice, 10);
        damageDealt = ctx.applyDefensiveModifiers(
            rawDmg, 'fire', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      String summary;
      if (shielded) {
        summary =
            'PARRIED BY SHIELD! ${target.displayName} cast Shield deflecting Fire Bolt ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary =
            'CRITICAL HIT! (Nat 20) Fire Bolt dealt $damageDealt fire damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary =
            'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt fire damage$fatal';
      } else {
        summary =
            'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
      }

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes =
            target.checkConcentration(damageDealt, ctx.rollDie, edition);
        if (conRes.broken) {
          final lostName = ctx.getSpellDisplayName(conRes.lostSpellId);
          summary +=
              ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
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

    // 4. Ray of Frost (spell_ray_of_frost) or generic spellcaster Ray of Frost
    if (attacker.hasSpell('spell_ray_of_frost') ||
        (attacker.isSpellcaster && !attacker.hasSpell('spell_sacred_flame'))) {
      attacker.attacksMade++;
      final (:d20, :totalAttack, :isHit, :isCrit, :isFumble, :shielded) =
          ctx.rollSpellAttackWithShield(attacker, target);

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final dice = isCrit ? multiplier * 2 : multiplier;
        final rawDmg = ctx.rollDice(dice, 8);
        damageDealt = ctx.applyDefensiveModifiers(
            rawDmg, 'cold', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      }

      String summary;
      if (shielded) {
        summary =
            'PARRIED BY SHIELD! ${target.displayName} deflected Ray of Frost ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — FROZEN & SLAIN!' : '';
        summary =
            'CRITICAL HIT! (Nat 20) Ray of Frost dealt $damageDealt cold damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — FROZEN & SLAIN!' : '';
        summary =
            'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt cold damage$fatal';
      } else {
        summary =
            'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}).';
      }

      if (damageDealt > 0 && target.activeConcentrationSpellId != null) {
        final conRes =
            target.checkConcentration(damageDealt, ctx.rollDie, edition);
        if (conRes.broken) {
          final lostName = ctx.getSpellDisplayName(conRes.lostSpellId);
          summary +=
              ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
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
      final d20 = ctx.rollDie(20);
      final saveBonus = target.getSavingThrowBonus('dex', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = ctx.evaluateSaveWithLegendaryResistance(
          defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      int damageDealt = 0;
      bool isKillShot = false;

      if (!saved) {
        attacker.hitsLanded++;
        final rawDmg = ctx.rollDice(multiplier, 8);
        damageDealt = ctx.applyDefensiveModifiers(
            rawDmg, 'radiant', target, edition, environment);
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
        final conRes =
            target.checkConcentration(damageDealt, ctx.rollDie, edition);
        if (conRes.broken) {
          final lostName = ctx.getSpellDisplayName(conRes.lostSpellId);
          summary +=
              ' [Concentration on $lostName broken! (CON save ${conRes.saveRoll} vs DC ${conRes.dc})]';
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

}
