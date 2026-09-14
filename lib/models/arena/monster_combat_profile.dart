import 'dart:math' as math;
import '../domain/character_models.dart';
import '../srd_summons/minion_stat_block.dart';
import '../../domain/simulation/precomputed_attack.dart';
import '../../services/ingestion/stat_block_acl_parser.dart';

/// Pre-calculated, strongly typed combat profile for monster simulation.
/// Decouples text corpus regex parsing from runtime entity instantiation in Arena loops.
class MonsterCombatProfile {
  final Map<String, PrecomputedAttack> attacks;
  final Map<int, int> maxSpellSlots;
  final List<String> knownSpellIds;
  final int spellSaveDc;
  final int spellAttackBonus;
  final int meleeReachInFeet;
  final bool canFly;
  final bool hasHover;
  final int defaultAltitudeInFeet;
  final Map<String, int> savingThrowBonuses;
  final int maxLegendaryActions;
  final int maxLegendaryResistances;
  final bool canSwim;
  final bool canBurrow;
  final bool canClimb;
  final bool hasEvasion;
  final bool hasFlyby;
  final bool hasNimbleEscape;

  const MonsterCombatProfile({
    this.attacks = const {},
    this.maxSpellSlots = const {},
    this.knownSpellIds = const [],
    this.spellSaveDc = 10,
    this.spellAttackBonus = 0,
    this.meleeReachInFeet = 5,
    this.canFly = false,
    this.hasHover = false,
    this.defaultAltitudeInFeet = 0,
    this.savingThrowBonuses = const {},
    this.maxLegendaryActions = 0,
    this.maxLegendaryResistances = 0,
    this.canSwim = false,
    this.canBurrow = false,
    this.canClimb = false,
    this.hasEvasion = false,
    this.hasFlyby = false,
    this.hasNimbleEscape = false,
  });

  /// Strongly-typed saving throw bonus lookup
  int getSaveBonus(AbilityType ability) {
    final key = switch (ability) {
      AbilityType.strength => 'str',
      AbilityType.dexterity => 'dex',
      AbilityType.constitution => 'con',
      AbilityType.intelligence => 'int',
      AbilityType.wisdom => 'wis',
      AbilityType.charisma => 'cha',
    };
    return savingThrowBonuses[key] ?? 0;
  }

  /// Parses a [MinionStatBlock] ONCE during ingestion/load into a reusable [MonsterCombatProfile].
  /// Explicit/incoming fields are validated against our internal Anti-Corruption Layer (ACL) parser,
  /// strictly favoring our internal parser if there is a discrepancy.
  factory MonsterCombatProfile.fromStatBlock(
    MinionStatBlock sb, {
    double challengeRating = 0.0,
  }) {
    // 1. Always evaluate boundary parsing via our Anti-Corruption Layer (ACL)
    final parsed = StatBlockAclParser.parseStatBlockBoundary(
      sb,
      challengeRating: challengeRating,
    );

    // 2. Build saving throws from internal ACL parser, falling back to explicit only if unparsed
    final saveMap = <String, int>{};
    for (final entry in parsed.savingThrows.entries) {
      saveMap[entry.key.shortName.toLowerCase()] = entry.value;
    }
    if (sb.explicitSavingThrows != null) {
      for (final entry in sb.explicitSavingThrows!.entries) {
        final key = entry.key.shortName.toLowerCase();
        saveMap.putIfAbsent(key, () => entry.value);
      }
    }

    // 3. Resolve mobility, reach, traits, and combat metrics favoring internal parser (ACL)
    final maxReach = math.max(sb.explicitMeleeReachFt ?? 5, parsed.maxReachFt);
    final canFly = parsed.canFly || (sb.canFly ?? false);
    final hasHover = parsed.hasHover || (sb.hasHover ?? false);
    final canSwim = parsed.canSwim || sb.speed.toLowerCase().contains('swim');
    final canBurrow = parsed.canBurrow || sb.speed.toLowerCase().contains('burrow');
    final canClimb = parsed.canClimb || sb.speed.toLowerCase().contains('climb');
    final maxLegendaryActions = math.max(sb.legendaryActions.isNotEmpty ? 3 : 0, parsed.maxLegendaryActions);
    final maxLegendaryResistances = math.max(sb.hasLegendaryResistance ? 3 : 0, parsed.maxLegendaryResistances);

    final spellSaveDc = parsed.spellSaveDc != 10
        ? parsed.spellSaveDc
        : (sb.spellSaveDc ?? parsed.spellSaveDc);
    final spellAttackBonus = parsed.spellAttackBonus != 0
        ? parsed.spellAttackBonus
        : (sb.spellAttackBonus ?? parsed.spellAttackBonus);
    final slots = parsed.spellSlots.isNotEmpty
        ? parsed.spellSlots
        : (sb.explicitSpellSlots ?? const {});

    return MonsterCombatProfile(
      attacks: parsed.attacks,
      maxSpellSlots: slots,
      knownSpellIds: parsed.knownSpellIds,
      spellSaveDc: spellSaveDc,
      spellAttackBonus: spellAttackBonus,
      meleeReachInFeet: maxReach,
      canFly: canFly,
      hasHover: hasHover,
      defaultAltitudeInFeet: canFly ? 20 : 0,
      savingThrowBonuses: saveMap,
      maxLegendaryActions: maxLegendaryActions,
      maxLegendaryResistances: maxLegendaryResistances,
      canSwim: canSwim,
      canBurrow: canBurrow,
      canClimb: canClimb,
      hasEvasion: parsed.hasEvasion,
      hasFlyby: parsed.hasFlyby,
      hasNimbleEscape: parsed.hasNimbleEscape,
    );
  }
}
