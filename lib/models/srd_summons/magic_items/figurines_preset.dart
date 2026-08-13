import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class FigurinesSummons {
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

  static const figurinesPreset = SummonPreset(
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
  );
}
