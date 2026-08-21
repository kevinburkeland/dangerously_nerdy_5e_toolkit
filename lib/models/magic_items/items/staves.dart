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
      damageAccent: DamageAccent.force,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Spell Absorption (Counterspell + Regain Charges)'),
        ActionTraitRing(ringType: ActionRingType.legendary, label: '50 Charges across 7th-Level Spells'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Supreme focus with 50 charges, +2 attack/spell attack, spell absorption reaction, spell saving throw advantage, and at-will cantrips/1st-level spells.',
        description: 'Grants +2 bonus to attack and damage rolls with this quarterstaff, +2 to spell attack rolls, and advantage on saving throws against spells. Has 50 charges (regains 4d6 + 2 daily at dawn). While holding it, you can cast spells with charges (Conjure Elemental, Dispel Magic, Fireball, Flaming Sphere, Ice Storm, Invisibility, Knock, Lightning Bolt, Passwall, Plane Shift, Telekinesis, Wall of Fire, Web) or at will (Arcane Lock, Detect Magic, Enlarge/Reduce, Light, Mage Hand, Protection from Evil and Good). When targeted by a spell that targets only you, you can use your Reaction to absorb the spell\'s energy and cancel it, regaining charges equal to the spell\'s level.',
        activation: '1 Action / 1 Reaction (Absorption)',
        charges: '50 charges (recharges 4d6 + 2 daily at dawn)',
        savingThrowDc: 'Fixed DC 17',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Supreme focus with 50 charges, Spell Absorption, Advantage on saves vs spells; spell DC scales with your own DC.',
        description: 'Grants +2 to weapon attacks and spell attack rolls, Advantage on saving throws against spells, 50 charges with extensive spell list, Spell Absorption reaction, and Retributive Strike. Spells cast through the staff utilize your own Spell Save DC (or DC 17, whichever is higher).',
        activation: '1 Action / 1 Reaction',
        charges: '50 charges (recharges 4d6 + 2 daily at dawn)',
        savingThrowDc: 'Your Spell Save DC or DC 17 (whichever is higher)',
      ),
      isChangedIn2024: true,
      diffSummary: 'Staff spell DCs now scale with your character\'s Spell Save DC.',
      diffHighlights: [
        '2024: Spell save DCs scale with caster\'s own Spell Save DC if higher than DC 17.',
        '2024: Spell Absorption reaction clarified for 2024 single-target spell targeting triggers.',
      ],
      tags: ['staff', 'magi', 'legendary', 'spell absorption', 'wizard'],
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
        ActionTraitRing(ringType: ActionRingType.reaction, damageType: DamageAccent.fire, label: 'Resistance to Fire Damage'),
        ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.fire, label: '10 Charges: Burning Hands, Fireball, Wall of Fire'),
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
  ];
}
