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
}
