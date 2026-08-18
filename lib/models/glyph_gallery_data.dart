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

/// Library of known spells and summons/creatures in the toolkit with multi-ring action traits.
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
}
