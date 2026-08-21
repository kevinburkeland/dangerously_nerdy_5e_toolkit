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
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Button Locks in Space (Holds up to 8,000 lbs, DC 30 Str)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Press button to fix rod in place; holds up to 8,000 pounds or requires DC 30 Strength check to move 10 ft.',
        description: 'This flat iron rod has a button on one end. You can use an action to press the button, which causes the rod to become magically fixed in place. Does not move even if defying gravity. The rod can hold up to 8,000 pounds of weight. A creature can use an action to make a DC 30 Strength check, moving the fixed rod up to 10 feet on a success.',
        activation: '1 Action (Toggle button)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Action to fix rod in place; holds up to 8,000 lbs or DC 30 Strength check to push 10 ft.',
        description: 'Pressing the button (Action or Object Interaction) locks the rod in space. Supports up to 8,000 pounds of weight without falling. A DC 30 Strength check can move it 10 feet.',
        activation: '1 Action',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'immovable', 'utility'],
    ),

    // Rod of the Pact Keeper
    MagicItem(
      id: 'item_rod_of_the_pact_keeper',
      name: 'Rod of the Pact Keeper',
      category: ItemCategory.rod,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      attunementRequirement: 'by a Warlock',
      damageAccent: DamageAccent.necrotic,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: '+1/+2/+3 to Spell Attack & DC; Regain 1 Warlock Slot'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Grants bonus to warlock spell attack rolls and spell save DCs, and allows the warlock to regain 1 warlock spell slot once per long rest.',
        description: 'While holding this rod, you gain a bonus (+1, +2, or +3) to spell attack rolls and to the saving throw DCs of your warlock spells. In addition, you can regain 1 warlock spell slot as an action while holding the rod. You can\'t use this property again until you finish a long rest.',
        activation: '1 Action (Regain slot)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus to Warlock spell attacks and Save DCs; Action to regain 1 expended Pact Magic slot once per Long Rest.',
        description: 'While holding this rod, you gain a bonus (+1, +2, or +3) to your spell attack rolls and your Warlock Spell Save DC. As an Action, you can regain 1 expended Pact Magic spell slot (once per Long Rest).',
        activation: '1 Action (1/Long Rest)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Explicitly specifies Pact Magic spell slots in 2024.',
      diffHighlights: [
        '2024: Clarified interaction with Pact Magic spell slots and multiclassing.',
      ],
      tags: ['rod', 'warlock', 'pact keeper', 'spell slot'],
    ),

    // Rod of Lordly Might
    MagicItem(
      id: 'item_rod_of_lordly_might',
      name: 'Rod of Lordly Might',
      category: ItemCategory.rod,
      rarity: ItemRarity.legendary,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.melee, label: 'Morphs into Flame Sword, Battleaxe, Spear'),
        ActionTraitRing(ringType: ActionRingType.control, label: 'Paralyze / Drain Life Actions'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Sovereign rod with 6 buttons that transform into magical weapons (+3 flame sword, +3 battleaxe, +3 spear), ladders, battering rams, and drains life/paralyzes.',
        description: 'This rod has a flanged head and the following properties. Buttons 1-3 transform the rod into magical weapons (+3 Flame Tongue blade, +3 Battleaxe, +3 Spear). Button 4 extends a 50-ft climbing pole. Button 5 acts as a battering ram (+10 to break doors). Button 6 extends a ladder. Also features Paralyzing Strike (DC 17 Con) and Life Drain (4d6 necrotic) actions.',
        activation: '1 Bonus Action (Transform) / 1 Action (Spells)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Multi-functional sovereign rod transforming into weapons (+3 sword, axe, spear), utility tools, and necrotic life drain.',
        description: 'Transforms via buttons into a +3 Flame Tongue weapon, +3 Battleaxe, +3 Spear, 50-ft pole, battering ram, or climbing ladder. Includes Drain Life and Paralyzing Strike features.',
        activation: '1 Bonus Action / 1 Action',
      ),
      isChangedIn2024: false,
      tags: ['rod', 'transforming', 'weapons', 'legendary'],
    ),
  ];
}
