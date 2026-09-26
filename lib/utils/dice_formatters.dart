/// Consolidated formatting utilities for dice expressions and modifier signs.
class DiceFormatters {
  DiceFormatters._();

  /// Formats an integer bonus with an explicit sign (e.g., "+3", "-2", or empty if 0).
  static String formatBonus(int bonus, {bool includeZero = false}) {
    if (bonus == 0 && !includeZero) return '';
    return bonus >= 0 ? '+$bonus' : '$bonus';
  }

  /// Formats a spaced modifier expression for multi-die addition (e.g., " + 5", " - 2", or empty if 0).
  static String formatModifierExpression(int modifier) {
    if (modifier > 0) return ' + $modifier';
    if (modifier < 0) return ' - ${modifier.abs()}';
    return '';
  }

  /// Formats a complete damage or attack formula (e.g., "1d4+4 Bludgeoning").
  static String formatFormula({
    required int count,
    required int sides,
    int bonus = 0,
    String? damageType,
  }) {
    final bonusStr = formatBonus(bonus);
    final base = '${count}d$sides$bonusStr';
    if (damageType != null && damageType.trim().isNotEmpty) {
      return '$base ${damageType.trim()}';
    }
    return base;
  }

  /// Formats a composite primary + secondary damage formula expression (e.g., "2d6+3 Slashing + 1d6 Fire").
  static String formatCompositeFormula({
    required int primaryCount,
    required int primarySides,
    int primaryBonus = 0,
    String? primaryDamageType,
    int secondaryCount = 0,
    int secondarySides = 0,
    String? secondaryDamageType,
  }) {
    final primary = formatFormula(
      count: primaryCount,
      sides: primarySides,
      bonus: primaryBonus,
      damageType: primaryDamageType,
    );
    if (secondaryCount > 0 &&
        secondaryDamageType != null &&
        secondaryDamageType.trim().isNotEmpty) {
      final secondary = formatFormula(
        count: secondaryCount,
        sides: secondarySides,
        damageType: secondaryDamageType,
      );
      return '$primary + $secondary';
    }
    return primary;
  }
}

/// Standard D&D 5e Ability Score Math & Modifier Helpers.
class Dnd5eScoreMath {
  Dnd5eScoreMath._();

  /// Calculates the ability modifier for a given ability score (e.g., 10 -> 0, 16 -> +3, 9 -> -1).
  static int scoreToModifier(int score) => ((score - 10) / 2).floor();

  /// Formats an ability score with its modifier (e.g., "16 (+3)" or "9 (-1)").
  static String formatScoreWithModifier(int score) {
    final mod = scoreToModifier(score);
    final sign = mod >= 0 ? '+$mod' : '$mod';
    return '$score ($sign)';
  }

  /// Calculates the standard proficiency bonus by character level (1-20).
  static int levelToProficiencyBonus(int level) =>
      ((level.clamp(1, 20) - 1) ~/ 4) + 2;
}
