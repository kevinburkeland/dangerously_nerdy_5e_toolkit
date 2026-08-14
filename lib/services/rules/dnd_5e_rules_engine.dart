import 'dart:math';

enum AbilityScore {
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma,
}

enum SpellSchool {
  abjuration,
  conjuration,
  divination,
  enchantment,
  evocation,
  illusion,
  necromancy,
  transmutation,
}

enum ActionEconomy {
  action,
  bonusAction,
  reaction,
  minute,
  hour,
}

enum ArmorType {
  unarmored,
  light,
  medium,
  heavy,
  natural,
}

/// A comprehensive, pure 5e Rules Engine for character stats, multiclassing, AC, and resting.
class Dnd5eRulesEngine {
  /// Ability Modifier calculation: floor((score - 10) / 2)
  static int calculateModifier(int abilityScore) {
    return ((abilityScore - 10) / 2).floor();
  }

  /// Proficiency Bonus Scaling: ceil(1 + (level / 4))
  /// Level 1-4: +2 | 5-8: +3 | 9-12: +4 | 13-16: +5 | 17-20: +6
  static int calculateProficiencyBonus(int totalLevel) {
    final clampedLevel = totalLevel.clamp(1, 20);
    return ((clampedLevel - 1) ~/ 4) + 2;
  }

  /// Non-stacking AC Calculation (PHB RAW p. 14, 164)
  /// Evaluates all eligible formulas and picks the highest without stacking.
  static int calculateArmorClass({
    required ArmorType armorType,
    int baseArmorAc = 10,
    required int dexModifier,
    int conModifier = 0,
    int wisModifier = 0,
    bool hasShield = false,
    int shieldBonus = 2,
    bool isBarbarianUnarmored = false,
    bool isMonkUnarmored = false,
    bool hasMageArmor = false,
    int naturalArmorAc = 0,
    int magicItemAcBonus = 0,
  }) {
    List<int> candidateFormulas = [];

    // 1. Standard Unarmored Base (10 + DEX + Shield allowed)
    candidateFormulas.add(10 + dexModifier + (hasShield ? shieldBonus : 0));

    // 2. Barbarian Unarmored Defense (10 + DEX + CON + Shield allowed)
    if (isBarbarianUnarmored) {
      candidateFormulas.add(10 + dexModifier + conModifier + (hasShield ? shieldBonus : 0));
    }

    // 3. Monk Unarmored Defense (10 + DEX + WIS, NO Shield allowed)
    if (isMonkUnarmored && !hasShield) {
      candidateFormulas.add(10 + dexModifier + wisModifier);
    }

    // 4. Mage Armor (13 + DEX + Shield allowed)
    if (hasMageArmor) {
      candidateFormulas.add(13 + dexModifier + (hasShield ? shieldBonus : 0));
    }

    // 5. Natural Armor (e.g. Lizardfolk 13+DEX, Tortle flat 17)
    if (naturalArmorAc > 0) {
      candidateFormulas.add(naturalArmorAc + (armorType == ArmorType.natural ? dexModifier : 0) + (hasShield ? shieldBonus : 0));
    }

    // 6. Worn Armor Calculations
    if (armorType == ArmorType.light) {
      candidateFormulas.add(baseArmorAc + dexModifier + (hasShield ? shieldBonus : 0));
    } else if (armorType == ArmorType.medium) {
      candidateFormulas.add(baseArmorAc + min<int>(dexModifier, 2) + (hasShield ? shieldBonus : 0));
    } else if (armorType == ArmorType.heavy) {
      candidateFormulas.add(baseArmorAc + (hasShield ? shieldBonus : 0));
    }

    return candidateFormulas.reduce(max) + magicItemAcBonus;
  }

  /// Multiclass Spell Slot Calculator (5th Edition Multiclass Rules)
  /// Returns a map of {spellSlotLevel (1..9): slotCount}.
  static Map<int, int> calculateMulticlassSpellSlots({
    int fullCasterLevels = 0,    // Full casters (e.g., Wizard, Cleric, Druid, Sorcerer, Bard)
    int artificerLevels = 0,     // Half-casters rounding up (e.g., Artificer multiclass progression)
    int halfCasterLevels = 0,    // Half-casters rounding down (e.g., Paladin, Ranger)
    int thirdCasterLevels = 0,   // Third-casters (e.g., Eldritch Knight, Arcane Trickster)
  }) {
    int effectiveLevel = fullCasterLevels;

    // Handles half-casters that round UP when multiclassing
    if (artificerLevels > 0) {
      effectiveLevel += (artificerLevels / 2).ceil();
    }

    effectiveLevel += (halfCasterLevels ~/ 2);
    effectiveLevel += (thirdCasterLevels ~/ 3);

    effectiveLevel = effectiveLevel.clamp(0, 20);

    const slotTable = <int, List<int>>{
      1:  [2, 0, 0, 0, 0, 0, 0, 0, 0],
      2:  [3, 0, 0, 0, 0, 0, 0, 0, 0],
      3:  [4, 2, 0, 0, 0, 0, 0, 0, 0],
      4:  [4, 3, 0, 0, 0, 0, 0, 0, 0],
      5:  [4, 3, 2, 0, 0, 0, 0, 0, 0],
      6:  [4, 3, 3, 0, 0, 0, 0, 0, 0],
      7:  [4, 3, 3, 1, 0, 0, 0, 0, 0],
      8:  [4, 3, 3, 2, 0, 0, 0, 0, 0],
      9:  [4, 3, 3, 3, 1, 0, 0, 0, 0],
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

    final slots = <int, int>{};
    for (int lvl = 1; lvl <= 9; lvl++) {
      slots[lvl] = 0;
    }

    if (effectiveLevel > 0 && slotTable.containsKey(effectiveLevel)) {
      final list = slotTable[effectiveLevel]!;
      for (int i = 0; i < 9; i++) {
        slots[i + 1] = list[i];
      }
    }
    return slots;
  }

  /// Warlock Pact Magic Slot Calculator (Tracked Separately from Spellcasting Slots)
  /// In 5e RAW, Pact Magic slots cap at 5th level (2 slots at lvls 2-10, 3 at 11-16, 4 at 17-20).
  static ({int slotLevel, int slotCount}) calculatePactMagicSlots(int warlockLevel) {
    if (warlockLevel <= 0) return (slotLevel: 0, slotCount: 0);
    if (warlockLevel == 1) return (slotLevel: 1, slotCount: 1);
    if (warlockLevel == 2) return (slotLevel: 1, slotCount: 2);
    if (warlockLevel <= 4) return (slotLevel: 2, slotCount: 2);
    if (warlockLevel <= 6) return (slotLevel: 3, slotCount: 2);
    if (warlockLevel <= 8) return (slotLevel: 4, slotCount: 2);
    if (warlockLevel <= 10) return (slotLevel: 5, slotCount: 2);
    if (warlockLevel <= 16) return (slotLevel: 5, slotCount: 3);
    return (slotLevel: 5, slotCount: 4); // Level 17-20
  }

  /// Warlock Mystic Arcanum Calculator (1 use each per Long Rest, distinct from spell slots)
  /// Level 11: 6th | Level 13: 7th | Level 15: 8th | Level 17: 9th
  static Map<int, int> calculateMysticArcanum(int warlockLevel) {
    final arcanum = <int, int>{6: 0, 7: 0, 8: 0, 9: 0};
    if (warlockLevel >= 11) arcanum[6] = 1;
    if (warlockLevel >= 13) arcanum[7] = 1;
    if (warlockLevel >= 15) arcanum[8] = 1;
    if (warlockLevel >= 17) arcanum[9] = 1;
    return arcanum;
  }

  /// Hit Dice Recovery on Long Rest: max(1, floor(totalHitDice / 2))
  static int calculateRecoveredHitDice(int totalHitDice) {
    if (totalHitDice <= 0) return 0;
    return max(1, (totalHitDice / 2).floor());
  }
}
