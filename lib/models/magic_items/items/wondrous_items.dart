import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Wondrous Items Catalog
class SrdWondrousItems {
  SrdWondrousItems._();

  static const List<EquipmentItem> items = [
    // Bag of Holding
    EquipmentItem(
      id: EntityId(slug: 'item_bag_of_holding', ruleset: RulesetVersion.v2024), name: 'Bag of Holding',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Extradimensional space holding up to 500 lbs / 64 cu ft. Breathing creatures have 10 minutes of air.',
      rules2014: ItemEditionDetails(
        summary:
            'Opens into an extradimensional space holding up to 500 pounds and 64 cubic feet while weighing 15 pounds.',
        description:
            'This bag has an interior space considerably larger than its outside dimensions, roughly 2 feet in diameter at the mouth and 4 feet deep. The bag can hold up to 500 pounds, not exceeding a volume of 64 cubic feet. The bag always weighs 15 pounds, regardless of its contents. Breathing creatures inside can survive for 10 minutes divided by the number of creatures. Placing a bag of holding inside an extradimensional space created by a handy haversack, portable hole, or similar item instantly destroys both items and opens a gate to the Astral Plane.',
        activation: '1 Action (Retrieve item)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Extradimensional space holding up to 500 lbs / 64 cu ft. Breathing creatures have 10 minutes of air.',
        description:
            'An extradimensional container that holds up to 500 pounds and 64 cubic feet while weighing only 15 pounds. Overloading, puncturing, or placing inside another extradimensional space destroys the bag and opens a portal to the Astral Plane.',
        activation: '1 Action / Object Interaction',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'bag', 'storage', 'extradimensional', 'utility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bag', 'storage', 'extradimensional', 'utility'] },
    ),

    // Cloak of Protection
    EquipmentItem(
      id: EntityId(slug: 'item_cloak_of_protection', ruleset: RulesetVersion.v2024), name: 'Cloak of Protection',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'You gain a +1 bonus to AC and all saving throws while wearing this cloak.',
      rules2014: ItemEditionDetails(
        summary:
            'You gain a +1 bonus to AC and saving throws while you wear this cloak.',
        description:
            'You gain a +1 bonus to AC and saving throws while you wear this cloak.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'You gain a +1 bonus to AC and all saving throws while wearing this cloak.',
        description:
            'You gain a +1 bonus to AC and all saving throws while wearing this cloak.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'cloak', 'ac', 'defense'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cloak', 'ac', 'defense'], 'bonusAc': 1, 'acBonus': 1 },
    ),

    // Deck of Many Things
    EquipmentItem(
      id: EntityId(slug: 'item_deck_of_many_things', ruleset: RulesetVersion.v2024), name: 'Deck of Many Things',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'Iconic deck of fate-altering cards updated with modernized conditions and escape mechanics for catastrophic cards.',
      rules2014: ItemEditionDetails(
        summary:
            'Deck of 13 or 22 cards containing cosmic fortunes, instant destruction, demon enmities, and wish grants.',
        description:
            'Usually found in a box or pouch, this deck contains a number of cards made of ivory or vellum (13 or 22 cards). Before you draw a card, you must declare how many cards you intend to draw. Cards drawn take effect immediately (e.g. Skull summons Avatar of Death, Void draws your soul away, Knight grants a 4th-level fighter follower, Moon grants 1d3 Wish spells).',
        activation: '1 Action (Declare & Draw)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Iconic deck of fate-altering cards updated with modernized conditions and escape mechanics for catastrophic cards.',
        description:
            'The 2024 Deck of Many Things refines classic card mechanics to provide engaging gameplay counters and clearer resolution steps while preserving epic legendary stakes.',
        activation: '1 Action (Declare & Draw)',
      ),
      isChangedIn2024: true, diffSummary: 'Catastrophic cards (Donjon, Void) given clearer resolution and rescue mechanics.', diffHighlights: [
        '2024: Card mechanics modernized to prevent non-interactive permanent character loss.',
      ], tags: ['wondrous', 'deck', 'cards', 'fate', 'legendary'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'deck', 'cards', 'fate', 'legendary'] },
    ),

    // Boots of Speed
    EquipmentItem(
      id: EntityId(slug: 'item_boots_of_speed', ruleset: RulesetVersion.v2024), name: 'Boots of Speed',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Bonus Action: doubles Speed for up to 10 minutes and gives Opportunity Attacks Disadvantage against you.',
      rules2014: ItemEditionDetails(
        summary:
            'Use a bonus action to click heels: doubles walking speed for 10 minutes and opportunity attacks against you have disadvantage.',
        description:
            'While you wear these boots, you can use a bonus action and click the boots\' heels together. If you do, the boots double your walking speed, and any creature that makes an opportunity attack against you has disadvantage on the attack roll. The boots have a duration of 10 minutes (usable in increments of 1 minute) and regain 2 hours of duration per long rest.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Bonus Action: doubles Speed for up to 10 minutes and gives Opportunity Attacks Disadvantage against you.',
        description:
            'Click heels as a Bonus Action: doubles your Speed for up to 10 minutes (can be used in 1-minute increments). Opportunity Attacks against you have Disadvantage. Regains all expended time on a Long Rest.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'boots', 'speed', 'mobility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'boots', 'speed', 'mobility'] },
    ),

    // Winged Boots
    EquipmentItem(
      id: EntityId(slug: 'item_winged_boots', ruleset: RulesetVersion.v2024), name: 'Winged Boots',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Grants a Fly Speed equal to your Speed for up to 4 hours (recharges on Long Rest).',
      rules2014: ItemEditionDetails(
        summary:
            'While you wear these boots, you have a flying speed equal to your walking speed for up to 4 hours per day.',
        description:
            'While you wear these boots, you have a flying speed equal to your walking speed. You can use the boots to fly for up to 4 hours, all at once or in several shorter flights, each one using a minimum of 1 minute. The boots regain 2 hours of flying capability for every 12 hours they aren\'t in use.',
        activation: 'Passive / Movement',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Grants a Fly Speed equal to your Speed for up to 4 hours (recharges on Long Rest).',
        description:
            'Grants a Fly Speed equal to your Speed for up to 4 hours (increments of 1 minute). Regains 2 hours of flight per Long Rest.',
        activation: 'Passive / Movement',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'boots', 'flight', 'mobility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'boots', 'flight', 'mobility'] },
    ),

    // Belt of Giant Strength
    EquipmentItem(
      id: EntityId(slug: 'item_belt_of_giant_strength', ruleset: RulesetVersion.v2024), name: 'Belt of Giant Strength',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets your Strength score to a fixed score based on giant tier (Hill 21 to Storm 29).',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this belt, your Strength score changes to a fixed high score (Hill 21, Stone/Frost 23, Fire 25, Cloud 27, Storm 29).',
        description:
            'While wearing this belt, your Strength score changes to a score determined by the belt\'s type (Hill 21, Stone/Frost 23, Fire 25, Cloud 27, Storm 29). If your Strength is already equal to or greater than the belt\'s score, the item has no effect on you.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Sets your Strength score to a fixed score based on giant tier (Hill 21 to Storm 29).',
        description:
            'While wearing this belt, your Strength score equals 21 (Hill, Rare), 23 (Stone/Frost, Very Rare), 25 (Fire, Very Rare), 27 (Cloud, Legendary), or 29 (Storm, Legendary). Has no effect if your Strength is already higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'belt', 'strength', 'giant', 'stat boost'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'belt', 'strength', 'giant', 'stat boost'] },
    ),

    // Amulet of Health
    EquipmentItem(
      id: EntityId(slug: 'item_amulet_of_health', ruleset: RulesetVersion.v2024), name: 'Amulet of Health',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets your Constitution score to 19 (+4 mod) while worn.',
      rules2014: ItemEditionDetails(
        summary:
            'Your Constitution score is 19 while you wear this amulet. Has no effect if your Constitution is already 19 or higher.',
        description:
            'Your Constitution score is 19 while you wear this amulet. It has no effect on you if your Constitution is already 19 or higher without it.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Constitution score to 19 (+4 mod) while worn.',
        description:
            'While wearing this amulet, your Constitution score equals 19. Has no effect if your Constitution is already 19 or higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'amulet', 'constitution', 'hp', 'stat boost'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'amulet', 'constitution', 'hp', 'stat boost'] },
    ),

    // Headband of Intellect
    EquipmentItem(
      id: EntityId(slug: 'item_headband_of_intellect', ruleset: RulesetVersion.v2024), name: 'Headband of Intellect',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets Intelligence score to 19 (+4 mod) while worn.',
      rules2014: ItemEditionDetails(
        summary:
            'Your Intelligence score is 19 while you wear this headband. Has no effect if your Intelligence is already 19 or higher.',
        description:
            'Your Intelligence score is 19 while you wear this headband. It has no effect on you if your Intelligence is already 19 or higher without it.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets Intelligence score to 19 (+4 mod) while worn.',
        description:
            'While wearing this headband, your Intelligence score equals 19. Has no effect if your Intelligence is already 19 or higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'headband', 'intelligence', 'stat boost'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'headband', 'intelligence', 'stat boost'] },
    ),

    // Gauntlets of Ogre Power
    EquipmentItem(
      id: EntityId(slug: 'item_gauntlets_of_ogre_power', ruleset: RulesetVersion.v2024), name: 'Gauntlets of Ogre Power',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets Strength score to 19 (+4 mod) while worn.',
      rules2014: ItemEditionDetails(
        summary:
            'Your Strength score is 19 while you wear these gauntlets. Has no effect if your Strength is already 19 or higher.',
        description:
            'Your Strength score is 19 while you wear these gauntlets. It has no effect on you if your Strength is already 19 or higher without them.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets Strength score to 19 (+4 mod) while worn.',
        description:
            'While wearing these gauntlets, your Strength score equals 19. Has no effect if your Strength is already 19 or higher.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'gauntlets', 'strength', 'stat boost'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gauntlets', 'strength', 'stat boost'] },
    ),

    // Bracers of Archery
    EquipmentItem(
      id: EntityId(slug: 'item_bracers_of_archery', ruleset: RulesetVersion.v2024), name: 'Bracers of Archery',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Proficiency with Longbow and Shortbow; +2 damage on attacks made with those weapons.',
      rules2014: ItemEditionDetails(
        summary:
            'Grants proficiency with longbows and shortbows, and a +2 bonus to damage rolls with ranged attacks made with them.',
        description:
            'While wearing these bracers, you have proficiency with the longbow and shortbow, and you gain a +2 bonus to damage rolls on ranged attacks made with such weapons.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Proficiency with Longbow and Shortbow; +2 damage on attacks made with those weapons.',
        description:
            'Grants proficiency with the Longbow and Shortbow and adds a +2 bonus to damage rolls made with them.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'bracers', 'archery', 'bow', 'damage'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bracers', 'archery', 'bow', 'damage'] },
    ),

    // Bracers of Defense
    EquipmentItem(
      id: EntityId(slug: 'item_bracers_of_defense', ruleset: RulesetVersion.v2024), name: 'Bracers of Defense',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: '+2 bonus to AC while not wearing armor or wielding a shield.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing these bracers, you gain a +2 bonus to AC if you are wearing no armor and using no shield.',
        description:
            'While wearing these bracers, you gain a +2 bonus to AC if you are wearing no armor and using no shield.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC while not wearing armor or wielding a shield.',
        description:
            'You gain a +2 bonus to AC while wearing these bracers if you are wearing no armor and wielding no Shield.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'bracers', 'ac', 'defense', 'monk', 'wizard'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bracers', 'ac', 'defense', 'monk', 'wizard'] },
    ),

    // Cloak of Elvenkind
    EquipmentItem(
      id: EntityId(slug: 'item_cloak_of_elvenkind', ruleset: RulesetVersion.v2024), name: 'Cloak of Elvenkind',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Advantage on Stealth checks and Disadvantage on Perception checks made to spot you.',
      rules2014: ItemEditionDetails(
        summary:
            'While you wear this cloak with its hood up, Wisdom (Perception) checks made to see you have disadvantage, and you have advantage on Dexterity (Stealth) checks made to hide.',
        description:
            'While you wear this cloak with its hood up, Wisdom (Perception) checks made to see you have disadvantage, and you have advantage on Dexterity (Stealth) checks made to hide, as the cloak\'s color shifts to camouflage you. Pulling the hood up or down requires an action.',
        activation: '1 Action (Toggle Hood) / Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Advantage on Stealth checks and Disadvantage on Perception checks made to spot you.',
        description:
            'While wearing this cloak with its hood up, you have Advantage on Dexterity (Stealth) checks, and Wisdom (Perception) checks made to see you have Disadvantage.',
        activation: '1 Action / Bonus Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'cloak', 'stealth', 'elvenkind'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cloak', 'stealth', 'elvenkind'] },
    ),

    // Cloak of Invisibility
    EquipmentItem(
      id: EntityId(slug: 'item_cloak_of_invisibility', ruleset: RulesetVersion.v2024), name: 'Cloak of Invisibility',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true,
      descriptionMarkdown: 'Action: become Invisible for up to 2 hours (recharges on Long Rest).',
      rules2014: ItemEditionDetails(
        summary:
            'Pull up the hood as an action to become invisible for up to 2 hours (recharges 1 hour per 12 hours unused).',
        description:
            'While wearing this cloak, you can pull its hood up over your head as an action to become invisible. While you are invisible, anything you are carrying or wearing is also invisible. You remain invisible until you pull the hood down. The cloak has a duration of 2 hours, used in 1-minute increments.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: become Invisible for up to 2 hours (recharges on Long Rest).',
        description:
            'Pull the hood up as an Action to gain the Invisible condition for up to 2 hours. Regains all expended time on a Long Rest.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'cloak', 'invisibility', 'legendary', 'stealth'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cloak', 'invisibility', 'legendary', 'stealth'] },
    ),

    // Cloak of the Bat
    EquipmentItem(
      id: EntityId(slug: 'item_cloak_of_the_bat', ruleset: RulesetVersion.v2024), name: 'Cloak of the Bat',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Advantage on Stealth; Fly 40 ft in Dim Light/Darkness; cast Polymorph (Bat only) once per Long Rest.',
      rules2014: ItemEditionDetails(
        summary:
            'Advantage on Stealth checks. In dim light or darkness, grants flying speed of 40 feet and ability to cast Polymorph on yourself to become a bat.',
        description:
            'While wearing this cloak, you have advantage on Dexterity (Stealth) checks. In an area of dim light or darkness, you can grip the edges of the cloak with both hands and use it to fly with a speed of 40 feet. If you ever fail to grip the cloak\'s edges or leave dim light/darkness, you lose this flying speed. You can also cast Polymorph on yourself to transform into a bat once per day.',
        activation: '1 Action (Polymorph) / Movement',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Advantage on Stealth; Fly 40 ft in Dim Light/Darkness; cast Polymorph (Bat only) once per Long Rest.',
        description:
            'Grants Advantage on Stealth checks, Fly Speed 40 ft in darkness/dim light while holding the cloak with both hands, and cast Polymorph on yourself (Bat) once per Long Rest.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'cloak', 'bat', 'stealth', 'fly', 'polymorph'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cloak', 'bat', 'stealth', 'fly', 'polymorph'] },
    ),

    // Driftglobe
    EquipmentItem(
      id: EntityId(slug: 'item_driftglobe', ruleset: RulesetVersion.v2024), name: 'Driftglobe',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: cast Light at will, Daylight once per Long Rest, and commands the globe to hover and follow you.',
      rules2014: ItemEditionDetails(
        summary:
            'Cast Light at will, Daylight once per day, and command the globe to hover and follow you within 60 feet.',
        description:
            'This small sphere of thick glass can be commanded to cast Light at will or Daylight once per day. You can speak a command word to make the globe hover and follow you within 60 feet. If you move more than 60 feet from it, it follows you until it is within 60 feet.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: cast Light at will, Daylight once per Long Rest, and commands the globe to hover and follow you.',
        description:
            'Glass sphere that casts Light at will, Daylight (1/Long Rest), and hovers alongside you within 60 feet.',
        activation: '1 Action / Bonus Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'driftglobe', 'light', 'utility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'driftglobe', 'light', 'utility'] },
    ),

    // Goggles of Night
    EquipmentItem(
      id: EntityId(slug: 'item_goggles_of_night', ruleset: RulesetVersion.v2024), name: 'Goggles of Night',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Grants Darkvision with a range of 60 feet (or increases existing Darkvision range by 60 feet).',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing these dark lenses, you have darkvision out to a range of 60 feet. If you already have darkvision, wearing the goggles increases its range by 60 feet.',
        description:
            'While wearing these dark lenses, you have darkvision out to a range of 60 feet. If you already have darkvision, wearing the goggles increases its range by 60 feet.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Grants Darkvision with a range of 60 feet (or increases existing Darkvision range by 60 feet).',
        description:
            'While wearing these goggles, you have Darkvision out to 60 feet (or +60 ft to your existing Darkvision).',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'goggles', 'darkvision', 'utility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'goggles', 'darkvision', 'utility'] },
    ),

    // Hat of Disguise
    EquipmentItem(
      id: EntityId(slug: 'item_hat_of_disguise', ruleset: RulesetVersion.v2024), name: 'Hat of Disguise',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Action: cast Disguise Self at will while wearing this hat.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this hat, you can use an action to cast the Disguise Self spell from it at will. The spell ends if the hat is removed.',
        description:
            'While wearing this hat, you can use an action to cast the Disguise Self spell from it at will. The spell ends if the hat is removed.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: cast Disguise Self at will while wearing this hat.',
        description:
            'Cast Disguise Self at will as an Action. The spell ends if the hat is taken off.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'hat', 'disguise', 'illusion'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'hat', 'disguise', 'illusion'] },
    ),

    // Necklace of Fireballs
    EquipmentItem(
      id: EntityId(slug: 'item_necklace_of_fireballs', ruleset: RulesetVersion.v2024), name: 'Necklace of Fireballs',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: throw beads up to 60 ft to detonate as Fireball (8d6 Fire + 1d6 per extra bead thrown).',
      rules2014: ItemEditionDetails(
        summary:
            'This necklace has 1d6 + 3 beads. Detach and throw 1 or more beads up to 60 feet: each bead casts Fireball (3rd level + 1 level per additional bead).',
        description:
            'This necklace has 1d6 + 3 glowing beads hanging from it. You can use an action to detach a bead and throw it up to 60 feet away. When it reaches the end of its trajectory, it detonates as a 3rd-level fireball spell (save DC 15). You can hurl multiple beads, or even the whole necklace, as one action. Doing so increases the level of the fireball by 1 for each bead beyond the first.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: throw beads up to 60 ft to detonate as Fireball (8d6 Fire + 1d6 per extra bead thrown).',
        description:
            'Detach and throw beads up to 60 feet as an Action to detonate as Fireball (DC 15 Dexterity save). Throw multiple beads in one Action to upcast.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'necklace', 'fireball', 'fire', 'aoe', 'consumable'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'necklace', 'fireball', 'fire', 'aoe', 'consumable'] },
    ),

    // Necklace of Adaptation
    EquipmentItem(
      id: EntityId(slug: 'item_necklace_of_adaptation', ruleset: RulesetVersion.v2024), name: 'Necklace of Adaptation',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Breathe in any environment; Advantage on saves against gases, vapors, and inhalation hazards.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this necklace, you can breathe normally in any environment, and you have advantage on saving throws made against harmful gases and vapors.',
        description:
            'While wearing this necklace, you can breathe normally in any environment, and you have advantage on saving throws made against harmful gases and vapors (such as cloudkill, stinking cloud, inhaled poisons, and the breath weapons of some dragons).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Breathe in any environment; Advantage on saves against gases, vapors, and inhalation hazards.',
        description:
            'Grants continuous breathing in water, vacuum, or toxic atmospheres, and Advantage on saving throws vs noxious gases.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'necklace', 'breathing', 'adaptation', 'survival'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'necklace', 'breathing', 'adaptation', 'survival'] },
    ),

    // Periapt of Wound Closure
    EquipmentItem(
      id: EntityId(slug: 'item_periapt_of_wound_closure', ruleset: RulesetVersion.v2024), name: 'Periapt of Wound Closure',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Automatic stabilization when dying; doubles all HP restored from Hit Point Dice during Short Rests.',
      rules2014: ItemEditionDetails(
        summary:
            'While you wear this pendant, you stabilize whenever you are dying at the start of your turn. In addition, whenever you roll a Hit Die to regain hit points, double the number of hit points it restores.',
        description:
            'While you wear this pendant, you stabilize whenever you are dying at the start of your turn. In addition, whenever you roll a Hit Die to regain hit points, double the number of hit points it restores.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Automatic stabilization when dying; doubles all HP restored from Hit Point Dice during Short Rests.',
        description:
            'Stabilizes you automatically at the start of your turn if at 0 HP. Doubles HP recovered when rolling Hit Point Dice.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'periapt', 'healing', 'stabilize', 'hit dice'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'periapt', 'healing', 'stabilize', 'hit dice'] },
    ),

    // Portable Hole
    EquipmentItem(
      id: EntityId(slug: 'item_portable_hole', ruleset: RulesetVersion.v2024), name: 'Portable Hole',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Extradimensional hole 6 ft wide by 10 ft deep that folds up into a handkerchief-sized cloth.',
      rules2014: ItemEditionDetails(
        summary:
            'Unfolds into a circular 6-foot diameter hole leading to a 10-foot-deep extradimensional space.',
        description:
            'This fine black silk cloth folds up to the size of a handkerchief. When unfolded and placed against a solid surface, it creates an extradimensional hole 6 feet in diameter and 10 feet deep. Creatures inside have 10 minutes of air divided by the number of breathing creatures.',
        activation: '1 Action (Place / Fold)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Extradimensional hole 6 ft wide by 10 ft deep that folds up into a handkerchief-sized cloth.',
        description:
            'Unfold on a solid surface as an Action to open a 10-ft-deep cylinder storage hole. Breathable air lasts 10 minutes.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'portable hole', 'storage', 'extradimensional'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'portable hole', 'storage', 'extradimensional'] },
    ),

    // Slippers of Spider Climbing
    EquipmentItem(
      id: EntityId(slug: 'item_slippers_of_spider_climbing', ruleset: RulesetVersion.v2024), name: 'Slippers of Spider Climbing',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Grants Climb Speed equal to Speed on vertical surfaces and ceilings with hands free.',
      rules2014: ItemEditionDetails(
        summary:
            'While you wear these slippers, you have a climbing speed equal to your walking speed, and you can move up, down, and across vertical surfaces and upside down along ceilings, while leaving your hands free.',
        description:
            'While you wear these slippers, you have a climbing speed equal to your walking speed, and you can move up, down, and across vertical surfaces and upside down along ceilings, while leaving your hands free.',
        activation: 'Passive / Movement',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Grants Climb Speed equal to Speed on vertical surfaces and ceilings with hands free.',
        description:
            'Walk across walls and ceilings hands-free with a Climb Speed equal to your base Speed.',
        activation: 'Passive / Movement',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'slippers', 'climbing', 'spider climb', 'mobility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'slippers', 'climbing', 'spider climb', 'mobility'] },
    ),

    // Stone of Good Luck (Luckstone)
    EquipmentItem(
      id: EntityId(slug: 'item_stone_of_good_luck', ruleset: RulesetVersion.v2024), name: 'Stone of Good Luck (Luckstone)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: '+1 bonus to all Ability Checks (including Initiative) and all Saving Throws while carried.',
      rules2014: ItemEditionDetails(
        summary:
            'While this polished agate is on your person, you gain a +1 bonus to ability checks and saving throws.',
        description:
            'While this polished agate is on your person, you gain a +1 bonus to ability checks and saving throws.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 bonus to all Ability Checks (including Initiative) and all Saving Throws while carried.',
        description:
            'While carrying this stone, you gain a +1 bonus to all Ability Checks and Saving Throws.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'stone', 'luck', 'ability check', 'saving throw'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'stone', 'luck', 'ability check', 'saving throw'] },
    ),

    // Pearl of Power
    EquipmentItem(
      id: EntityId(slug: 'item_pearl_of_power', ruleset: RulesetVersion.v2024), name: 'Pearl of Power',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: 'Action: regain 1 expended spell slot of level 1–3 once per Long Rest.',
      rules2014: ItemEditionDetails(
        summary:
            'Use an action to speak command word and regain 1 expended spell slot of up to 3rd level once per day.',
        description:
            'While this pearl is on your person, you can use an action to speak its command word and regain one expended spell slot. If the expended slot was of 4th level or higher, the new slot is 3rd level. Once you use the pearl, it can\'t be used again until the next dawn.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: regain 1 expended spell slot of level 1–3 once per Long Rest.',
        description:
            'While holding or carrying this pearl, you can use an Action to regain one expended spell slot of up to level 3 (once per Long Rest).',
        activation: '1 Action (1/Long Rest)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'pearl', 'spell slot', 'spellcaster'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'pearl', 'spell slot', 'spellcaster'] },
    ),

    // Robe of the Archmagi (White)
    EquipmentItem(
      id: EntityId(slug: 'item_robe_of_the_archmagi_white', ruleset: RulesetVersion.v2024), name: 'Robe of the Archmagi (White)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true, attunementRequirement: 'by a Good Sorcerer, Warlock, or Wizard',
      descriptionMarkdown: 'White Robe (Good): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
      rules2014: ItemEditionDetails(
        summary:
            'White Robe (Good): Base AC 15 + Dex, Advantage on saves vs spells, and +2 bonus to spell save DCs and spell attack rolls.',
        description:
            'This white silk garment is made for good-aligned spellcasters. Your base AC becomes 15 + Dex; you have advantage on saving throws against spells and magical effects; and your spell save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'White Robe (Good): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
        description:
            'While wearing this white robe, your base Armor Class equals 15 + Dexterity modifier. You have Advantage on saving throws against spells and magical effects, and your Spell Save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'robe',
        'white',
        'archmagi',
        'good',
        'wizard',
        'sorcerer',
        'warlock',
        'legendary'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'robe', 'white', 'archmagi', 'good', 'wizard', 'sorcerer', 'warlock', 'legendary'] },
    ),

    // Robe of the Archmagi (Gray)
    EquipmentItem(
      id: EntityId(slug: 'item_robe_of_the_archmagi_gray', ruleset: RulesetVersion.v2024), name: 'Robe of the Archmagi (Gray)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true, attunementRequirement: 'by a Neutral Sorcerer, Warlock, or Wizard',
      descriptionMarkdown: 'Gray Robe (Neutral): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
      rules2014: ItemEditionDetails(
        summary:
            'Gray Robe (Neutral): Base AC 15 + Dex, Advantage on saves vs spells, and +2 bonus to spell save DCs and spell attack rolls.',
        description:
            'This gray silk garment is made for neutral-aligned spellcasters. Your base AC becomes 15 + Dex; you have advantage on saving throws against spells and magical effects; and your spell save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Gray Robe (Neutral): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
        description:
            'While wearing this gray robe, your base Armor Class equals 15 + Dexterity modifier. You have Advantage on saving throws against spells and magical effects, and your Spell Save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'robe',
        'gray',
        'grey',
        'archmagi',
        'neutral',
        'wizard',
        'sorcerer',
        'warlock',
        'legendary'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'robe', 'gray', 'grey', 'archmagi', 'neutral', 'wizard', 'sorcerer', 'warlock', 'legendary'] },
    ),

    // Robe of the Archmagi (Black)
    EquipmentItem(
      id: EntityId(slug: 'item_robe_of_the_archmagi_black', ruleset: RulesetVersion.v2024), name: 'Robe of the Archmagi (Black)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true, attunementRequirement: 'by an Evil Sorcerer, Warlock, or Wizard',
      descriptionMarkdown: 'Black Robe (Evil): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
      rules2014: ItemEditionDetails(
        summary:
            'Black Robe (Evil): Base AC 15 + Dex, Advantage on saves vs spells, and +2 bonus to spell save DCs and spell attack rolls.',
        description:
            'This black silk garment is made for evil-aligned spellcasters. Your base AC becomes 15 + Dex; you have advantage on saving throws against spells and magical effects; and your spell save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Black Robe (Evil): Base AC 15 + Dex, Advantage on saves vs spells/effects, and +2 to your Spell Save DC and spell attack rolls.',
        description:
            'While wearing this black robe, your base Armor Class equals 15 + Dexterity modifier. You have Advantage on saving throws against spells and magical effects, and your Spell Save DC and spell attack bonus each increase by 2.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'robe',
        'black',
        'archmagi',
        'evil',
        'wizard',
        'sorcerer',
        'warlock',
        'legendary'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'robe', 'black', 'archmagi', 'evil', 'wizard', 'sorcerer', 'warlock', 'legendary'] },
    ),

    // Bag of Tricks (Gray)
    EquipmentItem(
      id: EntityId(slug: 'item_bag_of_tricks_gray', ruleset: RulesetVersion.v2024), name: 'Bag of Tricks (Gray)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: throw fuzzy ball up to 20 ft to summon a Gray Beast (d8: Weasel, Giant Rat, Badger, Boar, Panther, Giant Badger, Dire Wolf, Giant Elk). 3/Long Rest.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: throw a fuzzy ball up to 20 ft to summon a Gray Beast (d8: 1=Weasel, 2=Giant Rat, 3=Badger, 4=Boar, 5=Panther, 6=Giant Badger, 7=Dire Wolf, 8=Giant Elk). 3 pulls/day.',
        description:
            'Reaching inside this gray cloth sack pulls out a small fuzzy ball. As an action, throw it up to 20 feet: transforms into a friendly beast rolled on the Gray Table (1: Weasel, 2: Giant Rat, 3: Badger, 4: Boar, 5: Panther, 6: Giant Badger, 7: Dire Wolf, 8: Giant Elk). Max 3 creatures per day (recharges at dawn). Acts on your turn and obeys verbal commands.',
        activation: '1 Action (3/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: throw fuzzy ball up to 20 ft to summon a Gray Beast (d8: Weasel, Giant Rat, Badger, Boar, Panther, Giant Badger, Dire Wolf, Giant Elk). 3/Long Rest.',
        description:
            'Pull a fuzzy ball from the gray bag and throw it up to 20 feet as an Action. It turns into a friendly beast chosen by rolling a d8 (1: Weasel, 2: Giant Rat, 3: Badger, 4: Boar, 5: Panther, 6: Giant Badger, 7: Dire Wolf, 8: Giant Elk). Up to 3 creatures per Long Rest.',
        activation: '1 Action (3/Long Rest)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'bag',
        'summon',
        'gray',
        'grey',
        'beast',
        'tricks',
        'minions'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bag', 'summon', 'gray', 'grey', 'beast', 'tricks', 'minions'] },
    ),

    // Bag of Tricks (Rust)
    EquipmentItem(
      id: EntityId(slug: 'item_bag_of_tricks_rust', ruleset: RulesetVersion.v2024), name: 'Bag of Tricks (Rust)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: throw fuzzy ball up to 20 ft to summon a Rust Beast (d8: Rat, Owl, Mastiff, Goat, Giant Goat, Giant Boar, Lion, Brown Bear). 3/Long Rest.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: throw a fuzzy ball up to 20 ft to summon a Rust Beast (d8: 1=Rat, 2=Owl, 3=Mastiff, 4=Goat, 5=Giant Goat, 6=Giant Boar, 7=Lion, 8=Brown Bear). 3 pulls/day.',
        description:
            'Reaching inside this rust-colored sack pulls out a small fuzzy ball. As an action, throw it up to 20 feet: transforms into a friendly beast rolled on the Rust Table (1: Rat, 2: Owl, 3: Mastiff, 4: Goat, 5: Giant Goat, 6: Giant Boar, 7: Lion, 8: Brown Bear). Max 3 creatures per day (recharges at dawn). Acts on your turn and obeys verbal commands.',
        activation: '1 Action (3/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: throw fuzzy ball up to 20 ft to summon a Rust Beast (d8: Rat, Owl, Mastiff, Goat, Giant Goat, Giant Boar, Lion, Brown Bear). 3/Long Rest.',
        description:
            'Pull a fuzzy ball from the rust bag and throw it up to 20 feet as an Action. It turns into a friendly beast chosen by rolling a d8 (1: Rat, 2: Owl, 3: Mastiff, 4: Goat, 5: Giant Goat, 6: Giant Boar, 7: Lion, 8: Brown Bear). Up to 3 creatures per Long Rest.',
        activation: '1 Action (3/Long Rest)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'bag', 'summon', 'rust', 'beast', 'tricks', 'minions'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bag', 'summon', 'rust', 'beast', 'tricks', 'minions'] },
    ),

    // Bag of Tricks (Tan)
    EquipmentItem(
      id: EntityId(slug: 'item_bag_of_tricks_tan', ruleset: RulesetVersion.v2024), name: 'Bag of Tricks (Tan)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: throw fuzzy ball up to 20 ft to summon a Tan Beast (d8: Jackal, Ape, Baboon, Axe Beak, Black Bear, Giant Weasel, Giant Hyena, Tiger). 3/Long Rest.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: throw a fuzzy ball up to 20 ft to summon a Tan Beast (d8: 1=Jackal, 2=Ape, 3=Baboon, 4=Axe Beak, 5=Black Bear, 6=Giant Weasel, 7=Giant Hyena, 8=Tiger). 3 pulls/day.',
        description:
            'Reaching inside this tan cloth sack pulls out a small fuzzy ball. As an action, throw it up to 20 feet: transforms into a friendly beast rolled on the Tan Table (1: Jackal, 2: Ape, 3: Baboon, 4: Axe Beak, 5: Black Bear, 6: Giant Weasel, 7: Giant Hyena, 8: Tiger). Max 3 creatures per day (recharges at dawn). Acts on your turn and obeys verbal commands.',
        activation: '1 Action (3/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: throw fuzzy ball up to 20 ft to summon a Tan Beast (d8: Jackal, Ape, Baboon, Axe Beak, Black Bear, Giant Weasel, Giant Hyena, Tiger). 3/Long Rest.',
        description:
            'Pull a fuzzy ball from the tan bag and throw it up to 20 feet as an Action. It turns into a friendly beast chosen by rolling a d8 (1: Jackal, 2: Ape, 3: Baboon, 4: Axe Beak, 5: Black Bear, 6: Giant Weasel, 7: Giant Hyena, 8: Tiger). Up to 3 creatures per Long Rest.',
        activation: '1 Action (3/Long Rest)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'bag', 'summon', 'tan', 'beast', 'tricks', 'minions'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bag', 'summon', 'tan', 'beast', 'tricks', 'minions'] },
    ),

    // Ioun Stone (Deep Red)
    EquipmentItem(
      id: EntityId(slug: 'item_ioun_stone_deep_red', ruleset: RulesetVersion.v2024), name: 'Ioun Stone (Deep Red)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Orbiting deep red sphere gives +2 Dexterity score (max 20).',
      rules2014: ItemEditionDetails(
        summary:
            'Your Dexterity score increases by 2, to a maximum of 20, while this deep red sphere orbits your head.',
        description:
            'While this deep red marble orbits your head, your Dexterity score increases by 2, to a maximum of 20.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Orbiting deep red sphere gives +2 Dexterity score (max 20).',
        description:
            'Your Dexterity score increases by 2 (maximum of 20) while this stone orbits your head.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'ioun stone', 'deep red', 'dexterity', 'stat boost'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'ioun stone', 'deep red', 'dexterity', 'stat boost'] },
    ),

    // Ioun Stone (Incandescent Blue)
    EquipmentItem(
      id: EntityId(slug: 'item_ioun_stone_incandescent_blue', ruleset: RulesetVersion.v2024), name: 'Ioun Stone (Incandescent Blue)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Orbiting blue sphere gives +2 Wisdom score (max 20).',
      rules2014: ItemEditionDetails(
        summary:
            'Your Wisdom score increases by 2, to a maximum of 20, while this incandescent blue sphere orbits your head.',
        description:
            'While this glowing blue sphere orbits your head, your Wisdom score increases by 2, to a maximum of 20.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Orbiting blue sphere gives +2 Wisdom score (max 20).',
        description:
            'Your Wisdom score increases by 2 (maximum of 20) while this stone orbits your head.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'ioun stone',
        'incandescent blue',
        'wisdom',
        'stat boost'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'ioun stone', 'incandescent blue', 'wisdom', 'stat boost'] },
    ),

    // Ioun Stone (Pale Green)
    EquipmentItem(
      id: EntityId(slug: 'item_ioun_stone_pale_green', ruleset: RulesetVersion.v2024), name: 'Ioun Stone (Pale Green)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Orbiting prism gives +1 bonus to attack rolls, saving throws, and ability checks.',
      rules2014: ItemEditionDetails(
        summary:
            'You gain a +1 bonus to all attack rolls, saving throws, ability checks, and skill checks while this pale green prism orbits your head.',
        description:
            'You gain a +1 bonus to attack rolls, saving throws, ability checks, and skill checks while this pale green prism orbits your head.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Orbiting prism gives +1 bonus to attack rolls, saving throws, and ability checks.',
        description:
            'While this prism orbits your head, you gain a +1 bonus to all attack rolls, saving throws, and ability checks.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'ioun stone',
        'pale green',
        'attacks',
        'saves',
        'checks'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'ioun stone', 'pale green', 'attacks', 'saves', 'checks'] },
    ),

    // Ioun Stone (Dusty Rose)
    EquipmentItem(
      id: EntityId(slug: 'item_ioun_stone_dusty_rose', ruleset: RulesetVersion.v2024), name: 'Ioun Stone (Dusty Rose)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Orbiting prism gives +1 bonus to Armor Class (AC).',
      rules2014: ItemEditionDetails(
        summary:
            'You gain a +1 bonus to AC while this dusty rose prism orbits your head.',
        description:
            'You gain a +1 bonus to AC while this dusty rose prism orbits your head.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Orbiting prism gives +1 bonus to Armor Class (AC).',
        description:
            'You gain a +1 bonus to AC while this stone orbits your head.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'ioun stone',
        'dusty rose',
        'ac',
        'protection',
        'pink'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'ioun stone', 'dusty rose', 'ac', 'protection', 'pink'] },
    ),

    // Ioun Stone (Clear Spindle)
    EquipmentItem(
      id: EntityId(slug: 'item_ioun_stone_clear_spindle', ruleset: RulesetVersion.v2024), name: 'Ioun Stone (Clear Spindle)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Orbiting crystal provides total sustenance without food or water.',
      rules2014: ItemEditionDetails(
        summary:
            'You don\'t need to eat or drink while this clear spindle orbits your head.',
        description:
            'A translucent crystal spindle that sustains your biological body completely without food or water while orbiting.',
        activation: '1 Action (Toss into orbit)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Orbiting crystal provides total sustenance without food or water.',
        description:
            'You don\'t need food or water while this clear spindle orbits your head.',
        activation: '1 Action (Orbit)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'ioun stone', 'clear spindle', 'sustenance', 'white'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'ioun stone', 'clear spindle', 'sustenance', 'white'] },
    ),

    // Ioun Stone (Reserve)
    EquipmentItem(
      id: EntityId(slug: 'item_ioun_stone_reserve', ruleset: RulesetVersion.v2024), name: 'Ioun Stone (Reserve)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Stores up to 3 levels of spells. Cast stored spells with original caster stats.',
      rules2014: ItemEditionDetails(
        summary:
            'Stores up to 3 levels of spells that any creature can cast into it by touching it. You can cast stored spells using original caster stats.',
        description:
            'This vibrant purple rhomboid stores up to 3 levels of spells. Any creature can cast a spell of 1st through 3rd level into it by touching it as the spell is cast. You can cast any spell stored in it with the original slot level, save DC, attack bonus, and spellcasting ability.',
        activation: 'Cast stored spell',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Stores up to 3 levels of spells. Cast stored spells with original caster stats.',
        description:
            'Holds up to 3 spell slot levels that can be cast by the attuner.',
        activation: 'Cast stored spell',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'ioun stone', 'reserve', 'spell storage', 'purple'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'ioun stone', 'reserve', 'spell storage', 'purple'] },
    ),

    // Belt of Hill Giant Strength
    EquipmentItem(
      id: EntityId(slug: 'item_belt_of_hill_giant_strength', ruleset: RulesetVersion.v2024), name: 'Belt of Hill Giant Strength',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets your Strength score to 21 (+5).',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this belt, your Strength score is 21 (+5 modifier). Has no effect if your Strength is already 21 or higher.',
        description:
            'While wearing this belt, your Strength score changes to 21. If your Strength is already equal to or greater than 21, the item has no effect on you.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to 21 (+5).',
        description: 'Your Strength score becomes 21 while wearing this belt.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'belt',
        'giant strength',
        'hill giant',
        'strength',
        'melee'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'belt', 'giant strength', 'hill giant', 'strength', 'melee'] },
    ),

    // Belt of Frost Giant Strength
    EquipmentItem(
      id: EntityId(slug: 'item_belt_of_frost_giant_strength', ruleset: RulesetVersion.v2024), name: 'Belt of Frost Giant Strength',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets your Strength score to 23 (+6).',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this belt, your Strength score is 23 (+6 modifier).',
        description:
            'While wearing this belt, your Strength score changes to 23.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to 23 (+6).',
        description: 'Your Strength score becomes 23 while wearing this belt.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'belt',
        'giant strength',
        'frost giant',
        'strength',
        'melee'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'belt', 'giant strength', 'frost giant', 'strength', 'melee'] },
    ),

    // Belt of Fire Giant Strength
    EquipmentItem(
      id: EntityId(slug: 'item_belt_of_fire_giant_strength', ruleset: RulesetVersion.v2024), name: 'Belt of Fire Giant Strength',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets your Strength score to 25 (+7).',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this belt, your Strength score is 25 (+7 modifier).',
        description:
            'While wearing this belt, your Strength score changes to 25.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to 25 (+7).',
        description: 'Your Strength score becomes 25 while wearing this belt.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'belt',
        'giant strength',
        'fire giant',
        'strength',
        'melee'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'belt', 'giant strength', 'fire giant', 'strength', 'melee'] },
    ),

    // Belt of Storm Giant Strength
    EquipmentItem(
      id: EntityId(slug: 'item_belt_of_storm_giant_strength', ruleset: RulesetVersion.v2024), name: 'Belt of Storm Giant Strength',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets your Strength score to 29 (+9).',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this belt, your Strength score is 29 (+9 modifier).',
        description:
            'While wearing this belt, your Strength score changes to 29.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets your Strength score to 29 (+9).',
        description: 'Your Strength score becomes 29 while wearing this belt.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'belt',
        'giant strength',
        'storm giant',
        'strength',
        'melee',
        'legendary'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'belt', 'giant strength', 'storm giant', 'strength', 'melee', 'legendary'] },
    ),

    // Silver Horn of Valhalla
    EquipmentItem(
      id: EntityId(slug: 'item_horn_of_valhalla_silver', ruleset: RulesetVersion.v2024), name: 'Silver Horn of Valhalla',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Summon 2d4 + 2 spirit Berserkers for 1 hour (1/7 Days).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Blow horn to summon 2d4 + 2 warrior spirits from Ysgard for 1 hour. Recharges in 7 days.',
        description:
            'You can use an action to blow this silver horn: summons 2d4 + 2 spirit Berserkers to fight alongside you for up to 1 hour (recharges every 7 days). Requires martial weapon proficiency.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Summon 2d4 + 2 spirit Berserkers for 1 hour (1/7 Days).',
        description:
            'Blow the silver horn as an Action to summon allied Berserker warrior spirits.',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'horn', 'valhalla', 'silver', 'summon', 'berserker'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'horn', 'valhalla', 'silver', 'summon', 'berserker'] },
    ),

    // Iron Horn of Valhalla
    EquipmentItem(
      id: EntityId(slug: 'item_horn_of_valhalla_iron', ruleset: RulesetVersion.v2024), name: 'Iron Horn of Valhalla',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Summon 5d4 + 5 spirit Berserkers for 1 hour (1/7 Days).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Blow horn to summon 5d4 + 5 warrior spirits from Ysgard for 1 hour. Recharges in 7 days.',
        description:
            'You can use an action to blow this heavy iron horn: summons 5d4 + 5 spirit Berserkers to fight alongside you for up to 1 hour (recharges every 7 days). Requires proficiency with all armor.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Summon 5d4 + 5 spirit Berserkers for 1 hour (1/7 Days).',
        description:
            'Blow the iron horn as an Action to summon allied Berserker warrior spirits.',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'horn',
        'valhalla',
        'iron',
        'summon',
        'berserker',
        'legendary'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'horn', 'valhalla', 'iron', 'summon', 'berserker', 'legendary'] },
    ),

    // Figurine of Wondrous Power (Bronze Griffon)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_bronze_griffon', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Bronze Griffon)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into a living Griffon mount for 24 hours.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Speak command word and throw figurine to animate into a living Griffon mount for up to 24 hours (usable twice every 10 days).',
        description:
            'This bronze statuette transforms into a living Griffon when thrown up to 60 feet. It obeys your spoken commands and serves as a flying mount for up to 24 hours. Usable twice per 10 days.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Animate into a living Griffon mount for 24 hours.',
        description:
            'Throws up to 60 feet to become a loyal flying Griffon mount for up to 24 hours.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'figurine', 'bronze', 'griffon', 'summon', 'mount'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'bronze', 'griffon', 'summon', 'mount'] },
    ),

    // Figurine of Wondrous Power (Ebony Fly)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_ebony_fly', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Ebony Fly)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into a giant fly mount for 12 hours.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Speak command word to animate into a pony-sized giant fly for up to 12 hours (usable three times per 8 days).',
        description:
            'Transforms into a giant fly with fly speed 60 ft for up to 12 hours. Can carry up to 240 lbs.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Animate into a giant fly mount for 12 hours.',
        description: 'Transforms into a pony-sized flying mount for 12 hours.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'figurine', 'ebony', 'fly', 'summon', 'mount'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'ebony', 'fly', 'summon', 'mount'] },
    ),

    // Figurine of Wondrous Power (Marble Elephant)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_marble_elephant', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Marble Elephant)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into an Elephant for 24 hours (1/7 Days).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Transforms into a living Elephant for up to 24 hours (recharges once every 7 days).',
        description:
            'Transforms into a full-sized Elephant for up to 24 hours. Usable once every 7 days.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Animate into an Elephant for 24 hours (1/7 Days).',
        description:
            'Transforms into a massive elephant mount and heavy beast for 24 hours.',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'figurine',
        'marble',
        'elephant',
        'summon',
        'mount',
        'white'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'marble', 'elephant', 'summon', 'mount', 'white'] },
    ),

    // Figurine of Wondrous Power (Golden Lions)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_golden_lions', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Golden Lions)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into two living adult Lions for 1 hour.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Speak command word and throw figurine to animate into two living adult Lions for up to 1 hour (usable once every 7 days).',
        description:
            'These golden statuettes are sculpted in the likeness of lions. You can throw them up to 60 feet to become two living lions. If either lion is reduced to 0 HP, it reverts to a figurine and cannot be used again until 7 days have passed.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Animate into two living adult Lions for 1 hour.',
        description:
            'Throws up to 60 feet to become a coordinated hunting pair of two adult lions for up to 1 hour.',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'figurine', 'gold', 'lion', 'summon', 'pack tactics'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'gold', 'lion', 'summon', 'pack tactics'] },
    ),

    // Figurine of Wondrous Power (Ivory Goats)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_ivory_goats', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Ivory Goats)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into Goat of Traveling, Goat of Travail, or Goat of Terror.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Transforms into one of three ivory goats: Goat of Traveling (24 hrs/30 days), Goat of Travail (12 hrs, 1/30 days, +16 bludgeoning charge), or Goat of Terror (3 hrs, 1/30 days, DC 15 Aura of Terror).',
        description:
            'Set of three ivory goats carved with distinct features:\n• Goat of Traveling: Swift Large mount usable up to 24 hours per 30-day period.\n• Goat of Travail: Heavy war mount with 44 HP, Multiattack, and +16 bludgeoning charge.\n• Goat of Terror: Dread mount radiating a 30-foot Aura of Terror (DC 15 Wis save or frightened and grant advantage).',
        activation: '1 Action (Varies per goat)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Animate into Goat of Traveling, Goat of Travail, or Goat of Terror.',
        description:
            'Three distinct ivory statuettes transforming into specialized travel, combat, and terror goats.',
        activation: '1 Action (Varies per goat)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'figurine',
        'ivory',
        'goat',
        'summon',
        'mount',
        'terror'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'ivory', 'goat', 'summon', 'mount', 'terror'] },
    ),

    // Figurine of Wondrous Power (Obsidian Steed)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_obsidian_steed', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Obsidian Steed)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into a Nightmare mount with Ethereal Stride for 24 hours.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Transforms into a living Nightmare mount with Fly 90 ft., fire resistance grant, and Ethereal Stride for up to 24 hours (usable once every 5 days).',
        description:
            'A black volcanic glass statuette resembling a horse. Transforms into a living Nightmare. It can grant fire resistance to its rider and shift into the Ethereal Plane along with its rider. If the user is of good alignment, there is a chance the steed ignores commands or turns hostile.',
        activation: '1 Action (1/5 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Animate into a Nightmare mount with Ethereal Stride for 24 hours.',
        description:
            'Transforms into a terrifying Nightmare flying mount with planar travel and fire conferral.',
        activation: '1 Action (1/5 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'figurine',
        'obsidian',
        'nightmare',
        'steed',
        'summon',
        'mount',
        'fly',
        'ethereal'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'obsidian', 'nightmare', 'steed', 'summon', 'mount', 'fly', 'ethereal'] },
    ),

    // Figurine of Wondrous Power (Onyx Dog)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_onyx_dog', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Onyx Dog)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into an intelligent Mastiff with Truesight for 6 hours.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Transforms into an Onyx Mastiff with Int 8, Truesight 60 ft., and understanding of Common, Giant, and Goblin for up to 6 hours (usable once every 7 days).',
        description:
            'A sleek black dog carving. Transforms into a loyal mastiff with Keen Hearing/Smell, Pack Tactics, Truesight out to 60 feet (seeing invisible creatures/objects), and intelligence 8.',
        activation: '1 Action (1/7 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Animate into an intelligent Mastiff with Truesight for 6 hours.',
        description:
            'Transforms into a loyal hunting mastiff with 60 ft. Truesight and high intelligence.',
        activation: '1 Action (1/7 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'figurine',
        'onyx',
        'dog',
        'mastiff',
        'summon',
        'truesight',
        'invisible'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'onyx', 'dog', 'mastiff', 'summon', 'truesight', 'invisible'] },
    ),

    // Figurine of Wondrous Power (Serpentine Owl)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_serpentine_owl', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Serpentine Owl)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into a Giant Owl scout with 1-mile telepathy for 8 hours.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Transforms into a Giant Owl with Flyby and 1-mile telepathic communication for up to 8 hours (usable once every 2 days).',
        description:
            'A serpent-patterned green statuette. Transforms into a Giant Owl with fly speed 60 ft., Flyby, 120 ft. darkvision, and a continuous telepathic bond allowing you to communicate telepathically across 1 mile.',
        activation: '1 Action (1/2 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Animate into a Giant Owl scout with 1-mile telepathy for 8 hours.',
        description:
            'Transforms into a flying owl scout with Flyby and long-range telepathic report link.',
        activation: '1 Action (1/2 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'figurine',
        'serpentine',
        'owl',
        'summon',
        'flyby',
        'telepathy'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'serpentine', 'owl', 'summon', 'flyby', 'telepathy'] },
    ),

    // Figurine of Wondrous Power (Silver Raven)
    EquipmentItem(
      id: EntityId(slug: 'item_figurine_silver_raven', ruleset: RulesetVersion.v2024), name: 'Figurine of Wondrous Power (Silver Raven)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Animate into a message-delivering Silver Raven for 12 to 24 hours.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Transforms into a Silver Raven that can deliver spoken messages as Animal Messenger for up to 12 hours (or 24 hours on a message flight, usable once every 2 days).',
        description:
            'A polished silver raven statuette. Transforms into a living raven with fly speed 50 ft. and mimicry. You can command it to deliver a spoken message to a distant recipient as if under the Animal Messenger spell.',
        activation: '1 Action (1/2 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Animate into a message-delivering Silver Raven for 12 to 24 hours.',
        description:
            'Transforms into an agile raven courier that flies to deliver spoken messages across long distances.',
        activation: '1 Action (1/2 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'figurine',
        'silver',
        'raven',
        'summon',
        'messenger',
        'mimicry'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'figurine', 'silver', 'raven', 'summon', 'messenger', 'mimicry'] },
    ),

    // Elemental Gem (Blue Sapphire - Air)
    EquipmentItem(
      id: EntityId(slug: 'item_elemental_gem_blue_sapphire', ruleset: RulesetVersion.v2024), name: 'Elemental Gem (Blue Sapphire)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Crush gem to summon a CR 5 Air Elemental for 1 hour.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Crush gem to cast Conjure Elemental summoning a CR 5 Air Elemental for up to 1 hour (consumable).',
        description:
            'Crush this sapphire as an action to summon a friendly Air Elemental for 1 hour. The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Crush gem to summon a CR 5 Air Elemental for 1 hour.',
        description: 'Summons an Air Elemental companion for 1 hour.',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'gem', 'elemental', 'blue sapphire', 'air', 'summon'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gem', 'elemental', 'blue sapphire', 'air', 'summon'] },
    ),

    // Elemental Gem (Red Corundum - Fire)
    EquipmentItem(
      id: EntityId(slug: 'item_elemental_gem_red_corundum', ruleset: RulesetVersion.v2024), name: 'Elemental Gem (Red Corundum)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Crush gem to summon a CR 5 Fire Elemental for 1 hour.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Crush gem to cast Conjure Elemental summoning a CR 5 Fire Elemental for up to 1 hour (consumable).',
        description:
            'Crush this red corundum as an action to summon a friendly Fire Elemental for 1 hour. The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Crush gem to summon a CR 5 Fire Elemental for 1 hour.',
        description: 'Summons a Fire Elemental companion for 1 hour.',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'gem', 'elemental', 'red corundum', 'fire', 'summon'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gem', 'elemental', 'red corundum', 'fire', 'summon'] },
    ),

    // Elemental Gem (Yellow Diamond - Earth)
    EquipmentItem(
      id: EntityId(slug: 'item_elemental_gem_yellow_diamond', ruleset: RulesetVersion.v2024), name: 'Elemental Gem (Yellow Diamond)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Crush gem to summon a CR 5 Earth Elemental for 1 hour.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Crush gem to cast Conjure Elemental summoning a CR 5 Earth Elemental for up to 1 hour (consumable).',
        description:
            'Crush this yellow diamond as an action to summon a friendly Earth Elemental for 1 hour. The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Crush gem to summon a CR 5 Earth Elemental for 1 hour.',
        description: 'Summons an Earth Elemental companion for 1 hour.',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'gem',
        'elemental',
        'yellow diamond',
        'earth',
        'summon'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gem', 'elemental', 'yellow diamond', 'earth', 'summon'] },
    ),

    // Elemental Gem (Emerald - Water)
    EquipmentItem(
      id: EntityId(slug: 'item_elemental_gem_emerald', ruleset: RulesetVersion.v2024), name: 'Elemental Gem (Emerald)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Crush gem to summon a CR 5 Water Elemental for 1 hour.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Crush gem to cast Conjure Elemental summoning a CR 5 Water Elemental for up to 1 hour (consumable).',
        description:
            'Crush this emerald as an action to summon a friendly Water Elemental for 1 hour. The gem is destroyed.',
        activation: '1 Action (Consumable)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Crush gem to summon a CR 5 Water Elemental for 1 hour.',
        description: 'Summons a Water Elemental companion for 1 hour.',
        activation: '1 Action (Consumable)',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'gem', 'elemental', 'emerald', 'water', 'summon'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gem', 'elemental', 'emerald', 'water', 'summon'] },
    ),

    // Decanter of Endless Water
    EquipmentItem(
      id: EntityId(slug: 'item_decanter_of_endless_water', ruleset: RulesetVersion.v2024), name: 'Decanter of Endless Water',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Produces continuous fresh/salt water up to Geyser mode (30 gal/round, 30 ft push/prone).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Unstopper and produce endless water: Stream (1 gal), Fountain (5 gal), or Geyser (30 gal, 30 ft blast, 1d4 bludgeoning, DC 13 Str or prone).',
        description:
            'You can use an action and speak one of three command words to produce fresh or salt water: Stream (1 gallon), Fountain (5 gallons), or Geyser (30 gallons, 30 ft line, DC 13 Strength save or take 1d4 bludgeoning damage and fall prone).',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Produces continuous fresh/salt water up to Geyser mode (30 gal/round, 30 ft push/prone).',
        description: 'Produces Stream, Fountain, or Geyser volume on command.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'decanter', 'water', 'utility', 'geyser'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'decanter', 'water', 'utility', 'geyser'] },
    ),

    // Instant Fortress
    EquipmentItem(
      id: EntityId(slug: 'item_instant_fortress', ruleset: RulesetVersion.v2024), name: 'Instant Fortress',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Expands into 30-ft tall adamantine fortress (10d10 bludgeoning damage on expansion).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: Place 1-inch cube on ground and speak command word to instantly expand into a 20-ft square, 30-ft tall adamantine tower (10d10 bludgeoning, DC 15 Dex save for half).',
        description:
            'A 1-inch metal cube that expands into a 30-foot tall adamantine fortress with arrow slits and battlement roof. Creatures in its footprint must make a DC 15 Dex save or take 10d10 bludgeoning damage and be pushed away.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Expands into 30-ft tall adamantine fortress (10d10 bludgeoning damage on expansion).',
        description: 'Expands into a fortified tower and shelter.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'fortress',
        'adamantine',
        'shelter',
        'cube',
        'structure'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'fortress', 'adamantine', 'shelter', 'cube', 'structure'] },
    ),

    // Robe of Useful Items
    EquipmentItem(
      id: EntityId(slug: 'item_robe_of_useful_items', ruleset: RulesetVersion.v2024), name: 'Robe of Useful Items',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: Detach patch to produce the depicted mundane object, vehicle, or creature.',
      rules2014: ItemEditionDetails(
        summary:
            'Robe covered with cloth patches representing items (Daggers, Lanterns, Mirrors, 10-ft Poles, Ropes, Horses, Boats, etc.). Detach patch as an action to transform it into the real item.',
        description:
            'This robe has cloth patches of various shapes and colors. You can use an action to detach one of the patches, causing it to become the object or creature it represents.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: Detach patch to produce the depicted mundane object, vehicle, or creature.',
        description:
            'Detach cloth patch as an Action to materialize the item in your space.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'robe', 'useful items', 'patches', 'utility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'robe', 'useful items', 'patches', 'utility'] },
    ),

    // Apparatus of the Crab (Apparatus of Kwalish)
    EquipmentItem(
      id: EntityId(slug: 'item_apparatus_of_the_crab', ruleset: RulesetVersion.v2024), name: 'Apparatus of the Crab',
      name2014: 'Apparatus of Kwalish', name2024: 'Apparatus of the Crab',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'Piloted mechanical crab vehicle with swim speed, heavy pincers, and sealed life support.',
      rules2014: ItemEditionDetails(
        summary:
            'Large iron barrel that transforms into a piloted mechanical lobster/crab submersible holding up to 2 medium creatures with 10 levers.',
        description:
            'This item appears as a large sealed iron barrel. When activated, it transforms into an amphibious crab vehicle with speed 30 ft, swim 30 ft, AC 20, 200 HP, and mechanical levers to operate pincer attacks and floodlights.',
        activation: 'Action (Lever operation)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Piloted mechanical crab vehicle with swim speed, heavy pincers, and sealed life support.',
        description:
            'Amphibious submersible mechanical vehicle for 2 creatures.',
        activation: 'Action (Operate)',
      ),
      isChangedIn2024: true, diffSummary: 'Apparatus of the Crab in 2024 Free SRD 5.2.1.', diffHighlights: [
        'Free SRD 5.2.1 trademark-clean name: Apparatus of the Crab',
        'Updated vehicle helm controls and simplified speed mechanics',
      ], tags: ['wondrous', 'vehicle', 'crab', 'submersible', 'legendary'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'vehicle', 'crab', 'submersible', 'legendary'] },
    ),

    // Boots of Elvenkind
    EquipmentItem(
      id: EntityId(slug: 'item_boots_of_elvenkind', ruleset: RulesetVersion.v2024), name: 'Boots of Elvenkind',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Footsteps produce zero sound; gain Advantage on Stealth checks relying on silent movement.',
      rules2014: ItemEditionDetails(
        summary:
            'While you wear these boots, your steps make no sound, regardless of the surface you are moving across. You also have advantage on Dexterity (Stealth) checks that rely on moving silently.',
        description:
            'While you wear these boots, your steps make no sound, regardless of the surface you are moving across. You also have advantage on Dexterity (Stealth) checks that rely on moving silently.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Footsteps produce zero sound; gain Advantage on Stealth checks relying on silent movement.',
        description:
            'Silences all footsteps and grants Advantage on Stealth checks.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'boots', 'stealth', 'silence', 'elven'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'boots', 'stealth', 'silence', 'elven'] },
    ),

    // Boots of Levitation
    EquipmentItem(
      id: EntityId(slug: 'item_boots_of_levitation', ruleset: RulesetVersion.v2024), name: 'Boots of Levitation',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Action: cast Levitate at will on yourself.',
      rules2014: ItemEditionDetails(
        summary:
            'While you wear these boots, you can cast the Levitate spell on yourself at will as an action.',
        description:
            'While you wear these boots, you can use an action to cast Levitate on yourself at will.',
        activation: '1 Action (At Will)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: cast Levitate at will on yourself.',
        description:
            'Allows at-will vertical levitation up to 20 feet per round.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'boots', 'levitate', 'mobility', 'flight'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'boots', 'levitate', 'mobility', 'flight'] },
    ),

    // Boots of the Winterlands
    EquipmentItem(
      id: EntityId(slug: 'item_boots_of_the_winterlands', ruleset: RulesetVersion.v2024), name: 'Boots of the Winterlands',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Cold Resistance, ignore snow/ice difficult terrain, complete protection against Extreme Cold.',
      rules2014: ItemEditionDetails(
        summary:
            'Grants resistance to cold damage, ignores difficult terrain composed of ice or snow, and protects you against extreme cold down to -50 degrees Fahrenheit.',
        description:
            'These furred boots provide warmth and stability in arctic conditions.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Cold Resistance, ignore snow/ice difficult terrain, complete protection against Extreme Cold.',
        description:
            'Arctic exploration boots providing cold defense and unimpeded winter mobility.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'boots', 'cold', 'winter', 'resistance', 'survival'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'boots', 'cold', 'winter', 'resistance', 'survival'] },
    ),

    // Brooch of Shielding
    EquipmentItem(
      id: EntityId(slug: 'item_brooch_of_shielding', ruleset: RulesetVersion.v2024), name: 'Brooch of Shielding',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Resistance to Force damage and 100% immunity to damage from Magic Missile.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this brooch, you have resistance to force damage, and you have immunity to damage from the Magic Missile spell.',
        description:
            'While wearing this brooch, you have resistance to force damage, and you have immunity to damage from the magic missile spell.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Resistance to Force damage and 100% immunity to damage from Magic Missile.',
        description:
            'Warded brooch neutralizing force darts and reducing force blasts by half.',
        activation: 'Passive',
      ),
      tags: [
        'wondrous',
        'brooch',
        'magic missile',
        'force',
        'immunity',
        'defense'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'brooch', 'magic missile', 'force', 'immunity', 'defense'] },
    ),

    // Broom of Flying
    EquipmentItem(
      id: EntityId(slug: 'item_broom_of_flying', ruleset: RulesetVersion.v2024), name: 'Broom of Flying',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Flying Speed 50 ft (30 ft if carrying 200–400 lbs). Remote summonable within 1 mile.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: speak command word to gain a flying speed of 50 feet (30 feet if carrying over 200 lbs, max 400 lbs). Can send the broom alone up to 1 mile away.',
        description:
            'This wooden broom functions as a magic vehicle with a flying speed of 50 feet while carrying up to 200 pounds, or 30 feet while carrying between 200 and 400 pounds. You can also command it to fly on its own to any location within 1 mile.',
        activation: '1 Action (Command Word)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Flying Speed 50 ft (30 ft if carrying 200–400 lbs). Remote summonable within 1 mile.',
        description:
            'Iconic flying broom supporting aerial transport for rider and gear.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'broom', 'flying', 'flight', 'vehicle', 'mobility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'broom', 'flying', 'flight', 'vehicle', 'mobility'] },
    ),

    // Cape of the Mountebank
    EquipmentItem(
      id: EntityId(slug: 'item_cape_of_the_mountebank', ruleset: RulesetVersion.v2024), name: 'Cape of the Mountebank',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: cast Dimension Door with dramatic obscuring smoke clouds (1/Long Rest).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: cast Dimension Door (recharges daily at dawn). Leaves behind a 5-foot-radius cloud of heavy smoke at both the origin and destination.',
        description:
            'This cape smells faintly of brimstone. While wearing it, you can use an action to cast the Dimension Door spell from it. When the spell takes effect, you vanish in a cloud of thick smoke that heavily obscures the space you left and the destination space until the end of your next turn.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: cast Dimension Door with dramatic obscuring smoke clouds (1/Long Rest).',
        description:
            'Teleportation cape allowing a 500-foot jump and sensory concealment.',
        activation: '1 Action (1/Long Rest)',
      ),
      tags: [
        'wondrous',
        'cape',
        'dimension door',
        'teleport',
        'escape',
        'stealth'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cape', 'dimension door', 'teleport', 'escape', 'stealth'] },
    ),

    // Chime of Opening
    EquipmentItem(
      id: EntityId(slug: 'item_chime_of_opening', ruleset: RulesetVersion.v2024), name: 'Chime of Opening',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: instantly open mundane or magical locks within 120 ft (10 charges).',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 10 charges. Action: point at a lock, door, gate, chest, or vehicle within 120 feet. Strikes open the lock (dispelling Arcane Lock or picking normal locks).',
        description:
            'This hollow metal tube contains 10 charges. Striking it points a tone at a lock, latch, or barrier, unlocking or unbarring it instantly. Non-rechargeable; cracks when empty.',
        activation: '1 Action',
        charges: '10 charges (non-rechargeable)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: instantly open mundane or magical locks within 120 ft (10 charges).',
        description:
            'Acoustic lock-breaking chime opening reinforced barriers and overcoming Arcane Lock.',
        activation: '1 Action',
        charges: '10 charges (non-rechargeable)',
      ),
      tags: ['wondrous', 'chime', 'knock', 'lock', 'dungeon', 'utility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'chime', 'knock', 'lock', 'dungeon', 'utility'] },
    ),

    // Circlet of Blasting
    EquipmentItem(
      id: EntityId(slug: 'item_circlet_of_blasting', ruleset: RulesetVersion.v2024), name: 'Circlet of Blasting',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: cast Scorching Ray (+5 attack bonus or your spell attack bonus) once per Long Rest.',
      rules2014: ItemEditionDetails(
        summary:
            'Action (1/day): cast the Scorching Ray spell (+5 attack bonus, 120 ft range). Recharges daily at dawn.',
        description:
            'While wearing this circlet, you can use an action to cast the Scorching Ray spell with a +5 bonus to the attack roll.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: cast Scorching Ray (+5 attack bonus or your spell attack bonus) once per Long Rest.',
        description:
            'Golden circlet shooting fiery rays at targets up to 120 feet away.',
        activation: '1 Action (1/Long Rest)',
      ),
      tags: ['wondrous', 'circlet', 'scorching ray', 'fire', 'damage'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'circlet', 'scorching ray', 'fire', 'damage'] },
    ),

    // Cloak of Displacement
    EquipmentItem(
      id: EntityId(slug: 'item_cloak_of_displacement', ruleset: RulesetVersion.v2024), name: 'Cloak of Displacement',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Imposes Disadvantage on all incoming attack rolls. Suppressed until next turn when you take damage.',
      rules2014: ItemEditionDetails(
        summary:
            'Attack rolls against you have disadvantage. If you take damage, this property ceases to function until the start of your next turn (also inactive if incapacitated or unable to move).',
        description:
            'While you wear this cloak, it projects an illusion that makes you appear to be standing in a place near your actual location, causing any creature to have disadvantage on attack rolls against you. If you take damage, the property is suppressed until the start of your next turn.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Imposes Disadvantage on all incoming attack rolls. Suppressed until next turn when you take damage.',
        description:
            'Projects an illusory optical shift, conferring constant defensive evasion.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'cloak', 'displacement', 'defense', 'illusion'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cloak', 'displacement', 'defense', 'illusion'] },
    ),

    // Cloak of the Manta Ray
    EquipmentItem(
      id: EntityId(slug: 'item_cloak_of_the_manta_ray', ruleset: RulesetVersion.v2024), name: 'Cloak of the Manta Ray',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Underwater breathing and 60 ft Swim Speed while hood is active.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this cloak with the hood up, you can breathe underwater and gain a swimming speed of 60 feet. Pulling the hood up or down requires an action.',
        description:
            'While wearing this cloak with its hood up, you can breathe underwater, and you have a swimming speed of 60 feet.',
        activation: '1 Action (Toggle Hood)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Underwater breathing and 60 ft Swim Speed while hood is active.',
        description:
            'Aquatic cloak enabling rapid swimming and amphibious survival.',
        activation: '1 Action / Bonus Action',
      ),
      tags: [
        'wondrous',
        'cloak',
        'manta ray',
        'aquatic',
        'swimming',
        'water breathing'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cloak', 'manta ray', 'aquatic', 'swimming', 'water breathing'] },
    ),

    // Cube of Force
    EquipmentItem(
      id: EntityId(slug: 'item_cube_of_force', ruleset: RulesetVersion.v2024), name: 'Cube of Force',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: '36 charges: customizable 15-ft impenetrable barrier blocking matter, spells, and environmental hazards.',
      rules2014: ItemEditionDetails(
        summary:
            'Has 36 charges (regains 1d20 daily at dawn). Press one of 6 faces as an action to create a 15-foot cubic barrier blocking gas, nonliving matter, living matter, spells, or all things.',
        description:
            'This cube has 36 charges. Pressing faces creates custom protective force barriers around you that move with you.',
        activation: '1 Action',
        charges: '36 charges (recharges 1d20 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '36 charges: customizable 15-ft impenetrable barrier blocking matter, spells, and environmental hazards.',
        description:
            'Tactical force field generator adapting to block various types of incoming harm.',
        activation: '1 Action',
        charges: '36 charges (recharges 1d20 on Long Rest)',
      ),
      tags: ['wondrous', 'cube', 'force', 'barrier', 'defense', 'shield'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cube', 'force', 'barrier', 'defense', 'shield'] },
    ),

    // Eversmoking Bottle
    EquipmentItem(
      id: EntityId(slug: 'item_eversmoking_bottle', ruleset: RulesetVersion.v2024), name: 'Eversmoking Bottle',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: uncork for massive 60–120 ft radius obscuring smoke field.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: uncork to emit thick smoke in a 60-foot radius, expanding 10 feet per minute up to 120 feet. Heavily obscures vision. Action to recork.',
        description:
            'Smoke constantly trickles from the lead stopper of this brass bottle. Uncorking releases a massive cloud of thick smoke.',
        activation: '1 Action (Uncork / Recork)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: uncork for massive 60–120 ft radius obscuring smoke field.',
        description:
            'Creates vast tactical smoke concealment blocking line of sight.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'bottle', 'smoke', 'obscurement', 'tactical'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bottle', 'smoke', 'obscurement', 'tactical'] },
    ),

    // Eyes of the Eagle
    EquipmentItem(
      id: EntityId(slug: 'item_eyes_of_the_eagle', ruleset: RulesetVersion.v2024), name: 'Eyes of the Eagle',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Advantage on sight-based Perception; eagle telescopic sight up to 1 mile.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing these crystal lenses, you have advantage on Wisdom (Perception) checks that rely on sight. Can discern fine details up to 1 mile away.',
        description:
            'These crystal lenses fit over the eyes and magnify distant objects.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Advantage on sight-based Perception; eagle telescopic sight up to 1 mile.',
        description:
            'Precision scout optics granting telescopic sight and Advantage on visual search.',
        activation: 'Passive',
      ),
      tags: ['wondrous', 'eyes', 'eagle', 'perception', 'scouting', 'vision'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'eyes', 'eagle', 'perception', 'scouting', 'vision'] },
    ),

    // Folding Boat
    EquipmentItem(
      id: EntityId(slug: 'item_folding_boat', ruleset: RulesetVersion.v2024), name: 'Folding Boat',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: expands into 10-ft rowboat or 24-ft sailing vessel; folds into portable box.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: speak command word 1 to unfold into a 10-foot rowboat (4 passengers), command word 2 for a 24-foot sailing ship with cabin (15 passengers), or command word 3 to fold back into a 12-inch wooden box.',
        description:
            'This wooden box is 12 inches long, 6 inches wide, and 6 inches deep. Commands unfold it into ocean-ready vessels.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: expands into 10-ft rowboat or 24-ft sailing vessel; folds into portable box.',
        description:
            'Modular nautical vessel box providing instant maritime transportation.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'boat', 'vehicle', 'ship', 'transport', 'nautical'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'boat', 'vehicle', 'ship', 'transport', 'nautical'] },
    ),

    // Gem of Brightness
    EquipmentItem(
      id: EntityId(slug: 'item_gem_of_brightness', ruleset: RulesetVersion.v2024), name: 'Gem of Brightness',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: '50 charges: at-will illumination, single-target blindness ray, and 60-ft cone blinding flash.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 50 charges. Shed light (0 charges), shoot beam blinding 1 creature on DC 15 Con save (1 charge), or unleash 60-foot cone blinding all creatures for 1 minute (5 charges). Non-rechargeable.',
        description:
            'This prism has 50 charges and emits dazzling bursts of solar brilliance.',
        activation: '1 Action',
        charges: '50 charges (non-rechargeable)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '50 charges: at-will illumination, single-target blindness ray, and 60-ft cone blinding flash.',
        description:
            'Crystal prism generating intense radiant bursts to blind foes.',
        activation: '1 Action',
        charges: '50 charges (non-rechargeable)',
        savingThrowDc: 'Fixed DC 15',
      ),
      tags: ['wondrous', 'gem', 'brightness', 'blindness', 'light', 'radiant'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gem', 'brightness', 'blindness', 'light', 'radiant'] },
    ),

    // Gem of Seeing
    EquipmentItem(
      id: EntityId(slug: 'item_gem_of_seeing', ruleset: RulesetVersion.v2024), name: 'Gem of Seeing',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: '3 charges: peer through lens for 10 minutes of 120 ft Truesight.',
      rules2014: ItemEditionDetails(
        summary:
            'Has 3 charges (regains 1d3 daily at dawn). Action: peer through the gem for 10 minutes to gain Truesight out to 120 feet.',
        description:
            'This gem has 3 charges. Peering through it grants Truesight to see through magical darkness, invisible creatures, illusions, visual shapechangers, and into the Ethereal Plane.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '3 charges: peer through lens for 10 minutes of 120 ft Truesight.',
        description:
            'Divination prism revealing all invisible, ethereal, and shapeshifted entities.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      tags: [
        'wondrous',
        'gem',
        'truesight',
        'invisible',
        'illusions',
        'divination'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gem', 'truesight', 'invisible', 'illusions', 'divination'] },
    ),

    // Gloves of Missile Snaring
    EquipmentItem(
      id: EntityId(slug: 'item_gloves_of_missile_snaring', ruleset: RulesetVersion.v2024), name: 'Gloves of Missile Snaring',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Reaction: deflect ranged weapon attacks, reducing damage by 1d10 + Dex and catching missile if damage reaches 0.',
      rules2014: ItemEditionDetails(
        summary:
            'When a ranged weapon attack hits you, use your reaction to reduce the damage by 1d10 + Dexterity modifier. If damage is reduced to 0, you catch the missile if you have a free hand.',
        description:
            'These gloves seem to move on their own to snatch projectiles out of the air.',
        activation: '1 Reaction',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Reaction: deflect ranged weapon attacks, reducing damage by 1d10 + Dex and catching missile if damage reaches 0.',
        description:
            'Enchanted defensive gloves snatching arrows and thrown weapons out of flight.',
        activation: '1 Reaction',
      ),
      tags: [
        'wondrous',
        'gloves',
        'missile snaring',
        'deflect',
        'reaction',
        'defense'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gloves', 'missile snaring', 'deflect', 'reaction', 'defense'] },
    ),

    // Gloves of Thievery
    EquipmentItem(
      id: EntityId(slug: 'item_gloves_of_thievery', ruleset: RulesetVersion.v2024), name: 'Gloves of Thievery',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: '+5 bonus on Sleight of Hand and Thieves\' Tools checks; invisible while equipped.',
      rules2014: ItemEditionDetails(
        summary:
            'These gloves are invisible while worn. While wearing them, you gain a +5 bonus to Dexterity (Sleight of Hand) checks and Dexterity checks made to pick locks with thieves\' tools.',
        description:
            'Supple, translucent rogue\'s gloves boosting precision manual dexterity.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+5 bonus on Sleight of Hand and Thieves\' Tools checks; invisible while equipped.',
        description:
            'Masterwork lockpicking and pickpocketing gloves adding a flat +5 bonus.',
        activation: 'Passive',
      ),
      tags: [
        'wondrous',
        'gloves',
        'thievery',
        'sleight of hand',
        'lockpicking',
        'rogue'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gloves', 'thievery', 'sleight of hand', 'lockpicking', 'rogue'] },
    ),

    // Helm of Teleportation
    EquipmentItem(
      id: EntityId(slug: 'item_helm_of_teleportation', ruleset: RulesetVersion.v2024), name: 'Helm of Teleportation',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: '3 charges: cast Teleport (7th level) anywhere across the current plane.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 3 charges (regains 1d3 daily at dawn). While wearing it, use an action to expend 1 charge to cast the Teleport spell.',
        description:
            'This helm has 3 charges. While wearing it, you can use an action to expend 1 charge to cast Teleport.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '3 charges: cast Teleport (7th level) anywhere across the current plane.',
        description: 'Legendary long-distance traversal helm.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      tags: ['wondrous', 'helm', 'teleport', 'travel', 'mobility'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'helm', 'teleport', 'travel', 'mobility'] },
    ),

    // Lantern of Revealing
    EquipmentItem(
      id: EntityId(slug: 'item_lantern_of_revealing', ruleset: RulesetVersion.v2024), name: 'Lantern of Revealing',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Reveals all invisible creatures and objects within 30 ft bright light radius.',
      rules2014: ItemEditionDetails(
        summary:
            'While lit, sheds bright light in a 30-foot radius and dim light for an additional 30 feet. Invisible creatures and objects are visible as long as they are in the lantern\'s bright light.',
        description:
            'While lit, this hooded lantern reveals invisible creatures and hidden ethereal objects in its bright light beam.',
        activation: '1 Action (Light / Hood)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Reveals all invisible creatures and objects within 30 ft bright light radius.',
        description:
            'Essential dungeon exploration lantern unmasking invisible stalkers and hidden objects.',
        activation: '1 Action',
      ),
      tags: [
        'wondrous',
        'lantern',
        'revealing',
        'invisibility',
        'light',
        'scouting'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'lantern', 'revealing', 'invisibility', 'light', 'scouting'] },
    ),

    // Rope of Climbing
    EquipmentItem(
      id: EntityId(slug: 'item_rope_of_climbing', ruleset: RulesetVersion.v2024), name: 'Rope of Climbing',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: snake up to 50 ft to tie off to anchors. Creates knot handholds for effortless climbing.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: command this 60-foot rope to snake forward up to 50 feet and securely knot/fasten itself to an anchor point. Bonus action: create knot handholds (advantage on Athletics to climb). Supports up to 3,000 lbs.',
        description:
            'This 60-foot silk rope moves under telepathic/verbal command to scale cliffs and secure rappels.',
        activation: '1 Action / 1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: snake up to 50 ft to tie off to anchors. Creates knot handholds for effortless climbing.',
        description:
            'Enchanted climbing rope securing ascents and descents across sheer surfaces.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'rope', 'climbing', 'athletics', 'utility', 'dungeon'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'rope', 'climbing', 'athletics', 'utility', 'dungeon'] },
    ),

    // Rope of Entanglement
    EquipmentItem(
      id: EntityId(slug: 'item_rope_of_entanglement', ruleset: RulesetVersion.v2024), name: 'Rope of Entanglement',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: bind target in 20 ft with Restrained condition on failed DC 15 Dex save.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: command rope to lash out at a creature within 20 feet. Target must pass DC 15 Dex save or become restrained. DC 15 Strength or DC 20 Dexterity check to break free.',
        description:
            'This 30-foot rope springs forward to wrap around and bind a target with supernatural strength.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: bind target in 20 ft with Restrained condition on failed DC 15 Dex save.',
        description:
            'Tactical crowd-control rope restraining foes without requiring spell slots.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      tags: ['wondrous', 'rope', 'entanglement', 'restrained', 'crowd control'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'rope', 'entanglement', 'restrained', 'crowd control'] },
    ),

    // Wings of Flying
    EquipmentItem(
      id: EntityId(slug: 'item_wings_of_flying', ruleset: RulesetVersion.v2024), name: 'Wings of Flying',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Action: deploy wings granting 60 ft Flying Speed for 1 hour (recharges in 1d12 hours).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: speak command word to transform cloak into bat or bird wings, gaining a flying speed of 60 feet for 1 hour. Can\'t be used again for 1d12 hours.',
        description:
            'While wearing this cloak, you can use an action to speak its command word. This turns the cloak into a pair of bat wings or bird wings on your back for 1 hour or until you repeat the command word as an action. While the wings are present, you have a flying speed of 60 feet.',
        activation: '1 Action (1 Hour Duration)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: deploy wings granting 60 ft Flying Speed for 1 hour (recharges in 1d12 hours).',
        description:
            'Transforms cloak into wings enabling rapid 60-foot flight speed.',
        activation: '1 Action',
      ),
      tags: ['wondrous', 'wings', 'flying', 'flight', 'mobility', 'aerial'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'wings', 'flying', 'flight', 'mobility', 'aerial'] },
    ),

    // ==========================================
    // TOMES, MANUALS & ABILITY BOOKS
    // ==========================================

    // Manual of Bodily Health
    EquipmentItem(
      id: EntityId(slug: 'item_manual_of_bodily_health', ruleset: RulesetVersion.v2024), name: 'Manual of Bodily Health',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Study for 48 hours to gain permanent +2 to Constitution and Constitution maximum.',
      rules2014: ItemEditionDetails(
        summary:
            'Spend 48 hours over 6 days studying this book to permanently increase your Constitution score by 2 and your maximum for that score by 2. The manual loses its magic for 100 years.',
        description:
            'This heavy leather-bound tome contains health, diet, and physical endurance regimens. Once read, its words vanish and its magic is spent for a century.',
        activation: '48 Hours Study (6 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Study for 48 hours to gain permanent +2 to Constitution and Constitution maximum.',
        description:
            'Permanent physical enhancement tome increasing Constitution and raising ability score cap.',
        activation: '48 Hours Study (6 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'manual',
        'tome',
        'constitution',
        'ability score',
        'health',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'manual', 'tome', 'constitution', 'ability score', 'health', 'consumable'] },
    ),

    // Manual of Gainful Exercise
    EquipmentItem(
      id: EntityId(slug: 'item_manual_of_gainful_exercise', ruleset: RulesetVersion.v2024), name: 'Manual of Gainful Exercise',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Study for 48 hours to gain permanent +2 to Strength and Strength maximum.',
      rules2014: ItemEditionDetails(
        summary:
            'Spend 48 hours over 6 days studying this book to permanently increase your Strength score by 2 and your maximum for that score by 2. The manual loses its magic for 100 years.',
        description:
            'This book describes rigorous muscle training and athletic exercises. Once read, its pages turn blank and its magic is expended for a century.',
        activation: '48 Hours Study (6 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Study for 48 hours to gain permanent +2 to Strength and Strength maximum.',
        description:
            'Permanent martial training manual increasing Strength and raising ability score cap.',
        activation: '48 Hours Study (6 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'manual',
        'tome',
        'strength',
        'ability score',
        'muscle',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'manual', 'tome', 'strength', 'ability score', 'muscle', 'consumable'] },
    ),

    // Manual of Quickness of Action
    EquipmentItem(
      id: EntityId(slug: 'item_manual_of_quickness_of_action', ruleset: RulesetVersion.v2024), name: 'Manual of Quickness of Action',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Study for 48 hours to gain permanent +2 to Dexterity and Dexterity maximum.',
      rules2014: ItemEditionDetails(
        summary:
            'Spend 48 hours over 6 days studying this book to permanently increase your Dexterity score by 2 and your maximum for that score by 2. The manual loses its magic for 100 years.',
        description:
            'Contains agility exercises and balance mastery diagrams. Once read, the text fades and the manual becomes nonmagical for 100 years.',
        activation: '48 Hours Study (6 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Study for 48 hours to gain permanent +2 to Dexterity and Dexterity maximum.',
        description:
            'Permanent acrobatics and reflex manual increasing Dexterity and raising ability score cap.',
        activation: '48 Hours Study (6 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'manual',
        'tome',
        'dexterity',
        'ability score',
        'agility',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'manual', 'tome', 'dexterity', 'ability score', 'agility', 'consumable'] },
    ),

    // Manual of Golems (Clay)
    EquipmentItem(
      id: EntityId(slug: 'item_manual_of_golems_clay', ruleset: RulesetVersion.v2024), name: 'Manual of Golems (Clay)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Crafting manual for constructing an animated Clay Golem.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains formulas to animate a Clay Golem. Requires 30 days of continuous work and 65,000 gp in materials. The manual burns to ash upon completion.',
        description:
            'A comprehensive arcane treatise containing the precise alchemical and mystical incantations needed to animate a loyal Clay Golem.',
        activation: '30 Days Downtime Crafting',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Crafting manual for constructing an animated Clay Golem.',
        description:
            'Downtime construction guide enabling high-level spellcasters to build an obedient Clay Golem.',
        activation: '30 Days Downtime Crafting',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'manual',
        'golem',
        'clay',
        'crafting',
        'minion',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'manual', 'golem', 'clay', 'crafting', 'minion', 'consumable'] },
    ),

    // Manual of Golems (Flesh)
    EquipmentItem(
      id: EntityId(slug: 'item_manual_of_golems_flesh', ruleset: RulesetVersion.v2024), name: 'Manual of Golems (Flesh)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Crafting manual for assembling and animating a Flesh Golem.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains instructions to assemble and animate a Flesh Golem. Requires 60 days of continuous work and 50,000 gp in materials. The manual burns to ash upon completion.',
        description:
            'Treatise bound in stitched hide detailing the binding of elemental spirits into crafted flesh.',
        activation: '60 Days Downtime Crafting',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Crafting manual for assembling and animating a Flesh Golem.',
        description:
            'Downtime construction guide enabling spellcasters to create an obedient Flesh Golem.',
        activation: '60 Days Downtime Crafting',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'manual',
        'golem',
        'flesh',
        'crafting',
        'minion',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'manual', 'golem', 'flesh', 'crafting', 'minion', 'consumable'] },
    ),

    // Manual of Golems (Iron)
    EquipmentItem(
      id: EntityId(slug: 'item_manual_of_golems_iron', ruleset: RulesetVersion.v2024), name: 'Manual of Golems (Iron)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Crafting manual for forging and animating an Iron Golem.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains instructions to forge and animate an Iron Golem. Requires 120 days of continuous work and 100,000 gp in materials. The manual burns to ash upon completion.',
        description:
            'Heavy metal-bound folio detailing the masterwork metallurgy and binding rites of an Iron Golem.',
        activation: '120 Days Downtime Crafting',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Crafting manual for forging and animating an Iron Golem.',
        description:
            'Downtime construction guide for forging a towering, impervious Iron Golem.',
        activation: '120 Days Downtime Crafting',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'manual',
        'golem',
        'iron',
        'crafting',
        'minion',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'manual', 'golem', 'iron', 'crafting', 'minion', 'consumable'] },
    ),

    // Manual of Golems (Stone)
    EquipmentItem(
      id: EntityId(slug: 'item_manual_of_golems_stone', ruleset: RulesetVersion.v2024), name: 'Manual of Golems (Stone)',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Crafting manual for sculpting and animating a Stone Golem.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains instructions to sculpt and animate a Stone Golem. Requires 90 days of continuous work and 80,000 gp in materials. The manual burns to ash upon completion.',
        description:
            'Chiseled stone tablets bound together detailing the animation of a monolithic Stone Golem.',
        activation: '90 Days Downtime Crafting',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Crafting manual for sculpting and animating a Stone Golem.',
        description:
            'Downtime construction guide for shaping and animating a Stone Golem.',
        activation: '90 Days Downtime Crafting',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'manual',
        'golem',
        'stone',
        'crafting',
        'minion',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'manual', 'golem', 'stone', 'crafting', 'minion', 'consumable'] },
    ),

    // Tome of Clear Thought
    EquipmentItem(
      id: EntityId(slug: 'item_tome_of_clear_thought', ruleset: RulesetVersion.v2024), name: 'Tome of Clear Thought',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Study for 48 hours to gain permanent +2 to Intelligence and Intelligence maximum.',
      rules2014: ItemEditionDetails(
        summary:
            'Spend 48 hours over 6 days studying this book to permanently increase your Intelligence score by 2 and your maximum for that score by 2. The tome loses its magic for 100 years.',
        description:
            'This arcane folio contains logic proofs, mnemonics, and cognitive exercises. Once read, its pages turn blank for a century.',
        activation: '48 Hours Study (6 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Study for 48 hours to gain permanent +2 to Intelligence and Intelligence maximum.',
        description:
            'Permanent cognitive enhancement tome increasing Intelligence and raising ability score cap.',
        activation: '48 Hours Study (6 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'tome',
        'intelligence',
        'ability score',
        'cognition',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'tome', 'intelligence', 'ability score', 'cognition', 'consumable'] },
    ),

    // Tome of Leadership and Influence
    EquipmentItem(
      id: EntityId(slug: 'item_tome_of_leadership_and_influence', ruleset: RulesetVersion.v2024), name: 'Tome of Leadership and Influence',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Study for 48 hours to gain permanent +2 to Charisma and Charisma maximum.',
      rules2014: ItemEditionDetails(
        summary:
            'Spend 48 hours over 6 days studying this book to permanently increase your Charisma score by 2 and your maximum for that score by 2. The tome loses its magic for 100 years.',
        description:
            'Contains principles of leadership, rhetoric, and magnetism. Once read, its words vanish for 100 years.',
        activation: '48 Hours Study (6 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Study for 48 hours to gain permanent +2 to Charisma and Charisma maximum.',
        description:
            'Permanent personality and rhetoric enhancement tome increasing Charisma and raising ability score cap.',
        activation: '48 Hours Study (6 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'tome',
        'charisma',
        'ability score',
        'leadership',
        'influence',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'tome', 'charisma', 'ability score', 'leadership', 'influence', 'consumable'] },
    ),

    // Tome of Understanding
    EquipmentItem(
      id: EntityId(slug: 'item_tome_of_understanding', ruleset: RulesetVersion.v2024), name: 'Tome of Understanding',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Study for 48 hours to gain permanent +2 to Wisdom and Wisdom maximum.',
      rules2014: ItemEditionDetails(
        summary:
            'Spend 48 hours over 6 days studying this book to permanently increase your Wisdom score by 2 and your maximum for that score by 2. The tome loses its magic for 100 years.',
        description:
            'Contains philosophical and spiritual insights on intuition and awareness. Once read, its pages turn blank for 100 years.',
        activation: '48 Hours Study (6 Days)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Study for 48 hours to gain permanent +2 to Wisdom and Wisdom maximum.',
        description:
            'Permanent spiritual and intuitive enhancement tome increasing Wisdom and raising ability score cap.',
        activation: '48 Hours Study (6 Days)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'tome',
        'wisdom',
        'ability score',
        'insight',
        'awareness',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'tome', 'wisdom', 'ability score', 'insight', 'awareness', 'consumable'] },
    ),

    // ==========================================
    // ROBES, CLOAKS & MANTLES
    // ==========================================

    // Cloak of Arachnida
    EquipmentItem(
      id: EntityId(slug: 'item_cloak_of_arachnida', ruleset: RulesetVersion.v2024), name: 'Cloak of Arachnida',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Climb speed, Spider Climb trait, Poison resistance, Web immunity, and 1/Day expanded Web spell.',
      rules2014: ItemEditionDetails(
        summary:
            'Grants climbing speed equal to walking speed, Spider Climb (can move upside down on ceilings), poison damage resistance, immunity to webs, and cast Web (DC 13, twice standard area) once per day.',
        description:
            'A black silk cloak with subtle web embroidery. Gives the wearer complete freedom of movement within webs and spider mobility.',
        activation: 'Passive & 1 Action (1/Day Web)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Climb speed, Spider Climb trait, Poison resistance, Web immunity, and 1/Day expanded Web spell.',
        description:
            'Arachnid garment granting wall-crawling, poison warding, and massive web creation.',
        activation: 'Passive & 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'cloak',
        'arachnida',
        'spider climb',
        'web',
        'poison resistance'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cloak', 'arachnida', 'spider climb', 'web', 'poison resistance'] },
    ),

    // Mantle of Spell Resistance
    EquipmentItem(
      id: EntityId(slug: 'item_mantle_of_spell_resistance', ruleset: RulesetVersion.v2024), name: 'Mantle of Spell Resistance',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Passive: Advantage on saving throws against all spells and spell effects.',
      rules2014: ItemEditionDetails(
        summary: 'You have advantage on saving throws against spells.',
        description:
            'A shimmering woven mantle that deflects offensive magical energies.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: Advantage on saving throws against all spells and spell effects.',
        description: 'Abjuration cloak providing continuous spell warding.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'mantle',
        'cloak',
        'spell resistance',
        'saving throws',
        'abjuration'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'mantle', 'cloak', 'spell resistance', 'saving throws', 'abjuration'] },
    ),

    // Robe of Eyes
    EquipmentItem(
      id: EntityId(slug: 'item_robe_of_eyes', ruleset: RulesetVersion.v2024), name: 'Robe of Eyes',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: '360° vision, 120 ft darkvision, ethereal vision, sight advantage; vulnerable to sudden bright light flashes.',
      rules2014: ItemEditionDetails(
        summary:
            'Robe covered in eye motifs. Grants 360-degree vision, advantage on Perception checks relying on sight, 120 ft darkvision, and ability to see invisible/ethereal creatures within 120 ft. Vulnerable to Light/Daylight blinding.',
        description:
            'This robe is adorned with stylized eye patterns that blink and track movement in all directions.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '360° vision, 120 ft darkvision, ethereal vision, sight advantage; vulnerable to sudden bright light flashes.',
        description: 'Divination robe granting panoramic all-seeing vision.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'robe',
        'eyes',
        'truesight',
        'darkvision',
        'ethereal',
        'perception'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'robe', 'eyes', 'truesight', 'darkvision', 'ethereal', 'perception'] },
    ),

    // Robe of Scintillating Colors
    EquipmentItem(
      id: EntityId(slug: 'item_robe_of_scintillating_colors', ruleset: RulesetVersion.v2024), name: 'Robe of Scintillating Colors',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '3 charges: dazzling kaleidoscopic light imposing disadvantage on incoming attacks and stunning nearby foes (DC 15 Wis).',
      rules2014: ItemEditionDetails(
        summary:
            'Has 3 charges (regains 1d3 daily at dawn). Action: shed hypnotic shifting colors for 30 ft. Attack rolls against you have disadvantage, and creatures in 30 ft must succeed on a DC 15 Wis save or become stunned until the start of their next turn.',
        description:
            'A robe woven from kaleidoscopic silk that dazzles and stuns onlookers with shifting prismatic waves.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '3 charges: dazzling kaleidoscopic light imposing disadvantage on incoming attacks and stunning nearby foes (DC 15 Wis).',
        description:
            'Illusion and enchantment robe distorting enemy perception.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'robe',
        'scintillating',
        'stun',
        'disadvantage',
        'prismatic',
        'illusion'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'robe', 'scintillating', 'stun', 'disadvantage', 'prismatic', 'illusion'] },
    ),

    // Robe of Stars
    EquipmentItem(
      id: EntityId(slug: 'item_robe_of_stars', ruleset: RulesetVersion.v2024), name: 'Robe of Stars',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 to all saving throws, at-will Astral Plane transition, and 6 stars to cast 5th-level Magic Missile.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 bonus to all saving throws. As an action, enter the Astral Plane along with everything you are wearing and return as an action. Has 6 silver stars; as an action, pluck a star to cast 5th-level Magic Missile (regains 1d6 stars daily at dusk).',
        description:
            'A midnight blue robe stitched with six glowing silver stars and constellations.',
        activation: 'Passive & 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 to all saving throws, at-will Astral Plane transition, and 6 stars to cast 5th-level Magic Missile.',
        description:
            'Planar traveling robe with offensive celestial darts and abjuration protection.',
        activation: 'Passive & 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'robe',
        'stars',
        'astral plane',
        'magic missile',
        'saving throws'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'robe', 'stars', 'astral plane', 'magic missile', 'saving throws'] },
    ),

    // ==========================================
    // HELMS, HEADWEAR & EYE WEAR
    // ==========================================

    // Cap of Water Breathing
    EquipmentItem(
      id: EntityId(slug: 'item_cap_of_water_breathing', ruleset: RulesetVersion.v2024), name: 'Cap of Water Breathing',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: create renewable air bubble around head allowing underwater breathing.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this cap underwater, you can speak its command word as an action to create a bubble of air around your head. It allows you to breathe normally underwater until you speak the command word again.',
        description:
            'A cap made of woven kelp that encloses the wearer\'s head in a breathable pocket of air.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: create renewable air bubble around head allowing underwater breathing.',
        description:
            'Aquatic utility cap providing infinite underwater respiration.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'cap', 'water breathing', 'underwater', 'swimming'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cap', 'water breathing', 'underwater', 'swimming'] },
    ),

    // Eyes of Charming
    EquipmentItem(
      id: EntityId(slug: 'item_eyes_of_charming', ruleset: RulesetVersion.v2024), name: 'Eyes of Charming',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: '3 charges: cast Charm Person (DC 13 Wis save) on a target looking at you.',
      rules2014: ItemEditionDetails(
        summary:
            'Has 3 charges (regains all at dawn). Action: cast Charm Person (save DC 13) on a humanoid within 30 feet that can see you.',
        description:
            'Crystal lenses that fit over the eyes, imparting an alluring luminescence to your gaze.',
        activation: '1 Action',
        charges: '3 charges (recharges at dawn)',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '3 charges: cast Charm Person (DC 13 Wis save) on a target looking at you.',
        description:
            'Enchantment lenses subverting target hostility with charismatic gaze.',
        activation: '1 Action',
        charges: '3 charges (recharges on Long Rest)',
        savingThrowDc: 'Fixed DC 13',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'eyes', 'charming', 'charm person', 'enchantment'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'eyes', 'charming', 'charm person', 'enchantment'] },
    ),

    // Eyes of Minute Seeing
    EquipmentItem(
      id: EntityId(slug: 'item_eyes_of_minute_seeing', ruleset: RulesetVersion.v2024), name: 'Eyes of Minute Seeing',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Passive: Advantage on Intelligence (Investigation) checks for inspecting objects within 1 foot.',
      rules2014: ItemEditionDetails(
        summary:
            'These crystal lenses allow you to see much better at close range. You have advantage on Intelligence (Investigation) checks that rely on sight while searching an area or examining something within 1 foot of you.',
        description:
            'Magnifying crystal spectacles revealing microscopic fractures, hidden runes, and intricate lock mechanisms.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: Advantage on Intelligence (Investigation) checks for inspecting objects within 1 foot.',
        description:
            'Microscopic inspection lenses for trap disarming and forensic analysis.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'eyes',
        'minute seeing',
        'investigation',
        'traps',
        'inspection'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'eyes', 'minute seeing', 'investigation', 'traps', 'inspection'] },
    ),

    // Helm of Brilliance
    EquipmentItem(
      id: EntityId(slug: 'item_helm_of_brilliance', ruleset: RulesetVersion.v2024), name: 'Helm of Brilliance',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Gem matrix casting Daylight, Fireball (DC 18), Wall of Fire (DC 18), and Prismatic Spray (DC 18) with passive fire resistance.',
      rules2014: ItemEditionDetails(
        summary:
            'Set with diamonds, rubies, fire opals, and opals. Grants fire resistance, 30 ft radiant illumination dealing 1d6 radiant to undead at start of turn, weapon fire damage (+1d6), and action to cast Daylight (opal), Fireball (ruby, DC 18), Prismatic Spray (diamond, DC 18), or Wall of Fire (fire opal, DC 18). Detonates if wearer fails saving throw against fire.',
        description:
            'A dazzling crown of polished silver studded with brilliant gemstones that channel solar and elemental fire.',
        activation: 'Passive & 1 Action',
        savingThrowDc: 'Fixed DC 18',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Gem matrix casting Daylight, Fireball (DC 18), Wall of Fire (DC 18), and Prismatic Spray (DC 18) with passive fire resistance.',
        description:
            'High-power combat helm radiating blinding light and explosive elemental spells.',
        activation: 'Passive & 1 Action',
        savingThrowDc: 'Fixed DC 18',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'helm',
        'brilliance',
        'fire resistance',
        'fireball',
        'prismatic spray',
        'radiant'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'helm', 'brilliance', 'fire resistance', 'fireball', 'prismatic spray', 'radiant'] },
    ),

    // Helm of Comprehending Languages
    EquipmentItem(
      id: EntityId(slug: 'item_helm_of_comprehending_languages', ruleset: RulesetVersion.v2024), name: 'Helm of Comprehending Languages',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: at-will Comprehend Languages casting.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this helm, you can use an action to cast the Comprehend Languages spell from it at will.',
        description:
            'An open-faced steel helm inscribed with ancient translation runes.',
        activation: '1 Action (At Will)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: at-will Comprehend Languages casting.',
        description:
            'Translation headpiece deciphering any spoken language or written script.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'helm',
        'comprehend languages',
        'translation',
        'linguistics'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'helm', 'comprehend languages', 'translation', 'linguistics'] },
    ),

    // Helm of Telepathy
    EquipmentItem(
      id: EntityId(slug: 'item_helm_of_telepathy', ruleset: RulesetVersion.v2024), name: 'Helm of Telepathy',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Action: at-will Detect Thoughts (DC 13) and 1/Day Suggestion (DC 13).',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this helm, you can use an action to cast Detect Thoughts (save DC 13) at will. While maintaining concentration on the spell, you can use an action to send a telepathic message or cast Suggestion (save DC 13) on the target once per day.',
        description:
            'A polished metallic helm that amplifies the wearer\'s psionic and telepathic faculties.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: at-will Detect Thoughts (DC 13) and 1/Day Suggestion (DC 13).',
        description:
            'Mental espionage headpiece reading thoughts and projecting telepathic commands.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'helm',
        'telepathy',
        'detect thoughts',
        'suggestion',
        'psionics'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'helm', 'telepathy', 'detect thoughts', 'suggestion', 'psionics'] },
    ),

    // Medallion of Thoughts
    EquipmentItem(
      id: EntityId(slug: 'item_medallion_of_thoughts', ruleset: RulesetVersion.v2024), name: 'Medallion of Thoughts',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: '3 charges: cast Detect Thoughts (DC 13) from pendant.',
      rules2014: ItemEditionDetails(
        summary:
            'Has 3 charges (regains 1d3 daily at dawn). While wearing it, you can use an action and expend 1 charge to cast the Detect Thoughts spell (save DC 13) from it.',
        description:
            'A silver disc inscribed with labyrinthine mind sigils on a delicate chain.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: cast Detect Thoughts (DC 13) from pendant.',
        description:
            'Telepathic amulet for scanning nearby minds and surface thoughts.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
        savingThrowDc: 'Fixed DC 13',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'medallion',
        'thoughts',
        'detect thoughts',
        'divination'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'medallion', 'thoughts', 'detect thoughts', 'divination'] },
    ),

    // ==========================================
    // AMULETS, NECKLACES, PERIAPTS & TALISMANS
    // ==========================================

    // Amulet of Proof against Detection and Location
    EquipmentItem(
      id: EntityId(slug: 'item_amulet_of_proof_against_detection_and_location', ruleset: RulesetVersion.v2024), name: 'Amulet of Proof against Detection and Location',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Passive: Total immunity to divination targeting and magical scrying sensors.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing this amulet, you are hidden from divination magic. You can\'t be targeted by such magic or perceived through magical scrying sensors.',
        description:
            'A leaden amulet shielding the wearer completely from clairvoyance, scrying sensors, and locator spells.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: Total immunity to divination targeting and magical scrying sensors.',
        description:
            'Anti-surveillance pendant protecting the wearer from all forms of magical observation.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'amulet',
        'nondetection',
        'scrying',
        'divination',
        'stealth'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'amulet', 'nondetection', 'scrying', 'divination', 'stealth'] },
    ),

    // Amulet of the Planes
    EquipmentItem(
      id: EntityId(slug: 'item_amulet_of_the_planes', ruleset: RulesetVersion.v2024), name: 'Amulet of the Planes',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Action: cast Plane Shift with DC 15 Int check; failure triggers wild interplanar teleportation.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: name a plane of existence and make a DC 15 Intelligence check. On success, cast Plane Shift to transport yourself and up to 8 willing creatures. On failure, you and creatures within 15 feet teleport to a random destination.',
        description:
            'A heavy platinum talisman containing miniature planar dials and celestial gears.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: cast Plane Shift with DC 15 Int check; failure triggers wild interplanar teleportation.',
        description:
            'Interplanar transit relic opening portals across the multiverse.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'amulet',
        'planes',
        'plane shift',
        'planar',
        'teleportation'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'amulet', 'planes', 'plane shift', 'planar', 'teleportation'] },
    ),

    // Necklace of Prayer Beads
    EquipmentItem(
      id: EntityId(slug: 'item_necklace_of_prayer_beads', ruleset: RulesetVersion.v2024), name: 'Necklace of Prayer Beads',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Bonus Action divine spellcasting from beads (Bless, Cure Wounds, Restorations, Planar Ally).',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 1d4 + 2 magic beads (Blessing, Curing, Favor, Smiting, Summons, Wind Walk). Attuned cleric, druid, or paladin can cast associated spell as a bonus action (usable 1/day per bead).',
        description:
            'A string of sacred semi-precious beads that channel divine magic swiftly as bonus actions.',
        activation: '1 Bonus Action (1/Day per bead)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Bonus Action divine spellcasting from beads (Bless, Cure Wounds, Restorations, Planar Ally).',
        description:
            'Sacred prayer beads providing bonus-action divine spell versatility.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'necklace',
        'prayer beads',
        'divine',
        'bless',
        'cure wounds',
        'healing'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'necklace', 'prayer beads', 'divine', 'bless', 'cure wounds', 'healing'] },
    ),

    // Periapt of Health
    EquipmentItem(
      id: EntityId(slug: 'item_periapt_of_health', ruleset: RulesetVersion.v2024), name: 'Periapt of Health',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Passive: Complete immunity to disease and suppression of active infections.',
      rules2014: ItemEditionDetails(
        summary:
            'You are immune to contracting any disease while you wear this pendant. If you are already infected with disease, its effects are suppressed while wearing the periapt.',
        description:
            'A blue gem set into a silver brooch that purifies the wearer\'s bloodstream of all biological pathogens.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: Complete immunity to disease and suppression of active infections.',
        description:
            'Sanitary medical talisman granting total disease immunity.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'periapt', 'health', 'disease', 'immunity', 'healing'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'periapt', 'health', 'disease', 'immunity', 'healing'] },
    ),

    // Periapt of Proof against Poison
    EquipmentItem(
      id: EntityId(slug: 'item_periapt_of_proof_against_poison', ruleset: RulesetVersion.v2024), name: 'Periapt of Proof against Poison',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Passive: Total immunity to poison damage and the Poisoned condition.',
      rules2014: ItemEditionDetails(
        summary:
            'This delicate pendant makes you immune to poison damage and the poisoned condition. Any active poison is suppressed while worn.',
        description:
            'An emerald encased in platinum that neutralizing venoms, toxins, and environmental poisons.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: Total immunity to poison damage and the Poisoned condition.',
        description:
            'Anti-venom talisman conferring permanent poison immunity.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'periapt',
        'poison',
        'immunity',
        'poisoned',
        'protection'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'periapt', 'poison', 'immunity', 'poisoned', 'protection'] },
    ),

    // Talisman of Pure Good
    EquipmentItem(
      id: EntityId(slug: 'item_talisman_of_pure_good', ruleset: RulesetVersion.v2024), name: 'Talisman of Pure Good',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true,
      descriptionMarkdown: '+2 to spell attacks and save DC; 7 charges to open earth beneath evil foes (DC 20 Dex save or obliterated).',
      rules2014: ItemEditionDetails(
        summary:
            'Requires attunement by good spellcaster. +2 bonus to spell attack rolls and save DC. Has 7 charges. Action: choose an evil creature in 120 ft; target must pass DC 20 Dex save or earth opens to destroy them in a flaming fissure (8d6 radiant + 8d6 fire if saved). Talisman vanishes when last charge is used.',
        description:
            'A radiant golden talisman etched with symbols of celestial purity.',
        activation: 'Passive & 1 Action',
        charges: '7 charges (non-rechargeable)',
        savingThrowDc: 'Fixed DC 20',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+2 to spell attacks and save DC; 7 charges to open earth beneath evil foes (DC 20 Dex save or obliterated).',
        description:
            'Legendary holy relic destroying evil entities with celestial judgment.',
        activation: 'Passive & 1 Action',
        charges: '7 charges',
        savingThrowDc: 'Fixed DC 20',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'talisman',
        'pure good',
        'holy',
        'radiant',
        'legendary',
        'spell attack'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'talisman', 'pure good', 'holy', 'radiant', 'legendary', 'spell attack'] },
    ),

    // Talisman of the Sphere
    EquipmentItem(
      id: EntityId(slug: 'item_talisman_of_the_sphere', ruleset: RulesetVersion.v2024), name: 'Talisman of the Sphere',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Passive: Advantage and doubled proficiency on Arcana checks to manipulate a Sphere of Annihilation.',
      rules2014: ItemEditionDetails(
        summary:
            'While holding this talisman, you double your proficiency bonus on Intelligence (Arcana) checks made to control a Sphere of Annihilation and have advantage on the check.',
        description:
            'A black adamantine loop that stabilizes the gravitational pull of a Sphere of Annihilation.',
        activation: 'Passive (Sphere Control)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: Advantage and doubled proficiency on Arcana checks to manipulate a Sphere of Annihilation.',
        description:
            'Planar control focus ensuring mastery over black holes and spheres of annihilation.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'talisman',
        'sphere of annihilation',
        'arcana',
        'planar'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'talisman', 'sphere of annihilation', 'arcana', 'planar'] },
    ),

    // Talisman of Ultimate Evil
    EquipmentItem(
      id: EntityId(slug: 'item_talisman_of_ultimate_evil', ruleset: RulesetVersion.v2024), name: 'Talisman of Ultimate Evil',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true,
      descriptionMarkdown: '+2 to spell attacks and save DC; 7 charges to open abyssal chasm beneath good foes (DC 20 Dex save or obliterated).',
      rules2014: ItemEditionDetails(
        summary:
            'Requires attunement by evil spellcaster. +2 bonus to spell attack rolls and save DC. Has 7 charges. Action: choose a good creature in 120 ft; target must pass DC 20 Dex save or earth opens to consume them in an abyssal fissure (8d6 necrotic + 8d6 fire if saved). Talisman crumbles when last charge is spent.',
        description:
            'A jagged piece of unholy black obsidian pulsating with malevolent crimson veins.',
        activation: 'Passive & 1 Action',
        charges: '7 charges (non-rechargeable)',
        savingThrowDc: 'Fixed DC 20',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+2 to spell attacks and save DC; 7 charges to open abyssal chasm beneath good foes (DC 20 Dex save or obliterated).',
        description:
            'Legendary unholy relic destroying celestial and righteous foes.',
        activation: 'Passive & 1 Action',
        charges: '7 charges',
        savingThrowDc: 'Fixed DC 20',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'talisman',
        'ultimate evil',
        'necrotic',
        'unholy',
        'legendary'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'talisman', 'ultimate evil', 'necrotic', 'unholy', 'legendary'] },
    ),

    // ==========================================
    // BOOTS, GLOVES, BELTS & MOUNT GEAR
    // ==========================================

    // Belt of Dwarvenkind
    EquipmentItem(
      id: EntityId(slug: 'item_belt_of_dwarvenkind', ruleset: RulesetVersion.v2024), name: 'Belt of Dwarvenkind',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Passive: Constitution +2, Poison resistance/advantage, 60 ft Darkvision, Dwarvish fluency, and dwarf diplomacy advantage.',
      rules2014: ItemEditionDetails(
        summary:
            'Constitution increases by 2 (up to max of 20). Advantage on saving throws against poison and resistance to poison damage. Darkvision 60 ft. Can speak, read, and write Dwarvish. Advantage on Charisma (Persuasion) checks with dwarves. Grow a thick beard daily.',
        description:
            'A heavy leather belt with a forged bronze dwarven buckle honoring dwarven ancestry and resilience.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: Constitution +2, Poison resistance/advantage, 60 ft Darkvision, Dwarvish fluency, and dwarf diplomacy advantage.',
        description:
            'Ancestral belt granting dwarven fortitude and racial traits.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'belt',
        'dwarvenkind',
        'constitution',
        'poison resistance',
        'darkvision',
        'dwarvish'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'belt', 'dwarvenkind', 'constitution', 'poison resistance', 'darkvision', 'dwarvish'] },
    ),

    // Boots of Striding and Springing
    EquipmentItem(
      id: EntityId(slug: 'item_boots_of_striding_and_springing', ruleset: RulesetVersion.v2024), name: 'Boots of Striding and Springing',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Passive: 30 ft minimum walking speed immune to armor encumbrance; triple jumping distance.',
      rules2014: ItemEditionDetails(
        summary:
            'Your walking speed becomes 30 feet unless it was already higher, and speed is not reduced if encumbered or in heavy armor. You can jump three times the normal distance.',
        description:
            'Supple leather boots that put a supernatural spring in your stride and prevent encumbrance slow-down.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: 30 ft minimum walking speed immune to armor encumbrance; triple jumping distance.',
        description:
            'Mobility boots maximizing jump distance and heavy armor mobility.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'boots',
        'striding',
        'springing',
        'speed',
        'jumping',
        'mobility'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'boots', 'striding', 'springing', 'speed', 'jumping', 'mobility'] },
    ),

    // Bracers of Armor
    EquipmentItem(
      id: EntityId(slug: 'item_bracers_of_armor', ruleset: RulesetVersion.v2024), name: 'Bracers of Armor',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Passive: +2 AC bonus while unarmored and without a shield.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing these bracers, you gain a +2 bonus to AC if you are wearing no armor and using no shield.',
        description:
            'Reinforced steel bands that generate an invisible protective force field around unarmored combatants.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Passive: +2 AC bonus while unarmored and without a shield.',
        description:
            'Abjuration bracers granting armored defense to unarmored spellcasters and monks.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'bracers',
        'armor',
        'ac bonus',
        'unarmored',
        'defense'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bracers', 'armor', 'ac bonus', 'unarmored', 'defense'], 'defaultSlot': EquipmentSlot.armor },
    ),

    // Gloves of Swimming and Climbing
    EquipmentItem(
      id: EntityId(slug: 'item_gloves_of_swimming_and_climbing', ruleset: RulesetVersion.v2024), name: 'Gloves of Swimming and Climbing',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Passive: free swimming/climbing movement and +5 to Strength (Athletics) for traverse.',
      rules2014: ItemEditionDetails(
        summary:
            'While wearing these gloves, climbing and swimming do not cost you extra movement, and you have a +5 bonus to Strength (Athletics) checks made to climb or swim.',
        description:
            'Webbed leather gloves with micro-traction palms for scaling vertical rock and slicing through water.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: free swimming/climbing movement and +5 to Strength (Athletics) for traverse.',
        description:
            'Exploration gloves optimizing swimming speed and cliff climbing.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'gloves',
        'swimming',
        'climbing',
        'athletics',
        'mobility'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'gloves', 'swimming', 'climbing', 'athletics', 'mobility'] },
    ),

    // Horseshoes of a Zephyr
    EquipmentItem(
      id: EntityId(slug: 'item_horseshoes_of_a_zephyr', ruleset: RulesetVersion.v2024), name: 'Horseshoes of a Zephyr',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Passive: mount hovers 4 inches above ground, crossing difficult terrain and liquids without harm or tracks.',
      rules2014: ItemEditionDetails(
        summary:
            'Set of 4 iron horseshoes. A horse or similar creature wearing them floats 4 inches above the ground. It can move across uneven terrain, water, and even lava without harm, leaving no tracks.',
        description:
            'Silvery horseshoes imbued with elemental air allowing steeds to gallop over chasms, water, and mud without touching the ground.',
        activation: 'Passive (Mount)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Passive: mount hovers 4 inches above ground, crossing difficult terrain and liquids without harm or tracks.',
        description:
            'Enchanted equestrian shoes enabling floating gallop over all surfaces.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'horseshoes',
        'zephyr',
        'mount',
        'hover',
        'water walk',
        'flight'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'horseshoes', 'zephyr', 'mount', 'hover', 'water walk', 'flight'] },
    ),

    // Horseshoes of Speed
    EquipmentItem(
      id: EntityId(slug: 'item_horseshoes_of_speed', ruleset: RulesetVersion.v2024), name: 'Horseshoes of Speed',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Passive: +30 ft walking speed for horse or mount.',
      rules2014: ItemEditionDetails(
        summary:
            'Set of 4 horseshoes. While all four are affixed to the hooves of a horse or similar creature, they increase its walking speed by 30 feet.',
        description:
            'Forged from lightweight celestial steel, these horseshoes bestow blistering acceleration upon equine mounts.',
        activation: 'Passive (Mount)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Passive: +30 ft walking speed for horse or mount.',
        description: 'Speed-enhancing equestrian shoes for mounts.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'horseshoes', 'speed', 'mount', 'movement'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'horseshoes', 'speed', 'mount', 'movement'] },
    ),

    // ==========================================
    // DECKS, CONTAINERS, SPHERES & PLANAR ARTIFACTS
    // ==========================================

    // Bag of Beans
    EquipmentItem(
      id: EntityId(slug: 'item_bag_of_beans', ruleset: RulesetVersion.v2024), name: 'Bag of Beans',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: plant and water bean to spawn random d100 wondrous landmark, monster, or blessing.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 3d4 magic beans. Action: plant a bean in dirt and water it; 1 minute later, a random effect occurs from the d100 Bag of Beans table (giant beanstalk to cloud castle, mummy pyramid, treant spawner, explosive eggs).',
        description:
            'A heavy cloth pouch containing oversized speckled beans that grow miraculous structures and hazards.',
        activation: '1 Action (Plant & Water)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: plant and water bean to spawn random d100 wondrous landmark, monster, or blessing.',
        description:
            'Chaotic gardening pouch producing unpredictable magical phenomena.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'bag',
        'beans',
        'chaotic',
        'random table',
        'spawner',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bag', 'beans', 'chaotic', 'random table', 'spawner', 'consumable'] },
    ),

    // Bag of Devouring
    EquipmentItem(
      id: EntityId(slug: 'item_bag_of_devouring', ruleset: RulesetVersion.v2024), name: 'Bag of Devouring',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Hazardous cursed container devouring items and pulling creatures inside on failed DC 15 Strength save.',
      rules2014: ItemEditionDetails(
        summary:
            'Appears as a Bag of Holding. In reality, it is the feeding orifice of an extra-dimensional creature. Swallows organic matter in 1 day. Reaching inside triggers 50% chance to be pulled in on failed DC 15 Strength check, being consumed and killed after 1 round.',
        description:
            'A sinister extra-dimensional predator disguised as a harmless magic container.',
        activation: 'Passive (Cursed Hazard)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Hazardous cursed container devouring items and pulling creatures inside on failed DC 15 Strength save.',
        description:
            'Predatory extra-dimensional mimic bag consuming matter and careless adventurers.',
        activation: 'Passive',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'bag',
        'devouring',
        'cursed',
        'hazard',
        'extradimensional'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bag', 'devouring', 'cursed', 'hazard', 'extradimensional'] },
    ),

    // Crystal Ball
    EquipmentItem(
      id: EntityId(slug: 'item_crystal_ball', ruleset: RulesetVersion.v2024), name: 'Crystal Ball',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Action: at-will Scrying casting (DC 17 Wis save).',
      rules2014: ItemEditionDetails(
        summary:
            'While touching this crystal sphere, you can use an action to cast the Scrying spell (save DC 17) with it at will.',
        description:
            'A flawless 6-inch quartz sphere that reveals distant people and locations.',
        activation: '1 Action (At Will)',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: at-will Scrying casting (DC 17 Wis save).',
        description: 'Divination orb for long-range surveillance and tracking.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 17',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'crystal ball',
        'scrying',
        'divination',
        'surveillance'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'crystal ball', 'scrying', 'divination', 'surveillance'] },
    ),

    // Cubic Gate
    EquipmentItem(
      id: EntityId(slug: 'item_cubic_gate', ruleset: RulesetVersion.v2024), name: 'Cubic Gate',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: '3 charges: Plane Shift or open 1-minute two-way portal to 6 keyed planar destinations.',
      rules2014: ItemEditionDetails(
        summary:
            'A 3-inch cube with 6 faces keyed to Material Plane and 5 other planes. Has 3 charges (regains 1d3 daily at dawn). Action: press 1 face to cast Plane Shift (1 charge) or press twice to open a two-way portal for 1 minute (2 charges).',
        description:
            'A carnelian cube inscribed with planar geometries enabling direct gateway transit across the multiverse.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '3 charges: Plane Shift or open 1-minute two-way portal to 6 keyed planar destinations.',
        description:
            'Legendary interplanar key activating portals to configured realms.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'cubic gate',
        'portal',
        'plane shift',
        'planar',
        'legendary'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'cubic gate', 'portal', 'plane shift', 'planar', 'legendary'] },
    ),

    // Deck of Illusions
    EquipmentItem(
      id: EntityId(slug: 'item_deck_of_illusions', ruleset: RulesetVersion.v2024), name: 'Deck of Illusions',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: draw and toss card up to 30 ft to manifest realistic illusory monster.',
      rules2014: ItemEditionDetails(
        summary:
            'Deck of 34 parchment cards. Action: draw a card at random and throw it up to 30 feet; an illusory creature spawns with visual and audio presence (Dragon, Iron Golem, Giant, Lich, Goblins). Moving card ends illusion.',
        description:
            'A boxed deck of cards painted with mythical beasts that spring into realistic phantasms when tossed.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: draw and toss card up to 30 ft to manifest realistic illusory monster.',
        description:
            'Illusion card deck deploying decoy creatures in tactical combat.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'deck',
        'illusions',
        'phantasm',
        'cards',
        'decoy',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'deck', 'illusions', 'phantasm', 'cards', 'decoy', 'consumable'] },
    ),

    // Dimensional Shackles
    EquipmentItem(
      id: EntityId(slug: 'item_dimensional_shackles', ruleset: RulesetVersion.v2024), name: 'Dimensional Shackles',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: bind incapacitated target, blocking all teleportation, planar travel, and shapechanging (DC 30 Str break check).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: fasten shackles onto an incapacitated creature. Automatically adjusts from Small to Large. Bound creature cannot teleport, use extradimensional travel (Ethereal Plane, Astral Plane, Blink, Misty Step, Plane Shift), or shapeshift. DC 30 Strength check to break free (1 attempt every 30 days).',
        description:
            'Golden adamantine manacles traced with antimagic locking runes.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: bind incapacitated target, blocking all teleportation, planar travel, and shapechanging (DC 30 Str break check).',
        description:
            'High-security planar prisoner restraints disabling teleportation and astral escape.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'dimensional shackles',
        'restraints',
        'teleportation',
        'planar lock'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'dimensional shackles', 'restraints', 'teleportation', 'planar lock'] },
    ),

    // Iron Bands of Binding
    EquipmentItem(
      id: EntityId(slug: 'item_iron_bands_of_binding', ruleset: RulesetVersion.v2024), name: 'Iron Bands of Binding',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: +6 ranged attack within 60 ft to bind and restrain target up to Huge size on hit (DC 20 Str break).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: throw sphere up to 60 ft with +6 ranged attack. On hit, iron bands expand to bind and restrain target (up to Huge size). Target can make DC 20 Strength check to burst free. Usable once per dawn.',
        description:
            'A 3-inch rusty iron sphere that instantly expands into a cage of interlocked metal bands on impact.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: +6 ranged attack within 60 ft to bind and restrain target up to Huge size on hit (DC 20 Str break).',
        description:
            'Deployable metallic restraint sphere locking down heavy targets.',
        activation: '1 Action (1/Day)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'iron bands',
        'binding',
        'restrained',
        'crowd control'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'iron bands', 'binding', 'restrained', 'crowd control'] },
    ),

    // Iron Flask
    EquipmentItem(
      id: EntityId(slug: 'item_iron_flask', ruleset: RulesetVersion.v2024), name: 'Iron Flask',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: imprison extraplanar entity (DC 17 Wis) or release to obey commands for 1 hour.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: unstopper flask and target a creature within 60 ft from another plane. Target must pass DC 17 Wis save or be pulled inside. Action to release: creature obeys your commands for 1 hour, then acts on its own.',
        description:
            'A heavy iron bottle sealed with brass runes and lead stoppers designed to imprison outsiders, fiends, and celestials.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: imprison extraplanar entity (DC 17 Wis) or release to obey commands for 1 hour.',
        description:
            'Legendary entity containment vessel holding powerful fiends, elementals, and celestials.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 17',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'iron flask',
        'imprisonment',
        'extraplanar',
        'legendary',
        'minion'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'iron flask', 'imprisonment', 'extraplanar', 'legendary', 'minion'] },
    ),

    // Mirror of Life Trapping
    EquipmentItem(
      id: EntityId(slug: 'item_mirror_of_life_trapping', ruleset: RulesetVersion.v2024), name: 'Mirror of Life Trapping',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Reflection hazard trapping viewers in 12 dimensional cells on failed DC 15 Cha save; command word release.',
      rules2014: ItemEditionDetails(
        summary:
            'Has 12 extra-dimensional cells. Any creature within 30 ft that sees its reflection must succeed on a DC 15 Charisma save or be trapped inside. The mirror can be covered or spoken to to release prisoners.',
        description:
            'A 4-foot tall framed mirror whose silvered glass reflects a doorway into twelve suspended animation chambers.',
        activation: 'Passive & 1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Reflection hazard trapping viewers in 12 dimensional cells on failed DC 15 Cha save; command word release.',
        description:
            'Dimensional containment mirror trapping intruders in extradimensional stasis.',
        activation: 'Passive & 1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'mirror',
        'life trapping',
        'imprisonment',
        'hazard',
        'extradimensional'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'mirror', 'life trapping', 'imprisonment', 'hazard', 'extradimensional'] },
    ),

    // Well of Many Worlds
    EquipmentItem(
      id: EntityId(slug: 'item_well_of_many_worlds', ruleset: RulesetVersion.v2024), name: 'Well of Many Worlds',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: deploy black cloth to create 6-foot two-way doorway to random planar world.',
      rules2014: ItemEditionDetails(
        summary:
            'Looks like a 6-foot circular black cloth. Action: unfold onto a flat surface to create a two-way portal to another world or plane (determined randomly by DM). Action: pull edges to fold and close the portal.',
        description:
            'A circular cloth woven from starlight that opens an open portal into distant planetary worlds and outer planes.',
        activation: '1 Action (Unfold / Fold)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: deploy black cloth to create 6-foot two-way doorway to random planar world.',
        description:
            'Portable world-hopping portal sheet enabling interplanar exploration.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'well of many worlds',
        'portal',
        'planar',
        'interplanetary',
        'legendary'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'well of many worlds', 'portal', 'planar', 'interplanetary', 'legendary'] },
    ),

    // ==========================================
    // ELEMENTAL FOCUSES & INSTRUMENTS
    // ==========================================

    // Bowl of Commanding Water Elementals
    EquipmentItem(
      id: EntityId(slug: 'item_bowl_of_commanding_water_elementals', ruleset: RulesetVersion.v2024), name: 'Bowl of Commanding Water Elementals',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: summon Water Elemental using basin of water (1/Day).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: fill bowl with water to cast Conjure Elemental (Water Elemental). The bowl can\'t be used again until next dawn.',
        description:
            'A blue ceramic basin adorned with wave and aquatic engravings.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: summon Water Elemental using basin of water (1/Day).',
        description:
            'Elemental focus for summoning and controlling obedient Water Elementals.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'bowl',
        'water elemental',
        'elemental',
        'summon',
        'conjuration'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bowl', 'water elemental', 'elemental', 'summon', 'conjuration'] },
    ),

    // Brazier of Commanding Fire Elementals
    EquipmentItem(
      id: EntityId(slug: 'item_brazier_of_commanding_fire_elementals', ruleset: RulesetVersion.v2024), name: 'Brazier of Commanding Fire Elementals',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: summon Fire Elemental using lit brazier (1/Day).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: light a fire in the brazier to cast Conjure Elemental (Fire Elemental). Usable once per dawn.',
        description: 'A brass tripod brazier with flame engravings.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: summon Fire Elemental using lit brazier (1/Day).',
        description:
            'Elemental focus for summoning and commanding Fire Elementals.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'brazier',
        'fire elemental',
        'elemental',
        'summon',
        'conjuration'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'brazier', 'fire elemental', 'elemental', 'summon', 'conjuration'] },
    ),

    // Censer of Controlling Air Elementals
    EquipmentItem(
      id: EntityId(slug: 'item_censer_of_controlling_air_elementals', ruleset: RulesetVersion.v2024), name: 'Censer of Controlling Air Elementals',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: summon Air Elemental using burning incense (1/Day).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: burn incense in censer to cast Conjure Elemental (Air Elemental). Usable once per dawn.',
        description: 'A perforated brass censer swinging on a silver chain.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: summon Air Elemental using burning incense (1/Day).',
        description:
            'Elemental focus for summoning and commanding Air Elementals.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'censer',
        'air elemental',
        'elemental',
        'summon',
        'conjuration'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'censer', 'air elemental', 'elemental', 'summon', 'conjuration'] },
    ),

    // Stone of Controlling Earth Elementals
    EquipmentItem(
      id: EntityId(slug: 'item_stone_of_controlling_earth_elementals', ruleset: RulesetVersion.v2024), name: 'Stone of Controlling Earth Elementals',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: summon Earth Elemental by setting stone on ground (1/Day).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: place stone on dirt or rock to cast Conjure Elemental (Earth Elemental). Usable once per dawn.',
        description: 'A rough geode resonant with elemental earth energy.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: summon Earth Elemental by setting stone on ground (1/Day).',
        description:
            'Elemental focus for summoning and commanding Earth Elementals.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'stone',
        'earth elemental',
        'elemental',
        'summon',
        'conjuration'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'stone', 'earth elemental', 'elemental', 'summon', 'conjuration'] },
    ),

    // Horn of Blasting
    EquipmentItem(
      id: EntityId(slug: 'item_horn_of_blasting', ruleset: RulesetVersion.v2024), name: 'Horn of Blasting',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: 30-ft cone dealing 5d6 thunder damage and deafened condition (DC 15 Con). 20% malfunction detonation risk.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: blow horn to emit 30-ft cone. Creatures take 5d6 thunder damage and are deafened for 1 minute on failed DC 15 Con save (half damage on success). 20% chance horn detonates for 10d6 thunder damage to user.',
        description:
            'A curved horn made of polished brass that unleashes a thunderous sonic shockwave.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: 30-ft cone dealing 5d6 thunder damage and deafened condition (DC 15 Con). 20% malfunction detonation risk.',
        description:
            'Sonic siege horn blasting cone of thunderous concussive force.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'horn', 'blasting', 'thunder', 'deafened', 'sonic'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'horn', 'blasting', 'thunder', 'deafened', 'sonic'] },
    ),

    // Pipes of Haunting
    EquipmentItem(
      id: EntityId(slug: 'item_pipes_of_haunting', ruleset: RulesetVersion.v2024), name: 'Pipes of Haunting',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: '3 charges: play tune frightening non-allies in 30 ft radius (DC 15 Wis save).',
      rules2014: ItemEditionDetails(
        summary:
            'Has 3 charges (regains 1d3 daily at dawn). Action: play pipes; creatures within 30 ft that can hear must succeed on a DC 15 Wisdom save or become frightened for 1 minute.',
        description:
            'Pan pipes carved from bone that produce an eerie, mournful melody.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '3 charges: play tune frightening non-allies in 30 ft radius (DC 15 Wis save).',
        description:
            'Eerie musical pipes inflicting the Frightened condition across an area.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'pipes',
        'haunting',
        'frightened',
        'fear',
        'music',
        'instrument'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'pipes', 'haunting', 'frightened', 'fear', 'music', 'instrument'] },
    ),

    // Pipes of the Sewers
    EquipmentItem(
      id: EntityId(slug: 'item_pipes_of_the_sewers', ruleset: RulesetVersion.v2024), name: 'Pipes of the Sewers',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: '3 charges: summon and command 1d3 Swarms of Rats for 1 hour.',
      rules2014: ItemEditionDetails(
        summary:
            'Has 3 charges (regains 1d3 daily at dawn). While worn, ordinary rats are non-hostile. Action: play pipes to call 1d3 Swarms of Rats (if rats are in 1/2 mile); they obey telepathic commands for 1 hour.',
        description:
            'Rundown copper pipes that summon and direct swarms of rodent minions.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: summon and command 1d3 Swarms of Rats for 1 hour.',
        description: 'Instrument focus summoning swarms of vermin companions.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'pipes',
        'sewers',
        'rats',
        'swarm',
        'summon',
        'minion'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'pipes', 'sewers', 'rats', 'swarm', 'summon', 'minion'] },
    ),

    // Wind Fan
    EquipmentItem(
      id: EntityId(slug: 'item_wind_fan', ruleset: RulesetVersion.v2024), name: 'Wind Fan',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: cast Gust of Wind (DC 13 Str save). Repeat uses on same day risk destroying fan.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: wave fan to cast Gust of Wind (save DC 13). Can be used once per day safely; each additional use has cumulative 20% chance to rip fan and render it nonmagical.',
        description:
            'A fan of painted silk that unleashes a gale of pressurized wind.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: cast Gust of Wind (DC 13 Str save). Repeat uses on same day risk destroying fan.',
        description:
            'Wind-generating handheld fan pushing foes and clearing gaseous hazards.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'wind fan',
        'gust of wind',
        'wind',
        'push',
        'evocation'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'wind fan', 'gust of wind', 'wind', 'push', 'evocation'] },
    ),

    // ==========================================
    // DUSTS, GLUES & CONSUMABLES
    // ==========================================

    // Bead of Force
    EquipmentItem(
      id: EntityId(slug: 'item_bead_of_force', ruleset: RulesetVersion.v2024), name: 'Bead of Force',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: throw bead dealing 5d4 force damage and trapping targets inside a force sphere for 1 minute (DC 15 Dex save).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: throw bead up to 60 ft. Detonates in 10-ft radius: creatures take 5d4 force damage and are trapped in a transparent sphere of force on failed DC 15 Dex save for 1 minute (half damage on success).',
        description:
            'A small black sphere made of hardened force that explodes into a containment sphere upon impact.',
        activation: '1 Action (Thrown 60 ft)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: throw bead dealing 5d4 force damage and trapping targets inside a force sphere for 1 minute (DC 15 Dex save).',
        description:
            'Consumable tactical explosive creating a containment force sphere.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'bead of force',
        'force',
        'containment',
        'sphere',
        'explosive',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'bead of force', 'force', 'containment', 'sphere', 'explosive', 'consumable'] },
    ),

    // Dust of Disappearance
    EquipmentItem(
      id: EntityId(slug: 'item_dust_of_disappearance', ruleset: RulesetVersion.v2024), name: 'Dust of Disappearance',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: grant 2d4 minutes of persistent Invisibility to all creatures in 10 ft (remains active through attacks and spells).',
      rules2014: ItemEditionDetails(
        summary:
            'Action: throw a pinch of dust into the air; you and creatures within 10 feet become invisible for 2d4 minutes. Unlike normal invisibility, attacking or casting spells does not end the invisibility.',
        description:
            'Fine metallic dust that refracts light completely around all creatures within its radius.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: grant 2d4 minutes of persistent Invisibility to all creatures in 10 ft (remains active through attacks and spells).',
        description: 'Consumable superior invisibility powder.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'dust',
        'disappearance',
        'invisibility',
        'stealth',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'dust', 'disappearance', 'invisibility', 'stealth', 'consumable'] },
    ),

    // Dust of Dryness
    EquipmentItem(
      id: EntityId(slug: 'item_dust_of_dryness', ruleset: RulesetVersion.v2024), name: 'Dust of Dryness',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: condense 15-ft cube of water into a portable pellet; crush pellet to unleash flash flood.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: sprinkle dust onto water to instantly absorb a 15-foot cube of liquid into a marble-sized pellet. Action: smash pellet to release all water instantly. Deals 10d6 necrotic damage to water elementals on failed DC 13 Con save.',
        description:
            'Golden powder capable of capturing an entire pond or flooding a dry dungeon room instantly.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: condense 15-ft cube of water into a portable pellet; crush pellet to unleash flash flood.',
        description:
            'Water-manipulation dust capturing or unleashing large volumes of liquid.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: ['wondrous', 'dust', 'dryness', 'water', 'flood', 'consumable'],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'dust', 'dryness', 'water', 'flood', 'consumable'] },
    ),

    // Dust of Sneezing and Choking
    EquipmentItem(
      id: EntityId(slug: 'item_dust_of_sneezing_and_choking', ruleset: RulesetVersion.v2024), name: 'Dust of Sneezing and Choking',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Cursed dust cloud causing Incapacitated condition and suffocation on failed DC 15 Con save.',
      rules2014: ItemEditionDetails(
        summary:
            'Appears as Dust of Disappearance. When thrown, all creatures in 20-ft radius must succeed on a DC 15 Con save or become incapacitated and start suffocating until cured by Lesser Restoration or similar magic.',
        description:
            'Fine grey powder that triggers violent uncontrollable coughing and asphyxiation.',
        activation: '1 Action (Cursed Hazard)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Cursed dust cloud causing Incapacitated condition and suffocation on failed DC 15 Con save.',
        description:
            'Cursed asphyxiation powder disguised as invisibility dust.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'dust',
        'sneezing',
        'choking',
        'cursed',
        'suffocating',
        'incapacitated',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'dust', 'sneezing', 'choking', 'cursed', 'suffocating', 'incapacitated', 'consumable'] },
    ),

    // Incense of Obsession
    EquipmentItem(
      id: EntityId(slug: 'item_incense_of_obsession', ruleset: RulesetVersion.v2024), name: 'Incense of Obsession',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Cursed incense cloud imposing delusion and disadvantage on all ability checks and attack rolls on failed DC 15 Wis save.',
      rules2014: ItemEditionDetails(
        summary:
            'Appears as Incense of Meditation. When burned, creatures in 30-ft cloud must pass DC 15 Wis save or become obsessed with their spells, taking disadvantage on all attack rolls and ability checks for 24 hours.',
        description:
            'Aromatic incense blocks emitting sweet, mind-numbing purple vapor.',
        activation: 'Action to Burn (Cursed Hazard)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Cursed incense cloud imposing delusion and disadvantage on all ability checks and attack rolls on failed DC 15 Wis save.',
        description: 'Cursed psychological smoke inducing obsessive confusion.',
        activation: '1 Action',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'incense',
        'obsession',
        'cursed',
        'disadvantage',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'incense', 'obsession', 'cursed', 'disadvantage', 'consumable'] },
    ),

    // Restorative Ointment
    EquipmentItem(
      id: EntityId(slug: 'item_restorative_ointment', ruleset: RulesetVersion.v2024), name: 'Restorative Ointment',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: apply salve dose to restore 2d8 + 2 HP, remove Poisoned condition, and cure diseases.',
      rules2014: ItemEditionDetails(
        summary:
            'Jar contains 1d4 + 1 doses of thick salve. Action: apply 1 dose to a creature to restore 2d8 + 2 hit points, cure all diseases, and neutralize all poisons affecting it.',
        description:
            'A glass jar of herbal salve that instantly knits flesh, expels venoms, and cleanses disease.',
        activation: '1 Action (1 Dose)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: apply salve dose to restore 2d8 + 2 HP, remove Poisoned condition, and cure diseases.',
        description:
            'Triple-action medicinal ointment for emergency field healing and neutralization.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'ointment',
        'healing',
        'poison cure',
        'disease cure',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'ointment', 'healing', 'poison cure', 'disease cure', 'consumable'] },
    ),

    // Sovereign Glue
    EquipmentItem(
      id: EntityId(slug: 'item_sovereign_glue', ruleset: RulesetVersion.v2024), name: 'Sovereign Glue',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: apply legendary permanent adhesive bonding objects together permanently.',
      rules2014: ItemEditionDetails(
        summary:
            'Flask contains 1d6 + 1 ounces of milky viscous glue. Takes 1 minute to set, forming an unbreakable bond between two surfaces that can only be dissolved by Universal Solvent, Oil of Etherealness, or Wish.',
        description:
            'A legendary adhesive that forms an unbreakable molecular weld between any two solid objects.',
        activation: '1 Action to Apply (Sets in 1 Minute)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: apply legendary permanent adhesive bonding objects together permanently.',
        description:
            'Indestructible bonding glue dissolved only by Universal Solvent or Wish.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'sovereign glue',
        'adhesive',
        'permanent',
        'legendary',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'sovereign glue', 'adhesive', 'permanent', 'legendary', 'consumable'] },
    ),

    // Universal Solvent
    EquipmentItem(
      id: EntityId(slug: 'item_universal_solvent', ruleset: RulesetVersion.v2024), name: 'Universal Solvent',
      itemType: 'wondrousItem', category: ItemCategory.wondrousItem, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'Action: dissolve any adhesive or Sovereign Glue bond instantly.',
      rules2014: ItemEditionDetails(
        summary:
            'Action: pour milky liquid onto any adhesive, including Sovereign Glue; the adhesive dissolves instantly.',
        description:
            'A flask containing a clear solvent that dissolves any known magical or mundane adhesive instantly.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Action: dissolve any adhesive or Sovereign Glue bond instantly.',
        description:
            'Solvent flask specifically counteracting permanent adhesive bonds.',
        activation: '1 Action',
      ),
      isChangedIn2024: false, tags: [
        'wondrous',
        'universal solvent',
        'dissolve',
        'sovereign glue',
        'legendary',
        'consumable'
      ],
      customProperties: { 'cost': null, 'category': 'wondrousItem', 'tags': ['wondrous', 'universal solvent', 'dissolve', 'sovereign glue', 'legendary', 'consumable'] },
    ),
  ];
}
