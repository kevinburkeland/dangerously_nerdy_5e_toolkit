/// Pure 5e math engine and score extensions for ability modifier and proficiency bonus calculations.
extension Dnd5eScoreMath on int {
  /// Standard 5e Ability Score to Modifier conversion: floor((score - 10) / 2)
  int get dndModifier => ((this - 10) / 2).floor();

  /// Formatted modifier with explicit sign (e.g., "+3", "-1", "+0")
  String get dndModifierString {
    final mod = dndModifier;
    return mod >= 0 ? '+$mod' : '$mod';
  }

  /// Standard 5e Level to Proficiency Bonus scaling:
  /// Level 1-4: +2 | 5-8: +3 | 9-12: +4 | 13-16: +5 | 17-20: +6
  int get dndProficiencyBonus {
    final clampedLevel = clamp(1, 20);
    return ((clampedLevel - 1) ~/ 4) + 2;
  }
}

/// Static utility class maintaining backward-compatibility with existing call sites
@Deprecated('Use Dnd5eScoreMath extension getters directly (e.g., score.dndModifier)')
abstract class Dnd5eRulesEngine {
  /// Standard 5e Ability Modifier calculation: floor((score - 10) / 2)
  static int calculateModifier(int abilityScore) => abilityScore.dndModifier;

  /// Formatted modifier with sign (e.g., "+3", "-1")
  static String formatModifier(int abilityScore) => abilityScore.dndModifierString;

  /// Standard 5e Proficiency Bonus Scaling: 1-4: +2 | 5-8: +3 | 9-12: +4 | 13-16: +5 | 17-20: +6
  static int calculateProficiencyBonus(int totalLevel) => totalLevel.dndProficiencyBonus;
}
