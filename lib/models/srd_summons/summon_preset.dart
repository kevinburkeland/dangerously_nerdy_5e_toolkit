import '../../widgets/glyphs/glyph_tokens.dart';
import 'minion_stat_block.dart';

typedef BudgetCalculator = int Function(int spellLevel);

class SummonPreset {
  final String id;
  final String name;
  final SummonCategory category;
  final String levelDisplay; // e.g. "5th-level Transmutation", "Wondrous Item (Rare)"
  final String castingTime;
  final String range;
  final String components;
  final String duration;
  final String description;
  final String upcastRules;
  final List<MinionStatBlock> statBlocks;
  final bool isRandomTable; // e.g., Bag of Tricks
  final BudgetCalculator? budgetCalculator;
  final int defaultMinionCount;

  const SummonPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.levelDisplay,
    required this.castingTime,
    required this.range,
    required this.components,
    required this.duration,
    required this.description,
    required this.upcastRules,
    required this.statBlocks,
    this.isRandomTable = false,
    this.budgetCalculator,
    this.defaultMinionCount = 1,
  });

  int calculateMaxPoints(int spellLevel) {
    if (budgetCalculator != null) {
      return budgetCalculator!(spellLevel);
    }
    return 50;
  }
}

/// Helper extension mapping SummonPreset to dynamic DndGlyph parameters.
extension SummonPresetGlyphExt on SummonPreset {
  SpellSchool get glyphSchool {
    final lower = levelDisplay.toLowerCase() + name.toLowerCase();
    if (lower.contains('abjuration')) return SpellSchool.abjuration;
    if (lower.contains('conjuration')) return SpellSchool.conjuration;
    if (lower.contains('divination')) return SpellSchool.divination;
    if (lower.contains('enchantment')) return SpellSchool.enchantment;
    if (lower.contains('evocation')) return SpellSchool.evocation;
    if (lower.contains('illusion')) return SpellSchool.illusion;
    if (lower.contains('necromancy')) return SpellSchool.necromancy;
    if (lower.contains('transmutation') || lower.contains('animate objects')) return SpellSchool.transmutation;
    if (category == SummonCategory.magicItem) return SpellSchool.transmutation;
    return SpellSchool.conjuration;
  }

  int get glyphSpellLevel {
    if (levelDisplay.contains('1st')) return 1;
    if (levelDisplay.contains('2nd')) return 2;
    if (levelDisplay.contains('3rd')) return 3;
    if (levelDisplay.contains('4th')) return 4;
    if (levelDisplay.contains('5th')) return 5;
    if (levelDisplay.contains('6th')) return 6;
    if (levelDisplay.contains('7th')) return 7;
    if (levelDisplay.contains('8th')) return 8;
    if (levelDisplay.contains('9th')) return 9;
    return 5;
  }

  List<ActionTraitRing> get glyphActionRings {
    final rings = <ActionTraitRing>[];
    if (duration.toLowerCase().contains('concentration')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.concentration));
    }

    // Inspect minion stat blocks for elemental/special damage profiles
    for (final sb in statBlocks) {
      final dmgAccent = sb.glyphActionRings;
      for (final r in dmgAccent) {
        if (r.ringType != ActionRingType.concentration &&
            r.damageType != null &&
            r.damageType != DamageAccent.physical &&
            !rings.any((existing) => existing.ringType == r.ringType && existing.damageType == r.damageType)) {
          rings.add(r);
        }
      }
    }

    return rings;
  }
}

