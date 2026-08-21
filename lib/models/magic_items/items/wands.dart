import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Magic Wands Catalog
class SrdMagicWands {
  SrdMagicWands._();

  static const List<MagicItem> items = [
    // Wand of Magic Missiles
    MagicItem(
      id: 'item_wand_of_magic_missiles',
      name: 'Wand of Magic Missiles',
      category: ItemCategory.wand,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.force,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.recharge,
          damageType: DamageAccent.force,
          label: '7 Charges: Cast Magic Missile (1–7 Darts, 1d4+1 Force each, Autohit)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges to cast Magic Missile (1 charge per spell level, up to 7th level). Automatically hits.',
        description: 'This wand has 7 charges. While holding it, you can use an action to expend 1 or more of its charges to cast the Magic Missile spell from it. For 1 charge, you cast the 1st-level version of the spell. You can increase the spell slot level by one for each additional charge you expend. The wand regains 1d6 + 1 expended charges daily at dawn. If you expend the wand\'s last charge, roll a d20. On a 1, the wand crumbles into ashes and is destroyed.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges to cast Magic Missile (up to level 7). Regains 1d6+1 charges on Long Rest.',
        description: 'Expend 1–7 charges to cast Magic Missile at the matching level. Automatic hit force darts (1d4+1 each).',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
      ),
      isChangedIn2024: false,
      tags: ['wand', 'magic missile', 'force', 'autohit', 'damage'],
    ),

    // Wand of Fireballs
    MagicItem(
      id: 'item_wand_of_fireballs',
      name: 'Wand of Fireballs',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.recharge,
          damageType: DamageAccent.fire,
          label: '7 Charges: Cast Fireball 8d6+ (3–7 charges, DC 15 Dex Save, 150 ft Range)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges to cast Fireball (3rd level for 3 charges, +1 level per additional charge, save DC 15).',
        description: 'This wand has 7 charges. While holding it, you can use an action to expend 3 or more of its charges to cast the Fireball spell (save DC 15) from it. For 3 charges, you cast the 3rd-level version of the spell. You can increase the spell slot level by one for each additional charge you expend. Regains 1d6 + 1 daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges for Fireball (3+ charges); save DC uses your own Spell Save DC (or DC 15).',
        description: 'Cast Fireball at 3rd level (3 charges) up to 7th level. In 2024, save DC equals your own Spell Save DC or DC 15, whichever is higher.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: 'Spell DC scales with caster\'s personal Spell Save DC in 2024 if higher than 15.',
      diffHighlights: [
        '2024: Scaled save DC.',
      ],
      tags: ['wand', 'fireball', 'fire', 'aoe', 'charges'],
    ),

    // Wand of Lightning Bolts
    MagicItem(
      id: 'item_wand_of_lightning_bolts',
      name: 'Wand of Lightning Bolts',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      damageAccent: DamageAccent.lightning,
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.recharge,
          damageType: DamageAccent.lightning,
          label: '7 Charges: Cast Lightning Bolt 8d6+ (3–7 charges, 100-ft Line)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges to cast Lightning Bolt (3rd level for 3 charges, +1 level per additional charge, save DC 15).',
        description: 'This wand has 7 charges. While holding it, you can use an action to expend 3 or more of its charges to cast the Lightning Bolt spell (save DC 15) from it (100-foot line). Regains 1d6 + 1 daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges for Lightning Bolt (3+ charges) in a 100 ft line. Save DC scales with caster in 2024.',
        description: 'Cast Lightning Bolt in a 100-foot line dealing 8d6+ Lightning damage. Save DC equals your own Spell Save DC or DC 15.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: 'Scaled save DC in 2024.',
      diffHighlights: [
        '2024: Scaled save DC.',
      ],
      tags: ['wand', 'lightning', 'line', 'charges'],
    ),

    // Wand of the War Mage (+1 / +2 / +3)
    MagicItem(
      id: 'item_wand_of_the_war_mage_plus_1',
      name: 'Wand of the War Mage +1',
      category: ItemCategory.wand,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 to Spell Attack Rolls & Ignores Half Cover'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this wand, you gain a +1 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        description: 'While holding this wand, you gain a +1 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 to spell attack rolls; ignore Half Cover with spell attacks.',
        description: 'While holding this wand as an arcane focus, gain +1 to spell attack rolls and ignore Half Cover.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'],
    ),
    MagicItem(
      id: 'item_wand_of_the_war_mage_plus_2',
      name: 'Wand of the War Mage +2',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 to Spell Attack Rolls & Ignores Half Cover'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this wand, you gain a +2 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        description: 'While holding this wand, you gain a +2 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 to spell attack rolls; ignore Half Cover with spell attacks.',
        description: 'While holding this wand as an arcane focus, gain +2 to spell attack rolls and ignore Half Cover.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'],
    ),
    MagicItem(
      id: 'item_wand_of_the_war_mage_plus_3',
      name: 'Wand of the War Mage +3',
      category: ItemCategory.wand,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+3 to Spell Attack Rolls & Ignores Half Cover'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this wand, you gain a +3 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        description: 'While holding this wand, you gain a +3 bonus to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 to spell attack rolls; ignore Half Cover with spell attacks.',
        description: 'While holding this wand as an arcane focus, gain +3 to spell attack rolls and ignore Half Cover.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wand', 'war mage', 'spell attack', 'cover', 'spellcaster'],
    ),

    // Wand of Web
    MagicItem(
      id: 'item_wand_of_web',
      name: 'Wand of Web',
      category: ItemCategory.wand,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '7 Charges: Cast Web (DC 15 Dex Save, 20-ft Cube Restraining Web)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges to cast the Web spell (save DC 15) from it.',
        description: 'This wand has 7 charges. While holding it, you can use an action to expend 1 of its charges to cast the Web spell (save DC 15) from it. Regains 1d6 + 1 daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges to cast Web. Uses your own Spell Save DC (or DC 15).',
        description: 'Cast Web (1 charge) creating a 20-foot cube of sticky, restraining webbing. Save DC scales with caster.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: 'Scaled save DC in 2024.',
      diffHighlights: [
        '2024: Scaled save DC.',
      ],
      tags: ['wand', 'web', 'restrained', 'crowd control'],
    ),

    // Wand of Wonder
    MagicItem(
      id: 'item_wand_of_wonder',
      name: 'Wand of Wonder',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '7 Charges: Roll d100 on Chaotic Spell Effect Table'),
      ],
      rules2014: ItemEditionDetails(
        summary: '7 charges: roll d100 on the chaotic table for random effects (Fireball, Lightning Bolt, Gust of Wind, Stinking Cloud, Invisibility, polymorphing into butterfly, etc.).',
        description: 'This wand has 7 charges. While holding it, you can use an action to expend 1 of its charges and choose a target within 120 feet of you. Roll a d100 and consult the chaotic table for surprising magical phenomena and spells.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges to roll on the Wild Magic Wand table for unexpected, exciting chaotic effects.',
        description: 'Roll d100 on the updated 2024 Wand of Wonder table to trigger sudden Fireballs, Invisibility, Slow, Darkness, and bizarre manifestations.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: 'Modernized d100 table with updated 2024 condition rules and scaled save DCs.',
      diffHighlights: [
        '2024: Updated chaotic d100 table rules.',
      ],
      tags: ['wand', 'wonder', 'wild magic', 'chaotic', 'fun'],
    ),

    // Wand of Polymorph
    MagicItem(
      id: 'item_wand_of_polymorph',
      name: 'Wand of Polymorph',
      category: ItemCategory.wand,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '7 Charges: Cast Polymorph (DC 15 WIS Save, 1 Hour Duration)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges to cast Polymorph (1 charge, save DC 15) transforming target into a beast.',
        description: 'This wand has 7 charges. While holding it, you can use an action to expend 1 of its charges to cast the Polymorph spell (save DC 15) from it. Regains 1d6 + 1 daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges to cast Polymorph (1 charge). In 2024, benefits from updated 2024 Polymorph rules (granting Temporary HP).',
        description: 'Cast Polymorph (1 charge). Under 2024 rules, targets gain Temporary HP equal to the beast form rather than replacing original HP entirely.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: '2024 Polymorph spell grants Temporary HP matching beast form rather than distinct HP pool.',
      diffHighlights: [
        '2024: Polymorph grants Temp HP equal to beast form.',
      ],
      tags: ['wand', 'polymorph', 'transformation', 'beast'],
    ),

    // Wand of Paralysis
    MagicItem(
      id: 'item_wand_of_paralysis',
      name: 'Wand of Paralysis',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '7 Charges: Cast Paralyzing Ray (60 ft, DC 15 CON Save or Paralyzed for 1 Min)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges: shoot a ray at a creature within 60 feet. Target must pass DC 15 Con save or be paralyzed for 1 minute (repeating save at end of its turns).',
        description: 'This wand has 7 charges. While holding it, you can use an action to expend 1 of its charges to shoot a ray of blue light at a creature you can see within 60 feet of you. The target must succeed on a DC 15 Constitution saving throw or be paralyzed for 1 minute. At the end of each of the target\'s turns, it can repeat the save, ending the effect on itself on a success.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges to shoot ray paralyzing target for 1 minute on failed DC 15 Con save.',
        description: 'Action: shoot ray within 60 ft inflicting Paralyzed condition on a failed DC 15 Constitution save.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: 'Scaled save DC in 2024.',
      diffHighlights: [
        '2024: Scaled save DC.',
      ],
      tags: ['wand', 'paralysis', 'crowd control', 'ray'],
    ),

    // Wand of Binding
    MagicItem(
      id: 'item_wand_of_binding',
      name: 'Wand of Binding',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '7 Charges: Hold Person (2 charges), Hold Monster (5 charges) • Reaction (1 charge): Advantage to escape Paralyzed/Restrained'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges. Cast Hold Person (2 charges, save DC 17) or Hold Monster (5 charges, save DC 17). Reaction (1 charge): gain advantage on saving throw to end paralyzed or restrained condition.',
        description: 'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can expend charges to cast Hold Person (2 charges, save DC 17) or Hold Monster (5 charges, save DC 17). Assisted Escape: While holding the wand, you can use your reaction and expend 1 charge to gain advantage on a saving throw you make to avoid or end the paralyzed or restrained condition on yourself.',
        activation: '1 Action (Spells) / 1 Reaction (Escape)',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges for Hold Person, Hold Monster, and Reaction to escape Paralyzed/Restrained conditions with Advantage.',
        description: 'Arcane control wand locking targets in place or freeing the caster from paralyzing entrapment.',
        activation: '1 Action / 1 Reaction',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 17',
      ),
      tags: ['wand', 'binding', 'hold person', 'hold monster', 'paralysis', 'crowd control'],
    ),

    // Wand of Enemy Detection
    MagicItem(
      id: 'item_wand_of_enemy_detection',
      name: 'Wand of Enemy Detection',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '7 Charges: Action (1 charge): Detects Direction & Distance of Nearest Hostile Creature within 60 Feet (1 Min Concentration)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges. Action (1 charge): for 1 minute (concentration), you learn the direction and distance to the closest hostile creature within 60 feet.',
        description: 'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can use an action and expend 1 charge to cause the wand to pulse and point in the direction of the nearest creature hostile to you within 60 feet. For 1 minute, as long as you maintain concentration (as if concentrating on a spell), you learn the creature\'s direction and distance from you. Effect ends early if no hostiles are within 60 feet.',
        activation: '1 Action (1 Min Concentration)',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges: detect and track distance/direction to nearest hostile within 60 ft for 1 minute.',
        description: 'Tactical scouting wand piercing invisibility and darkness to locate enemies.',
        activation: '1 Action (Concentration)',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
      ),
      tags: ['wand', 'enemy detection', 'scouting', 'radar', 'utility'],
    ),

    // Wand of Fear
    MagicItem(
      id: 'item_wand_of_fear',
      name: 'Wand of Fear',
      category: ItemCategory.wand,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '7 Charges: Command "Flee" (1 charge, DC 15) • 60-ft Cone of Fear (2 charges, DC 15 WIS Save, 1 Min)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges. Cast Command ("Flee", 1 charge, save DC 15) or project a 60-foot cone of fear (2 charges: DC 15 Wis save or frightened and drops held items for 1 min).',
        description: 'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can expend 1 charge to cast Command (save DC 15) to force a creature within 60 feet to flee. Alternatively, expend 2 charges to project a 60-foot cone of amber light. Each creature in the cone must succeed on a DC 15 Wisdom save or drop whatever it is holding and become frightened for 1 minute, dashing away on its turns.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges for Command (Flee) and 60-ft Cone of Fear (Frightened condition, drops items, dashes away).',
        description: 'Mind-shattering wand compelling creatures to drop their weapons and flee in terror.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      tags: ['wand', 'fear', 'frightened', 'command', 'flee', 'crowd control'],
    ),

    // Wand of Magic Detection
    MagicItem(
      id: 'item_wand_of_magic_detection',
      name: 'Wand of Magic Detection',
      category: ItemCategory.wand,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '3 Charges: Cast Detect Magic at Will (30-ft Radius Aura Sensing)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'This wand has 3 charges (regains 1d3 daily at dawn). While holding it, you can expend 1 charge to cast Detect Magic.',
        description: 'This wand has 3 charges. While holding it, you can use an action and expend 1 charge to cast the Detect Magic spell from it. The wand regains 1d3 expended charges daily at dawn.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: cast Detect Magic without expending spell slots.',
        description: 'Convenient divination wand detecting magical auras and spell schools within 30 feet.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      tags: ['wand', 'detect magic', 'divination', 'utility'],
    ),

    // Wand of Pyrotechnics
    MagicItem(
      id: 'item_wand_of_pyrotechnics',
      name: 'Wand of Pyrotechnics',
      category: ItemCategory.wand,
      rarity: ItemRarity.uncommon,
      damageAccent: DamageAccent.fire,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.fire, label: '7 Charges: Fireworks (60 ft, DC 15 CON Save or Blinded) or Thick Obscuring Smoke (20-ft Radius Sphere)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges. Cast Pyrotechnics (1 charge, save DC 15) on a nonmagical flame within 60 feet to create blinding fireworks or heavy smoke.',
        description: 'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can use an action and expend 1 charge to cast the Pyrotechnics spell (save DC 15) from it, targeting a nonmagical flame you can see within 60 feet. Choose fireworks (blinded for 1 round on DC 15 Con save) or smoke (20-ft radius heavily obscured area for 1 minute).',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: '7 charges: create blinding fireworks or heavy smoke screen from any flame.',
        description: 'Arcane fire wand creating blinding flashes or tactical obscuring clouds.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 on Long Rest)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      tags: ['wand', 'pyrotechnics', 'fire', 'smoke', 'blindness', 'tactical'],
    ),

    // Wand of Secrets
    MagicItem(
      id: 'item_wand_of_secrets',
      name: 'Wand of Secrets',
      category: ItemCategory.wand,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.recharge, label: '3 Charges: Action (1 charge): Pulses & Points to Nearest Secret Door or Trap within 30 Feet'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'This wand has 3 charges (regains 1d3 daily at dawn). Action: expend 1 charge to detect and point to the nearest secret door or trap within 30 feet.',
        description: 'This wand has 3 charges. While holding it, you can use an action and expend 1 charge to cause the wand to pulse and point in the direction of the nearest secret door or trap within 30 feet of you. The wand regains 1d3 expended charges daily at dawn.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: '3 charges: locate closest hidden door or trap mechanism within 30 feet.',
        description: 'Dungeon delver\'s essential wand revealing secret pathways and deadly mechanisms.',
        activation: '1 Action',
        charges: '3 charges (recharges 1d3 on Long Rest)',
      ),
      tags: ['wand', 'secrets', 'traps', 'doors', 'exploration', 'dungeon'],
    ),
  ];
}
