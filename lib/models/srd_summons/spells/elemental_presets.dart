import 'package:flutter/material.dart';
import '../minion_stat_block.dart';
import '../summon_preset.dart';

class ElementalSummons {
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
    description: 'You call forth an elemental servant from the Inner Planes. It fills an area containing the appropriate element.',
    upcastRules: 'Challenge rating increases by 1 for each slot level above 5th.',
    statBlocks: [airElemental, earthElemental, fireElemental, waterElemental],
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
    description: 'You summon elementals of CR 2 or lower (e.g. 8 mephits of CR 1/4, 4 of CR 1/2, 2 of CR 1, or 1 Gargoyle of CR 2).',
    upcastRules: 'Twice as many at 6th level, three times as many at 8th level.',
    statBlocks: [dustMephit, iceMephit, magmaMephit, gargoyle],
  );
}
