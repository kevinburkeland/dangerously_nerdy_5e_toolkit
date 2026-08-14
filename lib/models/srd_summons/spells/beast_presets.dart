import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class BeastSummons {
  // --- CR 1/4 BEASTS (8 Beasts summoned at 3rd level) ---
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

  static const panther = MinionStatBlock(
    id: 'beast_panther',
    name: 'Panther',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/4',
    ac: 12,
    maxHp: 13,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 2,
    damageType: 'Slashing',
    specialTrait: 'Keen Smell & Pounce',
    accentColor: Color(0xFF546E7A),
  );

  static const giantBadger = MinionStatBlock(
    id: 'beast_giant_badger',
    name: 'Giant Badger',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/4',
    ac: 10,
    maxHp: 13,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 1,
    damageType: 'Slashing',
    specialTrait: 'Multiattack & Keen Smell',
    accentColor: Color(0xFF455A64),
  );

  static const giantPoisonousSnake = MinionStatBlock(
    id: 'beast_giant_poisonous_snake',
    name: 'Giant Poisonous Snake',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/4',
    ac: 14,
    maxHp: 11,
    attackBonus: 6,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 4,
    damageType: 'Piercing',
    secondaryDamageDiceCount: 3,
    secondaryDamageDiceSides: 6,
    secondaryDamageType: 'Poison',
    specialTrait: 'Bite (1d4+4 piercing + 3d6 poison, DC 11 Con save for half)',
    accentColor: Color(0xFF4CAF50),
  );

  // --- CR 1/2 BEASTS (4 Beasts summoned at 3rd level) ---
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

  static const blackBear = MinionStatBlock(
    id: 'beast_black_bear',
    name: 'Black Bear',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/2',
    ac: 11,
    maxHp: 19,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 2,
    damageType: 'Slashing',
    specialTrait: 'Multiattack & Keen Smell',
    accentColor: Color(0xFF4E342E),
  );

  static const crocodile = MinionStatBlock(
    id: 'beast_crocodile',
    name: 'Crocodile',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1/2',
    ac: 12,
    maxHp: 19,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 10,
    damageBonus: 2,
    damageType: 'Piercing',
    specialTrait: 'Bite & Grapple (DC 12 Str escape)',
    accentColor: Color(0xFF2E7D32),
  );

  // --- CR 1 BEASTS (2 Beasts summoned at 3rd level) ---
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

  static const brownBear = MinionStatBlock(
    id: 'beast_brown_bear',
    name: 'Brown Bear',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1',
    ac: 11,
    maxHp: 34,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 4,
    damageType: 'Slashing',
    specialTrait: 'Multiattack & Keen Smell',
    accentColor: Color(0xFFFB8C00),
  );

  static const lion = MinionStatBlock(
    id: 'beast_lion',
    name: 'Lion',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1',
    ac: 12,
    maxHp: 26,
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 3,
    damageType: 'Slashing',
    hasPackTactics: true,
    specialTrait: 'Pack Tactics & Pounce',
    accentColor: Color(0xFFFFB74D),
  );

  static const tiger = MinionStatBlock(
    id: 'beast_tiger',
    name: 'Tiger',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1',
    ac: 12,
    maxHp: 37,
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 10,
    damageBonus: 3,
    damageType: 'Slashing',
    specialTrait: 'Pounce & Keen Smell',
    accentColor: Color(0xFFE65100),
  );

  static const giantToad = MinionStatBlock(
    id: 'beast_giant_toad',
    name: 'Giant Toad',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1',
    ac: 11,
    maxHp: 39,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 10,
    damageBonus: 2,
    damageType: 'Piercing',
    secondaryDamageDiceCount: 1,
    secondaryDamageDiceSides: 10,
    secondaryDamageType: 'Poison',
    specialTrait: 'Bite (1d10+2 piercing + 1d10 poison) & Swallow',
    accentColor: Color(0xFF689F38),
  );

  // --- CR 2 BEASTS (1 Beast summoned at 3rd level) ---
  static const rhinoceros = MinionStatBlock(
    id: 'beast_rhinoceros',
    name: 'Rhinoceros',
    sizeDisplay: 'Large',
    crDisplay: 'CR 2',
    ac: 11,
    maxHp: 45,
    attackBonus: 7,
    damageDiceCount: 2,
    damageDiceSides: 8,
    damageBonus: 5,
    damageType: 'Bludgeoning',
    specialTrait: 'Charge (Extra 2d8 damage, DC 15 Strength save or knock prone)',
    accentColor: Color(0xFF78909C),
  );

  static const polarBear = MinionStatBlock(
    id: 'beast_polar_bear',
    name: 'Polar Bear',
    sizeDisplay: 'Large',
    crDisplay: 'CR 2',
    ac: 12,
    maxHp: 42,
    attackBonus: 7,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 5,
    damageType: 'Slashing',
    specialTrait: 'Multiattack & Keen Smell',
    accentColor: Color(0xFFB0BEC5),
  );

  static const giantBoar = MinionStatBlock(
    id: 'beast_giant_boar',
    name: 'Giant Boar',
    sizeDisplay: 'Large',
    crDisplay: 'CR 2',
    ac: 12,
    maxHp: 42,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Slashing',
    specialTrait: 'Charge (Extra 2d6 damage) & Relentless',
    accentColor: Color(0xFF5D4037),
  );

  static const saberToothedTiger = MinionStatBlock(
    id: 'beast_saber_toothed_tiger',
    name: 'Saber-Toothed Tiger',
    sizeDisplay: 'Large',
    crDisplay: 'CR 2',
    ac: 12,
    maxHp: 52,
    attackBonus: 6,
    damageDiceCount: 1,
    damageDiceSides: 10,
    damageBonus: 5,
    damageType: 'Slashing',
    specialTrait: 'Pounce & Keen Smell',
    accentColor: Color(0xFFF57C00),
  );

  static const giantConstrictorSnake = MinionStatBlock(
    id: 'beast_giant_constrictor_snake',
    name: 'Giant Constrictor Snake',
    sizeDisplay: 'Huge',
    crDisplay: 'CR 2',
    ac: 12,
    maxHp: 60,
    attackBonus: 6,
    damageDiceCount: 2,
    damageDiceSides: 8,
    damageBonus: 4,
    damageType: 'Bludgeoning',
    specialTrait: 'Constrict (2d8+4 bludgeoning, DC 14 Strength save or grappled/restrained)',
    accentColor: Color(0xFF388E3C),
  );

  static const conjureAnimalsPreset = SummonPreset(
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
    statBlocks: [
      // CR 1/4
      wolf,
      boar,
      panther,
      giantBadger,
      giantPoisonousSnake,
      // CR 1/2
      ape,
      blackBear,
      crocodile,
      // CR 1
      direWolf,
      giantHyena,
      giantSpider,
      giantEagle,
      brownBear,
      lion,
      tiger,
      giantToad,
      // CR 2
      rhinoceros,
      polarBear,
      giantBoar,
      saberToothedTiger,
      giantConstrictorSnake,
    ],
  );
}
