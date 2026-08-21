import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Magic Scrolls Catalog
class SrdMagicScrolls {
  SrdMagicScrolls._();

  static const List<MagicItem> items = [
    // Spell Scroll (General)
    MagicItem(
      id: 'item_spell_scroll',
      name: 'Spell Scroll',
      category: ItemCategory.scroll,
      rarity: ItemRarity.common,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Single-Use Arcane Formula'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Bears the words of a single spell. Must be on your class\'s spell list to read and cast.',
        description: 'A spell scroll bears the words of a single spell, written in a mystical cipher. If the spell is on your class\'s spell list, you can read the scroll and cast its spell without providing any material components. If the spell is of a higher level than you can normally cast, you must make an ability check with your spellcasting ability to cast it (DC 10 + spell level). On a failed check, the spell fails and the scroll is destroyed.',
        activation: 'Matches spell casting time',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Any spellcaster can attempt to cast a spell from a Spell Scroll (using Arcana check if not on class list).',
        description: 'A Spell Scroll bears the incantation of a single spell. If the spell is on your spell list, you can cast it without material components. If it is NOT on your class list, you can make an Intelligence (Arcana) check (DC 10 + spell level) to read and cast it. Casting time matches the spell\'s standard casting time (e.g. Action, Bonus Action, or Reaction).',
        activation: 'Matches spell casting time',
      ),
      isChangedIn2024: true,
      diffSummary: 'In 2024, spellcasters can attempt scrolls outside their class list with Arcana check.',
      diffHighlights: [
        '2024: Any spellcaster can attempt to use scrolls outside their class list via an Intelligence (Arcana) check.',
        '2024: Casting time matches the specific spell\'s casting time (including Bonus Action and Reaction spells).',
      ],
      tags: ['scroll', 'spell', 'consumable', 'single use'],
    ),

    // Scroll of Protection
    MagicItem(
      id: 'item_scroll_of_protection',
      name: 'Scroll of Protection',
      category: ItemCategory.scroll,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: '5-Minute 10-ft Anti-Creature Barrier'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Action to read; creates a 5-minute 10-foot radius barrier that wards against a specific creature type.',
        description: 'Using an action to read the scroll creates an invisible 10-foot-radius, 10-foot-high cylinder of magical protection around you. Protects against a specific creature type (aberrations, beasts, celestials, elementals, fey, fiends, plants, or undead) for 5 minutes. Prevented creatures can\'t enter or charm/frighten/possess creatures inside.',
        activation: '1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Creates a 10-foot Emanation for 5 minutes that wards against a designated creature type.',
        description: 'Action to activate: creates a 10-foot Emanation that moves with you for 5 minutes. The designated creature type cannot enter the area, attack targets inside with melee attacks, or inflict Charmed/Frightened conditions on targets within.',
        activation: '1 Action',
      ),
      isChangedIn2024: true,
      diffSummary: 'Barrier formalized as a moving 10-foot Emanation in 2024.',
      diffHighlights: [
        '2024: Uses the 2024 Emanation keyword.',
      ],
      tags: ['scroll', 'protection', 'ward', 'barrier'],
    ),

    // Scroll of Resurrection
    MagicItem(
      id: 'item_scroll_of_resurrection',
      name: 'Scroll of Resurrection',
      category: ItemCategory.scroll,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Restore Dead Creature to Life (1 Hour Casting)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Touches a dead creature and restores it to life with all its hit points, closing wounds and neutralizing poisons.',
        description: 'You touch a dead creature that has been dead for no more than a century and didn\'t die of old age. If its soul is free and willing, the creature is restored to life with all its hit points.',
        activation: '1 Hour',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bears the 7th-level Resurrection spell; restores a creature dead up to 100 years to full HP.',
        description: 'Restores a dead creature (dead for <=100 years, not from old age) to life with full Hit Points, neutralizing nonmagical poisons and closing mortal wounds.',
        activation: '1 Hour',
      ),
      isChangedIn2024: false,
      tags: ['scroll', 'resurrection', 'healing', 'revival'],
    ),
  ];
}
