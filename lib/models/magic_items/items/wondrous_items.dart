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
      tags: ['wondrous', 'boots', 'speed', 'mobility'],
    ),

    // Winged Boots
    MagicItem(
      id: 'item_winged_boots',
      name: 'Winged Boots',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Flying Speed equal to Walking Speed (Up to 4 Hours)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While you wear these boots, you have a flying speed equal to your walking speed for up to 4 hours per day.',
        description: 'While you wear these boots, you have a flying speed equal to your walking speed. You can use the boots to fly for up to 4 hours, all at once or in several shorter flights, each one using a minimum of 1 minute. The boots regain 2 hours of flying capability for every 12 hours they aren\'t in use.',
        activation: 'Passive / Movement',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants a Fly Speed equal to your Speed for up to 4 hours (recharges on Long Rest).',
        description: 'Grants a Fly Speed equal to your Speed for up to 4 hours (increments of 1 minute). Regains 2 hours of flight per Long Rest.',
        activation: 'Passive / Movement',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'boots', 'flight', 'mobility'],
    ),

    // Belt of Giant Strength
    MagicItem(
      id: 'item_belt_of_giant_strength',
      name: 'Belt of Giant Strength',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Sets Strength to 21, 23, 25, 27, or 29'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this belt, your Strength score changes to a fixed high score (Hill 21, Stone/Frost 23, Fire 25, Cloud 27, Storm 29).',
        description: 'While wearing this belt, your Strength score changes to a score determined by the belt\'s type (Hill 21, Stone/Frost 23, Fire 25, Cloud 27, Storm 29). If your Strength is already equal to or greater than the belt\'s score, the item has no effect on you.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to a fixed score based on giant tier (Hill 21 to Storm 29).',
        description: 'While wearing this belt, your Strength score equals 21 (Hill, Rare), 23 (Stone/Frost, Very Rare), 25 (Fire, Very Rare), 27 (Cloud, Legendary), or 29 (Storm, Legendary). Has no effect if your Strength is already higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'belt', 'strength', 'giant', 'stat boost'],
    ),

    // Amulet of Health
    MagicItem(
      id: 'item_amulet_of_health',
      name: 'Amulet of Health',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Sets Constitution Score to 19 (+4 Mod)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Your Constitution score is 19 while you wear this amulet. Has no effect if your Constitution is already 19 or higher.',
        description: 'Your Constitution score is 19 while you wear this amulet. It has no effect on you if your Constitution is already 19 or higher without it.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Constitution score to 19 (+4 mod) while worn.',
        description: 'While wearing this amulet, your Constitution score equals 19. Has no effect if your Constitution is already 19 or higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'amulet', 'constitution', 'hp', 'stat boost'],
    ),

    // Headband of Intellect
    MagicItem(
      id: 'item_headband_of_intellect',
      name: 'Headband of Intellect',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Sets Intelligence Score to 19 (+4 Mod)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Your Intelligence score is 19 while you wear this headband. Has no effect if your Intelligence is already 19 or higher.',
        description: 'Your Intelligence score is 19 while you wear this headband. It has no effect on you if your Intelligence is already 19 or higher without it.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets Intelligence score to 19 (+4 mod) while worn.',
        description: 'While wearing this headband, your Intelligence score equals 19. Has no effect if your Intelligence is already 19 or higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'headband', 'intelligence', 'stat boost'],
    ),

    // Gauntlets of Ogre Power
    MagicItem(
      id: 'item_gauntlets_of_ogre_power',
      name: 'Gauntlets of Ogre Power',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Sets Strength Score to 19 (+4 Mod)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Your Strength score is 19 while you wear these gauntlets. Has no effect if your Strength is already 19 or higher.',
        description: 'Your Strength score is 19 while you wear these gauntlets. It has no effect on you if your Strength is already 19 or higher without them.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets Strength score to 19 (+4 mod) while worn.',
        description: 'While wearing these gauntlets, your Strength score equals 19. Has no effect if your Strength is already 19 or higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'gauntlets', 'strength', 'stat boost'],
    ),

    // Bracers of Archery
    MagicItem(
      id: 'item_bracers_of_archery',
      name: 'Bracers of Archery',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 Damage with Longbows & Shortbows; Bow Proficiency'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Grants proficiency with longbows and shortbows, and a +2 bonus to damage rolls with ranged attacks made with them.',
        description: 'While wearing these bracers, you have proficiency with the longbow and shortbow, and you gain a +2 bonus to damage rolls on ranged attacks made with such weapons.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Proficiency with Longbow and Shortbow; +2 damage on attacks made with those weapons.',
        description: 'Grants proficiency with the Longbow and Shortbow and adds a +2 bonus to damage rolls made with them.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'bracers', 'archery', 'bow', 'damage'],
    ),

    // Bracers of Defense
    MagicItem(
      id: 'item_bracers_of_defense',
      name: 'Bracers of Defense',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 to AC while Wearing No Armor and No Shield'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing these bracers, you gain a +2 bonus to AC if you are wearing no armor and using no shield.',
        description: 'While wearing these bracers, you gain a +2 bonus to AC if you are wearing no armor and using no shield.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC while not wearing armor or wielding a shield.',
        description: 'You gain a +2 bonus to AC while wearing these bracers if you are wearing no armor and wielding no Shield.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'bracers', 'ac', 'defense', 'monk', 'wizard'],
    ),

    // Cloak of Elvenkind
    MagicItem(
      id: 'item_cloak_of_elvenkind',
      name: 'Cloak of Elvenkind',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Advantage on Stealth & Disadvantage on Perception to see you'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While you wear this cloak with its hood up, Wisdom (Perception) checks made to see you have disadvantage, and you have advantage on Dexterity (Stealth) checks made to hide.',
        description: 'While you wear this cloak with its hood up, Wisdom (Perception) checks made to see you have disadvantage, and you have advantage on Dexterity (Stealth) checks made to hide, as the cloak\'s color shifts to camouflage you. Pulling the hood up or down requires an action.',
        activation: '1 Action (Toggle Hood) / Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Advantage on Stealth checks and Disadvantage on Perception checks made to spot you.',
        description: 'While wearing this cloak with its hood up, you have Advantage on Dexterity (Stealth) checks, and Wisdom (Perception) checks made to see you have Disadvantage.',
        activation: '1 Action / Bonus Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'cloak', 'stealth', 'elvenkind'],
    ),

    // Cloak of Invisibility
    MagicItem(
      id: 'item_cloak_of_invisibility',
      name: 'Cloak of Invisibility',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Become Invisible (Up to 2 Hours Total)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Pull up the hood as an action to become invisible for up to 2 hours (recharges 1 hour per 12 hours unused).',
        description: 'While wearing this cloak, you can pull its hood up over your head as an action to become invisible. While you are invisible, anything you are carrying or wearing is also invisible. You remain invisible until you pull the hood down. The cloak has a duration of 2 hours, used in 1-minute increments.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: become Invisible for up to 2 hours (recharges on Long Rest).',
        description: 'Pull the hood up as an Action to gain the Invisible condition for up to 2 hours. Regains all expended time on a Long Rest.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'cloak', 'invisibility', 'legendary', 'stealth'],
    ),

    // Cloak of the Bat
    MagicItem(
      id: 'item_cloak_of_the_bat',
      name: 'Cloak of the Bat',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Advantage on Stealth; Fly 40 ft in Dim Light / Darkness; Polymorph into Bat'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Advantage on Stealth checks. In dim light or darkness, grants flying speed of 40 feet and ability to cast Polymorph on yourself to become a bat.',
        description: 'While wearing this cloak, you have advantage on Dexterity (Stealth) checks. In an area of dim light or darkness, you can grip the edges of the cloak with both hands and use it to fly with a speed of 40 feet. If you ever fail to grip the cloak\'s edges or leave dim light/darkness, you lose this flying speed. You can also cast Polymorph on yourself to transform into a bat once per day.',
        activation: '1 Action (Polymorph) / Movement',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Advantage on Stealth; Fly 40 ft in Dim Light/Darkness; cast Polymorph (Bat only) once per Long Rest.',
        description: 'Grants Advantage on Stealth checks, Fly Speed 40 ft in darkness/dim light while holding the cloak with both hands, and cast Polymorph on yourself (Bat) once per Long Rest.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'cloak', 'bat', 'stealth', 'fly', 'polymorph'],
    ),

    // Driftglobe
    MagicItem(
      id: 'item_driftglobe',
      name: 'Driftglobe',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Light spell at will; Daylight spell (1/Day); Floats and follows within 60 ft'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Cast Light at will, Daylight once per day, and command the globe to hover and follow you within 60 feet.',
        description: 'This small sphere of thick glass can be commanded to cast Light at will or Daylight once per day. You can speak a command word to make the globe hover and follow you within 60 feet. If you move more than 60 feet from it, it follows you until it is within 60 feet.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: cast Light at will, Daylight once per Long Rest, and commands the globe to hover and follow you.',
        description: 'Glass sphere that casts Light at will, Daylight (1/Long Rest), and hovers alongside you within 60 feet.',
        activation: '1 Action / Bonus Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'driftglobe', 'light', 'utility'],
    ),

    // Goggles of Night
    MagicItem(
      id: 'item_goggles_of_night',
      name: 'Goggles of Night',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Darkvision out to 60 ft (or +60 ft if you already have it)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing these dark lenses, you have darkvision out to a range of 60 feet. If you already have darkvision, wearing the goggles increases its range by 60 feet.',
        description: 'While wearing these dark lenses, you have darkvision out to a range of 60 feet. If you already have darkvision, wearing the goggles increases its range by 60 feet.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants Darkvision with a range of 60 feet (or increases existing Darkvision range by 60 feet).',
        description: 'While wearing these goggles, you have Darkvision out to 60 feet (or +60 ft to your existing Darkvision).',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'goggles', 'darkvision', 'utility'],
    ),

    // Hat of Disguise
    MagicItem(
      id: 'item_hat_of_disguise',
      name: 'Hat of Disguise',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Cast Disguise Self at Will (Action)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this hat, you can use an action to cast the Disguise Self spell from it at will. The spell ends if the hat is removed.',
        description: 'While wearing this hat, you can use an action to cast the Disguise Self spell from it at will. The spell ends if the hat is removed.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: cast Disguise Self at will while wearing this hat.',
        description: 'Cast Disguise Self at will as an Action. The spell ends if the hat is taken off.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'hat', 'disguise', 'illusion'],
    ),

    // Necklace of Fireballs
    MagicItem(
      id: 'item_necklace_of_fireballs',
      name: 'Necklace of Fireballs',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.fire, label: 'Detachable Beads (1d6+3): Throw up to 60 ft for 8d6+ Fireball'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'This necklace has 1d6 + 3 beads. Detach and throw 1 or more beads up to 60 feet: each bead casts Fireball (3rd level + 1 level per additional bead).',
        description: 'This necklace has 1d6 + 3 glowing beads hanging from it. You can use an action to detach a bead and throw it up to 60 feet away. When it reaches the end of its trajectory, it detonates as a 3rd-level fireball spell (save DC 15). You can hurl multiple beads, or even the whole necklace, as one action. Doing so increases the level of the fireball by 1 for each bead beyond the first.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: throw beads up to 60 ft to detonate as Fireball (8d6 Fire + 1d6 per extra bead thrown).',
        description: 'Detach and throw beads up to 60 feet as an Action to detonate as Fireball (DC 15 Dexterity save). Throw multiple beads in one Action to upcast.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'necklace', 'fireball', 'fire', 'aoe', 'consumable'],
    ),

    // Necklace of Adaptation
    MagicItem(
      id: 'item_necklace_of_adaptation',
      name: 'Necklace of Adaptation',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Breathe normally in any environment; Advantage on saves vs harmful gases & vapors'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this necklace, you can breathe normally in any environment, and you have advantage on saving throws made against harmful gases and vapors.',
        description: 'While wearing this necklace, you can breathe normally in any environment, and you have advantage on saving throws made against harmful gases and vapors (such as cloudkill, stinking cloud, inhaled poisons, and the breath weapons of some dragons).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Breathe in any environment; Advantage on saves against gases, vapors, and inhalation hazards.',
        description: 'Grants continuous breathing in water, vacuum, or toxic atmospheres, and Advantage on saving throws vs noxious gases.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'necklace', 'breathing', 'adaptation', 'survival'],
    ),

    // Periapt of Wound Closure
    MagicItem(
      id: 'item_periapt_of_wound_closure',
      name: 'Periapt of Wound Closure',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Stabilize at start of turn at 0 HP; Double HP regained from Hit Dice'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While you wear this pendant, you stabilize whenever you are dying at the start of your turn. In addition, whenever you roll a Hit Die to regain hit points, double the number of hit points it restores.',
        description: 'While you wear this pendant, you stabilize whenever you are dying at the start of your turn. In addition, whenever you roll a Hit Die to regain hit points, double the number of hit points it restores.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Automatic stabilization when dying; doubles all HP restored from Hit Point Dice during Short Rests.',
        description: 'Stabilizes you automatically at the start of your turn if at 0 HP. Doubles HP recovered when rolling Hit Point Dice.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'periapt', 'healing', 'stabilize', 'hit dice'],
    ),

    // Portable Hole
    MagicItem(
      id: 'item_portable_hole',
      name: 'Portable Hole',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Opens 10-ft deep extradimensional cylindrical space (6 ft diameter)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Unfolds into a circular 6-foot diameter hole leading to a 10-foot-deep extradimensional space.',
        description: 'This fine black silk cloth folds up to the size of a handkerchief. When unfolded and placed against a solid surface, it creates an extradimensional hole 6 feet in diameter and 10 feet deep. Creatures inside have 10 minutes of air divided by the number of breathing creatures.',
        activation: '1 Action (Place / Fold)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Extradimensional hole 6 ft wide by 10 ft deep that folds up into a handkerchief-sized cloth.',
        description: 'Unfold on a solid surface as an Action to open a 10-ft-deep cylinder storage hole. Breathable air lasts 10 minutes.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'portable hole', 'storage', 'extradimensional'],
    ),

    // Slippers of Spider Climbing
    MagicItem(
      id: 'item_slippers_of_spider_climbing',
      name: 'Slippers of Spider Climbing',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Climbing Speed equal to Walking Speed on vertical surfaces & ceilings (Hands Free)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While you wear these slippers, you have a climbing speed equal to your walking speed, and you can move up, down, and across vertical surfaces and upside down along ceilings, while leaving your hands free.',
        description: 'While you wear these slippers, you have a climbing speed equal to your walking speed, and you can move up, down, and across vertical surfaces and upside down along ceilings, while leaving your hands free.',
        activation: 'Passive / Movement',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants Climb Speed equal to Speed on vertical surfaces and ceilings with hands free.',
        description: 'Walk across walls and ceilings hands-free with a Climb Speed equal to your base Speed.',
        activation: 'Passive / Movement',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'slippers', 'climbing', 'spider climb', 'mobility'],
    ),

    // Stone of Good Luck (Luckstone)
    MagicItem(
      id: 'item_stone_of_good_luck',
      name: 'Stone of Good Luck (Luckstone)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Bonus to Ability Checks & Saving Throws'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While this polished agate is on your person, you gain a +1 bonus to ability checks and saving throws.',
        description: 'While this polished agate is on your person, you gain a +1 bonus to ability checks and saving throws.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to all Ability Checks (including Initiative) and all Saving Throws while carried.',
        description: 'While carrying this stone, you gain a +1 bonus to all Ability Checks and Saving Throws.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'stone', 'luck', 'ability check', 'saving throw'],
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
