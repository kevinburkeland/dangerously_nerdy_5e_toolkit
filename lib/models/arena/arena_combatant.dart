import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../dm_screen_data.dart';
import '../monster_codex_data.dart';
import '../spellbook_data.dart';
import '../srd_summons/minion_stat_block.dart';
import 'arena_condition.dart';
export 'arena_condition.dart';

/// Which team the combatant belongs to in the Arena.
enum ArenaTeam {
  teamA('Team Crimson', Color(0xFFEF4444), Icons.shield_moon),
  teamB('Team Cobalt', Color(0xFF3B82F6), Icons.shield_outlined);

  final String label;
  final Color color;
  final IconData icon;
  const ArenaTeam(this.label, this.color, this.icon);

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

    // Pre-parse spellcasting attributes once
    final parsedSlots = _parseMonsterSpellSlots(sb);
    final parsedKnownSpells = _parseMonsterKnownSpellIds(sb);
    final parsedDc = _parseMonsterSpellSaveDc(sb, monster.challengeRating);
    final parsedAttackBonus = _parseMonsterSpellAttackBonus(sb, monster.challengeRating);

    // Aerial combat & reach parsing
    final flySpeed = sb.speed.toLowerCase();
    final traitsText = sb.traits.map((t) => '${t.name} ${t.description}').join(' ').toLowerCase();
    final canFlyMonster = flySpeed.contains('fly') && !flySpeed.contains('fly 0');
    final hoverCapability = flySpeed.contains('hover') || traitsText.contains('hover');
    final parsedReach = _parseMonsterMeleeReach(sb);
    final parsedLegendaryActions = _parseMonsterLegendaryActions(sb);
    final parsedLegendaryResistances = _parseMonsterLegendaryResistances(sb);

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
      isAirborne: canFlyMonster,
      hasHover: hoverCapability,
      altitudeInFeet: canFlyMonster ? 20 : 0,
      meleeReachInFeet: parsedReach,
      conditions: {},
      maxSpellSlots: parsedSlots,
      currentSpellSlots: Map<int, int>.from(parsedSlots),
      knownSpellIds: parsedKnownSpells,
      spellSaveDc: parsedDc,
      spellAttackBonus: parsedAttackBonus,
      activeConcentrationSpellId: null,
      usedReactionThisRound: false,
      castBonusActionSpellThisTurn: false,
      temporaryAcBonus: 0,
      maxLegendaryActions: parsedLegendaryActions,
      maxLegendaryResistances: parsedLegendaryResistances,
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

  // --- Hoisted Static Regular Expressions ---
  static final RegExp _slotPattern = RegExp(
    r'(\d+)(?:st|nd|rd|th)[ -]level\s*\((\d+)\s*slots?\)',
    caseSensitive: false,
  );
  static final RegExp _casterLvlPattern = RegExp(
    r'(\d+)(?:st|nd|rd|th)-level spellcaster',
    caseSensitive: false,
  );
  static final RegExp _spellSaveDcPattern = RegExp(
    r'spell save DC\s*(\d+)',
    caseSensitive: false,
  );
  static final RegExp _spellAttackPattern = RegExp(
    r'([+-]?\d+)\s+to hit with spell attacks',
    caseSensitive: false,
  );
  static final RegExp _reachPattern = RegExp(
    r'reach\s*(\d+)\s*ft',
    caseSensitive: false,
  );
  static final RegExp _rechargeDayPattern = RegExp(
    r'\((\d+)/day\)',
    caseSensitive: false,
  );
  static final Map<String, RegExp> _spellWordPatterns = {};
  static final Map<String, RegExp> _abilitySavePatterns = {};

  // --- Static Pre-Parsing Helpers ---

  static Map<int, int> _parseMonsterSpellSlots(MinionStatBlock sb) {
    final slots = <int, int>{};
    final corpus = _buildMonsterSpellCorpus(sb);
    if (corpus.isEmpty) return slots;

    // 1. Check explicit slot regex, e.g. "1st level (4 slots)" or "3rd-level (3 slots)"
    for (final match in _slotPattern.allMatches(corpus)) {
      final lvl = int.tryParse(match.group(1) ?? '');
      final count = int.tryParse(match.group(2) ?? '');
      if (lvl != null && count != null && lvl >= 1 && lvl <= 9) {
        slots[lvl] = count;
      }
    }

    // 2. Fallback to caster level progression if slots weren't explicitly enumerated
    if (slots.isEmpty) {
      final casterLvlMatch = _casterLvlPattern.firstMatch(corpus);
      if (casterLvlMatch != null) {
        final casterLevel = int.tryParse(casterLvlMatch.group(1) ?? '') ?? 1;
        final matrix = MulticlassSlotMatrix.getSpellSlots(casterLevel);
        for (int i = 0; i < matrix.length; i++) {
          if (matrix[i] > 0) slots[i + 1] = matrix[i];
        }
      }
    }

    // 3. Innate Spellcasting slot emulation (e.g. 1/Day, 3/Day) if no standard slots exist
    if (slots.isEmpty && (corpus.contains('/day') || corpus.contains('at will'))) {
      // Find known spells and grant appropriate slots
      for (final spell in SpellbookLibrary.allSpells) {
        if (spell.level > 0 && _containsSpellWord(corpus, spell.name)) {
          slots[spell.level] = (slots[spell.level] ?? 0) + 1;
        }
      }
    }

    return slots;
  }

  static List<String> _parseMonsterKnownSpellIds(MinionStatBlock sb) {
    final known = <String>{};
    final corpus = _buildMonsterSpellCorpus(sb);
    if (corpus.isEmpty) return const [];

    for (final spell in SpellbookLibrary.allSpells) {
      if (_containsSpellWord(corpus, spell.name)) {
        known.add(spell.id);
      }
    }

    return known.toList();
  }

  static String _buildMonsterSpellCorpus(MinionStatBlock sb) {
    final buffer = StringBuffer();
    for (final t in sb.traits) {
      final nameLower = t.name.toLowerCase();
      if (nameLower.contains('spell') ||
          nameLower.contains('magic') ||
          nameLower.contains('casting') ||
          nameLower.contains('pact') ||
          nameLower.contains('innate')) {
        buffer.writeln('${t.name}: ${t.description}');
      }
    }
    for (final a in sb.actions) {
      final nameLower = a.name.toLowerCase();
      if (nameLower.contains('spell') || nameLower.contains('cast')) {
        buffer.writeln('${a.name}: ${a.description}');
      }
    }
    return buffer.toString().toLowerCase().replaceAll('_', ' ').replaceAll('*', ' ');
  }

  static int _parseMonsterSpellSaveDc(MinionStatBlock sb, double cr) {
    final corpus = _buildMonsterCorpus(sb);
    final match = _spellSaveDcPattern.firstMatch(corpus);
    if (match != null) {
      final val = int.tryParse(match.group(1) ?? '');
      if (val != null) return val;
    }

    final pb = _computeProficiencyBonus(cr);
    final castingMod = math.max(sb.intMod, math.max(sb.wisMod, sb.chaMod));
    return 8 + pb + castingMod;
  }

  static int _parseMonsterSpellAttackBonus(MinionStatBlock sb, double cr) {
    final corpus = _buildMonsterCorpus(sb);
    final match = _spellAttackPattern.firstMatch(corpus);
    if (match != null) {
      final val = int.tryParse(match.group(1)!.replaceAll('+', ''));
      if (val != null) return val;
    }

    final pb = _computeProficiencyBonus(cr);
    final castingMod = math.max(sb.intMod, math.max(sb.wisMod, sb.chaMod));
    return pb + castingMod;
  }

  static int _computeProficiencyBonus(double cr) {
    if (cr >= 17) return 6;
    if (cr >= 13) return 5;
    if (cr >= 9) return 4;
    if (cr >= 5) return 3;
    return 2;
  }

  static int _parseMonsterMeleeReach(MinionStatBlock sb) {
    int maxReach = 5;
    for (final a in sb.actions) {
      final match = _reachPattern.firstMatch(a.description);
      if (match != null) {
        final r = int.tryParse(match.group(1) ?? '') ?? 5;
        if (r > maxReach) maxReach = r;
      }
    }
    return maxReach;
  }

  static int _parseMonsterLegendaryActions(MinionStatBlock sb) {
    if (sb.legendaryActions.isNotEmpty) return 3;
    final corpus = _buildMonsterCorpus(sb);
    if (corpus.contains('legendary action')) return 3;
    return 0;
  }

  static int _parseMonsterLegendaryResistances(MinionStatBlock sb) {
    for (final t in sb.traits) {
      if (t.name.toLowerCase().contains('legendary resistance')) {
        final match = _rechargeDayPattern.firstMatch(t.name);
        if (match != null) {
          final count = int.tryParse(match.group(1) ?? '');
          if (count != null) return count;
        }
        return 3;
      }
    }
    return 0;
  }

  static String _buildMonsterCorpus(MinionStatBlock sb) {
    final buffer = StringBuffer();
    for (final t in sb.traits) {
      buffer.writeln('${t.name}: ${t.description}');
    }
    for (final a in sb.actions) {
      buffer.writeln('${a.name}: ${a.description}');
    }
    for (final r in sb.reactions) {
      buffer.writeln('${r.name}: ${r.description}');
    }
    if (sb.specialTrait != null) {
      buffer.writeln(sb.specialTrait);
    }
    return buffer.toString().toLowerCase().replaceAll('_', ' ').replaceAll('*', ' ');
  }

  static bool _containsSpellWord(String corpus, String spellName) {
    final lowerName = spellName.toLowerCase();
    final cleanCorpus = corpus.replaceAll('_', ' ').replaceAll('*', ' ');
    final pattern = _spellWordPatterns.putIfAbsent(
      lowerName,
      () => RegExp('\\b${RegExp.escape(lowerName)}\\b', caseSensitive: false),
    );
    return pattern.hasMatch(cleanCorpus);
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
    final s = getStatBlock(edition).speed.toLowerCase();
    return s.contains('fly') && !s.contains('fly 0');
  }

  bool canSwim([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final sb = getStatBlock(edition);
    final s = sb.speed.toLowerCase();
    final traits = sb.traits.map((t) => '${t.name} ${t.description}').join(' ').toLowerCase();
    return s.contains('swim') || traits.contains('amphibious') || traits.contains('water breathing');
  }

  bool canBurrow([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return getStatBlock(edition).speed.toLowerCase().contains('burrow');
  }

  bool canClimb([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return getStatBlock(edition).speed.toLowerCase().contains('climb');
  }

  bool hasEvasion([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final sb = getStatBlock(edition);
    final traits = sb.traits.map((t) => '${t.name} ${t.description}').join(' ').toLowerCase();
    final acts = sb.actions.map((a) => '${a.name} ${a.description}').join(' ').toLowerCase();
    return traits.contains('evasion') || acts.contains('evasion');
  }

  bool hasFlyby([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final sb = getStatBlock(edition);
    final traits = sb.traits.map((t) => '${t.name} ${t.description}').join(' ').toLowerCase();
    return traits.contains('flyby');
  }

  bool hasNimbleEscape([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final sb = getStatBlock(edition);
    final traits = sb.traits.map((t) => '${t.name} ${t.description}').join(' ').toLowerCase();
    return traits.contains('nimble escape');
  }

  /// Calculates saving throw modifier for a given ability (e.g. 'dex', 'str', 'con', 'wis', 'int', 'cha').
  int getSavingThrowBonus(String ability, [DmRulesEdition edition = DmRulesEdition.v2024]) {
    final sb = getStatBlock(edition);
    final abLower = ability.toLowerCase().trim();

    // Check explicit saving throw text like "Dex +5, Con +8"
    final rawSaves = sb.savingThrows;
    if (rawSaves != null && rawSaves.isNotEmpty) {
      final pattern = _abilitySavePatterns.putIfAbsent(
        abLower,
        () => RegExp(
          '\\b(?:${RegExp.escape(abLower)}|${_expandAbilityName(abLower)})\\s*([+-]?\\s*\\d+)',
          caseSensitive: false,
        ),
      );
      final match = pattern.firstMatch(rawSaves);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!.replaceAll(' ', ''));
        if (parsed != null) return parsed;
      }
    }

    // Fallback to raw ability modifier
    switch (abLower) {
      case 'str':
        return sb.strMod;
      case 'dex':
        return sb.dexMod;
      case 'con':
        return sb.conMod;
      case 'int':
        return sb.intMod;
      case 'wis':
        return sb.wisMod;
      case 'cha':
        return sb.chaMod;
      default:
        return sb.dexMod;
    }
  }

  static String _expandAbilityName(String ab) {
    switch (ab.toLowerCase()) {
      case 'str':
        return 'strength';
      case 'dex':
        return 'dexterity';
      case 'con':
        return 'constitution';
      case 'int':
        return 'intelligence';
      case 'wis':
        return 'wisdom';
      case 'cha':
        return 'charisma';
      default:
        return ab;
    }
  }
}
