import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Weapons Catalog
/// Includes standard nonmagical weapons with 2024 masteries, specific named +1/+2/+3 weapon variants, and iconic magic weapons.
class SrdMagicWeapons {
  SrdMagicWeapons._();

  static const List<MagicItem> items = [
    // =========================================================================
    // 1. STANDARD NONMAGICAL WEAPONS (With 2024 Weapon Masteries)
    // =========================================================================
    MagicItem(
      id: 'weapon_longsword',
      name: 'Longsword',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '1d8 (1d10 Versatile) Slashing • 2024 Mastery: Sap'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d8 slashing (Versatile 1d10). Standard martial melee weapon.',
        description: 'Versatile martial sword designed for single or two-handed strikes.',
        properties: ['Damage: 1d8 slashing', 'Versatile (1d10)', 'Weight: 3 lbs', 'Cost: 15 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d8 slashing (Versatile 1d10). Weapon Mastery: Sap (disadvantage on target\'s next attack roll).',
        description: 'Martial versatile sword with the Sap mastery property.',
        masteryProperties: 'Sap: On hit, the target has Disadvantage on its next attack roll before the start of your next turn.',
        properties: ['Damage: 1d8 slashing', 'Versatile (1d10)', 'Mastery: Sap', 'Weight: 3 lbs', 'Cost: 15 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Sap Weapon Mastery property.',
      diffHighlights: ['2024: Sap imposes Disadvantage on target\'s next attack roll.'],
      tags: ['weapon', 'martial', 'melee', 'versatile', 'slashing', 'sap'],
    ),
    MagicItem(
      id: 'weapon_greatsword',
      name: 'Greatsword',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '2d6 Slashing (Heavy, Two-Handed) • 2024 Mastery: Graze'),
      ],
      rules2014: ItemEditionDetails(
        summary: '2d6 slashing (Heavy, Two-Handed). Massive martial blade delivering devastating blows.',
        description: 'Massive two-handed sword delivering high consistent damage.',
        properties: ['Damage: 2d6 slashing', 'Heavy, Two-Handed', 'Weight: 6 lbs', 'Cost: 50 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '2d6 slashing (Heavy, Two-Handed). Weapon Mastery: Graze (deal ability modifier damage on a miss).',
        description: 'Premier heavy martial sword with Graze mastery.',
        masteryProperties: 'Graze: If your attack roll misses, deal damage equal to the ability modifier you used for the attack.',
        properties: ['Damage: 2d6 slashing', 'Heavy, Two-Handed', 'Mastery: Graze', 'Weight: 6 lbs', 'Cost: 50 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Graze Weapon Mastery property.',
      diffHighlights: ['2024: Graze guarantees ability modifier damage on a miss.'],
      tags: ['weapon', 'martial', 'melee', 'heavy', 'two-handed', 'slashing', 'graze'],
    ),
    MagicItem(
      id: 'weapon_greataxe',
      name: 'Greataxe',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '1d12 Slashing (Heavy, Two-Handed) • 2024 Mastery: Cleave'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d12 slashing (Heavy, Two-Handed). High-variance barbarian favorite.',
        description: 'Heavy two-handed battle axe capable of shearing through armor.',
        properties: ['Damage: 1d12 slashing', 'Heavy, Two-Handed', 'Weight: 7 lbs', 'Cost: 30 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d12 slashing (Heavy, Two-Handed). Weapon Mastery: Cleave (extra attack on adjacent enemy on hit).',
        description: 'Heavy greataxe with Cleave mastery property.',
        masteryProperties: 'Cleave: Once per turn on hit, make an extra melee attack against a second creature within 5 ft of the first.',
        properties: ['Damage: 1d12 slashing', 'Heavy, Two-Handed', 'Mastery: Cleave', 'Weight: 7 lbs', 'Cost: 30 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Cleave Weapon Mastery property.',
      tags: ['weapon', 'martial', 'melee', 'heavy', 'two-handed', 'slashing', 'cleave'],
    ),
    MagicItem(
      id: 'weapon_dagger',
      name: 'Dagger',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '1d4 Piercing (Finesse, Light, Thrown 20/60) • 2024 Mastery: Nick'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d4 piercing (Finesse, Light, Thrown 20/60). Simple concealable weapon.',
        description: 'Small blade for stabbing or throwing.',
        properties: ['Damage: 1d4 piercing', 'Finesse, Light, Thrown (range 20/60)', 'Weight: 1 lb', 'Cost: 2 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d4 piercing. Weapon Mastery: Nick (extra offhand attack made as part of the Attack action without spending Bonus Action).',
        description: 'Finesse light blade with the Nick mastery property.',
        masteryProperties: 'Nick: Make the additional attack from Light property as part of the Attack action instead of a Bonus Action.',
        properties: ['Damage: 1d4 piercing', 'Finesse, Light, Thrown (range 20/60)', 'Mastery: Nick', 'Weight: 1 lb', 'Cost: 2 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Nick Weapon Mastery property.',
      tags: ['weapon', 'simple', 'melee', 'finesse', 'light', 'thrown', 'nick'],
    ),
    MagicItem(
      id: 'weapon_shortsword',
      name: 'Shortsword',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '1d6 Piercing (Finesse, Light) • 2024 Mastery: Vex'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d6 piercing (Finesse, Light). Martial blade for two-weapon fighting and agile combatants.',
        description: 'Compact sword suitable for dual-wielding.',
        properties: ['Damage: 1d6 piercing', 'Finesse, Light', 'Weight: 2 lbs', 'Cost: 10 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d6 piercing (Finesse, Light). Weapon Mastery: Vex (Advantage on next attack roll against target on hit).',
        description: 'Light martial blade with the Vex mastery property.',
        masteryProperties: 'Vex: On hit, gain Advantage on your next attack roll against that target before the end of your next turn.',
        properties: ['Damage: 1d6 piercing', 'Finesse, Light', 'Mastery: Vex', 'Weight: 2 lbs', 'Cost: 10 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Vex Weapon Mastery property.',
      tags: ['weapon', 'martial', 'melee', 'finesse', 'light', 'vex'],
    ),
    MagicItem(
      id: 'weapon_rapier',
      name: 'Rapier',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '1d8 Piercing (Finesse) • 2024 Mastery: Vex'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d8 piercing (Finesse). The highest damage single-handed finesse martial weapon.',
        description: 'Slender fencing sword designed for thrusting attacks.',
        properties: ['Damage: 1d8 piercing', 'Finesse', 'Weight: 2 lbs', 'Cost: 25 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d8 piercing (Finesse). Weapon Mastery: Vex (Advantage on next attack roll against target on hit).',
        description: 'Premier finesse thrusting sword with Vex mastery.',
        masteryProperties: 'Vex: On hit, gain Advantage on your next attack roll against that target.',
        properties: ['Damage: 1d8 piercing', 'Finesse', 'Mastery: Vex', 'Weight: 2 lbs', 'Cost: 25 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Vex Weapon Mastery property.',
      tags: ['weapon', 'martial', 'melee', 'finesse', 'vex'],
    ),
    MagicItem(
      id: 'weapon_scimitar',
      name: 'Scimitar',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '1d6 Slashing (Finesse, Light) • 2024 Mastery: Nick'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d6 slashing (Finesse, Light). Curved martial blade for nimble dual-wielders.',
        description: 'Curved sword favored by dervishes, rangers, and rogues.',
        properties: ['Damage: 1d6 slashing', 'Finesse, Light', 'Weight: 3 lbs', 'Cost: 25 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d6 slashing (Finesse, Light). Weapon Mastery: Nick (extra offhand attack without Bonus Action cost).',
        description: 'Curved light blade with Nick mastery.',
        masteryProperties: 'Nick: Make the additional Light weapon attack as part of the Attack action.',
        properties: ['Damage: 1d6 slashing', 'Finesse, Light', 'Mastery: Nick', 'Weight: 3 lbs', 'Cost: 25 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Nick Weapon Mastery property.',
      tags: ['weapon', 'martial', 'melee', 'finesse', 'light', 'nick'],
    ),
    MagicItem(
      id: 'weapon_warhammer',
      name: 'Warhammer',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.bludgeoning,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '1d8 (1d10 Versatile) Bludgeoning • 2024 Mastery: Push'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d8 bludgeoning (Versatile 1d10). Solid martial blunt weapon.',
        description: 'Forged steel war hammer with spike and head for crushing blows.',
        properties: ['Damage: 1d8 bludgeoning', 'Versatile (1d10)', 'Weight: 2 lbs', 'Cost: 15 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d8 bludgeoning (Versatile 1d10). Weapon Mastery: Push (push target up to 10 ft away on hit).',
        description: 'Versatile martial warhammer with Push mastery.',
        masteryProperties: 'Push: On hit, push the target up to 10 feet away from you if it is Large or smaller.',
        properties: ['Damage: 1d8 bludgeoning', 'Versatile (1d10)', 'Mastery: Push', 'Weight: 2 lbs', 'Cost: 15 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Push Weapon Mastery property.',
      tags: ['weapon', 'martial', 'melee', 'versatile', 'bludgeoning', 'push'],
    ),
    MagicItem(
      id: 'weapon_maul',
      name: 'Maul',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.bludgeoning,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '2d6 Bludgeoning (Heavy, Two-Handed) • 2024 Mastery: Topple'),
      ],
      rules2014: ItemEditionDetails(
        summary: '2d6 bludgeoning (Heavy, Two-Handed). Heavy two-handed sledge designed to crush heavy armor.',
        description: 'Heavy two-handed sledge delivering blunt impact.',
        properties: ['Damage: 2d6 bludgeoning', 'Heavy, Two-Handed', 'Weight: 10 lbs', 'Cost: 10 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '2d6 bludgeoning (Heavy, Two-Handed). Weapon Mastery: Topple (force CON save or knock target Prone).',
        description: 'Heavy martial maul with Topple mastery.',
        masteryProperties: 'Topple: On hit, force the creature to make a Constitution save (DC 8 + PB + ability mod) or fall Prone.',
        properties: ['Damage: 2d6 bludgeoning', 'Heavy, Two-Handed', 'Mastery: Topple', 'Weight: 10 lbs', 'Cost: 10 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Topple Weapon Mastery property.',
      tags: ['weapon', 'martial', 'melee', 'heavy', 'two-handed', 'topple'],
    ),
    MagicItem(
      id: 'weapon_halberd',
      name: 'Halberd',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '1d10 Slashing (Heavy, Reach, Two-Handed) • 2024 Mastery: Cleave'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d10 slashing (Heavy, Reach, Two-Handed). Polearm combining axe blade and spear point with 10 ft reach.',
        description: 'Polearm weapon with 10-foot reach.',
        properties: ['Damage: 1d10 slashing', 'Heavy, Reach, Two-Handed', 'Weight: 6 lbs', 'Cost: 20 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d10 slashing (Heavy, Reach, Two-Handed). Weapon Mastery: Cleave (extra attack on adjacent enemy on hit).',
        description: 'Polearm weapon with Cleave mastery and 10 ft reach.',
        masteryProperties: 'Cleave: Once per turn on hit, make an extra melee attack against a second creature within 5 ft of the first.',
        properties: ['Damage: 1d10 slashing', 'Heavy, Reach, Two-Handed', 'Mastery: Cleave', 'Weight: 6 lbs', 'Cost: 20 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Cleave Weapon Mastery property.',
      tags: ['weapon', 'martial', 'melee', 'reach', 'heavy', 'two-handed', 'cleave'],
    ),
    MagicItem(
      id: 'weapon_longbow',
      name: 'Longbow',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: '1d8 Piercing (Ammunition 150/600, Heavy, Two-Handed) • 2024 Mastery: Slow'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d8 piercing (Ammunition 150/600, Heavy, Two-Handed). Supreme long-range martial missile weapon.',
        description: 'Tall bow crafted of yew or composite wood.',
        properties: ['Damage: 1d8 piercing', 'Ammunition (range 150/600), Heavy, Two-Handed', 'Weight: 2 lbs', 'Cost: 50 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d8 piercing (Range 150/600). Weapon Mastery: Slow (reduce target speed by 10 ft on hit).',
        description: 'Longbow with Slow mastery property.',
        masteryProperties: 'Slow: On hit, reduce the target\'s speed by 10 feet until the start of your next turn.',
        properties: ['Damage: 1d8 piercing', 'Ammunition (range 150/600), Heavy, Two-Handed', 'Mastery: Slow', 'Weight: 2 lbs', 'Cost: 50 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Slow Weapon Mastery property.',
      tags: ['weapon', 'martial', 'ranged', 'heavy', 'two-handed', 'slow'],
    ),
    MagicItem(
      id: 'weapon_shortbow',
      name: 'Shortbow',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: '1d6 Piercing (Ammunition 80/320, Two-Handed) • 2024 Mastery: Vex'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d6 piercing (Ammunition 80/320, Two-Handed). Simple ranged bow.',
        description: 'Compact wooden bow for light skirmishing.',
        properties: ['Damage: 1d6 piercing', 'Ammunition (range 80/320), Two-Handed', 'Weight: 2 lbs', 'Cost: 25 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d6 piercing (Range 80/320). Weapon Mastery: Vex (Advantage on next attack roll against target on hit).',
        description: 'Shortbow with Vex mastery property.',
        masteryProperties: 'Vex: On hit, gain Advantage on your next attack roll against that target.',
        properties: ['Damage: 1d6 piercing', 'Ammunition (range 80/320), Two-Handed', 'Mastery: Vex', 'Weight: 2 lbs', 'Cost: 25 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Vex Weapon Mastery property.',
      tags: ['weapon', 'simple', 'ranged', 'two-handed', 'vex'],
    ),
    MagicItem(
      id: 'weapon_heavy_crossbow',
      name: 'Heavy Crossbow',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: '1d10 Piercing (Ammunition 100/400, Heavy, Loading, Two-Handed) • 2024 Mastery: Push'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d10 piercing (Ammunition 100/400, Heavy, Loading, Two-Handed). High-impact martial crossbow.',
        description: 'Powerful steel-limbed crossbow spanned with a windlass.',
        properties: ['Damage: 1d10 piercing', 'Ammunition (range 100/400), Heavy, Loading, Two-Handed', 'Weight: 18 lbs', 'Cost: 50 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d10 piercing. Weapon Mastery: Push (push target up to 10 ft away on hit).',
        description: 'Heavy crossbow with Push mastery.',
        masteryProperties: 'Push: On hit, push the target up to 10 feet away from you if it is Large or smaller.',
        properties: ['Damage: 1d10 piercing', 'Ammunition (range 100/400), Heavy, Loading, Two-Handed', 'Mastery: Push', 'Weight: 18 lbs', 'Cost: 50 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Push Weapon Mastery property.',
      tags: ['weapon', 'martial', 'ranged', 'heavy', 'loading', 'push'],
    ),
    MagicItem(
      id: 'weapon_hand_crossbow',
      name: 'Hand Crossbow',
      category: ItemCategory.weapon,
      rarity: ItemRarity.nonmagical,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: '1d6 Piercing (Ammunition 30/120, Light, Loading) • 2024 Mastery: Vex'),
      ],
      rules2014: ItemEditionDetails(
        summary: '1d6 piercing (Ammunition 30/120, Light, Loading). One-handed crossbow designed for Crossbow Expert feats.',
        description: 'Compact one-handed crossbow.',
        properties: ['Damage: 1d6 piercing', 'Ammunition (range 30/120), Light, Loading', 'Weight: 3 lbs', 'Cost: 75 gp'],
      ),
      rules2024: ItemEditionDetails(
        summary: '1d6 piercing. Weapon Mastery: Vex (Advantage on next attack roll against target on hit).',
        description: 'Hand crossbow with Vex mastery property.',
        masteryProperties: 'Vex: On hit, gain Advantage on your next attack roll against that target.',
        properties: ['Damage: 1d6 piercing', 'Ammunition (range 30/120), Light, Loading', 'Mastery: Vex', 'Weight: 3 lbs', 'Cost: 75 gp'],
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains the Vex Weapon Mastery property.',
      tags: ['weapon', 'martial', 'ranged', 'light', 'loading', 'vex'],
    ),

    // =========================================================================
    // 2. SPECIFIC NAMED MAGIC WEAPONS (+1, +2, +3)
    // =========================================================================
    MagicItem(
      id: 'longsword_plus_1',
      name: 'Longsword +1',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Attack & Damage • 1d8/1d10 Slashing'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls made with this magic longsword (1d8/1d10 Versatile).',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic longsword.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls. Weapon Mastery: Sap.',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic longsword. Compatible with the Sap mastery property.',
        activation: 'Passive',
        masteryProperties: 'Sap',
      ),
      tags: ['weapon', 'martial', 'melee', 'longsword', 'magic', 'plus 1'],
    ),
    MagicItem(
      id: 'longsword_plus_2',
      name: 'Longsword +2',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+2 Attack & Damage • 1d8/1d10 Slashing'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus to attack and damage rolls made with this magic longsword.',
        description: 'You have a +2 bonus to attack and damage rolls made with this magic longsword.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to attack and damage rolls. Weapon Mastery: Sap.',
        description: 'You have a +2 bonus to attack and damage rolls made with this magic longsword.',
        activation: 'Passive',
        masteryProperties: 'Sap',
      ),
      tags: ['weapon', 'martial', 'melee', 'longsword', 'magic', 'plus 2'],
    ),
    MagicItem(
      id: 'longsword_plus_3',
      name: 'Longsword +3',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+3 Attack & Damage • 1d8/1d10 Slashing'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 bonus to attack and damage rolls made with this magic longsword.',
        description: 'You have a +3 bonus to attack and damage rolls made with this magic longsword.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 bonus to attack and damage rolls. Weapon Mastery: Sap.',
        description: 'You have a +3 bonus to attack and damage rolls made with this magic longsword.',
        activation: 'Passive',
        masteryProperties: 'Sap',
      ),
      tags: ['weapon', 'martial', 'melee', 'longsword', 'magic', 'plus 3'],
    ),

    MagicItem(
      id: 'greatsword_plus_1',
      name: 'Greatsword +1',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Attack & Damage • 2d6 Slashing (Graze)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls made with this magic greatsword (2d6 Slashing, Heavy, Two-Handed).',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic greatsword.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls. Weapon Mastery: Graze.',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic greatsword. Compatible with Graze.',
        activation: 'Passive',
        masteryProperties: 'Graze',
      ),
      tags: ['weapon', 'martial', 'melee', 'greatsword', 'heavy', 'magic', 'plus 1'],
    ),
    MagicItem(
      id: 'greatsword_plus_2',
      name: 'Greatsword +2',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+2 Attack & Damage • 2d6 Slashing (Graze)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus to attack and damage rolls made with this magic greatsword.',
        description: 'You have a +2 bonus to attack and damage rolls made with this magic greatsword.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to attack and damage rolls. Weapon Mastery: Graze.',
        description: 'You have a +2 bonus to attack and damage rolls made with this magic greatsword.',
        activation: 'Passive',
        masteryProperties: 'Graze',
      ),
      tags: ['weapon', 'martial', 'melee', 'greatsword', 'heavy', 'magic', 'plus 2'],
    ),
    MagicItem(
      id: 'greatsword_plus_3',
      name: 'Greatsword +3',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+3 Attack & Damage • 2d6 Slashing (Graze)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 bonus to attack and damage rolls made with this magic greatsword.',
        description: 'You have a +3 bonus to attack and damage rolls made with this magic greatsword.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 bonus to attack and damage rolls. Weapon Mastery: Graze.',
        description: 'You have a +3 bonus to attack and damage rolls made with this magic greatsword.',
        activation: 'Passive',
        masteryProperties: 'Graze',
      ),
      tags: ['weapon', 'martial', 'melee', 'greatsword', 'heavy', 'magic', 'plus 3'],
    ),

    MagicItem(
      id: 'dagger_plus_1',
      name: 'Dagger +1',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Attack & Damage • 1d4 Piercing (Finesse, Light)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls made with this magic dagger.',
        description: '+1 bonus to attack and damage rolls made with this magic dagger.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls. Weapon Mastery: Nick.',
        description: '+1 bonus to attack and damage rolls made with this magic dagger.',
        activation: 'Passive',
        masteryProperties: 'Nick',
      ),
      tags: ['weapon', 'simple', 'melee', 'dagger', 'finesse', 'light', 'magic', 'plus 1'],
    ),
    MagicItem(
      id: 'rapier_plus_1',
      name: 'Rapier +1',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Attack & Damage • 1d8 Piercing (Finesse)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls made with this magic rapier.',
        description: '+1 bonus to attack and damage rolls made with this magic rapier.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls. Weapon Mastery: Vex.',
        description: '+1 bonus to attack and damage rolls made with this magic rapier.',
        activation: 'Passive',
        masteryProperties: 'Vex',
      ),
      tags: ['weapon', 'martial', 'melee', 'rapier', 'finesse', 'magic', 'plus 1'],
    ),
    MagicItem(
      id: 'rapier_plus_2',
      name: 'Rapier +2',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+2 Attack & Damage • 1d8 Piercing (Finesse)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus to attack and damage rolls made with this magic rapier.',
        description: '+2 bonus to attack and damage rolls made with this magic rapier.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to attack and damage rolls. Weapon Mastery: Vex.',
        description: '+2 bonus to attack and damage rolls made with this magic rapier.',
        activation: 'Passive',
        masteryProperties: 'Vex',
      ),
      tags: ['weapon', 'martial', 'melee', 'rapier', 'finesse', 'magic', 'plus 2'],
    ),

    MagicItem(
      id: 'greataxe_plus_1',
      name: 'Greataxe +1',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Attack & Damage • 1d12 Slashing (Cleave)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls made with this magic greataxe (1d12 Slashing, Heavy, Two-Handed).',
        description: '+1 bonus to attack and damage rolls made with this magic greataxe.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls. Weapon Mastery: Cleave.',
        description: '+1 bonus to attack and damage rolls made with this magic greataxe.',
        activation: 'Passive',
        masteryProperties: 'Cleave',
      ),
      tags: ['weapon', 'martial', 'melee', 'greataxe', 'heavy', 'magic', 'plus 1'],
    ),
    MagicItem(
      id: 'longbow_plus_1',
      name: 'Longbow +1',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: '+1 Attack & Damage • 1d8 Piercing (Range 150/600, Slow)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls made with this magic longbow.',
        description: '+1 bonus to attack and damage rolls made with this magic longbow.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls. Weapon Mastery: Slow.',
        description: '+1 bonus to attack and damage rolls made with this magic longbow.',
        activation: 'Passive',
        masteryProperties: 'Slow',
      ),
      tags: ['weapon', 'martial', 'ranged', 'longbow', 'magic', 'plus 1'],
    ),
    MagicItem(
      id: 'longbow_plus_2',
      name: 'Longbow +2',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: '+2 Attack & Damage • 1d8 Piercing (Range 150/600, Slow)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus to attack and damage rolls made with this magic longbow.',
        description: '+2 bonus to attack and damage rolls made with this magic longbow.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to attack and damage rolls. Weapon Mastery: Slow.',
        description: '+2 bonus to attack and damage rolls made with this magic longbow.',
        activation: 'Passive',
        masteryProperties: 'Slow',
      ),
      tags: ['weapon', 'martial', 'ranged', 'longbow', 'magic', 'plus 2'],
    ),
    MagicItem(
      id: 'heavy_crossbow_plus_1',
      name: 'Heavy Crossbow +1',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: '+1 Attack & Damage • 1d10 Piercing (Push)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls made with this magic heavy crossbow.',
        description: '+1 bonus to attack and damage rolls made with this magic heavy crossbow.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to attack and damage rolls. Weapon Mastery: Push.',
        description: '+1 bonus to attack and damage rolls made with this magic heavy crossbow.',
        activation: 'Passive',
        masteryProperties: 'Push',
      ),
      tags: ['weapon', 'martial', 'ranged', 'heavy crossbow', 'magic', 'plus 1'],
    ),

    // =========================================================================
    // 3. GENERIC MAGIC WEAPONS (+1, +2, +3)
    // =========================================================================
    MagicItem(
      id: 'item_weapon_plus_1',
      name: 'Weapon +1',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Attack & Damage'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +1 bonus to attack and damage rolls made with this magic weapon.',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic weapon.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +1 bonus to attack and damage rolls made with this magic weapon and can utilize weapon mastery.',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic weapon. If you have the Weapon Mastery feature, you can utilize the mastery property of this weapon type.',
        activation: 'Passive',
        masteryProperties: 'Eligible for Weapon Mastery properties',
      ),
      isChangedIn2024: true,
      diffSummary: 'Interacts with 2024 Weapon Mastery properties.',
      diffHighlights: [
        '2024: Integrates with weapon mastery properties (Slow, Vex, Nick, Push, Topple, Sap, Cleave, Graze).',
      ],
      tags: ['weapon', 'bonus', 'simple', 'martial'],
    ),
    MagicItem(
      id: 'item_weapon_plus_2',
      name: 'Weapon +2',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+2 Attack & Damage'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +2 bonus to attack and damage rolls made with this magic weapon.',
        description: 'You have a +2 bonus to attack and damage rolls made with this magic weapon.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +2 bonus to attack and damage rolls made with this magic weapon and weapon mastery integration.',
        description: 'You have a +2 bonus to attack and damage rolls made with this magic weapon. Interacts with the 2024 Weapon Mastery system.',
        activation: 'Passive',
        masteryProperties: 'Eligible for Weapon Mastery properties',
      ),
      isChangedIn2024: true,
      diffSummary: 'Interacts with 2024 Weapon Mastery properties.',
      diffHighlights: [
        '2024: Integrates with weapon mastery properties.',
      ],
      tags: ['weapon', 'bonus', 'simple', 'martial'],
    ),
    MagicItem(
      id: 'item_weapon_plus_3',
      name: 'Weapon +3',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+3 Attack & Damage'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +3 bonus to attack and damage rolls made with this magic weapon.',
        description: 'You have a +3 bonus to attack and damage rolls made with this magic weapon.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +3 bonus to attack and damage rolls made with this magic weapon and weapon mastery integration.',
        description: 'You have a +3 bonus to attack and damage rolls made with this magic weapon. Interacts with the 2024 Weapon Mastery system.',
        activation: 'Passive',
        masteryProperties: 'Eligible for Weapon Mastery properties',
      ),
      isChangedIn2024: true,
      diffSummary: 'Interacts with 2024 Weapon Mastery properties.',
      diffHighlights: [
        '2024: Integrates with weapon mastery properties.',
      ],
      tags: ['weapon', 'bonus', 'simple', 'martial'],
    ),

    // =========================================================================
    // 4. ICONIC SRD MAGIC WEAPONS
    // =========================================================================
    MagicItem(
      id: 'item_flame_tongue',
      name: 'Flame Tongue',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Bonus Action: +2d6 Fire Damage on Hit • Bright Light 40 ft / Dim 40 ft'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Bonus action to ignite: deals extra 2d6 fire damage on hit and sheds bright light in a 40-foot radius.',
        description: 'You can use a bonus action to speak this magic sword\'s command word, causing flames to erupt from the blade. These flames shed bright light in a 40-foot radius and dim light for an additional 40 feet. While the sword is ablaze, it deals an extra 2d6 fire damage to any target it hits.',
        activation: '1 Bonus Action / Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus action to ignite: deals extra 2d6 fire damage on hit and sheds bright light.',
        description: 'Bonus action to speak command word, dealing +2d6 fire damage on hits while illuminated.',
        activation: '1 Bonus Action / Passive',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'sword', 'fire', 'flame', 'damage rider'],
    ),
    MagicItem(
      id: 'item_frost_brand',
      name: 'Frost Brand',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      damageAccent: DamageAccent.cold,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1d6 Cold Damage on Hit, Fire Resistance & Reaction: Extinguish Nonmagical Flames 30 ft'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Deals extra 1d6 cold damage on hit, grants resistance to fire damage, and extinguishes nonmagical fires within 30 feet as an action.',
        description: 'When you hit with an attack using this magic sword, the target takes an extra 1d6 cold damage. In addition, while you hold the sword, you have resistance to fire damage. In freezing temperatures, the blade sheds bright light in a 10-foot radius. As an action, you can extinguish all nonmagical fires within 30 feet of you.',
        activation: 'Passive / 1 Action (Extinguish)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Deals extra 1d6 cold damage, grants Fire Resistance, and extinguishes flames in 30 ft.',
        description: 'Provides +1d6 cold damage, Fire Resistance, and action to snuff nonmagical fires.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'sword', 'cold', 'frost', 'fire resistance'],
    ),
    MagicItem(
      id: 'item_sun_blade',
      name: 'Sun Blade',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+2 Attack & Damage, 1d8 Radiant Damage (Finesse Longsword) • +1d8 vs Undead'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 finesse longsword of pure radiant sunlight. Deals radiant damage instead of slashing, +1d8 extra radiant damage vs undead, and sheds sunlight.',
        description: 'This item appears to be a longsword hilt. While grasping the hilt, you can use a bonus action to cause a blade of pure radiance to spring into existence. The sword has the finesse property. If you are proficient with shortswords or longswords, you are proficient with the sun blade. You gain a +2 bonus to attack and damage rolls made with this weapon, which deals radiant damage instead of slashing damage. When you hit an undead with it, that target takes an extra 1d8 radiant damage.',
        activation: '1 Bonus Action / Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 radiant blade with finesse property; extra 1d8 radiant vs undead.',
        description: 'Blade of pure sunlight dealing radiant damage with finesse, +1d8 radiant vs undead.',
        activation: '1 Bonus Action / Passive',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'sword', 'radiant', 'sunlight', 'undead', 'finesse'],
    ),
    MagicItem(
      id: 'item_dragon_slayer',
      name: 'Dragon Slayer',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Attack & Damage • +3d6 Extra Damage vs Dragons'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 weapon. When you hit a dragon with this weapon, the dragon takes an extra 3d6 damage of the weapon\'s type.',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic weapon. When you hit a dragon with this weapon, the dragon takes an extra 3d6 damage of the weapon\'s type.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 weapon; deals extra 3d6 damage against dragons.',
        description: '+1 weapon dealing +3d6 extra weapon damage against creatures of the Dragon type.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'sword', 'dragon', 'slayer'],
    ),
    MagicItem(
      id: 'item_giant_slayer',
      name: 'Giant Slayer',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Attack & Damage • +2d6 vs Giants & DC 15 STR Save or Fall Prone'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 weapon dealing extra 2d6 damage to giants and forcing a DC 15 Strength save or be knocked prone.',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic weapon. When you hit a giant with it, the giant takes an extra 2d6 damage of the weapon\'s type and must succeed on a DC 15 Strength saving throw or fall prone.',
        activation: 'Passive / On Hit Save',
        savingThrowDc: 'DC 15 Strength',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 weapon dealing +2d6 to giants and DC 15 Strength save or prone.',
        description: '+1 weapon dealing +2d6 damage against giants with prone knockdown.',
        activation: 'Passive',
        savingThrowDc: 'DC 15 Strength',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'giant', 'slayer', 'knockdown', 'prone'],
    ),
    MagicItem(
      id: 'item_holy_avenger',
      name: 'Holy Avenger',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      attunementRequirement: 'by a Paladin',
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+3 Attack & Damage • +2d10 Radiant vs Fiends/Undead • 10–30 ft Magic Resistance Aura'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 weapon (Paladin attunement). Extra 2d10 radiant damage against fiends and undead. Emits a 10-foot aura (30 ft at level 17) granting advantage on saving throws against spells and magical effects.',
        description: 'You gain a +3 bonus to attack and damage rolls made with this magic weapon. When you hit a fiend or an undead with it, that creature takes an extra 2d10 radiant damage. While you hold the drawn sword, it creates an aura in a 10-foot radius around you. You and all creatures friendly to you in the aura have advantage on saving throws against spells and other magical effects. If you have 17 or more levels in the paladin class, the radius of the aura increases to 30 feet.',
        activation: 'Passive / Continuous Aura',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 weapon (Paladin). Extra 2d10 radiant damage against fiends/undead; 10/30 ft aura granting Advantage on saves vs spells.',
        description: '+3 weapon dealing +2d10 radiant vs fiends and undead with magic resistance aura for allies.',
        activation: 'Passive / Continuous Aura',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'paladin', 'holy', 'radiant', 'magic resistance', 'legendary'],
    ),
    MagicItem(
      id: 'item_dagger_of_venom',
      name: 'Dagger of Venom',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.poison,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Dagger • Action: Coat in Poison (2d10 Poison & Poisoned Condition, DC 15 CON Save)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 dagger. Action: coat the blade in black venom (1/day). Next hit within 1 min deals 2d10 poison damage and inflicts poisoned condition on DC 15 Con save.',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. You can use an action to cause thick, black poison to coat the blade. The poison remains for 1 minute or until an attack using this weapon hits a creature. That creature must succeed on a DC 15 Constitution saving throw or take 2d10 poison damage and become poisoned for 1 minute.',
        activation: '1 Action (1/Day)',
        savingThrowDc: 'DC 15 Constitution',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 dagger; Action to coat in poison dealing 2d10 poison and Poisoned condition on DC 15 Con save.',
        description: '+1 dagger with daily poison coating for burst damage and status debuff.',
        activation: '1 Action (1/Day)',
        savingThrowDc: 'DC 15 Constitution',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'dagger', 'poison', 'finesse', 'debuff'],
    ),
    MagicItem(
      id: 'item_oathbow',
      name: 'Oathbow',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      damageAccent: DamageAccent.piercing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: 'Sworn Enemy: Advantage on Attack Rolls, Extra 3d6 Piercing, Ignores Partial Cover'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Whisper command to swear a sworn enemy: gain advantage on attacks against sworn enemy, deal extra 3d6 piercing damage, and ignore non-full cover.',
        description: 'When you nock an arrow on this bow, it whispers in Elvish, "Swift defeat to my enemies." When you use this weapon to make a ranged attack, you can say, "Swift death to you who have wronged me." The target of your attack becomes your sworn enemy until it dies or until dawn seven days later. You have advantage on attack rolls against it, deal an extra 3d6 piercing damage on hit, and ignore light and medium cover.',
        activation: 'On Attack Command Word',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sworn enemy mechanic: Advantage on attacks, +3d6 piercing damage, ignores cover.',
        description: 'Elven longbow designed for hunting sworn targets with persistent Advantage and bonus damage.',
        activation: 'On Attack Command Word',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'bow', 'ranged', 'oath', 'advantage', 'cover'],
    ),
    MagicItem(
      id: 'item_vorpal_sword',
      name: 'Vorpal Sword',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      damageAccent: DamageAccent.slashing,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+3 Attack & Damage • Natural 20 Instantly Decapitates Target (or +6d8 Slashing Damage)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 weapon that ignores slashing resistance. On a natural 20, cuts off one of the creature\'s heads (or deals extra 6d8 slashing if immune to decapitation).',
        description: 'You gain a +3 bonus to attack and damage rolls made with this magic weapon. In addition, the weapon ignores resistance to slashing damage. When you roll a 20 on the attack roll with this weapon, you cut off one of the creature\'s heads. The creature dies if it can\'t survive without the lost head. A creature is immune to this effect if it is immune to slashing damage, doesn\'t have or need a head, has legendary actions, or the DM decides the creature is too big. Such a creature instead takes an extra 6d8 slashing damage from the hit.',
        activation: 'Passive / On Nat 20',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 weapon; natural 20 decapitates creature or inflicts +6d8 slashing damage.',
        description: '+3 weapon that ignores slashing resistance and decapitates targets on Critical Hit.',
        activation: 'Passive / On Nat 20',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'sword', 'vorpal', 'decapitation', 'critical hit', 'legendary'],
    ),
  ];
}
