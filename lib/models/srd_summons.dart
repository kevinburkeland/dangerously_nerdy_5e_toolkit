import 'package:flutter/material.dart';

enum SummonCategory { spell, magicItem }

class MinionStatBlock {
  final String id;
  final String name;
  final String sizeDisplay;
  final String crDisplay;
  final int ac;
  final int maxHp;
  final int attackBonus;
  final int damageDiceCount;
  final int damageDiceSides;
  final int damageBonus;
  final String damageType;
  final int secondaryDamageDiceCount;
  final int secondaryDamageDiceSides;
  final String? secondaryDamageType;
  final bool hasPackTactics;
  final String? specialTrait;
  final Color accentColor;

  const MinionStatBlock({
    required this.id,
    required this.name,
    required this.sizeDisplay,
    required this.crDisplay,
    required this.ac,
    required this.maxHp,
    required this.attackBonus,
    required this.damageDiceCount,
    required this.damageDiceSides,
    required this.damageBonus,
    required this.damageType,
    this.secondaryDamageDiceCount = 0,
    this.secondaryDamageDiceSides = 0,
    this.secondaryDamageType,
    this.hasPackTactics = false,
    this.specialTrait,
    this.accentColor = const Color(0xFF673AB7),
  });

  String get primaryDamageFormula => '${damageDiceCount}d$damageDiceSides${damageBonus >= 0 ? "+$damageBonus" : "$damageBonus"}';

  String get fullDamageFormula {
    if (secondaryDamageDiceCount > 0 && secondaryDamageType != null) {
      return '$primaryDamageFormula $damageType + ${secondaryDamageDiceCount}d$secondaryDamageDiceSides $secondaryDamageType';
    }
    return '$primaryDamageFormula $damageType';
  }
}

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
  });
}

class SrdSummonsLibrary {
  // --- STAT BLOCKS ---
  
  // Animate Objects
  static const tinyObject = MinionStatBlock(
    id: 'ao_tiny',
    name: 'Tiny Object',
    sizeDisplay: 'Tiny',
    crDisplay: 'CR 1/4',
    ac: 18,
    maxHp: 20,
    attackBonus: 8,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 4,
    damageType: 'Bludgeoning',
    accentColor: Color(0xFF4CAF50),
  );

  static const smallObject = MinionStatBlock(
    id: 'ao_small',
    name: 'Small Object',
    sizeDisplay: 'Small',
    crDisplay: 'CR 1/2',
    ac: 16,
    maxHp: 10,
    attackBonus: 6,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 2,
    damageType: 'Bludgeoning',
    accentColor: Color(0xFF03A9F4),
  );

  static const mediumObject = MinionStatBlock(
    id: 'ao_medium',
    name: 'Medium Object',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1',
    ac: 13,
    maxHp: 40,
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 10,
    damageBonus: 1,
    damageType: 'Bludgeoning',
    accentColor: Color(0xFFFF9800),
  );

  static const largeObject = MinionStatBlock(
    id: 'ao_large',
    name: 'Large Object',
    sizeDisplay: 'Large',
    crDisplay: 'CR 2',
    ac: 10,
    maxHp: 80,
    attackBonus: 6,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 2,
    damageType: 'Bludgeoning',
    accentColor: Color(0xFFE91E63),
  );

  static const hugeObject = MinionStatBlock(
    id: 'ao_huge',
    name: 'Huge Object',
    sizeDisplay: 'Huge',
    crDisplay: 'CR 4',
    ac: 10,
    maxHp: 100,
    attackBonus: 8,
    damageDiceCount: 2,
    damageDiceSides: 12,
    damageBonus: 4,
    damageType: 'Bludgeoning',
    accentColor: Color(0xFF9C27B0),
  );

  // Animate Dead & Create Undead
  static const skeleton = MinionStatBlock(
    id: 'undead_skeleton',
    name: 'Skeleton',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/4',
    ac: 13,
    maxHp: 13,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 2,
    damageType: 'Piercing',
    specialTrait: 'Shortbow / Shortsword attack',
    accentColor: Color(0xFFB0BEC5),
  );

  static const zombie = MinionStatBlock(
    id: 'undead_zombie',
    name: 'Zombie',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/4',
    ac: 8,
    maxHp: 22,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 1,
    damageType: 'Bludgeoning',
    specialTrait: 'Undead Fortitude (DC 5+dmg Con save to drop to 1 HP)',
    accentColor: Color(0xFF78909C),
  );

  static const ghoul = MinionStatBlock(
    id: 'undead_ghoul',
    name: 'Ghoul',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1',
    ac: 12,
    maxHp: 22,
    attackBonus: 4,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 2,
    damageType: 'Slashing',
    specialTrait: 'Claws (DC 10 Con save or paralyzed for 1 min)',
    accentColor: Color(0xFF546E7A),
  );

  static const ghast = MinionStatBlock(
    id: 'undead_ghast',
    name: 'Ghast',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 2',
    ac: 13,
    maxHp: 36,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Slashing',
    specialTrait: 'Stench (DC 10 Con save or poisoned within 5 ft)',
    accentColor: Color(0xFF37474F),
  );

  static const wight = MinionStatBlock(
    id: 'undead_wight',
    name: 'Wight',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 3',
    ac: 14,
    maxHp: 45,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 2,
    damageType: 'Piercing',
    specialTrait: 'Longbow / Life Drain',
    accentColor: Color(0xFF263238),
  );

  static const mummy = MinionStatBlock(
    id: 'undead_mummy',
    name: 'Mummy',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 3',
    ac: 11,
    maxHp: 58,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Bludgeoning',
    secondaryDamageDiceCount: 3,
    secondaryDamageDiceSides: 6,
    secondaryDamageType: 'Necrotic',
    specialTrait: 'Rotting Fist (3d6 Necrotic + Mummy Rot curse)',
    accentColor: Color(0xFF8D6E63),
  );

  // Conjure Animals
  static const wolf = MinionStatBlock(
    id: 'beast_wolf',
    name: 'Wolf',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/4',
    ac: 13,
    maxHp: 11,
    attackBonus: 4,
    damageDiceCount: 2,
    damageDiceSides: 4,
    damageBonus: 2,
    damageType: 'Piercing',
    hasPackTactics: true,
    specialTrait: 'Pack Tactics (Advantage if ally within 5 ft) + Trip (DC 11 Strength save)',
    accentColor: Color(0xFF8D6E63),
  );

  static const direWolf = MinionStatBlock(
    id: 'beast_dire_wolf',
    name: 'Dire Wolf',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1',
    ac: 14,
    maxHp: 37,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Piercing',
    hasPackTactics: true,
    specialTrait: 'Pack Tactics (Advantage if ally within 5 ft) + Trip (DC 13 Strength save)',
    accentColor: Color(0xFF6D4C41),
  );

  static const giantHyena = MinionStatBlock(
    id: 'beast_giant_hyena',
    name: 'Giant Hyena',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1',
    ac: 12,
    maxHp: 45,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Piercing',
    specialTrait: 'Rampage (Bonus bite attack when reducing creature to 0 HP)',
    accentColor: Color(0xFFA1887F),
  );

  static const giantSpider = MinionStatBlock(
    id: 'beast_giant_spider',
    name: 'Giant Spider',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1',
    ac: 14,
    maxHp: 26,
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 3,
    damageType: 'Piercing',
    secondaryDamageDiceCount: 2,
    secondaryDamageDiceSides: 8,
    secondaryDamageType: 'Poison',
    specialTrait: 'Bite (1d8+3 piercing + 2d8 poison, DC 11 Con save for half) + Webbing',
    accentColor: Color(0xFF43A047),
  );

  static const giantEagle = MinionStatBlock(
    id: 'beast_giant_eagle',
    name: 'Giant Eagle',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1',
    ac: 13,
    maxHp: 26,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Slashing',
    specialTrait: 'Keen Sight & Multiattack',
    accentColor: Color(0xFFFB8C00),
  );

  static const ape = MinionStatBlock(
    id: 'beast_ape',
    name: 'Ape',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/2',
    ac: 12,
    maxHp: 19,
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Bludgeoning',
    accentColor: Color(0xFF5D4037),
  );

  static const boar = MinionStatBlock(
    id: 'beast_boar',
    name: 'Boar',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/4',
    ac: 11,
    maxHp: 11,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 1,
    damageType: 'Slashing',
    specialTrait: 'Charge (Extra 1d6 damage if moving 20+ feet)',
    accentColor: Color(0xFF8D6E63),
  );

  // Elementals
  static const airElemental = MinionStatBlock(
    id: 'elem_air',
    name: 'Air Elemental',
    sizeDisplay: 'Large',
    crDisplay: 'CR 5',
    ac: 15,
    maxHp: 90,
    attackBonus: 8,
    damageDiceCount: 2,
    damageDiceSides: 8,
    damageBonus: 5,
    damageType: 'Bludgeoning',
    specialTrait: 'Whirlwind (DC 13 Strength save or flung)',
    accentColor: Color(0xFF81D4FA),
  );

  static const earthElemental = MinionStatBlock(
    id: 'elem_earth',
    name: 'Earth Elemental',
    sizeDisplay: 'Large',
    crDisplay: 'CR 5',
    ac: 17,
    maxHp: 126,
    attackBonus: 8,
    damageDiceCount: 2,
    damageDiceSides: 8,
    damageBonus: 5,
    damageType: 'Bludgeoning',
    specialTrait: 'Siege Monster & Earth Glide',
    accentColor: Color(0xFFA1887F),
  );

  static const fireElemental = MinionStatBlock(
    id: 'elem_fire',
    name: 'Fire Elemental',
    sizeDisplay: 'Large',
    crDisplay: 'CR 5',
    ac: 13,
    maxHp: 102,
    attackBonus: 6,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Fire',
    specialTrait: 'Touch (Target catches fire for 1d10 fire per turn)',
    accentColor: Color(0xFFFF5722),
  );

  static const waterElemental = MinionStatBlock(
    id: 'elem_water',
    name: 'Water Elemental',
    sizeDisplay: 'Large',
    crDisplay: 'CR 5',
    ac: 14,
    maxHp: 114,
    attackBonus: 7,
    damageDiceCount: 2,
    damageDiceSides: 8,
    damageBonus: 4,
    damageType: 'Bludgeoning',
    specialTrait: 'Whelm (DC 15 Strength save or grappled and drowning)',
    accentColor: Color(0xFF0288D1),
  );

  static const dustMephit = MinionStatBlock(
    id: 'elem_dust_mephit',
    name: 'Dust Mephit',
    sizeDisplay: 'Small',
    crDisplay: 'CR 1/2',
    ac: 12,
    maxHp: 17,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 2,
    damageType: 'Slashing',
    specialTrait: 'Blinding Breath (DC 10 Dex save or blinded)',
    accentColor: Color(0xFFBCAAA4),
  );

  static const iceMephit = MinionStatBlock(
    id: 'elem_ice_mephit',
    name: 'Ice Mephit',
    sizeDisplay: 'Small',
    crDisplay: 'CR 1/2',
    ac: 11,
    maxHp: 21,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 1,
    damageType: 'Slashing',
    secondaryDamageDiceCount: 1,
    secondaryDamageDiceSides: 4,
    secondaryDamageType: 'Cold',
    specialTrait: 'Frost Breath (2d4 cold, DC 10 Dex save for half)',
    accentColor: Color(0xFF80DEEA),
  );

  static const magmaMephit = MinionStatBlock(
    id: 'elem_magma_mephit',
    name: 'Magma Mephit',
    sizeDisplay: 'Small',
    crDisplay: 'CR 1/2',
    ac: 11,
    maxHp: 22,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 1,
    damageType: 'Slashing',
    secondaryDamageDiceCount: 1,
    secondaryDamageDiceSides: 4,
    secondaryDamageType: 'Fire',
    specialTrait: 'Fire Breath (2d6 fire, DC 11 Dex save for half)',
    accentColor: Color(0xFFFF7043),
  );

  static const gargoyle = MinionStatBlock(
    id: 'elem_gargoyle',
    name: 'Gargoyle',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 2',
    ac: 15,
    maxHp: 52,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 2,
    damageType: 'Slashing',
    accentColor: Color(0xFF78909C),
  );

  // Giant Insect
  static const giantCentipede = MinionStatBlock(
    id: 'insect_centipede',
    name: 'Giant Centipede',
    sizeDisplay: 'Small',
    crDisplay: 'CR 1/4',
    ac: 13,
    maxHp: 4,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 2,
    damageType: 'Piercing',
    secondaryDamageDiceCount: 3,
    secondaryDamageDiceSides: 6,
    secondaryDamageType: 'Poison',
    specialTrait: 'Bite (1d4+2 piercing + 3d6 poison, DC 11 Con save for half)',
    accentColor: Color(0xFF4CAF50),
  );

  static const giantWasp = MinionStatBlock(
    id: 'insect_wasp',
    name: 'Giant Wasp',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/2',
    ac: 12,
    maxHp: 13,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 2,
    damageType: 'Piercing',
    secondaryDamageDiceCount: 3,
    secondaryDamageDiceSides: 6,
    secondaryDamageType: 'Poison',
    specialTrait: 'Sting (1d4+2 piercing + 3d6 poison, DC 11 Con save for half/paralysis)',
    accentColor: Color(0xFFFBC02D),
  );

  // Items
  static const berserker = MinionStatBlock(
    id: 'item_berserker',
    name: 'Berserker (Valhalla)',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 2',
    ac: 13,
    maxHp: 67,
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 12,
    damageBonus: 3,
    damageType: 'Slashing',
    specialTrait: 'Reckless Attack (Gain Advantage on attack rolls, grant advantage on incoming attacks)',
    accentColor: Color(0xFFD32F2F),
  );

  static const bronzeGriffon = MinionStatBlock(
    id: 'item_griffon',
    name: 'Bronze Griffon',
    sizeDisplay: 'Large',
    crDisplay: 'CR 2',
    ac: 12,
    maxHp: 59,
    attackBonus: 6,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 4,
    damageType: 'Slashing',
    specialTrait: 'Beak & Claws Multiattack (Fly speed 80 ft)',
    accentColor: Color(0xFFFFB300),
  );

  static const onyxDog = MinionStatBlock(
    id: 'item_onyx_dog',
    name: 'Onyx Dog',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/4',
    ac: 13,
    maxHp: 11,
    attackBonus: 4,
    damageDiceCount: 2,
    damageDiceSides: 4,
    damageBonus: 2,
    damageType: 'Piercing',
    hasPackTactics: true,
    specialTrait: 'Mastiff stats + Truesight 60 ft & Perception advantage',
    accentColor: Color(0xFF424242),
  );

  static const marbleElephant = MinionStatBlock(
    id: 'item_elephant',
    name: 'Marble Elephant',
    sizeDisplay: 'Huge',
    crDisplay: 'CR 4',
    ac: 12,
    maxHp: 76,
    attackBonus: 8,
    damageDiceCount: 3,
    damageDiceSides: 10,
    damageBonus: 6,
    damageType: 'Bludgeoning',
    specialTrait: 'Gore/Grave Gore (3d10+6) & Trampling Charge',
    accentColor: Color(0xFFB0BEC5),
  );

  // --- PRESETS ---

  static const allPresets = <SummonPreset>[
    SummonPreset(
      id: 'animate_objects',
      name: 'Animate Objects',
      category: SummonCategory.spell,
      levelDisplay: '5th-level Transmutation',
      castingTime: '1 Action',
      range: '120 feet',
      components: 'V, S',
      duration: 'Concentration, up to 1 minute',
      description: 'Objects come to life at your command. Choose up to ten nonmagical objects within range. Tiny/Small count as 1 pt, Medium counts as 2 pts, Large counts as 4 pts, Huge counts as 8 pts (up to 10 pts total at 5th level).',
      upcastRules: '+2 points per spell slot level above 5th level.',
      statBlocks: [tinyObject, smallObject, mediumObject, largeObject, hugeObject],
    ),
    SummonPreset(
      id: 'conjure_animals',
      name: 'Conjure Animals',
      category: SummonCategory.spell,
      levelDisplay: '3rd-level Conjuration',
      castingTime: '1 Action',
      range: '60 feet',
      components: 'V, S',
      duration: 'Concentration, up to 1 hour',
      description: 'You summon fey spirits that take the form of beasts and appear in unoccupied spaces that you can see within range. Choose CR options: 8 beasts of CR 1/4, 4 beasts of CR 1/2, 2 beasts of CR 1, or 1 beast of CR 2.',
      upcastRules: 'Twice as many beasts at 5th level (e.g. 16 CR 1/4), three times as many at 7th level (24), four times as many at 9th level (32).',
      statBlocks: [wolf, direWolf, giantHyena, giantSpider, giantEagle, ape, boar],
    ),
    SummonPreset(
      id: 'animate_dead',
      name: 'Animate Dead',
      category: SummonCategory.spell,
      levelDisplay: '3rd-level Necromancy',
      castingTime: '1 Minute',
      range: '10 feet',
      components: 'V, S, M (a drop of blood, a piece of flesh, and a pinch of bone dust)',
      duration: '24 hours',
      description: 'This spell creates an undead servant. Choose a pile of bones or a corpse of a Medium or Small humanoid within range to animate a Skeleton or Zombie.',
      upcastRules: 'Animate or reassert control over 2 additional undead creatures for each slot level above 3rd.',
      statBlocks: [skeleton, zombie],
    ),
    SummonPreset(
      id: 'create_undead',
      name: 'Create Undead',
      category: SummonCategory.spell,
      levelDisplay: '6th-level Necromancy',
      castingTime: '1 Minute',
      range: '10 feet',
      components: 'V, S, M (one clay pot per corpse filled with grave dirt, salt, and 150gp black onyx per corpse)',
      duration: '24 hours',
      description: 'You can animate up to three Ghouls from corpses within range. Higher levels allow Ghasts, Wights, or Mummies.',
      upcastRules: '7th level: 4 Ghouls or 2 Ghasts/Wights. 8th level: 5 Ghouls, 3 Ghasts/Wights, or 2 Mummies. 9th level: 6 Ghouls, 4 Ghasts/Wights, or 3 Mummies.',
      statBlocks: [ghoul, ghast, wight, mummy],
    ),
    SummonPreset(
      id: 'conjure_elemental',
      name: 'Conjure Elemental',
      category: SummonCategory.spell,
      levelDisplay: '5th-level Conjuration',
      castingTime: '1 Minute',
      range: '90 feet',
      components: 'V, S, M (burning incense for air, soft clay for earth, sulfur and phosphorus for fire, or water for water)',
      duration: 'Concentration, up to 1 hour',
      description: 'You call forth an elemental servant from the Inner Planes. It fills an area containing the appropriate element.',
      upcastRules: 'Challenge rating increases by 1 for each slot level above 5th.',
      statBlocks: [airElemental, earthElemental, fireElemental, waterElemental],
    ),
    SummonPreset(
      id: 'conjure_minor_elementals',
      name: 'Conjure Minor Elementals',
      category: SummonCategory.spell,
      levelDisplay: '4th-level Conjuration',
      castingTime: '1 Minute',
      range: '90 feet',
      components: 'V, S',
      duration: 'Concentration, up to 1 hour',
      description: 'You summon elementals of CR 2 or lower (e.g. 8 mephits of CR 1/4, 4 of CR 1/2, 2 of CR 1, or 1 Gargoyle of CR 2).',
      upcastRules: 'Twice as many at 6th level, three times as many at 8th level.',
      statBlocks: [dustMephit, iceMephit, magmaMephit, gargoyle],
    ),
    SummonPreset(
      id: 'giant_insect',
      name: 'Giant Insect',
      category: SummonCategory.spell,
      levelDisplay: '4th-level Transmutation',
      castingTime: '1 Action',
      range: '30 feet',
      components: 'V, S',
      duration: 'Concentration, up to 10 minutes',
      description: 'You transform up to ten centipedes, three spiders, or five wasps into giant versions under your command.',
      upcastRules: 'No additional count scaling in SRD 5.1.',
      statBlocks: [giantCentipede, giantWasp, giantSpider],
    ),
    SummonPreset(
      id: 'horn_of_valhalla',
      name: 'Horn of Valhalla',
      category: SummonCategory.magicItem,
      levelDisplay: 'Wondrous Item (Rare to Legendary)',
      castingTime: '1 Action',
      range: 'Self (60-foot radius)',
      components: 'Action (Wind Instrument)',
      duration: '1 Hour',
      description: 'You blow the horn to summon heroic warrior spirits from Ysgard. Silver summons 2d4+2, Brass summons 3d4+3, Bronze summons 4d4+4, Iron summons 5d4+5 Berserkers.',
      upcastRules: 'Cannot be used again for 7 days.',
      statBlocks: [berserker],
    ),
    SummonPreset(
      id: 'bag_of_tricks',
      name: 'Bag of Tricks (Gray/Rust/Tan)',
      category: SummonCategory.magicItem,
      levelDisplay: 'Wondrous Item (Uncommon)',
      castingTime: '1 Action',
      range: '20 feet',
      components: 'Action (Pull fuzzy object and throw)',
      duration: 'Until killed or next dawn',
      description: 'Pull a random fuzzy object from the bag and throw it up to 20 feet. Roll a d8 on the bag table to determine which animal appears! Up to 3 creatures per day.',
      upcastRules: '3 uses per day per bag.',
      statBlocks: [wolf, boar, giantHyena, ape, direWolf, giantSpider],
      isRandomTable: true,
    ),
    SummonPreset(
      id: 'figurines_wondrous_power',
      name: 'Figurines of Wondrous Power',
      category: SummonCategory.magicItem,
      levelDisplay: 'Wondrous Item (Varies)',
      castingTime: '1 Action',
      range: '60 feet',
      components: 'Action (Command word)',
      duration: 'Varies (1 hr to 12 hrs)',
      description: 'Statues of animals that transform into real living creatures upon speaking the command word.',
      upcastRules: 'Cooldown varies per figurine.',
      statBlocks: [bronzeGriffon, onyxDog, marbleElephant],
    ),
  ];
}
