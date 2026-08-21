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

    // Robe of the Archmagi (White)
    MagicItem(
      id: 'item_robe_of_the_archmagi_white',
      name: 'Robe of the Archmagi (White)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      attunementRequirement: 'by a Good Sorcerer, Warlock, or Wizard',
      glyphColor: Color(0xFFF8FAFC),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 15 + Dex & Advantage on Saves vs Spells'),
        ActionTraitRing(ringType: ActionRingType.legendary, label: '+2 to Spell Save DC & Spell Attack Rolls'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'White Robe (Good): Base AC 15 + Dex, Advantage on saves vs spells, and +2 bonus to spell save DCs and spell attack rolls.',
        description: 'This white silk garment is made for good-aligned spellcasters. Your base AC becomes 15 + Dex; you have advantage on saving throws against spells and magical effects; and your spell save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'White Robe (Good): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
        description: 'While wearing this white robe, your base Armor Class equals 15 + Dexterity modifier. You have Advantage on saving throws against spells and magical effects, and your Spell Save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'robe', 'white', 'archmagi', 'good', 'wizard', 'sorcerer', 'warlock', 'legendary'],
    ),

    // Robe of the Archmagi (Gray)
    MagicItem(
      id: 'item_robe_of_the_archmagi_gray',
      name: 'Robe of the Archmagi (Gray)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      attunementRequirement: 'by a Neutral Sorcerer, Warlock, or Wizard',
      glyphColor: Color(0xFF94A3B8),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 15 + Dex & Advantage on Saves vs Spells'),
        ActionTraitRing(ringType: ActionRingType.legendary, label: '+2 to Spell Save DC & Spell Attack Rolls'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Gray Robe (Neutral): Base AC 15 + Dex, Advantage on saves vs spells, and +2 bonus to spell save DCs and spell attack rolls.',
        description: 'This gray silk garment is made for neutral-aligned spellcasters. Your base AC becomes 15 + Dex; you have advantage on saving throws against spells and magical effects; and your spell save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gray Robe (Neutral): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
        description: 'While wearing this gray robe, your base Armor Class equals 15 + Dexterity modifier. You have Advantage on saving throws against spells and magical effects, and your Spell Save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'robe', 'gray', 'grey', 'archmagi', 'neutral', 'wizard', 'sorcerer', 'warlock', 'legendary'],
    ),

    // Robe of the Archmagi (Black)
    MagicItem(
      id: 'item_robe_of_the_archmagi_black',
      name: 'Robe of the Archmagi (Black)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      attunementRequirement: 'by an Evil Sorcerer, Warlock, or Wizard',
      glyphColor: Color(0xFF334155),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 15 + Dex & Advantage on Saves vs Spells'),
        ActionTraitRing(ringType: ActionRingType.legendary, label: '+2 to Spell Save DC & Spell Attack Rolls'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Black Robe (Evil): Base AC 15 + Dex, Advantage on saves vs spells, and +2 bonus to spell save DCs and spell attack rolls.',
        description: 'This black silk garment is made for evil-aligned spellcasters. Your base AC becomes 15 + Dex; you have advantage on saving throws against spells and magical effects; and your spell save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Black Robe (Evil): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
        description: 'While wearing this black robe, your base Armor Class equals 15 + Dexterity modifier. You have Advantage on saving throws against spells and magical effects, and your Spell Save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'robe', 'black', 'archmagi', 'evil', 'wizard', 'sorcerer', 'warlock', 'legendary'],
    ),

    // Bag of Tricks (Gray)
    MagicItem(
      id: 'item_bag_of_tricks_gray',
      name: 'Bag of Tricks (Gray)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      glyphColor: Color(0xFF94A3B8),
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.sustain,
          label: 'Action: Pull & Throw Gray Fuzzy Object (1d8 Summon Table) (3/Day)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: throw a fuzzy ball up to 20 ft to summon a Gray Beast (d8: 1=Weasel, 2=Giant Rat, 3=Badger, 4=Boar, 5=Panther, 6=Giant Badger, 7=Dire Wolf, 8=Giant Elk). 3 pulls/day.',
        description: 'Reaching inside this gray cloth sack pulls out a small fuzzy ball. As an action, throw it up to 20 feet: transforms into a friendly beast rolled on the Gray Table (1: Weasel, 2: Giant Rat, 3: Badger, 4: Boar, 5: Panther, 6: Giant Badger, 7: Dire Wolf, 8: Giant Elk). Max 3 creatures per day (recharges at dawn). Acts on your turn and obeys verbal commands.',
        activation: '1 Action (3/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: throw fuzzy ball up to 20 ft to summon a Gray Beast (d8: Weasel, Giant Rat, Badger, Boar, Panther, Giant Badger, Dire Wolf, Giant Elk). 3/Long Rest.',
        description: 'Pull a fuzzy ball from the gray bag and throw it up to 20 feet as an Action. It turns into a friendly beast chosen by rolling a d8 (1: Weasel, 2: Giant Rat, 3: Badger, 4: Boar, 5: Panther, 6: Giant Badger, 7: Dire Wolf, 8: Giant Elk). Up to 3 creatures per Long Rest.',
        activation: '1 Action (3/Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'bag', 'summon', 'gray', 'grey', 'beast', 'tricks', 'minions'],
    ),

    // Bag of Tricks (Rust)
    MagicItem(
      id: 'item_bag_of_tricks_rust',
      name: 'Bag of Tricks (Rust)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      glyphColor: Color(0xFFC2410C),
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.sustain,
          label: 'Action: Pull & Throw Rust Fuzzy Object (1d8 Summon Table) (3/Day)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: throw a fuzzy ball up to 20 ft to summon a Rust Beast (d8: 1=Rat, 2=Owl, 3=Mastiff, 4=Goat, 5=Giant Goat, 6=Giant Boar, 7=Lion, 8=Brown Bear). 3 pulls/day.',
        description: 'Reaching inside this rust-colored sack pulls out a small fuzzy ball. As an action, throw it up to 20 feet: transforms into a friendly beast rolled on the Rust Table (1: Rat, 2: Owl, 3: Mastiff, 4: Goat, 5: Giant Goat, 6: Giant Boar, 7: Lion, 8: Brown Bear). Max 3 creatures per day (recharges at dawn). Acts on your turn and obeys verbal commands.',
        activation: '1 Action (3/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: throw fuzzy ball up to 20 ft to summon a Rust Beast (d8: Rat, Owl, Mastiff, Goat, Giant Goat, Giant Boar, Lion, Brown Bear). 3/Long Rest.',
        description: 'Pull a fuzzy ball from the rust bag and throw it up to 20 feet as an Action. It turns into a friendly beast chosen by rolling a d8 (1: Rat, 2: Owl, 3: Mastiff, 4: Goat, 5: Giant Goat, 6: Giant Boar, 7: Lion, 8: Brown Bear). Up to 3 creatures per Long Rest.',
        activation: '1 Action (3/Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'bag', 'summon', 'rust', 'beast', 'tricks', 'minions'],
    ),

    // Bag of Tricks (Tan)
    MagicItem(
      id: 'item_bag_of_tricks_tan',
      name: 'Bag of Tricks (Tan)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      glyphColor: Color(0xFFD4A373),
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.sustain,
          label: 'Action: Pull & Throw Tan Fuzzy Object (1d8 Summon Table) (3/Day)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: throw a fuzzy ball up to 20 ft to summon a Tan Beast (d8: 1=Jackal, 2=Ape, 3=Baboon, 4=Axe Beak, 5=Black Bear, 6=Giant Weasel, 7=Giant Hyena, 8=Tiger). 3 pulls/day.',
        description: 'Reaching inside this tan cloth sack pulls out a small fuzzy ball. As an action, throw it up to 20 feet: transforms into a friendly beast rolled on the Tan Table (1: Jackal, 2: Ape, 3: Baboon, 4: Axe Beak, 5: Black Bear, 6: Giant Weasel, 7: Giant Hyena, 8: Tiger). Max 3 creatures per day (recharges at dawn). Acts on your turn and obeys verbal commands.',
        activation: '1 Action (3/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: throw fuzzy ball up to 20 ft to summon a Tan Beast (d8: Jackal, Ape, Baboon, Axe Beak, Black Bear, Giant Weasel, Giant Hyena, Tiger). 3/Long Rest.',
        description: 'Pull a fuzzy ball from the tan bag and throw it up to 20 feet as an Action. It turns into a friendly beast chosen by rolling a d8 (1: Jackal, 2: Ape, 3: Baboon, 4: Axe Beak, 5: Black Bear, 6: Giant Weasel, 7: Giant Hyena, 8: Tiger). Up to 3 creatures per Long Rest.',
        activation: '1 Action (3/Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'bag', 'summon', 'tan', 'beast', 'tricks', 'minions'],
    ),

    // Ioun Stone (Deep Red)
    MagicItem(
      id: 'item_ioun_stone_deep_red',
      name: 'Ioun Stone (Deep Red)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      glyphColor: Color(0xFFEF4444),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Orbiting Sphere: +2 Dexterity Score (Max 20)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Your Dexterity score increases by 2, to a maximum of 20, while this deep red sphere orbits your head.',
        description: 'While this deep red marble orbits your head, your Dexterity score increases by 2, to a maximum of 20.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Orbiting deep red sphere gives +2 Dexterity score (max 20).',
        description: 'Your Dexterity score increases by 2 (maximum of 20) while this stone orbits your head.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'ioun stone', 'deep red', 'dexterity', 'stat boost'],
    ),

    // Ioun Stone (Incandescent Blue)
    MagicItem(
      id: 'item_ioun_stone_incandescent_blue',
      name: 'Ioun Stone (Incandescent Blue)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      glyphColor: Color(0xFF38BDF8),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Orbiting Sphere: +2 Wisdom Score (Max 20)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Your Wisdom score increases by 2, to a maximum of 20, while this incandescent blue sphere orbits your head.',
        description: 'While this glowing blue sphere orbits your head, your Wisdom score increases by 2, to a maximum of 20.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Orbiting blue sphere gives +2 Wisdom score (max 20).',
        description: 'Your Wisdom score increases by 2 (maximum of 20) while this stone orbits your head.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'ioun stone', 'incandescent blue', 'wisdom', 'stat boost'],
    ),

    // Ioun Stone (Pale Green)
    MagicItem(
      id: 'item_ioun_stone_pale_green',
      name: 'Ioun Stone (Pale Green)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      glyphColor: Color(0xFF10B981),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Orbiting Prism: +1 to All Attack Rolls, Checks & Saves'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You gain a +1 bonus to all attack rolls, saving throws, ability checks, and skill checks while this pale green prism orbits your head.',
        description: 'You gain a +1 bonus to attack rolls, saving throws, ability checks, and skill checks while this pale green prism orbits your head.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Orbiting prism gives +1 bonus to attack rolls, saving throws, and ability checks.',
        description: 'While this prism orbits your head, you gain a +1 bonus to all attack rolls, saving throws, and ability checks.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'ioun stone', 'pale green', 'attacks', 'saves', 'checks'],
    ),

    // Ioun Stone (Dusty Rose)
    MagicItem(
      id: 'item_ioun_stone_dusty_rose',
      name: 'Ioun Stone (Dusty Rose)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      glyphColor: Color(0xFFFB7185),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Orbiting Prism: +1 Bonus to Armor Class (AC)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You gain a +1 bonus to AC while this dusty rose prism orbits your head.',
        description: 'You gain a +1 bonus to AC while this dusty rose prism orbits your head.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Orbiting prism gives +1 bonus to Armor Class (AC).',
        description: 'You gain a +1 bonus to AC while this stone orbits your head.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'ioun stone', 'dusty rose', 'ac', 'protection', 'pink'],
    ),

    // Ioun Stone (Clear Spindle)
    MagicItem(
      id: 'item_ioun_stone_clear_spindle',
      name: 'Ioun Stone (Clear Spindle)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      glyphColor: Color(0xFFF1F5F9),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Orbiting Spindle: Full Sustenance Without Food or Water'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You don\'t need to eat or drink while this clear spindle orbits your head.',
        description: 'A translucent crystal spindle that sustains your biological body completely without food or water while orbiting.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Orbiting crystal provides total sustenance without food or water.',
        description: 'You don\'t need food or water while this clear spindle orbits your head.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'ioun stone', 'clear spindle', 'sustenance', 'white'],
    ),

    // Ioun Stone (Reserve)
    MagicItem(
      id: 'item_ioun_stone_reserve',
      name: 'Ioun Stone (Reserve)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      glyphColor: Color(0xFFA855F7),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Orbiting Rhomboid: Store Up to 3 Levels of Spells'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Stores up to 3 levels of spells that any creature can cast into it by touching it. You can cast stored spells using original caster stats.',
        description: 'This vibrant purple rhomboid stores up to 3 levels of spells. Any creature can cast a spell of 1st through 3rd level into it by touching it as the spell is cast. You can cast any spell stored in it with the original slot level, save DC, attack bonus, and spellcasting ability.',
        activation: 'Cast stored spell',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Stores up to 3 levels of spells. Cast stored spells with original caster stats.',
        description: 'Holds up to 3 spell slot levels that can be cast by the attuner.',
        activation: 'Cast stored spell',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'ioun stone', 'reserve', 'spell storage', 'purple'],
    ),

    // Belt of Hill Giant Strength
    MagicItem(
      id: 'item_belt_of_hill_giant_strength',
      name: 'Belt of Hill Giant Strength',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Sets Strength Score to 21 (+5 Modifier)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this belt, your Strength score is 21 (+5 modifier). Has no effect if your Strength is already 21 or higher.',
        description: 'While wearing this belt, your Strength score changes to 21. If your Strength is already equal to or greater than 21, the item has no effect on you.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to 21 (+5).',
        description: 'Your Strength score becomes 21 while wearing this belt.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'belt', 'giant strength', 'hill giant', 'strength', 'melee'],
    ),

    // Belt of Frost Giant Strength
    MagicItem(
      id: 'item_belt_of_frost_giant_strength',
      name: 'Belt of Frost Giant Strength',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Sets Strength Score to 23 (+6 Modifier)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this belt, your Strength score is 23 (+6 modifier).',
        description: 'While wearing this belt, your Strength score changes to 23.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to 23 (+6).',
        description: 'Your Strength score becomes 23 while wearing this belt.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'belt', 'giant strength', 'frost giant', 'strength', 'melee'],
    ),

    // Belt of Fire Giant Strength
    MagicItem(
      id: 'item_belt_of_fire_giant_strength',
      name: 'Belt of Fire Giant Strength',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Sets Strength Score to 25 (+7 Modifier)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this belt, your Strength score is 25 (+7 modifier).',
        description: 'While wearing this belt, your Strength score changes to 25.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to 25 (+7).',
        description: 'Your Strength score becomes 25 while wearing this belt.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'belt', 'giant strength', 'fire giant', 'strength', 'melee'],
    ),

    // Belt of Storm Giant Strength
    MagicItem(
      id: 'item_belt_of_storm_giant_strength',
      name: 'Belt of Storm Giant Strength',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Sets Strength Score to 29 (+9 Modifier)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this belt, your Strength score is 29 (+9 modifier).',
        description: 'While wearing this belt, your Strength score changes to 29.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to 29 (+9).',
        description: 'Your Strength score becomes 29 while wearing this belt.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'belt', 'giant strength', 'storm giant', 'strength', 'melee', 'legendary'],
    ),

    // Silver Horn of Valhalla
    MagicItem(
      id: 'item_horn_of_valhalla_silver',
      name: 'Silver Horn of Valhalla',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      glyphColor: Color(0xFFCBD5E1),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Action: Summon 2d4+2 Spirit Berserkers (1/7 Days)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Blow horn to summon 2d4 + 2 warrior spirits from Ysgard for 1 hour. Recharges in 7 days.',
        description: 'You can use an action to blow this silver horn: summons 2d4 + 2 spirit Berserkers to fight alongside you for up to 1 hour (recharges every 7 days). Requires martial weapon proficiency.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Summon 2d4 + 2 spirit Berserkers for 1 hour (1/7 Days).',
        description: 'Blow the silver horn as an Action to summon allied Berserker warrior spirits.',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'horn', 'valhalla', 'silver', 'summon', 'berserker'],
    ),

    // Iron Horn of Valhalla
    MagicItem(
      id: 'item_horn_of_valhalla_iron',
      name: 'Iron Horn of Valhalla',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      glyphColor: Color(0xFF475569),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Action: Summon 5d4+5 Spirit Berserkers (1/7 Days)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Blow horn to summon 5d4 + 5 warrior spirits from Ysgard for 1 hour. Recharges in 7 days.',
        description: 'You can use an action to blow this heavy iron horn: summons 5d4 + 5 spirit Berserkers to fight alongside you for up to 1 hour (recharges every 7 days). Requires proficiency with all armor.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Summon 5d4 + 5 spirit Berserkers for 1 hour (1/7 Days).',
        description: 'Blow the iron horn as an Action to summon allied Berserker warrior spirits.',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'horn', 'valhalla', 'iron', 'summon', 'berserker', 'legendary'],
    ),

    // Figurine of Wondrous Power (Bronze Griffon)
    MagicItem(
      id: 'item_figurine_bronze_griffon',
      name: 'Figurine of Wondrous Power (Bronze Griffon)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      glyphColor: Color(0xFFCD7F32),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Animate Living Griffon Mount (24 Hours, 2/10 Days)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Speak command word and throw figurine to animate into a living Griffon mount for up to 24 hours (usable twice every 10 days).',
        description: 'This bronze statuette transforms into a living Griffon when thrown up to 60 feet. It obeys your spoken commands and serves as a flying mount for up to 24 hours. Usable twice per 10 days.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Animate into a living Griffon mount for 24 hours.',
        description: 'Throws up to 60 feet to become a loyal flying Griffon mount for up to 24 hours.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'figurine', 'bronze', 'griffon', 'summon', 'mount'],
    ),

    // Figurine of Wondrous Power (Ebony Fly)
    MagicItem(
      id: 'item_figurine_ebony_fly',
      name: 'Figurine of Wondrous Power (Ebony Fly)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      glyphColor: Color(0xFF334155),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Animate Giant Fly Mount (12 Hours, 3/10 Days)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Speak command word to animate into a pony-sized giant fly for up to 12 hours (usable three times per 8 days).',
        description: 'Transforms into a giant fly with fly speed 60 ft for up to 12 hours. Can carry up to 240 lbs.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Animate into a giant fly mount for 12 hours.',
        description: 'Transforms into a pony-sized flying mount for 12 hours.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'figurine', 'ebony', 'fly', 'summon', 'mount'],
    ),

    // Figurine of Wondrous Power (Marble Elephant)
    MagicItem(
      id: 'item_figurine_marble_elephant',
      name: 'Figurine of Wondrous Power (Marble Elephant)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      glyphColor: Color(0xFFF1F5F9),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Animate True Elephant Mount/Beast (24 Hours, 1/7 Days)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Transforms into a living Elephant for up to 24 hours (recharges once every 7 days).',
        description: 'Transforms into a full-sized Elephant for up to 24 hours. Usable once every 7 days.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Animate into an Elephant for 24 hours (1/7 Days).',
        description: 'Transforms into a massive elephant mount and heavy beast for 24 hours.',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'figurine', 'marble', 'elephant', 'summon', 'mount', 'white'],
    ),

    // Elemental Gem (Blue Sapphire - Air)
    MagicItem(
      id: 'item_elemental_gem_blue_sapphire',
      name: 'Elemental Gem (Blue Sapphire)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      glyphColor: Color(0xFF38BDF8),
      damageAccent: DamageAccent.lightning,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Crush Gem to Summon CR 5 Air Elemental'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Crush gem to cast Conjure Elemental summoning a CR 5 Air Elemental for up to 1 hour (consumable).',
        description: 'Crush this sapphire as an action to summon a friendly Air Elemental for 1 hour. The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Crush gem to summon a CR 5 Air Elemental for 1 hour.',
        description: 'Summons an Air Elemental companion for 1 hour.',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'gem', 'elemental', 'blue sapphire', 'air', 'summon'],
    ),

    // Elemental Gem (Red Corundum - Fire)
    MagicItem(
      id: 'item_elemental_gem_red_corundum',
      name: 'Elemental Gem (Red Corundum)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      glyphColor: Color(0xFFEF4444),
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Crush Gem to Summon CR 5 Fire Elemental'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Crush gem to cast Conjure Elemental summoning a CR 5 Fire Elemental for up to 1 hour (consumable).',
        description: 'Crush this red corundum as an action to summon a friendly Fire Elemental for 1 hour. The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Crush gem to summon a CR 5 Fire Elemental for 1 hour.',
        description: 'Summons a Fire Elemental companion for 1 hour.',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'gem', 'elemental', 'red corundum', 'fire', 'summon'],
    ),

    // Elemental Gem (Yellow Diamond - Earth)
    MagicItem(
      id: 'item_elemental_gem_yellow_diamond',
      name: 'Elemental Gem (Yellow Diamond)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      glyphColor: Color(0xFFF59E0B),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Crush Gem to Summon CR 5 Earth Elemental'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Crush gem to cast Conjure Elemental summoning a CR 5 Earth Elemental for up to 1 hour (consumable).',
        description: 'Crush this yellow diamond as an action to summon a friendly Earth Elemental for 1 hour. The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Crush gem to summon a CR 5 Earth Elemental for 1 hour.',
        description: 'Summons an Earth Elemental companion for 1 hour.',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'gem', 'elemental', 'yellow diamond', 'earth', 'summon'],
    ),

    // Elemental Gem (Emerald - Water)
    MagicItem(
      id: 'item_elemental_gem_emerald',
      name: 'Elemental Gem (Emerald)',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      glyphColor: Color(0xFF10B981),
      damageAccent: DamageAccent.cold,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Crush Gem to Summon CR 5 Water Elemental'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Crush gem to cast Conjure Elemental summoning a CR 5 Water Elemental for up to 1 hour (consumable).',
        description: 'Crush this emerald as an action to summon a friendly Water Elemental for 1 hour. The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Crush gem to summon a CR 5 Water Elemental for 1 hour.',
        description: 'Summons a Water Elemental companion for 1 hour.',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'gem', 'elemental', 'emerald', 'water', 'summon'],
    ),

    // Decanter of Endless Water
    MagicItem(
      id: 'item_decanter_of_endless_water',
      name: 'Decanter of Endless Water',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      glyphColor: Color(0xFF38BDF8),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: 'Action: Stream / Fountain / Geyser (30 ft Line, 1d4 Bludgeoning, DC 13 Str or Prone)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Unstopper and produce endless water: Stream (1 gal), Fountain (5 gal), or Geyser (30 gal, 30 ft blast, 1d4 bludgeoning, DC 13 Str or prone).',
        description: 'You can use an action and speak one of three command words to produce fresh or salt water: Stream (1 gallon), Fountain (5 gallons), or Geyser (30 gallons, 30 ft line, DC 13 Strength save or take 1d4 bludgeoning damage and fall prone).',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Produces continuous fresh/salt water up to Geyser mode (30 gal/round, 30 ft push/prone).',
        description: 'Produces Stream, Fountain, or Geyser volume on command.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'decanter', 'water', 'utility', 'geyser'],
    ),

    // Instant Fortress
    MagicItem(
      id: 'item_instant_fortress',
      name: 'Instant Fortress',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Expands into 30-ft Adamantine Tower (10d10 Bludgeoning to Nearby Creatures)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: Place 1-inch cube on ground and speak command word to instantly expand into a 20-ft square, 30-ft tall adamantine tower (10d10 bludgeoning, DC 15 Dex save for half).',
        description: 'A 1-inch metal cube that expands into a 30-foot tall adamantine fortress with arrow slits and battlement roof. Creatures in its footprint must make a DC 15 Dex save or take 10d10 bludgeoning damage and be pushed away.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Expands into 30-ft tall adamantine fortress (10d10 bludgeoning damage on expansion).',
        description: 'Expands into a fortified tower and shelter.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'fortress', 'adamantine', 'shelter', 'cube', 'structure'],
    ),

    // Robe of Useful Items
    MagicItem(
      id: 'item_robe_of_useful_items',
      name: 'Robe of Useful Items',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Detach Patch to Produce Real Physical Object'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Robe covered with cloth patches representing items (Daggers, Lanterns, Mirrors, 10-ft Poles, Ropes, Horses, Boats, etc.). Detach patch as an action to transform it into the real item.',
        description: 'This robe has cloth patches of various shapes and colors. You can use an action to detach one of the patches, causing it to become the object or creature it represents.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Detach patch to produce the depicted mundane object, vehicle, or creature.',
        description: 'Detach cloth patch as an Action to materialize the item in your space.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['wondrous', 'robe', 'useful items', 'patches', 'utility'],
    ),

    // Apparatus of the Crab (Apparatus of Kwalish)
    MagicItem(
      id: 'item_apparatus_of_the_crab',
      name: 'Apparatus of the Crab',
      name2014: 'Apparatus of Kwalish',
      name2024: 'Apparatus of the Crab',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Piloted Submersible Vehicle (AC 20, 200 HP, 2 Pincer Attacks 2d6 Bludgeoning)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Large iron barrel that transforms into a piloted mechanical lobster/crab submersible holding up to 2 medium creatures with 10 levers.',
        description: 'This item appears as a large sealed iron barrel. When activated, it transforms into an amphibious crab vehicle with speed 30 ft, swim 30 ft, AC 20, 200 HP, and mechanical levers to operate pincer attacks and floodlights.',
        activation: 'Action (Lever operation)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Piloted mechanical crab vehicle with swim speed, heavy pincers, and sealed life support.',
        description: 'Amphibious submersible mechanical vehicle for 2 creatures.',
        activation: 'Action (Operate)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Renamed from Apparatus of Kwalish to Apparatus of the Crab in 2024 Free SRD 5.2.',
      diffHighlights: [
        'Free SRD 5.2 trademark-clean name: Apparatus of the Crab',
        'Updated vehicle helm controls and simplified speed mechanics',
      ],
      tags: ['wondrous', 'vehicle', 'crab', 'kwalish', 'submersible', 'legendary'],
    ),

    // Boots of Elvenkind
    MagicItem(
      id: 'item_boots_of_elvenkind',
      name: 'Boots of Elvenkind',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Steps Make No Sound • Advantage on Stealth Checks that Rely on Moving Silently'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While you wear these boots, your steps make no sound, regardless of the surface you are moving across. You also have advantage on Dexterity (Stealth) checks that rely on moving silently.',
        description: 'While you wear these boots, your steps make no sound, regardless of the surface you are moving across. You also have advantage on Dexterity (Stealth) checks that rely on moving silently.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Footsteps produce zero sound; gain Advantage on Stealth checks relying on silent movement.',
        description: 'Silences all footsteps and grants Advantage on Stealth checks.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'boots', 'stealth', 'silence', 'elven'],
    ),

    // Boots of Levitation
    MagicItem(
      id: 'item_boots_of_levitation',
      name: 'Boots of Levitation',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Cast Levitate on Yourself at Will (Rise or Descend up to 20 ft/round)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While you wear these boots, you can cast the Levitate spell on yourself at will as an action.',
        description: 'While you wear these boots, you can use an action to cast Levitate on yourself at will.',
        activation: '1 Action (At Will)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: cast Levitate at will on yourself.',
        description: 'Allows at-will vertical levitation up to 20 feet per round.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'boots', 'levitate', 'mobility', 'flight'],
    ),

    // Boots of the Winterlands
    MagicItem(
      id: 'item_boots_of_the_winterlands',
      name: 'Boots of the Winterlands',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Resistance to Cold Damage • Ignore Snow/Ice Difficult Terrain • Immune to Extreme Cold down to -50°F'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Grants resistance to cold damage, ignores difficult terrain composed of ice or snow, and protects you against extreme cold down to -50 degrees Fahrenheit.',
        description: 'These furred boots provide warmth and stability in arctic conditions.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cold Resistance, ignore snow/ice difficult terrain, complete protection against Extreme Cold.',
        description: 'Arctic exploration boots providing cold defense and unimpeded winter mobility.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'boots', 'cold', 'winter', 'resistance', 'survival'],
    ),

    // Brooch of Shielding
    MagicItem(
      id: 'item_brooch_of_shielding',
      name: 'Brooch of Shielding',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Resistance to Force Damage • Complete Immunity to Magic Missile Damage'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this brooch, you have resistance to force damage, and you have immunity to damage from the Magic Missile spell.',
        description: 'While wearing this brooch, you have resistance to force damage, and you have immunity to damage from the magic missile spell.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Resistance to Force damage and 100% immunity to damage from Magic Missile.',
        description: 'Warded brooch neutralizing force darts and reducing force blasts by half.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'brooch', 'magic missile', 'force', 'immunity', 'defense'],
    ),

    // Broom of Flying
    MagicItem(
      id: 'item_broom_of_flying',
      name: 'Broom of Flying',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Flying Speed 50 ft (Holds up to 400 lbs; 30 ft speed if over 200 lbs) • Remote Recall 1 Mile'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: speak command word to gain a flying speed of 50 feet (30 feet if carrying over 200 lbs, max 400 lbs). Can send the broom alone up to 1 mile away.',
        description: 'This wooden broom functions as a magic vehicle with a flying speed of 50 feet while carrying up to 200 pounds, or 30 feet while carrying between 200 and 400 pounds. You can also command it to fly on its own to any location within 1 mile.',
        activation: '1 Action (Command Word)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Flying Speed 50 ft (30 ft if carrying 200–400 lbs). Remote summonable within 1 mile.',
        description: 'Iconic flying broom supporting aerial transport for rider and gear.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'broom', 'flying', 'flight', 'vehicle', 'mobility'],
    ),

    // Cape of the Mountebank
    MagicItem(
      id: 'item_cape_of_the_mountebank',
      name: 'Cape of the Mountebank',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action (1/Day): Cast Dimension Door with Smoke Cloud at Origin & Destination'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: cast Dimension Door (recharges daily at dawn). Leaves behind a 5-foot-radius cloud of heavy smoke at both the origin and destination.',
        description: 'This cape smells faintly of brimstone. While wearing it, you can use an action to cast the Dimension Door spell from it. When the spell takes effect, you vanish in a cloud of thick smoke that heavily obscures the space you left and the destination space until the end of your next turn.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: cast Dimension Door with dramatic obscuring smoke clouds (1/Long Rest).',
        description: 'Teleportation cape allowing a 500-foot jump and sensory concealment.',
        activation: '1 Action (1/Long Rest)',
      ),
      tags: ['wondrous', 'cape', 'dimension door', 'teleport', 'escape', 'stealth'],
    ),

    // Chime of Opening
    MagicItem(
      id: 'item_chime_of_opening',
      name: 'Chime of Opening',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Unlock Any Mundane or Magical Lock within 120 ft (10 Charges Total)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 10 charges. Action: point at a lock, door, gate, chest, or vehicle within 120 feet. Strikes open the lock (dispelling Arcane Lock or picking normal locks).',
        description: 'This hollow metal tube contains 10 charges. Striking it points a tone at a lock, latch, or barrier, unlocking or unbarring it instantly. Non-rechargeable; cracks when empty.',
        activation: '1 Action',
        charges: '10 charges (non-rechargeable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: instantly open mundane or magical locks within 120 ft (10 charges).',
        description: 'Acoustic lock-breaking chime opening reinforced barriers and overcoming Arcane Lock.',
        activation: '1 Action',
        charges: '10 charges (non-rechargeable)',
      ),
      tags: ['wondrous', 'chime', 'knock', 'lock', 'dungeon', 'utility'],
    ),

    // Circlet of Blasting
    MagicItem(
      id: 'item_circlet_of_blasting',
      name: 'Circlet of Blasting',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, damageType: DamageAccent.fire, label: 'Action (1/Day): Cast Scorching Ray (+5 to Hit; 3 Rays dealing 2d6 Fire each)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action (1/day): cast the Scorching Ray spell (+5 attack bonus, 120 ft range). Recharges daily at dawn.',
        description: 'While wearing this circlet, you can use an action to cast the Scorching Ray spell with a +5 bonus to the attack roll.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: cast Scorching Ray (+5 attack bonus or your spell attack bonus) once per Long Rest.',
        description: 'Golden circlet shooting fiery rays at targets up to 120 feet away.',
        activation: '1 Action (1/Long Rest)',
      ),
      tags: ['wondrous', 'circlet', 'scorching ray', 'fire', 'damage'],
    ),

    // Cloak of Displacement
    MagicItem(
      id: 'item_cloak_of_displacement',
      name: 'Cloak of Displacement',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Attack Rolls against you have Disadvantage (Temporarily deactivated until start of next turn if you take damage)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Attack rolls against you have disadvantage. If you take damage, this property ceases to function until the start of your next turn (also inactive if incapacitated or unable to move).',
        description: 'While you wear this cloak, it projects an illusion that makes you appear to be standing in a place near your actual location, causing any creature to have disadvantage on attack rolls against you. If you take damage, the property is suppressed until the start of your next turn.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Imposes Disadvantage on all incoming attack rolls. Suppressed until next turn when you take damage.',
        description: 'Projects an illusory optical shift, conferring constant defensive evasion.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'cloak', 'displacement', 'defense', 'illusion'],
    ),

    // Cloak of the Manta Ray
    MagicItem(
      id: 'item_cloak_of_the_manta_ray',
      name: 'Cloak of the Manta Ray',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Breathe Underwater • Gain Swimming Speed of 60 Feet while Hood is Pulled Up'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this cloak with the hood up, you can breathe underwater and gain a swimming speed of 60 feet. Pulling the hood up or down requires an action.',
        description: 'While wearing this cloak with its hood up, you can breathe underwater, and you have a swimming speed of 60 feet.',
        activation: '1 Action (Toggle Hood)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Underwater breathing and 60 ft Swim Speed while hood is active.',
        description: 'Aquatic cloak enabling rapid swimming and amphibious survival.',
        activation: '1 Action / Bonus Action',
      ),
      tags: ['wondrous', 'cloak', 'manta ray', 'aquatic', 'swimming', 'water breathing'],
    ),

    // Cube of Force
    MagicItem(
      id: 'item_cube_of_force',
      name: 'Cube of Force',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '36 Charges: Action: Deploy 15-ft Force Barrier blocking Gas, Nonliving Matter, Living Matter, Spell Effects, or ALL Things'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Has 36 charges (regains 1d20 daily at dawn). Press one of 6 faces as an action to create a 15-foot cubic barrier blocking gas, nonliving matter, living matter, spells, or all things.',
        description: 'This cube has 36 charges. Pressing faces creates custom protective force barriers around you that move with you.',
        activation: '1 Action',
        charges: '36 charges (recharges 1d20 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '36 charges: customizable 15-ft impenetrable barrier blocking matter, spells, and environmental hazards.',
        description: 'Tactical force field generator adapting to block various types of incoming harm.',
        activation: '1 Action',
        charges: '36 charges (recharges 1d20 on Long Rest)',
      ),
      tags: ['wondrous', 'cube', 'force', 'barrier', 'defense', 'shield'],
    ),

    // Eversmoking Bottle
    MagicItem(
      id: 'item_eversmoking_bottle',
      name: 'Eversmoking Bottle',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Uncork to produce 60-ft up to 120-ft radius Cloud of Heavy Obscurement (100 ft/minute)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: uncork to emit thick smoke in a 60-foot radius, expanding 10 feet per minute up to 120 feet. Heavily obscures vision. Action to recork.',
        description: 'Smoke constantly trickles from the lead stopper of this brass bottle. Uncorking releases a massive cloud of thick smoke.',
        activation: '1 Action (Uncork / Recork)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: uncork for massive 60–120 ft radius obscuring smoke field.',
        description: 'Creates vast tactical smoke concealment blocking line of sight.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'bottle', 'smoke', 'obscurement', 'tactical'],
    ),

    // Eyes of the Eagle
    MagicItem(
      id: 'item_eyes_of_the_eagle',
      name: 'Eyes of the Eagle',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Advantage on Perception Checks that Rely on Sight • Discern Fine Detail up to 1 Mile Away'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing these crystal lenses, you have advantage on Wisdom (Perception) checks that rely on sight. Can discern fine details up to 1 mile away.',
        description: 'These crystal lenses fit over the eyes and magnify distant objects.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Advantage on sight-based Perception; eagle telescopic sight up to 1 mile.',
        description: 'Precision scout optics granting telescopic sight and Advantage on visual search.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'eyes', 'eagle', 'perception', 'scouting', 'vision'],
    ),

    // Folding Boat
    MagicItem(
      id: 'item_folding_boat',
      name: 'Folding Boat',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Unfolds from 12-in Box into 10-ft Rowboat (4 People) or 24-ft Ship (15 People)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: speak command word 1 to unfold into a 10-foot rowboat (4 passengers), command word 2 for a 24-foot sailing ship with cabin (15 passengers), or command word 3 to fold back into a 12-inch wooden box.',
        description: 'This wooden box is 12 inches long, 6 inches wide, and 6 inches deep. Commands unfold it into ocean-ready vessels.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: expands into 10-ft rowboat or 24-ft sailing vessel; folds into portable box.',
        description: 'Modular nautical vessel box providing instant maritime transportation.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'boat', 'vehicle', 'ship', 'transport', 'nautical'],
    ),

    // Gem of Brightness
    MagicItem(
      id: 'item_gem_of_brightness',
      name: 'Gem of Brightness',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '50 Charges: Shed Bright Light (At Will) • Blind 1 Creature (DC 15 CON, 1 charge) • Blind All in 60-ft Cone (DC 15 CON, 5 charges)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 50 charges. Shed light (0 charges), shoot beam blinding 1 creature on DC 15 Con save (1 charge), or unleash 60-foot cone blinding all creatures for 1 minute (5 charges). Non-rechargeable.',
        description: 'This prism has 50 charges and emits dazzling bursts of solar brilliance.',
        activation: '1 Action',
        charges: '50 charges (non-rechargeable)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '50 charges: at-will illumination, single-target blindness ray, and 60-ft cone blinding flash.',
        description: 'Crystal prism generating intense radiant bursts to blind foes.',
        activation: '1 Action',
        charges: '50 charges (non-rechargeable)',
        savingThrowDc: 'Fixed DC 15',
      ),
      tags: ['wondrous', 'gem', 'brightness', 'blindness', 'light', 'radiant'],
    ),

    // Gem of Seeing
    MagicItem(
      id: 'item_gem_of_seeing',
      name: 'Gem of Seeing',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: '3 Charges: Action (1 charge): Gain Truesight out to 120 Feet for 10 Minutes (Sees Invisible, Ethereal, Illusions & Shapechangers)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Has 3 charges (regains 1d3 daily at dawn). Action: peer through the gem for 10 minutes to gain Truesight out to 120 feet.',
        description: 'This gem has 3 charges. Peering through it grants Truesight to see through magical darkness, invisible creatures, illusions, visual shapechangers, and into the Ethereal Plane.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: peer through lens for 10 minutes of 120 ft Truesight.',
        description: 'Divination prism revealing all invisible, ethereal, and shapeshifted entities.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      tags: ['wondrous', 'gem', 'truesight', 'invisible', 'illusions', 'divination'],
    ),

    // Gloves of Missile Snaring
    MagicItem(
      id: 'item_gloves_of_missile_snaring',
      name: 'Gloves of Missile Snaring',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Reaction: Reduce Ranged Weapon Attack Damage by 1d10 + DEX Mod • Catch Missile if Damage is 0'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When a ranged weapon attack hits you, use your reaction to reduce the damage by 1d10 + Dexterity modifier. If damage is reduced to 0, you catch the missile if you have a free hand.',
        description: 'These gloves seem to move on their own to snatch projectiles out of the air.',
        activation: '1 Reaction',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Reaction: deflect ranged weapon attacks, reducing damage by 1d10 + Dex and catching missile if damage reaches 0.',
        description: 'Enchanted defensive gloves snatching arrows and thrown weapons out of flight.',
        activation: '1 Reaction',
      ),
      tags: ['wondrous', 'gloves', 'missile snaring', 'deflect', 'reaction', 'defense'],
    ),

    // Gloves of Thievery
    MagicItem(
      id: 'item_gloves_of_thievery',
      name: 'Gloves of Thievery',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+5 Bonus to Sleight of Hand & Thieves\' Tools Ability Checks (Invisible while Worn)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'These gloves are invisible while worn. While wearing them, you gain a +5 bonus to Dexterity (Sleight of Hand) checks and Dexterity checks made to pick locks with thieves\' tools.',
        description: 'Supple, translucent rogue\'s gloves boosting precision manual dexterity.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+5 bonus on Sleight of Hand and Thieves\' Tools checks; invisible while equipped.',
        description: 'Masterwork lockpicking and pickpocketing gloves adding a flat +5 bonus.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'gloves', 'thievery', 'sleight of hand', 'lockpicking', 'rogue'],
    ),

    // Helm of Teleportation
    MagicItem(
      id: 'item_helm_of_teleportation',
      name: 'Helm of Teleportation',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '3 Charges: Action (1 charge): Cast Teleport spell anywhere on the same plane'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 3 charges (regains 1d3 daily at dawn). While wearing it, use an action to expend 1 charge to cast the Teleport spell.',
        description: 'This helm has 3 charges. While wearing it, you can use an action to expend 1 charge to cast Teleport.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: cast Teleport (7th level) anywhere across the current plane.',
        description: 'Legendary long-distance traversal helm.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      tags: ['wondrous', 'helm', 'teleport', 'travel', 'mobility'],
    ),

    // Lantern of Revealing
    MagicItem(
      id: 'item_lantern_of_revealing',
      name: 'Lantern of Revealing',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Burns for 6 Hours on 1 Pint of Oil: Sheds 30 ft Bright Light (30 ft Dim) • Invisible Creatures & Objects are Visible in Bright Light'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While lit, sheds bright light in a 30-foot radius and dim light for an additional 30 feet. Invisible creatures and objects are visible as long as they are in the lantern\'s bright light.',
        description: 'While lit, this hooded lantern reveals invisible creatures and hidden ethereal objects in its bright light beam.',
        activation: '1 Action (Light / Hood)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Reveals all invisible creatures and objects within 30 ft bright light radius.',
        description: 'Essential dungeon exploration lantern unmasking invisible stalkers and hidden objects.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'lantern', 'revealing', 'invisibility', 'light', 'scouting'],
    ),

    // Rope of Climbing
    MagicItem(
      id: 'item_rope_of_climbing',
      name: 'Rope of Climbing',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: 60-ft Silk Rope moves up to 50 ft to tie/fasten itself to any object • Supports up to 3,000 lbs • AC 20, 20 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: command this 60-foot rope to snake forward up to 50 feet and securely knot/fasten itself to an anchor point. Bonus action: create knot handholds (advantage on Athletics to climb). Supports up to 3,000 lbs.',
        description: 'This 60-foot silk rope moves under telepathic/verbal command to scale cliffs and secure rappels.',
        activation: '1 Action / 1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: snake up to 50 ft to tie off to anchors. Creates knot handholds for effortless climbing.',
        description: 'Enchanted climbing rope securing ascents and descents across sheer surfaces.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'rope', 'climbing', 'athletics', 'utility', 'dungeon'],
    ),

    // Rope of Entanglement
    MagicItem(
      id: 'item_rope_of_entanglement',
      name: 'Rope of Entanglement',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.ranged, label: 'Action: Target creature within 20 ft (DC 15 DEX Save or Restrained) • DC 15 STR or DC 20 Acrobatics to Escape • AC 20, 20 HP'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: command rope to lash out at a creature within 20 feet. Target must pass DC 15 Dex save or become restrained. DC 15 Strength or DC 20 Dexterity check to break free.',
        description: 'This 30-foot rope springs forward to wrap around and bind a target with supernatural strength.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: bind target in 20 ft with Restrained condition on failed DC 15 Dex save.',
        description: 'Tactical crowd-control rope restraining foes without requiring spell slots.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      tags: ['wondrous', 'rope', 'entanglement', 'restrained', 'crowd control'],
    ),

    // Wings of Flying
    MagicItem(
      id: 'item_wings_of_flying',
      name: 'Wings of Flying',
      category: ItemCategory.wondrousItem,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Transform Cloak into Bat/Bird Wings for 1 Hour (Flying Speed 60 ft; Recharges in 1d12 Hours)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: speak command word to transform cloak into bat or bird wings, gaining a flying speed of 60 feet for 1 hour. Can\'t be used again for 1d12 hours.',
        description: 'While wearing this cloak, you can use an action to speak its command word. This turns the cloak into a pair of bat wings or bird wings on your back for 1 hour or until you repeat the command word as an action. While the wings are present, you have a flying speed of 60 feet.',
        activation: '1 Action (1 Hour Duration)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: deploy wings granting 60 ft Flying Speed for 1 hour (recharges in 1d12 hours).',
        description: 'Transforms cloak into wings enabling rapid 60-foot flight speed.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'wings', 'flying', 'flight', 'mobility', 'aerial'],
    ),
  ];
}
