import 'dart:math' as math;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../dm_screen_data.dart';
import '../monster_codex_data.dart';
import '../domain/character_models.dart';
import '../srd_summons/minion_stat_block.dart';
import 'arena_condition.dart';
import 'monster_combat_profile.dart';
import '../../services/rules/dnd_5e_rules_engine.dart';
import '../../domain/simulation/precomputed_attack.dart';
import '../../domain/models/value_objects/hit_points.dart';
export 'package:fast_immutable_collections/fast_immutable_collections.dart';
export 'arena_condition.dart';
export 'monster_combat_profile.dart';
export '../../domain/simulation/combat_rider.dart';

/// Which team the combatant belongs to in the Arena.
enum ArenaTeam {
  teamA('Team Crimson'),
  teamB('Team Cobalt');

  final String label;
  const ArenaTeam(this.label);

  ArenaTeam get opponent => this == ArenaTeam.teamA ? ArenaTeam.teamB : ArenaTeam.teamA;
}

/// Attack classification distinguishing reach and delivery mechanisms.
enum AttackType {
  meleeStandard(5, 'Melee Standard (5 ft.)'),
  meleeReach(10, 'Melee Reach (10+ ft.)'),
  rangedWeapon(120, 'Ranged Weapon'),
  rangedSpell(120, 'Ranged Spell');

  final int defaultReach;
  final String label;
  const AttackType(this.defaultReach, this.label);
}


/// Represents a single active instance of a monster in the Arena.
class ArenaCombatant {
  final String id;
  final MonsterItem monster;
  final ArenaTeam team;
  final String displayName;
  HitPoints hitPoints;
  int get maxHp => hitPoints.maxHp;
  set maxHp(int val) {
    hitPoints = hitPoints.copyWith(maxHp: val);
  }
  int get currentHp => hitPoints.currentHp;
  set currentHp(int val) {
    hitPoints = hitPoints.copyWith(currentHp: val);
  }
  int get tempHp => hitPoints.tempHp;
  set tempHp(int val) {
    hitPoints = hitPoints.copyWith(tempHp: val);
  }
  final int ac;
  final int initiativeBonus;
  int initiative;
  bool isRechargeReady;

  // Aerial Combat & Reach State
  bool isAirborne;
  final bool hasHover;
  int altitudeInFeet;
  int meleeReachInFeet;
  ISet<ArenaCondition> conditions;
  IList<ActiveCondition> activeConditions;

  // Spellcasting State & Pre-Cached Attributes
  IMap<int, int> currentSpellSlots;
  IMap<int, int> maxSpellSlots;
  final List<String> knownSpellIds;
  final int spellSaveDc;
  final int spellAttackBonus;
  final IMap<String, int> savingThrowBonuses;
  String? activeConcentrationSpellId;
  bool usedReactionThisRound;
  bool castBonusActionSpellThisTurn;
  int temporaryAcBonus;

  // Legendary Action & Resistance State
  final int maxLegendaryActions;
  int legendaryActionsRemaining;
  final int maxLegendaryResistances;
  int legendaryResistancesRemaining;

  // Tracked combat stats
  int totalDamageDealt;
  int totalDamageTaken;
  int kills;
  int attacksMade;
  int hitsLanded;
  int critsLanded;

  // Attribute Drain & Max HP Reduction State
  IMap<String, int> drainedAbilityScores;
  int maxHpReduction;
  bool isHealingSuppressed;

  ArenaCombatant({
    required this.id,
    required this.monster,
    required this.team,
    required this.displayName,
    HitPoints? hitPoints,
    int? maxHp,
    int? currentHp,
    int tempHp = 0,
    required this.ac,
    required this.initiativeBonus,
    this.initiative = 0,
    this.isRechargeReady = true,
    this.isAirborne = false,
    this.hasHover = false,
    this.altitudeInFeet = 0,
    this.meleeReachInFeet = 5,
    dynamic conditions,
    dynamic activeConditions,
    dynamic currentSpellSlots,
    dynamic maxSpellSlots,
    List<String>? knownSpellIds,
    this.spellSaveDc = 10,
    this.spellAttackBonus = 0,
    dynamic savingThrowBonuses,
    this.activeConcentrationSpellId,
    this.usedReactionThisRound = false,
    this.castBonusActionSpellThisTurn = false,
    this.temporaryAcBonus = 0,
    this.maxLegendaryActions = 0,
    int? legendaryActionsRemaining,
    this.maxLegendaryResistances = 0,
    int? legendaryResistancesRemaining,
    this.totalDamageDealt = 0,
    this.totalDamageTaken = 0,
    this.kills = 0,
    this.attacksMade = 0,
    this.hitsLanded = 0,
    this.critsLanded = 0,
    dynamic drainedAbilityScores,
    this.maxHpReduction = 0,
    this.isHealingSuppressed = false,
  })  : hitPoints = hitPoints ??
            HitPoints(
              currentHp: currentHp ?? maxHp ?? 1,
              maxHp: maxHp ?? 1,
              tempHp: tempHp,
            ),
        conditions = _parseConditions(conditions, activeConditions),
        activeConditions = _parseActiveConditions(activeConditions, conditions),
        maxSpellSlots = _parseIMap<int, int>(maxSpellSlots),
        currentSpellSlots = currentSpellSlots != null
            ? _parseIMap<int, int>(currentSpellSlots)
            : _parseIMap<int, int>(maxSpellSlots),
        knownSpellIds = knownSpellIds != null ? List<String>.from(knownSpellIds) : [],
        savingThrowBonuses = _parseIMap<String, int>(savingThrowBonuses),
        drainedAbilityScores = _parseIMap<String, int>(drainedAbilityScores),
        legendaryActionsRemaining = legendaryActionsRemaining ?? maxLegendaryActions,
        legendaryResistancesRemaining = legendaryResistancesRemaining ?? maxLegendaryResistances;

  static ISet<ArenaCondition> _parseConditions(dynamic conditions, dynamic activeConditions) {
    if (conditions != null) {
      if (conditions is ISet<ArenaCondition>) return conditions;
      if (conditions is Iterable<ArenaCondition>) return conditions.toISet();
      if (conditions is Iterable) return ISet<ArenaCondition>(conditions.cast<ArenaCondition>());
    }
    if (activeConditions != null) {
      if (activeConditions is IList<ActiveCondition>) {
        return activeConditions.map((a) => a.condition).toISet();
      }
      if (activeConditions is Iterable<ActiveCondition>) {
        return activeConditions.map((a) => a.condition).toISet();
      }
    }
    return const ISetConst({});
  }

  static IList<ActiveCondition> _parseActiveConditions(dynamic activeConditions, dynamic conditions) {
    if (activeConditions != null) {
      if (activeConditions is IList<ActiveCondition>) return activeConditions;
      if (activeConditions is Iterable<ActiveCondition>) return activeConditions.toIList();
      if (activeConditions is Iterable) return IList<ActiveCondition>(activeConditions.cast<ActiveCondition>());
    }
    if (conditions != null) {
      if (conditions is ISet<ArenaCondition>) {
        return conditions.map((c) => ActiveCondition(condition: c)).toIList();
      }
      if (conditions is Iterable<ArenaCondition>) {
        return conditions.map((c) => ActiveCondition(condition: c)).toIList();
      }
    }
    return const IListConst([]);
  }

  static IMap<K, V> _parseIMap<K, V>(dynamic map) {
    if (map == null) return IMap<K, V>();
    if (map is IMap<K, V>) return map;
    if (map is Map<K, V>) return map.toIMap();
    if (map is Map) return IMap<K, V>(Map<K, V>.from(map));
    return IMap<K, V>();
  }

  /// Updates a spell slot level count immutably via structural sharing.
  void setSpellSlot(int level, int count) {
    currentSpellSlots = currentSpellSlots.add(level, count);
  }

  /// Updates a max spell slot level count immutably via structural sharing.
  void setMaxSpellSlot(int level, int count) {
    maxSpellSlots = maxSpellSlots.add(level, count);
  }

  /// Effective AC accounting for active reaction bonuses (e.g. Shield spell +5 AC).
  int get effectiveAc => ac + temporaryAcBonus;

  bool get isSpellcaster => knownSpellIds.isNotEmpty || maxSpellSlots.isNotEmpty;
  bool get hasAvailableSlots => currentSpellSlots.values.any((v) => v > 0);
  bool hasSpell(String spellId) => knownSpellIds.contains(spellId);

  // Legendary Action & Resistance Helpers
  bool get hasLegendaryActions => maxLegendaryActions > 0;
  void resetLegendaryActions() {
    legendaryActionsRemaining = maxLegendaryActions;
  }

  bool get hasLegendaryResistances => maxLegendaryResistances > 0;
  bool useLegendaryResistance() {
    if (legendaryResistancesRemaining > 0) {
      legendaryResistancesRemaining--;
      return true;
    }
    return false;
  }
  void resetLegendaryResistances() {
    legendaryResistancesRemaining = maxLegendaryResistances;
  }

  // Condition Status Helpers
  bool get isProne => conditions.contains(ArenaCondition.prone);
  bool get isParalyzed => conditions.contains(ArenaCondition.paralyzed);
  bool get isStunned => conditions.contains(ArenaCondition.stunned);
  bool get isRestrained => conditions.contains(ArenaCondition.restrained);
  bool get isUnconscious => conditions.contains(ArenaCondition.unconscious);
  bool get isIncapacitated =>
      conditions.contains(ArenaCondition.incapacitated) ||
      isParalyzed ||
      isStunned ||
      isUnconscious;

  /// Factory constructor to create a fresh combatant from a [MonsterItem].
  /// Uses pre-calculated [MonsterCombatProfile] directly with zero regex or string allocations.
  factory ArenaCombatant.fromMonster({
    required String id,
    required MonsterItem monster,
    required ArenaTeam team,
    String? customName,
    DmRulesEdition edition = DmRulesEdition.v2024,
    int? hpOverride,
    int? acOverride,
  }) {
    final sb = monster.getStatBlock(edition);
    final initBonus = sb.dexMod;
    final maxHp = hpOverride ?? sb.maxHp;
    final ac = acOverride ?? sb.ac;
    final name = customName ?? monster.getName(edition);
    final profile = monster.getCombatProfile(edition);

    return ArenaCombatant(
      id: id,
      monster: monster,
      team: team,
      displayName: name,
      maxHp: maxHp > 0 ? maxHp : 1,
      currentHp: maxHp > 0 ? maxHp : 1,
      ac: ac > 0 ? ac : 10,
      initiativeBonus: initBonus,
      isRechargeReady: true,
      isAirborne: profile.canFly,
      hasHover: profile.hasHover,
      altitudeInFeet: profile.defaultAltitudeInFeet,
      meleeReachInFeet: profile.meleeReachInFeet,
      conditions: const ISetConst({}),
      maxSpellSlots: profile.maxSpellSlots.toIMap(),
      currentSpellSlots: profile.maxSpellSlots.toIMap(),
      knownSpellIds: profile.knownSpellIds,
      spellSaveDc: profile.spellSaveDc,
      spellAttackBonus: profile.spellAttackBonus,
      savingThrowBonuses: profile.savingThrowBonuses.toIMap(),
      activeConcentrationSpellId: null,
      usedReactionThisRound: false,
      castBonusActionSpellThisTurn: false,
      temporaryAcBonus: 0,
      maxLegendaryActions: profile.maxLegendaryActions,
      maxLegendaryResistances: profile.maxLegendaryResistances,
    );
  }

  int get effectiveMaxHp => (maxHp - maxHpReduction).clamp(0, maxHp);
  bool get isAlive =>
      currentHp > 0 &&
      effectiveMaxHp > 0 &&
      (drainedAbilityScores['str'] == null || getAbilityScore(AbilityType.strength) > 0);
  bool get isDefeated => !isAlive;
  double get hpPercent => effectiveMaxHp > 0 ? (currentHp / effectiveMaxHp).clamp(0.0, 1.0) : 0.0;

  /// Applies an [ActiveCondition] with optional duration and source effect tracking.
  ({int fallDamage, bool fell, String? log}) applyActiveCondition(
    ActiveCondition activeCondition, {
    int Function(int sides)? diceRoller,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    conditions = conditions.add(activeCondition.condition);
    final idx = activeConditions.indexWhere((a) => a.condition == activeCondition.condition);
    if (idx >= 0) {
      activeConditions = activeConditions.put(idx, activeCondition);
    } else {
      activeConditions = activeConditions.add(activeCondition);
    }
    return _handleDisruptiveCondition(
      activeCondition.condition,
      diceRoller ?? (s) => (s / 2).ceil(),
      edition,
    );
  }

  /// Applies a 5e condition and executes falling mechanics if airborne without hover.
  ({int fallDamage, bool fell, String? log}) applyCondition(
    ArenaCondition condition,
    int Function(int sides) diceRoller,
    DmRulesEdition edition, {
    int? durationRounds,
    String? source,
  }) {
    conditions = conditions.add(condition);
    final idx = activeConditions.indexWhere((a) => a.condition == condition);
    final active = ActiveCondition(
      condition: condition,
      durationRounds: durationRounds,
      source: source,
    );
    if (idx >= 0) {
      activeConditions = activeConditions.put(idx, active);
    } else {
      activeConditions = activeConditions.add(active);
    }

    return _handleDisruptiveCondition(condition, diceRoller, edition);
  }

  ({int fallDamage, bool fell, String? log}) _handleDisruptiveCondition(
    ArenaCondition condition,
    int Function(int sides) diceRoller,
    DmRulesEdition edition,
  ) {
    final isDisruptive = condition == ArenaCondition.prone ||
        condition == ArenaCondition.stunned ||
        condition == ArenaCondition.paralyzed ||
        condition == ArenaCondition.restrained ||
        condition == ArenaCondition.unconscious;

    if (isDisruptive && isAirborne) {
      if (!hasHover) {
        final fallHeight = altitudeInFeet;
        final diceCount = (fallHeight ~/ 10).clamp(1, 20);
        int rawFallDamage = 0;
        for (int i = 0; i < diceCount; i++) {
          rawFallDamage += diceRoller(6);
        }

        isAirborne = false;
        altitudeInFeet = 0;
        conditions = conditions.add(ArenaCondition.prone);
        if (!activeConditions.any((a) => a.condition == ArenaCondition.prone)) {
          activeConditions = activeConditions.add(const ActiveCondition(condition: ArenaCondition.prone));
        }
        applyDamage(rawFallDamage);

        return (
          fallDamage: rawFallDamage,
          fell: true,
          log: '$displayName fell $fallHeight ft. from the air, taking $rawFallDamage bludgeoning damage and landing Prone!',
        );
      } else {
        return (
          fallDamage: 0,
          fell: false,
          log: '$displayName hovered in place despite suffering ${condition.label}!',
        );
      }
    }

    return (fallDamage: 0, fell: false, log: null);
  }

  void removeCondition(ArenaCondition condition) {
    conditions = conditions.remove(condition);
    activeConditions = activeConditions.removeWhere((a) => a.condition == condition);
  }

  bool hasCondition(ArenaCondition condition) => conditions.contains(condition);

  /// Toggles a condition on or off. Returns true if condition is now active, false if removed.
  bool toggleCondition(
    ArenaCondition condition, {
    int? durationRounds,
    String? source,
    int Function(int sides)? diceRoller,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    if (hasCondition(condition)) {
      removeCondition(condition);
      return false;
    } else {
      applyActiveCondition(
        ActiveCondition(
          condition: condition,
          durationRounds: durationRounds,
          source: source,
        ),
        diceRoller: diceRoller,
        edition: edition,
      );
      return true;
    }
  }

  /// Decrements condition durations at the end of turn, removing any expired conditions.
  List<ArenaCondition> tickTurnConditions() {
    final expired = <ArenaCondition>[];
    final remaining = <ActiveCondition>[];
    for (int i = 0; i < activeConditions.length; i++) {
      final active = activeConditions[i];
      if (active.hasFiniteDuration) {
        final updated = active.tickTurn();
        if (updated.isExpired) {
          expired.add(active.condition);
          conditions = conditions.remove(active.condition);
        } else {
          remaining.add(updated);
        }
      } else {
        remaining.add(active);
      }
    }
    activeConditions = remaining.toIList();
    return expired;
  }

  void clearConditions() {
    conditions = const ISetConst({});
    activeConditions = const IListConst([]);
  }

  /// Clones combatant with fresh max HP, reset spell slots, and reset combat counters.
  ArenaCombatant reset() {
    final canFlyMonster = canFly();
    return ArenaCombatant(
      id: id,
      monster: monster,
      team: team,
      displayName: displayName,
      maxHp: maxHp,
      currentHp: maxHp,
      tempHp: 0,
      ac: ac,
      initiativeBonus: initiativeBonus,
      initiative: 0,
      isRechargeReady: true,
      isAirborne: canFlyMonster,
      hasHover: hasHover,
      altitudeInFeet: canFlyMonster ? 20 : 0,
      meleeReachInFeet: meleeReachInFeet,
      conditions: const ISetConst({}),
      activeConditions: const IListConst([]),
      maxSpellSlots: maxSpellSlots,
      currentSpellSlots: maxSpellSlots,
      knownSpellIds: List<String>.from(knownSpellIds),
      spellSaveDc: spellSaveDc,
      spellAttackBonus: spellAttackBonus,
      savingThrowBonuses: savingThrowBonuses,
      activeConcentrationSpellId: null,
      usedReactionThisRound: false,
      castBonusActionSpellThisTurn: false,
      temporaryAcBonus: 0,
      maxLegendaryActions: maxLegendaryActions,
      legendaryActionsRemaining: maxLegendaryActions,
      maxLegendaryResistances: maxLegendaryResistances,
      legendaryResistancesRemaining: maxLegendaryResistances,
      totalDamageDealt: 0,
      totalDamageTaken: 0,
      kills: 0,
      attacksMade: 0,
      hitsLanded: 0,
      critsLanded: 0,
      drainedAbilityScores: const IMapConst({}),
      maxHpReduction: 0,
      isHealingSuppressed: false,
    );
  }

  /// Deep copy for simulation state snapshots and Monte Carlo branch isolation.
  ArenaCombatant clone() {
    return ArenaCombatant(
      id: id,
      monster: monster,
      team: team,
      displayName: displayName,
      maxHp: maxHp,
      currentHp: currentHp,
      tempHp: tempHp,
      ac: ac,
      initiativeBonus: initiativeBonus,
      initiative: initiative,
      isRechargeReady: isRechargeReady,
      isAirborne: isAirborne,
      hasHover: hasHover,
      altitudeInFeet: altitudeInFeet,
      meleeReachInFeet: meleeReachInFeet,
      conditions: conditions,
      activeConditions: activeConditions,
      maxSpellSlots: maxSpellSlots,
      currentSpellSlots: currentSpellSlots,
      knownSpellIds: List<String>.from(knownSpellIds),
      spellSaveDc: spellSaveDc,
      spellAttackBonus: spellAttackBonus,
      savingThrowBonuses: savingThrowBonuses,
      activeConcentrationSpellId: activeConcentrationSpellId,
      usedReactionThisRound: usedReactionThisRound,
      castBonusActionSpellThisTurn: castBonusActionSpellThisTurn,
      temporaryAcBonus: temporaryAcBonus,
      maxLegendaryActions: maxLegendaryActions,
      legendaryActionsRemaining: legendaryActionsRemaining,
      maxLegendaryResistances: maxLegendaryResistances,
      legendaryResistancesRemaining: legendaryResistancesRemaining,
      totalDamageDealt: totalDamageDealt,
      totalDamageTaken: totalDamageTaken,
      kills: kills,
      attacksMade: attacksMade,
      hitsLanded: hitsLanded,
      critsLanded: critsLanded,
      drainedAbilityScores: drainedAbilityScores,
      maxHpReduction: maxHpReduction,
      isHealingSuppressed: isHealingSuppressed,
    );
  }

  /// Checks concentration saving throw when taking damage.
  /// Returns a record detailing if concentration was broken.
  ({bool broken, int saveRoll, int dc, String? lostSpellId}) checkConcentration(
    int damageDealt,
    int Function(int sides) d20Roller, [
    DmRulesEdition edition = DmRulesEdition.v2024,
  ]) {
    if (activeConcentrationSpellId == null || damageDealt <= 0) {
      return (broken: false, saveRoll: 0, dc: 0, lostSpellId: null);
    }
    final dc = math.max(10, (damageDealt / 2).floor());
    final d20 = d20Roller(20);
    final conBonus = getSavingThrowBonus('con', edition);
    final totalSave = d20 + conBonus;
    if (totalSave < dc) {
      final lost = activeConcentrationSpellId;
      activeConcentrationSpellId = null;
      return (broken: true, saveRoll: totalSave, dc: dc, lostSpellId: lost);
    }
    return (broken: false, saveRoll: totalSave, dc: dc, lostSpellId: activeConcentrationSpellId);
  }

  /// Applies damage with temporary HP buffering.
  int applyDamage(int damage) {
    if (damage <= 0 || isDefeated) return 0;
    hitPoints = hitPoints.takeDamage(damage);
    if (currentHp > effectiveMaxHp) {
      currentHp = effectiveMaxHp;
    }
    totalDamageTaken += damage;
    return damage;
  }

  /// Applies healing up to [effectiveMaxHp] unless healing is suppressed.
  int applyHealing(int amount) {
    if (amount <= 0 || isDefeated || isHealingSuppressed) return 0;
    final prevHp = currentHp;
    hitPoints = hitPoints.heal(amount);
    if (currentHp > effectiveMaxHp) {
      currentHp = effectiveMaxHp;
    }
    return currentHp - prevHp;
  }

  /// Stat block accessor helper
  MinionStatBlock getStatBlock([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getStatBlock(edition);
  }

  // --- Mobility & Evasion Capabilities ---

  bool canFly([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getCombatProfile(edition).canFly;
  }

  bool canSwim([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getCombatProfile(edition).canSwim;
  }

  bool canBurrow([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getCombatProfile(edition).canBurrow;
  }

  bool canClimb([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getCombatProfile(edition).canClimb;
  }

  bool hasEvasion([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getCombatProfile(edition).hasEvasion;
  }

  bool hasFlyby([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getCombatProfile(edition).hasFlyby;
  }

  bool hasNimbleEscape([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getCombatProfile(edition).hasNimbleEscape;
  }

  /// Returns effective ability score accounting for any attribute drains.
  int getAbilityScore(AbilityType ability, [DmRulesEdition edition = DmRulesEdition.v2024]) {
    final sb = getStatBlock(edition);
    final base = switch (ability) {
      AbilityType.strength => sb.strScore,
      AbilityType.dexterity => sb.dexScore,
      AbilityType.constitution => sb.conScore,
      AbilityType.intelligence => sb.intScore,
      AbilityType.wisdom => sb.wisScore,
      AbilityType.charisma => sb.chaScore,
    };
    final drain = drainedAbilityScores[ability.shortName.toLowerCase()] ?? 0;
    return base - drain;
  }

  /// Returns effective ability modifier accounting for any attribute drains.
  int getAbilityModifier(AbilityType ability, [DmRulesEdition edition = DmRulesEdition.v2024]) {
    return getAbilityScore(ability, edition).dndModifier;
  }

  /// Calculates effective melee attack bonus scaled by strength drain.
  int getMeleeAttackBonus([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final sb = getStatBlock(edition);
    final baseMod = sb.strMod;
    final currentMod = getAbilityModifier(AbilityType.strength, edition);
    final modDelta = currentMod - baseMod;
    return sb.attackBonus + modDelta;
  }

  int get meleeAttackBonus => getMeleeAttackBonus();

  /// Applies attribute drain to the specified ability.
  /// If [deathAtZero] is true and effective score drops <= 0, triggers immediate death.
  void applyAttributeDrain(AbilityType ability, int drain, {bool deathAtZero = true}) {
    if (drain <= 0) return;
    final key = ability.shortName.toLowerCase();
    final currentDrain = drainedAbilityScores[key] ?? 0;
    drainedAbilityScores = drainedAbilityScores.add(key, currentDrain + drain);

    if (deathAtZero && getAbilityScore(ability) <= 0) {
      currentHp = 0;
    }
  }

  /// Reduces maximum hit points.
  /// If [deathAtZero] is true and effectiveMaxHp drops <= 0, triggers immediate death.
  void applyMaxHpReduction(int reduction, {bool deathAtZero = true}) {
    if (reduction <= 0) return;
    maxHpReduction += reduction;
    if (currentHp > effectiveMaxHp) {
      currentHp = effectiveMaxHp;
    }
    if (deathAtZero && effectiveMaxHp <= 0) {
      currentHp = 0;
    }
  }

  /// Executes a single [CombatEffectRider] against this combatant.
  ({List<String> logs, List<ArenaCondition> conditionsApplied}) applyRider(
    CombatEffectRider rider, {
    math.Random? rng,
    int damageDealt = 0,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final random = rng ?? math.Random();
    final logs = <String>[];
    final conditions = <ArenaCondition>[];

    switch (rider) {
      case ConditionRider(:final condition, :final requiresSave, :final saveDc, :final saveAbility):
        if (requiresSave && saveDc != null && saveAbility != null) {
          final saveBonus = getAbilitySavingThrowBonus(saveAbility, edition);
          final roll = random.nextInt(20) + 1 + saveBonus;
          if (roll < saveDc) {
            applyActiveCondition(ActiveCondition(condition: condition), edition: edition);
            conditions.add(condition);
            final actionVerb = condition == ArenaCondition.prone ? 'fell' : 'became';
            logs.add('$displayName failed DC $saveDc ${saveAbility.shortName.toUpperCase()} save ($roll) and $actionVerb ${condition.label}!');
          } else {
            logs.add('$displayName succeeded on DC $saveDc ${saveAbility.shortName.toUpperCase()} save ($roll) against ${condition.label}.');
          }
        } else {
          applyActiveCondition(ActiveCondition(condition: condition), edition: edition);
          conditions.add(condition);
          logs.add('$displayName gained ${condition.label}!');
        }
      case AttributeDrainRider(
          :final targetAbility,
          :final diceCount,
          :final diceSides,
          :final flatBonus,
          :final deathAtZero
        ):
        var drain = flatBonus;
        for (var i = 0; i < diceCount; i++) {
          drain += random.nextInt(diceSides) + 1;
        }
        applyAttributeDrain(targetAbility, drain, deathAtZero: deathAtZero);
        logs.add('$displayName had ${targetAbility.shortName.toUpperCase()} drained by $drain!');
      case MaxHpReductionRider(
          :final reductionEqualsDamage,
          :final flatReduction,
          :final deathAtZero
        ):
        final reduction = reductionEqualsDamage ? damageDealt : (flatReduction ?? 0);
        applyMaxHpReduction(reduction, deathAtZero: deathAtZero);
        logs.add("$displayName's hit point maximum was reduced by $reduction!");
      case ForcedMovementRider(:final pullDistanceFeet, :final toMeleeReach):
        if (isAirborne && altitudeInFeet > 0) {
          if (toMeleeReach && altitudeInFeet <= pullDistanceFeet) {
            altitudeInFeet = 0;
            isAirborne = false;
          } else {
            altitudeInFeet = math.max(0, altitudeInFeet - pullDistanceFeet);
          }
        }
        logs.add('$displayName was pulled $pullDistanceFeet ft.!');
      case HealingSupressionRider():
        isHealingSuppressed = true;
        logs.add("$displayName's healing was suppressed!");
      case PeriodicDamageRider():
        break;
    }
    return (logs: logs, conditionsApplied: conditions);
  }

  /// Applies a [PrecomputedAttack] hit to this combatant, including damage and all riders.
  ({int damageDealt, List<String> riderLogs, List<ArenaCondition> conditionsApplied}) applyAttackHit(
    PrecomputedAttack attack, {
    math.Random? rng,
    bool isCrit = false,
    DmRulesEdition edition = DmRulesEdition.v2024,
    int Function(int rawDamage)? damageModifier,
  }) {
    final random = rng ?? math.Random();
    var damage = attack.rollDamage(random, isCrit: isCrit);
    if (damageModifier != null) {
      damage = damageModifier(damage);
    }
    applyDamage(damage);

    final riderLogs = <String>[];
    final conditionsApplied = <ArenaCondition>[];

    for (final rider in attack.riders) {
      final res = applyRider(rider, rng: random, damageDealt: damage, edition: edition);
      riderLogs.addAll(res.logs);
      conditionsApplied.addAll(res.conditionsApplied);
    }
    return (
      damageDealt: damage,
      riderLogs: riderLogs,
      conditionsApplied: conditionsApplied,
    );
  }

  /// Calculates saving throw modifier for a given [AbilityType].
  /// Uses pre-calculated bonuses and dynamically scales with attribute drain.
  int getAbilitySavingThrowBonus(AbilityType ability, [DmRulesEdition edition = DmRulesEdition.v2024]) {
    final key = ability.shortName.toLowerCase();
    final sb = getStatBlock(edition);
    final baseMod = switch (ability) {
      AbilityType.strength => sb.strMod,
      AbilityType.dexterity => sb.dexMod,
      AbilityType.constitution => sb.conMod,
      AbilityType.intelligence => sb.intMod,
      AbilityType.wisdom => sb.wisMod,
      AbilityType.charisma => sb.chaMod,
    };
    final currentMod = getAbilityModifier(ability, edition);
    final modDelta = currentMod - baseMod;

    final cached = savingThrowBonuses[key];
    if (cached != null) return cached + modDelta;
    final profileBonus = monster.getCombatProfile(edition).savingThrowBonuses[key];
    if (profileBonus != null) return profileBonus + modDelta;
    return baseMod + modDelta;
  }

  /// Calculates saving throw modifier for a given ability (e.g. 'dex', 'str', 'con', 'wis', 'int', 'cha').
  /// Uses pre-parsed bonuses to eliminate regex evaluations during Monte Carlo simulation.
  int getSavingThrowBonus(String ability, [DmRulesEdition edition = DmRulesEdition.v2024]) {
    return getAbilitySavingThrowBonus(AbilityType.fromLooseString(ability), edition);
  }
}
