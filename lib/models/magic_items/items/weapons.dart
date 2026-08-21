import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Magic Weapons Catalog
class SrdMagicWeapons {
  SrdMagicWeapons._();

  static const List<MagicItem> items = [
    // Weapon +1 / +2 / +3
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
      tags: ['weapon', 'bonus', 'rare'],
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
      tags: ['weapon', 'bonus', 'very rare'],
    ),

    // Flame Tongue
    MagicItem(
      id: 'item_flame_tongue',
      name: 'Flame Tongue',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          damageType: DamageAccent.fire,
          label: '+2d6 Fire Damage on Hit',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Command word ignites blade for extra 2d6 fire damage and sheds 40ft bright light.',
        description: 'You can use a bonus action to speak this magic sword\'s command word, causing flames to erupt from the blade. These flames shed bright light in a 40-foot radius and dim light for an additional 40 feet. While the sword is ablaze, it deals an extra 2d6 fire damage to any target it hits. The flames last until you use a bonus action to speak the command word again or until you drop or sheathe the sword.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Ignites for +2d6 fire damage with updated illumination rules and weapon mastery.',
        description: 'You can use a Bonus Action to speak the command word to ignite the blade. While ablaze, it deals an extra 2d6 Fire damage to any target it hits and sheds Bright Light in a 40-foot radius and Dim Light for an additional 40 feet. Compatible with 2024 Weapon Mastery properties.',
        activation: '1 Bonus Action',
        masteryProperties: 'Applies sword weapon mastery (e.g. Vex or Sap)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Clarified activation economy and weapon mastery compatibility.',
      diffHighlights: [
        '2024: Applies relevant Weapon Mastery properties (such as Vex on shortswords/greatswords or Sap on longswords).',
      ],
      tags: ['sword', 'fire', 'damage', 'illumination'],
    ),

    // Frost Brand
    MagicItem(
      id: 'item_frost_brand',
      name: 'Frost Brand',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      damageAccent: DamageAccent.cold,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          damageType: DamageAccent.cold,
          label: '+1d6 Cold Damage & Fire Resistance',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Deals +1d6 cold damage, grants fire resistance, and extinguishes nonmagical flames in 30ft.',
        description: 'When you hit with an attack using this magic sword, the target takes an extra 1d6 cold damage. In addition, while you hold the sword, you have resistance to fire damage. In freezing temperatures, the blade sheds bright light in a 10-foot radius. When you draw this weapon, you can extinguish all nonmagical flames within 30 feet of you once per hour.',
        activation: 'Passive + Reaction/Special',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Deals +1d6 cold damage, grants fire damage resistance, extinguishes fire, and unlocks mastery.',
        description: 'When you hit with an attack using this magic sword, the target takes an extra 1d6 Cold damage. While holding it, you have Resistance to Fire damage. Extinguishes nonmagical flames in a 30-foot emanation when drawn.',
        activation: 'Passive + Special',
        masteryProperties: 'Applies weapon mastery',
      ),
      isChangedIn2024: true,
      diffSummary: '30-foot radius defined using 2024 Emanation rules keyword.',
      diffHighlights: [
        '2024: Extinguish aura formalized as a 30-foot Emanation.',
        '2024: Integrates with weapon mastery.',
      ],
      tags: ['sword', 'cold', 'resistance', 'fire resistance'],
    ),

    // Sun Blade
    MagicItem(
      id: 'item_sun_blade',
      name: 'Sun Blade',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          damageType: DamageAccent.radiant,
          label: '+2 Attack & 1d8 Radiant (+1d8 vs Undead)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus blade of pure radiance with Finesse, dealing radiant damage (+1d8 vs undead).',
        description: 'This item appears to be a longsword hilt. While grasping the hilt, you can use a bonus action to cause a blade of pure radiance to spring into existence. The blade deals radiant damage instead of slashing damage and has the finesse property. You gain a +2 bonus to attack and damage rolls. If the target is undead, it takes an extra 1d8 radiant damage. Sheds sunlight in up to a 30-foot radius.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 radiant blade with Finesse property, +1d8 extra damage vs Undead, sheds sunlight, and uses sword mastery.',
        description: 'A longsword hilt that ignites as a blade of pure radiant energy (Bonus Action). Deals Radiant damage with the Finesse property and +2 bonus to attack and damage rolls. Deals an extra 1d8 Radiant damage to Undead targets and sheds true Sunlight in an adjustable 15–30 ft radius.',
        activation: '1 Bonus Action',
        masteryProperties: 'Vex / Sap',
      ),
      isChangedIn2024: true,
      diffSummary: 'Clarified true Sunlight interaction with Vampire/Undead sunlight hypersensitivity.',
      diffHighlights: [
        '2024: Explicitly categorized as Sunlight for 2024 creature sensitivity triggers.',
        '2024: Compatible with Weapon Mastery (Vex / Sap).',
      ],
      tags: ['sword', 'radiant', 'undead', 'sunlight', 'finesse'],
    ),

    // Holy Avenger
    MagicItem(
      id: 'item_holy_avenger',
      name: 'Holy Avenger',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      attunementRequirement: 'by a Paladin',
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          damageType: DamageAccent.radiant,
          label: '+3 Attack & +2d10 Radiant vs Fiends/Undead',
        ),
        ActionTraitRing(
          ringType: ActionRingType.sustain,
          label: '10-ft/30-ft Aura of Advantage on Spell Saves',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 holy weapon dealing +2d10 radiant to fiends/undead with 10-30ft spell saving throw aura.',
        description: 'You gain a +3 bonus to attack and damage rolls made with this magic weapon. When you hit a fiend or an undead with it, that creature takes an extra 2d10 radiant damage. While you hold the drawn sword, it creates an aura in a 10-foot radius (30-foot if you have 17+ paladin levels) granting you and all allies advantage on saving throws against spells and other magical effects.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 paladin blade with +2d10 radiant vs fiends/undead and 10/30ft Emanation of spell save advantage.',
        description: 'You gain a +3 bonus to attack and damage rolls. Deals an extra 2d10 Radiant damage to Fiends and Undead. Generates a 10-foot Emanation (30-foot if 17+ levels in Paladin) granting you and allies Advantage on saving throws against spells and magical effects.',
        activation: 'Passive',
        masteryProperties: 'Weapon Mastery compatible',
      ),
      isChangedIn2024: true,
      diffSummary: 'Aura updated to 2024 Emanation rules keyword.',
      diffHighlights: [
        '2024: Aura defined as an Emanation origin.',
        '2024: Interacts with 2024 Paladin Aura of Protection.',
      ],
      tags: ['paladin', 'radiant', 'fiend', 'undead', 'legendary'],
    ),

    // Dagger of Venom
    MagicItem(
      id: 'item_dagger_of_venom',
      name: 'Dagger of Venom',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.poison,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          damageType: DamageAccent.poison,
          label: '+1 Attack & 2d10 Poison (DC 15 Con)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 dagger that can coat itself in black poison once per day dealing 2d10 poison damage and poisoned condition.',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. You can use an action to cause thick, black poison to coat the blade. The poison remains for 1 minute or until an attack using this weapon hits a creature. That creature must succeed on a DC 15 Constitution saving throw or take 2d10 poison damage and become poisoned for 1 minute.',
        activation: '1 Action (Poison coating)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 dagger with 2d10 poison coating (DC 15 Con) and Nick weapon mastery.',
        description: 'You gain a +1 bonus to attack and damage rolls. As an Action (or Bonus Action under 2024 weapon coating rules), you can coat the blade in venom once daily. On hit, DC 15 Con save or take 2d10 Poison damage and the Poisoned condition for 1 minute.',
        activation: '1 Action',
        masteryProperties: 'Nick (extra light attack without bonus action)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Gains Nick weapon mastery for dagger offhand extra attacks.',
      diffHighlights: [
        '2024: Nick mastery allows an extra attack as part of the Attack action without spending a Bonus Action.',
      ],
      tags: ['dagger', 'poison', 'nick', 'finesse'],
    ),

    // Defender
    MagicItem(
      id: 'item_defender',
      name: 'Defender',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          label: 'Transfer +3 Bonus between Attack & AC',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 sword allowing you to allocate its +3 bonus between attack rolls and Armor Class each turn.',
        description: 'You gain a +3 bonus to attack and damage rolls made with this magic weapon. The first time you attack with the sword on each of your turns, you can transfer some or all of the sword\'s bonus to your AC instead of using the bonus on any attacks that turn. The adjusted bonuses remain in effect until the start of your next turn.',
        activation: 'Free on attack',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 sword allowing tactical allocation of +3 between attack bonus and AC until next turn.',
        description: 'You gain a +3 bonus to attack and damage rolls. When you make your first attack on your turn, you can transfer up to +3 of the bonus to your Armor Class until the start of your next turn.',
        activation: 'Free on attack',
        masteryProperties: 'Vex / Sap / Topple',
      ),
      isChangedIn2024: true,
      diffSummary: 'Streamlined AC bonus duration and mastery synergy.',
      diffHighlights: [
        '2024: AC bonus applies continuously until the start of your next turn.',
      ],
      tags: ['sword', 'defense', 'ac', 'legendary'],
    ),

    // Dragon Slayer
    MagicItem(
      id: 'item_dragon_slayer',
      name: 'Dragon Slayer',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          label: '+1 Attack & +3d6 vs Dragons',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 weapon that deals an extra 3d6 damage against creatures of the dragon type.',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic weapon. When you hit a dragon with this weapon, the dragon takes an extra 3d6 damage of the weapon\'s type.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 weapon dealing an extra 3d6 damage to dragons with weapon mastery.',
        description: 'You have a +1 bonus to attack and damage rolls made with this magic weapon. When you hit a Dragon, the target takes an extra 3d6 damage of the weapon\'s type.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'dragon', 'slayer'],
    ),

    // Giant Slayer
    MagicItem(
      id: 'item_giant_slayer',
      name: 'Giant Slayer',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          label: '+1 Attack & +2d6 vs Giants (DC 15 Prone)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 weapon dealing +2d6 vs giants and forcing a DC 15 Strength save against falling prone.',
        description: 'You have a +1 bonus to attack and damage rolls made with this weapon. When you hit a giant, it takes an extra 2d6 damage and must succeed on a DC 15 Strength saving throw or fall prone.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 weapon dealing +2d6 vs giants and DC 15 Str save vs Prone.',
        description: 'You have a +1 bonus to attack and damage rolls. When you hit a Giant, it takes an extra 2d6 damage and must succeed on a DC 15 Strength save or have the Prone condition.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['axe', 'giant', 'slayer', 'prone'],
    ),

    // Mace of Disruption
    MagicItem(
      id: 'item_mace_of_disruption',
      name: 'Mace of Disruption',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          damageType: DamageAccent.radiant,
          label: '+2d6 Radiant vs Fiends/Undead (DC 15 Destroy)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Deals +2d6 radiant to fiends/undead; targets with 25 HP or fewer must save DC 15 Wis or be destroyed.',
        description: 'When you hit a fiend or an undead with this magic weapon, that creature takes an extra 2d6 radiant damage. If the target has 25 hit points or fewer after taking this damage, it must succeed on a DC 15 Wisdom saving throw or be destroyed. On a success, the creature becomes frightened of you until the end of your next turn. Sheds bright light in a 20-foot radius.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Deals +2d6 Radiant to Fiends/Undead; targets with <=25 HP must save DC 15 Wis or be destroyed.',
        description: 'When you hit a Fiend or Undead, it takes an extra 2d6 Radiant damage. If it has 25 HP or fewer, DC 15 Wisdom save or be instantly destroyed (or Frightened on success). Sheds 20-foot Bright Light.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['mace', 'radiant', 'fiend', 'undead'],
    ),

    // Oathbow
    MagicItem(
      id: 'item_oathbow',
      name: 'Oathbow',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      damageAccent: DamageAccent.physical,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.ranged,
          label: 'Sworn Enemy: Advantage & +3d6 Piercing',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Whisper "Swift defeat to my enemy" to gain advantage and +3d6 piercing damage against a sworn enemy.',
        description: 'When you nock an arrow and whisper "Swift defeat to my enemy", the target becomes your sworn enemy for 7 days. You have advantage on attack rolls against it, ignore non-total cover and long-range disadvantage, and deal an extra 3d6 piercing damage on hit.',
        activation: '1 Command Word',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sworn Enemy bow granting Advantage, ignoring cover/long range, and dealing +3d6 piercing damage.',
        description: 'Designate a Sworn Enemy upon drawing the bow. Gain Advantage on attacks against the sworn enemy, ignore Half and Three-Quarters Cover and long-range disadvantage, and deal an extra 3d6 Piercing damage. Mastery: Slow / Push.',
        activation: '1 Command Word',
        masteryProperties: 'Push / Slow',
      ),
      isChangedIn2024: true,
      diffSummary: 'Interacts with 2024 Ranged Weapon Mastery properties.',
      diffHighlights: [
        '2024: Synergy with Push/Slow mastery on longbows.',
      ],
      tags: ['bow', 'ranged', 'advantage', 'damage'],
    ),

    // Vorpal Sword
    MagicItem(
      id: 'item_vorpal_sword',
      name: 'Vorpal Sword',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          damageType: DamageAccent.force,
          label: '+3 Attack & Instant Decapitation on Nat 20',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 slashing weapon that ignores slashing resistance and decapitates targets on a natural 20.',
        description: 'You gain a +3 bonus to attack and damage rolls made with this magic weapon. It ignores resistance to slashing damage. When you roll a 20 on the attack roll with this weapon, you lop off one of the target\'s heads. The creature dies if it can\'t survive without the lost head. If the creature is too large, has legendary actions, or no head, it takes an extra 6d8 slashing damage instead.',
        activation: 'Passive on Nat 20',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 weapon that ignores slashing resistance and decapitates on a natural 20 roll (or deals 6d8 slashing).',
        description: 'You gain a +3 bonus to attack and damage rolls and ignore Resistance to Slashing damage. On a Natural 20, you decapitate the target (or deal an extra 6d8 Slashing damage if immune/legendary/headless).',
        activation: 'Passive on Nat 20',
        masteryProperties: 'Vex / Cleave / Topple',
      ),
      isChangedIn2024: true,
      diffSummary: 'Clarified legendary resistance triggers on decapitation attempts.',
      diffHighlights: [
        '2024: Clarified interaction with creature size and Legendary Resistance/Actions.',
      ],
      tags: ['sword', 'vorpal', 'slashing', 'legendary'],
    ),
  ];
}
