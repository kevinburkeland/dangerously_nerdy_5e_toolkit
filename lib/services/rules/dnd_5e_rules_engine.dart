/// Pure 5e math engine for core ability modifier and proficiency bonus calculations.
class Dnd5eRulesEngine {
  /// Standard 5e Ability Modifier calculation: floor((score - 10) / 2)
  static int calculateModifier(int abilityScore) {
    return ((abilityScore - 10) / 2).floor();
  }

  /// Standard 5e Proficiency Bonus Scaling: ceil(1 + (level / 4))
  /// Level 1-4: +2 | 5-8: +3 | 9-12: +4 | 13-16: +5 | 17-20: +6
  static int calculateProficiencyBonus(int totalLevel) {
    final clampedLevel = totalLevel.clamp(1, 20);
    return ((clampedLevel - 1) ~/ 4) + 2;
  }
}

