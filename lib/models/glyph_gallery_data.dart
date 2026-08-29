import 'package:flutter/material.dart';
import 'dm_screen_data.dart';
import 'spellbook_data.dart';
import 'srd_summons/srd_summons_library.dart';

/// Data model representing a spell entry in the Glyph Gallery.
class GlyphSpellEntry implements GlyphRenderable {
  final String spellId;
  final String summary;

  const GlyphSpellEntry({
    required this.spellId,
    required this.summary,
  });

  SpellItem get spell {
    final found = SpellbookLibrary.getSpellById(spellId);
    if (found == null) {
      throw StateError('Unknown spell id for glyph gallery: $spellId');
    }
    return found;
  }

  String get name => spell.getName(DmRulesEdition.v2024);
  SpellSchool get school => spell.getSchool(DmRulesEdition.v2024);
  int get level => spell.level;

  @override
  String get glyphId => spellId;

  @override
  String get displayName => name;

  @override
  GlyphCategory get glyphCategory => GlyphCategory.spell;

  @override
  List<ActionTraitRing> get actionRings =>
      spell.getGlyphActionRings(DmRulesEdition.v2024);

  @override
  DamageAccent? get primaryAccent =>
      spell.getGlyphPrimaryDamageAccent(DmRulesEdition.v2024);

  @override
  IconData? get fallbackIcon => school.icon;

  @override
  Map<String, dynamic>? get metadata => {
        'school': school,
        'level': level,
        'summary': summary,
        'castingTime': castingTime,
        'range': range,
        'duration': duration,
      };

  DamageAccent? get damageAccent => primaryAccent;
  String get castingTime => spell.getRules(DmRulesEdition.v2024).castingTime;
  String get range => spell.getRules(DmRulesEdition.v2024).range;
  String get duration => spell.getRules(DmRulesEdition.v2024).duration;

  String get levelDescription => level == 0 ? 'Cantrip' : 'Level $level';
}

/// Data model representing a creature entry in the Glyph Gallery.
class GlyphCreatureEntry implements GlyphRenderable {
  final String name;
  final CreatureType type;
  final String cr;
  final int crTier; // 1: CR 0-4, 2: CR 5-10, 3: CR 11-16, 4: CR 17+
  @override
  final List<ActionTraitRing> actionRings;
  final ActionBadge? actionBadge;
  final int ac;
  final int hp;
  final String speed;
  final String primaryAttack;

  const GlyphCreatureEntry({
    required this.name,
    required this.type,
    required this.cr,
    required this.crTier,
    this.actionRings = const [],
    this.actionBadge,
    required this.ac,
    required this.hp,
    required this.speed,
    required this.primaryAttack,
  });

  @override
  String get glyphId =>
      'creature_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

  @override
  String get displayName => name;

  @override
  GlyphCategory get glyphCategory => GlyphCategory.creature;

  @override
  DamageAccent? get primaryAccent =>
      actionRings.isNotEmpty ? actionRings.first.damageType : null;

  @override
  IconData? get fallbackIcon => Icons.pets;

  @override
  Map<String, dynamic>? get metadata => {
        'creatureType': type,
        'cr': cr,
        'crTier': crTier,
        'ac': ac,
        'hp': hp,
        'speed': speed,
        'primaryAttack': primaryAttack,
      };
}

/// Data model representing a magic item entry in the Glyph Gallery.
class GlyphItemEntry implements GlyphRenderable {
  final String name;
  final ItemCategory category;
  final ItemRarity rarity;
  final bool requiresAttunement;
  final DamageAccent? damageAccent;
  @override
  final List<ActionTraitRing> actionRings;
  final String summary;

  const GlyphItemEntry({
    required this.name,
    required this.category,
    required this.rarity,
    this.requiresAttunement = false,
    this.damageAccent,
    this.actionRings = const [],
    required this.summary,
  });

  @override
  String get glyphId =>
      'item_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

  @override
  String get displayName => name;

  @override
  GlyphCategory get glyphCategory => GlyphCategory.item;

  @override
  DamageAccent? get primaryAccent =>
      damageAccent ??
      (actionRings.isNotEmpty ? actionRings.first.damageType : null);

  @override
  IconData? get fallbackIcon => category.icon;

  @override
  Map<String, dynamic>? get metadata => {
        'category': category,
        'rarity': rarity,
        'requiresAttunement': requiresAttunement,
        'summary': summary,
      };
}

/// Data model representing a character class entry in the Glyph Gallery.
class GlyphClassEntry implements GlyphRenderable {
  final String name;
  final DndClassType classType;
  final String primaryAbility;
  final String savingThrows;
  final String primaryResource;
  @override
  final List<ActionTraitRing> actionRings;
  final String summary;

  const GlyphClassEntry({
    required this.name,
    required this.classType,
    required this.primaryAbility,
    required this.savingThrows,
    required this.primaryResource,
    required this.actionRings,
    required this.summary,
  });

  @override
  String get glyphId => 'class_${classType.name}';

  @override
  String get displayName => name;

  @override
  GlyphCategory get glyphCategory => GlyphCategory.classFeature;

  @override
  DamageAccent? get primaryAccent => null;

  @override
  IconData? get fallbackIcon => Icons.shield;

  @override
  Map<String, dynamic>? get metadata => {
        'classType': classType,
        'hitDieSides': classType.hitDieSides,
        'primaryAbility': primaryAbility,
        'savingThrows': savingThrows,
        'primaryResource': primaryResource,
        'summary': summary,
      };
}

/// Data model representing a feat entry in the Glyph Gallery.
class GlyphFeatEntry implements GlyphRenderable {
  final String featId;
  final String name;
  final FeatCategory featCategory;
  final int minLevel;
  final String? prerequisite;
  final FeatTriggerType triggerType;
  @override
  final List<ActionTraitRing> actionRings;
  final DamageAccent? damageAccent;
  final String summary;

  const GlyphFeatEntry({
    required this.featId,
    required this.name,
    required this.featCategory,
    this.minLevel = 1,
    this.prerequisite,
    this.triggerType = FeatTriggerType.passive,
    required this.actionRings,
    this.damageAccent,
    required this.summary,
  });

  @override
  String get glyphId => featId;

  @override
  String get displayName => name;

  @override
  GlyphCategory get glyphCategory => GlyphCategory.feat;

  @override
  DamageAccent? get primaryAccent => damageAccent;

  @override
  IconData? get fallbackIcon => Icons.stars_outlined;

  @override
  Map<String, dynamic>? get metadata => {
        'featCategory': featCategory,
        'minLevel': minLevel,
        'prerequisite': prerequisite,
        'triggerType': triggerType,
        'summary': summary,
      };
}

/// Data model representing a species / race entry in the Glyph Gallery.
class GlyphSpeciesEntry implements GlyphRenderable {
  final String name;
  final SpeciesType speciesType;
  final String? sizeOverride;
  final int? speedOverride;
  final String? traitsOverride;
  final List<ActionTraitRing>? actionRings2014;
  final List<ActionTraitRing>? actionRings2024;
  final String? summary2014;
  final String? summary2024;

  const GlyphSpeciesEntry({
    required this.name,
    required this.speciesType,
    this.sizeOverride,
    this.speedOverride,
    this.traitsOverride,
    this.actionRings2014,
    this.actionRings2024,
    this.summary2014,
    this.summary2024,
  });

  String getSize([DmRulesEdition edition = DmRulesEdition.v2024]) =>
      sizeOverride ?? speciesType.getSize(edition);

  int getSpeed([DmRulesEdition edition = DmRulesEdition.v2024]) =>
      speedOverride ?? speciesType.getSpeed(edition);

  String getTraits([DmRulesEdition edition = DmRulesEdition.v2024]) =>
      traitsOverride ?? speciesType.getTraits(edition);

  String getSummary([DmRulesEdition edition = DmRulesEdition.v2024]) =>
      (edition == DmRulesEdition.v2014 ? summary2014 : summary2024) ??
      summary2024 ??
      summary2014 ??
      '';

  List<ActionTraitRing> getActionRings(
          [DmRulesEdition edition = DmRulesEdition.v2024]) =>
      (edition == DmRulesEdition.v2014 ? actionRings2014 : actionRings2024) ??
      actionRings2024 ??
      actionRings2014 ??
      const [];

  String get size => getSize();
  int get speed => getSpeed();
  String get traits => getTraits();
  String get summary => getSummary();

  @override
  String get glyphId => 'species_${speciesType.name}';

  @override
  String get displayName => name;

  @override
  GlyphCategory get glyphCategory => GlyphCategory.species;

  @override
  List<ActionTraitRing> get actionRings => getActionRings();

  @override
  DamageAccent? get primaryAccent => null;

  @override
  IconData? get fallbackIcon => Icons.groups_outlined;

  @override
  Map<String, dynamic>? get metadata => {
        'speciesType': speciesType,
        'size': size,
        'speed': speed,
        'traits': traits,
        'summary': summary,
      };
}

/// Data model representing a generic UI glyph entry in the Glyph Gallery.
class GlyphGenericEntry implements GlyphRenderable {
  final String name;
  final GenericUiGlyphType uiType;
  final String group;
  @override
  final List<ActionTraitRing> actionRings;
  final String summary;

  const GlyphGenericEntry({
    required this.name,
    required this.uiType,
    required this.group,
    this.actionRings = const [],
    required this.summary,
  });

  @override
  String get glyphId => 'ui_${uiType.name}';

  @override
  String get displayName => name;

  @override
  GlyphCategory get glyphCategory => GlyphCategory.genericUi;

  @override
  DamageAccent? get primaryAccent => null;

  @override
  IconData? get fallbackIcon => Icons.widgets_outlined;

  @override
  Map<String, dynamic>? get metadata => {
        'uiType': uiType,
        'group': group,
        'summary': summary,
      };
}

/// Library of known spells, creatures, magic items, feats, classes, species, and generic UI in the toolkit.
class GlyphGalleryData {
  // ---------------------------------------------------------------------------
  // SPELLS (The 7 core summon/minion spells in the toolkit)
  // ---------------------------------------------------------------------------
  static const List<GlyphSpellEntry> allSpells = [
    GlyphSpellEntry(
      spellId: 'spell_animate_objects',
      summary:
          'Animate up to 10 nonmagical objects as high-speed tactical construct minions.',
    ),
    GlyphSpellEntry(
      spellId: 'spell_conjure_animals',
      summary:
          'Summon fey beast spirits (wolves, dire wolves, bears, spiders, and eagles).',
    ),
    GlyphSpellEntry(
      spellId: 'spell_animate_dead',
      summary:
          'Imbue bones or corpse with dark animus to raise Skeletons or Zombies.',
    ),
    GlyphSpellEntry(
      spellId: 'spell_create_undead',
      summary:
          'Craft elite undead strike forces: Ghouls, Ghasts, Wights, or Mummies.',
    ),
    GlyphSpellEntry(
      spellId: 'spell_conjure_elemental',
      summary:
          'Summon a powerful CR 5 Elemental spirit (Fire, Water, Earth, or Air Elemental).',
    ),
    GlyphSpellEntry(
      spellId: 'spell_conjure_minor_elementals',
      summary:
          'Summon swarms of lesser elementals (Dust, Ice, Magma, Steam Mephits, Gargoyles).',
    ),
    GlyphSpellEntry(
      spellId: 'spell_giant_insect',
      summary:
          'Transform ordinary centipedes, wasps, and scorpions into giant bio-weapon beasts.',
    ),
  ];

  // ---------------------------------------------------------------------------
  // CREATURES (Every summon and minion stat block actually in SrdSummonsLibrary)
  // ---------------------------------------------------------------------------
  static final List<GlyphCreatureEntry> allCreatures = [
    // Animate Objects Constructs
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.tinyObject.name,
      type: CreatureType.construct,
      cr: '1/4',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            label: 'Micro Kinetic Slam (+8 to hit)'),
      ],
      ac: SrdSummonsLibrary.tinyObject.ac,
      hp: SrdSummonsLibrary.tinyObject.maxHp,
      speed: SrdSummonsLibrary.tinyObject.speed,
      primaryAttack: 'Slam (+8 to hit, 1d4+4 bludgeoning)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.smallObject.name,
      type: CreatureType.construct,
      cr: '1/2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Kinetic Slam (+6 to hit)'),
      ],
      ac: SrdSummonsLibrary.smallObject.ac,
      hp: SrdSummonsLibrary.smallObject.maxHp,
      speed: SrdSummonsLibrary.smallObject.speed,
      primaryAttack: 'Slam (+6 to hit, 1d8+2 bludgeoning)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.mediumObject.name,
      type: CreatureType.construct,
      cr: '1',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Heavy Slam (+5 to hit)'),
      ],
      ac: SrdSummonsLibrary.mediumObject.ac,
      hp: SrdSummonsLibrary.mediumObject.maxHp,
      speed: SrdSummonsLibrary.mediumObject.speed,
      primaryAttack: 'Slam (+5 to hit, 2d6+1 bludgeoning)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.largeObject.name,
      type: CreatureType.construct,
      cr: '2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Crushing Slam (+6 to hit)'),
      ],
      ac: SrdSummonsLibrary.largeObject.ac,
      hp: SrdSummonsLibrary.largeObject.maxHp,
      speed: SrdSummonsLibrary.largeObject.speed,
      primaryAttack: 'Slam (+6 to hit, 2d10+2 bludgeoning)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.hugeObject.name,
      type: CreatureType.construct,
      cr: '3',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Titanic Slam (+8 to hit)'),
      ],
      ac: SrdSummonsLibrary.hugeObject.ac,
      hp: SrdSummonsLibrary.hugeObject.maxHp,
      speed: SrdSummonsLibrary.hugeObject.speed,
      primaryAttack: 'Slam (+8 to hit, 2d12+4 bludgeoning)',
    ),

    // Undead Summons
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.skeleton.name,
      type: CreatureType.undead,
      cr: '1/4',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.ranged,
            label: 'Shortbow Reticle (+4 to hit)'),
      ],
      ac: SrdSummonsLibrary.skeleton.ac,
      hp: SrdSummonsLibrary.skeleton.maxHp,
      speed: SrdSummonsLibrary.skeleton.speed,
      primaryAttack: 'Shortbow (+4 to hit, 1d6+2 piercing)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.zombie.name,
      type: CreatureType.undead,
      cr: '1/4',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.reaction,
            label: 'Undead Fortitude (DC Con)'),
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Slam Attack (+3 to hit)'),
      ],
      ac: SrdSummonsLibrary.zombie.ac,
      hp: SrdSummonsLibrary.zombie.maxHp,
      speed: SrdSummonsLibrary.zombie.speed,
      primaryAttack: 'Slam (+3 to hit, 1d6+1 bludgeoning)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.ghoul.name,
      type: CreatureType.undead,
      cr: '1',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.necrotic,
            label: 'Paralyzing Claws (DC 10)'),
      ],
      ac: SrdSummonsLibrary.ghoul.ac,
      hp: SrdSummonsLibrary.ghoul.maxHp,
      speed: SrdSummonsLibrary.ghoul.speed,
      primaryAttack: 'Claws (+4 to hit, 2d4+2 & DC 10 Paralyze)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.ghast.name,
      type: CreatureType.undead,
      cr: '2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.reaction,
            damageType: DamageAccent.poison,
            label: 'Stench Aura (DC 10 Con)'),
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.necrotic,
            label: 'Paralyzing Claws'),
      ],
      ac: SrdSummonsLibrary.ghast.ac,
      hp: SrdSummonsLibrary.ghast.maxHp,
      speed: SrdSummonsLibrary.ghast.speed,
      primaryAttack: 'Stench & Claws (+5 to hit, 2d6+3 slashing)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.wight.name,
      type: CreatureType.undead,
      cr: '3',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.necrotic,
            label: 'Life Drain (Max HP Drain)'),
        ActionTraitRing(
            ringType: ActionRingType.ranged,
            label: 'Longbow Reticle (+4 to hit)'),
      ],
      ac: SrdSummonsLibrary.wight.ac,
      hp: SrdSummonsLibrary.wight.maxHp,
      speed: SrdSummonsLibrary.wight.speed,
      primaryAttack: 'Life Drain (+4 to hit, 1d6+2 & max HP drain)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.mummy.name,
      type: CreatureType.undead,
      cr: '3',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.necrotic,
            label: 'Mummy Rot Fist (3d6 necrotic)'),
      ],
      ac: SrdSummonsLibrary.mummy.ac,
      hp: SrdSummonsLibrary.mummy.maxHp,
      speed: SrdSummonsLibrary.mummy.speed,
      primaryAttack: 'Rotting Fist (+5 to hit, 2d6+3 & Mummy Rot)',
    ),

    // Elementals
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.fireElemental.name,
      type: CreatureType.elemental,
      cr: '5',
      crTier: 2,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.reaction,
            damageType: DamageAccent.fire,
            label: 'Fire Form (1d10 ignite)'),
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.fire,
            label: 'Flaming Touch (+6 to hit)'),
      ],
      ac: SrdSummonsLibrary.fireElemental.ac,
      hp: SrdSummonsLibrary.fireElemental.maxHp,
      speed: SrdSummonsLibrary.fireElemental.speed,
      primaryAttack: 'Touch (+6 to hit, 2d6+3 fire & Ignite)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.waterElemental.name,
      type: CreatureType.elemental,
      cr: '5',
      crTier: 2,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            damageType: DamageAccent.cold,
            label: 'Whelm Surge (Recharge 4-6)'),
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Slam Attack (+7 to hit)'),
      ],
      ac: SrdSummonsLibrary.waterElemental.ac,
      hp: SrdSummonsLibrary.waterElemental.maxHp,
      speed: SrdSummonsLibrary.waterElemental.speed,
      primaryAttack: 'Whelm & Slam (+7 to hit, 2d8+4 bludgeoning)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.earthElemental.name,
      type: CreatureType.elemental,
      cr: '5',
      crTier: 2,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.reaction, label: 'Earth Glide Phasing'),
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Siege Slam (+8 to hit)'),
      ],
      ac: SrdSummonsLibrary.earthElemental.ac,
      hp: SrdSummonsLibrary.earthElemental.maxHp,
      speed: SrdSummonsLibrary.earthElemental.speed,
      primaryAttack: 'Siege Slam (+8 to hit, 2d8+5 bludgeoning)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.airElemental.name,
      type: CreatureType.elemental,
      cr: '5',
      crTier: 2,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            damageType: DamageAccent.thunder,
            label: 'Whirlwind Pulse (Recharge 4-6)'),
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Air Slam (+8 to hit)'),
      ],
      ac: SrdSummonsLibrary.airElemental.ac,
      hp: SrdSummonsLibrary.airElemental.maxHp,
      speed: SrdSummonsLibrary.airElemental.speed,
      primaryAttack: 'Whirlwind & Slam (+8 to hit, 2d8+5)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.dustMephit.name,
      type: CreatureType.elemental,
      cr: '1/2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            label: 'Blinding Breath (Recharge 6)'),
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Dust Claws (+4 to hit)'),
      ],
      ac: SrdSummonsLibrary.dustMephit.ac,
      hp: SrdSummonsLibrary.dustMephit.maxHp,
      speed: SrdSummonsLibrary.dustMephit.speed,
      primaryAttack: 'Blinding Breath (DC 10 Dex) & Claws',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.iceMephit.name,
      type: CreatureType.elemental,
      cr: '1/2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            damageType: DamageAccent.cold,
            label: 'Frost Breath (2d4 cold, Recharge 6)'),
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.cold,
            label: 'Ice Claws (+4 to hit)'),
      ],
      ac: SrdSummonsLibrary.iceMephit.ac,
      hp: SrdSummonsLibrary.iceMephit.maxHp,
      speed: SrdSummonsLibrary.iceMephit.speed,
      primaryAttack: 'Frost Breath (2d4 cold, DC 10 Dex)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.magmaMephit.name,
      type: CreatureType.elemental,
      cr: '1/2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            damageType: DamageAccent.fire,
            label: 'Fire Breath (2d6 fire, Recharge 6)'),
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.fire,
            label: 'Magma Claws (+3 to hit)'),
      ],
      ac: SrdSummonsLibrary.magmaMephit.ac,
      hp: SrdSummonsLibrary.magmaMephit.maxHp,
      speed: SrdSummonsLibrary.magmaMephit.speed,
      primaryAttack: 'Fire Breath (2d6 fire, DC 11 Dex)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.steamMephit.name,
      type: CreatureType.elemental,
      cr: '1/4',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            damageType: DamageAccent.fire,
            label: 'Steam Breath (1d4 fire, Recharge 6)'),
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Claws (+2 to hit)'),
      ],
      ac: SrdSummonsLibrary.steamMephit.ac,
      hp: SrdSummonsLibrary.steamMephit.maxHp,
      speed: SrdSummonsLibrary.steamMephit.speed,
      primaryAttack: 'Steam Breath (1d4 fire, DC 10 Dex)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.gargoyle.name,
      type: CreatureType.elemental,
      cr: '2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.reaction, label: 'Stone False Appearance'),
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Bite & Claws (+4 to hit)'),
      ],
      ac: SrdSummonsLibrary.gargoyle.ac,
      hp: SrdSummonsLibrary.gargoyle.maxHp,
      speed: SrdSummonsLibrary.gargoyle.speed,
      primaryAttack: 'Bite & Claws (+4 to hit, 1d6+2 each)',
    ),

    // Beasts & Insects
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.wolf.name,
      type: CreatureType.beast,
      cr: '1/4',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            label: 'Pack Tactics & Bite (+4 to hit)'),
      ],
      ac: SrdSummonsLibrary.wolf.ac,
      hp: SrdSummonsLibrary.wolf.maxHp,
      speed: SrdSummonsLibrary.wolf.speed,
      primaryAttack: 'Bite (+4 to hit, 2d4+2 & DC 11 Prone)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.direWolf.name,
      type: CreatureType.beast,
      cr: '1',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            label: 'Apex Bite (+5 to hit & DC 13 Prone)'),
      ],
      ac: SrdSummonsLibrary.direWolf.ac,
      hp: SrdSummonsLibrary.direWolf.maxHp,
      speed: SrdSummonsLibrary.direWolf.speed,
      primaryAttack: 'Bite (+5 to hit, 2d6+3 & DC 13 Prone)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.giantSpider.name,
      type: CreatureType.beast,
      cr: '1',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.poison,
            label: 'Venom Bite (2d8 poison)'),
        ActionTraitRing(
            ringType: ActionRingType.ranged,
            label: 'Web Projectile (+5 to hit)'),
      ],
      ac: SrdSummonsLibrary.giantSpider.ac,
      hp: SrdSummonsLibrary.giantSpider.maxHp,
      speed: SrdSummonsLibrary.giantSpider.speed,
      primaryAttack: 'Web & Bite (+5 to hit, 1d8+3 & 2d8 poison)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.giantEagle.name,
      type: CreatureType.beast,
      cr: '1',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee, label: 'Aerial Talons (+5 to hit)'),
      ],
      ac: SrdSummonsLibrary.giantEagle.ac,
      hp: SrdSummonsLibrary.giantEagle.maxHp,
      speed: SrdSummonsLibrary.giantEagle.speed,
      primaryAttack: 'Beak & Talons (+5 to hit, 2d6+3 slashing)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.giantCentipede.name,
      type: CreatureType.beast,
      cr: '1/4',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.poison,
            label: 'Venom Bite (3d6 poison, DC 11)'),
      ],
      ac: SrdSummonsLibrary.giantCentipede.ac,
      hp: SrdSummonsLibrary.giantCentipede.maxHp,
      speed: SrdSummonsLibrary.giantCentipede.speed,
      primaryAttack: 'Bite (+4 to hit, 1d4+2 & 3d6 poison)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.giantWasp.name,
      type: CreatureType.beast,
      cr: '1/2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.poison,
            label: 'Paralyzing Sting (3d6 poison)'),
      ],
      ac: SrdSummonsLibrary.giantWasp.ac,
      hp: SrdSummonsLibrary.giantWasp.maxHp,
      speed: SrdSummonsLibrary.giantWasp.speed,
      primaryAttack: 'Sting (+4 to hit, 1d6+2 & 3d6 poison)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.giantScorpion.name,
      type: CreatureType.beast,
      cr: '3',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.poison,
            label: 'Deadly Stinger (4d10 poison)'),
        ActionTraitRing(
            ringType: ActionRingType.melee,
            label: 'Grappling Claws (+4 to hit)'),
      ],
      ac: SrdSummonsLibrary.giantScorpion.ac,
      hp: SrdSummonsLibrary.giantScorpion.maxHp,
      speed: SrdSummonsLibrary.giantScorpion.speed,
      primaryAttack: 'Claws & Sting (+4 to hit, 1d8+2 & 4d10 poison)',
    ),

    // Magic Item Summons
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.berserker.name,
      type: CreatureType.humanoid,
      cr: '2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.reaction, label: 'Reckless Attack Vector'),
        ActionTraitRing(
            ringType: ActionRingType.melee,
            label: 'Greataxe Strike (+5 to hit)'),
      ],
      ac: SrdSummonsLibrary.berserker.ac,
      hp: SrdSummonsLibrary.berserker.maxHp,
      speed: SrdSummonsLibrary.berserker.speed,
      primaryAttack: 'Reckless Greataxe (+5 to hit, 1d12+3 slashing)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.bronzeGriffon.name,
      type: CreatureType.monstrosity,
      cr: '2',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            label: 'Multiattack: Beak & Claws (+6 to hit)'),
      ],
      ac: SrdSummonsLibrary.bronzeGriffon.ac,
      hp: SrdSummonsLibrary.bronzeGriffon.maxHp,
      speed: SrdSummonsLibrary.bronzeGriffon.speed,
      primaryAttack: 'Beak & Claws (+6 to hit, 1d8+4 & 2d6+4)',
    ),
    GlyphCreatureEntry(
      name: SrdSummonsLibrary.marbleElephant.name,
      type: CreatureType.beast,
      cr: '4',
      crTier: 1,
      actionRings: const [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            label: 'Trampling Charge & Gore (+8 to hit)'),
      ],
      ac: SrdSummonsLibrary.marbleElephant.ac,
      hp: SrdSummonsLibrary.marbleElephant.maxHp,
      speed: SrdSummonsLibrary.marbleElephant.speed,
      primaryAttack: 'Gore & Trample (+8 to hit, 3d8+6 & 3d10+6)',
    ),
  ];

  // ---------------------------------------------------------------------------
  // MAGIC ITEMS & EQUIPMENT (Iconic 5e SRD Items across all 9 Categories)
  // ---------------------------------------------------------------------------
  static const List<GlyphItemEntry> allItems = [
    // WEAPONS
    GlyphItemEntry(
      name: 'Flame Tongue',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.fire,
            label: '+2d6 Fire Damage on Hit'),
      ],
      summary:
          'While the sword is ablaze, it deals an extra 2d6 fire damage to any target it hits and sheds bright light.',
    ),
    GlyphItemEntry(
      name: 'Frost Brand',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      damageAccent: DamageAccent.cold,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.cold,
            label: '+1d6 Cold Damage & Resistance'),
      ],
      summary:
          'Deals an extra 1d6 cold damage to any target it hits, grants resistance to fire damage, and extinguishes open flames.',
    ),
    GlyphItemEntry(
      name: 'Sun Blade',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.radiant,
            label: '+2 Attack & 1d8 Radiant Damage'),
      ],
      summary:
          'A blade of pure radiant sunlight that deals radiant damage instead of slashing, with +2 bonus to attack and damage rolls.',
    ),
    GlyphItemEntry(
      name: 'Holy Avenger',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.radiant,
            label: '+3 Attack & +2d10 vs Fiends/Undead'),
        ActionTraitRing(
            ringType: ActionRingType.sustain,
            label: '10-ft Aura of Advantage on Spell Saves'),
      ],
      summary:
          'Legendary paladin blade granting +3 bonus to attack and damage rolls, +2d10 radiant damage vs fiends/undead, and an aura of spell saving throw advantage.',
    ),

    // ARMOR & SHIELDS
    GlyphItemEntry(
      name: 'Mithral Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      summary:
          'Mithral is a light, flexible metal. A mithral chain shirt or breastplate can be worn under normal clothes without Stealth disadvantage.',
    ),
    GlyphItemEntry(
      name: 'Adamantine Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.reaction,
            label: 'Critical Hit Immunity'),
      ],
      summary:
          'Reinforced with one of the hardest substances in existence. Any critical hit against you becomes a normal hit.',
    ),
    GlyphItemEntry(
      name: 'Armor of Invulnerability',
      category: ItemCategory.armor,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.reaction,
            label: 'Nonmagical Damage Resistance'),
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            label: 'Immunity Action (1/Day for 10 Min)'),
      ],
      summary:
          'Plate armor granting resistance to nonmagical damage, and an action to become immune to all nonmagical damage for 10 minutes.',
    ),

    // POTIONS
    GlyphItemEntry(
      name: 'Potion of Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.common,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.sustain,
            label: 'Regain 2d4 + 2 Hit Points'),
      ],
      summary:
          'A magical red fluid that glimmers when agitated. Drinking it restores 2d4 + 2 hit points.',
    ),
    GlyphItemEntry(
      name: 'Potion of Greater Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.sustain,
            label: 'Regain 4d4 + 4 Hit Points'),
      ],
      summary:
          'Restores 4d4 + 4 hit points when consumed as a bonus action (2024) or action (2014).',
    ),
    GlyphItemEntry(
      name: 'Potion of Invisibility',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.control,
            label: 'Invisible for 1 Hour'),
      ],
      summary:
          'Become invisible for 1 hour after drinking. The effect ends early if you attack or cast a spell.',
    ),

    // RINGS
    GlyphItemEntry(
      name: 'Ring of Protection',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.reaction,
            label: '+1 to AC & Saving Throws'),
      ],
      summary:
          'You gain a +1 bonus to Armor Class and saving throws while wearing this ring.',
    ),
    GlyphItemEntry(
      name: 'Ring of Spell Storing',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            label: 'Store up to 5 Levels of Spells'),
      ],
      summary:
          'Holds up to 5 levels of spells that any creature can cast into the ring and the wearer can release without spell slots.',
    ),
    GlyphItemEntry(
      name: 'Ring of Three Wishes',
      category: ItemCategory.ring,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.legendary,
            label: '3 Charges of the Wish Spell'),
      ],
      summary:
          'Set with three rubies. While wearing it, you can use an action to expend 1 charge and cast the Wish spell.',
    ),

    // RODS
    GlyphItemEntry(
      name: 'Rod of the Pact Keeper',
      category: ItemCategory.rod,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      damageAccent: DamageAccent.necrotic,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.sustain,
            label: '+1 Spell Attack/DC & Regain 1 Slot'),
      ],
      summary:
          'Grants a bonus to warlock spell attack rolls and spell save DCs, and allows the warlock to regain 1 warlock spell slot once per long rest.',
    ),
    GlyphItemEntry(
      name: 'Rod of Lordly Might',
      category: ItemCategory.rod,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            label: 'Morphs into Flame Sword, Battleaxe, Spear'),
        ActionTraitRing(
            ringType: ActionRingType.control,
            label: 'Paralyze / Drain Life Actions'),
      ],
      summary:
          'Versatile sovereign rod featuring six buttons that transform the rod into magical weapons, ladders, battering rams, and life-drain conduits.',
    ),

    // SCROLLS
    GlyphItemEntry(
      name: 'Spell Scroll (Fireball)',
      category: ItemCategory.scroll,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            damageType: DamageAccent.fire,
            label: '8d6 Fire Damage (DC 15 Save)'),
      ],
      summary:
          'Bears the words of Fireball. If the spell is on your class’s spell list, you can read and cast it without material components.',
    ),
    GlyphItemEntry(
      name: 'Scroll of Resurrection',
      category: ItemCategory.scroll,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.sustain,
            label: 'Restore Dead Creature to Life'),
      ],
      summary:
          'Touches a dead creature and restores it to life with all its hit points, closing mortal wounds and curing nonmagical poisons.',
    ),

    // STAVES
    GlyphItemEntry(
      name: 'Staff of Power',
      category: ItemCategory.staff,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      damageAccent: DamageAccent.force,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.melee,
            damageType: DamageAccent.force,
            label: '+2 Quarterstaff & +2 AC/Saves'),
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            label: '20 Charges (Fireball, Lightning, Cone of Cold)'),
      ],
      summary:
          'Mighty archmage staff with 20 charges, granting +2 to AC, saving throws, and spell attack rolls, with retributive strike capability.',
    ),
    GlyphItemEntry(
      name: 'Staff of the Magi',
      category: ItemCategory.staff,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      damageAccent: DamageAccent.force,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.reaction,
            label: 'Spell Absorption Reaction'),
        ActionTraitRing(
            ringType: ActionRingType.legendary,
            label: '50 Charges across 7th-Level Spells'),
      ],
      summary:
          'Supreme focus for wizards, sorcerers, and warlocks with 50 charges, advantage on saving throws against spells, and spell absorption.',
    ),

    // WANDS
    GlyphItemEntry(
      name: 'Wand of Magic Missiles',
      category: ItemCategory.wand,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.force,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.ranged,
            damageType: DamageAccent.force,
            label: '7 Charges: Auto-Hit Darts'),
      ],
      summary:
          'Contains 7 charges. Can cast the 1st-level Magic Missile spell or upcast it by expending additional charges.',
    ),
    GlyphItemEntry(
      name: 'Wand of Fireballs',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.recharge,
            damageType: DamageAccent.fire,
            label: '7 Charges: 8d6+ Fireball (DC 15)'),
      ],
      summary:
          'Contains 7 charges. While holding it, you can use an action to expend charges and cast Fireball at 3rd level or higher.',
    ),

    // WONDROUS ITEMS
    GlyphItemEntry(
      name: 'Bag of Holding',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      summary:
          'A magical bag that opens into an extradimensional space holding up to 500 pounds and 64 cubic feet while always weighing 15 pounds.',
    ),
    GlyphItemEntry(
      name: 'Cloak of Protection',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.reaction,
            label: '+1 to AC and Saving Throws'),
      ],
      summary:
          'You gain a +1 bonus to AC and saving throws while you wear this cloak.',
    ),
    GlyphItemEntry(
      name: 'Deck of Many Things',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(
            ringType: ActionRingType.legendary,
            label: 'Fate Altering Arcane Cards'),
      ],
      summary:
          'A deck of vellum cards containing cosmic fortunes and catastrophes that irrevocably warp destinies.',
    ),

    // ADVENTURING GEAR
    GlyphItemEntry(
      name: 'Explorer\'s Pack & Harness',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      summary:
          'A heavy canvas expedition backpack rigged with bedroll, torches, rations, and 50 feet of silk climbing rope.',
    ),
    GlyphItemEntry(
      name: 'Thieves\' Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      summary:
          'A set of lock picks, tension wrenches, small mirror, narrow file, and pliers in a folding leather case.',
    ),

    // GEMSTONES
    GlyphItemEntry(
      name: 'Diamond (5,000 GP)',
      category: ItemCategory.gemstone,
      rarity: ItemRarity.veryRare,
      summary:
          'A brilliant flawless diamond utilized for resurrection spells and royal treasury reserves.',
    ),

    // ART OBJECTS
    GlyphItemEntry(
      name: 'Jeweled Gold Crown (7,500 GP)',
      category: ItemCategory.artObject,
      rarity: ItemRarity.legendary,
      summary:
          'An ancient imperial diadem encrusted with rubies, sapphires, and platinum filigree.',
    ),

    // TRINKETS
    GlyphItemEntry(
      name: 'Mummified Goblin Hand',
      category: ItemCategory.trinket,
      rarity: ItemRarity.common,
      summary:
          'A curious desiccated goblin hand wearing a rusted iron band, rolled from the 100 SRD Trinkets.',
    ),
  ];

  // ---------------------------------------------------------------------------
  // FEATS & EPIC BOONS (Representative 2014/2024 SRD Feats)
  // ---------------------------------------------------------------------------
  static const List<GlyphFeatEntry> allFeats = [
    GlyphFeatEntry(
      featId: 'feat_alert',
      name: 'Alert',
      featCategory: FeatCategory.origin,
      minLevel: 1,
      triggerType: FeatTriggerType.passive,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: '+Proficiency to Initiative & Swap Initiative',
        ),
      ],
      summary:
          'Always on the lookout for danger. You gain a bonus to initiative rolls equal to your proficiency bonus and can swap initiative with a willing ally.',
    ),
    GlyphFeatEntry(
      featId: 'feat_war_caster',
      name: 'War Caster',
      featCategory: FeatCategory.general,
      minLevel: 4,
      prerequisite: 'Spellcasting or Pact Magic feature',
      triggerType: FeatTriggerType.reaction,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.concentration,
          label: 'Advantage on Concentration Saves',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Opportunity Attack Spell Cast',
        ),
      ],
      summary:
          'Master of combat spellcasting. Grants advantage on Constitution saves for concentration, somatic spells with weapons equipped, and casting spells on Opportunity Attacks.',
    ),
    GlyphFeatEntry(
      featId: 'feat_great_weapon_master',
      name: 'Great Weapon Master',
      featCategory: FeatCategory.general,
      minLevel: 4,
      prerequisite: 'Strength 13+',
      triggerType: FeatTriggerType.bonusAction,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          label: '+Proficiency Heavy Weapon Damage',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          label: 'Bonus Attack on Crit or Kill',
        ),
      ],
      summary:
          'Devastating strikes with heavy weapons. Hit with heavy weapons deals extra damage equal to your proficiency bonus, and crits/kills grant a bonus attack.',
    ),
    GlyphFeatEntry(
      featId: 'feat_sharpshooter',
      name: 'Sharpshooter',
      featCategory: FeatCategory.general,
      minLevel: 4,
      prerequisite: 'Dexterity 13+',
      triggerType: FeatTriggerType.passive,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.ranged,
          label: 'Ignore 1/2 & 3/4 Cover, Max Range',
        ),
      ],
      summary:
          'Supreme marksman. Ranged weapon attacks ignore half and three-quarters cover, suffer no disadvantage at long range, and can fire in melee range.',
    ),
    GlyphFeatEntry(
      featId: 'feat_sentinel',
      name: 'Sentinel',
      featCategory: FeatCategory.general,
      minLevel: 4,
      prerequisite: 'Strength or Dexterity 13+',
      triggerType: FeatTriggerType.reaction,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'OA Sets Speed to 0 & Ignore Disengage',
        ),
      ],
      summary:
          'Immovable guardian. Hitting a creature with an opportunity attack reduces its speed to 0 for the turn, and you can strike creatures even if they disengage.',
    ),
    GlyphFeatEntry(
      featId: 'feat_lucky',
      name: 'Lucky',
      featCategory: FeatCategory.origin,
      minLevel: 1,
      triggerType: FeatTriggerType.reaction,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.resource,
          label: 'Luck Points = Proficiency Bonus',
        ),
      ],
      summary:
          'Uncanny knack for survival. You possess luck points equal to your proficiency bonus to gain advantage or force disadvantage on incoming attacks.',
    ),
    GlyphFeatEntry(
      featId: 'feat_tavern_brawler',
      name: 'Tavern Brawler',
      featCategory: FeatCategory.origin,
      minLevel: 1,
      triggerType: FeatTriggerType.passive,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          label: '1d4 Unarmed Strike & Push 5 ft',
        ),
      ],
      summary:
          'Accustomed to rough-and-tumble fighting. Your unarmed strikes deal 1d4 + Str mod damage, you reroll damage 1s, and you can push targets 5 feet on hit.',
    ),
    GlyphFeatEntry(
      featId: 'feat_inspiring_leader',
      name: 'Inspiring Leader',
      featCategory: FeatCategory.general,
      minLevel: 4,
      prerequisite: 'Charisma or Wisdom 13+',
      triggerType: FeatTriggerType.resource,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.sustain,
          label: 'Temp HP = Level + Ability Mod',
        ),
      ],
      summary:
          'Inspire confidence in your allies. Deliver a 10-minute speech granting temporary hit points equal to your level + ability modifier to up to 6 allies.',
    ),
    GlyphFeatEntry(
      featId: 'feat_boon_combat_prowess',
      name: 'Boon of Combat Prowess',
      featCategory: FeatCategory.epicBoon,
      minLevel: 19,
      triggerType: FeatTriggerType.passive,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.legendary,
          label: 'Turn Miss into Hit (1/Turn)',
        ),
      ],
      summary:
          'Transcendent martial mastery. When you miss with an attack roll, you can choose to hit instead once per combat round.',
    ),
    GlyphFeatEntry(
      featId: 'feat_boon_spell_recall',
      name: 'Boon of Spell Recall',
      featCategory: FeatCategory.epicBoon,
      minLevel: 19,
      triggerType: FeatTriggerType.reaction,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.legendary,
          damageType: DamageAccent.radiant,
          label: '25% Free Slot Chance on 1st-4th Level',
        ),
      ],
      summary:
          'Unfathomable arcane resonance. Whenever you cast a spell of 1st through 4th level, roll a d4; on a 4, the spell slot is not expended.',
    ),
  ];

  // ---------------------------------------------------------------------------
  // CHARACTER CLASSES (13 Core SRD Classes & Hit Die Geometries)
  // ---------------------------------------------------------------------------
  static const List<GlyphClassEntry> allClasses = [
    GlyphClassEntry(
      name: 'Barbarian',
      classType: DndClassType.barbarian,
      primaryAbility: 'Strength',
      savingThrows: 'Strength & Constitution',
      primaryResource: 'Rage (d12 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd12 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          label: 'Enter Rage & Primal Power',
        ),
      ],
      summary:
          'A fierce warrior of primitive background who can enter a battle rage, shrugging off fatal injuries with a titanic d12 hit die.',
    ),
    GlyphClassEntry(
      name: 'Bard',
      classType: DndClassType.bard,
      primaryAbility: 'Charisma',
      savingThrows: 'Dexterity & Charisma',
      primaryResource: 'Bardic Inspiration (d8 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd8 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          label: 'Bardic Inspiration Die',
        ),
      ],
      summary:
          'An inspiring magician whose power echoes the music of creation, weaving spells and inspiring allies with harmonic resonance.',
    ),
    GlyphClassEntry(
      name: 'Cleric',
      classType: DndClassType.cleric,
      primaryAbility: 'Wisdom',
      savingThrows: 'Wisdom & Charisma',
      primaryResource: 'Channel Divinity (d8 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd8 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.resource,
          label: 'Channel Divinity & Turn Undead',
        ),
      ],
      summary:
          'A priestly champion who wields divine magic in service of a higher power, smiting unholy foes and restoring vitality.',
    ),
    GlyphClassEntry(
      name: 'Druid',
      classType: DndClassType.druid,
      primaryAbility: 'Wisdom',
      savingThrows: 'Intelligence & Wisdom',
      primaryResource: 'Wild Shape (d8 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd8 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          label: 'Wild Shape Beast Matrix',
        ),
      ],
      summary:
          'A priest of the Old Faith, wielding the powers of nature and adopting the forms of beasts through sacred Wild Shape.',
    ),
    GlyphClassEntry(
      name: 'Fighter',
      classType: DndClassType.fighter,
      primaryAbility: 'Strength or Dexterity',
      savingThrows: 'Strength & Constitution',
      primaryResource: 'Action Surge (d10 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd10 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.resource,
          label: 'Action Surge (Extra Action)',
        ),
      ],
      summary:
          'A master of martial combat, skilled with a variety of weapons and armor, capable of pushing past physical limits with Action Surge.',
    ),
    GlyphClassEntry(
      name: 'Monk',
      classType: DndClassType.monk,
      primaryAbility: 'Dexterity & Wisdom',
      savingThrows: 'Strength & Dexterity',
      primaryResource: 'Focus / Ki Points (d8 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd8 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.resource,
          label: 'Focus Points (Flurry, Patient Defense)',
        ),
      ],
      summary:
          'A master of martial arts, harnessing the power of the body in pursuit of physical and spiritual perfection through ki channels.',
    ),
    GlyphClassEntry(
      name: 'Paladin',
      classType: DndClassType.paladin,
      primaryAbility: 'Strength & Charisma',
      savingThrows: 'Wisdom & Charisma',
      primaryResource: 'Lay on Hands & Divine Smite (d10 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd10 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.sustain,
          damageType: DamageAccent.radiant,
          label: 'Lay on Hands Pool (5x Level)',
        ),
      ],
      summary:
          'A holy warrior bound to a sacred oath, smiting foes with radiant retribution and healing comrades with Lay on Hands.',
    ),
    GlyphClassEntry(
      name: 'Ranger',
      classType: DndClassType.ranger,
      primaryAbility: 'Dexterity & Wisdom',
      savingThrows: 'Strength & Dexterity',
      primaryResource: 'Hunter\'s Mark & Spell Slots (d10 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd10 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          label: 'Hunter\'s Mark Tracking',
        ),
      ],
      summary:
          'A warrior who uses martial prowess and nature magic to combat threats on the edges of civilization, tracking targets across any terrain.',
    ),
    GlyphClassEntry(
      name: 'Rogue',
      classType: DndClassType.rogue,
      primaryAbility: 'Dexterity',
      savingThrows: 'Dexterity & Intelligence',
      primaryResource: 'Sneak Attack (d8 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd8 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.melee,
          label: 'Sneak Attack (+Xd6 Damage)',
        ),
      ],
      summary:
          'A scoundrel who uses stealth and trickery to overcome obstacles and enemies, landing devastating sneak attack strikes.',
    ),
    GlyphClassEntry(
      name: 'Sorcerer',
      classType: DndClassType.sorcerer,
      primaryAbility: 'Charisma',
      savingThrows: 'Constitution & Charisma',
      primaryResource: 'Sorcery Points & Metamagic (d6 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd6 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.resource,
          damageType: DamageAccent.fire,
          label: 'Sorcery Points & Metamagic Shaper',
        ),
      ],
      summary:
          'A spellcaster who draws on inherent magic from a gift or bloodline, bending and sculpting spells with Metamagic.',
    ),
    GlyphClassEntry(
      name: 'Warlock',
      classType: DndClassType.warlock,
      primaryAbility: 'Charisma',
      savingThrows: 'Wisdom & Charisma',
      primaryResource: 'Pact Magic Slots (d8 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd8 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.recharge,
          damageType: DamageAccent.necrotic,
          label: 'Pact Slots (Recharge on Short Rest)',
        ),
      ],
      summary:
          'A wielder of magic that is derived from a bargain with an otherworldly patron, unleashing potent spells that recharge on short rests.',
    ),
    GlyphClassEntry(
      name: 'Wizard',
      classType: DndClassType.wizard,
      primaryAbility: 'Intelligence',
      savingThrows: 'Intelligence & Wisdom',
      primaryResource: 'Arcane Recovery & Spellbook (d6 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd6 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.resource,
          damageType: DamageAccent.force,
          label: 'Arcane Recovery (Half Level in Slots)',
        ),
      ],
      summary:
          'A scholarly magic-user capable of manipulating the structures of reality, mastering the widest repository of arcane spells.',
    ),
    GlyphClassEntry(
      name: 'Artificer',
      classType: DndClassType.artificer,
      primaryAbility: 'Intelligence',
      savingThrows: 'Constitution & Intelligence',
      primaryResource: 'Infusions & Magical Tinkering (d8 Hit Die)',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.hitDie,
          label: 'd8 Hit Die Geometry',
        ),
        ActionTraitRing(
          ringType: ActionRingType.resource,
          label: 'Infused Items & Crafting Repertoire',
        ),
      ],
      summary:
          'Masters of invention, artificers use ingenuity and magic to unlock extraordinary capabilities in objects and construct techno-magical wonders.',
    ),
  ];

  // ---------------------------------------------------------------------------
  // SPECIES / HERITAGES (10 Core SRD 2014/2024 Species)
  // ---------------------------------------------------------------------------
  static const List<GlyphSpeciesEntry> allSpecies = [
    GlyphSpeciesEntry(
      name: 'Human',
      speciesType: SpeciesType.human,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.speed,
          label: '30 ft Base Movement Speed',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: '+1 to All Ability Scores',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.speed,
          label: '30 ft Base Speed',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Origin Feat & Heroic Inspiration',
        ),
      ],
      summary2014:
          'Versatile and ambitious, 2014 humans gain +1 to all ability scores (or a bonus feat and skill if utilizing Variant Human rules).',
      summary2024:
          'Resourceful and adaptable, 2024 humans gain Heroic Inspiration each long rest, an extra skill proficiency, and a free Origin Feat.',
    ),
    GlyphSpeciesEntry(
      name: 'Elf',
      speciesType: SpeciesType.elf,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Fey Ancestry & Trance (4 Hours)',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Fey Ancestry & Elven Lineage',
        ),
      ],
      summary2014:
          'Magical beings of grace possessing 60 ft darkvision, Keen Senses, Fey Ancestry (advantage vs charms, immune to magical sleep), and 4-hour Trance.',
      summary2024:
          'Otherworldly beings possessing 60 ft darkvision, Fey Ancestry, and specialized Elven Lineages (Drow, High Elf, or Wood Elf).',
    ),
    GlyphSpeciesEntry(
      name: 'Dwarf',
      speciesType: SpeciesType.dwarf,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          damageType: DamageAccent.poison,
          label: 'Poison Resistance & Stonecunning',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (120 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          damageType: DamageAccent.poison,
          label: 'Poison Resistance & +1 HP/Level',
        ),
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Stonecunning (Tremorsense 60 ft)',
        ),
      ],
      summary2014:
          'Hardy subterranean artisans with 25 ft base speed (unhindered by heavy armor), 60 ft darkvision, Dwarven Resilience against poison, and Stonecunning.',
      summary2024:
          'Hardy subterranean folk with 30 ft base speed, 120 ft darkvision, Dwarven Toughness (+1 HP/level), and Stonecunning Tremorsense on stone surfaces.',
    ),
    GlyphSpeciesEntry(
      name: 'Halfling',
      speciesType: SpeciesType.halfling,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Lucky (Reroll d20 1s)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Brave (Advantage vs Frightened)',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Luck (Reroll d20 1s)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Brave (Advantage vs Frightened)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Naturally Stealthy',
        ),
      ],
      summary2014:
          'Diminutive, cheerful wanderers with 25 ft speed, rerolling natural 1s on d20 rolls via Lucky, Brave advantage vs frightened, and Halfling Nimbleness.',
      summary2024:
          'Diminutive, agile survivors with 30 ft speed, rerolling natural 1s via Luck, Brave advantage vs frightened, and moving through larger creatures.',
    ),
    GlyphSpeciesEntry(
      name: 'Dragonborn',
      speciesType: SpeciesType.dragonborn,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.recharge,
          damageType: DamageAccent.fire,
          label: 'Draconic Breath Weapon (Action)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          damageType: DamageAccent.fire,
          label: 'Draconic Damage Resistance',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.recharge,
          damageType: DamageAccent.fire,
          label: 'Draconic Breath Weapon (Attack Action)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          label: 'Draconic Flight (Lv 5+)',
        ),
      ],
      summary2014:
          'Noble draconic humanoids wielding a full-action elemental Breath Weapon and damage resistance matching their draconic ancestry.',
      summary2024:
          'Draconic heroes whose Breath Weapon replaces one attack in an Attack action, gaining 60 ft darkvision and spectral Draconic Flight at level 5.',
    ),
    GlyphSpeciesEntry(
      name: 'Gnome',
      speciesType: SpeciesType.gnome,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Gnome Cunning (Advantage vs Magic Saves)',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Gnomish Cunning (Int/Wis/Cha Saves)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Gnomish Lineage (Forest / Rock)',
        ),
      ],
      summary2014:
          'Diminutive, inventive explorers with 25 ft base speed, 60 ft darkvision, and Gnome Cunning granting advantage on Int/Wis/Cha saves against magic.',
      summary2024:
          'Curious inventors with 30 ft base speed, 60 ft darkvision, Gnomish Cunning on Int/Wis/Cha saves, and Forest/Rock lineage magic.',
    ),
    GlyphSpeciesEntry(
      name: 'Tiefling',
      speciesType: SpeciesType.tiefling,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          damageType: DamageAccent.fire,
          label: 'Hellish Resistance (Fire) & Infernal Legacy',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          damageType: DamageAccent.fire,
          label: 'Fiendish Legacy (Abyssal / Chthonic / Infernal)',
        ),
      ],
      summary2014:
          'Infused with infernal essence, tieflings have 60 ft darkvision, Hellish Resistance to fire damage, and innate Infernal Legacy spells.',
      summary2024:
          'Heirs to fiendish planes (Abyssal, Chthonic, or Infernal), tieflings wield 60 ft darkvision, plane-specific damage resistance, and legacy spells.',
    ),
    GlyphSpeciesEntry(
      name: 'Orc',
      speciesType: SpeciesType.orc,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Darkvision (60 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Relentless Endurance (Drop to 1 HP)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Savage Attacks (Extra Critical Die)',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.sense,
          label: 'Superior Darkvision (120 ft)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          label: 'Adrenaline Rush (Dash + Temp HP)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Relentless Endurance (Drop to 1 HP)',
        ),
      ],
      summary2014:
          'Fierce warriors endowed with 60 ft darkvision, Menacing proficiency, Relentless Endurance (1 HP instead of 0 once/long rest), and Savage Attacks.',
      summary2024:
          'Unyielding survivors possessing 120 ft darkvision, Adrenaline Rush (bonus action Dash + temporary HP), and Relentless Endurance.',
    ),
    GlyphSpeciesEntry(
      name: 'Goliath',
      speciesType: SpeciesType.goliath,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Stone\'s Endurance (Reduce 1d12 + Con Damage)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.passive,
          label: 'Powerful Build & Mountain Born',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.speed,
          label: '35 ft Base Movement Speed',
        ),
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Stone\'s Endurance (Reduce 1d12 + Con Damage)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          label: 'Large Form (Bonus Action, Lv 5+)',
        ),
      ],
      summary2014:
          'Mountain-dwelling champions with 30 ft speed, Natural Athlete, Stone\'s Endurance (reduce damage by 1d12+Con), Powerful Build, and cold resistance.',
      summary2024:
          'Giant-blooded champions with 35 ft base speed, Giant Ancestry benefits, Powerful Build, and the ability to grow Large at level 5.',
    ),
    GlyphSpeciesEntry(
      name: 'Aasimar',
      speciesType: SpeciesType.aasimar,
      actionRings2014: [
        ActionTraitRing(
          ringType: ActionRingType.sustain,
          damageType: DamageAccent.radiant,
          label: 'Healing Hands (Action, HP = Level)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          damageType: DamageAccent.radiant,
          label: 'Celestial Revelation (Action)',
        ),
      ],
      actionRings2024: [
        ActionTraitRing(
          ringType: ActionRingType.sustain,
          damageType: DamageAccent.radiant,
          label: 'Healing Hands (Bonus Action, D6s = Prof)',
        ),
        ActionTraitRing(
          ringType: ActionRingType.bonusAction,
          damageType: DamageAccent.radiant,
          label: 'Celestial Revelation (Bonus Action Wings)',
        ),
      ],
      summary2014:
          'Mortals carrying celestial spark with 60 ft darkvision, Celestial Resistance to radiant and necrotic, Healing Hands, and Celestial Revelation.',
      summary2024:
          'Celestial vessels wielding 60 ft darkvision, necrotic/radiant resistance, bonus action Healing Hands (d6s = Proficiency Bonus), and bonus action Revelation.',
    ),
  ];

  // ---------------------------------------------------------------------------
  // GENERIC UI & POLYHEDRAL HUD ICONS
  // ---------------------------------------------------------------------------
  static const List<GlyphGenericEntry> allGenericUi = [
    // DICE POLYHEDRALS
    GlyphGenericEntry(
      name: 'd4 Die',
      uiType: GenericUiGlyphType.d4,
      group: 'Dice Polyhedrals',
      summary:
          'Tetrahedral 4-sided wireframe die used for daggers, healing potions, and bless bonuses.',
    ),
    GlyphGenericEntry(
      name: 'd6 Die',
      uiType: GenericUiGlyphType.d6,
      group: 'Dice Polyhedrals',
      summary:
          'Hexahedral 6-sided isometric cube used for sneak attack, fireball, shortswords, and ability scores.',
    ),
    GlyphGenericEntry(
      name: 'd8 Die',
      uiType: GenericUiGlyphType.d8,
      group: 'Dice Polyhedrals',
      summary:
          'Octahedral 8-sided diamond wireframe die used for longswords, divine smite, and medium hit dice.',
    ),
    GlyphGenericEntry(
      name: 'd10 Die',
      uiType: GenericUiGlyphType.d10,
      group: 'Dice Polyhedrals',
      summary:
          'Pentagonal trapezohedron 10-sided kite die used for eldritch blast, halberds, and fighter hit dice.',
    ),
    GlyphGenericEntry(
      name: 'd12 Die',
      uiType: GenericUiGlyphType.d12,
      group: 'Dice Polyhedrals',
      summary:
          'Dodecahedral 12-sided faceted polygon die used for greataxes, barbarian hit dice, and chain lightning.',
    ),
    GlyphGenericEntry(
      name: 'd20 Die',
      uiType: GenericUiGlyphType.d20,
      group: 'Dice Polyhedrals',
      summary:
          'Icosahedral 20-sided core D&D die used for all attack rolls, ability checks, and saving throws.',
    ),
    GlyphGenericEntry(
      name: 'd100 Die',
      uiType: GenericUiGlyphType.d100,
      group: 'Dice Polyhedrals',
      summary:
          'Percentile dual-coordinate matrix die used for divine intervention and loot tables.',
    ),

    // STATUS HUD INDICATORS
    GlyphGenericEntry(
      name: 'Advantage',
      uiType: GenericUiGlyphType.advantage,
      group: 'Status HUD Badges',
      summary:
          'Dual upward green flow chevrons indicating roll 2d20 and take the higher result.',
    ),
    GlyphGenericEntry(
      name: 'Disadvantage',
      uiType: GenericUiGlyphType.disadvantage,
      group: 'Status HUD Badges',
      summary:
          'Dual downward crimson flow chevrons indicating roll 2d20 and take the lower result.',
    ),
    GlyphGenericEntry(
      name: 'Concentrating',
      uiType: GenericUiGlyphType.concentrating,
      group: 'Status HUD Badges',
      summary:
          'Orbital satellite telemetry loop indicating active spell concentration maintenance.',
    ),
    GlyphGenericEntry(
      name: 'Death Save',
      uiType: GenericUiGlyphType.deathSave,
      group: 'Status HUD Badges',
      summary:
          'Cardiac electrocardiogram telemetry line indicating active death saving throw state at 0 HP.',
    ),

    // ACTION ECONOMY COUNTERS
    GlyphGenericEntry(
      name: 'Action',
      uiType: GenericUiGlyphType.actionEconomyAction,
      group: 'Action Economy',
      summary:
          'Standard primary action economy token used for Attack, Cast a Spell, Dash, Disengage, Dodge, and Help.',
    ),
    GlyphGenericEntry(
      name: 'Bonus Action',
      uiType: GenericUiGlyphType.actionEconomyBonus,
      group: 'Action Economy',
      summary:
          'Triple-spark quick action economy token used for swift spells, second wind, and off-hand strikes.',
    ),
    GlyphGenericEntry(
      name: 'Reaction',
      uiType: GenericUiGlyphType.actionEconomyReaction,
      group: 'Action Economy',
      summary:
          'Deflection bracket reaction economy token used for Shield, Counterspell, and Opportunity Attacks.',
    ),
  ];
}
