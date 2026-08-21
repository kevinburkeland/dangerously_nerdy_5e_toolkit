import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Armor and Shields Catalog
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
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 AC Bonus'),
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
      tags: ['armor', 'ac', 'defense'],
    ),
    MagicItem(
      id: 'item_armor_plus_2',
      name: 'Armor +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 AC Bonus'),
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
      tags: ['armor', 'ac', 'defense'],
    ),
    MagicItem(
      id: 'item_armor_plus_3',
      name: 'Armor +3',
      category: ItemCategory.armor,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+3 AC Bonus'),
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
      tags: ['armor', 'ac', 'defense', 'legendary'],
    ),

    // Shield +1 / +2 / +3
    MagicItem(
      id: 'item_shield_plus_1',
      name: 'Shield +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Shield AC (+3 Total)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have a +1 bonus to AC in addition to the shield\'s normal bonus.',
        description: 'While holding this shield, you have a +1 bonus to AC in addition to the shield\'s normal bonus (+3 AC total).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'While wielding this shield, you have a +1 bonus to AC (+3 AC total) and shield mastery synergy.',
        description: 'While wielding this shield, you have a +1 bonus to AC in addition to the shield\'s standard bonus. Compatible with the 2024 Shield Master feat.',
        activation: 'Passive',
      ),
      isChangedIn2024: true,
      diffSummary: 'Interacts with revised 2024 Shield Master feat rules.',
      diffHighlights: [
        '2024: Interacts with updated 2024 Shield Master feat (bonus action bash without requiring an attack first).',
      ],
      tags: ['shield', 'ac', 'defense'],
    ),
    MagicItem(
      id: 'item_shield_plus_2',
      name: 'Shield +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 Shield AC (+4 Total)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have a +2 bonus to AC in addition to normal shield bonus.',
        description: 'While holding this shield, you have a +2 bonus to AC in addition to the shield\'s normal bonus (+4 AC total).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'While wielding this shield, you have a +2 bonus to AC (+4 AC total).',
        description: 'While wielding this shield, you have a +2 bonus to AC in addition to the shield\'s standard bonus.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'ac', 'rare'],
    ),

    // Adamantine Armor
    MagicItem(
      id: 'item_adamantine_armor',
      name: 'Adamantine Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Critical Hit Immunity'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'This suit of armor is reinforced with adamantine. Any critical hit against you becomes a normal hit.',
        description: 'This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While you\'re wearing it, any critical hit against you becomes a normal hit.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Any critical hit against you becomes a normal hit.',
        description: 'While you\'re wearing this armor, any Critical Hit against you becomes a normal hit.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'critical hit', 'immunity'],
    ),

    // Mithral Armor
    MagicItem(
      id: 'item_mithral_armor',
      name: 'Mithral Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'No Stealth Disadvantage & No Strength Requirement'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Mithral is a light, flexible metal. Removes Stealth disadvantage and Strength requirements.',
        description: 'Mithral is a light, flexible metal. If the armor normally imposes disadvantage on Dexterity (Stealth) checks or has a Strength requirement, the mithral version of the armor doesn\'t.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Lightweight flexible metal: removes Stealth disadvantage and Strength requirements.',
        description: 'If the armor normally imposes Disadvantage on Dexterity (Stealth) checks or has a Strength requirement, this version doesn\'t.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'mithral', 'stealth'],
    ),

    // Animated Shield
    MagicItem(
      id: 'item_animated_shield',
      name: 'Animated Shield',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Bonus Action Hover for 1 Minute (Hands Free +2 AC)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Use a bonus action to speak command word; shield animates to protect you for 1 minute while hands remain free.',
        description: 'While holding this shield, you can speak its command word as a bonus action to cause it to animate. The shield leaps into the air and hovers in your space to protect you as if you were wielding it, leaving your hands free. The condition ends after 1 minute or until you are incapacitated or die.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action: shield floats in your space protecting you for 1 minute with hands free.',
        description: 'You can use a Bonus Action to command the shield to animate for 1 minute. It hovers in your space, granting its +2 AC bonus while keeping both hands completely free.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'animated', 'hands free'],
    ),

    // Armor of Invulnerability
    MagicItem(
      id: 'item_armor_of_invulnerability',
      name: 'Armor of Invulnerability',
      category: ItemCategory.armor,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Nonmagical Damage Resistance'),
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Immunity Action (1/Day for 10 Min)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Plate armor granting resistance to nonmagical damage, and an action to become immune to nonmagical damage for 10 minutes.',
        description: 'You have resistance to nonmagical damage while you wear this plate armor. Additionally, you can use an action to make yourself immune to nonmagical damage for 10 minutes or until you are no longer wearing the armor. Once used, this action can\'t be used again until the next dawn.',
        activation: '1 Action (Immunity)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants resistance to Bludgeoning, Piercing, and Slashing damage; action to gain immunity for 10 min daily.',
        description: 'You have Resistance to nonmagical damage (or Bludgeoning, Piercing, and Slashing damage from non-magical sources). Once per long rest, you can use an Action to become immune to nonmagical damage for 10 minutes.',
        activation: '1 Action (1/Day)',
      ),
      isChangedIn2024: true,
      diffSummary: '2024 standardizes damage resistance phrasing to bludgeoning/piercing/slashing.',
      diffHighlights: [
        '2024: Revised damage resistance terminology aligned with 2024 core rules.',
      ],
      tags: ['plate', 'invulnerability', 'immunity', 'legendary'],
    ),

    // Spellguard Shield
    MagicItem(
      id: 'item_spellguard_shield',
      name: 'Spellguard Shield',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Advantage on Saves vs Spells'),
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Spell Attacks Have Disadvantage vs You'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Grants advantage on saving throws against spells and magical effects, and spell attacks have disadvantage against you.',
        description: 'While holding this shield, you have advantage on saving throws against spells and other magical effects, and spell attacks have disadvantage against you.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Advantage on saves vs spells; spell attack rolls have Disadvantage against you.',
        description: 'While wielding this shield, you have Advantage on saving throws against spells and magical effects, and spell attack rolls have Disadvantage against you.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'spellguard', 'magic resistance'],
    ),
  ];
}
