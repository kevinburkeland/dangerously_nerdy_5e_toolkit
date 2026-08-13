import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class UndeadSummons {
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

  static const animateDeadPreset = SummonPreset(
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
  );

  static const createUndeadPreset = SummonPreset(
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
  );
}
