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
          label: 'Bonus Action: +2d6 Fire Damage & Sheds Light',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Bonus action: sword ignites in flames, dealing an extra 2d6 fire damage on hits and shedding bright light in a 40-foot radius.',
        description: 'You can use a bonus action to speak this magic sword\'s command word, causing flames to erupt from the blade. These flames shed bright light in a 40-foot radius and dim light for an additional 40 feet. While the sword is ablaze, it deals an extra 2d6 fire damage to any target it hits. The flames last until you use a bonus action to speak the command word again or until you drop or sheathe the sword.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus action: ignites dealing an extra 2d6 Fire damage per hit. Sheds 40/40 ft Light.',
        description: 'Bonus action activation: flames erupt from the blade, dealing +2d6 Fire damage on hit and shedding Bright Light (40 ft) and Dim Light (40 ft). Lasts until doused as a Bonus Action, sheathed, or dropped.',
        activation: '1 Bonus Action',
        masteryProperties: 'Vex / Cleave / Sap',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'fire', 'damage', 'light'],
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
        summary: 'Deals an extra 1d6 cold damage on hits, grants resistance to fire damage, sheds dim light in sub-freezing temperatures, and snuffs nonmagical fires.',
        description: 'When you hit with an attack using this magic sword, the target takes an extra 1d6 cold damage. In addition, while you hold the sword, you have resistance to fire damage. In freezing temperatures, the blade sheds bright light in a 10-foot radius and dim light for an additional 10 feet. When drawn, you can extinguish all nonmagical flames within 30 feet of you once per hour.',
        activation: 'Passive / On Draw',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Deals +1d6 Cold damage per hit, gives Resistance to Fire damage, and snuffs fires on draw.',
        description: 'Extra 1d6 Cold damage on hit. Grants Resistance to Fire damage while held. Snuffs nonmagical fire in 30 ft when drawn.',
        activation: 'Passive',
        masteryProperties: 'Vex / Cleave / Sap',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'cold', 'resistance', 'fire'],
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
          label: '+2 Longsword (Finesse) & +1d8 Radiant vs Undead',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 finesse longsword made of pure radiant sunlight dealing 1d8 radiant damage, with +1d8 extra radiant damage against undead.',
        description: 'This item appears to be a longsword hilt. While grasping the hilt, you can use a bonus action to cause a blade of pure radiance to spring into existence. The sword has the finesse property and grants a +2 bonus to attack and damage rolls. It deals radiant damage instead of slashing damage. When you hit an undead target with it, the undead takes an extra 1d8 radiant damage. The blade sheds bright sunlight in a 15-foot radius and dim light for an additional 15 feet.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 Finesse Longsword dealing Radiant damage (+1d8 Radiant vs Undead). Sheds sunlight.',
        description: 'Bonus action to ignite pure radiant blade (+2 bonus, Finesse, Radiant damage). Deals an extra 1d8 Radiant damage to Undead and sheds true sunlight.',
        activation: '1 Bonus Action',
        masteryProperties: 'Sap / Vex',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'radiant', 'undead', 'sunlight', 'finesse'],
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
          label: '+1 Attack/Dmg & +3d6 vs Dragons',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 weapon that deals an extra 3d6 damage against any creature with the Dragon type.',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. When you hit a dragon with this weapon, the dragon takes an extra 3d6 damage of the weapon\'s type.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 weapon dealing +3d6 extra damage of the weapon\'s type when hitting Dragons.',
        description: 'Grants +1 to attack and damage rolls. When hitting a creature of the Dragon type, deals an extra 3d6 damage.',
        activation: 'Passive',
        masteryProperties: 'Eligible for Weapon Mastery',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'dragon', 'damage', 'slayer'],
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
          label: '+1 Attack/Dmg, +2d6 vs Giants, & DC 15 STR Save to Knocks Prone',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 weapon dealing +2d6 extra damage against Giants and forcing a DC 15 Strength save to knock the Giant prone.',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. When you hit a giant with it, the giant takes an extra 2d6 damage of the weapon\'s type and must succeed on a DC 15 Strength saving throw or fall prone.',
        activation: 'Passive',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 weapon dealing +2d6 vs Giants and forcing DC 15 Strength save or Prone condition.',
        description: 'Grants +1 to attack and damage rolls. Against Giants, deals an extra 2d6 damage and inflicts the Prone condition on a failed DC 15 Strength save.',
        activation: 'Passive',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'giant', 'prone', 'slayer'],
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
          label: '+3 Attack/Dmg, +2d10 Radiant vs Fiends/Undead & 10–30 ft Aura of Magic Resistance',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 weapon for Paladins dealing +2d10 radiant damage to fiends and undead, with a 10-foot aura granting advantage on saves vs spells.',
        description: 'You gain a +3 bonus to attack and damage rolls made with this magic weapon. When you hit a fiend or an undead with it, that creature takes an extra 2d10 radiant damage. While you hold the drawn sword, it creates an aura in a 10-foot radius. You and all creatures friendly to you in the aura have advantage on saving throws against spells and other magical effects. If you have 17 or more levels in the paladin class, the radius of the aura increases to 30 feet.',
        activation: 'Passive (10–30 ft Aura)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 Paladin weapon; +2d10 Radiant damage vs Fiends/Undead; 10/30 ft aura granting Advantage on saving throws vs spells.',
        description: '+3 weapon for Paladins. Extra 2d10 Radiant damage against Fiends and Undead. 10 ft aura (30 ft at level 17+) granting Advantage on saves against spells and magical effects to allies.',
        activation: 'Passive',
        masteryProperties: 'Sap / Cleave / Vex',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'paladin', 'radiant', 'fiend', 'undead', 'legendary'],
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
          label: '+1 Dagger & Action: Coat in Venom (2d10 Poison + Poisoned 1 Min)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 dagger with action to coat in black poison for 1 minute: deals 2d10 poison damage and inflicts poisoned condition on DC 15 Con save.',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. You can use an action to cause thick, black poison to coat the blade. The poison remains for 1 minute or until an attack using this weapon hits a creature. That creature must succeed on a DC 15 Constitution saving throw or take 2d10 poison damage and become poisoned for 1 minute. The dagger can\'t be used this way again until the next dawn.',
        activation: '1 Action (1/Day)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Dagger; Action: coat blade to deal 2d10 Poison damage and inflict Poisoned condition on DC 15 Con save (1/Long Rest).',
        description: '+1 bonus to attack and damage rolls. Action to coat the blade in venom: next hit deals +2d10 Poison damage and inflicts the Poisoned condition for 1 minute on a failed DC 15 Constitution saving throw.',
        activation: '1 Action (1/Long Rest)',
        savingThrowDc: 'Fixed DC 15',
        masteryProperties: 'Nick',
      ),
      isChangedIn2024: false,
      tags: ['dagger', 'poison', 'venom', 'rogue'],
    ),

    // Dancing Sword
    MagicItem(
      id: 'item_dancing_sword',
      name: 'Dancing Sword',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Bonus Action: Toss Sword to Hover & Attack up to 30 ft (4 Attacks)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Toss sword into the air as a bonus action: hovers and flies up to 30 feet to attack independently using your attack roll and ability mod.',
        description: 'You can use a bonus action to toss this magic sword into the air and speak the command word. When you do so, the sword begins to hover, flies up to 30 feet, and attacks one creature of your choice within 5 feet of it. The sword uses your attack roll and ability score modifier to damage rolls. While the sword hovers, you can use a bonus action to cause it to fly up to 30 feet to another spot within 30 feet of you. After the sword makes its fourth attack, it flies up to 30 feet back to your hand.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action: sword hovers and makes independent melee attacks within 30 ft for up to 4 attacks.',
        description: 'Toss into the air as a Bonus Action: flies up to 30 feet and attacks. Uses your attack roll and ability modifier. Returns after 4 attacks or on command.',
        activation: '1 Bonus Action',
        masteryProperties: 'Vex / Cleave',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'dancing', 'animated', 'bonus action'],
    ),

    // Defender
    MagicItem(
      id: 'item_defender',
      name: 'Defender',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+3 Sword: Allocate +1/+2/+3 to AC instead of Attack Bonus'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 sword allowing you to transfer some or all of its +3 bonus to your Armor Class instead of your attack and damage rolls each turn.',
        description: 'You gain a +3 bonus to attack and damage rolls made with this magic weapon. The first time you attack with the sword on each of your turns, you can transfer some or all of the sword\'s bonus to your AC, instead of using the bonus on any attacks that turn. For example, you could reduce the bonus to your attack and damage rolls to +1 and gain a +2 bonus to AC. The adjusted bonuses remain in effect until the start of your next turn.',
        activation: 'Passive / On Attack',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 weapon: allocate bonus between Attack/Damage and AC at the start of your turn.',
        description: '+3 bonus to attack and damage rolls. On your turn, choose how to allocate the +3 between attack/damage rolls and your Armor Class until your next turn.',
        activation: 'Passive / On Attack',
        masteryProperties: 'Sap / Cleave',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'defender', 'ac', 'defense', 'legendary'],
    ),

    // Oathbow
    MagicItem(
      id: 'item_oathbow',
      name: 'Oathbow',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Swear Sworn Enemy: Advantage on Attacks, +3d6 Piercing & Ignores Cover'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Whisper command word to swear a sworn enemy: advantage on attacks against it, deals +3d6 piercing damage, ignores cover, and gives disadvantage with other weapons.',
        description: 'When you nock an arrow on this bow, it whispers in Elvish: "Swift defeat to my enemies." When you use this weapon to make a ranged attack, you can, as a command phrase, say, "Swift death to you who have wronged me." The target of your attack becomes your sworn enemy until it dies or at dawn seven days later. You have advantage on ranged attack rolls made against it, attacks deal an extra 3d6 piercing damage, and your target gains no benefit from cover other than total cover. While your sworn enemy lives, you have disadvantage on attack rolls with all other weapons.',
        activation: '1 Command Word',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Swear a Sworn Enemy: grants Advantage on attack rolls, +3d6 extra Piercing damage, and ignores all cover except Total Cover.',
        description: 'Designate a Sworn Enemy when attacking: you gain Advantage on attack rolls against it, deal an extra 3d6 Piercing damage, and ignore Half and Three-Quarters Cover.',
        activation: '1 Command Word',
        masteryProperties: 'Push / Slow',
      ),
      isChangedIn2024: false,
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
      isChangedIn2024: false,
      tags: ['sword', 'vorpal', 'slashing', 'legendary'],
    ),

    // Berserker Axe
    MagicItem(
      id: 'item_berserker_axe',
      name: 'Berserker Axe',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Greataxe & +1 Max HP per Level; Cursed Berserk State'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 axe that increases maximum HP by 1 per character level. Cursed: taking damage forces a DC 15 Wis save to enter a berserk rampage attacking nearest creature.',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. In addition, while you are attuned to this weapon, your hit point maximum increases by 1 for each level you have attained. Curse: You are unwilling to part with the axe. Whenever a hostile creature damages you while the axe is in your possession, you must succeed on a DC 15 Wisdom saving throw or go berserk. While berserk, you must use your action each round to attack the creature nearest to you with the axe.',
        activation: 'Passive / Cursed Trigger',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Greataxe granting +1 Max HP per level. Cursed: taking damage triggers DC 15 Wisdom save or enter berserk state.',
        description: '+1 bonus to attack and damage rolls. Increases Max HP by 1 per level. Cursed: taking damage requires a DC 15 Wisdom save or go berserk, attacking the nearest creature each turn until no creatures are within 60 ft.',
        activation: 'Passive / Cursed Trigger',
        savingThrowDc: 'Fixed DC 15',
        masteryProperties: 'Cleave / Topple',
      ),
      isChangedIn2024: false,
      tags: ['axe', 'curse', 'hp', 'berserker'],
    ),

    // Hammer of Thunderbolts
    MagicItem(
      id: 'item_hammer_of_thunderbolts',
      name: 'Hammer of Thunderbolts',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      damageAccent: DamageAccent.thunder,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.thunder, label: '+1 Maul (+4 with Gauntlets/Belt), +4 STR Score, Thrown Thunderclap (DC 17 Stun)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 maul granting +4 to Strength score (max 30). When attuned with Gauntlets of Ogre Power and a Belt of Giant Strength, becomes +4 and can be hurled for 20/60 ft thunderclap.',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. Giant\'s Bane: Requires Gauntlets of Ogre Power and a Belt of Giant Strength to attune. Your Strength score increases by 4 and can exceed 20, up to a maximum of 30. The weapon gains 5 charges. You can expend 1 charge and make a ranged attack (range 20/60 ft). On a hit, it emits a thunderclap (DC 17 Con save or stunned until end of next turn).',
        activation: '1 Action / Thrown Attack',
        charges: '5 charges (recharges 1d4 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Maul; +4 to Strength score (max 30). Synergy with Gauntlets and Giant Belt to become +4 and throw thunderbolts.',
        description: 'Increases Strength score by 4 (max 30). When paired with Gauntlets of Ogre Power and Belt of Giant Strength, becomes a +4 weapon with 5 charges to hurl thunderclap shockwaves (DC 17 Constitution save or Stunned).',
        activation: '1 Action / Thrown Attack',
        charges: '5 charges (recharges 1d4 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 17',
        masteryProperties: 'Topple / Push',
      ),
      isChangedIn2024: false,
      tags: ['hammer', 'maul', 'thunder', 'strength', 'legendary'],
    ),

    // Javelin of Lightning
    MagicItem(
      id: 'item_javelin_of_lightning',
      name: 'Javelin of Lightning',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.lightning,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.lightning, label: 'Hurl Javelin: 120-ft Line of 4d6 Lightning + Weapon Damage (1/Day)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Hurl javelin up to 120 feet: transforms into a bolt of lightning dealing 4d6 lightning damage to all in line (DC 13 Dex save) and standard damage to target.',
        description: 'This javelin is a magic weapon. When you hurl it and speak its command word, it transforms into a bolt of lightning, forming a line 5 feet wide that extends out from you to a target within 120 feet. Each creature in the line excluding you and the target must make a DC 13 Dexterity saving throw, taking 4d6 lightning damage on a failed save, or half as much damage on a successful one. The lightning bolt turns back into a javelin when it reaches the target. Make a ranged weapon attack against the target: deals normal damage plus 4d6 lightning damage on a hit. Recharges daily at dawn.',
        activation: '1 Action (1/Day)',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Hurl javelin in 120 ft line: 4d6 Lightning to all in path (DC 13 Dex save), plus regular damage + 4d6 Lightning to target (1/Long Rest).',
        description: 'Hurl as an Action (120 ft line, 5 ft wide). Creatures in line take 4d6 Lightning damage on failed DC 13 Dexterity save. Target takes weapon damage + 4d6 Lightning damage on hit.',
        activation: '1 Action (1/Long Rest)',
        savingThrowDc: 'Fixed DC 13',
        masteryProperties: 'Slow',
      ),
      isChangedIn2024: false,
      tags: ['javelin', 'lightning', 'thrown', 'line', 'aoe'],
    ),

    // Luck Blade
    MagicItem(
      id: 'item_luck_blade',
      name: 'Luck Blade',
      category: ItemCategory.weapon,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Attack/Dmg & +1 to All Saves; Lucky Reroll (1/Day)'),
        ActionTraitRing(ringType: ActionRingType.legendary, label: 'Contains 1d4-1 Wish Spells (Action)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 sword granting +1 to all saving throws, 1 lucky reroll per day, and 1d4-1 Wish spells.',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. While the sword is on your person, you also gain a +1 bonus to saving throws. Luck: If the sword is on your person, you can call on its luck (no action required) to reroll one attack roll, ability check, or saving throw you dislike. You must use the second roll. This property can\'t be used again until the next dawn. Wish: The sword has 1d4 - 1 charges. While holding it, you can use an action to expend 1 charge and cast the Wish spell from it. Once all charges are used, this property ceases to function.',
        activation: 'Passive / 1 Action (Wish)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 sword; +1 to all Saving Throws; 1 reroll per Long Rest; contains 1d4-1 charges to cast Wish.',
        description: '+1 weapon and +1 to all saving throws while carried. Reroll one d20 roll per Long Rest. Holds 1d4-1 charges to cast Wish.',
        activation: 'Passive / 1 Action (Wish)',
        masteryProperties: 'Vex / Cleave',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'wish', 'luck', 'reroll', 'legendary'],
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
        ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.radiant, label: '+2d6 Radiant vs Fiends/Undead; DC 15 Save to Instantly Destroy if ≤25 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Deals +2d6 radiant damage against fiends and undead. If a fiend/undead has 25 HP or fewer after hit, must pass DC 15 Wis save or be destroyed.',
        description: 'When you hit a fiend or an undead with this magic weapon, that creature takes an extra 2d6 radiant damage. If the target has 25 hit points or fewer after taking this damage, it must succeed on a DC 15 Wisdom saving throw or be destroyed. On a successful save, the creature becomes frightened of you until the end of your next turn. While holding the mace, you can make it shed bright light in a 20-foot radius.',
        activation: 'Passive',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2d6 Radiant damage vs Fiends and Undead; forces DC 15 Wisdom save to instantly disintegrate targets with 25 HP or fewer.',
        description: 'Extra 2d6 Radiant damage against Fiends and Undead. Targets reduced to 25 HP or fewer must pass DC 15 Wisdom save or be instantly destroyed.',
        activation: 'Passive',
        savingThrowDc: 'Fixed DC 15',
        masteryProperties: 'Sap',
      ),
      isChangedIn2024: false,
      tags: ['mace', 'radiant', 'fiend', 'undead', 'disruption'],
    ),

    // Mace of Smiting
    MagicItem(
      id: 'item_mace_of_smiting',
      name: 'Mace of Smiting',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+1 Mace (+3 vs Constructs); Extra 2d6 Bludgeoning on Nat 20 (or +40 vs Constructs)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 mace (+3 vs Constructs). Rolling a 20 deals an extra 2d6 bludgeoning damage (or 40 bludgeoning damage if target is a Construct).',
        description: 'You gain a +1 bonus to attack and damage rolls made with this magic weapon. The bonus increases to +3 when you use the mace to attack a construct. When you roll a 20 on an attack roll made with this weapon, the target takes an extra 2d6 bludgeoning damage, or an extra 40 bludgeoning damage if it is a construct. If a construct has 25 hit points or fewer after taking this damage, it is destroyed.',
        activation: 'Passive on Nat 20',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Mace (+3 vs Constructs). Nat 20 deals +2d6 Bludgeoning (or +40 Bludgeoning and destroys Constructs ≤25 HP).',
        description: '+1 to attack and damage (+3 against Constructs). Rolling a Natural 20 deals an extra 2d6 Bludgeoning damage (or +40 Bludgeoning vs Constructs, instantly destroying them if ≤25 HP).',
        activation: 'Passive on Nat 20',
        masteryProperties: 'Sap',
      ),
      isChangedIn2024: false,
      tags: ['mace', 'construct', 'crit', 'smiting'],
    ),

    // Scimitar of Speed
    MagicItem(
      id: 'item_scimitar_of_speed',
      name: 'Scimitar of Speed',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+2 Scimitar & Bonus Action: Make 1 Extra Attack on each of your turns'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 scimitar that allows you to make one attack with it as a bonus action on each of your turns.',
        description: 'You gain a +2 bonus to attack and damage rolls made with this magic weapon. In addition, you can make one attack with it as a bonus action on each of your turns.',
        activation: '1 Bonus Action / Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 Scimitar granting an extra weapon attack as a Bonus Action on each of your turns.',
        description: '+2 bonus to attack and damage rolls. You can make an attack with this weapon as a Bonus Action on every turn.',
        activation: '1 Bonus Action / Passive',
        masteryProperties: 'Nick',
      ),
      isChangedIn2024: false,
      tags: ['scimitar', 'speed', 'bonus action', 'finesse'],
    ),

    // Sword of Life Stealing
    MagicItem(
      id: 'item_sword_of_life_stealing',
      name: 'Sword of Life Stealing',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.necrotic,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.necrotic, label: 'Nat 20: +10 Necrotic Damage & Gain 10 Temp HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you roll a 20 on an attack roll with this weapon, the target takes an extra 10 necrotic damage (unless construct/undead) and you gain 10 temporary HP.',
        description: 'When you attack a creature with this weapon and roll a 20 on the attack roll, that target takes an extra 10 necrotic damage, provided that the target isn\'t a construct or an undead. You also gain 10 temporary hit points.',
        activation: 'Passive on Nat 20',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Natural 20 deals +10 Necrotic damage and grants 10 Temporary Hit Points.',
        description: 'On a Natural 20 roll against living creatures, deals +10 Necrotic damage and grants 10 Temporary HP.',
        activation: 'Passive on Nat 20',
        masteryProperties: 'Vex / Cleave',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'life stealing', 'necrotic', 'temp hp'],
    ),

    // Sword of Sharpness
    MagicItem(
      id: 'item_sword_of_sharpness',
      name: 'Sword of Sharpness',
      category: ItemCategory.weapon,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Max Damage on Objects; Nat 20: +14 Slashing & Roll to Sever Limb'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Deals maximum damage against objects. Rolling a 20 deals +14 slashing damage, and a subsequent d20 roll of 20 severs a limb.',
        description: 'When you attack an object with this magic sword and hit, maximize your weapon damage dice against the target. When you attack a creature with this weapon and roll a 20 on the attack roll, that target takes an extra 14 slashing damage. Then roll another d20. If you roll a 20, you lop off one of the target\'s limbs.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Deals maximum damage against objects. Natural 20 deals +14 Slashing damage with chance to sever a limb.',
        description: 'Maximum damage against inanimate objects. On a Natural 20, deals +14 Slashing damage and rolling an additional 20 severs a limb.',
        activation: 'Passive',
        masteryProperties: 'Cleave / Vex',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'sharpness', 'slashing', 'objects', 'sever'],
    ),

    // Sword of Wounding
    MagicItem(
      id: 'item_sword_of_wounding',
      name: 'Sword of Wounding',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.necrotic,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.necrotic, label: 'Prevents HP Regain; Inflicts 1d4 Stacking Bleed at start of target\'s turns (DC 15 CON Save)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Hit prevents target from regaining HP for 1 round, and wounds target causing 1d4 necrotic damage at the start of each of its turns per stack.',
        description: 'Hit points lost to this weapon\'s damage can be regained only through a short or long rest, rather than by regeneration, magic, or any other means. Once per turn when you hit a creature with an attack using this magic weapon, you can wound the target. At the start of each of the wounded creature\'s turns, it takes 1d4 necrotic damage for each time you\'ve wounded it, and it can then make a DC 15 Constitution saving throw, ending the effect of all such wounds on a success.',
        activation: 'Passive on Hit',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Target cannot regain HP except via rests. Inflicts stacking 1d4 Necrotic bleed damage per turn (DC 15 Constitution save to heal).',
        description: 'Hit prevents magical healing until a rest. Once per turn, inflict a bleeding wound dealing 1d4 Necrotic damage at start of target\'s turns per wound (DC 15 Constitution save to end).',
        activation: 'Passive on Hit',
        savingThrowDc: 'Fixed DC 15',
        masteryProperties: 'Vex / Sap',
      ),
      isChangedIn2024: false,
      tags: ['sword', 'wounding', 'bleed', 'necrotic'],
    ),

    // Trident of Fish Command
    MagicItem(
      id: 'item_trident_of_fish_command',
      name: 'Trident of Fish Command',
      category: ItemCategory.weapon,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '3 Charges: Dominate Beast on Aquatic Creatures (DC 15 WIS Save)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Has 3 charges to cast Dominate Beast (save DC 15) on beasts that have an innate swimming speed.',
        description: 'This trident is a magic weapon. It has 3 charges (regains 1d3 daily at dawn). While holding it, you can use an action and expend 1 charge to cast Dominate Beast (save DC 15) on a beast that has an innate swimming speed.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges to cast Dominate Beast (DC 15) on aquatic beasts.',
        description: '3 charges (recharges 1d3 on Long Rest). Action: expend 1 charge to cast Dominate Beast (DC 15 Wisdom save) on any creature with a Swim Speed.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
        savingThrowDc: 'Fixed DC 15',
        masteryProperties: 'Topple',
      ),
      isChangedIn2024: false,
      tags: ['trident', 'aquatic', 'beast', 'dominate'],
    ),

    // Vicious Weapon
    MagicItem(
      id: 'item_vicious_weapon',
      name: 'Vicious Weapon',
      category: ItemCategory.weapon,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Nat 20: Deals an Extra 7 Flat Damage of Weapon\'s Type'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you roll a 20 on your attack roll with this magic weapon, the target takes an extra 7 damage of the weapon\'s type.',
        description: 'When you roll a 20 on your attack roll with this magic weapon, the target takes an extra 7 damage of the weapon\'s type.',
        activation: 'Passive on Nat 20',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Rolling a Natural 20 deals an extra 7 damage of the weapon\'s type.',
        description: 'On a Natural 20 attack roll, deals an additional 7 damage of the weapon\'s damage type.',
        activation: 'Passive on Nat 20',
        masteryProperties: 'Eligible for Weapon Mastery',
      ),
      isChangedIn2024: false,
      tags: ['weapon', 'vicious', 'crit', 'damage'],
    ),
  ];
}
