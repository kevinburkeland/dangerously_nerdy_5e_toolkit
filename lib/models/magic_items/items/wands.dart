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
          ringType: ActionRingType.ranged,
          damageType: DamageAccent.force,
          label: '7 Charges: Auto-Hit Force Darts (1d4 + 1 each)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges. Use an action to expend charges and cast Magic Missile at 1st level (1 charge) or upcast.',
        description: 'This wand has 7 charges. While holding it, you can use an action to expend 1 or more of its charges to cast the magic missile spell from it. For 1 charge, you cast the 1st-level version of the spell. You can increase the spell slot level by one for each additional charge you expend. Regains 1d6 + 1 charges daily at dawn. If you expend the wand\'s last charge, roll a d20; on a 1, the wand crumbles into ashes.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Contains 7 charges to cast Magic Missile (1st level or upcast) without components.',
        description: 'While holding this wand, you can use an Action to expend 1 or more charges to cast Magic Missile from it (1 charge for level 1, +1 charge per additional level). Regains 1d6 + 1 charges daily at dawn.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
      ),
      isChangedIn2024: false,
      tags: ['wand', 'magic missile', 'force', 'auto hit', 'charges'],
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
          label: '7 Charges: 8d6+ Fireball (DC 15 or Spell DC)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges. Use an action to expend charges and cast Fireball at 3rd level or higher (fixed DC 15).',
        description: 'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can use an action to expend 1 or more of its charges to cast the fireball spell (save DC 15) from it. For 1 charge, you cast the 3rd-level version. You can increase the spell slot level by one for each additional charge you expend.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Fixed DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Contains 7 charges to cast Fireball; spell save DC now scales with your character\'s Spell Save DC.',
        description: 'While holding this wand, you can use an Action to expend charges to cast Fireball (3rd level + 1 level per extra charge). In 2024, the save DC scales with your own Spell Save DC if higher than DC 15.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Your Spell Save DC or DC 15 (whichever is higher)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Save DC scales with your own Spell Save DC in 2024.',
      diffHighlights: [
        '2024: Fireball save DC uses your Spell Save DC if higher than DC 15.',
      ],
      tags: ['wand', 'fireball', 'fire', 'aoe', 'charges'],
    ),

    // Wand of the War Mage
    MagicItem(
      id: 'item_wand_of_the_war_mage',
      name: 'Wand of the War Mage',
      category: ItemCategory.wand,
      rarity: ItemRarity.uncommon,
      requiresAttunement: true,
      attunementRequirement: 'by a Spellcaster',
      actionRings: [
        ActionTraitRing(
          ringType: ActionRingType.ranged,
          label: '+1/+2/+3 to Spell Attack Rolls & Ignore Half Cover',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Gain a bonus (+1, +2, or +3) to spell attack rolls, and your spell attacks ignore half cover.',
        description: 'While holding this wand, you gain a bonus (+1, +2, or +3) to spell attack rolls. In addition, you ignore half cover when making a spell attack.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Gain bonus to spell attack rolls, ignore Half Cover on spell attacks, and acts as an arcane focus.',
        description: 'While holding this wand, you gain a bonus (+1, +2, or +3) to spell attack rolls and your spell attacks ignore Half Cover. Functions as a spellcasting focus for any of your spells.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['wand', 'war mage', 'spell attack', 'cover'],
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
        ActionTraitRing(
          ringType: ActionRingType.control,
          label: '7 Charges: Cast Web (DC 15 Dex)',
        ),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 7 charges. Expend 1 charge as an action to cast the Web spell (DC 15).',
        description: 'This wand has 7 charges (regains 1d6 + 1 daily at dawn). While holding it, you can use an action to expend 1 of its charges to cast the web spell (save DC 15) from it.',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'DC 15',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Contains 7 charges to cast the Web spell (DC 15 or your Spell Save DC).',
        description: 'While holding this wand, you can use an Action to expend 1 charge to cast the Web spell. The save DC is DC 15 or your Spell Save DC (whichever is higher).',
        activation: '1 Action',
        charges: '7 charges (recharges 1d6 + 1 daily at dawn)',
        savingThrowDc: 'Your Spell Save DC or DC 15',
      ),
      isChangedIn2024: true,
      diffSummary: 'Web save DC scales with your own Spell Save DC in 2024.',
      diffHighlights: [
        '2024: Scaled save DC.',
      ],
      tags: ['wand', 'web', 'restrained', 'control'],
    ),
  ];
}
