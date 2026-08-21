import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Potions and Oils Catalog
class SrdPotionsAndOils {
  SrdPotionsAndOils._();

  static const List<MagicItem> items = [
    // Potion of Healing (Common)
    MagicItem(
      id: 'item_potion_of_healing',
      name: 'Potion of Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.common,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action (or Bonus Action 2024): Regain 2d4 + 2 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: drink this magical red fluid to regain 2d4 + 2 hit points (or administer to an unconscious creature).',
        description: 'You regain 2d4 + 2 hit points when you drink this potion. The potion\'s red liquid glimmers when agitated.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink (or Action to administer to another creature): regain 2d4 + 2 HP.',
        description: 'Drink as a Bonus Action or administer to another creature as an Action to restore 2d4 + 2 Hit Points.',
        activation: '1 Bonus Action (Self) / 1 Action (Other)',
      ),
      isChangedIn2024: true,
      diffSummary: 'In 2024, drinking a potion yourself is now a Bonus Action (administering to another is an Action).',
      diffHighlights: [
        '2024: Consuming a potion is streamlined to a Bonus Action.',
      ],
      tags: ['potion', 'healing', 'hp', 'consumable'],
    ),

    // Potion of Greater Healing
    MagicItem(
      id: 'item_potion_of_greater_healing',
      name: 'Potion of Greater Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Regain 4d4 + 4 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You regain 4d4 + 4 hit points when you drink this potion.',
        description: 'You regain 4d4 + 4 hit points when you drink this potion.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink (or Action to administer): regain 4d4 + 4 HP.',
        description: 'Drink as a Bonus Action or administer to another creature as an Action to restore 4d4 + 4 Hit Points.',
        activation: '1 Bonus Action (Self) / 1 Action (Other)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'healing', 'hp', 'consumable'],
    ),

    // Potion of Superior Healing
    MagicItem(
      id: 'item_potion_of_superior_healing',
      name: 'Potion of Superior Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Regain 8d4 + 8 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You regain 8d4 + 8 hit points when you drink this potion.',
        description: 'You regain 8d4 + 8 hit points when you drink this potion.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: regain 8d4 + 8 HP.',
        description: 'Drink as a Bonus Action or administer to another creature as an Action to restore 8d4 + 8 Hit Points.',
        activation: '1 Bonus Action (Self) / 1 Action (Other)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'healing', 'hp', 'consumable'],
    ),

    // Potion of Supreme Healing
    MagicItem(
      id: 'item_potion_of_supreme_healing',
      name: 'Potion of Supreme Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      damageAccent: DamageAccent.radiant,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Regain 10d4 + 20 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You regain 10d4 + 20 hit points when you drink this potion.',
        description: 'You regain 10d4 + 20 hit points when you drink this potion.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: regain 10d4 + 20 HP.',
        description: 'Drink as a Bonus Action or administer to another creature as an Action to restore 10d4 + 20 Hit Points.',
        activation: '1 Bonus Action (Self) / 1 Action (Other)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'healing', 'hp', 'consumable'],
    ),

    // Potion of Giant Strength
    MagicItem(
      id: 'item_potion_of_giant_strength',
      name: 'Potion of Giant Strength',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Strength Score changes to 21, 23, 25, 27, or 29 for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, your Strength score changes for 1 hour based on giant kind (Hill 21, Frost/Stone 23, Fire 25, Cloud 27, Storm 29).',
        description: 'When you drink this potion, your Strength score changes for 1 hour. The type of giant determines the score (Hill 21, Frost/Stone 23, Fire 25, Cloud 27, Storm 29). Has no effect if your Strength is already higher.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Strength becomes 21–29 for 1 hour (Hill Uncommon to Storm Legendary).',
        description: 'Bonus Action to drink: your Strength score becomes 21 (Hill), 23 (Stone/Frost), 25 (Fire), 27 (Cloud), or 29 (Storm) for 1 hour.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'giant', 'strength', 'buff', 'stat boost'],
    ),

    // Potion of Flying
    MagicItem(
      id: 'item_potion_of_flying',
      name: 'Potion of Flying',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Gain Flying Speed equal to Walking Speed & Hover for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain a flying speed equal to your walking speed for 1 hour and can hover.',
        description: 'When you drink this potion, you gain a flying speed equal to your walking speed for 1 hour and can hover. If you\'re in the air when the potion wears off, you descend at 30 feet per round for 1 minute until you land.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gain Fly Speed equal to Speed and Hover capability for 1 hour.',
        description: 'Drink as a Bonus Action: gain Fly Speed equal to Speed (with Hover) for 1 hour. Floats down safely if effect ends mid-air.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'flying', 'mobility', 'hover'],
    ),

    // Potion of Invisibility
    MagicItem(
      id: 'item_potion_of_invisibility',
      name: 'Potion of Invisibility',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Gain Invisibility for 1 Hour (Ends on Attack or Spell)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Become invisible for 1 hour. Anything you are wearing or carrying is invisible with you. Ends if you attack or cast a spell.',
        description: 'This potion\'s container looks empty but feels as though it holds liquid. When you drink it, you become invisible for 1 hour. Anything you wear or carry is invisible with you. The effect ends early if you attack or cast a spell.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gain Invisible condition for 1 hour (ends if you attack, cast a spell, or deal damage).',
        description: 'Drink as a Bonus Action: gain Invisible condition for 1 hour. Ends if you make an attack roll, cast a spell, or deal damage.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'invisibility', 'stealth'],
    ),

    // Potion of Speed
    MagicItem(
      id: 'item_potion_of_speed',
      name: 'Potion of Speed',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Gain Haste for 1 Minute without Concentration (Doubles Speed, +2 AC, Advantage on DEX Saves, Extra Action)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain the effect of the Haste spell for 1 minute (no concentration required).',
        description: 'When you drink this potion, you gain the effect of the Haste spell for 1 minute (no concentration required). The yellow fluid is streaked with black and swirls on its own.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gain Haste effect for 1 minute without concentration. Lethargy follows when it ends.',
        description: 'Drink as a Bonus Action: gain the benefits of the Haste spell for 1 minute without requiring Concentration. When the effect ends, you experience wave of lethargy.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'speed', 'haste', 'buff'],
    ),

    // Oil of Sharpness
    MagicItem(
      id: 'item_oil_of_sharpness',
      name: 'Oil of Sharpness',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Coat Weapon or 5 Ammunition: Grants +3 Bonus to Attack & Damage for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Coat a slashing or piercing weapon or up to 5 pieces of ammunition: gains a +3 bonus to attack and damage rolls for 1 hour.',
        description: 'This clear, gelatinous oil sparkles with tiny, ultrathin silver shards. The oil can coat one slashing or piercing weapon or up to 5 pieces of slashing or piercing ammunition. Applying the oil takes 1 minute. For 1 hour, the coated item is magical and has a +3 bonus to attack and damage rolls.',
        activation: '1 Minute to Apply',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Apply to weapon or 5 pieces of ammo: grants +3 attack and damage rolls for 1 hour.',
        description: 'Take 1 minute to coat a weapon or 5 ammunition: grants +3 to attack and damage rolls for 1 hour.',
        activation: '1 Minute to Apply',
      ),
      isChangedIn2024: false,
      tags: ['oil', 'sharpness', 'weapon buff', 'damage'],
    ),

    // Oil of Slipperiness
    MagicItem(
      id: 'item_oil_of_slipperiness',
      name: 'Oil of Slipperiness',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Freedom of Movement for 8 Hours; Or Pour as 10-ft Square Grease'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Apply to creature for Freedom of Movement for 8 hours, or pour on ground to create a 10-foot square Grease spell area for 8 hours.',
        description: 'This sticky black oil is thick and heavy. Applying it to a creature takes 10 minutes. For 8 hours, the creature gains the effect of the Freedom of Movement spell. Alternatively, the oil can be poured on the ground as an action, covering a 10-foot square with the effect of a Grease spell for 8 hours.',
        activation: '10 Minutes / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Freedom of Movement for 8 hours (applied to body), or creates 10 ft Grease surface for 8 hours.',
        description: 'Apply to body over 10 minutes for 8 hours of Freedom of Movement, or pour as an Action for a permanent 10-ft Grease area.',
        activation: '10 Minutes / 1 Action',
      ),
      isChangedIn2024: false,
      tags: ['oil', 'slipperiness', 'freedom of movement', 'grease'],
    ),

    // Potion of Water Breathing
    MagicItem(
      id: 'item_potion_of_water_breathing',
      name: 'Potion of Water Breathing',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Breathe Underwater for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You can breathe underwater for 1 hour after drinking this potion.',
        description: 'You can breathe underwater for 1 hour after drinking this potion. Its cloudy green fluid smells of the sea and has a jellyfish-like bubble floating in it.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: breathe underwater for 1 hour.',
        description: 'Drink as a Bonus Action: gain the ability to breathe underwater for 1 hour.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'water breathing', 'aquatic', 'utility'],
    ),

    // Potion of Vitality
    MagicItem(
      id: 'item_potion_of_vitality',
      name: 'Potion of Vitality',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Cures Exhaustion, Disease & Poison; Maximizes all Hit Dice rolled for 24 Hours'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Cures all diseases and poison, removes all exhaustion, and maximizes all hit points restored from Hit Dice for the next 24 hours.',
        description: 'When you drink this potion, it removes any exhaustion you are suffering and cures any disease or poison affecting you. For the next 24 hours, whenever you regain hit points from rolling Hit Dice during a short rest, maximize the number of hit points restored.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Removes all Exhaustion, cures Poisoned/Disease conditions, and maximizes all Hit Dice healing for 24 hours.',
        description: 'Drink as a Bonus Action: cleanses all Exhaustion levels and cures all active diseases and poisons. For the next 24 hours, rolling Hit Point Dice automatically restores maximum HP.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'vitality', 'exhaustion', 'disease', 'healing'],
    ),

    // Potion of Heroism
    MagicItem(
      id: 'item_potion_of_heroism',
      name: 'Potion of Heroism',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Gain 10 Temp HP & Bless spell effect (+1d4 on Attacks & Saves) for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'For 1 hour after drinking it, you gain 10 temporary hit points that last for 1 hour, and you are under the effect of the Bless spell (no concentration required).',
        description: 'For 1 hour after drinking it, you gain 10 temporary hit points that last for 1 hour, and you are under the effect of the Bless spell (no concentration required).',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gain 10 Temp HP and Bless (+1d4 to attack rolls and saving throws) for 1 hour without concentration.',
        description: 'Drink as a Bonus Action: gain 10 Temporary HP and the Bless spell effect for 1 hour (no Concentration required).',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      diffHighlights: [
        '2024: Bonus action drinking.',
      ],
      tags: ['potion', 'heroism', 'bless', 'temp hp', 'buff'],
    ),
  ];
}
