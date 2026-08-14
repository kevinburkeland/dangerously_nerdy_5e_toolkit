import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class ElementalSummons {
  // --- CR 5 ELEMENTALS (5th-level base slot) ---
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

  static const salamander = MinionStatBlock(
    id: 'elem_salamander',
    name: 'Salamander',
    sizeDisplay: 'Large',
    crDisplay: 'CR 5',
    ac: 15,
    maxHp: 90,
    attackBonus: 7,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 4,
    damageType: 'Piercing',
    secondaryDamageDiceCount: 1,
    secondaryDamageDiceSides: 6,
    secondaryDamageType: 'Fire',
    specialTrait: 'Spear (2d6+4 piercing + 1d6 fire) & Tail Constrict + Heated Body (1d6 fire aura)',
    accentColor: Color(0xFFE64A19),
  );

  static const xorn = MinionStatBlock(
    id: 'elem_xorn',
    name: 'Xorn',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 5',
    ac: 19,
    maxHp: 84,
    attackBonus: 6,
    damageDiceCount: 3,
    damageDiceSides: 6,
    damageBonus: 3,
    damageType: 'Piercing',
    specialTrait: 'Multiattack (3 Claws 1d6+3 + 1 Bite 3d6+3) & Earth Glide',
    accentColor: Color(0xFF795548),
  );

  // --- LOWER CR ELEMENTALS & MEPHITS ---
  static const fireSnake = MinionStatBlock(
    id: 'elem_fire_snake',
    name: 'Fire Snake',
    sizeDisplay: 'Small',
    crDisplay: 'CR 1',
    ac: 14,
    maxHp: 22,
    attackBonus: 3,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 1,
    damageType: 'Piercing',
    secondaryDamageDiceCount: 1,
    secondaryDamageDiceSides: 4,
    secondaryDamageType: 'Fire',
    specialTrait: 'Bite (1d4+1 piercing + 1d4 fire) & Heated Body (1d4 fire aura)',
    accentColor: Color(0xFFFF3D00),
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

  static const steamMephit = MinionStatBlock(
    id: 'elem_steam_mephit',
    name: 'Steam Mephit',
    sizeDisplay: 'Small',
    crDisplay: 'CR 1/4',
    ac: 10,
    maxHp: 21,
    attackBonus: 2,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 0,
    damageType: 'Fire',
    specialTrait: 'Steam Breath (1d4 fire, DC 10 Dex save)',
    accentColor: Color(0xFFCFD8DC),
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

  static const conjureElementalPreset = SummonPreset(
    id: 'conjure_elemental',
    name: 'Conjure Elemental',
    category: SummonCategory.spell,
    levelDisplay: '5th-level Conjuration',
    castingTime: '1 Minute',
    range: '90 feet',
    components: 'V, S, M (burning incense for air, soft clay for earth, sulfur and phosphorus for fire, or water for water)',
    duration: 'Concentration, up to 1 hour',
    description: 'You call forth an elemental servant from the Inner Planes. Summons an elemental of CR 5 or lower (Air, Earth, Fire, Water Elementals, Salamander, Xorn).',
    upcastRules: 'Challenge rating increases by 1 for each slot level above 5th (CR 6 at 6th level, CR 7 at 7th level, CR 8 at 8th level, CR 9 at 9th level).',
    statBlocks: [airElemental, earthElemental, fireElemental, waterElemental, salamander, xorn],
  );

  static const conjureMinorElementalsPreset = SummonPreset(
    id: 'conjure_minor_elementals',
    name: 'Conjure Minor Elementals',
    category: SummonCategory.spell,
    levelDisplay: '4th-level Conjuration',
    castingTime: '1 Minute',
    range: '90 feet',
    components: 'V, S',
    duration: 'Concentration, up to 1 hour',
    description: 'You summon elementals of CR 2 or lower (e.g. 8 mephits of CR 1/4, 4 of CR 1/2, 2 Fire Snakes of CR 1, or 1 Gargoyle of CR 2).',
    upcastRules: 'Twice as many at 6th level, three times as many at 8th level.',
    statBlocks: [dustMephit, iceMephit, magmaMephit, steamMephit, fireSnake, gargoyle],
  );
}
