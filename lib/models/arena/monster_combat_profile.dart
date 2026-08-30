import 'dart:math' as math;
import '../domain/character_models.dart';
import '../srd_summons/minion_stat_block.dart';
import '../../services/ingestion/stat_block_acl_parser.dart';

/// Pre-calculated, strongly typed combat profile for monster simulation.
/// Decouples text corpus regex parsing from runtime entity instantiation in Arena loops.
class MonsterCombatProfile {
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
  /// Zero runtime regex is executed if [sb] contains explicit pre-calculated metrics.
  factory MonsterCombatProfile.fromStatBlock(
    MinionStatBlock sb, {
    double challengeRating = 0.0,
  }) {
    // If stat block already has explicit pre-calculated fields, project directly with zero regex
    if (sb.explicitSpellSlots != null || sb.explicitSavingThrows != null) {
      final pb = _computeProficiencyBonus(challengeRating);
      final castingMod = math.max(sb.intMod, math.max(sb.wisMod, sb.chaMod));

      final saveMap = <String, int>{};
      if (sb.explicitSavingThrows != null) {
        for (final entry in sb.explicitSavingThrows!.entries) {
          saveMap[entry.key.shortName.toLowerCase()] = entry.value;
        }
      } else {
        saveMap['str'] = sb.strMod;
        saveMap['dex'] = sb.dexMod;
        saveMap['con'] = sb.conMod;
        saveMap['int'] = sb.intMod;
        saveMap['wis'] = sb.wisMod;
        saveMap['cha'] = sb.chaMod;
      }

      final canFly = sb.canFly ?? (sb.speed.toLowerCase().contains('fly') && !sb.speed.toLowerCase().contains('fly 0'));

      return MonsterCombatProfile(
        maxSpellSlots: sb.explicitSpellSlots ?? const {},
        knownSpellIds: const [],
        spellSaveDc: sb.spellSaveDc ?? (8 + pb + castingMod),
        spellAttackBonus: sb.spellAttackBonus ?? (pb + castingMod),
        meleeReachInFeet: sb.explicitMeleeReachFt ?? 5,
        canFly: canFly,
        hasHover: sb.hasHover ?? false,
        defaultAltitudeInFeet: canFly ? 20 : 0,
        savingThrowBonuses: saveMap,
        maxLegendaryActions: sb.legendaryActions.isNotEmpty ? 3 : 0,
        maxLegendaryResistances: sb.hasLegendaryResistance ? 3 : 0,
        canSwim: sb.speed.toLowerCase().contains('swim'),
        canBurrow: sb.speed.toLowerCase().contains('burrow'),
        canClimb: sb.speed.toLowerCase().contains('climb'),
      );
    }

    // Otherwise, delegate boundary parsing to the Anti-Corruption Layer (ACL)
    final parsed = StatBlockAclParser.parseStatBlockBoundary(
      sb,
      challengeRating: challengeRating,
    );

    final saveMap = <String, int>{};
    for (final entry in parsed.savingThrows.entries) {
      saveMap[entry.key.shortName.toLowerCase()] = entry.value;
    }

    return MonsterCombatProfile(
      maxSpellSlots: parsed.spellSlots,
      knownSpellIds: parsed.knownSpellIds,
      spellSaveDc: parsed.spellSaveDc,
      spellAttackBonus: parsed.spellAttackBonus,
      meleeReachInFeet: parsed.maxReachFt,
      canFly: parsed.canFly,
      hasHover: parsed.hasHover,
      defaultAltitudeInFeet: parsed.canFly ? 20 : 0,
      savingThrowBonuses: saveMap,
      maxLegendaryActions: parsed.maxLegendaryActions,
      maxLegendaryResistances: parsed.maxLegendaryResistances,
      canSwim: parsed.canSwim,
      canBurrow: parsed.canBurrow,
      canClimb: parsed.canClimb,
      hasEvasion: parsed.hasEvasion,
      hasFlyby: parsed.hasFlyby,
      hasNimbleEscape: parsed.hasNimbleEscape,
    );
  }

  static int _computeProficiencyBonus(double cr) {
    if (cr >= 17) return 6;
    if (cr >= 13) return 5;
    if (cr >= 9) return 4;
    if (cr >= 5) return 3;
    return 2;
  }
}
