import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Magic Rings Catalog
class SrdMagicRings {
  SrdMagicRings._();

  static const List<MagicItem> items = [
    // Ring of Protection
    MagicItem(
      id: 'item_ring_of_protection',
      name: 'Ring of Protection',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 to AC & Saving Throws'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You gain a +1 bonus to Armor Class and saving throws while wearing this ring.',
        description: 'You gain a +1 bonus to Armor Class and saving throws while wearing this ring.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You gain a +1 bonus to Armor Class and all saving throws while wearing this ring.',
        description: 'You gain a +1 bonus to Armor Class and all saving throws while wearing this ring.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'ac', 'saving throws', 'defense'],
    ),

    // Ring of Spell Storing
    MagicItem(
      id: 'item_ring_of_spell_storing',
      name: 'Ring of Spell Storing',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Store up to 5 Levels of Spells'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Holds up to 5 levels of spells that any creature can cast into the ring and the wearer can cast without spell slots.',
        description: 'This ring stores spells cast into it, holding them until the attuned wearer uses them. The ring can store up to 5 levels worth of spells at a time. When found, it contains 1d6 - 1 levels of stored spells chosen by the DM. Any creature can cast a spell of 1st through 5th level into the ring by touching it as the spell is cast. The spell has no effect, other than to be stored in the ring. While wearing this ring, you can cast any spell stored in it with the slot level, spell save DC, spell attack bonus, and spellcasting ability of the original caster.',
        activation: 'Matches stored spell',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Stores up to 5 spell levels cast into the ring; wearer casts them with original caster\'s parameters or wearer\'s parameters.',
        description: 'Holds up to 5 levels of spells. Any creature can cast a spell of level 1–5 into the ring by touching it. While wearing it, you can cast any stored spell using its standard casting time.',
        activation: 'Matches stored spell',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'spell slot', 'utility', 'versatile'],
    ),

    // Ring of Invisibility
    MagicItem(
      id: 'item_ring_of_invisibility',
      name: 'Ring of Invisibility',
      category: ItemCategory.ring,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Become Invisible (At Will) until Attack or Spell'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this ring, you can turn invisible as an action. Anything you are wearing or carrying is invisible with you. You remain invisible until the ring is removed, until you attack or cast a spell, or until you use a bonus action to become visible again.',
        description: 'While wearing this ring, you can turn invisible as an action. Anything you are wearing or carrying is invisible with you. You remain invisible until the ring is removed, until you attack or cast a spell, or until you use a bonus action to become visible again.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: gain Invisible condition at will. Ends if you make an attack roll, deal damage, cast a spell, or dismiss it.',
        description: 'While wearing this ring, use an Action to become Invisible. The condition ends if you attack, cast a spell, deal damage, or use a Bonus Action to end it.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'invisibility', 'stealth', 'legendary'],
    ),

    // Ring of Regeneration
    MagicItem(
      id: 'item_ring_of_regeneration',
      name: 'Ring of Regeneration',
      category: ItemCategory.ring,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Regain 1d6 HP every 10 Minutes & Regrow Lost Limbs (1d6+1 Days)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this ring, you regain 1d6 hit points every 10 minutes if you have at least 1 hit point. If you lose a body part, the ring causes it to regrow in 1d6 + 1 days.',
        description: 'While wearing this ring, you regain 1d6 hit points every 10 minutes, provided that you have at least 1 hit point. If you lose a body part, the ring causes the missing part to regrow and return to full functionality after 1d6 + 1 days if you have at least 1 hit point the whole time.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Regain 1d6 HP every 10 minutes (if above 0 HP) and regrow severed body parts over 1d6+1 days.',
        description: 'While you have at least 1 HP, regain 1d6 HP every 10 minutes and regrow lost body parts after 1d6 + 1 days.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'regeneration', 'healing', 'survival'],
    ),

    // Ring of Resistance
    MagicItem(
      id: 'item_ring_of_resistance',
      name: 'Ring of Resistance',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Grants Resistance to 1 Damage Type (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, Thunder)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have resistance to one damage type determined by the gem set in the ring (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, Thunder).',
        description: 'You have resistance to one damage type determined by the gem set in the ring: Acid (Pearl), Cold (Tourmaline), Fire (Garnet), Force (Sapphire), Lightning (Citrine), Necrotic (Jet), Poison (Amethyst), Psychic (Jade), Radiant (Topaz), or Thunder (Spinel).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants Resistance to one chosen damage type while worn.',
        description: 'You have Resistance to one damage type (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, or Thunder) associated with the ring.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'resistance', 'defense', 'elemental'],
    ),

    // Ring of Free Action
    MagicItem(
      id: 'item_ring_of_free_action',
      name: 'Ring of Free Action',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Ignore Difficult Terrain; Magic cannot reduce speed or cause Paralyzed/Restrained'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this ring, difficult terrain doesn\'t cost you extra movement, and magic can neither reduce your speed nor cause you to be paralyzed or restrained.',
        description: 'While you wear this ring, difficult terrain doesn\'t cost you extra movement. In addition, magic can neither reduce your speed nor cause you to be paralyzed or restrained.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Ignore Difficult Terrain; immune to magical speed reduction and the Paralyzed and Restrained conditions caused by magic.',
        description: 'Difficult terrain does not reduce your Speed. Magic cannot reduce your Speed, nor can magic inflict the Paralyzed or Restrained conditions on you.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'free action', 'movement', 'immunity', 'condition'],
    ),

    // Ring of Evasion
    MagicItem(
      id: 'item_ring_of_evasion',
      name: 'Ring of Evasion',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Reaction: Succeed on Failed DEX Saving Throw (3 Charges)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'This ring has 3 charges. When you fail a Dexterity saving throw while wearing it, you can use your reaction to expend 1 charge to succeed instead.',
        description: 'This ring has 3 charges (regains 1d3 daily at dawn). When you fail a Dexterity saving throw while wearing it, you can use your reaction to expend 1 charge to succeed on that saving throw instead.',
        activation: '1 Reaction',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Reaction: expend 1 charge to turn a failed Dexterity saving throw into a success (3 charges, recharges on Long Rest).',
        description: 'Contains 3 charges. When you fail a Dexterity saving throw, use your Reaction to expend 1 charge and succeed instead.',
        activation: '1 Reaction',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'evasion', 'dexterity', 'saving throw', 'reaction'],
    ),

    // Ring of Feather Falling
    MagicItem(
      id: 'item_ring_of_feather_falling',
      name: 'Ring of Feather Falling',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Reaction on Falling: Feather Fall (Descent 60 ft/round, 0 Fall Dmg)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'When you fall while wearing this ring, you descend 60 feet per round and take no damage from falling.',
        description: 'When you fall while wearing this ring, you descend 60 feet per round and take no damage from falling.',
        activation: 'Passive on Falling',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Falling speed automatically slows to 60 ft per round and you take no falling damage.',
        description: 'While wearing this ring, when you fall, your descent slows to 60 feet per round and you take 0 damage from the fall.',
        activation: 'Passive on Falling',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'feather fall', 'falling', 'survival'],
    ),

    // Ring of Mind Shielding
    MagicItem(
      id: 'item_ring_of_mind_shielding',
      name: 'Ring of Mind Shielding',
      category: ItemCategory.ring,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Immune to telepathy, mind reading & lie detection; Soul enters ring on death'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You are immune to magic that allows other creatures to read your thoughts, determine if you are lying, or know your creature type. Can make the ring invisible.',
        description: 'While wearing this ring, you are immune to magic that allows other creatures to read your thoughts, determine whether you are lying, know your alignment, or know your creature type. Creatures can telepathically communicate with you only if you allow it. If you die while wearing the ring, your soul enters it, unless it already houses a soul.',
        activation: 'Passive / 1 Action (Invisibility)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Immunity to telepathic intrusion, thought reading, and alignment/lie detection. Preserves soul upon death.',
        description: 'Grants complete immunity to telepathic intrusions and thought-reading magic. You can turn the ring invisible at will. If you die, your soul can safely inhabit the ring.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'mind shielding', 'telepathy', 'soul', 'psychic'],
    ),

    // Ring of Shooting Stars
    MagicItem(
      id: 'item_ring_of_shooting_stars',
      name: 'Ring of Shooting Stars',
      category: ItemCategory.ring,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      damageAccent: DamageAccent.lightning,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '6 Charges: Dancing Lights at will; Faerie Fire (1 charge); Ball Lightning 5d4 (2 charges); Shooting Stars 5d4 (1-3 charges)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 6 charges for Dancing Lights (at will in darkness), Faerie Fire, Ball Lightning (5d4 per ball), and Shooting Stars (5d4 per bead in 15-ft cube).',
        description: 'While wearing this ring in dim light or darkness, you can cast Dancing Lights and Light from it at will. Has 6 charges (regains 1d6 daily at dawn). You can expend charges to cast: Faerie Fire (1 charge), Ball Lightning (2 charges: creates up to 4 glowing balls dealing 5d4 lightning damage each on DC 15 Dex save), or Shooting Stars (1-3 charges: launches 1 to 3 sparks exploding in a 15-foot cube for 5d4 fire damage each on DC 15 Dex save).',
        activation: '1 Action',
        charges: '6 charges (recharges 1d6 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '6 charges: at-will Light spells, Faerie Fire, Ball Lightning, and Shooting Stars bursts.',
        description: 'Contains 6 charges. Cast Dancing Lights at will in darkness. Expend charges for Faerie Fire (1 charge), Ball Lightning (2 charges, 5d4 Lightning each), or Shooting Stars (1–3 charges, 5d4 Fire per star).',
        activation: '1 Action',
        charges: '6 charges (recharges 1d6 on Long Rest)',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'shooting stars', 'lightning', 'fire', 'aoe', 'charges'],
    ),

    // Ring of Telekinesis
    MagicItem(
      id: 'item_ring_of_telekinesis',
      name: 'Ring of Telekinesis',
      category: ItemCategory.ring,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Cast Telekinesis at Will (Objects up to 1,000 lbs)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this ring, you can cast the Telekinesis spell at will, but you can target only objects that aren\'t being worn or carried.',
        description: 'While wearing this ring, you can cast the Telekinesis spell at will, but you can target only objects that aren\'t being worn or carried.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: cast Telekinesis at will targeting unheld objects (up to 1,000 lbs).',
        description: 'Cast Telekinesis at will as an Action, targeting objects up to 1,000 pounds that aren\'t worn or carried.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'telekinesis', 'force', 'utility'],
    ),

    // Ring of the Ram
    MagicItem(
      id: 'item_ring_of_the_ram',
      name: 'Ring of the Ram',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      damageAccent: DamageAccent.force,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.force, label: '3 Charges: Ram Attack (2d10 Force per charge, +7 to Hit, 60 ft Range & DC 15 Push 5 ft)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Has 3 charges: make a ranged spell attack (+7 bonus, 60 ft range) expending 1–3 charges. Deals 2d10 force damage per charge and pushes target 5 ft per charge (DC 15 Str save).',
        description: 'This ring has 3 charges (regains 1d3 daily at dawn). While wearing the ring, you can use an action and expend 1 to 3 of its charges to make a ranged spell attack against one creature or object you can see within 60 feet of you. The ring makes its attack roll with a +7 bonus. On a hit, for each charge you expend, the target takes 2d10 force damage and is pushed 5 feet away from you (DC 15 Strength save to resist push). Can also break doors/locks.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: make +7 ranged spell attack dealing 2d10 Force damage and pushing 5 ft per charge spent (up to 6d10 Force and 15 ft push).',
        description: 'Action: expend 1–3 charges to make a +7 spell attack (60 ft). Deals 2d10 Force damage and pushes 5 ft per charge (DC 15 Strength save).',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'ram', 'force', 'push', 'damage'],
    ),

    // Ring of Three Wishes
    MagicItem(
      id: 'item_ring_of_three_wishes',
      name: 'Ring of Three Wishes',
      category: ItemCategory.ring,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.legendary, label: 'Contains 3 Wishes (Cast Wish as an Action; Becomes Nonmagical when Expended)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this ring, you can use an action to expend 1 of its 3 charges to cast the Wish spell from it. Once the last charge is spent, the ring becomes a nonmagical ring.',
        description: 'While wearing this ring, you can use an action to expend 1 of its 3 charges to cast the Wish spell from it. The ring regains no charges. Once the third charge is expended, the ring loses its magic and becomes a nonmagical ring.',
        activation: '1 Action',
        charges: '3 charges (non-rechargeable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: expend 1 charge to cast Wish (3 charges total, non-rechargeable).',
        description: 'Action: cast Wish. Has 3 charges. Becomes nonmagical once all 3 charges are expended.',
        activation: '1 Action',
        charges: '3 charges (non-rechargeable)',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'wish', 'legendary', 'ultimate'],
    ),

    // Ring of Water Walking
    MagicItem(
      id: 'item_ring_of_water_walking',
      name: 'Ring of Water Walking',
      category: ItemCategory.ring,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Stand on and Move Across Any Liquid Surface (Water, Acid, Mud, Snow, Quicksand, Lava)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this ring, you can stand on and move across any liquid surface (such as water, acid, mud, snow, quicksand, or lava) as if it were harmless solid ground.',
        description: 'While wearing this ring, you can stand on and move across any liquid surface (such as water, acid, mud, snow, quicksand, or lava) as if it were harmless solid ground (creatures crossing molten lava can still take damage from the heat).',
        activation: 'Passive / Movement',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Walk and run across all liquid surfaces as solid ground.',
        description: 'While wearing this ring, you can move across liquids (water, acid, snow, lava) as if they were solid ground.',
        activation: 'Passive / Movement',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'water walking', 'liquids', 'utility'],
    ),

    // Ring of Warmth
    MagicItem(
      id: 'item_ring_of_warmth',
      name: 'Ring of Warmth',
      category: ItemCategory.ring,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      glyphColor: Color(0xFFEF4444),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Resistance to Cold Damage & Immune to Extreme Cold Environments (down to -50°F)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While wearing this ring, you have resistance to cold damage. In addition, you and everything you wear and carry are unharmed by temperatures as low as -50 degrees Fahrenheit.',
        description: 'While wearing this ring, you have resistance to cold damage. In addition, you and everything you wear and carry are unharmed by temperatures as low as -50 degrees Fahrenheit.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Resistance to Cold damage; complete protection against Extreme Cold environments.',
        description: 'Grants Resistance to Cold damage and immunity to cold weather hazards down to -50°F.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'warmth', 'cold', 'resistance', 'survival'],
    ),

    // Ring of Animal Influence
    MagicItem(
      id: 'item_ring_of_animal_influence',
      name: 'Ring of Animal Influence',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      glyphColor: Color(0xFF10B981),
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '3 Charges: Animal Friendship, Fear (Beasts), Speak with Animals'),
      ],
      rules2014: ItemEditionDetails(
        summary: '3 charges (recharges 1d3 daily at dawn). Cast Animal Friendship (DC 13), Fear (beasts only, DC 13), or Speak with Animals.',
        description: 'This ring has 3 charges. While wearing it, you can expend 1 charge to cast Animal Friendship (save DC 13), Fear (save DC 13, targeting only beasts with Int 3 or lower), or Speak with Animals.',
        activation: '1 Action (Expends 1 Charge)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cast Animal Friendship, Fear (beasts), or Speak with Animals (3 charges).',
        description: 'Allows casting nature spells to communicate with and charm beasts.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'animal', 'beast', 'charm', 'druid', 'ranger'],
    ),
  ];
}
