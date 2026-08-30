import 'dart:math' as math;
import '../dm_screen_data.dart';
import '../monster_codex_data.dart';
import '../srd_summons/minion_stat_block.dart';
import 'arena_condition.dart';
import 'monster_combat_profile.dart';
export 'arena_condition.dart';
export 'monster_combat_profile.dart';

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
  final int maxHp;
  int currentHp;
  int tempHp;
  final int ac;
  final int initiativeBonus;
  int initiative;
  bool isRechargeReady;

  // Aerial Combat & Reach State
  bool isAirborne;
  final bool hasHover;
  int altitudeInFeet;
  int meleeReachInFeet;
  final Set<ArenaCondition> conditions;
  final List<ActiveCondition> activeConditions;

  // Spellcasting State & Pre-Cached Attributes
  Map<int, int> currentSpellSlots;
  final Map<int, int> maxSpellSlots;
  final List<String> knownSpellIds;
  final int spellSaveDc;
  final int spellAttackBonus;
  final Map<String, int> savingThrowBonuses;
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

  ArenaCombatant({
    required this.id,
    required this.monster,
    required this.team,
    required this.displayName,
    required this.maxHp,
    required this.currentHp,
    this.tempHp = 0,
    required this.ac,
    required this.initiativeBonus,
    this.initiative = 0,
    this.isRechargeReady = true,
    this.isAirborne = false,
    this.hasHover = false,
    this.altitudeInFeet = 0,
    this.meleeReachInFeet = 5,
    Set<ArenaCondition>? conditions,
    List<ActiveCondition>? activeConditions,
    Map<int, int>? currentSpellSlots,
    Map<int, int>? maxSpellSlots,
    List<String>? knownSpellIds,
    this.spellSaveDc = 10,
    this.spellAttackBonus = 0,
    Map<String, int>? savingThrowBonuses,
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
  })  : conditions = conditions != null
            ? Set<ArenaCondition>.from(conditions)
            : (activeConditions != null
                ? activeConditions.map((a) => a.condition).toSet()
                : {}),
        activeConditions = activeConditions != null
            ? List<ActiveCondition>.from(activeConditions)
            : (conditions != null
                ? conditions.map((c) => ActiveCondition(condition: c)).toList()
                : []),
        maxSpellSlots = maxSpellSlots != null ? Map<int, int>.from(maxSpellSlots) : {},
        currentSpellSlots = currentSpellSlots != null
            ? Map<int, int>.from(currentSpellSlots)
            : (maxSpellSlots != null ? Map<int, int>.from(maxSpellSlots) : {}),
        knownSpellIds = knownSpellIds != null ? List<String>.from(knownSpellIds) : [],
        savingThrowBonuses = savingThrowBonuses != null ? Map<String, int>.from(savingThrowBonuses) : const {},
        legendaryActionsRemaining = legendaryActionsRemaining ?? maxLegendaryActions,
        legendaryResistancesRemaining = legendaryResistancesRemaining ?? maxLegendaryResistances;

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
      conditions: {},
      maxSpellSlots: profile.maxSpellSlots,
      currentSpellSlots: Map<int, int>.from(profile.maxSpellSlots),
      knownSpellIds: profile.knownSpellIds,
      spellSaveDc: profile.spellSaveDc,
      spellAttackBonus: profile.spellAttackBonus,
      savingThrowBonuses: profile.savingThrowBonuses,
      activeConcentrationSpellId: null,
      usedReactionThisRound: false,
      castBonusActionSpellThisTurn: false,
      temporaryAcBonus: 0,
      maxLegendaryActions: profile.maxLegendaryActions,
      maxLegendaryResistances: profile.maxLegendaryResistances,
    );
  }

  bool get isAlive => currentHp > 0;
  bool get isDefeated => currentHp <= 0;
  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  /// Applies an [ActiveCondition] with optional duration and source effect tracking.
  ({int fallDamage, bool fell, String? log}) applyActiveCondition(
    ActiveCondition activeCondition, {
    int Function(int sides)? diceRoller,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    conditions.add(activeCondition.condition);
    final idx = activeConditions.indexWhere((a) => a.condition == activeCondition.condition);
    if (idx >= 0) {
      activeConditions[idx] = activeCondition;
    } else {
      activeConditions.add(activeCondition);
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
    conditions.add(condition);
    final idx = activeConditions.indexWhere((a) => a.condition == condition);
    final active = ActiveCondition(
      condition: condition,
      durationRounds: durationRounds,
      source: source,
    );
    if (idx >= 0) {
      activeConditions[idx] = active;
    } else {
      activeConditions.add(active);
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
        conditions.add(ArenaCondition.prone);
        if (!activeConditions.any((a) => a.condition == ArenaCondition.prone)) {
          activeConditions.add(const ActiveCondition(condition: ArenaCondition.prone));
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
    conditions.remove(condition);
    activeConditions.removeWhere((a) => a.condition == condition);
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
    for (int i = activeConditions.length - 1; i >= 0; i--) {
      final active = activeConditions[i];
      if (active.hasFiniteDuration) {
        final updated = active.tickTurn();
        if (updated.isExpired) {
          expired.add(active.condition);
          activeConditions.removeAt(i);
          conditions.remove(active.condition);
        } else {
          activeConditions[i] = updated;
        }
      }
    }
    return expired;
  }

  void clearConditions() {
    conditions.clear();
    activeConditions.clear();
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
      conditions: {},
      activeConditions: [],
      maxSpellSlots: Map<int, int>.from(maxSpellSlots),
      currentSpellSlots: Map<int, int>.from(maxSpellSlots),
      knownSpellIds: List<String>.from(knownSpellIds),
      spellSaveDc: spellSaveDc,
      spellAttackBonus: spellAttackBonus,
      savingThrowBonuses: Map<String, int>.from(savingThrowBonuses),
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
      conditions: Set<ArenaCondition>.from(conditions),
      activeConditions: List<ActiveCondition>.from(activeConditions),
      maxSpellSlots: Map<int, int>.from(maxSpellSlots),
      currentSpellSlots: Map<int, int>.from(currentSpellSlots),
      knownSpellIds: List<String>.from(knownSpellIds),
      spellSaveDc: spellSaveDc,
      spellAttackBonus: spellAttackBonus,
      savingThrowBonuses: Map<String, int>.from(savingThrowBonuses),
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
    int remaining = damage;
    if (tempHp > 0) {
      if (tempHp >= remaining) {
        tempHp -= remaining;
        remaining = 0;
      } else {
        remaining -= tempHp;
        tempHp = 0;
      }
    }
    currentHp = (currentHp - remaining).clamp(0, maxHp);
    totalDamageTaken += damage;
    return damage;
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

  /// Calculates saving throw modifier for a given ability (e.g. 'dex', 'str', 'con', 'wis', 'int', 'cha').
  /// Uses pre-parsed bonuses to eliminate regex evaluations during Monte Carlo simulation.
  int getSavingThrowBonus(String ability, [DmRulesEdition edition = DmRulesEdition.v2024]) {
    final abLower = ability.toLowerCase().trim();
    final cached = savingThrowBonuses[abLower];
    if (cached != null) return cached;
    return monster.getCombatProfile(edition).savingThrowBonuses[abLower] ?? getStatBlock(edition).dexMod;
  }
}
