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
  final String
      components; // e.g. "V, S, M (a tiny ball of bat guano and pitch)"
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

  String getFullTypeLabel(DmRulesEdition edition) =>
      '$levelLabel ${getSchool(edition).label}';

  static final Map<String, String> _corpusCache = {};

  String _getCorpus(DmRulesEdition edition) {
    final key = '${id}_${edition.name}';
    final cached = _corpusCache[key];
    if (cached != null) return cached;
    final currentRules = getRules(edition);
    final effectiveSchool = currentRules.schoolOverride ?? school;
    final buffer = StringBuffer()
      ..write('$name ')
      ..write('${name2014 ?? ""} ')
      ..write('${name2024 ?? ""} ')
      ..write('${effectiveSchool.label} ')
      ..write('$levelLabel ')
      ..write('${diffSummary ?? ""} ')
      ..write('${currentRules.damageOrHealType ?? ""} ')
      ..write('${currentRules.savingThrow ?? ""} ')
      ..write('${currentRules.components} ')
      ..write('${currentRules.range} ')
      ..write('${currentRules.castingTime} ')
      ..write('${currentRules.duration} ')
      ..write('${currentRules.rollFormula ?? ""} ')
      ..write('${currentRules.higherLevels ?? ""} ');
    for (final tag in tags) {
      buffer.write('$tag ');
    }
    for (final cls in currentRules.classes) {
      buffer.write('${cls.label} ');
    }
    for (final line in currentRules.description) {
      buffer.write('$line ');
    }
    final corpus = buffer.toString().toLowerCase();
    _corpusCache[key] = corpus;
    return corpus;
  }

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

    if (classFilter != null && !currentRules.classes.contains(classFilter))
      return false;
    if (ritualOnly == true && !currentRules.ritual) return false;
    if (concentrationOnly == true && !currentRules.concentration) return false;

    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;
    final q = trimmed.toLowerCase();

    return _getCorpus(edition).contains(q);
  }

  /// Dynamic action rings for DndGlyph HUD rendering conforming to the Glyph Style Guide.
  List<ActionTraitRing> getGlyphActionRings(DmRulesEdition edition) {
    final rings = <ActionTraitRing>[];
    final rules = getRules(edition);

    bool hasExplicitAreaOfEffect() {
      final text = [
        rules.range,
        ...rules.description,
        ...tags,
      ].map((value) => value.toLowerCase()).join(' ');

      final areaShapeTerms = [
        'cone',
        'line',
        'radius',
        'sphere',
        'cube',
        'cylinder',
        'emanation',
        'burst',
        'wall'
      ];
      final aoePhrases = [
        'each creature in a',
        'each creature in the',
        'creatures in a',
        'creatures in the',
        'in a 20-foot-radius',
        'in a 15-foot-radius',
        'in a 10-foot-radius',
        'within the area',
        'in the area',
        'area of effect',
        'explosion of flame',
      ];

      return areaShapeTerms.any(text.contains) || aoePhrases.any(text.contains);
    }

    bool hasExplicitRechargeMechanic() {
      final text = [
        ...rules.description,
        ...tags,
      ].map((value) => value.toLowerCase()).join(' ');
      return text.contains('recharge') || text.contains('recharges');
    }

    bool hasControlSemantics() {
      const controlTerms = [
        'restrain',
        'restrained',
        'paralyze',
        'paralyzed',
        'charm',
        'charmed',
        'frighten',
        'frightened',
        'incapacitated',
        'stun',
        'stunned',
        'banish',
        'banished',
        'grapple',
        'grappled',
        'prone',
        'sleep',
        'confusion',
      ];
      final text = [
        ...rules.description,
        ...tags,
        rules.savingThrow ?? '',
      ].map((value) => value.toLowerCase()).join(' ');
      return controlTerms.any(text.contains);
    }

    bool hasSustainSemantics() {
      const sustainTerms = [
        'healing',
        'regain hit points',
        'regains hit points',
        'regain hp',
        'regains hp',
        'temporary hit points',
        'temp hp',
        'regeneration',
        'regenerate',
      ];
      final text = [
        rules.damageOrHealType ?? '',
        ...rules.description,
        ...tags,
      ].map((value) => value.toLowerCase()).join(' ');
      return sustainTerms.any(text.contains);
    }

    bool sameDamageTypes(List<DamageAccent> a, List<DamageAccent> b) {
      if (identical(a, b)) return true;
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    void addRing(ActionRingType type,
        {DamageAccent? damageType, List<DamageAccent> damageTypes = const []}) {
      final exists = rings.any((r) =>
          r.ringType == type &&
          r.damageType == damageType &&
          sameDamageTypes(r.damageTypes, damageTypes));
      if (exists) return;
      rings.add(ActionTraitRing(
        ringType: type,
        damageType: damageType,
        damageTypes: damageTypes,
      ));
    }

    if (rules.concentration) {
      addRing(ActionRingType.concentration);
    }

    if (hasControlSemantics()) {
      addRing(ActionRingType.control);
    }

    if (hasSustainSemantics()) {
      addRing(ActionRingType.sustain);
    }

    if (hasExplicitAreaOfEffect() || hasExplicitRechargeMechanic()) {
      final damageAccents = getGlyphDamageAccents(edition);
      final primaryDamage =
          damageAccents.isNotEmpty ? damageAccents.first : null;
      final extraDamageTypes = damageAccents.length > 1
          ? damageAccents.sublist(1)
          : const <DamageAccent>[];
      addRing(
        ActionRingType.recharge,
        damageType: primaryDamage,
        damageTypes: extraDamageTypes,
      );
    }

    final casting = rules.castingTime.toLowerCase();
    if (casting.contains('reaction')) {
      addRing(ActionRingType.reaction);
    }

    return rings.take(3).toList(growable: false);
  }

  /// Primary damage accent used by glyphs for this spell in the selected rules edition.
  DamageAccent? getGlyphPrimaryDamageAccent(DmRulesEdition edition) {
    final accents = getGlyphDamageAccents(edition);
    if (accents.isEmpty) return null;
    return accents.first;
  }

  /// Ordered damage accents used by glyphs for this spell in the selected rules edition.
  List<DamageAccent> getGlyphDamageAccents(DmRulesEdition edition) {
    final dmg = (getRules(edition).damageOrHealType ?? '').toLowerCase();
    if (dmg.isEmpty) return const [];

    final accents = <DamageAccent>[];
    void addIfPresent(String token, DamageAccent accent) {
      if (dmg.contains(token) && !accents.contains(accent)) {
        accents.add(accent);
      }
    }

    addIfPresent('fire', DamageAccent.fire);
    addIfPresent('radiant', DamageAccent.radiant);
    addIfPresent('necrotic', DamageAccent.necrotic);
    addIfPresent('lightning', DamageAccent.lightning);
    addIfPresent('cold', DamageAccent.cold);
    addIfPresent('poison', DamageAccent.poison);
    addIfPresent('acid', DamageAccent.acid);
    addIfPresent('psychic', DamageAccent.psychic);
    addIfPresent('force', DamageAccent.force);
    addIfPresent('thunder', DamageAccent.thunder);

    if ((dmg.contains('bludgeoning') ||
            dmg.contains('slashing') ||
            dmg.contains('piercing')) &&
        !accents.contains(DamageAccent.physical)) {
      accents.add(DamageAccent.physical);
    }

    return accents;
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

  static List<SpellItem> getSpellsByClass(SpellClass cls,
      {DmRulesEdition edition = DmRulesEdition.v2024}) {
    return allSpells
        .where((s) => s.getRules(edition).classes.contains(cls))
        .toList();
  }
}
