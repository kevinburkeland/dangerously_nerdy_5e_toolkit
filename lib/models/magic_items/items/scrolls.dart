import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Magic Scrolls Catalog
class SrdMagicScrolls {
  SrdMagicScrolls._();

  static const List<MagicItem> items = [
    // Spell Scroll (Cantrip)
    MagicItem(
      id: 'item_spell_scroll_cantrip',
      name: 'Spell Scroll (Cantrip)',
      category: ItemCategory.scroll,
      rarity: ItemRarity.common,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Cast Inscribed Cantrip (Save DC 13, +5 Attack)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'A spell scroll bears the words of a single spell written in a mystical cipher. Reading the scroll casts the cantrip without components, and the scroll crumbles to dust.',
        description: 'A spell scroll bears the words of a single spell, written in a mystical cipher. If the spell is on your class’s spell list, you can read the scroll and cast its spell without providing any material components. Otherwise, the scroll is unintelligible. Casting the spell by reading the scroll requires the spell\'s normal casting time. Once the spell is cast, the scroll crumbles to dust.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Fixed DC 13 (+5 Attack)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cast inscribed Cantrip. In 2024, anyone with Spellcasting or Pact Magic can use spell scrolls from any class list by succeeding on an Arcana check.',
        description: 'Read the scroll to cast the inscribed Cantrip. Under 2024 rules, characters can attempt to cast scrolls from other class lists via DC 10 + spell level Arcana checks.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Your Spell Save DC or DC 13',
      ),
      isChangedIn2024: true,
      diffSummary: '2024 rules allow cross-class scroll casting with an Arcana check.',
      diffHighlights: [
        '2024: Cross-class scroll casting enabled via Arcana check.',
      ],
      tags: ['scroll', 'cantrip', 'spell scroll', 'consumable'],
    ),

    // Spell Scroll (1st Level)
    MagicItem(
      id: 'item_spell_scroll_level_1',
      name: 'Spell Scroll (1st Level)',
      category: ItemCategory.scroll,
      rarity: ItemRarity.common,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Cast 1st-Level Spell (Save DC 13, +5 Attack)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Cast 1st-level spell without material components. Consumed on use.',
        description: 'A spell scroll bears the words of a 1st-level spell. If the spell is on your class\'s spell list, you can read the scroll and cast it without components (Save DC 13, +5 Attack). The scroll crumbles to dust once cast.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Fixed DC 13 (+5 Attack)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cast 1st-level spell. Cross-class scroll use with Arcana check.',
        description: 'Read scroll to cast 1st-level spell. Save DC equals caster DC or DC 13.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Your Spell Save DC or DC 13',
      ),
      isChangedIn2024: true,
      diffSummary: 'Cross-class scroll rules in 2024.',
      diffHighlights: [
        '2024: Cross-class scroll casting.',
      ],
      tags: ['scroll', '1st level', 'spell scroll', 'consumable'],
    ),

    // Spell Scroll (2nd Level)
    MagicItem(
      id: 'item_spell_scroll_level_2',
      name: 'Spell Scroll (2nd Level)',
      category: ItemCategory.scroll,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Cast 2nd-Level Spell (Save DC 13, +5 Attack)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Cast 2nd-level spell without material components (Save DC 13, +5 Attack). Consumed on use.',
        description: 'A spell scroll bearing a 2nd-level spell. If the spell is of a higher level than you can normally cast, make an ability check with your spellcasting ability (DC 12) to cast successfully.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Fixed DC 13 (+5 Attack)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cast 2nd-level spell. Save DC uses your DC or DC 13.',
        description: 'Read scroll to cast 2nd-level spell. DC 12 check if higher level than you normally cast.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Your Spell Save DC or DC 13',
      ),
      isChangedIn2024: true,
      diffSummary: '2024 cross-class scroll mechanics.',
      diffHighlights: [
        '2024: Cross-class scroll casting.',
      ],
      tags: ['scroll', '2nd level', 'spell scroll', 'consumable'],
    ),

    // Spell Scroll (3rd Level)
    MagicItem(
      id: 'item_spell_scroll_level_3',
      name: 'Spell Scroll (3rd Level)',
      category: ItemCategory.scroll,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Cast 3rd-Level Spell (Save DC 15, +7 Attack)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Cast 3rd-level spell without material components (Save DC 15, +7 Attack). Consumed on use.',
        description: 'A spell scroll bearing a 3rd-level spell (such as Fireball, Counterspell, or Revivify). Ability check DC 13 if above your spell slot level.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Fixed DC 15 (+7 Attack)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cast 3rd-level spell. Save DC uses your DC or DC 15.',
        description: 'Cast inscribed 3rd-level spell. Save DC equals caster DC or DC 15.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: '2024 cross-class scroll mechanics.',
      diffHighlights: [
        '2024: Cross-class scroll casting.',
      ],
      tags: ['scroll', '3rd level', 'spell scroll', 'consumable'],
    ),

    // Spell Scroll (4th Level)
    MagicItem(
      id: 'item_spell_scroll_level_4',
      name: 'Spell Scroll (4th Level)',
      category: ItemCategory.scroll,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Cast 4th-Level Spell (Save DC 15, +7 Attack)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Cast 4th-level spell without material components (Save DC 15, +7 Attack). Ability check DC 14 if above your spell slot level.',
        description: 'A spell scroll bearing a 4th-level spell (such as Dimension Door, Polymorph, or Greater Invisibility).',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Fixed DC 15 (+7 Attack)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cast 4th-level spell. Save DC uses your DC or DC 15.',
        description: 'Read scroll to cast 4th-level spell.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: '2024 cross-class scroll mechanics.',
      diffHighlights: [
        '2024: Cross-class scroll casting.',
      ],
      tags: ['scroll', '4th level', 'spell scroll', 'consumable'],
    ),

    // Spell Scroll (5th Level)
    MagicItem(
      id: 'item_spell_scroll_level_5',
      name: 'Spell Scroll (5th Level)',
      category: ItemCategory.scroll,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: 'Action: Cast 5th-Level Spell (Save DC 17, +9 Attack)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Cast 5th-level spell without material components (Save DC 17, +9 Attack). Ability check DC 15 if above your spell slot level.',
        description: 'A spell scroll bearing a 5th-level spell (such as Cone of Cold, Wall of Force, or Greater Restoration).',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Fixed DC 17 (+9 Attack)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cast 5th-level spell. Save DC uses your DC or DC 17.',
        description: 'Read scroll to cast 5th-level spell.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Your Spell Save DC or DC 17',
      ),
      isChangedIn2024: true,
      diffSummary: '2024 cross-class scroll mechanics.',
      diffHighlights: [
        '2024: Cross-class scroll casting.',
      ],
      tags: ['scroll', '5th level', 'spell scroll', 'consumable'],
    ),

    // Spell Scroll (9th Level)
    MagicItem(
      id: 'item_spell_scroll_level_9',
      name: 'Spell Scroll (9th Level)',
      category: ItemCategory.scroll,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.legendary, label: 'Action: Cast 9th-Level Spell (Save DC 19, +11 Attack; Wish, Meteor Swarm, True Polymorph)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Cast world-altering 9th-level spell without material components (Save DC 19, +11 Attack). Ability check DC 19 if below 9th level casting.',
        description: 'A legendary parchment bearing a 9th-level spell (Wish, Meteor Swarm, True Polymorph, Power Word Kill). If the spell is above your level, make a DC 19 spellcasting ability check. On a failure, the scroll is lost with no effect.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Fixed DC 19 (+11 Attack)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cast 9th-level spell. Consumed upon casting.',
        description: 'Cast 9th-level spell. DC 19 check if beyond current spell tier. Consumed when read.',
        activation: 'Matches Spell Casting Time',
        savingThrowDc: 'Your Spell Save DC or DC 19',
      ),
      isChangedIn2024: true,
      diffSummary: '2024 cross-class scroll mechanics.',
      diffHighlights: [
        '2024: Cross-class scroll casting.',
      ],
      tags: ['scroll', '9th level', 'legendary', 'wish', 'meteor swarm', 'consumable'],
    ),

    // Scroll of Protection
    MagicItem(
      id: 'item_scroll_of_protection',
      name: 'Scroll of Protection',
      category: ItemCategory.scroll,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Action: 5-ft Radius Ward vs Chosen Creature Type for 5 Minutes'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action: creates a 5-foot-radius barrier protecting against Aberrations, Beasts, Celestials, Elementals, Fey, Fiends, Plants, or Undead for 5 minutes.',
        description: 'Using an action to read the scroll creates a 5-foot-radius barrier of magical energy extending from you. For 5 minutes, creatures of the specified type (Aberrations, Beasts, Celestials, Elementals, Fey, Fiends, Plants, or Undead) can\'t enter or willingly reach into the barrier, and targets within the barrier cannot be charmed, frightened, or possessed by them. Barrier moves with you.',
        activation: '1 Action (5 Min Duration)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action: 5-ft mobile ward barring chosen creature type and granting immunity to Charmed/Frightened/Possessed for 5 minutes.',
        description: 'Read as an Action to create a 5-foot protective aura centered on you that prevents designated creature types from entering or attacking inside for 5 minutes.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['scroll', 'protection', 'ward', 'barrier', 'fiend', 'undead', 'aberration'],
    ),
  ];
}
