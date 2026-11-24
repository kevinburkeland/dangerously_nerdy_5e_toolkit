import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import '../aoe_resolver.dart';
import 'arena_combat_context.dart';

/// Resolves Priority 2 AoE blast spells and Priority 3 concentration/control spells.
class ArenaAoeSpellResolver {
  final ArenaCombatContext ctx;

  const ArenaAoeSpellResolver(this.ctx);

  List<ArenaAttackEvent>? evaluateAoeSpells({
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
      (
        id: 'spell_meteor_swarm',
        name: 'Meteor Swarm',
        minLevel: 9,
        saveAbility: 'dex',
        damageType: 'fire',
        shape: AoeShape.sphere,
        sizeInFeet: 40.0,
        diceCount: (_) => 40,
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_sunburst',
        name: 'Sunburst',
        minLevel: 8,
        saveAbility: 'con',
        damageType: 'radiant',
        shape: AoeShape.sphere,
        sizeInFeet: 60.0,
        diceCount: (_) => 12,
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_delayed_blast_fireball',
        name: 'Delayed Blast Fireball',
        minLevel: 7,
        saveAbility: 'dex',
        damageType: 'fire',
        shape: AoeShape.sphere,
        sizeInFeet: 20.0,
        diceCount: (s) => 12 + (s - 7),
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_fire_storm',
        name: 'Fire Storm',
        minLevel: 7,
        saveAbility: 'dex',
        damageType: 'fire',
        shape: AoeShape.cube,
        sizeInFeet: 100.0,
        diceCount: (_) => 7,
        diceSides: 10,
        staticBonus: 0
      ),
      (
        id: 'spell_chain_lightning',
        name: 'Chain Lightning',
        minLevel: 6,
        saveAbility: 'dex',
        damageType: 'lightning',
        shape: AoeShape.line,
        sizeInFeet: 120.0,
        diceCount: (s) => 10 + (s - 6),
        diceSides: 8,
        staticBonus: 0
      ),
      (
        id: 'spell_circle_of_death',
        name: 'Circle of Death',
        minLevel: 6,
        saveAbility: 'con',
        damageType: 'necrotic',
        shape: AoeShape.sphere,
        sizeInFeet: 60.0,
        diceCount: (s) => 8 + (s - 6) * 2,
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_cone_of_cold',
        name: 'Cone of Cold',
        minLevel: 5,
        saveAbility: 'con',
        damageType: 'cold',
        shape: AoeShape.cone,
        sizeInFeet: 60.0,
        diceCount: (s) => 8 + (s - 5),
        diceSides: 8,
        staticBonus: 0
      ),
      (
        id: 'spell_cloudkill',
        name: 'Cloudkill',
        minLevel: 5,
        saveAbility: 'con',
        damageType: 'poison',
        shape: AoeShape.sphere,
        sizeInFeet: 20.0,
        diceCount: (s) => 5 + (s - 5),
        diceSides: 8,
        staticBonus: 0
      ),
      (
        id: 'spell_flame_strike',
        name: 'Flame Strike',
        minLevel: 5,
        saveAbility: 'dex',
        damageType: 'fire',
        shape: AoeShape.cylinder,
        sizeInFeet: 10.0,
        diceCount: (s) => 8 + (s - 5) * 2,
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_ice_storm',
        name: 'Ice Storm',
        minLevel: 4,
        saveAbility: 'dex',
        damageType: 'cold',
        shape: AoeShape.cylinder,
        sizeInFeet: 20.0,
        diceCount: (s) => 6 + (s - 4),
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_fireball',
        name: 'Fireball',
        minLevel: 3,
        saveAbility: 'dex',
        damageType: 'fire',
        shape: AoeShape.sphere,
        sizeInFeet: 20.0,
        diceCount: (s) => 8 + (s - 3),
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_lightning_bolt',
        name: 'Lightning Bolt',
        minLevel: 3,
        saveAbility: 'dex',
        damageType: 'lightning',
        shape: AoeShape.line,
        sizeInFeet: 100.0,
        diceCount: (s) => 8 + (s - 3),
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_shatter',
        name: 'Shatter',
        minLevel: 2,
        saveAbility: 'con',
        damageType: 'thunder',
        shape: AoeShape.sphere,
        sizeInFeet: 10.0,
        diceCount: (s) => 3 + (s - 2),
        diceSides: 8,
        staticBonus: 0
      ),
      (
        id: 'spell_burning_hands',
        name: 'Burning Hands',
        minLevel: 1,
        saveAbility: 'dex',
        damageType: 'fire',
        shape: AoeShape.cone,
        sizeInFeet: 15.0,
        diceCount: (s) => 3 + (s - 1),
        diceSides: 6,
        staticBonus: 0
      ),
      (
        id: 'spell_thunderwave',
        name: 'Thunderwave',
        minLevel: 1,
        saveAbility: 'con',
        damageType: 'thunder',
        shape: AoeShape.cube,
        sizeInFeet: 15.0,
        diceCount: (s) => 2 + (s - 1),
        diceSides: 8,
        staticBonus: 0
      ),
    ];

    for (final candidate in aoeCandidates) {
      if (attacker.hasSpell(candidate.id) &&
          ctx.hasSlotFor(attacker, candidate.minLevel)) {
        final slotLvl = ctx.deductHighestSlot(attacker, candidate.minLevel)!;
        attacker.attacksMade++;

        // Resolve targets using DMG p.249 AoeResolver with natural Box-Muller Gaussian variance
        final caughtTargets = AoeResolver.selectTargets(
          livingEnemies: livingEnemies,
          shape: candidate.shape,
          sizeInFeet: candidate.sizeInFeet,
          rng: ctx.rng,
          strategy: strategy,
        );

        final numDice = candidate.diceCount(slotLvl);
        final rawDamage =
            ctx.rollDice(numDice, candidate.diceSides) + candidate.staticBonus;
        final events = <ArenaAttackEvent>[];

        for (final defender in caughtTargets) {
          final saveBonus =
              defender.getSavingThrowBonus(candidate.saveAbility, edition);
          final d20 = ctx.rollDie(20);
          final totalSave = d20 + saveBonus;
          final saveRes = ctx.evaluateSaveWithLegendaryResistance(
              defender: defender,
              saveRoll: totalSave,
              saveDc: attacker.spellSaveDc);
          final saved = saveRes.saved;

          final hasEvasion = defender.hasEvasion(edition) &&
              candidate.saveAbility.toLowerCase() == 'dex';
          final saveDamage = computeSaveDamage(
            rawDamage: rawDamage,
            saved: saved,
            halfOnSuccess: true,
            hasEvasion: hasEvasion,
          );
          int effectiveDamage = saveDamage.damageTaken;

          effectiveDamage = ctx.applyDefensiveModifiers(effectiveDamage,
              candidate.damageType, defender, edition, environment);
          attacker.totalDamageDealt += effectiveDamage;
          defender.applyDamage(effectiveDamage);
          if (effectiveDamage > 0) attacker.hitsLanded++;

          bool isKillShot = false;
          if (defender.isDefeated) {
            isKillShot = true;
            attacker.kills++;
            defender.applyCondition(
                ArenaCondition.unconscious, ctx.rollDie, edition);
          }

          final fatal = isKillShot ? ' — SLAIN!' : '';
          String summary = ArenaCombatContext.formatSaveDamageSummary(
              saveDamage.outcome, saved, hasEvasion, d20, saveBonus, totalSave,
              attacker.spellSaveDc, saveRes.summaryNote, effectiveDamage,
              candidate.damageType, fatal);

          if (effectiveDamage > 0 &&
              defender.activeConcentrationSpellId != null) {
            final conRes =
                defender.checkConcentration(effectiveDamage, ctx.rollDie, edition);
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
              evadedWithEvasion: saveDamage.outcome == SaveDamageOutcome.none && hasEvasion,
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
  ({List<ArenaAttackEvent> events, String? summary})?
      evaluateConcentrationControl({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> livingEnemies,
    required List<ArenaCombatant> livingAllies,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    // 1. Hold Monster (spell_hold_monster, Level 5)
    if (attacker.hasSpell('spell_hold_monster') && ctx.hasSlotFor(attacker, 5)) {
      livingEnemies.sort((a, b) =>
          b.monster.challengeRating.compareTo(a.monster.challengeRating));
      final target = livingEnemies.first;
      final slotLvl = ctx.deductHighestSlot(attacker, 5)!;
      attacker.activeConcentrationSpellId = 'spell_hold_monster';

      final d20 = ctx.rollDie(20);
      final saveBonus = target.getSavingThrowBonus('wis', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = ctx.evaluateSaveWithLegendaryResistance(
          defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
      final saved = saveRes.saved;

      String note;
      if (saved) {
        note =
            '${target.displayName} resisted Hold Monster (Wis save $totalSave vs DC ${attacker.spellSaveDc})${saveRes.summaryNote}';
      } else {
        final condRes =
            target.applyCondition(ArenaCondition.paralyzed, ctx.rollDie, edition);
        note =
            '${target.displayName} failed Wis save ($totalSave vs DC ${attacker.spellSaveDc}) and is PARALYZED by Hold Monster!';
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
        summary:
            '${attacker.displayName} is now concentrating on Hold Monster.',
      );
    }

    // 2. Banishment (spell_banishment, Level 4)
    if (attacker.hasSpell('spell_banishment') && ctx.hasSlotFor(attacker, 4)) {
      livingEnemies.sort((a, b) =>
          b.monster.challengeRating.compareTo(a.monster.challengeRating));
      final target = livingEnemies.first;
      final slotLvl = ctx.deductHighestSlot(attacker, 4)!;
      attacker.activeConcentrationSpellId = 'spell_banishment';

      final d20 = ctx.rollDie(20);
      final saveBonus = target.getSavingThrowBonus('cha', edition);
      final totalSave = d20 + saveBonus;
      final saveRes = ctx.evaluateSaveWithLegendaryResistance(
          defender: target, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
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
    if (attacker.hasSpell('spell_slow') && ctx.hasSlotFor(attacker, 3)) {
      final slotLvl = ctx.deductHighestSlot(attacker, 3)!;
      attacker.activeConcentrationSpellId = 'spell_slow';
      final events = <ArenaAttackEvent>[];

      for (final enemy in livingEnemies.take(6)) {
        final d20 = ctx.rollDie(20);
        final saveBonus = enemy.getSavingThrowBonus('wis', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = ctx.evaluateSaveWithLegendaryResistance(
            defender: enemy, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
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

      return (
        events: events,
        summary: '${attacker.displayName} is concentrating on Slow.'
      );
    }

    // 4. Faerie Fire (spell_faerie_fire, Level 1)
    if (attacker.hasSpell('spell_faerie_fire') && ctx.hasSlotFor(attacker, 1)) {
      final slotLvl = ctx.deductLowestSlot(attacker, 1)!;
      attacker.activeConcentrationSpellId = 'spell_faerie_fire';
      final events = <ArenaAttackEvent>[];

      for (final enemy in livingEnemies.take(4)) {
        final d20 = ctx.rollDie(20);
        final saveBonus = enemy.getSavingThrowBonus('dex', edition);
        final totalSave = d20 + saveBonus;
        final saveRes = ctx.evaluateSaveWithLegendaryResistance(
            defender: enemy, saveRoll: totalSave, saveDc: attacker.spellSaveDc);
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

      return (
        events: events,
        summary: '${attacker.displayName} is concentrating on Faerie Fire.'
      );
    }

    // 5. Shield of Faith (spell_shield_of_faith, Level 1)
    if (attacker.hasSpell('spell_shield_of_faith') &&
        ctx.hasSlotFor(attacker, 1)) {
      final slotLvl = ctx.deductLowestSlot(attacker, 1)!;
      attacker.activeConcentrationSpellId = 'spell_shield_of_faith';
      attacker.temporaryAcBonus += 2;
      return (
        events: const [],
        summary:
            '${attacker.displayName} cast Shield of Faith (Slot $slotLvl) on themselves (+2 AC, concentrating)!',
      );
    }

    // 6. Bless (spell_bless, Level 1)
    if (attacker.hasSpell('spell_bless') && ctx.hasSlotFor(attacker, 1)) {
      final slotLvl = ctx.deductLowestSlot(attacker, 1)!;
      attacker.activeConcentrationSpellId = 'spell_bless';
      return (
        events: const [],
        summary:
            '${attacker.displayName} cast Bless (Slot $slotLvl) boosting allies with divine favor!',
      );
    }

    return null;
  }

  /// Priority 4: Single-Target Burst Spells

}
