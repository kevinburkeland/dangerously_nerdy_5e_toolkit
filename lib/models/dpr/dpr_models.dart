import 'dart:math' as math;
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

/// Catalog item representing a base weapon or magic weapon to easily equip or customize.
class DprWeaponPreset {
  final String id;
  final String name;
  final String category; // e.g. "Standard Melee", "Standard Ranged", "Magic Weapon"
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
  });

  static const List<DprWeaponPreset> allPresets = [
    // Standard Melee
    DprWeaponPreset(id: 'greatsword', name: 'Greatsword (2d6 Slashing)', category: 'Standard Melee', diceCount: 2, diceSides: 6, damageType: 'slashing', defaultMastery: WeaponMastery.graze, isHeavy: true),
    DprWeaponPreset(id: 'greataxe', name: 'Greataxe (1d12 Slashing)', category: 'Standard Melee', diceCount: 1, diceSides: 12, damageType: 'slashing', defaultMastery: WeaponMastery.none, isHeavy: true),
    DprWeaponPreset(id: 'maul', name: 'Maul (2d6 Bludgeoning)', category: 'Standard Melee', diceCount: 2, diceSides: 6, damageType: 'bludgeoning', defaultMastery: WeaponMastery.topple, isHeavy: true),
    DprWeaponPreset(id: 'longsword', name: 'Longsword (1d8 Slashing)', category: 'Standard Melee', diceCount: 1, diceSides: 8, damageType: 'slashing', defaultMastery: WeaponMastery.none),
    DprWeaponPreset(id: 'longsword_2h', name: 'Longsword (2-Handed 1d10)', category: 'Standard Melee', diceCount: 1, diceSides: 10, damageType: 'slashing', defaultMastery: WeaponMastery.none),
    DprWeaponPreset(id: 'glaive', name: 'Glaive / Halberd (1d10 Slashing)', category: 'Standard Melee', diceCount: 1, diceSides: 10, damageType: 'slashing', defaultMastery: WeaponMastery.graze, isHeavy: true),
    DprWeaponPreset(id: 'polearm_butt', name: 'Polearm Master Butt-End (1d4)', category: 'Standard Melee', diceCount: 1, diceSides: 4, damageType: 'bludgeoning', defaultMastery: WeaponMastery.none),
    DprWeaponPreset(id: 'rapier', name: 'Rapier (1d8 Piercing)', category: 'Standard Melee', diceCount: 1, diceSides: 8, damageType: 'piercing', defaultMastery: WeaponMastery.vex),
    DprWeaponPreset(id: 'shortsword', name: 'Shortsword (1d6 Piercing)', category: 'Standard Melee', diceCount: 1, diceSides: 6, damageType: 'piercing', defaultMastery: WeaponMastery.vex),
    DprWeaponPreset(id: 'scimitar', name: 'Scimitar / Dagger (1d6 / 1d4)', category: 'Standard Melee', diceCount: 1, diceSides: 6, damageType: 'slashing', defaultMastery: WeaponMastery.nick),
    DprWeaponPreset(id: 'unarmed', name: 'Unarmed Strike (1d6 Monk)', category: 'Standard Melee', diceCount: 1, diceSides: 6, damageType: 'bludgeoning', defaultMastery: WeaponMastery.none),

    // Standard Ranged
    DprWeaponPreset(id: 'hand_crossbow', name: 'Hand Crossbow (1d6 Piercing)', category: 'Standard Ranged', diceCount: 1, diceSides: 6, damageType: 'piercing', defaultMastery: WeaponMastery.vex, isRanged: true),
    DprWeaponPreset(id: 'heavy_crossbow', name: 'Heavy Crossbow (1d10 Piercing)', category: 'Standard Ranged', diceCount: 1, diceSides: 10, damageType: 'piercing', defaultMastery: WeaponMastery.none, isRanged: true, isHeavy: true),
    DprWeaponPreset(id: 'longbow', name: 'Longbow (1d8 Piercing)', category: 'Standard Ranged', diceCount: 1, diceSides: 8, damageType: 'piercing', defaultMastery: WeaponMastery.none, isRanged: true, isHeavy: true),
    DprWeaponPreset(id: 'shortbow', name: 'Shortbow (1d6 Piercing)', category: 'Standard Ranged', diceCount: 1, diceSides: 6, damageType: 'piercing', defaultMastery: WeaponMastery.vex, isRanged: true),

    // Damage Cantrips
    DprWeaponPreset(id: 'fire_bolt_1', name: 'Fire Bolt (1d10 Fire, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'fire_bolt_2', name: 'Fire Bolt (2d10 Fire, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 10, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'eldritch_blast_1', name: 'Eldritch Blast (1d10 Force, 1 Beam)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'force', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'eldritch_blast_2', name: 'Eldritch Blast (2x 1d10 Force, Lvl 5+)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'force', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'ray_of_frost_1', name: 'Ray of Frost (1d8 Cold, Lvl 1-4)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'cold', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'ray_of_frost_2', name: 'Ray of Frost (2d8 Cold, Lvl 5-10)', category: 'Damage Cantrip', diceCount: 2, diceSides: 8, damageType: 'cold', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'toll_the_dead_1', name: 'Toll the Dead (1d12 Necrotic)', category: 'Damage Cantrip', diceCount: 1, diceSides: 12, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'toll_the_dead_2', name: 'Toll the Dead (2d12 Necrotic, Lvl 5+)', category: 'Damage Cantrip', diceCount: 2, diceSides: 12, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'sacred_flame_1', name: 'Sacred Flame (1d8 Radiant)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'radiant', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'sacred_flame_2', name: 'Sacred Flame (2d8 Radiant, Lvl 5+)', category: 'Damage Cantrip', diceCount: 2, diceSides: 8, damageType: 'radiant', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'shocking_grasp_1', name: 'Shocking Grasp (1d8 Lightning Melee)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'lightning', isCantrip: true),
    DprWeaponPreset(id: 'shocking_grasp_2', name: 'Shocking Grasp (2d8 Lightning, Lvl 5+)', category: 'Damage Cantrip', diceCount: 2, diceSides: 8, damageType: 'lightning', isCantrip: true),
    DprWeaponPreset(id: 'poison_spray_1', name: 'Poison Spray (1d12 Poison)', category: 'Damage Cantrip', diceCount: 1, diceSides: 12, damageType: 'poison', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'poison_spray_2', name: 'Poison Spray (2d12 Poison, Lvl 5+)', category: 'Damage Cantrip', diceCount: 2, diceSides: 12, damageType: 'poison', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'vicious_mockery_1', name: 'Vicious Mockery (1d4 Psychic)', category: 'Damage Cantrip', diceCount: 1, diceSides: 4, damageType: 'psychic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'mind_sliver_1', name: 'Mind Sliver (1d6 Psychic)', category: 'Damage Cantrip', diceCount: 1, diceSides: 6, damageType: 'psychic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'chill_touch_1', name: 'Chill Touch (1d8 Necrotic)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'necrotic', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'produce_flame_1', name: 'Produce Flame (1d8 Fire)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'fire', isRanged: true, isCantrip: true),
    DprWeaponPreset(id: 'primal_savagery_1', name: 'Primal Savagery (1d10 Acid)', category: 'Damage Cantrip', diceCount: 1, diceSides: 10, damageType: 'acid', isCantrip: true),
    DprWeaponPreset(id: 'booming_blade', name: 'Booming Blade (1d8 Weapon + 1d8 Thunder)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 1, secondaryDiceSides: 8, secondaryDamageType: 'thunder', isCantrip: true),
    DprWeaponPreset(id: 'green_flame_blade', name: 'Green-Flame Blade (1d8 Weapon + 1d8 Fire)', category: 'Damage Cantrip', diceCount: 1, diceSides: 8, damageType: 'slashing', secondaryDiceCount: 1, secondaryDiceSides: 8, secondaryDamageType: 'fire', isCantrip: true),

    // Magic Weapons
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

/// Represents a single weapon attack or action profile in a combatant's turn.
class DprAttackAction {
  final String id;
  final String name;
  final int attackBonus;
  final int diceCount;
  final int diceSides;
  final int damageBonus;
  final String damageType;

  // Secondary / Rider Damage (e.g. Hunter's Mark, Smite, Hex, Poison)
  final int secondaryDiceCount;
  final int secondaryDiceSides;
  final int secondaryDamageBonus;
  final String? secondaryDamageType;

  // Feats, Invocations & Fighting Styles
  final GwmMode gwmMode;
  final GwfVersion gwfVersion;
  final bool hasDueling;          // +2 damage on 1H melee
  final bool hasArchery;          // +2 to-hit on ranged
  final bool hasThrownWeapon;     // +2 damage on thrown
  final bool isOffhandWithoutTwf; // no ability mod to damage
  final bool hasAgonizingBlast;   // adds ability modifier to cantrip / Eldritch Blast damage
  final int abilityModForAgonizing;

  // Weapon Mastery
  final WeaponMastery weaponMastery;
  final int abilityModForGraze;   // Used if Graze mastery is active

  // Critical Hit Modifiers
  final int critThreshold;        // 20 for standard, 19 for Champion, 18 for Superior
  final int extraCritDiceCount;   // +1 for Half-Orc Savage Attacks / Brutal Critical
  final int extraCritDiceSides;

  // Buffs / Precision Modifiers
  final int attackBuffDiceSides;  // e.g. 4 for Bless (+1d4), 6/8/10/12 for Bardic/Precision
  final int attackBuffFlat;       // e.g. +1/+2/+3 magic weapon or flat buff

  // Attack Count & Action Economy
  final int attacksPerRound;
  final bool isBonusActionAttack;

  const DprAttackAction({
    required this.id,
    required this.name,
    required this.attackBonus,
    required this.diceCount,
    required this.diceSides,
    required this.damageBonus,
    this.damageType = 'slashing',
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
    this.weaponMastery = WeaponMastery.none,
    this.abilityModForGraze = 0,
    this.critThreshold = 20,
    this.extraCritDiceCount = 0,
    this.extraCritDiceSides = 0,
    this.attackBuffDiceSides = 0,
    this.attackBuffFlat = 0,
    this.attacksPerRound = 1,
    this.isBonusActionAttack = false,
  });

  DprAttackAction copyWith({
    String? id,
    String? name,
    int? attackBonus,
    int? diceCount,
    int? diceSides,
    int? damageBonus,
    String? damageType,
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
    WeaponMastery? weaponMastery,
    int? abilityModForGraze,
    int? critThreshold,
    int? extraCritDiceCount,
    int? extraCritDiceSides,
    int? attackBuffDiceSides,
    int? attackBuffFlat,
    int? attacksPerRound,
    bool? isBonusActionAttack,
  }) {
    return DprAttackAction(
      id: id ?? this.id,
      name: name ?? this.name,
      attackBonus: attackBonus ?? this.attackBonus,
      diceCount: diceCount ?? this.diceCount,
      diceSides: diceSides ?? this.diceSides,
      damageBonus: damageBonus ?? this.damageBonus,
      damageType: damageType ?? this.damageType,
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
      weaponMastery: weaponMastery ?? this.weaponMastery,
      abilityModForGraze: abilityModForGraze ?? this.abilityModForGraze,
      critThreshold: critThreshold ?? this.critThreshold,
      extraCritDiceCount: extraCritDiceCount ?? this.extraCritDiceCount,
      extraCritDiceSides: extraCritDiceSides ?? this.extraCritDiceSides,
      attackBuffDiceSides: attackBuffDiceSides ?? this.attackBuffDiceSides,
      attackBuffFlat: attackBuffFlat ?? this.attackBuffFlat,
      attacksPerRound: attacksPerRound ?? this.attacksPerRound,
      isBonusActionAttack: isBonusActionAttack ?? this.isBonusActionAttack,
    );
  }

  /// Formatted damage formula (e.g., "2d6 + 4 slashing + 1d6 fire").
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
    this.attacks = const [],
  });

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
