import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Wondrous Items Catalog
class SrdWondrousItems {
  SrdWondrousItems._();

  static const List<MagicItem> items = [
    // Bag of Holding
    MagicItem(
      id: 'item_bag_of_holding',
      name: 'Bag of Holding',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Holds 500 lbs / 64 cu ft (Weighs 15 lbs)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Opens into an extradimensional space holding up to 500 pounds and 64 cubic feet while weighing 15 pounds.',
        description: 'This bag has an interior space considerably larger than its outside dimensions, roughly 2 feet in diameter at the mouth and 4 feet deep. The bag can hold up to 500 pounds, not exceeding a volume of 64 cubic feet. The bag always weighs 15 pounds, regardless of its contents. Breathing creatures inside can survive for 10 minutes divided by the number of creatures. Placing a bag of holding inside an extradimensional space created by a handy haversack, portable hole, or similar item instantly destroys both items and opens a gate to the Astral Plane.',
        activation: '1 Action (Retrieve item)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Extradimensional space holding up to 500 lbs / 64 cu ft. Breathing creatures have 10 minutes of air.',
        description: 'An extradimensional container that holds up to 500 pounds and 64 cubic feet while weighing only 15 pounds. Overloading, puncturing, or placing inside another extradimensional space destroys the bag and opens a portal to the Astral Plane.',
        activation: '1 Action / Object Interaction',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'bag', 'storage', 'extradimensional', 'utility'],
    ),

    // Cloak of Protection
    MagicItem(
      id: 'item_cloak_of_protection',
      name: 'Cloak of Protection',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 to AC & Saving Throws'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You gain a +1 bonus to AC and saving throws while you wear this cloak.',
        description: 'You gain a +1 bonus to AC and saving throws while you wear this cloak.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You gain a +1 bonus to AC and all saving throws while wearing this cloak.',
        description: 'You gain a +1 bonus to AC and all saving throws while wearing this cloak.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'cloak', 'ac', 'defense'],
    ),

    // Deck of Many Things
    MagicItem(
      id: 'item_deck_of_many_things',
      name: 'Deck of Many Things',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.legendary, label: 'Draw Fate-Altering Arcane Cards'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Deck of 13 or 22 cards containing cosmic fortunes, instant destruction, demon enmities, and wish grants.',
        description: 'Usually found in a box or pouch, this deck contains a number of cards made of ivory or vellum (13 or 22 cards). Before you draw a card, you must declare how many cards you intend to draw. Cards drawn take effect immediately (e.g. Skull summons Avatar of Death, Void draws your soul away, Knight grants a 4th-level fighter follower, Moon grants 1d3 Wish spells).',
        activation: '1 Action (Declare & Draw)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Iconic deck of fate-altering cards updated with modernized conditions and escape mechanics for catastrophic cards.',
        description: 'The 2024 Deck of Many Things refines classic card mechanics to provide engaging gameplay counters and clearer resolution steps while preserving epic legendary stakes.',
        activation: '1 Action (Declare & Draw)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Catastrophic cards (Donjon, Void) given clearer resolution and rescue mechanics.',
      diffHighlights: [
        '2024: Card mechanics modernized to prevent non-interactive permanent character loss.',
      ],
      tags: ['wondrous', 'deck', 'cards', 'fate', 'legendary'],
    ),

    // Boots of Speed
    MagicItem(
      id: 'item_boots_of_speed',
      name: 'Boots of Speed',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Bonus Action: Double Speed & Opportunity Disadvantage (10 Min)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Use a bonus action to click heels: doubles walking speed for 10 minutes and opportunity attacks against you have disadvantage.',
        description: 'While you wear these boots, you can use a bonus action and click the boots\' heels together. If you do, the boots double your walking speed, and any creature that makes an opportunity attack against you has disadvantage on the attack roll. The boots have a duration of 10 minutes (usable in increments of 1 minute) and regain 2 hours of duration per long rest.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action: doubles Speed for up to 10 minutes and gives Opportunity Attacks Disadvantage against you.',
        description: 'Click heels as a Bonus Action: doubles your Speed for up to 10 minutes (can be used in 1-minute increments). Opportunity Attacks against you have Disadvantage. Regains all expended time on a Long Rest.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'boots', 'speed', 'movement'],
    ),

    // Cloak of Displacement
    MagicItem(
      id: 'item_cloak_of_displacement',
      name: 'Cloak of Displacement',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Illusion Displaces You: Attack Rolls Have Disadvantage'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Projects an illusion making you appear in a different spot; attacks against you have disadvantage until you take damage.',
        description: 'While you wear this cloak, it projects an illusion that makes you appear to be standing in a place a few inches from your actual location, causing any creature to have disadvantage on attack rolls against you. If you take damage, the property is suppressed until the start of your next turn. This property is also suppressed while you are incapacitated or unable to move.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Attack rolls against you have Disadvantage; suppressed until your next turn if you take damage.',
        description: 'While wearing this cloak, attack rolls against you have Disadvantage due to an optical displacement illusion. If you take damage or have the Incapacitated condition, the property is suppressed until the start of your next turn.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'cloak', 'defense', 'illusion', 'disadvantage'],
    ),

    // Gauntlets of Ogre Power
    MagicItem(
      id: 'item_gauntlets_of_ogre_power',
      name: 'Gauntlets of Ogre Power',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Sets Strength Score to 19 (+4 Mod)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Your Strength score is 19 while you wear these gauntlets. Has no effect if your Strength is already 19 or higher.',
        description: 'Your Strength score is 19 while you wear these gauntlets. They have no effect on you if your Strength is already 19 or higher.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Your Strength score becomes 19 while wearing these gauntlets.',
        description: 'Your Strength score is 19 while you wear these gauntlets. They have no effect if your Strength score is already 19 or higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'strength', 'gauntlets', 'stat increase'],
    ),

    // Headband of Intellect
    MagicItem(
      id: 'item_headband_of_intellect',
      name: 'Headband of Intellect',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Sets Intelligence Score to 19 (+4 Mod)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Your Intelligence score is 19 while you wear this headband. Has no effect if your Intelligence is already 19 or higher.',
        description: 'Your Intelligence score is 19 while you wear this headband. It has no effect on you if your Intelligence is already 19 or higher.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Your Intelligence score becomes 19 while wearing this headband.',
        description: 'Your Intelligence score is 19 while you wear this headband. It has no effect if your Intelligence score is already 19 or higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'intelligence', 'headband', 'stat increase'],
    ),

    // Pearl of Power
    MagicItem(
      id: 'item_pearl_of_power',
      name: 'Pearl of Power',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Regain 1 Expended Spell Slot up to 3rd Level (1/Day)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Use an action to speak command word and regain 1 expended spell slot of up to 3rd level once per day.',
        description: 'While this pearl is on your person, you can use an action to speak its command word and regain one expended spell slot. If the expended slot was of 4th level or higher, the new slot is 3rd level. Once you use the pearl, it can\'t be used again until the next dawn.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: regain 1 expended spell slot of level 1–3 once per Long Rest.',
        description: 'While holding or carrying this pearl, you can use an Action to regain one expended spell slot of up to level 3 (once per Long Rest).',
        activation: '1 Action (1/Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'pearl', 'spell slot', 'spellcaster'],
    ),

    // Robe of the Archmagi
    MagicItem(
      id: 'item_robe_of_the_archmagi',
      name: 'Robe of the Archmagi',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      attunementRequirement: 'by a Sorcerer, Warlock, or Wizard',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 15 + Dex & Advantage on Saves vs Spells'),
        ActionTraitRing(ringType: ActionRingType.legendary, label: '+2 to Spell Save DC & Spell Attack Rolls'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Base AC 15 + Dex modifier, advantage on saving throws against spells and magical effects, and +2 bonus to spell save DCs and spell attack rolls.',
        description: 'This garment comes in white (good), gray (neutral), or black (evil). You gain these benefits while wearing it: your base AC becomes 15 + your Dexterity modifier; you have advantage on saving throws against spells and other magical effects; and your spell save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
        description: 'While wearing this robe, your base Armor Class equals 15 + Dexterity modifier. You have Advantage on saving throws against spells and magical effects, and your Spell Save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'robe', 'archmagi', 'wizard', 'sorcerer', 'warlock', 'legendary'],
    ),

    // Bag of Tricks
    MagicItem(
      id: 'item_bag_of_tricks',
      name: 'Bag of Tricks',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Pull & Summon 1d8 Random Beast Minion (3/Day)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Use an action to pull a furry object and throw it up to 20 feet: summons a friendly beast determined by rolling on the bag\'s d8 table (3 times per day).',
        description: 'This ordinary cloth sack appears empty. Reaching inside pulls out a small fuzzy ball. As an action, you can throw it up to 20 feet. When it lands, it transforms into a friendly beast rolled on the table (Gray, Rust, or Tan). You can summon up to 3 creatures per day (recharges daily at dawn). The beasts act on your turn and obey your verbal commands.',
        activation: '1 Action (3/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: throw a fuzzy ball up to 20 ft to summon a friendly beast from the d8 table (3 creatures per Long Rest).',
        description: 'Pull a fuzzy ball from the bag and throw it up to 20 feet as an Action. It turns into a friendly beast chosen by rolling a d8. Up to 3 creatures per Long Rest.',
        activation: '1 Action (3/Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'bag', 'summon', 'beast', 'tricks', 'minions'],
    ),

    // Horn of Valhalla
    MagicItem(
      id: 'item_horn_of_valhalla',
      name: 'Horn of Valhalla',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Action: Blow Horn to Summon Berserker Warrior Squad (1/7 Days)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Blow the horn to summon a squad of legendary warrior spirits from Ysgard (Silver 2d4+2, Brass 3d4+3, Bronze 4d4+4, Iron 5d4+5) for 1 hour.',
        description: 'You can use an action to blow this horn. In response, warrior spirits from Ysgard appear within 60 feet of you. They use the Berserker stat block and are friendly to you and your companions. They return to Ysgard after 1 hour or when reduced to 0 hit points. Once you blow the horn, it can\'t be blown again for 7 days.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Summon an allied squad of spirit Berserkers for 1 hour (recharges every 7 days).',
        description: 'Blow the horn as an Action to summon Berserker warrior spirits that fight alongside you for up to 1 hour (usable once every 7 days).',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'horn', 'summon', 'valhalla', 'berserker', 'warrior'],
    ),

    // Figurine of Wondrous Power
    MagicItem(
      id: 'item_figurine_of_wondrous_power',
      name: 'Figurine of Wondrous Power',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Animate Statuette into Living Creature Mount/Companion'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Statue of a creature (Bronze Griffon, Onyx Dog, Marble Elephant, etc.) that transforms into a living creature when command word is spoken.',
        description: 'A figurine of wondrous power is a statuette small enough to fit in a pocket. If you use an action to speak the command word and throw the figurine to a point on the ground within 60 feet of you, it becomes a living creature (Bronze Griffon for 24 hours, Onyx Dog for 6 hours, Marble Elephant for 24 hours). It understands your languages and obeys your spoken commands.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: throw figurine up to 60 ft and speak command word to animate into a loyal living creature/mount.',
        description: 'Throw the statuette up to 60 feet and speak its command word as an Action: transforms into a loyal living creature companion that obeys your verbal commands.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'figurine', 'summon', 'mount', 'griffon', 'elephant', 'companion'],
    ),

    // Elemental Gem
    MagicItem(
      id: 'item_elemental_gem',
      name: 'Elemental Gem',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Crush Gem to Summon Elemental (Air, Earth, Fire, or Water)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Use an action to break the gem: casts Conjure Elemental summoning an elemental corresponding to the gem type (Air, Earth, Fire, or Water).',
        description: 'This gem contains a mote of elemental energy. When you use an action to break the gem, an elemental appears as if you had cast the conjure elemental spell. The gem determines the elemental summoned: Blue Sapphire (Air Elemental), Yellow Diamond (Earth Elemental), Red Corundum (Fire Elemental), or Emerald (Water Elemental). The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: crush gem to summon a CR 5 Elemental (Air, Earth, Fire, or Water) for up to 1 hour.',
        description: 'Break the gem as an Action to summon a friendly CR 5 Elemental companion for up to 1 hour (consumable).',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'gem', 'elemental', 'summon', 'fire', 'water', 'air', 'earth'],
    ),
  ];
}
