import 'dm_screen_data.dart';
import 'spellbook_data.dart';
import 'srd_summons/srd_summons_library.dart';

/// Data model representing a spell entry in the Glyph Gallery.
class GlyphSpellEntry {
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
  List<ActionTraitRing> get actionRings =>
      spell.getGlyphActionRings(DmRulesEdition.v2024);
  DamageAccent? get damageAccent =>
      spell.getGlyphPrimaryDamageAccent(DmRulesEdition.v2024);
  String get castingTime => spell.getRules(DmRulesEdition.v2024).castingTime;
  String get range => spell.getRules(DmRulesEdition.v2024).range;
  String get duration => spell.getRules(DmRulesEdition.v2024).duration;

  String get levelDescription => level == 0 ? 'Cantrip' : 'Level $level';
}

/// Data model representing a creature entry in the Glyph Gallery.
class GlyphCreatureEntry {
  final String name;
  final CreatureType type;
  final String cr;
  final int crTier; // 1: CR 0-4, 2: CR 5-10, 3: CR 11-16, 4: CR 17+
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
}

/// Data model representing a magic item entry in the Glyph Gallery.
class GlyphItemEntry {
  final String name;
  final ItemCategory category;
  final ItemRarity rarity;
  final bool requiresAttunement;
  final DamageAccent? damageAccent;
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
}

/// Library of known spells, creatures, and magic items in the toolkit with multi-ring action traits.
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
  ];
}
