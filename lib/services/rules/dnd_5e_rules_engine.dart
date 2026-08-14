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

/// Generic, boundary-safe enum lookup helper for serialization/deserialization.
extension SafeEnumLookup<T extends Enum> on List<T> {
  T safeByIndex(int? index, T fallback) {
    if (index == null || index < 0 || index >= length) return fallback;
    return this[index];
  }
}

/// Zero-guarded numeric ratio calculation for combat and resource meters.
extension DndMathUtils on num {
  /// Computes safe progress fraction [0.0 - 1.0] strictly protected against divide-by-zero
  double ratioOf(num max) => max <= 0 ? 0.0 : (this / max).clamp(0.0, 1.0).toDouble();
}

