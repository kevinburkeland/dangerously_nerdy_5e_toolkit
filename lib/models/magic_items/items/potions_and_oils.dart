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

    // Potion of Animal Friendship
    MagicItem(
      id: 'item_potion_of_animal_friendship',
      name: 'Potion of Animal Friendship',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Cast Animal Friendship (DC 13) for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you can cast the Animal Friendship spell (save DC 13) for 1 hour at will.',
        description: 'A muddy liquid that smells of wet fur and fresh grass.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: cast Animal Friendship (DC 13) for 1 hour.',
        description: 'Drink as a Bonus Action to charm beasts for 1 hour.',
        activation: '1 Bonus Action',
        savingThrowDc: 'Your Spell Save DC or DC 13',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'animal friendship', 'charm', 'beasts'],
    ),

    // Potion of Clairvoyance
    MagicItem(
      id: 'item_potion_of_clairvoyance',
      name: 'Potion of Clairvoyance',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Gain Clairvoyance Spell Effect for 10 Minutes'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain the effect of the Clairvoyance spell for 10 minutes.',
        description: 'A yellowish liquid with an eyeball floating in it that vanishes upon consumption.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: gain Clairvoyance for 10 minutes.',
        description: 'Drink as a Bonus Action to create an invisible sensor to see or hear a familiar location within 1 mile.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'clairvoyance', 'scrying', 'divination'],
    ),

    // Potion of Climbing
    MagicItem(
      id: 'item_potion_of_climbing',
      name: 'Potion of Climbing',
      category: ItemCategory.potion,
      rarity: ItemRarity.common,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Climb Speed equal to Walk Speed & Advantage on Athletics (Climbing) for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain a climbing speed equal to your walking speed for 1 hour and have advantage on Strength (Athletics) checks made to climb.',
        description: 'A chalky white liquid that tastes of limestone.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: gain Climb Speed and Advantage on climbing checks for 1 hour.',
        description: 'Drink as a Bonus Action: gain Climb Speed equal to your Speed and Advantage on Athletics checks to climb.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'climbing', 'mobility', 'athletics'],
    ),

    // Potion of Diminution
    MagicItem(
      id: 'item_potion_of_diminution',
      name: 'Potion of Diminution',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Shrink to Half Size / 1/8 Weight for 1d4 Hours (-1d4 Weapon Dmg, Adv on Stealth)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain the \'Reduce\' effect of the Enlarge/Reduce spell for 1d4 hours. Dimensions are halved, weight is divided by 8, and weapons deal 1d4 less damage (minimum 1).',
        description: 'The red liquid in the bottle constantly shrinks down and expands.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: reduce size category by one for 1d4 hours with advantage on Stealth checks.',
        description: 'Drink as a Bonus Action: size halves, gaining Advantage on Dexterity (Stealth) checks and fitting into tiny crevices.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'diminution', 'reduce', 'stealth', 'utility'],
    ),

    // Potion of Gaseous Form
    MagicItem(
      id: 'item_potion_of_gaseous_form',
      name: 'Potion of Gaseous Form',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Gain Gaseous Form for 1 Hour (Fly Speed 10 ft, Damage Resistance, Pass Tiny Cracks)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain the effect of the Gaseous Form spell for 1 hour (no concentration required) or until you dismiss it as a bonus action.',
        description: 'The container seems to hold swirling fog that turns to mist as it is uncorked.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: transform into a misty cloud for 1 hour without concentration.',
        description: 'Drink as a Bonus Action: gain Fly Speed 10 ft, Resistance to nonmagical damage, and pass through any opening where air can pass.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'gaseous form', 'mist', 'infiltrate', 'defense'],
    ),

    // Potion of Growth
    MagicItem(
      id: 'item_potion_of_growth',
      name: 'Potion of Growth',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Enlarge Size for 1d4 Hours (+1d4 Weapon Damage & Adv on STR Checks/Saves)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain the \'Enlarge\' effect of the Enlarge/Reduce spell for 1d4 hours. Your size doubles in all dimensions, weight is multiplied by 8, and weapon attacks deal an extra 1d4 damage.',
        description: 'The red medicinal fluid pulses rhythmically in its vial.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: increase size by one category for 1d4 hours (+1d4 damage on weapon attacks).',
        description: 'Drink as a Bonus Action: grow to Large (or Huge), gaining +1d4 weapon damage and Advantage on Strength checks and saves.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'growth', 'enlarge', 'damage bonus', 'strength'],
    ),

    // Potion of Invulnerability
    MagicItem(
      id: 'item_potion_of_invulnerability',
      name: 'Potion of Invulnerability',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Gain Resistance to ALL Damage for 1 Minute'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'For 1 minute after you drink this potion, you have resistance to all damage.',
        description: 'A syrupy golden liquid that gleams like polished steel.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: gain Resistance to ALL damage types for 1 minute.',
        description: 'Drink as a Bonus Action: gives comprehensive 50% damage reduction across every single damage type for 1 full minute.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'invulnerability', 'resistance', 'tank', 'defense'],
    ),

    // Potion of Longevity
    MagicItem(
      id: 'item_potion_of_longevity',
      name: 'Potion of Longevity',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Reduces Physical Age by 1d6 + 6 Years (10% Cumulative Aging Risk)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Drinking this potion reduces your physical age by 1d6 + 6 years (to a minimum of 13 years). Each subsequent potion drunk has a cumulative 10% chance to AGE you by 1d6 + 6 years instead.',
        description: 'An iridescent amber elixir with an ever-dancing silver thread inside.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Reduces physical age by 1d6 + 6 years. Repeated drinks have cumulative 10% aging risk.',
        description: 'An elixir of youth reversing natural physical aging by 1d6 + 6 years.',
        activation: '1 Action',
      ),
      tags: ['potion', 'longevity', 'youth', 'age'],
    ),

    // Potion of Mind Reading
    MagicItem(
      id: 'item_potion_of_mind_reading',
      name: 'Potion of Mind Reading',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Gain Detect Thoughts Spell Effect for 1 Hour (DC 13 / Caster DC)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain the effect of the Detect Thoughts spell (save DC 13) for 1 hour.',
        description: 'A dense purple liquid that hums with faint psychic resonance.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: gain Detect Thoughts for 1 hour using your own Spell Save DC or DC 13.',
        description: 'Drink as a Bonus Action to read surface thoughts and probe minds within 30 feet.',
        activation: '1 Bonus Action',
        savingThrowDc: 'Your Spell Save DC or DC 13',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'mind reading', 'detect thoughts', 'telepathy', 'psychic'],
    ),

    // Potion of Poison
    MagicItem(
      id: 'item_potion_of_poison',
      name: 'Potion of Poison',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.poison,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Deals 3d6 Poison Damage & Poisoned Condition (DC 13 CON Save at Turn Start for 3d6 per round)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Deceptively looks, smells, and tastes like a Potion of Healing. When drunk, deals 3d6 poison damage and forces DC 13 Con save or poisoned condition, taking 3d6 poison at turn start until saved.',
        description: 'A deceitful concoction magically disguised as restorative healing draught.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Disguised poison potion dealing 3d6 poison damage and continuous Poisoned condition on DC 13 Con save.',
        description: 'Trap potion inflicting severe poison damage and debuff.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      tags: ['potion', 'poison', 'trap', 'debuff', 'cursed'],
    ),

    // Potion of Resistance
    MagicItem(
      id: 'item_potion_of_resistance',
      name: 'Potion of Resistance',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Resistance to 1 Damage Type (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, Thunder) for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, you gain resistance to one type of damage for 1 hour (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, or Thunder).',
        description: 'A thick, viscous fluid that reflects the elemental energy it protects against.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: gain Resistance to one designated damage type for 1 hour.',
        description: 'Drink as a Bonus Action: grants 1 hour of Resistance to an elemental or energy damage type.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'resistance', 'elemental', 'defense'],
    ),

    // Oil of Etherealness
    MagicItem(
      id: 'item_oil_of_etherealness',
      name: 'Oil of Etherealness',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Apply in 10 Minutes: Gain Etherealness Spell Effect for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Takes 10 minutes to apply to a Medium or smaller creature. Gains the effect of the Etherealness spell for 1 hour.',
        description: 'Beads of this cloudy gray oil evaporate into tiny wisps of ethereal mist when uncorked.',
        activation: '10 Minutes to Apply',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Apply in 10 minutes for 1 hour of Etherealness border plane phasing.',
        description: 'Coats a creature in ethereal film, allowing it to move through walls and creatures on the Border Ethereal.',
        activation: '10 Minutes to Apply',
      ),
      tags: ['oil', 'etherealness', 'phase', 'infiltrate'],
    ),

    // Philter of Love
    MagicItem(
      id: 'item_philter_of_love',
      name: 'Philter of Love',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Charmed by Next Creature Seen for 1 Hour (Regards as True Love)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'The next time you see a creature within 10 minutes after drinking this philter, you become charmed by that creature for 1 hour and regard it as your true love.',
        description: 'A sparkling rose-colored liquid containing a floating bubble shaped like a miniature heart.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: charmed by the next creature seen for 1 hour, treating it as true love.',
        description: 'Enchantment draught inducing romantic devotion toward the first creature perceived.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'charm', 'love', 'enchantment', 'social'],
    ),

    // Elixir of Health
    MagicItem(
      id: 'item_elixir_of_health',
      name: 'Elixir of Health',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Cures all Diseases, Blindness, Deafness, Paralyzed & Poisoned Conditions'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you drink this potion, it cures any disease afflicting you, and it removes the blinded, deafened, paralyzed, and poisoned conditions.',
        description: 'A pure, crystalline liquid that glows with faint restorative luminescence.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action to drink: cleanses all active diseases and removes Blinded, Deafened, Paralyzed, and Poisoned conditions.',
        description: 'Drink as a Bonus Action: instantly ends all disease and major sensory/debilitating conditions.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking is a Bonus Action in 2024.',
      tags: ['potion', 'elixir', 'cure', 'cleansing', 'healing'],
    ),
  ];
}
