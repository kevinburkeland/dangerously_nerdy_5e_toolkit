import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Magic Wands Catalog
class SrdMagicWands {
  SrdMagicWands._();

  static const List<EquipmentItem> items = [
    // Wand of Magic Missiles
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_magic_missiles', ruleset: RulesetVersion.v2024), name: 'Wand of Magic Missiles',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: '7 charges to cast Magic Missile (up to level 7). Regains 1d6+1 charges on Long Rest.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges to cast Magic Missile (1 charge per spell level, up to 7th level). Automatically hits.',
        description:
            'This wand has 7 charges. While holding it, you can use an action to expend 1 or more of its charges to cast the Magic Missile spell from it. For 1 charge, you cast the 1st-level version of the spell. You can increase the spell slot level by one for each additional charge you expend. The wand regains 1d6 + 1 expended charges daily at dawn. If you expend the wand\'s last charge, roll a d20. On a 1, the wand crumbles into ashes and is destroyed.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges to cast Magic Missile (up to level 7). Regains 1d6+1 charges on Long Rest.',
        description:
            'Expend 1–7 charges to cast Magic Missile at the matching level. Automatic hit force darts (1d4+1 each).',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
      ),
      isChangedIn2024: false, tags: ['wand', 'magic missile', 'force', 'autohit', 'damage'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'magic missile', 'force', 'autohit', 'damage'] },
    ),

    // Wand of Fireballs
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_fireballs', ruleset: RulesetVersion.v2024), name: 'Wand of Fireballs',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '7 charges for Fireball (3+ charges); save DC uses your own Spell Save DC (or DC 15).',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges to cast Fireball (3rd level for 3 charges, +1 level per additional charge, save DC 15).',
        description:
            'This wand has 7 charges. While holding it, you can use an action to expend 3 or more of its charges to cast the Fireball spell (save DC 15) from it. For 3 charges, you cast the 3rd-level version of the spell. You can increase the spell slot level by one for each additional charge you expend. Regains 1d6 + 1 daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges for Fireball (3+ charges); save DC uses your own Spell Save DC (or DC 15).',
        description:
            'Cast Fireball at 3rd level (3 charges) up to 7th level. In 2024, save DC equals your own Spell Save DC or DC 15, whichever is higher.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true, diffSummary: 'Spell DC scales with caster\'s personal Spell Save DC in 2024 if higher than 15.', diffHighlights: [
        '2024: Scaled save DC.',
      ], tags: ['wand', 'fireball', 'fire', 'aoe', 'charges'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'fireball', 'fire', 'aoe', 'charges'] },
    ),

    // Wand of Lightning Bolts
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_lightning_bolts', ruleset: RulesetVersion.v2024), name: 'Wand of Lightning Bolts',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '7 charges for Lightning Bolt (3+ charges) in a 100 ft line. Save DC scales with caster in 2024.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges to cast Lightning Bolt (3rd level for 3 charges, +1 level per additional charge, save DC 15).',
        description:
            'This wand has 7 charges. While holding it, you can use an action to expend 3 or more of its charges to cast the Lightning Bolt spell (save DC 15) from it (100-foot line). Regains 1d6 + 1 daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges for Lightning Bolt (3+ charges) in a 100 ft line. Save DC scales with caster in 2024.',
        description:
            'Cast Lightning Bolt in a 100-foot line dealing 8d6+ Lightning damage. Save DC equals your own Spell Save DC or DC 15.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true, diffSummary: 'Scaled save DC in 2024.', diffHighlights: [
        '2024: Scaled save DC.',
      ], tags: ['wand', 'lightning', 'line', 'charges'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'lightning', 'line', 'charges'] },
    ),

    // Wand of the War Mage (+1 / +2 / +3)
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_the_war_mage_plus_1', ruleset: RulesetVersion.v2024), name: 'Wand of the War Mage +1',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '+1 to spell attack rolls; ignore Half Cover with spell attacks.',
      rules2014: ItemEditionDetails(
        summary:
            'While holding this wand, you gain a +1 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        description:
            'While holding this wand, you gain a +1 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 to spell attack rolls; ignore Half Cover with spell attacks.',
        description:
            'While holding this wand as an arcane focus, gain +1 to spell attack rolls and ignore Half Cover.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'], 'bonusSpellAttack': 1 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_the_war_mage_plus_2', ruleset: RulesetVersion.v2024), name: 'Wand of the War Mage +2',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '+2 to spell attack rolls; ignore Half Cover with spell attacks.',
      rules2014: ItemEditionDetails(
        summary:
            'While holding this wand, you gain a +2 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        description:
            'While holding this wand, you gain a +2 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+2 to spell attack rolls; ignore Half Cover with spell attacks.',
        description:
            'While holding this wand as an arcane focus, gain +2 to spell attack rolls and ignore Half Cover.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'], 'bonusSpellAttack': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_the_war_mage_plus_3', ruleset: RulesetVersion.v2024), name: 'Wand of the War Mage +3',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '+3 to spell attack rolls; ignore Half Cover with spell attacks.',
      rules2014: ItemEditionDetails(
        summary:
            'While holding this wand, you gain a +3 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        description:
            'While holding this wand, you gain a +3 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+3 to spell attack rolls; ignore Half Cover with spell attacks.',
        description:
            'While holding this wand as an arcane focus, gain +3 to spell attack rolls and ignore Half Cover.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'], 'bonusSpellAttack': 3 },
    ),

    // Wand of Web
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_web', ruleset: RulesetVersion.v2024), name: 'Wand of Web',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '7 charges to cast Web. Uses your own Spell Save DC (or DC 15).',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges to cast the Web spell (save DC 15) from it.',
        description:
            'This wand has 7 charges. While holding it, you can use an action to expend 1 of its charges to cast the Web spell (save DC 15) from it. Regains 1d6 + 1 daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges to cast Web. Uses your own Spell Save DC (or DC 15).',
        description:
            'Cast Web (1 charge) creating a 20-foot cube of sticky, restraining webbing. Save DC scales with caster.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true, diffSummary: 'Scaled save DC in 2024.', diffHighlights: [
        '2024: Scaled save DC.',
      ], tags: ['wand', 'web', 'restrained', 'crowd control'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'web', 'restrained', 'crowd control'] },
    ),

    // Wand of Wonder
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_wonder', ruleset: RulesetVersion.v2024), name: 'Wand of Wonder',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '7 charges to roll on the Wand of Wonder table for unexpected, exciting chaotic effects.',
      rules2014: ItemEditionDetails(
        summary:
            '7 charges: roll d100 on the chaotic table for random effects (Fireball, Lightning Bolt, Gust of Wind, Stinking Cloud, Invisibility, polymorphing into butterfly, etc.).',
        description:
            'This wand has 7 charges. While holding it, you can use an action to expend 1 of its charges and choose a target within 120 feet of you. Roll a d100 and consult the chaotic table for surprising magical phenomena and spells.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges to roll on the Wand of Wonder table for unexpected, exciting chaotic effects.',
        description:
            'Roll d100 on the updated 2024 Wand of Wonder table to trigger sudden Fireballs, Invisibility, Slow, Darkness, and bizarre manifestations.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true, diffSummary: 'Modernized d100 table with updated 2024 condition rules and scaled save DCs.', diffHighlights: [
        '2024: Updated chaotic d100 table rules.',
      ], tags: ['wand', 'wonder', 'chaotic', 'fun'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'wonder', 'chaotic', 'fun'] },
    ),

    // Wand of Polymorph
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_polymorph', ruleset: RulesetVersion.v2024), name: 'Wand of Polymorph',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '7 charges to cast Polymorph (1 charge). In 2024, benefits from updated 2024 Polymorph rules (granting Temporary HP).',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges to cast Polymorph (1 charge, save DC 15) transforming target into a beast.',
        description:
            'This wand has 7 charges. While holding it, you can use an action to expend 1 of its charges to cast the Polymorph spell (save DC 15) from it. Regains 1d6 + 1 daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges to cast Polymorph (1 charge). In 2024, benefits from updated 2024 Polymorph rules (granting Temporary HP).',
        description:
            'Cast Polymorph (1 charge). Under 2024 rules, targets gain Temporary HP equal to the beast form rather than replacing original HP entirely.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true, diffSummary: '2024 Polymorph spell grants Temporary HP matching beast form rather than distinct HP pool.', diffHighlights: [
        '2024: Polymorph grants Temp HP equal to beast form.',
      ], tags: ['wand', 'polymorph', 'transformation', 'beast'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'polymorph', 'transformation', 'beast'] },
    ),

    // Wand of Paralysis
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_paralysis', ruleset: RulesetVersion.v2024), name: 'Wand of Paralysis',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '7 charges to shoot ray paralyzing target for 1 minute on failed DC 15 Con save.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges: shoot a ray at a creature within 60 feet. Target must pass DC 15 Con save or be paralyzed for 1 minute (repeating save at end of its turns).',
        description:
            'This wand has 7 charges. While holding it, you can use an action to expend 1 of its charges to shoot a ray of blue light at a creature you can see within 60 feet of you. The target must succeed on a DC 15 Constitution saving throw or be paralyzed for 1 minute. At the end of each of the target\'s turns, it can repeat the save, ending the effect on itself on a success.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges to shoot ray paralyzing target for 1 minute on failed DC 15 Con save.',
        description:
            'Action: shoot ray within 60 ft inflicting Paralyzed condition on a failed DC 15 Constitution save.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true, diffSummary: 'Scaled save DC in 2024.', diffHighlights: [
        '2024: Scaled save DC.',
      ], tags: ['wand', 'paralysis', 'crowd control', 'ray'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'paralysis', 'crowd control', 'ray'] },
    ),

    // Wand of Binding
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_binding', ruleset: RulesetVersion.v2024), name: 'Wand of Binding',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '7 charges for Hold Person, Hold Monster, and Reaction to escape Paralyzed/Restrained conditions with Advantage.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges. Cast Hold Person (2 charges, save DC 17) or Hold Monster (5 charges, save DC 17). Reaction (1 charge): gain advantage on saving throw to end paralyzed or restrained condition.',
        description:
            'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can expend charges to cast Hold Person (2 charges, save DC 17) or Hold Monster (5 charges, save DC 17). Assisted Escape: While holding the wand, you can use your reaction and expend 1 charge to gain advantage on a saving throw you make to avoid or end the paralyzed or restrained condition on yourself.',
        activation: '1 Action (Spells) / 1 Reaction (Escape)',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges for Hold Person, Hold Monster, and Reaction to escape Paralyzed/Restrained conditions with Advantage.',
        description:
            'Arcane control wand locking targets in place or freeing the caster from paralyzing entrapment.',
        activation: '1 Action / 1 Reaction',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 17',
      ),
      tags: [
        'wand',
        'binding',
        'hold person',
        'hold monster',
        'paralysis',
        'crowd control'
      ],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'binding', 'hold person', 'hold monster', 'paralysis', 'crowd control'] },
    ),

    // Wand of Enemy Detection
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_enemy_detection', ruleset: RulesetVersion.v2024), name: 'Wand of Enemy Detection',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: '7 charges: detect and track distance/direction to nearest hostile within 60 ft for 1 minute.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges. Action (1 charge): for 1 minute (concentration), you learn the direction and distance to the closest hostile creature within 60 feet.',
        description:
            'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can use an action and expend 1 charge to cause the wand to pulse and point in the direction of the nearest creature hostile to you within 60 feet. For 1 minute, as long as you maintain concentration (as if concentrating on a spell), you learn the creature\'s direction and distance from you. Effect ends early if no hostiles are within 60 feet.',
        activation: '1 Action (1 Min Concentration)',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges: detect and track distance/direction to nearest hostile within 60 ft for 1 minute.',
        description:
            'Tactical scouting wand piercing invisibility and darkness to locate enemies.',
        activation: '1 Action (Concentration)',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
      ),
      tags: ['wand', 'enemy detection', 'scouting', 'radar', 'utility'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'enemy detection', 'scouting', 'radar', 'utility'] },
    ),

    // Wand of Fear
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_fear', ruleset: RulesetVersion.v2024), name: 'Wand of Fear',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true, attunementRequirement: 'by a Spellcaster',
      descriptionMarkdown: '7 charges for Command (Flee) and 60-ft Cone of Fear (Frightened condition, drops items, dashes away).',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges. Cast Command ("Flee", 1 charge, save DC 15) or project a 60-foot cone of fear (2 charges: DC 15 Wis save or frightened and drops held items for 1 min).',
        description:
            'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can expend 1 charge to cast Command (save DC 15) to force a creature within 60 feet to flee. Alternatively, expend 2 charges to project a 60-foot cone of amber light. Each creature in the cone must succeed on a DC 15 Wisdom save or drop whatever it is holding and become frightened for 1 minute, dashing away on its turns.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges for Command (Flee) and 60-ft Cone of Fear (Frightened condition, drops items, dashes away).',
        description:
            'Mind-shattering wand compelling creatures to drop their weapons and flee in terror.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      tags: ['wand', 'fear', 'frightened', 'command', 'flee', 'crowd control'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'fear', 'frightened', 'command', 'flee', 'crowd control'] },
    ),

    // Wand of Magic Detection
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_magic_detection', ruleset: RulesetVersion.v2024), name: 'Wand of Magic Detection',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: '3 charges: cast Detect Magic without expending spell slots.',
      rules2014: ItemEditionDetails(
        summary:
            'This wand has 3 charges (regains 1d3 daily at dawn). While holding it, you can expend 1 charge to cast Detect Magic.',
        description:
            'This wand has 3 charges. While holding it, you can use an action and expend 1 charge to cast the Detect Magic spell from it. The wand regains 1d3 expended charges daily at dawn.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: cast Detect Magic without expending spell slots.',
        description:
            'Convenient divination wand detecting magical auras and spell schools within 30 feet.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      tags: ['wand', 'detect magic', 'divination', 'utility'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'detect magic', 'divination', 'utility'] },
    ),

    // Wand of Pyrotechnics
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_pyrotechnics', ruleset: RulesetVersion.v2024), name: 'Wand of Pyrotechnics',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: '7 charges: create blinding fireworks or heavy smoke screen from any flame.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 7 charges. Cast Pyrotechnics (1 charge, save DC 15) on a nonmagical flame within 60 feet to create blinding fireworks or heavy smoke.',
        description:
            'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can use an action and expend 1 charge to cast the Pyrotechnics spell (save DC 15) from it, targeting a nonmagical flame you can see within 60 feet. Choose fireworks (blinded for 1 round on DC 15 Con save) or smoke (20-ft radius heavily obscured area for 1 minute).',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '7 charges: create blinding fireworks or heavy smoke screen from any flame.',
        description:
            'Arcane fire wand creating blinding flashes or tactical obscuring clouds.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      tags: ['wand', 'pyrotechnics', 'fire', 'smoke', 'blindness', 'tactical'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'pyrotechnics', 'fire', 'smoke', 'blindness', 'tactical'] },
    ),

    // Wand of Secrets
    EquipmentItem(
      id: EntityId(slug: 'item_wand_of_secrets', ruleset: RulesetVersion.v2024), name: 'Wand of Secrets',
      itemType: 'wand', category: ItemCategory.wand, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: '3 charges: locate closest hidden door or trap mechanism within 30 feet.',
      rules2014: ItemEditionDetails(
        summary:
            'This wand has 3 charges (regains 1d3 daily at dawn). Action: expend 1 charge to detect and point to the nearest secret door or trap within 30 feet.',
        description:
            'This wand has 3 charges. While holding it, you can use an action and expend 1 charge to cause the wand to pulse and point in the direction of the nearest secret door or trap within 30 feet of you. The wand regains 1d3 expended charges daily at dawn.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '3 charges: locate closest hidden door or trap mechanism within 30 feet.',
        description:
            'Dungeon delver\'s essential wand revealing secret pathways and deadly mechanisms.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      tags: ['wand', 'secrets', 'traps', 'doors', 'exploration', 'dungeon'],
      customProperties: { 'cost': null, 'category': 'wand', 'tags': ['wand', 'secrets', 'traps', 'doors', 'exploration', 'dungeon'] },
    ),
  ];
}
