import 'dart:math' as math;
import '../arena/arena_combatant.dart';
import '../dm_screen_data.dart';
import '../monster_codex_data.dart';
import '../srd_summons/minion_stat_block.dart';
import '../../services/rules/dnd_5e_rules_engine.dart';

/// Advantage state for attack accuracy calculations.
enum AdvantageType {
  normal('Normal (1d20)'),
  advantage('Advantage (Roll 2, Highest)'),
  disadvantage('Disadvantage (Roll 2, Lowest)'),
  elvenAccuracy('Elven Accuracy (Roll 3, Highest)');

  final String label;
  const AdvantageType(this.label);
}

/// Great Weapon Fighting style rule versions.
enum GwfVersion {
  none('None'),
  v2014Reroll('GWF 2014 (Reroll 1s & 2s)'),
  v2024Floor3('GWF 2024 (1s & 2s count as 3)');

  final String label;
  const GwfVersion(this.label);
}

/// Great Weapon Master / Power Attack Feat modes.
enum GwmMode {
  none('None'),
  v2014PowerAttack('GWM/Sharpshooter 2014 (-5 to hit / +10 dmg)'),
  v2024ProficiencyBonus('GWM 2024 (+PB flat damage on hit)');

  final String label;
  const GwmMode(this.label);
}

/// 2024 Weapon Masteries that affect offensive DPR math.
enum WeaponMastery {
  none('None'),
  graze('Graze (Ability mod damage on MISS)'),
  vex('Vex (Advantage on next attack on HIT)'),
  nick('Nick (Extra light attack without Bonus Action)'),
  topple('Topple (Target prone on failed CON save)');

  final String label;
  const WeaponMastery(this.label);
}

/// Modes of graphical visualization in the DPR interactive chart.
enum DprChartMode {
  dpr('DPR vs AC', 'Damage Per Round curve across AC 5 to 30'),
  accuracy('Accuracy %', 'Hit, Crit, and Miss probabilities across AC'),
  damageBreakdown('Damage on Hit', 'Expected damage on Hit, Crit, and Miss');

  final String label;
  final String description;
  const DprChartMode(this.label, this.description);
}

/// Catalog item representing a base weapon or magic weapon to easily equip or customize.
class DprWeaponPreset {
  final String id;
  final String name;
  final String category; // e.g. "Standard Melee", "Standard Ranged", "Magic Weapon", "Damage Cantrip"
  final int diceCount;
  final int diceSides;
  final String damageType;
  final int flatBonus;
  final int secondaryDiceCount;
  final int secondaryDiceSides;
  final String? secondaryDamageType;
  final WeaponMastery defaultMastery;
  final bool isRanged;
  final bool isHeavy;
  final bool isCantrip;
  final int defaultAttacksPerRound;

  const DprWeaponPreset({
    required this.id,
    required this.name,
    this.category = 'Standard Weapon',
    required this.diceCount,
    required this.diceSides,
    required this.damageType,
    this.flatBonus = 0,
    this.secondaryDiceCount = 0,
    this.secondaryDiceSides = 0,
    this.secondaryDamageType,
    this.defaultMastery = WeaponMastery.none,
    this.isRanged = false,
    this.isHeavy = false,
    this.isCantrip = false,
    this.defaultAttacksPerRound = 1,
  });

  static const List<DprWeaponPreset> allPresets = [
    // Standard Melee
    DprWeaponPreset(id: 'greatsword', name: 'Greatsword (2d6 Slashing)', category: 'Standard Melee', diceCount: 2, diceSides: 6, damageType: 'slashing', isHeavy: true, defaultMastery: WeaponMastery.graze),
    DprWeaponPreset(id: 'greataxe', name: 'Greataxe (1d12 Slashing)', category: 'Standard Melee', diceCount: 1, diceSides: 12, damageType: 'slashing', isHeavy: true, defaultMastery: WeaponMastery.topple),
    DprWeaponPreset(id: 'maul', name: 'Maul (2d6 Bludgeoning)', category: 'Standard Melee', diceCount: 2, diceSides: 6, damageType: 'bludgeoning', isHeavy: true, defaultMastery: WeaponMastery.topple),
    DprWeaponPreset(id: 'halberd', name: 'Halberd / Glaive (1d10 Slashing, Reach)', category: 'Standard Melee', diceCount: 1, diceSides: 10, damageType: 'slashing', isHeavy: true, defaultMastery: WeaponMastery.graze),
    DprWeaponPreset(id: 'pam_butt', name: 'Polearm Master Butt-End (1d4 Bludgeoning)', category: 'Standard Melee', diceCount: 1, diceSides: 4, damageType: 'bludgeoning', defaultMastery: WeaponMastery.none),
    DprWeaponPreset(id: 'longsword', name: 'Longsword / Warhammer (1d8 / 1d10 Versatile)', category: 'Standard Melee', diceCount: 1, diceSides: 8, damageType: 'slashing', defaultMastery: WeaponMastery.none),
    DprWeaponPreset(id: 'rapier', name: 'Rapier (1d8 Piercing, Finesse)', category: 'Standard Melee', diceCount: 1, diceSides: 8, damageType: 'piercing', defaultMastery: WeaponMastery.vex),
    DprWeaponPreset(id: 'shortsword', name: 'Shortsword (1d6 Piercing)', category: 'Standard Melee', diceCount: 1, diceSides: 6, damageType: 'piercing', defaultMastery: WeaponMastery.vex),
    DprWeaponPreset(id: 'scimitar', name: 'Scimitar / Dagger (1d6 / 1d4)', category: 'Standard Melee', diceCount: 1, diceSides: 6, damageType: 'slashing', defaultMastery: WeaponMastery.nick),
    DprWeaponPreset(id: 'unarmed', name: 'Unarmed Strike (1d6 Monk)', category: 'Standard Melee', diceCount: 1, diceSides: 6, damageType: 'bludgeoning', defaultMastery: WeaponMastery.none),

    // Standard Ranged
    DprWeaponPreset(id: 'hand_crossbow', name: 'Hand Crossbow (1d6 Piercing)', category: 'Standard Ranged', diceCount: 1, diceSides: 6, damageType: 'piercing', defaultMastery: WeaponMastery.vex, isRanged: true),
    DprWeaponPreset(id: 'heavy_crossbow', name: 'Heavy Crossbow (1d10 Piercing)', category: 'Standard Ranged', diceCount: 1, diceSides: 10, damageType: 'piercing', defaultMastery: WeaponMastery.none, isRanged: true, isHeavy: true),
    DprWeaponPreset(id: 'longbow', name: 'Longbow (1d8 Piercing)', category: 'Standard Ranged', diceCount: 1, diceSides: 8, damageType: 'piercing', defaultMastery: WeaponMastery.none, isRanged: true, isHeavy: true),
    DprWeaponPreset(id: 'shortbow', name: 'Shortbow (1d6 Piercing)', category: 'Standard Ranged', diceCount: 1, diceSides: 6, damageType: 'piercing', defaultMastery: WeaponMastery.vex, isRanged: true),

    // Damage Cantrips (Tier 1: Lvl 1-4, Tier 2: Lvl 5-10, Tier 3: Lvl 11-16, Tier 4: Lvl 17-20)
    // Eldritch Blast (Multi-Beam)
    DprWeaponPreset(id: 'eldritch_blast_1', name: 'Eldritch Blast (1x 1d10 Force, 1 Beam, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'force', isRanged: true, isCantrip: true, defaultAttacksPerRound: 1),
    DprWeaponPreset(id: 'eldritch_blast_2', name: 'Eldritch Blast (2x 1d10 Force, 2 Beams, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'force', isRanged: true, isCantrip: true, defaultAttacksPerRound: 2),
    DprWeaponPreset(id: 'eldritch_blast_3', name: 'Eldritch Blast (3x 1d10 Force, 3 Beams, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'force', isRanged: true, isCantrip: true, defaultAttacksPerRound: 3),
    DprWeaponPreset(id: 'eldritch_blast_4', name: 'Eldritch Blast (4x 1d10 Force, 4 Beams, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'force', isRanged: true, isCantrip: true, defaultAttacksPerRound: 4),

    // Fire Bolt
    DprWeaponPreset(id: 'fire_bolt_1', name: 'Fire Bolt (1d10 Fire, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'fire_bolt_2', name: 'Fire Bolt (2d10 Fire, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 10, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'fire_bolt_3', name: 'Fire Bolt (3d10 Fire, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 10, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'fire_bolt_4', name: 'Fire Bolt (4d10 Fire, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 10, damageType: 'fire', isRanged: true, isCantrip: true),

    // Toll the Dead
    DprWeaponPreset(id: 'toll_the_dead_1', name: 'Toll the Dead (1d12 Necrotic, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 12, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'toll_the_dead_2', name: 'Toll the Dead (2d12 Necrotic, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 12, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'toll_the_dead_3', name: 'Toll the Dead (3d12 Necrotic, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 12, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'toll_the_dead_4', name: 'Toll the Dead (4d12 Necrotic, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 12, damageType: 'necrotic', isRanged: true, isCantrip: true),

    // Ray of Frost
    DprWeaponPreset(id: 'ray_of_frost_1', name: 'Ray of Frost (1d8 Cold, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'cold', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'ray_of_frost_2', name: 'Ray of Frost (2d8 Cold, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 8, damageType: 'cold', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'ray_of_frost_3', name: 'Ray of Frost (3d8 Cold, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 8, damageType: 'cold', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'ray_of_frost_4', name: 'Ray of Frost (4d8 Cold, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 8, damageType: 'cold', isRanged: true, isCantrip: true),

    // Sacred Flame
    DprWeaponPreset(id: 'sacred_flame_1', name: 'Sacred Flame (1d8 Radiant, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'radiant', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'sacred_flame_2', name: 'Sacred Flame (2d8 Radiant, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 8, damageType: 'radiant', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'sacred_flame_3', name: 'Sacred Flame (3d8 Radiant, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 8, damageType: 'radiant', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'sacred_flame_4', name: 'Sacred Flame (4d8 Radiant, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 8, damageType: 'radiant', isRanged: true, isCantrip: true),

    // Chill Touch
    DprWeaponPreset(id: 'chill_touch_1', name: 'Chill Touch (1d8 Necrotic, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'chill_touch_2', name: 'Chill Touch (2d8 Necrotic, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 8, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'chill_touch_3', name: 'Chill Touch (3d8 Necrotic, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 8, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'chill_touch_4', name: 'Chill Touch (4d8 Necrotic, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 8, damageType: 'necrotic', isRanged: true, isCantrip: true),

    // Mind Sliver
    DprWeaponPreset(id: 'mind_sliver_1', name: 'Mind Sliver (1d6 Psychic, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 6, damageType: 'psychic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'mind_sliver_2', name: 'Mind Sliver (2d6 Psychic, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 6, damageType: 'psychic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'mind_sliver_3', name: 'Mind Sliver (3d6 Psychic, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 6, damageType: 'psychic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'mind_sliver_4', name: 'Mind Sliver (4d6 Psychic, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 6, damageType: 'psychic', isRanged: true, isCantrip: true),

    // Shocking Grasp
    DprWeaponPreset(id: 'shocking_grasp_1', name: 'Shocking Grasp (1d8 Lightning, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'lightning', isCantrip: true),
    DprWeaponPreset(id: 'shocking_grasp_2', name: 'Shocking Grasp (2d8 Lightning, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 8, damageType: 'lightning', isCantrip: true),
    DprWeaponPreset(id: 'shocking_grasp_3', name: 'Shocking Grasp (3d8 Lightning, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 8, damageType: 'lightning', isCantrip: true),
    DprWeaponPreset(id: 'shocking_grasp_4', name: 'Shocking Grasp (4d8 Lightning, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 8, damageType: 'lightning', isCantrip: true),

    // Poison Spray
    DprWeaponPreset(id: 'poison_spray_1', name: 'Poison Spray (1d12 Poison, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 12, damageType: 'poison', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'poison_spray_2', name: 'Poison Spray (2d12 Poison, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 12, damageType: 'poison', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'poison_spray_3', name: 'Poison Spray (3d12 Poison, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 12, damageType: 'poison', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'poison_spray_4', name: 'Poison Spray (4d12 Poison, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 12, damageType: 'poison', isRanged: true, isCantrip: true),

    // Acid Splash
    DprWeaponPreset(id: 'acid_splash_1', name: 'Acid Splash (1d6 Acid, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 6, damageType: 'acid', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'acid_splash_2', name: 'Acid Splash (2d6 Acid, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 6, damageType: 'acid', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'acid_splash_3', name: 'Acid Splash (3d6 Acid, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 6, damageType: 'acid', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'acid_splash_4', name: 'Acid Splash (4d6 Acid, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 6, damageType: 'acid', isRanged: true, isCantrip: true),

    // Vicious Mockery
    DprWeaponPreset(id: 'vicious_mockery_1', name: 'Vicious Mockery (1d4 Psychic, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 4, damageType: 'psychic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'vicious_mockery_2', name: 'Vicious Mockery (2d4 Psychic, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 4, damageType: 'psychic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'vicious_mockery_3', name: 'Vicious Mockery (3d4 Psychic, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 4, damageType: 'psychic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'vicious_mockery_4', name: 'Vicious Mockery (4d4 Psychic, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 4, damageType: 'psychic', isRanged: true, isCantrip: true),

    // Produce Flame
    DprWeaponPreset(id: 'produce_flame_1', name: 'Produce Flame (1d8 Fire, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'produce_flame_2', name: 'Produce Flame (2d8 Fire, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 8, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'produce_flame_3', name: 'Produce Flame (3d8 Fire, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 8, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'produce_flame_4', name: 'Produce Flame (4d8 Fire, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 8, damageType: 'fire', isRanged: true, isCantrip: true),

    // Primal Savagery
    DprWeaponPreset(id: 'primal_savagery_1', name: 'Primal Savagery (1d10 Acid, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'acid', isCantrip: true),
    DprWeaponPreset(id: 'primal_savagery_2', name: 'Primal Savagery (2d10 Acid, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 10, damageType: 'acid', isCantrip: true),
    DprWeaponPreset(id: 'primal_savagery_3', name: 'Primal Savagery (3d10 Acid, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 10, damageType: 'acid', isCantrip: true),
    DprWeaponPreset(id: 'primal_savagery_4', name: 'Primal Savagery (4d10 Acid, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 10, damageType: 'acid', isCantrip: true),

    // Thorn Whip
    DprWeaponPreset(id: 'thorn_whip_1', name: 'Thorn Whip (1d6 Piercing, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 6, damageType: 'piercing', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'thorn_whip_2', name: 'Thorn Whip (2d6 Piercing, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 6, damageType: 'piercing', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'thorn_whip_3', name: 'Thorn Whip (3d6 Piercing, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 6, damageType: 'piercing', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'thorn_whip_4', name: 'Thorn Whip (4d6 Piercing, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 6, damageType: 'piercing', isRanged: true, isCantrip: true),

    // Word of Radiance
    DprWeaponPreset(id: 'word_of_radiance_1', name: 'Word of Radiance (1d6 Radiant, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 6, damageType: 'radiant', isCantrip: true),
    DprWeaponPreset(id: 'word_of_radiance_2', name: 'Word of Radiance (2d6 Radiant, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 6, damageType: 'radiant', isCantrip: true),
    DprWeaponPreset(id: 'word_of_radiance_3', name: 'Word of Radiance (3d6 Radiant, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 3, diceSides: 6, damageType: 'radiant', isCantrip: true),
    DprWeaponPreset(id: 'word_of_radiance_4', name: 'Word of Radiance (4d6 Radiant, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 4, diceSides: 6, damageType: 'radiant', isCantrip: true),

    // Booming Blade
    DprWeaponPreset(id: 'booming_blade_1', name: 'Booming Blade (1d8 Weapon, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', isCantrip: true),
    DprWeaponPreset(id: 'booming_blade_2', name: 'Booming Blade (1d8 Weapon + 1d8 Thunder, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 1, secondaryDiceSides: 8, secondaryDamageType: 'thunder', isCantrip: true),
    DprWeaponPreset(id: 'booming_blade_3', name: 'Booming Blade (1d8 Weapon + 2d8 Thunder, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 2, secondaryDiceSides: 8, secondaryDamageType: 'thunder', isCantrip: true),
    DprWeaponPreset(id: 'booming_blade_4', name: 'Booming Blade (1d8 Weapon + 3d8 Thunder, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 3, secondaryDiceSides: 8, secondaryDamageType: 'thunder', isCantrip: true),

    // Green-Flame Blade
    DprWeaponPreset(id: 'green_flame_blade_1', name: 'Green-Flame Blade (1d8 Weapon, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', isCantrip: true),
    DprWeaponPreset(id: 'green_flame_blade_2', name: 'Green-Flame Blade (1d8 Weapon + 1d8 Fire, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 1, secondaryDiceSides: 8, secondaryDamageType: 'fire', isCantrip: true),
    DprWeaponPreset(id: 'green_flame_blade_3', name: 'Green-Flame Blade (1d8 Weapon + 2d8 Fire, Lvl 11-16)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 2, secondaryDiceSides: 8, secondaryDamageType: 'fire', isCantrip: true),
    DprWeaponPreset(id: 'green_flame_blade_4', name: 'Green-Flame Blade (1d8 Weapon + 3d8 Fire, Lvl 17-20)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 3, secondaryDiceSides: 8, secondaryDamageType: 'fire', isCantrip: true),

    // Weapon Enhancing & Ranged Utility Cantrips
    DprWeaponPreset(id: 'shillelagh', name: 'Shillelagh (1d8 Magical Bludgeoning, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'bludgeoning', isCantrip: true),
    DprWeaponPreset(id: 'shillelagh_2', name: 'Shillelagh (1d10 Magical Bludgeoning, 2024 Lvl 5+)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'bludgeoning', isCantrip: true),
    DprWeaponPreset(id: 'shillelagh_3', name: 'Shillelagh (1d12 Magical Bludgeoning, 2024 Lvl 11+)', category: 'Damage Cantrip', diceCount: 1, diceSides: 12, damageType: 'bludgeoning', isCantrip: true),
    DprWeaponPreset(id: 'shillelagh_4', name: 'Shillelagh (2d6 Magical Bludgeoning, 2024 Lvl 17+)', category: 'Damage Cantrip', diceCount: 2, diceSides: 6, damageType: 'bludgeoning', isCantrip: true),
    DprWeaponPreset(id: 'magic_stone', name: 'Magic Stone (1d6 Bludgeoning Ranged, 3 Stones)', category: 'Damage Cantrip', diceCount: 1, diceSides: 6, damageType: 'bludgeoning', isRanged: true, isCantrip: true),

    // Magic & Spell Weapons
    DprWeaponPreset(id: 'shadow_blade_2', name: 'Shadow Blade (2d8 Psychic, 2nd Lvl)', category: 'Magic Weapon', diceCount: 2, diceSides: 8, damageType: 'psychic', defaultMastery: WeaponMastery.vex),
    DprWeaponPreset(id: 'shadow_blade_3', name: 'Shadow Blade (3d8 Psychic, 3rd-4th Lvl)', category: 'Magic Weapon', diceCount: 3, diceSides: 8, damageType: 'psychic', defaultMastery: WeaponMastery.vex),
    DprWeaponPreset(id: 'shadow_blade_5', name: 'Shadow Blade (4d8 Psychic, 5th+ Lvl)', category: 'Magic Weapon', diceCount: 4, diceSides: 8, damageType: 'psychic', defaultMastery: WeaponMastery.vex),
    DprWeaponPreset(id: 'magic_plus_1', name: '+1 Magic Weapon (+1 hit & dmg)', category: 'Magic Weapon', diceCount: 1, diceSides: 8, damageType: 'slashing', flatBonus: 1),
    DprWeaponPreset(id: 'magic_plus_2', name: '+2 Magic Weapon (+2 hit & dmg)', category: 'Magic Weapon', diceCount: 1, diceSides: 8, damageType: 'slashing', flatBonus: 2),
    DprWeaponPreset(id: 'magic_plus_3', name: '+3 Magic Weapon (+3 hit & dmg)', category: 'Magic Weapon', diceCount: 1, diceSides: 8, damageType: 'slashing', flatBonus: 3),
    DprWeaponPreset(id: 'flame_tongue_greatsword', name: 'Flame Tongue Greatsword (2d6 + 2d6 Fire)', category: 'Magic Weapon', diceCount: 2, diceSides: 6, damageType: 'slashing', secondaryDiceCount: 2, secondaryDiceSides: 6, secondaryDamageType: 'fire', isHeavy: true, defaultMastery: WeaponMastery.graze),
    DprWeaponPreset(id: 'flame_tongue_sword', name: 'Flame Tongue Longsword (1d8 + 2d6 Fire)', category: 'Magic Weapon', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 2, secondaryDiceSides: 6, secondaryDamageType: 'fire'),
    DprWeaponPreset(id: 'frost_brand', name: 'Frost Brand (+1d6 Cold)', category: 'Magic Weapon', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 1, secondaryDiceSides: 6, secondaryDamageType: 'cold'),
    DprWeaponPreset(id: 'sun_blade', name: 'Sun Blade (+2, 1d8 Radiant + 1d8 Undead)', category: 'Magic Weapon', diceCount: 1, diceSides: 8, damageType: 'radiant', flatBonus: 2, defaultMastery: WeaponMastery.none),
    DprWeaponPreset(id: 'dragon_slayer', name: 'Dragon Slayer (+1, +3d6 vs Dragons)', category: 'Magic Weapon', diceCount: 1, diceSides: 8, damageType: 'slashing', flatBonus: 1, secondaryDiceCount: 3, secondaryDiceSides: 6, secondaryDamageType: 'slashing'),
    DprWeaponPreset(id: 'holy_avenger', name: 'Holy Avenger (+3, +2d10 Radiant)', category: 'Magic Weapon', diceCount: 1, diceSides: 8, damageType: 'slashing', flatBonus: 3, secondaryDiceCount: 2, secondaryDiceSides: 10, secondaryDamageType: 'radiant'),
  ];
}

/// Delivery mode of an offensive action (Attack Roll vs Saving Throw vs Utility).
enum DprActionDeliveryType {
  attackRoll,
  savingThrow,
  utility,
}

/// Represents a single weapon attack, offensive spell, or action profile in a combatant's turn.
class DprAttackAction {
  final String id;
  final String name;
  final int attackBonus;
  final int diceCount;
  final int diceSides;
  final int damageBonus;
  final String damageType;

  // Delivery Mode & Saving Throw Mechanics
  final DprActionDeliveryType deliveryType;
  final String? saveAbility; // 'str', 'dex', 'con', 'int', 'wis', 'cha'
  final int? saveDc;
  final bool halfDamageOnSave; // true = half damage on save, false = no damage on save

  // Area of Effect & Target Scaling
  final bool isAoe;
  final int targetCount; // default 1 for single-target, 2 for standard 5e DMG AoE assumptions

  // Recharge & Action Horizons (e.g. Recharge 5-6 -> 5, Recharge 6 -> 6)
  final int? rechargeRoll;

  // Legendary Actions
  final bool isLegendaryAction;
  final int legendaryCost; // 1, 2, or 3 actions

  // Secondary / Rider Damage (e.g. Hunter's Mark, Smite, Hex, Poison)
  final int secondaryDiceCount;
  final int secondaryDiceSides;
  final int secondaryDamageBonus;
  final String? secondaryDamageType;

  // Feats, Invocations & Fighting Styles
  final GwmMode gwmMode;
  final GwfVersion gwfVersion;
  final bool hasDueling; // +2 damage on 1H melee
  final bool hasArchery; // +2 to-hit on ranged
  final bool hasThrownWeapon; // +2 damage on thrown
  final bool isOffhandWithoutTwf; // no ability mod to damage
  final bool hasAgonizingBlast; // adds ability modifier to cantrip / Eldritch Blast damage
  final int abilityModForAgonizing;
  final bool hasHalflingLuck; // rerolls natural 1s on attack rolls

  // Weapon Mastery
  final WeaponMastery weaponMastery;
  final int abilityModForGraze; // Used if Graze mastery is active

  // Critical Hit Modifiers
  final int critThreshold; // 20 for standard, 19 for Champion, 18 for Superior
  final int extraCritDiceCount; // +1 for Half-Orc Savage Attacks / Brutal Critical
  final int extraCritDiceSides;

  // Buffs / Precision Modifiers
  final int attackBuffDiceSides; // e.g. 4 for Bless (+1d4), 6/8/10/12 for Bardic/Precision
  final int attackBuffFlat; // e.g. +1/+2/+3 magic weapon or flat buff

  // Attack Count & Action Economy
  final int attacksPerRound;
  final bool isBonusActionAttack;
  final int reachInFeet;
  final AttackType? attackTypeOverride;

  const DprAttackAction({
    required this.id,
    required this.name,
    required this.attackBonus,
    required this.diceCount,
    required this.diceSides,
    required this.damageBonus,
    this.damageType = 'slashing',
    this.deliveryType = DprActionDeliveryType.attackRoll,
    this.saveAbility,
    this.saveDc,
    this.halfDamageOnSave = true,
    this.isAoe = false,
    this.targetCount = 1,
    this.rechargeRoll,
    this.isLegendaryAction = false,
    this.legendaryCost = 1,
    this.secondaryDiceCount = 0,
    this.secondaryDiceSides = 0,
    this.secondaryDamageBonus = 0,
    this.secondaryDamageType,
    this.gwmMode = GwmMode.none,
    this.gwfVersion = GwfVersion.none,
    this.hasDueling = false,
    this.hasArchery = false,
    this.hasThrownWeapon = false,
    this.isOffhandWithoutTwf = false,
    this.hasAgonizingBlast = false,
    this.abilityModForAgonizing = 0,
    this.hasHalflingLuck = false,
    this.weaponMastery = WeaponMastery.none,
    this.abilityModForGraze = 0,
    this.critThreshold = 20,
    this.extraCritDiceCount = 0,
    this.extraCritDiceSides = 0,
    this.attackBuffDiceSides = 0,
    this.attackBuffFlat = 0,
    this.attacksPerRound = 1,
    this.isBonusActionAttack = false,
    this.reachInFeet = 5,
    this.attackTypeOverride,
  });

  /// Evaluates the 5e AttackType classification (meleeStandard, meleeReach, rangedWeapon, rangedSpell).
  AttackType get attackType {
    if (attackTypeOverride != null) return attackTypeOverride!;
    final nameLower = name.toLowerCase();
    final isRanged = nameLower.contains('bow') ||
        nameLower.contains('ranged') ||
        nameLower.contains('javelin') ||
        nameLower.contains('sling') ||
        nameLower.contains('dart') ||
        nameLower.contains('crossbow');
    final isSpell = nameLower.contains('ray') ||
        nameLower.contains('bolt') ||
        nameLower.contains('blast') ||
        nameLower.contains('missile') ||
        deliveryType == DprActionDeliveryType.savingThrow;

    if (isSpell) return AttackType.rangedSpell;
    if (isRanged) return AttackType.rangedWeapon;
    if (reachInFeet >= 10) return AttackType.meleeReach;
    return AttackType.meleeStandard;
  }

  DprAttackAction copyWith({
    String? id,
    String? name,
    int? attackBonus,
    int? diceCount,
    int? diceSides,
    int? damageBonus,
    String? damageType,
    DprActionDeliveryType? deliveryType,
    String? saveAbility,
    int? saveDc,
    bool? halfDamageOnSave,
    bool? isAoe,
    int? targetCount,
    int? rechargeRoll,
    bool? isLegendaryAction,
    int? legendaryCost,
    int? secondaryDiceCount,
    int? secondaryDiceSides,
    int? secondaryDamageBonus,
    String? secondaryDamageType,
    GwmMode? gwmMode,
    GwfVersion? gwfVersion,
    bool? hasDueling,
    bool? hasArchery,
    bool? hasThrownWeapon,
    bool? isOffhandWithoutTwf,
    bool? hasAgonizingBlast,
    int? abilityModForAgonizing,
    bool? hasHalflingLuck,
    WeaponMastery? weaponMastery,
    int? abilityModForGraze,
    int? critThreshold,
    int? extraCritDiceCount,
    int? extraCritDiceSides,
    int? attackBuffDiceSides,
    int? attackBuffFlat,
    int? attacksPerRound,
    bool? isBonusActionAttack,
    int? reachInFeet,
    AttackType? attackTypeOverride,
  }) {
    return DprAttackAction(
      id: id ?? this.id,
      name: name ?? this.name,
      attackBonus: attackBonus ?? this.attackBonus,
      diceCount: diceCount ?? this.diceCount,
      diceSides: diceSides ?? this.diceSides,
      damageBonus: damageBonus ?? this.damageBonus,
      damageType: damageType ?? this.damageType,
      deliveryType: deliveryType ?? this.deliveryType,
      saveAbility: saveAbility ?? this.saveAbility,
      saveDc: saveDc ?? this.saveDc,
      halfDamageOnSave: halfDamageOnSave ?? this.halfDamageOnSave,
      isAoe: isAoe ?? this.isAoe,
      targetCount: targetCount ?? this.targetCount,
      rechargeRoll: rechargeRoll ?? this.rechargeRoll,
      isLegendaryAction: isLegendaryAction ?? this.isLegendaryAction,
      legendaryCost: legendaryCost ?? this.legendaryCost,
      secondaryDiceCount: secondaryDiceCount ?? this.secondaryDiceCount,
      secondaryDiceSides: secondaryDiceSides ?? this.secondaryDiceSides,
      secondaryDamageBonus: secondaryDamageBonus ?? this.secondaryDamageBonus,
      secondaryDamageType: secondaryDamageType ?? this.secondaryDamageType,
      gwmMode: gwmMode ?? this.gwmMode,
      gwfVersion: gwfVersion ?? this.gwfVersion,
      hasDueling: hasDueling ?? this.hasDueling,
      hasArchery: hasArchery ?? this.hasArchery,
      hasThrownWeapon: hasThrownWeapon ?? this.hasThrownWeapon,
      isOffhandWithoutTwf: isOffhandWithoutTwf ?? this.isOffhandWithoutTwf,
      hasAgonizingBlast: hasAgonizingBlast ?? this.hasAgonizingBlast,
      abilityModForAgonizing: abilityModForAgonizing ?? this.abilityModForAgonizing,
      hasHalflingLuck: hasHalflingLuck ?? this.hasHalflingLuck,
      weaponMastery: weaponMastery ?? this.weaponMastery,
      abilityModForGraze: abilityModForGraze ?? this.abilityModForGraze,
      critThreshold: critThreshold ?? this.critThreshold,
      extraCritDiceCount: extraCritDiceCount ?? this.extraCritDiceCount,
      extraCritDiceSides: extraCritDiceSides ?? this.extraCritDiceSides,
      attackBuffDiceSides: attackBuffDiceSides ?? this.attackBuffDiceSides,
      attackBuffFlat: attackBuffFlat ?? this.attackBuffFlat,
      attacksPerRound: attacksPerRound ?? this.attacksPerRound,
      isBonusActionAttack: isBonusActionAttack ?? this.isBonusActionAttack,
      reachInFeet: reachInFeet ?? this.reachInFeet,
      attackTypeOverride: attackTypeOverride ?? this.attackTypeOverride,
    );
  }

  /// Formatted damage formula (e.g., "2d6 + 4 slashing", "8d6 fire (DC 15 Dex, 2 targets)").
  String get formulaDisplay {
    final buffer = StringBuffer();
    if (diceCount > 0 && diceSides > 0) {
      buffer.write('${diceCount}d$diceSides');
    }
    var totalBonus = damageBonus + attackBuffFlat;
    if (hasDueling) totalBonus += 2;
    if (hasThrownWeapon) totalBonus += 2;
    if (hasAgonizingBlast && abilityModForAgonizing > 0) totalBonus += abilityModForAgonizing;
    if (gwmMode == GwmMode.v2014PowerAttack) totalBonus += 10;

    if (totalBonus > 0) {
      buffer.write(' + $totalBonus');
    } else if (totalBonus < 0) {
      buffer.write(' - ${totalBonus.abs()}');
    }

    if (damageType.isNotEmpty) {
      buffer.write(' $damageType');
    }

    if (secondaryDiceCount > 0 && secondaryDiceSides > 0) {
      buffer.write(' + ${secondaryDiceCount}d$secondaryDiceSides');
      if (secondaryDamageBonus > 0) {
        buffer.write(' + $secondaryDamageBonus');
      }
      if (secondaryDamageType != null && secondaryDamageType!.isNotEmpty) {
        buffer.write(' $secondaryDamageType');
      }
    }

    if (deliveryType == DprActionDeliveryType.savingThrow && saveDc != null) {
      final saveLabel = saveAbility != null ? ' ${saveAbility!.toUpperCase()}' : '';
      buffer.write(' (DC $saveDc$saveLabel)');
    }

    if (isAoe && targetCount > 1) {
      buffer.write(' × $targetCount targets');
    }

    if (rechargeRoll != null) {
      final rechStr = rechargeRoll == 5 ? '5–6' : '$rechargeRoll';
      buffer.write(' [Recharge $rechStr]');
    }

    return buffer.toString().trim();
  }
}

/// Complete combatant profile for DPR evaluation (Characters, Minions, Monsters).
class DprCombatantProfile {
  final String id;
  final String name;
  final String description;
  final int level;
  final int abilityScore;
  final int proficiencyBonus;
  final AdvantageType defaultAdvantage;
  final int sneakAttackDiceCount; // 0 for none, 1..10 for Rogues (once per turn proc)
  final int sneakAttackDiceSides;
  final List<DprAttackAction> attacks;

  const DprCombatantProfile({
    required this.id,
    required this.name,
    this.description = '',
    this.level = 5,
    this.abilityScore = 18,
    this.proficiencyBonus = 3,
    this.defaultAdvantage = AdvantageType.normal,
    this.sneakAttackDiceCount = 0,
    this.sneakAttackDiceSides = 6,
    this.hasHalflingLuck = false,
    this.attacks = const [],
  });

  final bool hasHalflingLuck;
  int get abilityModifier => abilityScore.dndModifier;

  /// Creates a completely clean default custom profile with NO situational feats/styles toggled on.
  factory DprCombatantProfile.cleanCustom({
    int level = 5,
    int abilityScore = 18,
    int proficiencyBonus = 3,
  }) {
    final abilityMod = abilityScore.dndModifier;
    final attackBonus = abilityMod + proficiencyBonus;

    return DprCombatantProfile(
      id: 'custom',
      name: 'Custom Character Build',
      description: 'Level $level Character (+$abilityMod Mod, +$proficiencyBonus PB)',
      level: level,
      abilityScore: abilityScore,
      proficiencyBonus: proficiencyBonus,
      defaultAdvantage: AdvantageType.normal,
      sneakAttackDiceCount: 0,
      hasHalflingLuck: false,
      attacks: [
        DprAttackAction(
          id: 'attack_primary',
          name: 'Primary Weapon',
          attackBonus: attackBonus,
          diceCount: 1,
          diceSides: 8,
          damageBonus: abilityMod,
          damageType: 'slashing',
          attacksPerRound: 1,
        ),
      ],
    );
  }

  DprCombatantProfile copyWith({
    String? id,
    String? name,
    String? description,
    int? level,
    int? abilityScore,
    int? proficiencyBonus,
    AdvantageType? defaultAdvantage,
    int? sneakAttackDiceCount,
    int? sneakAttackDiceSides,
    bool? hasHalflingLuck,
    List<DprAttackAction>? attacks,
  }) {
    return DprCombatantProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      level: level ?? this.level,
      abilityScore: abilityScore ?? this.abilityScore,
      proficiencyBonus: proficiencyBonus ?? this.proficiencyBonus,
      defaultAdvantage: defaultAdvantage ?? this.defaultAdvantage,
      sneakAttackDiceCount: sneakAttackDiceCount ?? this.sneakAttackDiceCount,
      sneakAttackDiceSides: sneakAttackDiceSides ?? this.sneakAttackDiceSides,
      hasHalflingLuck: hasHalflingLuck ?? this.hasHalflingLuck,
      attacks: attacks ?? this.attacks,
    );
  }

  /// Factory constructor to convert any MinionStatBlock into a DprCombatantProfile.
  factory DprCombatantProfile.fromMinionStatBlock(
    MinionStatBlock statBlock, {
    AdvantageType? advantage,
  }) {
    final adv = advantage ??
        (statBlock.hasPackTactics ? AdvantageType.advantage : AdvantageType.normal);

    final actions = <DprAttackAction>[];

    // Primary action
    if (statBlock.damageDiceCount > 0 && statBlock.damageDiceSides > 0) {
      actions.add(
        DprAttackAction(
          id: '${statBlock.id}_primary',
          name: statBlock.name,
          attackBonus: statBlock.attackBonus,
          diceCount: statBlock.damageDiceCount,
          diceSides: statBlock.damageDiceSides,
          damageBonus: statBlock.damageBonus,
          damageType: statBlock.damageType,
          secondaryDiceCount: statBlock.secondaryDamageDiceCount,
          secondaryDiceSides: statBlock.secondaryDamageDiceSides,
          secondaryDamageType: statBlock.secondaryDamageType,
          attacksPerRound: 1,
        ),
      );
    }

    return DprCombatantProfile(
      id: statBlock.id,
      name: statBlock.name,
      description: 'CR ${statBlock.crDisplay} ${statBlock.sizeDisplay} ${statBlock.typeDisplay}',
      level: math.max(1, statBlock.crDisplay.contains('/') ? 1 : int.tryParse(statBlock.crDisplay) ?? 1),
      abilityScore: math.max(statBlock.strScore, statBlock.dexScore),
      proficiencyBonus: 2,
      defaultAdvantage: adv,
      attacks: actions,
    );
  }

  /// Factory constructor to convert any MonsterItem from Monster Codex into a DprCombatantProfile.
  factory DprCombatantProfile.fromMonsterItem(
    MonsterItem monster, {
    DmRulesEdition edition = DmRulesEdition.v2024,
    AdvantageType? advantage,
  }) {
    final sb = monster.getStatBlock(edition);
    final adv = advantage ??
        (sb.hasPackTactics ? AdvantageType.advantage : AdvantageType.normal);

    final parsedActions = <DprAttackAction>[];

    // Try parsing specific weapon attack actions from the monster stat block
    for (int i = 0; i < sb.actions.length; i++) {
      final act = sb.actions[i];
      if (act.attackBonus != null || (act.attackType != null && act.attackType!.contains('Attack'))) {
        final parsedDice = _parseDamageFormula(act.hitDamage ?? sb.primaryDamageFormula);
        parsedActions.add(
          DprAttackAction(
            id: '${monster.id}_action_$i',
            name: act.name,
            attackBonus: act.attackBonus ?? sb.attackBonus,
            diceCount: parsedDice.diceCount > 0 ? parsedDice.diceCount : sb.damageDiceCount,
            diceSides: parsedDice.diceSides > 0 ? parsedDice.diceSides : sb.damageDiceSides,
            damageBonus: parsedDice.bonus != 0 ? parsedDice.bonus : sb.damageBonus,
            damageType: parsedDice.damageType.isNotEmpty ? parsedDice.damageType : sb.damageType,
            attacksPerRound: 1,
          ),
        );
      }
    }

    // Fallback if no actions parsed
    if (parsedActions.isEmpty) {
      parsedActions.add(
        DprAttackAction(
          id: '${monster.id}_default',
          name: monster.getName(edition),
          attackBonus: sb.attackBonus,
          diceCount: sb.damageDiceCount,
          diceSides: sb.damageDiceSides,
          damageBonus: sb.damageBonus,
          damageType: sb.damageType,
          secondaryDiceCount: sb.secondaryDamageDiceCount,
          secondaryDiceSides: sb.secondaryDamageDiceSides,
          secondaryDamageType: sb.secondaryDamageType,
          attacksPerRound: 1,
        ),
      );
    }

    return DprCombatantProfile(
      id: monster.id,
      name: monster.getName(edition),
      description: 'CR ${sb.crDisplay} ${sb.sizeDisplay} ${sb.typeDisplay}',
      level: math.max(1, monster.challengeRating.ceil()),
      abilityScore: math.max(sb.strScore, sb.dexScore),
      proficiencyBonus: ((math.max(1, monster.challengeRating.ceil()) - 1) ~/ 4) + 2,
      defaultAdvantage: adv,
      attacks: parsedActions,
    );
  }

  static _ParsedDamage _parseDamageFormula(String text) {
    final diceRegex = RegExp(r'(\d+)\s*d\s*(\d+)(?:\s*([+-])\s*(\d+))?(?:\s+([a-zA-Z]+))?');
    final match = diceRegex.firstMatch(text);
    if (match != null) {
      final count = int.tryParse(match.group(1) ?? '1') ?? 1;
      final sides = int.tryParse(match.group(2) ?? '6') ?? 6;
      final sign = match.group(3) ?? '+';
      final bonusVal = int.tryParse(match.group(4) ?? '0') ?? 0;
      final bonus = sign == '-' ? -bonusVal : bonusVal;
      final dmgType = match.group(5) ?? '';
      return _ParsedDamage(count, sides, bonus, dmgType);
    }
    return const _ParsedDamage(1, 6, 0, '');
  }
}

class _ParsedDamage {
  final int diceCount;
  final int diceSides;
  final int bonus;
  final String damageType;
  const _ParsedDamage(this.diceCount, this.diceSides, this.bonus, this.damageType);
}

/// Calculated data point for a specific target AC.
class DprPoint {
  final int ac;
  final double dpr;
  final double hitChance;
  final double critChance;
  final double expectedDamageOnHit;
  final double expectedDamageOnCrit;
  final double expectedDamageOnMiss;

  const DprPoint({
    required this.ac,
    required this.dpr,
    required this.hitChance,
    required this.critChance,
    required this.expectedDamageOnHit,
    required this.expectedDamageOnCrit,
    required this.expectedDamageOnMiss,
  });
}

/// Complete curve data mapping target ACs (e.g. 5 to 30) to DPR points.
class DprCurveData {
  final DprCombatantProfile profile;
  final AdvantageType advantage;
  final Map<int, DprPoint> points;

  const DprCurveData({
    required this.profile,
    required this.advantage,
    required this.points,
  });

  double get minDpr {
    if (points.isEmpty) return 0.0;
    return points.values.map((p) => p.dpr).reduce(math.min);
  }

  double get maxDpr {
    if (points.isEmpty) return 0.0;
    return points.values.map((p) => p.dpr).reduce(math.max);
  }

  DprPoint? pointAt(int ac) => points[ac];
}

/// Comprehensive break-even crossover analysis between standard and power attack (GWM/Sharpshooter) profiles.
class DprBreakEvenAnalysis {
  final DprCombatantProfile baselineProfile;
  final DprCombatantProfile powerAttackProfile;
  final DprCurveData baselineCurve;
  final DprCurveData powerAttackCurve;
  
  /// The maximum AC where Power Attack (GWM/SS) deals more or equal DPR than Normal.
  /// Null if GWM is always worse or always better across the evaluated range.
  final int? maxOptimalAcForGwm;

  /// Full recommendation summary text.
  final String recommendation;

  const DprBreakEvenAnalysis({
    required this.baselineProfile,
    required this.powerAttackProfile,
    required this.baselineCurve,
    required this.powerAttackCurve,
    this.maxOptimalAcForGwm,
    required this.recommendation,
  });
}

/// Standard 5e Monster AC Benchmarks by Challenge Rating (CR) for quick target selection.
class DprMonsterAcPreset {
  final String label;
  final String crDisplay;
  final int typicalAc;
  final String examples;

  const DprMonsterAcPreset({
    required this.label,
    required this.crDisplay,
    required this.typicalAc,
    required this.examples,
  });

  static const List<DprMonsterAcPreset> standardPresets = [
    DprMonsterAcPreset(label: 'CR 1/4 - Minion/Unarmored', crDisplay: '1/4', typicalAc: 11, examples: 'Goblin, Skeleton, Cultist'),
    DprMonsterAcPreset(label: 'CR 1 - Standard Monster', crDisplay: '1', typicalAc: 13, examples: 'Bugbear, Ghoul, Spy'),
    DprMonsterAcPreset(label: 'CR 5 - Tough Veteran', crDisplay: '5', typicalAc: 15, examples: 'Gladiator, Troll, Wraith'),
    DprMonsterAcPreset(label: 'CR 10 - Elite / Monster', crDisplay: '10', typicalAc: 17, examples: 'Young Red Dragon, Stone Golem'),
    DprMonsterAcPreset(label: 'CR 15 - Adult Dragon', crDisplay: '15', typicalAc: 18, examples: 'Adult Blue Dragon, Mummy Lord'),
    DprMonsterAcPreset(label: 'CR 20 - Ancient Fiend', crDisplay: '20', typicalAc: 19, examples: 'Pit Fiend, Ancient Brass Dragon'),
    DprMonsterAcPreset(label: 'CR 25+ - Legendary Avatar', crDisplay: '25', typicalAc: 22, examples: 'Solar, Tiamat Avatar'),
    DprMonsterAcPreset(label: 'CR 30 - The Tarrasque', crDisplay: '30', typicalAc: 25, examples: 'Tarrasque (AC 25, Reflective)'),
  ];
}

/// Extension on MinionStatBlock providing DPR conversion, attack extraction, and routine calculations.
extension MinionStatBlockDprExt on MinionStatBlock {
  /// Extracts structured DprAttackAction objects from this monster's stat block, actions, and legendary actions.
  List<DprAttackAction> extractDprAttacks() {
    final attacks = <DprAttackAction>[];
    CreatureAction? multiattackAction;

    for (final action in actions) {
      if (action.name.toLowerCase().contains('multiattack')) {
        multiattackAction = action;
        break;
      }
    }

    // Collect all valid attack actions
    for (final action in actions) {
      if (action == multiattackAction) continue;

      final isAttack = action.attackBonus != null ||
          action.hitDamage != null ||
          (action.attackType != null && action.attackType!.isNotEmpty) ||
          action.description.toLowerCase().contains('to hit') ||
          action.description.toLowerCase().contains('weapon attack') ||
          action.description.toLowerCase().contains('melee attack') ||
          action.description.toLowerCase().contains('ranged attack') ||
          action.description.toLowerCase().contains('spell attack') ||
          (action.description.toLowerCase().contains('saving throw') &&
              action.description.toLowerCase().contains('damage')) ||
          (action.description.toLowerCase().contains('recharge') &&
              action.description.toLowerCase().contains('damage'));

      if (!isAttack) continue;

      final parsed = _parseCreatureActionToDpr(action);
      if (parsed != null) {
        attacks.add(parsed);
      }
    }

    // Collect legendary actions (with regular attacks available for reference lookup)
    for (final legAction in legendaryActions) {
      final parsed = _parseCreatureActionToDpr(
        legAction,
        isLegendary: true,
        availableRegularAttacks: attacks,
      );
      if (parsed != null) {
        attacks.add(parsed);
      }
    }

    if (attacks.isEmpty) {
      attacks.add(
        DprAttackAction(
          id: '${id}_primary',
          name: actions.isNotEmpty ? actions.first.name : 'Primary Attack',
          attackBonus: attackBonus,
          diceCount: damageDiceCount,
          diceSides: damageDiceSides,
          damageBonus: damageBonus,
          damageType: damageType,
          secondaryDiceCount: secondaryDamageDiceCount,
          secondaryDiceSides: secondaryDamageDiceSides,
          secondaryDamageType: secondaryDamageType,
          attacksPerRound: multiattackAction != null ? 2 : 1,
        ),
      );
      return attacks;
    }

    // Resolve attacksPerRound across all regular turn actions
    final turnAttacks = attacks.where((a) => !a.isLegendaryAction).toList();
    _resolveAttacksPerRound(turnAttacks, multiattackAction);
    for (int i = 0; i < turnAttacks.length; i++) {
      final idx = attacks.indexWhere((a) => a.id == turnAttacks[i].id);
      if (idx >= 0) attacks[idx] = turnAttacks[i];
    }

    return attacks;
  }

  void _resolveAttacksPerRound(
    List<DprAttackAction> attacks,
    CreatureAction? multiattack,
  ) {
    if (multiattack == null) {
      // Without Multiattack, a creature has 1 action per round and makes 1 attack.
      _assignSingleBestAttack(attacks, 1);
      return;
    }

    final multiDesc = multiattack.description.toLowerCase();

    // 1. Extract global attack count if stated (e.g. "makes three attacks", "makes five attacks")
    int globalCount = 2; // Default 5e fallback
    final globalMatch = RegExp(
      r'makes\s+(one|two|three|four|five|six|seven|eight|\d+)\s+(?:melee\s+|ranged\s+|weapon\s+)?attacks?',
      caseSensitive: false,
    ).firstMatch(multiDesc);
    if (globalMatch != null) {
      globalCount = _parseNumberWord(globalMatch.group(1));
      if (globalCount <= 0) globalCount = 2;
    }

    // 2. Filter out non-attack replacement clauses (e.g. "It can use its Swallow instead of its bite.")
    final cleanedDesc = multiDesc
        .replaceAll(RegExp(r'it can (?:use|make) its swallow instead of its bite\.?', caseSensitive: false), '')
        .replaceAll(RegExp(r'it can use its frightful presence\.?', caseSensitive: false), '')
        .replaceAll(RegExp(r'it can replace one (?:of those )?attacks? with [^.]*\.?', caseSensitive: false), '')
        .trim();

    // 3. Identify distinct option branches separated by alternative keywords
    final branchSegments = _splitMultiattackBranches(cleanedDesc);

    List<int>? bestBranchCounts;
    double bestBranchDpr = -1.0;

    for (final branch in branchSegments) {
      final branchCounts = List<int>.filled(attacks.length, 0);
      bool anyExplicitMatched = false;

      // First pass: look for explicit numbers ("one with its bite", "two with its claws")
      for (int i = 0; i < attacks.length; i++) {
        final attack = attacks[i];
        final nameLower = attack.name.toLowerCase();
        final cleanName = nameLower.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
        final baseName = cleanName.endsWith('s') && cleanName.length > 3
            ? cleanName.substring(0, cleanName.length - 1)
            : cleanName;

        final count = _extractAttackCountForName(branch, cleanName, baseName);
        if (count > 0) {
          branchCounts[i] = count;
          anyExplicitMatched = true;
        }
      }

      // Second pass: if NO explicit numbers found in the entire branch, check if a single weapon is mentioned
      if (!anyExplicitMatched) {
        int branchGlobal = globalCount;
        final bMatch = RegExp(
          r'(?:makes\s+)?(one|two|three|four|five|six|seven|eight|\d+)\s+(?:melee\s+|ranged\s+|weapon\s+)?attacks?',
          caseSensitive: false,
        ).firstMatch(branch);
        if (bMatch != null) {
          final parsed = _parseNumberWord(bMatch.group(1));
          if (parsed > 0) branchGlobal = parsed;
        }

        for (int i = 0; i < attacks.length; i++) {
          final attack = attacks[i];
          final nameLower = attack.name.toLowerCase();
          final cleanName = nameLower.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
          final baseName = cleanName.endsWith('s') && cleanName.length > 3
              ? cleanName.substring(0, cleanName.length - 1)
              : cleanName;

          if (_branchMentionsWeapon(branch, cleanName, baseName)) {
            branchCounts[i] = branchGlobal;
            break; // Assign to the mentioned weapon in this branch
          }
        }
      }

      if (branchCounts.any((c) => c > 0)) {
        // Calculate estimated branch offensive DPR
        double branchDpr = 0.0;
        for (int i = 0; i < attacks.length; i++) {
          if (branchCounts[i] > 0) {
            final a = attacks[i];
            final avgHitDmg = (a.diceCount * (a.diceSides + 1) / 2.0) +
                a.damageBonus +
                (a.secondaryDiceCount * (a.secondaryDiceSides + 1) / 2.0) +
                a.secondaryDamageBonus;
            final hitProb = ((21 - (15 - a.attackBonus)).clamp(2, 20)) / 20.0;
            branchDpr += (avgHitDmg * hitProb) * branchCounts[i];
          }
        }

        if (branchDpr > bestBranchDpr) {
          bestBranchDpr = branchDpr;
          bestBranchCounts = branchCounts;
        }
      }
    }

    if (bestBranchCounts != null && bestBranchCounts.any((c) => c > 0)) {
      for (int i = 0; i < attacks.length; i++) {
        attacks[i] = attacks[i].copyWith(attacksPerRound: bestBranchCounts[i]);
      }
      return;
    }

    // 4. Fallback for generic Multiattack ("The knight makes two melee attacks.")
    _assignSingleBestAttack(attacks, globalCount);
  }

  List<String> _splitMultiattackBranches(String desc) {
    final rawParts = desc.split(RegExp(
      r'--\s*or\s+|\b(?:either\s+)?with\s+its\s+[^,;]+?\s+or\s+(?:with\s+)?its\s+|,\s*or\s+(?:it\s+can\s+|makes\s+|with\s+)|\.\s+(?:or|alternatively)\s+|\bor\s+(?:two|three|four|five|six|\d+)\s+',
      caseSensitive: false,
    ));
    final branches = <String>[];
    for (final p in rawParts) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty && trimmed != 'the' && trimmed != 'a') {
        branches.add(trimmed);
      }
    }
    return branches.isNotEmpty ? branches : [desc];
  }

  bool _branchMentionsWeapon(String branch, String cleanName, String baseName) {
    final escaped = RegExp.escape(cleanName);
    final baseEscaped = RegExp.escape(baseName);
    return RegExp('\\b(?:$escaped|$baseEscaped)(?:s)?\\b', caseSensitive: false).hasMatch(branch);
  }

  void _assignSingleBestAttack(List<DprAttackAction> attacks, int count) {
    int bestIndex = 0;
    double maxDmg = -1;

    for (int i = 0; i < attacks.length; i++) {
      final a = attacks[i];
      final avgDmg = (a.diceCount * (a.diceSides + 1) / 2.0) +
          a.damageBonus +
          (a.secondaryDiceCount * (a.secondaryDiceSides + 1) / 2.0) +
          a.secondaryDamageBonus;
      if (avgDmg > maxDmg) {
        maxDmg = avgDmg;
        bestIndex = i;
      }
    }

    for (int i = 0; i < attacks.length; i++) {
      attacks[i] = attacks[i].copyWith(attacksPerRound: (i == bestIndex) ? count : 0);
    }
  }

  int _extractAttackCountForName(String desc, String cleanName, String baseName) {
    final aliases = <String>{
      cleanName,
      baseName,
      if (!cleanName.endsWith('s')) '${cleanName}s',
      if (cleanName.endsWith('s') && cleanName.length > 3)
        cleanName.substring(0, cleanName.length - 1),
    };

    if (cleanName == 'staff' || baseName == 'staff') aliases.add('staves');
    if (cleanName == 'hoof' || baseName == 'hoof') aliases.add('hooves');
    if (cleanName == 'tooth' || baseName == 'tooth') aliases.add('teeth');

    for (final name in aliases) {
      final escaped = RegExp.escape(name);

      final prefixRegex = RegExp(
        r'\b(one|two|three|four|five|six|seven|eight|1|2|3|4|5|6|7|8)\s+(?:melee\s+|ranged\s+|weapon\s+)?(?:attacks?\s+)?(?:with\s+(?:its|their|either|a)\s+)?' +
            escaped +
            r'\b',
        caseSensitive: false,
      );

      final prefixMatch = prefixRegex.firstMatch(desc);
      if (prefixMatch != null) {
        final count = _parseNumberWord(prefixMatch.group(1));
        if (count > 0) return count;
      }

      final andRegex = RegExp(
        r'\band\s+(?:one\s+(?:with\s+(?:its|their)\s+)?|its\s+|their\s+|a\s+)' +
            escaped +
            r'\b',
        caseSensitive: false,
      );
      if (andRegex.hasMatch(desc)) {
        return 1;
      }

      final postfixRegex = RegExp(
        escaped +
            r'\b(?:\s+attacks?)?\s*[:(]?\s*(?:with\s+(?:its|their)\s+)?\b(one|two|three|four|five|six|seven|eight|1|2|3|4|5|6|7|8)\b',
        caseSensitive: false,
      );
      final postfixMatch = postfixRegex.firstMatch(desc);
      if (postfixMatch != null) {
        final count = _parseNumberWord(postfixMatch.group(1));
        if (count > 0) return count;
      }
    }

    return 0;
  }

  int _parseNumberWord(String? s) {
    if (s == null) return 0;
    switch (s.toLowerCase().trim()) {
      case '1':
      case 'one':
        return 1;
      case '2':
      case 'two':
        return 2;
      case '3':
      case 'three':
        return 3;
      case '4':
      case 'four':
        return 4;
      case '5':
      case 'five':
        return 5;
      case '6':
      case 'six':
        return 6;
      case '7':
      case 'seven':
        return 7;
      case '8':
      case 'eight':
        return 8;
      default:
        return int.tryParse(s) ?? 0;
    }
  }

  DprAttackAction? _parseCreatureActionToDpr(
    CreatureAction action, {
    bool isLegendary = false,
    List<DprAttackAction> availableRegularAttacks = const [],
  }) {
    final descLower = action.description.toLowerCase();
    final nameLower = action.name.toLowerCase();

    // Legendary action cost
    int legCost = 1;
    if (isLegendary && (nameLower.contains('costs 2') || descLower.contains('costs 2'))) {
      legCost = 2;
    } else if (isLegendary && (nameLower.contains('costs 3') || descLower.contains('costs 3'))) {
      legCost = 3;
    }

    // Recharge roll
    int? recharge;
    if (nameLower.contains('recharge 5') || descLower.contains('recharge 5')) {
      recharge = 5;
    } else if (nameLower.contains('recharge 6') || descLower.contains('recharge 6')) {
      recharge = 6;
    }

    // Saving throw DC & Ability
    int? sDc;
    String? sAbility;
    DprActionDeliveryType delivery = DprActionDeliveryType.attackRoll;

    final saveMatch = RegExp(
      r'DC\s*(\d+)\s*(Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma)?',
      caseSensitive: false,
    ).firstMatch(action.description);
    if (saveMatch != null) {
      sDc = int.tryParse(saveMatch.group(1) ?? '');
      final abRaw = saveMatch.group(2)?.toLowerCase();
      if (abRaw != null && abRaw.length >= 3) {
        sAbility = abRaw.substring(0, 3);
      }
    }

    int bonus = action.attackBonus ?? attackBonus;
    final bonusMatch = RegExp(r'([+-]\s*\d+)\s+to\s+hit', caseSensitive: false)
        .firstMatch(action.description);
    if (bonusMatch != null) {
      final parsed = int.tryParse(bonusMatch.group(1)!.replaceAll(' ', ''));
      if (parsed != null) bonus = parsed;
    } else if (sDc != null) {
      delivery = DprActionDeliveryType.savingThrow;
    }

    // AoE detection
    final isAoeAction = descLower.contains('cone') ||
        descLower.contains('line') ||
        descLower.contains('sphere') ||
        descLower.contains('cube') ||
        descLower.contains('radius') ||
        descLower.contains('each creature') ||
        descLower.contains('all creatures') ||
        descLower.contains('breath weapon');

    final halfOnSave = descLower.contains('half as much') || !descLower.contains('taking no damage');

    int dCount = 0;
    int dSides = 0;
    int dBonus = 0;
    String dType = damageType;

    int secDCount = 0;
    int secDSides = 0;
    String? secDType;

    // 1. Parse primary damage dice & bonus
    final primarySource = action.hitDamage != null && action.hitDamage!.isNotEmpty
        ? action.hitDamage!
        : action.description;

    final primaryMatch = RegExp(
      r'(\d+)\s*d\s*(\d+)(?:\s*([+-])\s*(\d+))?',
      caseSensitive: false,
    ).firstMatch(primarySource);

    if (primaryMatch != null) {
      dCount = int.tryParse(primaryMatch.group(1) ?? '') ?? 0;
      dSides = int.tryParse(primaryMatch.group(2) ?? '') ?? 0;
      if (primaryMatch.group(4) != null) {
        final sign = primaryMatch.group(3) == '-' ? -1 : 1;
        dBonus = sign * (int.tryParse(primaryMatch.group(4)!) ?? 0);
      } else {
        dBonus = 0;
      }
    } else {
      final flatMatch = RegExp(r'Hit:\s*(\d+)|taking\s*(\d+)', caseSensitive: false)
          .firstMatch(action.description);
      if (flatMatch != null) {
        final numStr = flatMatch.group(1) ?? flatMatch.group(2);
        dBonus = int.tryParse(numStr ?? '') ?? 0;
      }
    }

    // 2. Parse primary damage type
    final typeMatch = RegExp(
      r'(bludgeoning|piercing|slashing|fire|cold|lightning|thunder|acid|poison|necrotic|radiant|force|psychic)\s+damage',
      caseSensitive: false,
    ).firstMatch(action.description);
    if (typeMatch != null) {
      dType = typeMatch.group(1)!.toLowerCase();
    }

    // 3. Parse secondary / rider damage dice
    final secMatch = RegExp(
      r'(?:plus|and(?:\s+the\s+target)?\s+takes?|extra)\s*(?:\d+)?\s*\(?(\d+)\s*d\s*(\d+)\)?(?:\s*([+-]\s*\d+))?\s*(\w+)?\s*damage',
      caseSensitive: false,
    ).firstMatch(action.description);

    if (secMatch != null) {
      secDCount = int.tryParse(secMatch.group(1) ?? '') ?? 0;
      secDSides = int.tryParse(secMatch.group(2) ?? '') ?? 0;
      final rawSecType = secMatch.group(4)?.toLowerCase();
      if (rawSecType != null &&
          const [
            'bludgeoning',
            'piercing',
            'slashing',
            'fire',
            'cold',
            'lightning',
            'thunder',
            'acid',
            'poison',
            'necrotic',
            'radiant',
            'force',
            'psychic'
          ].contains(rawSecType)) {
        secDType = rawSecType;
      }
    }

    // 4. If this is a Legendary Action that references an existing regular attack, inherit its damage stats!
    if (isLegendary && availableRegularAttacks.isNotEmpty) {
      final hasOwnDamage = dCount > 0 || dBonus > 0 || secDCount > 0 || delivery == DprActionDeliveryType.savingThrow;

      if (!hasOwnDamage || descLower.contains('makes a ') || descLower.contains('makes one ') || descLower.contains('uses its ')) {
        DprAttackAction? referencedAttack;

        // Clean action name (e.g. "Tail Attack" -> "tail", "Bite (Costs 2 Actions)" -> "bite")
        final cleanName = nameLower
            .replaceAll(RegExp(r'\(costs\s*\d+\s*actions?\)', caseSensitive: false), '')
            .replaceAll('attack', '')
            .replaceAll('swipe', '')
            .trim();

        // Check if cleanName matches any regular attack
        for (final reg in availableRegularAttacks) {
          final regName = reg.name.toLowerCase();
          if (cleanName.isNotEmpty && (regName == cleanName || regName.contains(cleanName) || cleanName.contains(regName))) {
            referencedAttack = reg;
            break;
          }
        }

        // If not matched by name, check description for "makes one/a [X] attack" or "uses its [X]"
        if (referencedAttack == null) {
          final descRefMatch = RegExp(
            r'(?:makes\s+(?:one|a|an)?\s+(?:melee\s+|ranged\s+|weapon\s+)?|uses\s+its\s+)([a-zA-Z\s]+?)(?:\s+attack|\.|\s+against)',
            caseSensitive: false,
          ).firstMatch(action.description);

          if (descRefMatch != null) {
            final targetWord = descRefMatch.group(1)!.toLowerCase().trim();
            for (final reg in availableRegularAttacks) {
              final regName = reg.name.toLowerCase();
              if (regName == targetWord || regName.contains(targetWord) || targetWord.contains(regName)) {
                referencedAttack = reg;
                break;
              }
            }
          }
        }

        // If "Attack" or "Weapon Attack", take the primary/highest damage regular attack
        if (referencedAttack == null && (cleanName == 'attack' || cleanName == 'weapon' || descLower.contains('makes one weapon attack') || descLower.contains('makes one attack'))) {
          referencedAttack = availableRegularAttacks.first;
        }

        if (referencedAttack != null) {
          bonus = referencedAttack.attackBonus;
          dCount = referencedAttack.diceCount;
          dSides = referencedAttack.diceSides;
          dBonus = referencedAttack.damageBonus;
          dType = referencedAttack.damageType;
          delivery = referencedAttack.deliveryType;
          sAbility = referencedAttack.saveAbility;
          sDc = referencedAttack.saveDc;
          secDCount = referencedAttack.secondaryDiceCount;
          secDSides = referencedAttack.secondaryDiceSides;
          secDType = referencedAttack.secondaryDamageType;
        }
      }
    }

    final reachMatch = RegExp(r'reach\s*(\d+)\s*ft', caseSensitive: false).firstMatch(action.description);
    final actionReach = reachMatch != null ? (int.tryParse(reachMatch.group(1) ?? '') ?? 5) : 5;

    return DprAttackAction(
      id: '${id}_${isLegendary ? "leg_" : ""}${action.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}',
      name: action.name,
      attackBonus: bonus,
      diceCount: dCount,
      diceSides: dSides,
      damageBonus: dBonus,
      damageType: dType,
      deliveryType: delivery,
      saveAbility: sAbility,
      saveDc: sDc,
      halfDamageOnSave: halfOnSave,
      isAoe: isAoeAction,
      targetCount: isAoeAction ? 2 : 1,
      rechargeRoll: recharge,
      isLegendaryAction: isLegendary,
      legendaryCost: legCost,
      secondaryDiceCount: secDCount,
      secondaryDiceSides: secDSides,
      secondaryDamageType: secDType,
      attacksPerRound: 1,
      reachInFeet: actionReach,
    );
  }
}


