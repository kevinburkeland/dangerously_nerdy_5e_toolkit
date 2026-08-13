import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class BeastSummons {
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
    statBlocks: [wolf, direWolf, giantHyena, giantSpider, giantEagle, ape, boar],
  );
}
