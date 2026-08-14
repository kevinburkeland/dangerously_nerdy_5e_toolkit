import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class AnimateObjectsSummon {
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
    maxHp: 25,
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
    damageDiceCount: 2,
    damageDiceSides: 6,
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
    maxHp: 50,
    attackBonus: 6,
    damageDiceCount: 2,
    damageDiceSides: 10,
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
    maxHp: 80,
    attackBonus: 8,
    damageDiceCount: 2,
    damageDiceSides: 12,
    damageBonus: 4,
    damageType: 'Bludgeoning',
    accentColor: Color(0xFF9C27B0),
  );

  static const preset = SummonPreset(
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
  );
}
