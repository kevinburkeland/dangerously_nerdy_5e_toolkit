import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Armor & Shields Catalog
class SrdArmorAndShields {
  SrdArmorAndShields._();

  static const List<MagicItem> items = [
    // Armor +1 / +2 / +3
    MagicItem(
      id: 'item_armor_plus_1',
      name: 'Armor +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 bonus to AC'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +1 bonus to AC while wearing this magic armor.',
        description: 'You have a +1 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +1 bonus to AC while wearing this magic armor.',
        description: 'You have a +1 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_armor_plus_2',
      name: 'Armor +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 bonus to AC'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +2 bonus to AC while wearing this magic armor.',
        description: 'You have a +2 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +2 bonus to AC while wearing this magic armor.',
        description: 'You have a +2 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_armor_plus_3',
      name: 'Armor +3',
      category: ItemCategory.armor,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+3 bonus to AC'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +3 bonus to AC while wearing this magic armor.',
        description: 'You have a +3 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +3 bonus to AC while wearing this magic armor.',
        description: 'You have a +3 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'defense', 'ac', 'legendary'],
    ),

    // Shield +1 / +2 / +3
    MagicItem(
      id: 'item_shield_plus_1',
      name: 'Shield +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+3 Total AC (+2 Base Shield + 1 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have a +1 bonus to AC. This bonus is in addition to the shield\'s normal bonus to AC (+2), giving a total of +3 AC.',
        description: 'While holding this shield, you have a +1 bonus to AC. This bonus is in addition to the shield\'s normal bonus to AC.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC while wielding this shield (+3 AC total).',
        description: 'While wielding this magic shield, you gain a +1 bonus to Armor Class (total +3 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_shield_plus_2',
      name: 'Shield +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+4 Total AC (+2 Base Shield + 2 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have a +2 bonus to AC in addition to the normal shield bonus (+4 AC total).',
        description: 'While holding this shield, you have a +2 bonus to AC in addition to the normal shield bonus.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC while wielding this shield (+4 AC total).',
        description: 'While wielding this magic shield, you gain a +2 bonus to Armor Class (total +4 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_shield_plus_3',
      name: 'Shield +3',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+5 Total AC (+2 Base Shield + 3 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have a +3 bonus to AC in addition to the normal shield bonus (+5 AC total).',
        description: 'While holding this shield, you have a +3 bonus to AC in addition to the normal shield bonus.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 bonus to AC while wielding this shield (+5 AC total).',
        description: 'While wielding this magic shield, you gain a +3 bonus to Armor Class (total +5 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'defense', 'ac'],
    ),

    // Animated Shield
    MagicItem(
      id: 'item_animated_shield',
      name: 'Animated Shield',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Bonus Action: Shield Hovers & Protects for 1 Minute (Leaves Both Hands Free)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Speak command word as bonus action: shield hovers around you for 1 minute, granting +2 AC while leaving both hands free.',
        description: 'While holding this shield, you can speak its command word as a bonus action to cause it to animate. The shield leaps into the air and hovers in your space to protect you as if you were wielding it, leaving your hands free. The shield remains animated for 1 minute, until you use a bonus action to end this effect, or until you are incapacitated or die, at which point the shield falls to the ground or into your hand if you have one free.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action: shield animates for 1 minute, granting +2 AC while freeing both hands for two-handed weapons/casting.',
        description: 'Speak command word as a Bonus Action: shield hovers for 1 minute to provide +2 AC with both hands free.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'animated', 'hands free', 'defense', 'ac'],
    ),

    // Adamantine Armor
    MagicItem(
      id: 'item_adamantine_armor',
      name: 'Adamantine Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Critical Hits against you become Normal Hits'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While you\'re wearing it, any critical hit against you becomes a normal hit.',
        description: 'This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While you\'re wearing it, any critical hit against you becomes a normal hit.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Critical Hits against you turn into normal hits.',
        description: 'While wearing this armor, any Critical Hit scored against you becomes a normal hit.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'adamantine', 'crit immunity', 'defense'],
    ),

    // Mithral Armor
    MagicItem(
      id: 'item_mithral_armor',
      name: 'Mithral Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'No Disadvantage on Stealth; No Strength Requirement'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Mithral is a light, flexible metal. If the armor normally imposes disadvantage on Dexterity (Stealth) checks or has a Strength requirement, the mithral version of the armor doesn\'t.',
        description: 'Mithral is a light, flexible metal. If the armor normally imposes disadvantage on Dexterity (Stealth) checks or has a Strength requirement, the mithral version of the armor doesn\'t.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Removes Stealth disadvantage and Strength requirements from heavy/medium armor.',
        description: 'Lightweight mithral eliminates Stealth disadvantage and Strength score requirements on all armor types.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'mithral', 'stealth', 'strength'],
    ),

    // Dragon Scale Mail
    MagicItem(
      id: 'item_dragon_scale_mail',
      name: 'Dragon Scale Mail',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Scale Mail, Damage Resistance, Advantage vs Dragon Breath & Sense Dragons 30 Miles'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 scale mail granting resistance to dragon damage type, advantage on saves against dragon breath weapons and Frightful Presence, and action to sense dragon locations in 30 miles.',
        description: 'Dragon scale mail is made of the scales of one kind of dragon. While wearing this armor, you gain a +1 bonus to AC, you have resistance to one damage type determined by the dragon species (Black/Copper: Acid, Blue/Bronze: Lightning, Green: Poison, Red/Brass/Gold: Fire, White/Silver: Cold), and you have advantage on saving throws against the breath weapons and Frightful Presence of dragons. Once per day, you can focus to detect the location of any dragon within 30 miles.',
        activation: 'Passive / 1 Action (Detect)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Scale Mail; Resistance to dragon element; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description: '+1 Scale Mail granting elemental Resistance, Advantage on saves vs Dragon breath weapons and Frightful Presence, and 30-mile dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'dragon', 'resistance', 'breath weapon'],
    ),

    // Dwarven Plate
    MagicItem(
      id: 'item_dwarven_plate',
      name: 'Dwarven Plate',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 Plate Armor (AC 20) & Reaction: Reduce Forced Push/Prone by 10 ft'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 plate armor. If an effect moves you against your will along the ground, you can use your reaction to reduce the distance you are moved by up to 10 feet.',
        description: 'While wearing this armor, you gain a +2 bonus to AC. In addition, if an effect moves you against your will along the ground, you can use your reaction to reduce the distance you are moved by up to 10 feet.',
        activation: 'Passive / 1 Reaction',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 Plate Armor (AC 20); Reaction to resist forced movement by 10 feet.',
        description: '+2 bonus to AC. When an effect pushes you, use Reaction to reduce forced movement by up to 10 feet.',
        activation: 'Passive / 1 Reaction',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'plate', 'dwarven', 'defense', 'forced movement'],
    ),

    // Elven Chain
    MagicItem(
      id: 'item_elven_chain',
      name: 'Elven Chain',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Chain Shirt (AC 14 + Dex max 2); Proficient Even If You Lack Medium Armor Proficiency'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 chain shirt. You are considered proficient with this armor even if you lack medium armor proficiency.',
        description: 'You gain a +1 bonus to AC while you wear this armor. You are considered proficient with this armor even if you lack proficiency with medium armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Chain Shirt; grants proficiency to wearers who lack medium armor proficiency.',
        description: '+1 AC bonus. Any character is proficient while wearing this armor, making it ideal for wizards, sorcerers, and rogues.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'elven', 'medium armor', 'proficiency', 'spellcaster'],
    ),

    // Glamoured Studded Leather
    MagicItem(
      id: 'item_glamoured_studded_leather',
      name: 'Glamoured Studded Leather',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Studded Leather (AC 13 + Dex); Bonus Action: Disguise Armor as Any Outfit'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 studded leather armor. Bonus action: speak command word to disguise the armor as normal clothing or other armor.',
        description: 'While wearing this armor, you gain a +1 bonus to AC. You can also use a bonus action to speak the armor\'s command word and cause the armor to assume the appearance of a normal set of clothing or some other kind of armor. You decide what it looks like, including its color, style, and accessories, but the armor retains its normal bulk and weight. The illusory appearance lasts until you use this property again or remove the armor.',
        activation: '1 Bonus Action / Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Studded Leather; Bonus Action: illusory shift into clothing or other armor suits.',
        description: '+1 bonus to AC. Use Bonus Action to change visual appearance into normal clothes or distinct armor styles at will.',
        activation: '1 Bonus Action / Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'glamour', 'disguise', 'stealth'],
    ),

    // Spellguard Shield
    MagicItem(
      id: 'item_spellguard_shield',
      name: 'Spellguard Shield',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Advantage on Saves vs Spells; Spell Attack Rolls against you have Disadvantage'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have advantage on saving throws against spells and other magical effects, and spell attacks have disadvantage against you.',
        description: 'While holding this shield, you have advantage on saving throws against spells and other magical effects, and spell attacks have disadvantage against you.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Advantage on all saving throws vs spells/magical effects; Spell attacks against you suffer Disadvantage.',
        description: 'While wielding this shield, gain Advantage on saving throws vs spells and other magical effects, and spell attacks against you have Disadvantage.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'spellguard', 'magic resistance', 'defense'],
    ),

    // Shield of Missile Attraction
    MagicItem(
      id: 'item_shield_of_missile_attraction',
      name: 'Shield of Missile Attraction',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Resistance to Ranged Weapon Damage; Cursed: Pulls Ranged Attacks within 10 ft to You'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Grants resistance to damage from ranged weapon attacks. Cursed: whenever a ranged weapon attack is made against a target within 10 feet of you, the curse redirects the attack to you.',
        description: 'While holding this shield, you have resistance to damage from ranged weapon attacks. Curse: This shield is cursed. Whenever a ranged weapon attack is made against a target within 10 feet of you, the curse causes you to become the target instead.',
        activation: 'Passive / Cursed Trigger',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Resistance to Ranged Weapon Damage; Cursed redirection of projectile attacks within 10 ft.',
        description: 'Provides Resistance to damage from ranged weapon attacks. Cursed: pulls ranged attacks within 10 feet directly to yourself.',
        activation: 'Passive / Cursed Trigger',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'curse', 'missile', 'ranged defense'],
    ),
  ];
}
