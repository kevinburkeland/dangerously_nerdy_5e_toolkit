import 'dart:math';
import '../../models/dm_screen_data.dart';
import '../../models/domain/character_models.dart';
import '../../models/spellbook_data.dart';
import '../../utils/secure_random.dart';

/// Pure 5e Rules-as-Written (RAW) calculation engine for spellcasting, multiclassing,
/// slot matrices, cantrip scaling, upcasting, concentration DCs, and components.

// ============================================================================
// 1. MULTICLASS SPELL SLOTS & PACT MAGIC
// ============================================================================

class MulticlassSlotMatrix {
  MulticlassSlotMatrix._();

  static const Map<int, List<int>> _standardSlotProgression = {
    1: [2, 0, 0, 0, 0, 0, 0, 0, 0],
    2: [3, 0, 0, 0, 0, 0, 0, 0, 0],
    3: [4, 2, 0, 0, 0, 0, 0, 0, 0],
    4: [4, 3, 0, 0, 0, 0, 0, 0, 0],
    5: [4, 3, 2, 0, 0, 0, 0, 0, 0],
    6: [4, 3, 3, 0, 0, 0, 0, 0, 0],
    7: [4, 3, 3, 1, 0, 0, 0, 0, 0],
    8: [4, 3, 3, 2, 0, 0, 0, 0, 0],
    9: [4, 3, 3, 3, 1, 0, 0, 0, 0],
    10: [4, 3, 3, 3, 2, 0, 0, 0, 0],
    11: [4, 3, 3, 3, 2, 1, 0, 0, 0],
    12: [4, 3, 3, 3, 2, 1, 0, 0, 0],
    13: [4, 3, 3, 3, 2, 1, 1, 0, 0],
    14: [4, 3, 3, 3, 2, 1, 1, 0, 0],
    15: [4, 3, 3, 3, 2, 1, 1, 1, 0],
    16: [4, 3, 3, 3, 2, 1, 1, 1, 0],
    17: [4, 3, 3, 3, 2, 1, 1, 1, 1],
    18: [4, 3, 3, 3, 3, 1, 1, 1, 1],
    19: [4, 3, 3, 3, 3, 2, 1, 1, 1],
    20: [4, 3, 3, 3, 3, 2, 2, 1, 1],
  };

  /// Returns the 9-element list of spell slots (1st to 9th level) for a given effective caster level.
  static List<int> getSpellSlots(int effectiveCasterLevel) {
    if (effectiveCasterLevel <= 0) return List.filled(9, 0);
    return List<int>.from(_standardSlotProgression[effectiveCasterLevel.clamp(1, 20)] ?? List.filled(9, 0));
  }

  /// Computes RAW Effective Spellcaster Level for multiclass characters across 2014 & 2024 editions:
  /// - 2014: Full (1:1), Paladin/Ranger floor(lvl/2), Artificer ceil(lvl/2), 1/3-caster floor(lvl/3)
  /// - 2024: Full (1:1), Paladin/Ranger/Artificer ceil(lvl/2), 1/3-caster ceil(lvl/3)
  static int calculateEffectiveCasterLevel({
    int fullCasterLevels = 0,
    int paladinLevels = 0,
    int rangerLevels = 0,
    int artificerLevels = 0,
    int thirdCasterLevels = 0,
    DmRulesEdition edition = DmRulesEdition.v2014,
  }) {
    if (edition == DmRulesEdition.v2024) {
      final paladinEcl = (paladinLevels + 1) ~/ 2;
      final rangerEcl = (rangerLevels + 1) ~/ 2;
      final artificerEcl = (artificerLevels + 1) ~/ 2;
      final thirdEcl = thirdCasterLevels > 0 ? ((thirdCasterLevels + 2) ~/ 3) : 0;
      final effective = fullCasterLevels + paladinEcl + rangerEcl + artificerEcl + thirdEcl;
      return effective.clamp(0, 20);
    } else {
      final effective = fullCasterLevels +
          (paladinLevels ~/ 2) +
          (rangerLevels ~/ 2) +
          ((artificerLevels + 1) ~/ 2) +
          (thirdCasterLevels ~/ 3);
      return effective.clamp(0, 20);
    }
  }

  /// Calculates complete SpellSlotPool for a Character adhering to 2014/2024 RAW rules.
  static SpellSlotPool calculateSpellSlots(Character character) {
    int fullCasterLevels = 0;
    int paladinLevels = 0;
    int rangerLevels = 0;
    int artificerLevels = 0;
    int thirdCasterLevels = 0;
    int warlockLevels = 0;

    for (final cls in character.progression.classes) {
      final slug = cls.classRef.slug.toLowerCase();
      switch (slug) {
        case 'wizard':
        case 'cleric':
        case 'druid':
        case 'bard':
        case 'sorcerer':
          fullCasterLevels += cls.level;
        case 'paladin':
          paladinLevels += cls.level;
        case 'ranger':
          rangerLevels += cls.level;
        case 'artificer':
          artificerLevels += cls.level;
        case 'warlock':
          warlockLevels += cls.level;
      }

      final subSlug = cls.subclassRef?.slug.toLowerCase() ?? '';
      if (subSlug.contains('eldritch_knight') ||
          subSlug.contains('arcane_trickster') ||
          subSlug.contains('eldritch-knight') ||
          subSlug.contains('arcane-trickster')) {
        thirdCasterLevels += cls.level;
      }
    }

    final totalCasterClasses = (fullCasterLevels > 0 ? 1 : 0) +
        (paladinLevels > 0 ? 1 : 0) +
        (rangerLevels > 0 ? 1 : 0) +
        (artificerLevels > 0 ? 1 : 0) +
        (thirdCasterLevels > 0 ? 1 : 0);

    int effectiveCasterLevel;
    if (totalCasterClasses == 1 && fullCasterLevels == 0) {
      if (paladinLevels > 0) {
        effectiveCasterLevel = character.rulesEdition == DmRulesEdition.v2024
            ? (paladinLevels + 1) ~/ 2
            : paladinLevels ~/ 2;
      } else if (rangerLevels > 0) {
        effectiveCasterLevel = character.rulesEdition == DmRulesEdition.v2024
            ? (rangerLevels + 1) ~/ 2
            : rangerLevels ~/ 2;
      } else if (artificerLevels > 0) {
        effectiveCasterLevel = (artificerLevels + 1) ~/ 2;
      } else if (thirdCasterLevels > 0) {
        effectiveCasterLevel = character.rulesEdition == DmRulesEdition.v2024
            ? (thirdCasterLevels + 2) ~/ 3
            : thirdCasterLevels ~/ 3;
      } else {
        effectiveCasterLevel = 0;
      }
    } else {
      effectiveCasterLevel = calculateEffectiveCasterLevel(
        fullCasterLevels: fullCasterLevels,
        paladinLevels: paladinLevels,
        rangerLevels: rangerLevels,
        artificerLevels: artificerLevels,
        thirdCasterLevels: thirdCasterLevels,
        edition: character.rulesEdition,
      );
    }

    final rawSlots = getSpellSlots(effectiveCasterLevel);
    final maxSlots = <int, int>{};
    for (int i = 0; i < rawSlots.length; i++) {
      if (rawSlots[i] > 0) {
        maxSlots[i + 1] = rawSlots[i];
      }
    }

    final pactPool = PactMagicPool.fromWarlockLevel(warlockLevels);

    return SpellSlotPool(
      currentSlots: Map<int, int>.from(maxSlots),
      maxSlots: maxSlots,
      pactMagicSlotLevel: pactPool.slotLevel,
      pactMagicMax: pactPool.totalSlots,
      pactMagicCurrent: pactPool.totalSlots,
    );
  }
}

/// Facade for spellcasting rules
class SpellcastingRulesEngine {
  SpellcastingRulesEngine._();

  static SpellSlotPool calculateSpellSlots(Character character) =>
      MulticlassSlotMatrix.calculateSpellSlots(character);
}

/// Helper for Warlock Pact Magic slot pool (which regains on short rest and remains separate from standard slots).
class PactMagicPool {
  final int totalSlots;
  final int slotLevel;

  const PactMagicPool({
    required this.totalSlots,
    required this.slotLevel,
  });

  /// Computes Warlock Pact Magic slots and slot level by Warlock level (1-20).
  static PactMagicPool fromWarlockLevel(int warlockLevel) {
    if (warlockLevel <= 0) return const PactMagicPool(totalSlots: 0, slotLevel: 0);
    final lvl = warlockLevel.clamp(1, 20);
    final slotLvl = (lvl >= 9) ? 5 : ((lvl + 1) ~/ 2);
    final slotCount = (lvl >= 17) ? 4 : ((lvl >= 11) ? 3 : ((lvl >= 2) ? 2 : 1));
    return PactMagicPool(totalSlots: slotCount, slotLevel: slotLvl);
  }
}

// ============================================================================
// 2. CASTER PREPARATION LIMIT RULES
// ============================================================================

enum CasterPrepStyle {
  spontaneousKnown, // Bard, Sorcerer, Warlock, Ranger
  preparedFull,     // Cleric, Druid, Wizard (Level + Mod)
  preparedHalf,     // Paladin (floor(Level / 2) + Mod)
  preparedArtificer // Artificer (floor(Level / 2) + Mod)
}

class CasterPreparationRules {
  CasterPreparationRules._();

  static CasterPrepStyle getPrepStyle(SpellClass spellClass) {
    return switch (spellClass) {
      SpellClass.bard || SpellClass.sorcerer || SpellClass.warlock || SpellClass.ranger =>
        CasterPrepStyle.spontaneousKnown,
      SpellClass.cleric || SpellClass.druid || SpellClass.wizard =>
        CasterPrepStyle.preparedFull,
      SpellClass.paladin =>
        CasterPrepStyle.preparedHalf,
      SpellClass.artificer =>
        CasterPrepStyle.preparedArtificer,
    };
  }

  /// Computes maximum prepared spells (min 1 for prepared casters).
  static int calculateMaxPreparedSpells({
    required SpellClass spellClass,
    required int classLevel,
    required int abilityModifier,
  }) {
    final style = getPrepStyle(spellClass);
    final lvl = classLevel.clamp(1, 20);

    return switch (style) {
      CasterPrepStyle.spontaneousKnown => 0,
      CasterPrepStyle.preparedFull => max(1, lvl + abilityModifier),
      CasterPrepStyle.preparedHalf => max(1, (lvl ~/ 2) + abilityModifier),
      CasterPrepStyle.preparedArtificer => max(1, (lvl ~/ 2) + abilityModifier),
    };
  }

  /// Calculates Wizard spell copying gold (50 gp / 25 gp) and time (2 hr / 1 hr) costs per spell level.
  static ({int goldCostGp, int timeInHours}) calculateWizardCopyCost({
    required int spellLevel,
    required SpellSchool spellSchool,
    SpellSchool? wizardSchoolSpecialization,
  }) {
    if (spellLevel <= 0) return (goldCostGp: 0, timeInHours: 0);
    final isSpecialized = wizardSchoolSpecialization != null && wizardSchoolSpecialization == spellSchool;
    final baseCost = spellLevel * 50;
    final baseHours = spellLevel * 2;
    return (
      goldCostGp: isSpecialized ? (baseCost ~/ 2) : baseCost,
      timeInHours: isSpecialized ? (baseHours ~/ 2) : baseHours,
    );
  }
}

// ============================================================================
// 3. SPELL MATERIAL COMPONENTS
// ============================================================================

class SpellMaterialComponent {
  final String description;
  final bool hasCost;
  final int costInGp;
  final bool isConsumed;

  const SpellMaterialComponent({
    required this.description,
    this.hasCost = false,
    this.costInGp = 0,
    this.isConsumed = false,
  });

  /// RAW Rule: An arcane focus or component pouch replaces materials UNLESS they have a gp cost or are consumed.
  bool get canBeReplacedByFocus => !hasCost && !isConsumed;
}

// ============================================================================
// 4. CANTRIP SCALING & UPCASTING DICE ENGINE
// ============================================================================


class CantripScalingEngine {
  CantripScalingEngine._();

  /// Character Level scaling multiplier: 1-4: 1x, 5-10: 2x, 11-16: 3x, 17-20: 4x.
  static int getMultiplier(int totalCharacterLevel) {
    final lvl = totalCharacterLevel.clamp(1, 20);
    if (lvl >= 17) return 4;
    if (lvl >= 11) return 3;
    if (lvl >= 5) return 2;
    return 1;
  }

  static final RegExp _cantripFormulaPattern = RegExp(r'^(\d+)d(\d+)(.*)$');

  /// Adjusts dice count in a formula like "1d10" or "1d6" based on total character level.
  static String scaleCantripFormula(String baseFormula, int totalCharacterLevel) {
    final match = _cantripFormulaPattern.firstMatch(baseFormula.trim());
    if (match == null) return baseFormula;

    final baseCount = int.parse(match.group(1)!);
    final sides = match.group(2)!;
    final suffix = match.group(3)!;
    final multiplier = getMultiplier(totalCharacterLevel);

    return '${baseCount * multiplier}d$sides$suffix';
  }
}

/// Defines dynamic upcast dice math for leveled spells.
class SpellScalingFormula {
  final int baseDiceCount;
  final int diceSides;
  final int dicePerSlotLevel;
  final int slotStep; // 1 for most spells (Fireball), 2 for Spiritual Weapon
  final bool addsAbilityMod;
  final int staticBonus;

  const SpellScalingFormula({
    required this.baseDiceCount,
    required this.diceSides,
    this.dicePerSlotLevel = 1,
    this.slotStep = 1,
    this.addsAbilityMod = false,
    this.staticBonus = 0,
  });

  /// Computes the active formula string for a given casting slot level.
  String getFormulaForSlot(int baseSpellLevel, int castSlotLevel) {
    if (castSlotLevel <= baseSpellLevel) {
      final modStr = addsAbilityMod ? ' + mod' : (staticBonus != 0 ? ' + $staticBonus' : '');
      return '$baseDiceCount' 'd$diceSides$modStr';
    }
    final extraSlots = castSlotLevel - baseSpellLevel;
    final totalDice = baseDiceCount + ((extraSlots ~/ slotStep) * dicePerSlotLevel);
    final modStr = addsAbilityMod ? ' + mod' : (staticBonus != 0 ? ' + $staticBonus' : '');
    return '$totalDice' 'd$diceSides$modStr';
  }
}

class SpellRollResult {
  final List<int> individualDice;
  final int modifier;
  final int total;
  final String formulaDescription;

  const SpellRollResult({
    required this.individualDice,
    required this.modifier,
    required this.total,
    required this.formulaDescription,
  });
}

class SpellRollEngine {
  SpellRollEngine._();

  static final RegExp _diceFormulaPattern = RegExp(r'(\d+)d(\d+)');
  static final RegExp _staticModPattern = RegExp(r'([+-])(\d+)$');

  /// Evaluates and rolls a spell formula (e.g. "8d6", "2d8 + mod", "1d4 + 4")
  /// using the cryptographically secure RNG and resolves ability modifiers.
  static SpellRollResult roll({
    required String formula,
    int abilityModifier = 0,
  }) {
    final clean = formula.replaceAll(' ', '');
    final match = _diceFormulaPattern.firstMatch(clean);

    if (match == null) {
      // Fallback for static numbers or unsupported custom formulas
      final staticNum = int.tryParse(clean) ?? 0;
      return SpellRollResult(
        individualDice: [],
        modifier: staticNum,
        total: staticNum,
        formulaDescription: formula,
      );
    }

    final count = int.tryParse(match.group(1) ?? '1') ?? 1;
    final sides = int.tryParse(match.group(2) ?? '6') ?? 6;

    final rolls = List.generate(count, (_) => secureRandom.nextInt(sides) + 1);
    final diceTotal = rolls.fold<int>(0, (sum, val) => sum + val);

    int finalModifier = 0;
    if (clean.contains('+mod')) {
      finalModifier = abilityModifier;
    } else if (clean.contains('-mod')) {
      finalModifier = -abilityModifier;
    } else {
      final staticMatch = _staticModPattern.firstMatch(clean);
      if (staticMatch != null) {
        final sign = staticMatch.group(1);
        final val = int.tryParse(staticMatch.group(2) ?? '0') ?? 0;
        finalModifier = (sign == '-') ? -val : val;
      }
    }

    final total = diceTotal + finalModifier;
    final modText = finalModifier != 0 ? (finalModifier > 0 ? ' + $finalModifier' : ' - ${finalModifier.abs()}') : '';

    return SpellRollResult(
      individualDice: rolls,
      modifier: finalModifier,
      total: total,
      formulaDescription: '$count' 'd$sides$modText',
    );
  }
}

// ============================================================================
// 4. CONCENTRATION & ACTION ECONOMY UTILITIES
// ============================================================================

class ConcentrationRules {
  ConcentrationRules._();

  /// RAW Concentration Save DC: max(10, floor(damage / 2)).
  static int calculateSaveDc(int damageTaken) {
    if (damageTaken <= 0) return 10;
    return max(10, damageTaken ~/ 2);
  }
}

class ActionEconomySpellValidator {
  ActionEconomySpellValidator._();

  /// RAW 2014 & 2024 Bonus Action spell validation:
  /// - 2014: If you cast a Bonus Action spell, you can only cast Cantrips with a 1-Action casting time on that turn.
  /// - 2024: You can only expend ONE spell slot to cast a spell per turn.
  static ({bool isValid, String? warningMessage}) validateBonusActionCasting({
    required bool hasCastBonusActionSpell,
    required int incomingSpellLevel,
    required String incomingCastingTime,
    required DmRulesEdition edition,
  }) {
    if (!hasCastBonusActionSpell) {
      return (isValid: true, warningMessage: null);
    }

    if (edition == DmRulesEdition.v2014) {
      if (incomingSpellLevel > 0) {
        return (
          isValid: false,
          warningMessage: 'RAW 2014 Restriction: Casting a Bonus Action spell limits remaining spells on this turn to Cantrips with a casting time of 1 Action.',
        );
      }
      if (!incomingCastingTime.toLowerCase().contains('1 action')) {
        return (
          isValid: false,
          warningMessage: 'RAW 2014 Restriction: Cantrip must have a casting time of 1 Action when cast on the same turn as a Bonus Action spell.',
        );
      }
    } else {
      if (incomingSpellLevel > 0) {
        return (
          isValid: false,
          warningMessage: 'RAW 2024 Restriction: Only one spell slot may be expended per turn.',
        );
      }
    }

    return (isValid: true, warningMessage: null);
  }
}
