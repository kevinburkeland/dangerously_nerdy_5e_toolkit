import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import 'arena_combat_context.dart';

/// Resolves high-level single-target burst spells (Finger of Death, Harm, Disintegrate, Blight, Scorching Ray).
class ArenaHighLevelBurstResolver {
  final ArenaCombatContext ctx;

  const ArenaHighLevelBurstResolver(this.ctx);

  List<ArenaAttackEvent>? evaluateHighLevelBurst({
    required ArenaCombatant attacker,
    required ArenaCombatant target,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    // 1. Finger of Death (spell_finger_of_death, Level 7)
    if (attacker.hasSpell('spell_finger_of_death') &&
        ctx.hasSlotFor(attacker, 7)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 7)!;
      attacker.attacksMade++;

      final d20 = ctx.rollDie(20);
      final saveBonus = target.getSavingThrowBonus('con', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = ctx.evaluateSaveWithLegendaryResistance(
          defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final rawDmg = ctx.rollDice(7, 8) + 30;
      int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
      damageDealt = ctx.applyDefensiveModifiers(
          damageDealt, 'necrotic', target, edition, environment);
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
    if (attacker.hasSpell('spell_harm') && ctx.hasSlotFor(attacker, 6)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 6)!;
      attacker.attacksMade++;

      final d20 = ctx.rollDie(20);
      final saveBonus = target.getSavingThrowBonus('con', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = ctx.evaluateSaveWithLegendaryResistance(
          defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final rawDmg = ctx.rollDice(14, 6);
      int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
      damageDealt = ctx.applyDefensiveModifiers(
          damageDealt, 'necrotic', target, edition, environment);
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
    if (attacker.hasSpell('spell_disintegrate') && ctx.hasSlotFor(attacker, 6)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 6)!;
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
        final extraDice = (slotLvl - 6) * 3;
        final rawDmg = ctx.rollDice(10 + extraDice, 6) + 40;
        damageDealt = ctx.applyDefensiveModifiers(
            rawDmg, 'force', target, edition, environment);
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
    if (attacker.hasSpell('spell_blight') && ctx.hasSlotFor(attacker, 4)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 4)!;
      attacker.attacksMade++;

      final d20 = ctx.rollDie(20);
      final saveBonus = target.getSavingThrowBonus('con', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = ctx.evaluateSaveWithLegendaryResistance(
          defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final rawDmg = ctx.rollDice(8 + (slotLvl - 4), 8);
      int damageDealt = saved ? (rawDmg / 2).floor() : rawDmg;
      damageDealt = ctx.applyDefensiveModifiers(
          damageDealt, 'necrotic', target, edition, environment);
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
    if (attacker.hasSpell('spell_scorching_ray') && ctx.hasSlotFor(attacker, 2)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 2)!;
      final rayCount = 3 + (slotLvl - 2);
      final events = <ArenaAttackEvent>[];

      for (int i = 0; i < rayCount; i++) {
        if (target.isDefeated) break;
        attacker.attacksMade++;

        final (:d20, :totalAttack, :isHit, :isCrit, :isFumble, :shielded) =
            ctx.rollSpellAttackWithShield(attacker, target);

        int damageDealt = 0;
        bool isKillShot = false;

        if (isHit) {
          attacker.hitsLanded++;
          if (isCrit) attacker.critsLanded++;

          final dice = isCrit ? 4 : 2;
          final rawDmg = ctx.rollDice(dice, 6);
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
              'PARRIED BY SHIELD! ${target.displayName} cast Shield (+5 AC) deflecting Scorching Ray # ${i + 1} ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
        } else if (isCrit) {
          final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
          summary =
              'CRITICAL HIT! (Nat 20) Scorching Ray # ${i + 1} dealt $damageDealt fire damage$fatal';
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


    return null;
  }
}
