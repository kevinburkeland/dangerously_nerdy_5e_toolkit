import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import 'arena_combat_context.dart';

/// Resolves low-level single-target burst spells (Magic Missile, Guiding Bolt, Inflict Wounds, Acid Arrow, AoE fallback).
class ArenaLowLevelBurstResolver {
  final ArenaCombatContext ctx;

  const ArenaLowLevelBurstResolver(this.ctx);

  List<ArenaAttackEvent>? evaluateLowLevelBurst({
    required ArenaCombatant attacker,
    required ArenaCombatant target,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    // 3. Magic Missile (spell_magic_missile, Level 1)
    if (attacker.hasSpell('spell_magic_missile') && ctx.hasSlotFor(attacker, 1)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 1)!;
      final dartCount = 3 + (slotLvl - 1);
      attacker.attacksMade++;
      attacker.hitsLanded++;

      // In 5e RAW Shield negates Magic Missile entirely
      if (!target.usedReactionThisRound &&
          target.hasSpell('spell_shield') &&
          target.hasAvailableSlots) {
        ctx.deductLowestSlot(target, 1);
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
            summaryText:
                'SHIELD INTERCEPT! ${target.displayName} cast Shield as a reaction, completely neutralizing all $dartCount Magic Missile darts!',
          ),
        ];
      }

      final rawDmg = ctx.rollDice(dartCount, 4) + dartCount;
      final damageDealt = ctx.applyDefensiveModifiers(
          rawDmg, 'force', target, edition, environment);
      attacker.totalDamageDealt += damageDealt;
      target.applyDamage(damageDealt);

      bool isKillShot = false;
      if (target.isDefeated) {
        isKillShot = true;
        attacker.kills++;
      }

      final fatal = isKillShot ? ' — STRUCK DOWN BY FORCE DARTS!' : '';
      String summary =
          '$dartCount Magic Missiles automatically struck ${target.displayName} for $damageDealt force damage$fatal';

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
    if (attacker.hasSpell('spell_guiding_bolt') && ctx.hasSlotFor(attacker, 1)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 1)!;
      attacker.attacksMade++;

      final (:d20, :totalAttack, :isHit, :isCrit, :isFumble, :shielded) =
          ctx.rollSpellAttackWithShield(attacker, target);

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final dice = isCrit ? (4 + (slotLvl - 1)) * 2 : (4 + (slotLvl - 1));
        final rawDmg = ctx.rollDice(dice, 6);
        damageDealt = ctx.applyDefensiveModifiers(
            rawDmg, 'radiant', target, edition, environment);
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
            'PARRIED BY SHIELD! ${target.displayName} cast Shield deflecting Guiding Bolt ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary =
            'CRITICAL HIT! (Nat 20) Guiding Bolt dealt $damageDealt radiant damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary =
            'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt radiant damage$fatal';
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
    if (attacker.hasSpell('spell_inflict_wounds') && ctx.hasSlotFor(attacker, 1)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 1)!;
      attacker.attacksMade++;

      final (:d20, :totalAttack, :isHit, :isCrit, :isFumble, :shielded) =
          ctx.rollSpellAttackWithShield(attacker, target);

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final dice = isCrit ? (3 + (slotLvl - 1)) * 2 : (3 + (slotLvl - 1));
        final rawDmg = ctx.rollDice(dice, 10);
        damageDealt = ctx.applyDefensiveModifiers(
            rawDmg, 'necrotic', target, edition, environment);
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
            'PARRIED BY SHIELD! ${target.displayName} cast Shield deflecting Inflict Wounds ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary =
            'CRITICAL HIT! (Nat 20) Inflict Wounds dealt $damageDealt necrotic damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary =
            'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt necrotic damage$fatal';
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

    // 6. Acid Arrow (spell_acid_arrow, Level 2)
    if (attacker.hasSpell('spell_acid_arrow') && ctx.hasSlotFor(attacker, 2)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 2)!;
      attacker.attacksMade++;

      final (:d20, :totalAttack, :isHit, :isCrit, :isFumble, :shielded) =
          ctx.rollSpellAttackWithShield(attacker, target);

      int damageDealt = 0;
      bool isKillShot = false;

      if (isHit) {
        attacker.hitsLanded++;
        if (isCrit) attacker.critsLanded++;

        final baseDice = 4 + (slotLvl - 2);
        final dice = isCrit ? (baseDice * 2) : baseDice;
        // 4d4 initial acid (+ 2d4 secondary)
        final rawDmg = ctx.rollDice(dice, 4) + ctx.rollDice(2, 4);
        damageDealt = ctx.applyDefensiveModifiers(
            rawDmg, 'acid', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);

        if (target.isDefeated) {
          isKillShot = true;
          attacker.kills++;
        }
      } else if (!shielded) {
        // Miss: takes half the initial 4d4 acid damage
        final rawDmg = (ctx.rollDice(4, 4) / 2).floor();
        damageDealt = ctx.applyDefensiveModifiers(
            rawDmg, 'acid', target, edition, environment);
        attacker.totalDamageDealt += damageDealt;
        target.applyDamage(damageDealt);
        if (damageDealt > 0) attacker.hitsLanded++;
      }

      String summary;
      if (shielded) {
        summary =
            'PARRIED BY SHIELD! ${target.displayName} cast Shield deflecting Acid Arrow ($d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc})!';
      } else if (isCrit) {
        final fatal = isKillShot ? ' — DEFENDER CORRODED & SLAIN!' : '';
        summary =
            'CRITICAL HIT! (Nat 20) Acid Arrow splashed for $damageDealt acid damage$fatal';
      } else if (isHit) {
        final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
        summary =
            'Hits (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) for $damageDealt acid damage$fatal';
      } else {
        summary =
            'Misses (Roll $d20 + ${attacker.spellAttackBonus} = $totalAttack vs AC ${target.effectiveAc}) — splash dealt $damageDealt acid damage.';
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
        ctx.hasSlotFor(attacker, 2)) {
      final isFireball =
          attacker.hasSpell('spell_fireball') && ctx.hasSlotFor(attacker, 3);
      final isLightning =
          attacker.hasSpell('spell_lightning_bolt') && ctx.hasSlotFor(attacker, 3);
      final isConeOfCold =
          attacker.hasSpell('spell_cone_of_cold') && ctx.hasSlotFor(attacker, 5);
      final isCloudkill =
          attacker.hasSpell('spell_cloudkill') && ctx.hasSlotFor(attacker, 5);

      final spellName = isConeOfCold
          ? 'Cone of Cold'
          : (isCloudkill
              ? 'Cloudkill'
              : (isFireball
                  ? 'Fireball'
                  : (isLightning ? 'Lightning Bolt' : 'Shatter')));
      final minLvl =
          isConeOfCold || isCloudkill ? 5 : (isFireball || isLightning ? 3 : 2);
      final saveAbility = isConeOfCold || isCloudkill
          ? 'con'
          : (isFireball || isLightning ? 'dex' : 'con');
      final dmgType = isConeOfCold
          ? 'cold'
          : (isCloudkill
              ? 'poison'
              : (isFireball
                  ? 'fire'
                  : (isLightning ? 'lightning' : 'thunder')));

      final slotLvl = ctx.deductHighestSlot(attacker, minLvl)!;
      attacker.attacksMade++;

      final d20 = ctx.rollDie(20);
      final saveBonus = target.getSavingThrowBonus(saveAbility, edition);
      final totalSave = d20 + saveBonus;
      final saveRes = ctx.evaluateSaveWithLegendaryResistance(
          defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      final hasEvasion = target.hasEvasion(edition) && saveAbility == 'dex';

      final numDice = minLvl == 5
          ? 8 + (slotLvl - 5)
          : (minLvl == 3 ? 8 + (slotLvl - 3) : 3 + (slotLvl - 2));
      final diceSides = minLvl == 5 ? 8 : (minLvl == 3 ? 6 : 8);
      final rawDmg = ctx.rollDice(numDice, diceSides);

      final saveDamage = computeSaveDamage(
        rawDamage: rawDmg,
        saved: saved,
        halfOnSuccess: true,
        hasEvasion: hasEvasion,
      );
      int damageDealt = saveDamage.damageTaken;

      damageDealt = ctx.applyDefensiveModifiers(
          damageDealt, dmgType, target, edition, environment);
      attacker.totalDamageDealt += damageDealt;
      target.applyDamage(damageDealt);
      if (damageDealt > 0) attacker.hitsLanded++;

      bool isKillShot = false;
      if (target.isDefeated) {
        isKillShot = true;
        attacker.kills++;
      }

      final fatal = isKillShot ? ' — DEFENDER SLAIN!' : '';
      String summary = ArenaCombatContext.formatSaveDamageSummary(
          saveDamage.outcome, saved, hasEvasion, d20, saveBonus, totalSave,
          attacker.spellSaveDc, saveRes.summaryNote, damageDealt, dmgType,
          fatal, spellName);

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
          evadedWithEvasion: saveDamage.outcome == SaveDamageOutcome.none && hasEvasion,
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

}
