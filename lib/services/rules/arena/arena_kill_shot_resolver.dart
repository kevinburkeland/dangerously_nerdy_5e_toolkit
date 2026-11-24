import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import 'arena_combat_context.dart';

/// Resolves Priority 1 guaranteed kill-shot spells in the arena AI.
class ArenaKillShotResolver {
  final ArenaCombatContext ctx;

  const ArenaKillShotResolver(this.ctx);

  List<ArenaAttackEvent>? evaluateKillShot({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> livingEnemies,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    // 1. Power Word Kill (spell_power_word_kill) - Instantly slays target <= 100 HP
    if (attacker.hasSpell('spell_power_word_kill') &&
        ctx.hasSlotFor(attacker, 9)) {
      final killable = livingEnemies.where((e) => e.currentHp <= 100).toList();
      if (killable.isNotEmpty) {
        killable.sort((a, b) => b.maxHp.compareTo(a.maxHp));
        final target = killable.first;
        ctx.deductHighestSlot(attacker, 9);

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
            summaryText:
                'EXECUTION! ${attacker.displayName} uttered Power Word Kill — ${target.displayName} is instantly slain (took $dmg force damage)!',
          ),
        ];
      }
    }

    // 2. Disintegrate (spell_disintegrate) - High force execution against low/moderate HP foes
    if (attacker.hasSpell('spell_disintegrate') && ctx.hasSlotFor(attacker, 6)) {
      final lowHpFoes = livingEnemies.where((e) => e.currentHp <= 75).toList();
      if (lowHpFoes.isNotEmpty) {
        lowHpFoes.sort((a, b) => a.currentHp.compareTo(b.currentHp));
        final target = lowHpFoes.first;
        final slotLvl = ctx.deductHighestSlot(attacker, 6)!;

        attacker.attacksMade++;
        final d20 = ctx.rollDie(20);
        final saveBonus = target.getSavingThrowBonus('dex', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = ctx.evaluateSaveWithLegendaryResistance(
            defender: target,
            saveRoll: totalSave,
            saveDc: attacker.spellSaveDc);
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

        String summary;
        if (saved) {
          summary =
              'Saved (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote} — avoided Disintegrate entirely!';
        } else {
          final fatal = isKillShot ? ' — DISINTEGRATED TO ASH!' : '';
          summary =
              'Failed Save (Rolled $d20 + $saveBonus = $totalSave vs DC ${attacker.spellSaveDc}) took full $damageDealt force damage$fatal';
        }

        // Concentration check on target
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
    }

    // 3. Finger of Death (spell_finger_of_death) - High 7th level necrotic execution
    if (attacker.hasSpell('spell_finger_of_death') &&
        ctx.hasSlotFor(attacker, 7)) {
      final lowHpFoes = livingEnemies.where((e) => e.currentHp <= 65).toList();
      if (lowHpFoes.isNotEmpty) {
        lowHpFoes.sort((a, b) => a.currentHp.compareTo(b.currentHp));
        final target = lowHpFoes.first;
        final slotLvl = ctx.deductHighestSlot(attacker, 7)!;

        attacker.attacksMade++;
        final d20 = ctx.rollDie(20);
        final saveBonus = target.getSavingThrowBonus('con', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = ctx.evaluateSaveWithLegendaryResistance(
            defender: target,
            saveRoll: totalSave,
            saveDc: attacker.spellSaveDc);
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

        final fatal = isKillShot ? ' — SMITTEN WITH NECROTIC DEATH!' : '';
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
    }

    // 4. Blight (spell_blight) - Targeted necrotic execution
    if (attacker.hasSpell('spell_blight') && ctx.hasSlotFor(attacker, 4)) {
      final lowHpFoes = livingEnemies.where((e) => e.currentHp <= 40).toList();
      if (lowHpFoes.isNotEmpty) {
        lowHpFoes.sort((a, b) => a.currentHp.compareTo(b.currentHp));
        final target = lowHpFoes.first;
        final slotLvl = ctx.deductHighestSlot(attacker, 4)!;

        attacker.attacksMade++;
        final d20 = ctx.rollDie(20);
        final saveBonus = target.getSavingThrowBonus('con', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = ctx.evaluateSaveWithLegendaryResistance(
            defender: target,
            saveRoll: totalSave,
            saveDc: attacker.spellSaveDc);
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
    }

    return null;
  }

  /// Priority 2: AoE Clustering Evaluation (DMG p.249 Theater-of-the-Mind with Box-Muller Gaussian clustering)

}
