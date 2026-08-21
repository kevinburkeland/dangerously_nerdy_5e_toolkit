import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Magic Staves Catalog
class SrdMagicStaves {
  SrdMagicStaves._();

  static const List<MagicItem> items = [
    // Staff of Power
    MagicItem(
      id: 'item_staff_of_power',
      name: 'Staff of Power',
      category: ItemCategory.staff,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      attunementRequirement: 'by a Sorcerer, Warlock, or Wizard',
      damageAccent: DamageAccent.force,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          damageType: DamageAccent.force,
          label: '+2 Quarterstaff & +2 to AC, Saves & Spell Attacks',
        ),
        ActionTraitRing(
          ringType: ActionRingType.recharge,
          label: '20 Charges (Cone of Cold, Fireball, Globe of Invulnerability, Lightning Bolt, Wall of Force)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 staff granting +2 to AC, saving throws, and spell attack rolls with 20 charges for high-tier spells and Retributive Strike.',
        description: 'This staff can be wielded as a magic quarterstaff that grants a +2 bonus to attack and damage rolls. While holding it, you gain a +2 bonus to Armor Class, saving throws, and spell attack rolls. The staff has 20 charges (regains 2d8 + 4 charges daily at dawn). You can expend charges to cast: cone of cold (5 charges), fireball (5th-level, 5 charges), globe of invulnerability (6 charges), hold monster (5 charges), levitate (2 charges), lightning bolt (5th-level, 5 charges), magic missile (1 charge), ray of enfeeblement (1 charge), or wall of force (5 charges). You can use an action to break the staff over your knee for a Retributive Strike (deals up to 400 force damage based on charges).',
        activation: '1 Action (Spells or Retributive Strike)',
        charges: '20 charges (recharges 2d8 + 4 daily at dawn)',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 staff with +2 to AC, Saves, and Spell Attacks; 20 charges that now scale with your own Spell Save DC.',
        description: 'Quarterstaff (+2 bonus to attack and damage rolls). While holding it, gain a +2 bonus to AC, saving throws, and spell attack rolls. Has 20 charges. Spells cast through the staff now use YOUR spell save DC and spell attack bonus (or DC 17, whichever is higher). Includes Retributive Strike.',
        activation: '1 Action',
        charges: '20 charges (recharges 2d8 + 4 daily at dawn)',
        savingThrowDc: 'Your Spell Save DC or DC 17 (whichever is higher)',
      ),
      isChangedIn2024: true,
      diffSummary: 'In 2024, spells cast from the staff use your own Spell Save DC if higher than DC 17.',
      diffHighlights: [
        '2024: Magic focus save DCs scale using your own Spell Save DC if higher than the staff\'s default DC 17.',
      ],
      tags: ['staff', 'wizard', 'sorcerer', 'warlock', 'power', 'charges'],
    ),

    // Staff of the Magi
    MagicItem(
      id: 'item_staff_of_the_magi',
      name: 'Staff of the Magi',
      category: ItemCategory.staff,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      attunementRequirement: 'by a Sorcerer, Warlock, or Wizard',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.melee,
          label: '+2 Quarterstaff, +2 to Spell Attacks & Spell Absorption',
        ),
        ActionTraitRing(
          ringType: ActionRingType.legendary,
          label: '50 Charges: Plane Shift, Telekinesis, Wall of Fire, Conjure Elemental, Ice Storm, Dispel Magic',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 quarterstaff, +2 to spell attack rolls, spell absorption, and 50 charges for casting world-shaking spells and devastating Retributive Strike.',
        description: 'This staff grants a +2 bonus to attack and damage rolls and +2 to spell attack rolls. Spell Absorption: Reaction to absorb a targeted spell and convert into charges. 50 charges (regains 4d6 + 2 daily at dawn). Cast at-will spells (Arcane Lock, Detect Magic, Enlarge/Reduce, Light, Mage Hand, Protection from Evil and Good) or expending charges for Conjure Elemental, Dispel Magic, Fireball (7th-level), Flaming Sphere, Ice Storm, Invisibility, Knock, Lightning Bolt (7th-level), Passwall, Plane Shift, Telekinesis, Wall of Fire (7th-level), or Web. Retributive Strike: Deals up to 800 damage.',
        activation: '1 Action (Spells) / 1 Reaction (Absorption)',
        charges: '50 charges (recharges 4d6 + 2 daily at dawn)',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 staff and +2 to Spell Attacks; Spell Absorption reaction; 50 charges scaling with your own DC.',
        description: 'Iconic legendary staff. Spell Absorption reaction absorbs incoming magic to restore charges. Spells cast through the staff utilize your own Spell Save DC or DC 17.',
        activation: '1 Action / 1 Reaction',
        charges: '50 charges (recharges 4d6 + 2 daily at dawn)',
        savingThrowDc: 'Your Spell Save DC or DC 17',
      ),
      isChangedIn2024: true,
      diffSummary: 'Staff spell DC scales with caster\'s own Spell Save DC in 2024.',
      diffHighlights: [
        '2024: Scaled save DC and updated Plane Shift / Telekinesis rules.',
      ],
      tags: ['staff', 'magi', 'legendary', 'wizard', 'spellcaster', 'absorption'],
    ),

    // Staff of Fire
    MagicItem(
      id: 'item_staff_of_fire',
      name: 'Staff of Fire',
      category: ItemCategory.staff,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      attunementRequirement: 'by a Druid, Sorcerer, Warlock, or Wizard',
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          damageType: DamageAccent.fire,
          label: 'Fire Resistance & 10 Charges (Burning Hands, Fireball, Wall of Fire)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Grants resistance to fire damage and 10 charges to cast Burning Hands, Fireball, and Wall of Fire.',
        description: 'You have resistance to fire damage while you hold this staff. Has 10 charges (regains 1d6 + 4 daily at dawn). While holding it, you can cast Burning Hands (1 charge), Fireball (3 charges), or Wall of Fire (4 charges).',
        activation: '1 Action',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Resistance to Fire damage; 10 charges for Burning Hands, Fireball, and Wall of Fire using your own Save DC.',
        description: 'Grants Resistance to Fire damage. 10 charges to cast fire spells. Spells cast through the staff use your Spell Save DC (or DC 15, whichever is higher).',
        activation: '1 Action',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: 'Staff spell DC scales with your own Spell Save DC in 2024.',
      diffHighlights: [
        '2024: Scaled save DC.',
      ],
      tags: ['staff', 'fire', 'fireball', 'resistance'],
    ),

    // Staff of Frost
    MagicItem(
      id: 'item_staff_of_frost',
      name: 'Staff of Frost',
      category: ItemCategory.staff,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      attunementRequirement: 'by a Druid, Sorcerer, Warlock, or Wizard',
      damageAccent: DamageAccent.cold,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.reaction,
          damageType: DamageAccent.cold,
          label: 'Cold Resistance & 10 Charges (Cone of Cold, Fog Cloud, Ice Storm, Wall of Ice)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Grants resistance to cold damage and 10 charges to cast Cone of Cold (5 charges), Fog Cloud (1 charge), Ice Storm (4 charges), and Wall of Ice (4 charges).',
        description: 'You have resistance to cold damage while you hold this staff. Has 10 charges (regains 1d6 + 4 daily at dawn). While holding it, you can cast: Cone of Cold (5 charges), Fog Cloud (1 charge), Ice Storm (4 charges), or Wall of Ice (4 charges).',
        activation: '1 Action',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Resistance to Cold damage; 10 charges for Cone of Cold, Fog Cloud, Ice Storm, and Wall of Ice.',
        description: 'Grants Resistance to Cold damage and 10 charges to cast frost spells with your own Spell Save DC.',
        activation: '1 Action',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: 'Staff save DC scales with personal Spell Save DC in 2024.',
      diffHighlights: [
        '2024: Scaled save DC.',
      ],
      tags: ['staff', 'frost', 'cold', 'cone of cold', 'resistance'],
    ),

    // Staff of Healing
    MagicItem(
      id: 'item_staff_of_healing',
      name: 'Staff of Healing',
      category: ItemCategory.staff,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Bard, Cleric, or Druid',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: '10 Charges: Cure Wounds, Lesser Restoration, Mass Cure Wounds'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 10 charges to cast Cure Wounds (1-4 charges), Lesser Restoration (2 charges), and Mass Cure Wounds (5 charges).',
        description: 'This staff has 10 charges (regains 1d6 + 4 daily at dawn). You can expend charges to cast Cure Wounds (1 charge per spell level, up to 4th), Lesser Restoration (2 charges), or Mass Cure Wounds (5 charges).',
        activation: '1 Action',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '10 charges for Cure Wounds (upgraded 2d8 per level in 2024), Lesser Restoration, and Mass Cure Wounds.',
        description: 'Contains 10 charges to cast restorative spells. Benefits from 2024 Cure Wounds potency (2d8 per slot level).',
        activation: '1 Action',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Cure Wounds cast through this staff heals 2d8 per level under 2024 spell revisions.',
      diffHighlights: [
        '2024: Cure Wounds heals 2d8 + mod (doubled from 1d8 in 2014).',
      ],
      tags: ['staff', 'healing', 'cleric', 'druid', 'bard'],
    ),

    // Staff of the Woodlands
    MagicItem(
      id: 'item_staff_of_the_woodlands',
      name: 'Staff of the Woodlands',
      category: ItemCategory.staff,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Druid',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: '+2 Quarterstaff & +2 to Spell Attacks'),
        ActionTraitRing(ringType: ActionRingType.recharge, label: '10 Charges: Awaken (Tree Summon), Wall of Thorns, Pass Without Trace'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 Quarterstaff, +2 to spell attacks, pass without trace at will, and 10 charges for Awaken, Wall of Thorns, Animal Friendship, etc.',
        description: 'This staff can be wielded as a magic quarterstaff that grants a +2 bonus to attack and damage rolls made with it. While holding it, you gain a +2 bonus to spell attack rolls. Has 10 charges (regains 1d6 + 4 daily at dawn). You can cast Pass Without Trace at will without expending charges. You can expend charges to cast: Animal Friendship (1 charge), Awaken (5 charges, animates a beast/tree companion), Barkskin (2 charges), Locate Animals or Plants (2 charges), Speak with Animals (1 charge), Speak with Plants (3 charges), or Wall of Thorns (6 charges). You can also turn the staff into a 60-foot-tall living tree.',
        activation: '1 Action (Spells / Living Tree)',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 Quarterstaff and +2 to Spell Attacks for Druids; at-will Pass Without Trace, 10 charges (Awaken companion, Wall of Thorns).',
        description: 'Quarterstaff (+2 attack and damage). Grants +2 to spell attack rolls. Cast Pass Without Trace at will. Contains 10 charges for Awaken (creates an Awakened Tree/Beast companion), Wall of Thorns, Barkskin, and transforms into a living tree.',
        activation: '1 Action',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
      ),
      isChangedIn2024: false,
      tags: ['staff', 'druid', 'summon', 'awaken', 'woodlands', 'nature'],
    ),

    // Staff of Charming
    MagicItem(
      id: 'item_staff_of_charming',
      name: 'Staff of Charming',
      category: ItemCategory.staff,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Bard, Cleric, Druid, Sorcerer, Warlock, or Wizard',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '10 Charges: Charm Person, Command, Comprehend Languages; Reaction: Auto-Succeed vs Enchantment Save & Reflect Spell'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 10 charges to cast Charm Person, Command, or Comprehend Languages. When you fail a save against an enchantment spell targeting only you, turn the failure into a success, or expend 1 charge to redirect it to the caster.',
        description: 'While holding this staff, you can cast Charm Person (1 charge), Command (1 charge), or Comprehend Languages (1 charge). If you fail a saving throw against an enchantment spell that targets only you, you can turn your failed save into a successful one. You can also expend 1 charge to reflect the spell back onto the caster.',
        activation: '1 Action / 1 Reaction',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
        savingThrowDc: 'Fixed DC 13',
      ),
      rules2024: ItemEditionDetails(
        summary: '10 charges for Charm Person and Command. Reaction to auto-succeed enchantment saves and reflect spells.',
        description: '10 charges. Cast enchantment spells with scaled save DC. Reaction: turn failed enchantment saves into successes and reflect onto caster.',
        activation: '1 Action / 1 Reaction',
        charges: '10 charges (recharges 1d6 + 4 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 13',
      ),
      isChangedIn2024: true,
      diffSummary: 'Scaled save DC in 2024.',
      diffHighlights: [
        '2024: Scaled save DC.',
      ],
      tags: ['staff', 'charming', 'enchantment', 'reflect', 'spellcaster'],
    ),

    // Staff of Striking
    MagicItem(
      id: 'item_staff_of_striking',
      name: 'Staff of Striking',
      category: ItemCategory.staff,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      damageAccent: DamageAccent.force,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.force, label: '+3 Quarterstaff; Spend 1–3 Charges for +1d6 Force Damage per charge (up to +3d6)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+3 quarterstaff with 10 charges. When you hit with a melee attack using it, you can expend up to 3 charges to deal an extra 1d6 force damage per charge.',
        description: 'This staff can be wielded as a magic quarterstaff that grants a +3 bonus to attack and damage rolls made with it. Has 10 charges (regains 1d6 + 4 daily at dawn). When you hit with a melee attack using it, you can expend up to 3 of its charges. For each charge you expend, the target takes an extra 1d6 force damage.',
        activation: 'Passive / On Hit',
        charges: '10 charges (recharges 1d6 + 4 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 Quarterstaff with 10 charges; expend up to 3 charges on hit for +1d6 Force damage per charge.',
        description: '+3 bonus to attack and damage rolls. On hit, expend 1–3 charges for +1d6 Force damage each (up to +3d6 Force).',
        activation: 'Passive / On Hit',
        charges: '10 charges (recharges 1d6 + 4 on Long Rest)',
        masteryProperties: 'Topple',
      ),
      isChangedIn2024: false,
      tags: ['staff', 'quarterstaff', 'force', 'damage', 'striking'],
    ),

    // Staff of Withering
    MagicItem(
      id: 'item_staff_of_withering',
      name: 'Staff of Withering',
      category: ItemCategory.staff,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Cleric, Druid, or Warlock',
      damageAccent: DamageAccent.necrotic,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.necrotic, label: 'Quarterstaff; Spend 1 Charge on Hit for +2d10 Necrotic (DC 15 CON Save or Disadvantage on STR/CON Checks)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Quarterstaff with 3 charges. When you hit with a melee attack, spend 1 charge: deals +2d10 necrotic damage and forces a DC 15 Con save or disadvantage on Str/Con checks for 1 hour.',
        description: 'This staff has 3 charges (regains 1d3 daily at dawn). When you hit with a melee attack using the staff, you can expend 1 charge to deal an extra 2d10 necrotic damage to the target. In addition, the target must succeed on a DC 15 Constitution saving throw or have disadvantage for 1 hour on any ability check or saving throw that uses Strength or Constitution.',
        activation: 'Passive on Hit',
        charges: '3 charges (recharges 1d3 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: +2d10 Necrotic damage on hit and disadvantage on Str/Con saves on failed DC 15 Con save.',
        description: 'Quarterstaff. Spend 1 charge on hit for +2d10 Necrotic damage and target suffers Disadvantage on Strength and Constitution checks/saves for 1 hour (DC 15 Con save).',
        activation: 'Passive on Hit',
        charges: '3 charges (recharges 1d3 on Long Rest)',
        savingThrowDc: 'Fixed DC 15',
        masteryProperties: 'Topple',
      ),
      isChangedIn2024: false,
      tags: ['staff', 'withering', 'necrotic', 'debuff', 'cleric', 'druid', 'warlock'],
    ),

    // Staff of the Python
    MagicItem(
      id: 'item_staff_of_the_python',
      name: 'Staff of the Python',
      category: ItemCategory.staff,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      attunementRequirement: 'by a Cleric, Druid, or Warlock',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Throw Staff up to 10 ft to Transform into Giant Constrictor Snake'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: throw staff up to 10 feet to transform into a Giant Constrictor Snake that obeys your commands. Bonus action to revert to staff.',
        description: 'You can use an action to speak this staff\'s command word and throw the staff on the ground within 10 feet of you. The staff becomes a Giant Constrictor Snake under your control and acts on its own initiative count. By using a bonus action to speak the command word again, you return the staff to its normal form in a space formerly occupied by the snake. If the snake dies, the staff is destroyed.',
        activation: '1 Action (Transform) / 1 Bonus Action (Revert)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: transform into a friendly Giant Constrictor Snake minion companion.',
        description: 'Throw staff up to 10 feet to animate a Giant Constrictor Snake that obeys verbal commands. Revert as a Bonus Action.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['staff', 'python', 'snake', 'summon', 'companion', 'druid', 'cleric'],
    ),
  ];
}
