import 'package:flutter/widgets.dart';
import '../spellbook_data.dart';
import '../../widgets/glyphs/dnd_glyph.dart';
import 'minion_stat_block.dart';

typedef BudgetCalculator = int Function(int spellLevel);

class SummonPreset {
  final String id;
  final String? spellId;
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
    this.spellId,
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

  /// Canonical source spell from the SRD Spellbook, if applicable.
  SpellItem? get sourceSpell => spellId != null ? SpellbookLibrary.getSpellById(spellId!) : null;

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
    final spell = sourceSpell;
    if (spell != null) return spell.school;

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

  ItemCategory get glyphItemCategory {
    final lower = name.toLowerCase() + levelDisplay.toLowerCase();
    if (lower.contains('staff')) return ItemCategory.staff;
    if (lower.contains('wand')) return ItemCategory.wand;
    if (lower.contains('rod')) return ItemCategory.rod;
    if (lower.contains('scroll')) return ItemCategory.scroll;
    if (lower.contains('potion')) return ItemCategory.potion;
    if (lower.contains('ring')) return ItemCategory.ring;
    if (lower.contains('armor') || lower.contains('shield')) return ItemCategory.armor;
    if (lower.contains('sword') || lower.contains('weapon') || lower.contains('bow')) return ItemCategory.weapon;
    return ItemCategory.wondrousItem;
  }

  ItemRarity get glyphItemRarity {
    final lower = levelDisplay.toLowerCase();
    if (lower.contains('uncommon')) return ItemRarity.uncommon;
    if (lower.contains('very rare')) return ItemRarity.veryRare;
    if (lower.contains('legendary')) return ItemRarity.legendary;
    if (lower.contains('artifact')) return ItemRarity.artifact;
    if (lower.contains('rare')) return ItemRarity.rare;
    return ItemRarity.uncommon;
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

  Widget buildGlyph({double size = 40, bool isDarkMode = true}) {
    if (category == SummonCategory.magicItem) {
      return DndGlyph.item(
        category: glyphItemCategory,
        rarity: glyphItemRarity,
        actionRings: glyphActionRings,
        size: size,
        isDarkMode: isDarkMode,
      );
    }
    return DndGlyph.spell(
      school: glyphSchool,
      level: glyphSpellLevel,
      actionRings: glyphActionRings,
      size: size,
      isDarkMode: isDarkMode,
    );
  }
}
