import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Potions and Oils Catalog
class SrdPotionsAndOils {
  SrdPotionsAndOils._();

  static const List<MagicItem> items = [
    // Potion of Healing
    MagicItem(
      id: 'item_potion_of_healing',
      name: 'Potion of Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.common,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Regain 2d4 + 2 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Drinking or administering this potion restores 2d4 + 2 hit points as an Action.',
        description: 'You regain 2d4 + 2 hit points when you drink this potion. The potion\'s red liquid glimmers when agitated. Drinking it or administering it to another creature requires an Action.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Drinking this potion yourself is a Bonus Action; administering to another creature is an Action (restores 2d4 + 2 HP).',
        description: 'You regain 2d4 + 2 Hit Points when you drink this potion. Drinking a potion yourself is a Bonus Action. Administering a potion to another creature takes an Action.',
        activation: '1 Bonus Action (Self) / 1 Action (Other)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Drinking a potion on yourself takes a Bonus Action instead of an Action.',
      diffHighlights: [
        '2024: Drinking yourself now requires a Bonus Action (previously an Action in 2014).',
        '2024: Administering to another creature still requires an Action.',
      ],
      tags: ['potion', 'healing', 'hp', 'common'],
    ),

    // Potion of Greater Healing
    MagicItem(
      id: 'item_potion_of_greater_healing',
      name: 'Potion of Greater Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Regain 4d4 + 4 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Restores 4d4 + 4 hit points as an Action.',
        description: 'You regain 4d4 + 4 hit points when you drink this potion as an Action.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Restores 4d4 + 4 Hit Points (Bonus Action self / Action other).',
        description: 'You regain 4d4 + 4 Hit Points when you drink this potion as a Bonus Action (or Action if administered to another).',
        activation: '1 Bonus Action (Self) / 1 Action (Other)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Bonus Action to drink yourself in 2024.',
      diffHighlights: [
        '2024: Bonus Action self-consumption.',
      ],
      tags: ['potion', 'healing', 'uncommon'],
    ),

    // Potion of Superior Healing
    MagicItem(
      id: 'item_potion_of_superior_healing',
      name: 'Potion of Superior Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Regain 8d4 + 8 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Restores 8d4 + 8 hit points as an Action.',
        description: 'You regain 8d4 + 8 hit points when you drink this potion.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Restores 8d4 + 8 Hit Points (Bonus Action self / Action other).',
        description: 'You regain 8d4 + 8 Hit Points when you drink this potion as a Bonus Action.',
        activation: '1 Bonus Action (Self) / 1 Action (Other)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Bonus Action to drink yourself in 2024.',
      diffHighlights: [
        '2024: Bonus Action self-consumption.',
      ],
      tags: ['potion', 'healing', 'rare'],
    ),

    // Potion of Supreme Healing
    MagicItem(
      id: 'item_potion_of_supreme_healing',
      name: 'Potion of Supreme Healing',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Regain 10d4 + 20 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Restores 10d4 + 20 hit points as an Action.',
        description: 'You regain 10d4 + 20 hit points when you drink this potion.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Restores 10d4 + 20 Hit Points (Bonus Action self / Action other).',
        description: 'You regain 10d4 + 20 Hit Points when you drink this potion as a Bonus Action.',
        activation: '1 Bonus Action (Self) / 1 Action (Other)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Bonus Action to drink yourself in 2024.',
      diffHighlights: [
        '2024: Bonus Action self-consumption.',
      ],
      tags: ['potion', 'healing', 'very rare'],
    ),

    // Potion of Invisibility
    MagicItem(
      id: 'item_potion_of_invisibility',
      name: 'Potion of Invisibility',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.control, label: 'Invisible for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Become invisible for 1 hour; ends early if you attack or cast a spell.',
        description: 'This potion\'s container looks empty but feels as though it holds liquid. When you drink it, you become invisible for 1 hour. Anything you wear or carry is invisible with you. The effect ends early if you attack or cast a spell.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gain the Invisible condition for 1 hour (ends early if you attack or cast a spell).',
        description: 'When you drink this potion as a Bonus Action, you gain the Invisible condition for 1 hour. The condition ends early if you make an attack roll, deal damage, or cast a spell.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Uses 2024 Invisible condition and Bonus Action consumption.',
      diffHighlights: [
        '2024: Grants formal Invisible condition with revised combat benefits.',
        '2024: Bonus Action to drink.',
      ],
      tags: ['potion', 'invisible', 'stealth'],
    ),

    // Potion of Speed
    MagicItem(
      id: 'item_potion_of_speed',
      name: 'Potion of Speed',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Haste for 1 Minute without Concentration'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Gain the effect of the Haste spell for 1 minute without requiring concentration.',
        description: 'When you drink this potion, you gain the effect of the haste spell for 1 minute (no concentration required). The potion\'s yellow fluid is streaked with black and swirls on its own.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gain Haste effect for 1 minute without concentration (Bonus Action consumption).',
        description: 'When you drink this potion as a Bonus Action, you gain the effects of the Haste spell for 1 minute without requiring Concentration. When the effect ends, you experience the lethargy wave.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Bonus Action consumption in 2024.',
      diffHighlights: [
        '2024: Bonus Action consumption.',
      ],
      tags: ['potion', 'haste', 'speed', 'buff'],
    ),

    // Potion of Flying
    MagicItem(
      id: 'item_potion_of_flying',
      name: 'Potion of Flying',
      category: ItemCategory.potion,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Fly Speed equal to Walking Speed (1 Hour)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Gain a flying speed equal to your walking speed for 1 hour and can hover.',
        description: 'When you drink this potion, you gain a flying speed equal to your walking speed for 1 hour and can hover. If you\'re in the air when the duration ends, you descend at a rate of 30 feet per round until you land.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gain Fly speed equal to Speed with Hover for 1 hour (Bonus Action consumption).',
        description: 'When you drink this potion as a Bonus Action, you gain a Fly speed equal to your Speed for 1 hour with the Hover ability. If airborne when the duration expires, you descend safely at 30 ft/round.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Bonus Action consumption in 2024.',
      diffHighlights: [
        '2024: Bonus Action consumption.',
      ],
      tags: ['potion', 'flying', 'speed'],
    ),

    // Potion of Giant Strength
    MagicItem(
      id: 'item_potion_of_giant_strength',
      name: 'Potion of Giant Strength',
      category: ItemCategory.potion,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Strength 21-29 for 1 Hour'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Your Strength score increases to a fixed value (Hill: 21, Frost/Stone: 23, Fire: 25, Cloud: 27, Storm: 29) for 1 hour.',
        description: 'When you drink this potion, your Strength score changes for 1 hour. The type of giant determines the score (Hill Giant: 21, Frost/Stone Giant: 23, Fire Giant: 25, Cloud Giant: 27, Storm Giant: 29). The potion has no effect if your Strength is already equal to or greater than that score.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets Strength to 21–29 for 1 hour (Bonus Action consumption).',
        description: 'When you drink this potion as a Bonus Action, your Strength score becomes the giant\'s score for 1 hour (Hill: 21, Stone/Frost: 23, Fire: 25, Cloud: 27, Storm: 29).',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Bonus Action consumption in 2024.',
      diffHighlights: [
        '2024: Bonus Action consumption.',
      ],
      tags: ['potion', 'strength', 'giant', 'buff'],
    ),
  ];
}
