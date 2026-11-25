import 'dart:math';

import '../../../models/arena/arena_action_result.dart';
import '../../../models/arena/arena_combatant.dart';
import '../../../models/arena/arena_simulation_models.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/spellbook_data.dart';
import 'arena_aoe_spell_resolver.dart';
import 'arena_cantrip_resolver.dart';
import 'arena_combat_context.dart';
import 'arena_high_level_burst_resolver.dart';
import 'arena_kill_shot_resolver.dart';
import 'arena_low_level_burst_resolver.dart';

/// Priority-ordered tactical spellcasting AI for arena combatants.
class ArenaSpellcastingAi {
  final ArenaCombatContext ctx;
  final ArenaKillShotResolver _killShot;
  final ArenaAoeSpellResolver _aoe;
  final ArenaHighLevelBurstResolver _highBurst;
  final ArenaLowLevelBurstResolver _lowBurst;
  final ArenaCantripResolver _cantrips;

  ArenaSpellcastingAi(this.ctx)
      : _killShot = ArenaKillShotResolver(ctx),
        _aoe = ArenaAoeSpellResolver(ctx),
        _highBurst = ArenaHighLevelBurstResolver(ctx),
        _lowBurst = ArenaLowLevelBurstResolver(ctx),
        _cantrips = ArenaCantripResolver(ctx);

  List<ArenaAttackEvent>? _evaluateSingleTargetBurst({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> livingEnemies,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    final target = ctx.selectTarget(attacker, allCombatants, strategy);
    if (target == null) return null;
    final high = _highBurst.evaluateHighLevelBurst(
      attacker: attacker,
      target: target,
      edition: edition,
      environment: environment,
    );
    if (high != null) return high;
    return _lowBurst.evaluateLowLevelBurst(
      attacker: attacker,
      target: target,
      edition: edition,
      environment: environment,
    );
  }

  ({List<ArenaAttackEvent> events, String? specialSummary})?
      evaluateTacticalSpellcasting({
    required ArenaCombatant attacker,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    required DmRulesEdition edition,
    required ArenaEnvironment environment,
  }) {
    final livingEnemies = allCombatants
        .where((c) => c.team != attacker.team && c.isAlive)
        .toList();
    if (livingEnemies.isEmpty) return null;

    final livingAllies = allCombatants
        .where((c) => c.team == attacker.team && c.isAlive)
        .toList();

    final events = <ArenaAttackEvent>[];
    String? bonusSummary;

    // --- Bonus Action Spells ---
    // 1. Healing Word (spell_healing_word)
    if (attacker.hasSpell('spell_healing_word') && ctx.hasSlotFor(attacker, 1)) {
      final injuredAllies =
          livingAllies.where((a) => a.currentHp < a.maxHp * 0.6).toList();
      if (injuredAllies.isNotEmpty) {
        injuredAllies.sort((a, b) => a.hpPercent.compareTo(b.hpPercent));
        final healTarget = injuredAllies.first;
        final slotLvl = ctx.deductLowestSlot(attacker, 1)!;
        attacker.castBonusActionSpellThisTurn = true;

        final healSpell = SpellbookLibrary.getSpellById('spell_healing_word')!;
        final healDetails = edition == DmRulesEdition.v2014
            ? healSpell.rules2014
            : healSpell.rules2024;
        final scaling = healDetails.scalingFormula!;
        final diceCount = scaling.baseDiceCount +
            (slotLvl - healSpell.level) * scaling.dicePerSlotLevel;
        final castingMod = scaling.addsAbilityMod
            ? attacker.spellAttackBonus
            : 0;
        final healAmount =
            max(0, ctx.rollDice(diceCount, scaling.diceSides) + castingMod);
        final actualHealed =
            min(healTarget.maxHp - healTarget.currentHp, healAmount);
        healTarget.currentHp += actualHealed;
        bonusSummary =
            '${attacker.displayName} cast Healing Word (Slot $slotLvl) on ${healTarget.displayName}, restoring $actualHealed HP!';
      }
    }
    // 2. Misty Step (spell_misty_step)
    else if (attacker.hasSpell('spell_misty_step') &&
        ctx.hasSlotFor(attacker, 2) &&
        !attacker.castBonusActionSpellThisTurn) {
      if (attacker.hpPercent < 0.5) {
        final slotLvl = ctx.deductLowestSlot(attacker, 2)!;
        attacker.castBonusActionSpellThisTurn = true;
        bonusSummary =
            '${attacker.displayName} cast Misty Step (Slot $slotLvl) to teleport to safety!';
      }
    }

    // --- Main Action Spells ---
    // 5e Action Economy: If a Bonus Action spell was cast, strictly Cantrips only for the main action!
    if (attacker.castBonusActionSpellThisTurn) {
      final cantripEvents = _cantrips.evaluateCantrips(
        attacker: attacker,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );
      if (cantripEvents != null && cantripEvents.isNotEmpty) {
        events.addAll(cantripEvents);
        return (events: events, specialSummary: bonusSummary);
      }
      return bonusSummary != null
          ? (events: const [], specialSummary: bonusSummary)
          : null;
    }

    // Priority 1A: Large AoE Clustering (>= 3 living enemies)
    if (livingEnemies.length >= 3) {
      final aoeEvents = _aoe.evaluateAoeSpells(
        attacker: attacker,
        livingEnemies: livingEnemies,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );
      if (aoeEvents != null && aoeEvents.isNotEmpty) {
        events.addAll(aoeEvents);
        return (events: events, specialSummary: bonusSummary);
      }
    }

    // Priority 1B: Kill-Shot / Execution
    final killShotEvents = _killShot.evaluateKillShot(
      attacker: attacker,
      livingEnemies: livingEnemies,
      edition: edition,
      environment: environment,
    );
    if (killShotEvents != null && killShotEvents.isNotEmpty) {
      events.addAll(killShotEvents);
      return (events: events, specialSummary: bonusSummary);
    }

    // Priority 2: AoE Clustering (2 living enemies)
    if (livingEnemies.length >= 2) {
      final aoeEvents = _aoe.evaluateAoeSpells(
        attacker: attacker,
        livingEnemies: livingEnemies,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );
      if (aoeEvents != null && aoeEvents.isNotEmpty) {
        events.addAll(aoeEvents);
        return (events: events, specialSummary: bonusSummary);
      }
    }

    // Priority 3: Concentration Buff / Control (if not currently concentrating)
    if (attacker.activeConcentrationSpellId == null) {
      final controlResult = _aoe.evaluateConcentrationControl(
        attacker: attacker,
        livingEnemies: livingEnemies,
        livingAllies: livingAllies,
        edition: edition,
        environment: environment,
      );
      if (controlResult != null) {
        events.addAll(controlResult.events);
        final summary = [
          ?bonusSummary,
          if (controlResult.summary != null) controlResult.summary,
        ].join('\n');
        return (
          events: events,
          specialSummary: summary.isNotEmpty ? summary : null
        );
      }
    }

    // Priority 4: Single-Target Burst
    final burstEvents = _evaluateSingleTargetBurst(
      attacker: attacker,
      livingEnemies: livingEnemies,
      allCombatants: allCombatants,
      strategy: strategy,
      edition: edition,
      environment: environment,
    );
    if (burstEvents != null && burstEvents.isNotEmpty) {
      events.addAll(burstEvents);
      return (events: events, specialSummary: bonusSummary);
    }

    // Priority 5: Cantrip Fallback
    final cantripEvents = _cantrips.evaluateCantrips(
      attacker: attacker,
      allCombatants: allCombatants,
      strategy: strategy,
      edition: edition,
      environment: environment,
    );
    if (cantripEvents != null && cantripEvents.isNotEmpty) {
      events.addAll(cantripEvents);
      return (events: events, specialSummary: bonusSummary);
    }

    return bonusSummary != null
        ? (events: const [], specialSummary: bonusSummary)
        : null;
  }

  /// Priority 1: Kill-Shot Execution Spells

}
