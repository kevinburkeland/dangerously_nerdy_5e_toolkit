import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class BagOfTricksSummons {
  // --- GRAY BAG CREATURES (d8) ---
  static const weasel = MinionStatBlock(
    id: 'bot_weasel',
    name: 'Weasel',
    sizeDisplay: 'Tiny',
    crDisplay: 'CR 0',
    ac: 13,
    maxHp: 1,
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 1,
    damageBonus: 0,
    damageType: 'Piercing',
    accentColor: Color(0xFF90A4AE),
  );

  static const giantRat = MinionStatBlock(
    id: 'bot_giant_rat',
    name: 'Giant Rat',
    sizeDisplay: 'Small',
    crDisplay: 'CR 1/8',
    ac: 12,
    maxHp: 7,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 2,
    damageType: 'Piercing',
    hasPackTactics: true,
    specialTrait: 'Keen Smell & Pack Tactics',
    accentColor: Color(0xFF78909C),
  );

  static const badger = MinionStatBlock(
    id: 'bot_badger',
    name: 'Badger',
    sizeDisplay: 'Tiny',
    crDisplay: 'CR 0',
    ac: 10,
    maxHp: 3,
    attackBonus: 2,
    damageDiceCount: 1,
    damageDiceSides: 1,
    damageBonus: 0,
    damageType: 'Piercing',
    accentColor: Color(0xFF607D8B),
  );

  static const boar = MinionStatBlock(
    id: 'bot_boar',
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
    specialTrait: 'Charge (Extra 1d6 damage)',
    accentColor: Color(0xFF8D6E63),
  );

  static const panther = MinionStatBlock(
    id: 'bot_panther',
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
    id: 'bot_giant_badger',
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

  static const direWolf = MinionStatBlock(
    id: 'bot_dire_wolf',
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
    specialTrait: 'Pack Tactics & Trip (DC 13 Str)',
    accentColor: Color(0xFF37474F),
  );

  static const giantElk = MinionStatBlock(
    id: 'bot_giant_elk',
    name: 'Giant Elk',
    sizeDisplay: 'Huge',
    crDisplay: 'CR 2',
    ac: 14,
    maxHp: 42,
    attackBonus: 6,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 4,
    damageType: 'Bludgeoning',
    specialTrait: 'Charge (Extra 2d6 damage)',
    accentColor: Color(0xFF263238),
  );

  // --- RUST BAG CREATURES (d8) ---
  static const rat = MinionStatBlock(
    id: 'bot_rat',
    name: 'Rat',
    sizeDisplay: 'Tiny',
    crDisplay: 'CR 0',
    ac: 10,
    maxHp: 1,
    attackBonus: 0,
    damageDiceCount: 1,
    damageDiceSides: 1,
    damageBonus: 0,
    damageType: 'Piercing',
    accentColor: Color(0xFFA1887F),
  );

  static const owl = MinionStatBlock(
    id: 'bot_owl',
    name: 'Owl',
    sizeDisplay: 'Tiny',
    crDisplay: 'CR 0',
    ac: 11,
    maxHp: 1,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 1,
    damageBonus: 0,
    damageType: 'Slashing',
    specialTrait: 'Flyby & Keen Sight',
    accentColor: Color(0xFF8D6E63),
  );

  static const mastiff = MinionStatBlock(
    id: 'bot_mastiff',
    name: 'Mastiff',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/8',
    ac: 12,
    maxHp: 5,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 1,
    damageType: 'Piercing',
    specialTrait: 'Keen Hearing/Smell & Trip (DC 11 Str)',
    accentColor: Color(0xFF795548),
  );

  static const goat = MinionStatBlock(
    id: 'bot_goat',
    name: 'Goat',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/8',
    ac: 10,
    maxHp: 4,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 1,
    damageType: 'Bludgeoning',
    specialTrait: 'Charge (Extra 1d4 damage)',
    accentColor: Color(0xFF6D4C41),
  );

  static const giantGoat = MinionStatBlock(
    id: 'bot_giant_goat',
    name: 'Giant Goat',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1/4',
    ac: 11,
    maxHp: 19,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 4,
    damageBonus: 3,
    damageType: 'Bludgeoning',
    specialTrait: 'Charge (Extra 2d4 damage)',
    accentColor: Color(0xFF5D4037),
  );

  static const giantBoar = MinionStatBlock(
    id: 'bot_giant_boar',
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
    accentColor: Color(0xFF4E342E),
  );

  static const lion = MinionStatBlock(
    id: 'bot_lion',
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

  static const brownBear = MinionStatBlock(
    id: 'bot_brown_bear',
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

  // --- TAN BAG CREATURES (d8) ---
  static const jackal = MinionStatBlock(
    id: 'bot_jackal',
    name: 'Jackal',
    sizeDisplay: 'Small',
    crDisplay: 'CR 0',
    ac: 12,
    maxHp: 3,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 2,
    damageType: 'Piercing',
    hasPackTactics: true,
    specialTrait: 'Pack Tactics & Keen Hearing/Smell',
    accentColor: Color(0xFFDCE775),
  );

  static const ape = MinionStatBlock(
    id: 'bot_ape',
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
    accentColor: Color(0xFFC0CA33),
  );

  static const baboon = MinionStatBlock(
    id: 'bot_baboon',
    name: 'Baboon',
    sizeDisplay: 'Small',
    crDisplay: 'CR 0',
    ac: 12,
    maxHp: 3,
    attackBonus: 1,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: -1,
    damageType: 'Bludgeoning',
    hasPackTactics: true,
    specialTrait: 'Pack Tactics',
    accentColor: Color(0xFFAFB42B),
  );

  static const axeBeak = MinionStatBlock(
    id: 'bot_axe_beak',
    name: 'Axe Beak',
    sizeDisplay: 'Large',
    crDisplay: 'CR 1/4',
    ac: 11,
    maxHp: 19,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 2,
    damageType: 'Slashing',
    accentColor: Color(0xFFFBC02D),
  );

  static const blackBear = MinionStatBlock(
    id: 'bot_black_bear',
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
    accentColor: Color(0xFFF57F17),
  );

  static const giantWeasel = MinionStatBlock(
    id: 'bot_giant_weasel',
    name: 'Giant Weasel',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1/8',
    ac: 13,
    maxHp: 9,
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 3,
    damageType: 'Piercing',
    specialTrait: 'Keen Hearing & Smell',
    accentColor: Color(0xFF827717),
  );

  static const giantHyena = MinionStatBlock(
    id: 'bot_giant_hyena',
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
    specialTrait: 'Rampage',
    accentColor: Color(0xFFA1887F),
  );

  static const tiger = MinionStatBlock(
    id: 'bot_tiger',
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

  // --- PRESETS FOR EACH BAG VARIANT ---
  static const grayBagPreset = SummonPreset(
    id: 'bag_of_tricks_gray',
    name: 'Bag of Tricks (Gray)',
    category: SummonCategory.magicItem,
    levelDisplay: 'Wondrous Item (Uncommon)',
    castingTime: '1 Action',
    range: '20 feet',
    components: 'Action (Pull fuzzy object and throw)',
    duration: 'Until killed or next dawn',
    description: 'Pull a fuzzy object from the Gray Bag of Tricks and throw it up to 20 feet. Roll a d8: 1=Weasel, 2=Giant Rat, 3=Badger, 4=Boar, 5=Panther, 6=Giant Badger, 7=Dire Wolf, 8=Giant Elk.',
    upcastRules: 'Up to 3 uses per day.',
    statBlocks: [weasel, giantRat, badger, boar, panther, giantBadger, direWolf, giantElk],
    isRandomTable: true,
  );

  static const rustBagPreset = SummonPreset(
    id: 'bag_of_tricks_rust',
    name: 'Bag of Tricks (Rust)',
    category: SummonCategory.magicItem,
    levelDisplay: 'Wondrous Item (Uncommon)',
    castingTime: '1 Action',
    range: '20 feet',
    components: 'Action (Pull fuzzy object and throw)',
    duration: 'Until killed or next dawn',
    description: 'Pull a fuzzy object from the Rust Bag of Tricks and throw it up to 20 feet. Roll a d8: 1=Rat, 2=Owl, 3=Mastiff, 4=Goat, 5=Giant Goat, 6=Giant Boar, 7=Lion, 8=Brown Bear.',
    upcastRules: 'Up to 3 uses per day.',
    statBlocks: [rat, owl, mastiff, goat, giantGoat, giantBoar, lion, brownBear],
    isRandomTable: true,
  );

  static const tanBagPreset = SummonPreset(
    id: 'bag_of_tricks_tan',
    name: 'Bag of Tricks (Tan)',
    category: SummonCategory.magicItem,
    levelDisplay: 'Wondrous Item (Uncommon)',
    castingTime: '1 Action',
    range: '20 feet',
    components: 'Action (Pull fuzzy object and throw)',
    duration: 'Until killed or next dawn',
    description: 'Pull a fuzzy object from the Tan Bag of Tricks and throw it up to 20 feet. Roll a d8: 1=Jackal, 2=Ape, 3=Baboon, 4=Axe Beak, 5=Black Bear, 6=Giant Weasel, 7=Giant Hyena, 8=Tiger.',
    upcastRules: 'Up to 3 uses per day.',
    statBlocks: [jackal, ape, baboon, axeBeak, blackBear, giantWeasel, giantHyena, tiger],
    isRandomTable: true,
  );

  // Backward-compatibility default alias
  static const bagOfTricksPreset = grayBagPreset;
}
