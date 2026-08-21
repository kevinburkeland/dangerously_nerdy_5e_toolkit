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
      tags: ['ring', 'spellcasting', 'storage'],
    ),

    // Ring of Three Wishes
    MagicItem(
      id: 'item_ring_of_three_wishes',
      name: 'Ring of Three Wishes',
      category: ItemCategory.ring,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.legendary, label: '3 Charges: Cast Wish'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Contains 3 charges. While wearing it, you can use an action to expend 1 charge and cast the Wish spell.',
        description: 'While wearing this ring, you can use an action to expend 1 of its 3 charges to cast the wish spell from it. The ring loses this property if it has no charges remaining.',
        activation: '1 Action',
        charges: '3 charges (non-rechargeable)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Expend 1 of 3 charges to cast the Wish spell.',
        description: 'While wearing this ring, you can use an Action to expend 1 of its 3 charges to cast the Wish spell. When the last charge is expended, the ring becomes a nonmagical ring.',
        activation: '1 Action',
        charges: '3 charges (non-rechargeable)',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'wish', 'legendary', 'charges'],
    ),

    // Ring of Evasion
    MagicItem(
      id: 'item_ring_of_evasion',
      name: 'Ring of Evasion',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '3 Charges: Succeed on Failed Dex Save'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Has 3 charges. When you fail a Dex saving throw, you can use your reaction to expend 1 charge and succeed instead.',
        description: 'This ring has 3 charges, and it regains 1d3 expended charges daily at dawn. When you fail a Dexterity saving throw while wearing it, you can use your reaction to expend 1 of its charges to succeed on that saving throw instead.',
        activation: '1 Reaction',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Reaction: expend 1 charge to succeed on a failed Dexterity saving throw (3 charges).',
        description: 'Has 3 charges and regains 1d3 charges daily at dawn. When you fail a Dexterity saving throw, you can use a Reaction to expend 1 charge and succeed on the save instead.',
        activation: '1 Reaction',
        charges: '3 charges (recharges 1d3 daily at dawn)',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'evasion', 'dexterity', 'saving throws'],
    ),

    // Ring of Free Action
    MagicItem(
      id: 'item_ring_of_free_action',
      name: 'Ring of Free Action',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Immune to Paralyzed, Restrained & Difficult Terrain'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Difficult terrain costs no extra movement, and magic can\'t reduce your speed or cause you to be paralyzed or restrained.',
        description: 'While you wear this ring, difficult terrain doesn\'t cost you extra movement. In addition, magic can neither reduce your speed nor cause you to be paralyzed or restrained.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Difficult terrain costs no extra movement; magic cannot reduce speed or cause Paralyzed/Restrained conditions.',
        description: 'While wearing this ring, Difficult Terrain costs no extra movement, and spells/magical effects cannot reduce your speed or inflict the Paralyzed or Restrained conditions upon you.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'movement', 'immunity', 'paralyzed', 'restrained'],
    ),

    // Ring of Resistance
    MagicItem(
      id: 'item_ring_of_resistance',
      name: 'Ring of Resistance',
      category: ItemCategory.ring,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Resistance to Chosen Damage Type'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have resistance to one damage type (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, or Thunder).',
        description: 'You have resistance to one damage type while wearing this ring. The gem in the ring indicates the type (e.g. ruby for fire, sapphire for cold, diamond for radiant).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants Resistance to one chosen damage type.',
        description: 'You have Resistance to one damage type (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, or Thunder) while wearing this ring.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['ring', 'resistance', 'elemental'],
    ),
  ];
}
