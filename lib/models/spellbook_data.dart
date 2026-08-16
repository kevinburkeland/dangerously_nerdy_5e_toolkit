import 'package:flutter/material.dart';
import '../services/rules/spellcasting_rules_engine.dart';
import '../widgets/glyphs/glyph_tokens.dart';
import 'dm_screen_data.dart';
import 'spells/cantrips.dart';
import 'spells/level_1_spells.dart';
import 'spells/level_2_spells.dart';
import 'spells/level_3_spells.dart';
import 'spells/level_4_spells.dart';
import 'spells/level_5_spells.dart';
import 'spells/high_level_spells.dart';

export '../services/rules/spellcasting_rules_engine.dart';
export '../widgets/glyphs/glyph_tokens.dart';

enum SpellClass {
  bard('Bard', Icons.music_note),
  cleric('Cleric', Icons.health_and_safety_outlined),
  druid('Druid', Icons.eco_outlined),
  paladin('Paladin', Icons.shield),
  ranger('Ranger', Icons.track_changes),
  sorcerer('Sorcerer', Icons.flash_on),
  warlock('Warlock', Icons.dark_mode_outlined),
  wizard('Wizard', Icons.auto_awesome),
  artificer('Artificer', Icons.handyman_outlined);

  final String label;
  final IconData icon;

  const SpellClass(this.label, this.icon);
}

/// Detailed rules information for a specific rules edition of a spell.
class SpellEditionDetails {
  final SpellSchool? schoolOverride;
  final String castingTime;
  final String range;
  final String components; // e.g. "V, S, M (a tiny ball of bat guano and pitch)"
  final SpellMaterialComponent? materialDetails;
  final String duration;
  final bool concentration;
  final bool ritual;
  final List<String> description;
  final String? higherLevels;
  final List<SpellClass> classes;
  final String? rollFormula; // e.g. "8d6" or "2d8 + mod"
  final SpellScalingFormula? scalingFormula;
  final String? damageOrHealType; // e.g. "Fire", "Healing", "Radiant"
  final String? savingThrow; // e.g. "Dexterity", "Wisdom"
  final String? reactionTrigger;

  const SpellEditionDetails({
    this.schoolOverride,
    required this.castingTime,
    required this.range,
    required this.components,
    this.materialDetails,
    required this.duration,
    this.concentration = false,
    this.ritual = false,
    required this.description,
    this.higherLevels,
    required this.classes,
    this.rollFormula,
    this.scalingFormula,
    this.damageOrHealType,
    this.savingThrow,
    this.reactionTrigger,
  });
}

/// Represents an SRD Spell with 2014 & 2024 comparison metadata and rules definitions.
class SpellItem {
  final String id;
  final String name;
  final String? name2014;
  final String? name2024;
  final int level; // 0 = Cantrip, 1-9 = Spell Level
  final SpellSchool school;
  final SpellEditionDetails rules2014;
  final SpellEditionDetails rules2024;
  final bool isChangedIn2024;
  final String? diffSummary;
  final List<String> diffHighlights;
  final List<String> tags;

  const SpellItem({
    required this.id,
    required this.name,
    this.name2014,
    this.name2024,
    required this.level,
    required this.school,
    required this.rules2014,
    required this.rules2024,
    this.isChangedIn2024 = false,
    this.diffSummary,
    this.diffHighlights = const [],
    this.tags = const [],
  });

  String getName(DmRulesEdition edition) {
    if (edition == DmRulesEdition.v2014 && name2014 != null) return name2014!;
    if (edition == DmRulesEdition.v2024 && name2024 != null) return name2024!;
    return name;
  }

  SpellEditionDetails getRules(DmRulesEdition edition) {
    return edition == DmRulesEdition.v2014 ? rules2014 : rules2024;
  }

  SpellSchool getSchool(DmRulesEdition edition) {
    return getRules(edition).schoolOverride ?? school;
  }

  String get levelLabel {
    if (level == 0) return 'Cantrip';
    switch (level) {
      case 1:
        return '1st Level';
      case 2:
        return '2nd Level';
      case 3:
        return '3rd Level';
      default:
        return '${level}th Level';
    }
  }

  String get fullTypeLabel => '$levelLabel ${school.label}';

  String getFullTypeLabel(DmRulesEdition edition) => '$levelLabel ${getSchool(edition).label}';

  bool matches(
    String query, {
    SpellSchool? schoolFilter,
    int? levelFilter,
    SpellClass? classFilter,
    bool? changedOnly,
    bool? ritualOnly,
    bool? concentrationOnly,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final currentRules = getRules(edition);
    final effectiveSchool = currentRules.schoolOverride ?? school;

    if (schoolFilter != null && effectiveSchool != schoolFilter) return false;
    if (levelFilter != null && level != levelFilter) return false;
    if (changedOnly == true && !isChangedIn2024) return false;

    if (classFilter != null && !currentRules.classes.contains(classFilter)) return false;
    if (ritualOnly == true && !currentRules.ritual) return false;
    if (concentrationOnly == true && !currentRules.concentration) return false;

    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();

    if (name.toLowerCase().contains(q)) return true;
    if (name2014 != null && name2014!.toLowerCase().contains(q)) return true;
    if (name2024 != null && name2024!.toLowerCase().contains(q)) return true;
    if (effectiveSchool.label.toLowerCase().contains(q)) return true;
    if (levelLabel.toLowerCase().contains(q)) return true;
    if (diffSummary != null && diffSummary!.toLowerCase().contains(q)) return true;
    if (currentRules.damageOrHealType != null && currentRules.damageOrHealType!.toLowerCase().contains(q)) return true;
    if (currentRules.savingThrow != null && currentRules.savingThrow!.toLowerCase().contains(q)) return true;

    if (currentRules.components.toLowerCase().contains(q)) return true;
    if (currentRules.range.toLowerCase().contains(q)) return true;
    if (currentRules.castingTime.toLowerCase().contains(q)) return true;
    if (currentRules.duration.toLowerCase().contains(q)) return true;
    if (currentRules.rollFormula != null && currentRules.rollFormula!.toLowerCase().contains(q)) return true;
    if (currentRules.higherLevels != null && currentRules.higherLevels!.toLowerCase().contains(q)) return true;

    for (final tag in tags) {
      if (tag.toLowerCase().contains(q)) return true;
    }
    for (final cls in currentRules.classes) {
      if (cls.label.toLowerCase().contains(q)) return true;
    }
    for (final line in currentRules.description) {
      if (line.toLowerCase().contains(q)) return true;
    }

    return false;
  }

  /// Dynamic action rings for DndGlyph HUD rendering conforming to the Glyph Style Guide.
  List<ActionTraitRing> getGlyphActionRings(DmRulesEdition edition) {
    final rings = <ActionTraitRing>[];
    final rules = getRules(edition);

    if (rules.concentration) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.concentration));
    }

    final dmg = rules.damageOrHealType?.toLowerCase() ?? '';
    if (dmg.contains('fire')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.fire));
    } else if (dmg.contains('radiant')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.radiant));
    } else if (dmg.contains('necrotic')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.necrotic));
    } else if (dmg.contains('lightning')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.lightning));
    } else if (dmg.contains('cold')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.cold));
    } else if (dmg.contains('poison')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.poison));
    } else if (dmg.contains('acid')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.acid));
    } else if (dmg.contains('psychic')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.psychic));
    } else if (dmg.contains('force')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.force));
    } else if (dmg.contains('thunder')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.thunder));
    }

    return rings;
  }
}

/// Comprehensive SRD Spell Library featuring core cantrips and spells with 2014 & 2024 comparison data.
class SpellbookLibrary {
  SpellbookLibrary._();

  static const List<SpellItem> allSpells = [
    ...srdCantrips,
    ...srdLevel1Spells,
    ...srdLevel2Spells,
    ...srdLevel3Spells,
    ...srdLevel4Spells,
    ...srdLevel5Spells,
    ...srdHighLevelSpells,
  ];

  static SpellItem? getSpellById(String id) {
    try {
      return allSpells.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<SpellItem> getChangedSpells() {
    return allSpells.where((s) => s.isChangedIn2024).toList();
  }

  static List<SpellItem> getSpellsByLevel(int level) {
    return allSpells.where((s) => s.level == level).toList();
  }

  static List<SpellItem> getSpellsByClass(SpellClass cls, {DmRulesEdition edition = DmRulesEdition.v2024}) {
    return allSpells.where((s) => s.getRules(edition).classes.contains(cls)).toList();
  }
}
