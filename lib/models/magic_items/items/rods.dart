import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Magic Rods Catalog
class SrdMagicRods {
  SrdMagicRods._();

  static const List<MagicItem> items = [
    // Immovable Rod
    MagicItem(
      id: 'item_immovable_rod',
      name: 'Immovable Rod',
      category: ItemCategory.rod,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: Press Button to Lock in Place (Holds up to 8,000 lbs; DC 30 STR to Move)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: press the button to fix the rod in place in mid-air. It defies gravity and holds up to 8,000 pounds of weight (DC 30 Strength check to move 10 ft).',
        description: 'This flat iron rod has a button on one end. You can use an action to press the button, which causes the rod to become magically fixed in place. Wherever you push the button, the rod remains in place, even if defying gravity. The rod can hold up to 8,000 pounds of weight. More weight causes the rod to deactivate and fall. A creature can use an action to make a DC 30 Strength check, moving the fixed rod up to 10 feet on a success.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: lock in place anywhere in space. Holds up to 8,000 lbs (DC 30 Strength check to move).',
        description: 'Press the button as an Action to fix the rod in its current position in mid-air. Supports up to 8,000 pounds before deactivating.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'immovable', 'utility', 'climbing', 'physics'],
    ),

    // Rod of the Pact Keeper (+1 / +2 / +3)
    MagicItem(
      id: 'item_rod_of_the_pact_keeper_plus_1',
      name: 'Rod of the Pact Keeper +1',
      category: ItemCategory.rod,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      attunementRequirement: 'by a Warlock',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 to Warlock Spell Attack Rolls & Spell Save DC; Action: Regain 1 Warlock Spell Slot (1/Day)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this rod, you gain a +1 bonus to spell attack rolls and to the saving throw DCs of your warlock spells. Regain 1 warlock spell slot as an action once per day.',
        description: 'While holding this rod, you gain a +1 bonus to spell attack rolls and to the saving throw DCs of your warlock spells. In addition, you can regain one warlock spell slot as an action while holding the rod. You can\'t use this property again until you finish a long rest.',
        activation: 'Passive / 1 Action (1/Long Rest)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 to Warlock Spell Attacks and Spell Save DC; Action: regain 1 Warlock spell slot once per Long Rest.',
        description: 'Grants +1 bonus to Warlock spell attack rolls and Spell Save DC. Action: regain 1 expended Warlock spell slot (once per Long Rest).',
        activation: 'Passive / 1 Action (1/Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'warlock', 'spell slot', 'dc bonus', 'spellcaster'],
    ),
    MagicItem(
      id: 'item_rod_of_the_pact_keeper_plus_2',
      name: 'Rod of the Pact Keeper +2',
      category: ItemCategory.rod,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Warlock',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 to Warlock Spell Attack Rolls & Spell Save DC; Action: Regain 1 Warlock Spell Slot (1/Day)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this rod, you gain a +2 bonus to spell attack rolls and to the saving throw DCs of your warlock spells. Regain 1 warlock spell slot once per day.',
        description: 'While holding this rod, you gain a +2 bonus to spell attack rolls and to the saving throw DCs of your warlock spells. In addition, you can regain one warlock spell slot as an action while holding the rod (once per long rest).',
        activation: 'Passive / 1 Action (1/Long Rest)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 to Warlock Spell Attacks and Spell Save DC; Action: regain 1 Warlock spell slot once per Long Rest.',
        description: 'Grants +2 bonus to Warlock spell attack rolls and Spell Save DC. Action: regain 1 expended Warlock spell slot (once per Long Rest).',
        activation: 'Passive / 1 Action (1/Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'warlock', 'spell slot', 'dc bonus', 'spellcaster'],
    ),
    MagicItem(
      id: 'item_rod_of_the_pact_keeper_plus_3',
      name: 'Rod of the Pact Keeper +3',
      category: ItemCategory.rod,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      attunementRequirement: 'by a Warlock',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+3 to Warlock Spell Attack Rolls & Spell Save DC; Action: Regain 1 Warlock Spell Slot (1/Day)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this rod, you gain a +3 bonus to spell attack rolls and to the saving throw DCs of your warlock spells. Regain 1 warlock spell slot once per day.',
        description: 'While holding this rod, you gain a +3 bonus to spell attack rolls and to the saving throw DCs of your warlock spells. In addition, you can regain one warlock spell slot as an action while holding the rod (once per long rest).',
        activation: 'Passive / 1 Action (1/Long Rest)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 to Warlock Spell Attacks and Spell Save DC; Action: regain 1 Warlock spell slot once per Long Rest.',
        description: 'Grants +3 bonus to Warlock spell attack rolls and Spell Save DC. Action: regain 1 expended Warlock spell slot (once per Long Rest).',
        activation: 'Passive / 1 Action (1/Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'warlock', 'spell slot', 'dc bonus', 'spellcaster'],
    ),

    // Rod of Absorption
    MagicItem(
      id: 'item_rod_of_absorption',
      name: 'Rod of Absorption',
      category: ItemCategory.rod,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Reaction: Absorb Incoming Spells (Up to 50 Levels Total) & Convert into Spell Slots'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Reaction: absorb spells targeted only at you, nullifying their effect and storing the spell levels (up to 50 levels max) to convert into free spell slots.',
        description: 'While holding this rod, you can use your reaction to absorb a spell that is targeting only you and not with an area of effect. The absorbed spell\'s effect is canceled, and the spell\'s energy is stored in the rod (1 level per spell level). The rod can absorb a total of 50 levels in its lifetime. If you are a spellcaster, you can convert stored energy into spell slots to cast spells you have prepared without expending slots.',
        activation: '1 Reaction / Free Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Reaction: absorb targeted spells up to 50 levels total in rod\'s lifetime and convert to free spell slots.',
        description: 'Reaction to counter and absorb targeted spells. Stored energy powers your own spell slots without using your personal spell slots.',
        activation: '1 Reaction / Free Action',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'absorption', 'counterspell', 'spell slots', 'spellcaster'],
    ),

    // Rod of Alertness
    MagicItem(
      id: 'item_rod_of_alertness',
      name: 'Rod of Alertness',
      category: ItemCategory.rod,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Advantage on Initiative, Perception & Insight; Cast Detect Evil/Good, Magic, Poison/Disease, See Invisibility; Action: 10-ft Protective Aura'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 mace granting advantage on Initiative and Wisdom checks. Can cast Detect Evil and Good, Detect Magic, Detect Poison and Disease, and See Invisibility. Action: plant rod to create 120-ft aura granting +1 AC and advantage on all saves.',
        description: 'This rod has a flanged head and functions as a magic mace that grants a +1 bonus to attack and damage rolls. While holding it, you have advantage on Wisdom (Insight) and Wisdom (Perception) checks, and on initiative rolls. Spells: Cast Detect Evil and Good, Detect Magic, Detect Poison and Disease, or See Invisibility. Protective Aura: Plant rod into the ground as an action: creates a 60-foot aura granting allies +1 AC and saves, and bright light.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Mace; Advantage on Initiative, Perception, Insight; Divination spells; Action: plant rod for 60 ft +1 AC and Save aura.',
        description: '+1 weapon and divination focus. Advantage on Initiative and Perception. Plant in ground for 10-minute protective aura.',
        activation: 'Passive / 1 Action',
        masteryProperties: 'Sap',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'mace', 'alertness', 'initiative', 'aura', 'divination'],
    ),

    // Rod of Lordly Might
    MagicItem(
      id: 'item_rod_of_lordly_might',
      name: 'Rod of Lordly Might',
      category: ItemCategory.rod,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Transforms into +3 Flail, +3 Spear, or +3 Battleaxe; Climbing Pole, Battering Ram, Drain Life 4d6, DC 17 Fear & Paralyze'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 mace with 6 mechanical transformation buttons (transforms into +3 Flame Tongue Flail, +3 Spear, +3 Battleaxe, 50-ft Climbing Pole, or Battering Ram) and 3 spell powers (Drain 4d6 HP, DC 17 Paralysis, DC 17 Frighten).',
        description: 'This rod has a flanged head and 6 buttons along its shaft. Functions as a +2 magic mace. Button 1: +3 Flame Tongue sword/flail. Button 2: +3 Spear. Button 3: +3 Battleaxe. Button 4: 50-ft climbing pole. Button 5: Door-battering ram (+10 to Strength checks). Button 6: Deconstructs into normal rod. Spell properties: Life Drain (4d6 necrotic), Paralyze (DC 17 Str save for 1 min), Terrify (DC 17 Wis save).',
        activation: 'Bonus Action (Transform) / 1 Action',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Multifunctional +2/+3 weapon; transforms into flail, spear, battleaxe, ladder, or ram. Life drain, paralysis, and fear effects.',
        description: '6 distinct transformation modes and powerful combat effects in a single legendary rod.',
        activation: '1 Bonus Action / 1 Action',
        savingThrowDc: 'Fixed DC 17',
        masteryProperties: 'Vex / Topple / Cleave / Sap',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'weapon', 'transform', 'versatile', 'legendary'],
    ),

    // Rod of Rulership
    MagicItem(
      id: 'item_rod_of_rulership',
      name: 'Rod of Rulership',
      category: ItemCategory.rod,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Charm all creatures within 120 ft for 8 Hours (DC 15 WIS Save; 1/Day)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: speak command word to charm all creatures within 120 feet for 8 hours (DC 15 Wisdom save). Charmed creatures regard you as their trusted leader.',
        description: 'You can use an action to present the rod and command obedience from each creature of your choice that you can see within 120 feet of you. Each target must succeed on a DC 15 Wisdom saving throw or be charmed by you for 8 hours. While charmed in this way, the creature regards you as its trusted leader. If harmed by you or your companions, or commanded to do something contrary to its nature, the charm ends. Recharges daily at dawn.',
        activation: '1 Action (1/Day)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: Charm all chosen creatures in 120 ft for 8 hours on failed DC 15 Wisdom save (1/Long Rest).',
        description: 'Action: command obedience in 120 ft radius. Charmed creatures treat you as trusted leader for up to 8 hours.',
        activation: '1 Action (1/Long Rest)',
        savingThrowDc: 'Fixed DC 15',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'charm', 'command', 'social', 'enchantment'],
    ),
  ];
}
