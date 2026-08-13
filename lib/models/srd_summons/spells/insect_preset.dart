import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';
import 'beast_presets.dart';

class InsectSummons {
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

  static const giantInsectPreset = SummonPreset(
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
    statBlocks: [giantCentipede, giantWasp, BeastSummons.giantSpider],
  );
}
