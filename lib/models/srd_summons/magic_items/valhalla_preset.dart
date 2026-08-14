import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class ValhallaSummons {
  static const berserker = MinionStatBlock(
    id: 'item_berserker',
    name: 'Berserker (Valhalla)',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 2',
    typeDisplay: 'Humanoid (Any Race)',
    alignment: 'chaotic neutral',
    ac: 13,
    armorType: 'hide armor',
    maxHp: 67,
    hitDice: '9d8 + 27',
    speed: '30 ft.',
    strScore: 16,
    dexScore: 12,
    conScore: 17,
    intScore: 9,
    wisScore: 11,
    chaScore: 9,
    senses: 'passive Perception 10',
    languages: 'any one language (usually Common)',
    xp: 450,
    traits: [
      CreatureTrait(
        name: 'Reckless',
        description: 'At the start of its turn, the berserker can gain advantage on all melee weapon attack rolls during that turn, but attack rolls against it have advantage until the start of its next turn.',
      ),
    ],
    actions: [
      CreatureAction(
        name: 'Greataxe',
        description: 'Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 9 (1d12 + 3) slashing damage.',
        attackType: 'Melee Weapon Attack',
        attackBonus: 5,
        reach: 'reach 5 ft.',
        hitDamage: '9 (1d12 + 3) slashing damage',
      ),
    ],
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 12,
    damageBonus: 3,
    damageType: 'Slashing',
    specialTrait: 'Reckless Attack (Advantage on attacks, grants advantage on incoming)',
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
    description: 'You blow the horn to summon heroic warrior spirits from Valhalla. Silver summons 2d4+2, Brass summons 3d4+3, Bronze summons 4d4+4, Iron summons 5d4+5 Berserkers.',
    upcastRules: 'Cannot be used again for 7 days.',
    statBlocks: [berserker],
  );
}
