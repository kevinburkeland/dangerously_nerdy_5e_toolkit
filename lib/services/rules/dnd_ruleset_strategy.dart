import 'dart:math' as math;
import '../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../models/domain/character_models.dart';
import '../../models/domain/spell_monster_equipment.dart';

/// Weapon Mastery properties introduced in 2024 revision
enum WeaponMasteryProperty {
  cleave,
  graze,
  nick,
  push,
  sap,
  slow,
  topple,
  vex;

  String get displayName => switch (this) {
        WeaponMasteryProperty.cleave => 'Cleave',
        WeaponMasteryProperty.graze => 'Graze',
        WeaponMasteryProperty.nick => 'Nick',
        WeaponMasteryProperty.push => 'Push',
        WeaponMasteryProperty.sap => 'Sap',
        WeaponMasteryProperty.slow => 'Slow',
        WeaponMasteryProperty.topple => 'Topple',
        WeaponMasteryProperty.vex => 'Vex',
      };

  static WeaponMasteryProperty? tryParse(String? name) {
    if (name == null) return null;
    final clean = name.trim().toLowerCase();
    for (final val in WeaponMasteryProperty.values) {
      if (val.name == clean) return val;
    }
    return null;
  }
}

/// Encumbrance tier state
enum EncumbranceTier {
  unencumbered,
  encumbered,
  heavilyEncumbered,
  overCapacity;

  String get displayName => switch (this) {
        EncumbranceTier.unencumbered => 'Unencumbered',
        EncumbranceTier.encumbered => 'Encumbered',
        EncumbranceTier.heavilyEncumbered => 'Heavily Encumbered',
        EncumbranceTier.overCapacity => 'Over Capacity',
      };
}

/// Encumbrance calculation result
class EncumbranceStatus {
  final double totalWeightLbs;
  final double carryCapacityLbs;
  final double pushDragLiftLbs;
  final EncumbranceTier variantTier;
  final int speedPenaltyFeet;
  final bool hasDisadvantageOnD20;

  const EncumbranceStatus({
    required this.totalWeightLbs,
    required this.carryCapacityLbs,
    required this.pushDragLiftLbs,
    required this.variantTier,
    required this.speedPenaltyFeet,
    required this.hasDisadvantageOnD20,
  });
}

/// Evaluated Exhaustion Effects
class ExhaustionEffects {
  final int level;
  final int d20TestPenalty; // 2024: -2 * level
  final int speedReductionFeet; // 2024: -5 * level
  final double speedMultiplier; // 2014: 0.5 at tier 2, 0.0 at tier 5
  final double maxHpMultiplier; // 2014: 0.5 at tier 4
  final bool hasDisadvantageOnAbilityChecks; // 2014 tier 1
  final bool hasDisadvantageOnAttacksAndSaves; // 2014 tier 3
  final bool isDead; // tier 6

  const ExhaustionEffects({
    required this.level,
    this.d20TestPenalty = 0,
    this.speedReductionFeet = 0,
    this.speedMultiplier = 1.0,
    this.maxHpMultiplier = 1.0,
    this.hasDisadvantageOnAbilityChecks = false,
    this.hasDisadvantageOnAttacksAndSaves = false,
    this.isDead = false,
  });
}

/// Abstract strategy defining ruleset differences between 2014 and 2024 D&D 5e
abstract class RulesetStrategy {
  DmRulesEdition get edition;

  /// Multiclass effective caster level calculation
  int calculateEffectiveCasterLevel({
    int fullCasterLevels = 0,
    int paladinLevels = 0,
    int rangerLevels = 0,
    int artificerLevels = 0,
    int thirdCasterLevels = 0,
  });

  /// Evaluates exhaustion penalties for the active ruleset
  ExhaustionEffects evaluateExhaustion(int exhaustionLevel);

  /// Computes Grapple & Shove Save DC or description
  ({int? dc, String formulaDescription}) calculateGrappleShoveDc({
    required int strengthModifier,
    required int dexterityModifier,
    required int proficiencyBonus,
  });

  /// Validates whether a character can use a weapon's mastery property
  bool canUseWeaponMastery({
    required Character character,
    required EquipmentItem weapon,
    required WeaponMasteryProperty mastery,
  });

  /// Computes character inventory encumbrance
  EncumbranceStatus calculateEncumbrance({
    required int strengthScore,
    required List<InventoryItemInstance> inventory,
    required int totalCoinCount,
    bool isPowerfulBuildOrLarge = false,
  });

  static RulesetStrategy forEdition(DmRulesEdition edition) {
    return switch (edition) {
      DmRulesEdition.v2024 => const Ruleset2024Strategy(),
      DmRulesEdition.v2014 || DmRulesEdition.comparative => const Ruleset2014Strategy(),
    };
  }
}

/// 2014 Rules-as-Written Strategy
class Ruleset2014Strategy implements RulesetStrategy {
  const Ruleset2014Strategy();

  @override
  DmRulesEdition get edition => DmRulesEdition.v2014;

  @override
  int calculateEffectiveCasterLevel({
    int fullCasterLevels = 0,
    int paladinLevels = 0,
    int rangerLevels = 0,
    int artificerLevels = 0,
    int thirdCasterLevels = 0,
  }) {
    // 2014 RAW: Paladin & Ranger round down per class, Third Casters round down, Artificer rounds up
    final effective = fullCasterLevels +
        (paladinLevels ~/ 2) +
        (rangerLevels ~/ 2) +
        ((artificerLevels + 1) ~/ 2) +
        (thirdCasterLevels ~/ 3);
    return effective.clamp(0, 20);
  }

  @override
  ExhaustionEffects evaluateExhaustion(int exhaustionLevel) {
    final lvl = exhaustionLevel.clamp(0, 6);
    if (lvl == 0) return const ExhaustionEffects(level: 0);

    return ExhaustionEffects(
      level: lvl,
      d20TestPenalty: 0,
      speedReductionFeet: 0,
      speedMultiplier: lvl >= 5 ? 0.0 : (lvl >= 2 ? 0.5 : 1.0),
      maxHpMultiplier: lvl >= 4 ? 0.5 : 1.0,
      hasDisadvantageOnAbilityChecks: lvl >= 1,
      hasDisadvantageOnAttacksAndSaves: lvl >= 3,
      isDead: lvl >= 6,
    );
  }

  @override
  ({int? dc, String formulaDescription}) calculateGrappleShoveDc({
    required int strengthModifier,
    required int dexterityModifier,
    required int proficiencyBonus,
  }) {
    // 2014: Contested Athletics check vs Athletics/Acrobatics
    final strAthleticsBonus = strengthModifier + proficiencyBonus;
    final bonusStr = strAthleticsBonus >= 0 ? '+$strAthleticsBonus' : '$strAthleticsBonus';
    return (
      dc: null,
      formulaDescription: 'Contested Athletics ($bonusStr) vs Target Athletics/Acrobatics',
    );
  }

  @override
  bool canUseWeaponMastery({
    required Character character,
    required EquipmentItem weapon,
    required WeaponMasteryProperty mastery,
  }) {
    // 2014 rules did not have Weapon Mastery properties
    return false;
  }

  @override
  EncumbranceStatus calculateEncumbrance({
    required int strengthScore,
    required List<InventoryItemInstance> inventory,
    required int totalCoinCount,
    bool isPowerfulBuildOrLarge = false,
  }) {
    final multiplier = isPowerfulBuildOrLarge ? 2 : 1;
    final carryCapacity = (strengthScore * 15 * multiplier).toDouble();
    final pushDragLift = (strengthScore * 30 * multiplier).toDouble();

    double totalWeight = 0.0;
    for (final item in inventory) {
      final weightPerUnit = (item.customProperties['weightLbs'] as num?)?.toDouble() ??
          (item.customProperties['weight'] as num?)?.toDouble() ??
          0.0;
      totalWeight += weightPerUnit * item.quantity;
    }
    // 50 coins = 1 lb
    totalWeight += (totalCoinCount / 50.0);

    final encumberedThreshold = strengthScore * 5 * multiplier;
    final heavilyEncumberedThreshold = strengthScore * 10 * multiplier;

    EncumbranceTier tier;
    int speedPenalty = 0;
    bool hasDisadvantage = false;

    if (totalWeight > carryCapacity) {
      tier = EncumbranceTier.overCapacity;
      speedPenalty = 20;
      hasDisadvantage = true;
    } else if (totalWeight > heavilyEncumberedThreshold) {
      tier = EncumbranceTier.heavilyEncumbered;
      speedPenalty = 20;
      hasDisadvantage = true;
    } else if (totalWeight > encumberedThreshold) {
      tier = EncumbranceTier.encumbered;
      speedPenalty = 10;
      hasDisadvantage = false;
    } else {
      tier = EncumbranceTier.unencumbered;
    }

    return EncumbranceStatus(
      totalWeightLbs: totalWeight,
      carryCapacityLbs: carryCapacity,
      pushDragLiftLbs: pushDragLift,
      variantTier: tier,
      speedPenaltyFeet: speedPenalty,
      hasDisadvantageOnD20: hasDisadvantage,
    );
  }
}

/// 2024 Revised Rules Strategy
class Ruleset2024Strategy implements RulesetStrategy {
  const Ruleset2024Strategy();

  @override
  DmRulesEdition get edition => DmRulesEdition.v2024;

  @override
  int calculateEffectiveCasterLevel({
    int fullCasterLevels = 0,
    int paladinLevels = 0,
    int rangerLevels = 0,
    int artificerLevels = 0,
    int thirdCasterLevels = 0,
  }) {
    // 2024 RAW: Half Casters (Paladin, Ranger, Artificer) round UP (ceil(level / 2)),
    // Third Casters (Eldritch Knight, Arcane Trickster) round UP (ceil(level / 3))
    final paladinEcl = (paladinLevels + 1) ~/ 2;
    final rangerEcl = (rangerLevels + 1) ~/ 2;
    final artificerEcl = (artificerLevels + 1) ~/ 2;
    final thirdEcl = thirdCasterLevels > 0 ? ((thirdCasterLevels + 2) ~/ 3) : 0;

    final effective = fullCasterLevels + paladinEcl + rangerEcl + artificerEcl + thirdEcl;
    return effective.clamp(0, 20);
  }

  @override
  ExhaustionEffects evaluateExhaustion(int exhaustionLevel) {
    final lvl = exhaustionLevel.clamp(0, 6);
    if (lvl == 0) return const ExhaustionEffects(level: 0);

    return ExhaustionEffects(
      level: lvl,
      d20TestPenalty: -2 * lvl,
      speedReductionFeet: 5 * lvl,
      speedMultiplier: 1.0,
      maxHpMultiplier: 1.0,
      hasDisadvantageOnAbilityChecks: false,
      hasDisadvantageOnAttacksAndSaves: false,
      isDead: lvl >= 6,
    );
  }

  @override
  ({int? dc, String formulaDescription}) calculateGrappleShoveDc({
    required int strengthModifier,
    required int dexterityModifier,
    required int proficiencyBonus,
  }) {
    // 2024: Save DC = 8 + STR mod + PB (or DEX if chosen/specialized)
    final bestMod = math.max(strengthModifier, dexterityModifier);
    final dc = 8 + proficiencyBonus + bestMod;
    return (
      dc: dc,
      formulaDescription: 'DC $dc (8 + PB + ${bestMod == strengthModifier ? "STR" : "DEX"} Mod)',
    );
  }

  static const _masteryEligibleClasses = {
    'fighter',
    'barbarian',
    'rogue',
    'paladin',
    'ranger',
  };

  @override
  bool canUseWeaponMastery({
    required Character character,
    required EquipmentItem weapon,
    required WeaponMasteryProperty mastery,
  }) {
    // 1. Check if character class possesses Weapon Mastery feature
    final hasMasteryClass = character.progression.classes.any(
      (c) => _masteryEligibleClasses.contains(c.classRef.slug.toLowerCase()),
    );
    if (!hasMasteryClass) return false;

    // 2. Check if weapon supports this mastery property
    final weaponMasteryProp = weapon.customProperties['mastery']?.toString().toLowerCase() ??
        weapon.customProperties['weaponMastery']?.toString().toLowerCase();

    if (weaponMasteryProp == null) return false;
    return weaponMasteryProp == mastery.name.toLowerCase();
  }

  @override
  EncumbranceStatus calculateEncumbrance({
    required int strengthScore,
    required List<InventoryItemInstance> inventory,
    required int totalCoinCount,
    bool isPowerfulBuildOrLarge = false,
  }) {
    final multiplier = isPowerfulBuildOrLarge ? 2 : 1;
    final carryCapacity = (strengthScore * 15 * multiplier).toDouble();
    final pushDragLift = (strengthScore * 30 * multiplier).toDouble();

    double totalWeight = 0.0;
    for (final item in inventory) {
      final weightPerUnit = (item.customProperties['weightLbs'] as num?)?.toDouble() ??
          (item.customProperties['weight'] as num?)?.toDouble() ??
          0.0;
      totalWeight += weightPerUnit * item.quantity;
    }
    totalWeight += (totalCoinCount / 50.0);

    final encumberedThreshold = strengthScore * 5 * multiplier;
    final heavilyEncumberedThreshold = strengthScore * 10 * multiplier;

    EncumbranceTier tier;
    int speedPenalty = 0;
    bool hasDisadvantage = false;

    if (totalWeight > carryCapacity) {
      tier = EncumbranceTier.overCapacity;
      speedPenalty = 20;
      hasDisadvantage = true;
    } else if (totalWeight > heavilyEncumberedThreshold) {
      tier = EncumbranceTier.heavilyEncumbered;
      speedPenalty = 20;
      hasDisadvantage = true;
    } else if (totalWeight > encumberedThreshold) {
      tier = EncumbranceTier.encumbered;
      speedPenalty = 10;
      hasDisadvantage = false;
    } else {
      tier = EncumbranceTier.unencumbered;
    }

    return EncumbranceStatus(
      totalWeightLbs: totalWeight,
      carryCapacityLbs: carryCapacity,
      pushDragLiftLbs: pushDragLift,
      variantTier: tier,
      speedPenaltyFeet: speedPenalty,
      hasDisadvantageOnD20: hasDisadvantage,
    );
  }
}
