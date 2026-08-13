import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class ValhallaSummons {
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

  static const hornOfValhallaPreset = SummonPreset(
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
  );
}
