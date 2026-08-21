import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Armor & Shields Catalog
/// Includes standard nonmagical suits, specific named magic armor/shield tiers, and legendary relics.
class SrdArmorAndShields {
  SrdArmorAndShields._();

  static const List<MagicItem> items = [
    // =========================================================================
    // 1. STANDARD NONMAGICAL ARMOR & SHIELDS
    // =========================================================================
    MagicItem(
      id: 'armor_plate',
      name: 'Plate Armor (Full Plate)',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 18 (Heavy Armor; Str 15 required)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 18. Heavy armor composed of shaped, interlocking metal plates covering the entire body. Requires Str 15 and imposes Disadvantage on Stealth.',
        description: 'Plate consists of shaped, interlocking metal plates to cover the entire body. A suit of plate includes gauntlets, heavy leather boots, a visored helmet, and thick layers of padding underneath the armor. Buckles and straps distribute the weight over the body.',
        properties: [
          'Armor Class: 18 (no Dex modifier added).',
          'Strength Requirement: Str 15.',
          'Stealth: Disadvantage.',
          'Weight: 65 lbs.',
          'Cost: 1,500 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 18. Heavy armor providing peak nonmagical protection. Requires Str 15 and imposes Disadvantage on Stealth checks.',
        description: 'Plate consists of shaped, interlocking metal plates covering the entire body with underlying arming doublet and gauntlets.',
        properties: [
          'Armor Class: 18.',
          'Strength: 15.',
          'Stealth: Disadvantage.',
          'Weight: 65 lbs.',
          'Cost: 1,500 gp.',
        ],
      ),
      tags: ['armor', 'heavy', 'plate', 'nonmagical', 'ac 18'],
    ),
    MagicItem(
      id: 'armor_half_plate',
      name: 'Half Plate Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 15 + Dex Mod (max 2)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 15 + Dex modifier (max 2). Medium armor covering vital areas with shaped metal plates. Imposes Disadvantage on Stealth.',
        description: 'Half plate consists of shaped metal plates that cover most of the wearer\'s body. It does not include leg protection beyond simple greaves attached with leather straps.',
        properties: [
          'Armor Class: 15 + Dex modifier (max 2).',
          'Stealth: Disadvantage.',
          'Weight: 40 lbs.',
          'Cost: 750 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 15 + Dex modifier (max 2). Medium armor with Stealth Disadvantage.',
        description: 'Half plate provides superior medium armor defense with shaped steel breastplate, pauldrons, and greaves.',
        properties: [
          'Armor Class: 15 + Dex modifier (max 2).',
          'Stealth: Disadvantage.',
          'Weight: 40 lbs.',
          'Cost: 750 gp.',
        ],
      ),
      tags: ['armor', 'medium', 'half plate', 'nonmagical'],
    ),
    MagicItem(
      id: 'armor_breastplate',
      name: 'Breastplate',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 14 + Dex Mod (max 2; No Stealth Penalty)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 14 + Dex modifier (max 2). Medium armor consisting of a fitted metal chest piece worn with supple leather. Imposes NO penalty on Stealth.',
        description: 'This armor consists of a fitted metal chest piece worn with supple leather. Although it leaves the legs and arms relatively unprotected, this armor provides good protection for the wearer\'s vital organs while leaving the wearer relatively unencumbered.',
        properties: [
          'Armor Class: 14 + Dex modifier (max 2).',
          'Stealth: Normal (No Disadvantage).',
          'Weight: 20 lbs.',
          'Cost: 400 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 14 + Dex modifier (max 2). Medium armor with no Stealth disadvantage.',
        description: 'Fitted steel chest piece leaving limbs unencumbered.',
        properties: [
          'Armor Class: 14 + Dex modifier (max 2).',
          'Stealth: Normal.',
          'Weight: 20 lbs.',
          'Cost: 400 gp.',
        ],
      ),
      tags: ['armor', 'medium', 'breastplate', 'nonmagical', 'stealth friendly'],
    ),
    MagicItem(
      id: 'armor_splint',
      name: 'Splint Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 17 (Heavy Armor; Str 15 required)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 17. Heavy armor made of narrow vertical strips of metal riveted to a backing of leather. Requires Str 15 and imposes Disadvantage on Stealth.',
        description: 'This armor is made of narrow vertical strips of metal riveted to a backing of leather that is worn over cloth padding. Flexible chain mail protects the joints.',
        properties: [
          'Armor Class: 17.',
          'Strength: 15.',
          'Stealth: Disadvantage.',
          'Weight: 60 lbs.',
          'Cost: 200 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 17. Heavy armor made of vertical metal splints on leather backing.',
        description: 'Heavy armor offering robust defense for frontline martial combatants.',
        properties: [
          'Armor Class: 17.',
          'Strength: 15.',
          'Stealth: Disadvantage.',
          'Weight: 60 lbs.',
          'Cost: 200 gp.',
        ],
      ),
      tags: ['armor', 'heavy', 'splint', 'nonmagical'],
    ),
    MagicItem(
      id: 'armor_chain_mail',
      name: 'Chain Mail',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 16 (Heavy Armor; Str 13 required)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 16. Heavy armor made of interlocking metal rings worn over a layer of quilted fabric. Requires Str 13 and imposes Disadvantage on Stealth.',
        description: 'Made of interlocking metal rings, chain mail includes a layer of quilted fabric worn underneath the mail to prevent chafing and to cushion the impact of blows. The suit includes gauntlets.',
        properties: [
          'Armor Class: 16.',
          'Strength: 13.',
          'Stealth: Disadvantage.',
          'Weight: 55 lbs.',
          'Cost: 75 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 16. Classic heavy armor made of interlocking steel rings.',
        description: 'Standard knightly chain mail protecting torso and limbs.',
        properties: [
          'Armor Class: 16.',
          'Strength: 13.',
          'Stealth: Disadvantage.',
          'Weight: 55 lbs.',
          'Cost: 75 gp.',
        ],
      ),
      tags: ['armor', 'heavy', 'chain mail', 'nonmagical'],
    ),
    MagicItem(
      id: 'armor_scale_mail',
      name: 'Scale Mail',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 14 + Dex Mod (max 2; Stealth Disadvantage)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 14 + Dex modifier (max 2). Medium armor consisting of a coat and leggings of leather covered with overlapping pieces of metal.',
        description: 'This armor consists of a coat and leggings (and perhaps a separate skirt) of leather covered with overlapping pieces of metal, much like the scales of a fish. The suit includes gauntlets.',
        properties: [
          'Armor Class: 14 + Dex modifier (max 2).',
          'Stealth: Disadvantage.',
          'Weight: 45 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 14 + Dex modifier (max 2). Overlapping metal scales on leather.',
        description: 'Medium armor of overlapping metal scales.',
        properties: [
          'Armor Class: 14 + Dex modifier (max 2).',
          'Stealth: Disadvantage.',
          'Weight: 45 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['armor', 'medium', 'scale mail', 'nonmagical'],
    ),
    MagicItem(
      id: 'armor_chain_shirt',
      name: 'Chain Shirt',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 13 + Dex Mod (max 2; No Stealth Penalty)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 13 + Dex modifier (max 2). Medium armor made of interlocking metal rings worn between layers of clothing or leather.',
        description: 'Made of interlocking metal rings, a chain shirt is worn between layers of clothing or leather. This armor offers modest protection to the wearer\'s upper body and allows the sound of the rings rubbing together to be muffled by outer garments.',
        properties: [
          'Armor Class: 13 + Dex modifier (max 2).',
          'Stealth: Normal.',
          'Weight: 20 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 13 + Dex modifier (max 2). Medium armor with no Stealth disadvantage.',
        description: 'Interlocking metal ring shirt worn under tunics or leathers.',
        properties: [
          'Armor Class: 13 + Dex modifier (max 2).',
          'Stealth: Normal.',
          'Weight: 20 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['armor', 'medium', 'chain shirt', 'nonmagical'],
    ),
    MagicItem(
      id: 'armor_studded_leather',
      name: 'Studded Leather Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 12 + Full Dex Mod (No Stealth Penalty)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 12 + Dex modifier. Light armor made of tough but flexible leather reinforced with close-set rivets or spikes.',
        description: 'Made from tough but flexible leather, studded leather is reinforced with close-set rivets or spikes.',
        properties: [
          'Armor Class: 12 + Dex modifier (full).',
          'Stealth: Normal.',
          'Weight: 13 lbs.',
          'Cost: 45 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 12 + Dex modifier. Premier light armor reinforced with steel rivets.',
        description: 'Flexible boiled leather reinforced with close-set rivets.',
        properties: [
          'Armor Class: 12 + Dex modifier.',
          'Stealth: Normal.',
          'Weight: 13 lbs.',
          'Cost: 45 gp.',
        ],
      ),
      tags: ['armor', 'light', 'studded leather', 'nonmagical'],
    ),
    MagicItem(
      id: 'armor_leather',
      name: 'Leather Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Base AC 11 + Full Dex Mod'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'AC 11 + Dex modifier. Light armor made of boiled and cured leather.',
        description: 'The breastplate and shoulder protectors of this armor are made of leather that has been stiffened by being boiled in oil. The rest of the armor is made of softer and more flexible materials.',
        properties: [
          'Armor Class: 11 + Dex modifier.',
          'Stealth: Normal.',
          'Weight: 10 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 11 + Dex modifier. Standard boiled leather suit.',
        description: 'Lightweight cured leather armor.',
        properties: [
          'Armor Class: 11 + Dex modifier.',
          'Stealth: Normal.',
          'Weight: 10 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['armor', 'light', 'leather', 'nonmagical'],
    ),
    MagicItem(
      id: 'armor_shield_standard',
      name: 'Shield',
      category: ItemCategory.armor,
      rarity: ItemRarity.nonmagical,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 AC (Requires 1 Free Hand)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus to AC. Made from wood or metal and carried in one hand. You can benefit from only one shield at a time.',
        description: 'A shield is made from wood or metal and is carried in one hand. Wielding a shield increases your Armor Class by 2. You can benefit from only one shield at a time.',
        properties: [
          'Armor Class: +2 bonus.',
          'Requires: 1 hand.',
          'Weight: 6 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC while held in one hand.',
        description: 'A shield held in one hand provides a +2 bonus to Armor Class.',
        properties: [
          'Armor Class: +2 bonus.',
          'Weight: 6 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['shield', 'defense', 'ac', 'nonmagical'],
    ),

    // =========================================================================
    // 2. SPECIFIC MAGIC ARMOR VARIANTS (+1, +2, +3)
    // =========================================================================
    MagicItem(
      id: 'plate_plus_1',
      name: 'Plate Armor +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 19 (18 Base + 1 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +1 bonus to AC while wearing this suit of magic plate armor (Total AC 19).',
        description: 'You have a +1 bonus to AC while wearing this suit of magic plate armor (Total AC 19). Requires Str 15 and imposes Disadvantage on Stealth.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Total AC 19. +1 magical defense bonus applied to full plate armor.',
        description: 'You have a +1 bonus to AC while wearing this magic plate armor (Total AC 19).',
        activation: 'Passive',
      ),
      tags: ['armor', 'heavy', 'plate', 'magic', 'ac 19'],
    ),
    MagicItem(
      id: 'plate_plus_2',
      name: 'Plate Armor +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 20 (18 Base + 2 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +2 bonus to AC while wearing this suit of magic plate armor (Total AC 20).',
        description: 'Masterwork enchanted full plate granting a +2 bonus to Armor Class (Total AC 20).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Total AC 20. +2 magical defense bonus applied to full plate armor.',
        description: 'Masterwork enchanted full plate granting a +2 bonus to Armor Class (Total AC 20).',
        activation: 'Passive',
      ),
      tags: ['armor', 'heavy', 'plate', 'magic', 'ac 20'],
    ),
    MagicItem(
      id: 'plate_plus_3',
      name: 'Plate Armor +3',
      category: ItemCategory.armor,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 21 (18 Base + 3 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +3 bonus to AC while wearing this suit of magic plate armor (Total AC 21).',
        description: 'Legendary suit of impenetrable full plate offering a +3 bonus to Armor Class (Total AC 21).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Total AC 21. Legendary +3 enchanted full plate armor.',
        description: 'Legendary suit of impenetrable full plate offering a +3 bonus to Armor Class (Total AC 21).',
        activation: 'Passive',
      ),
      tags: ['armor', 'heavy', 'plate', 'magic', 'legendary', 'ac 21'],
    ),

    MagicItem(
      id: 'half_plate_plus_1',
      name: 'Half Plate +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 16 + Dex Mod (max 2)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to AC (16 + Dex mod max 2) while wearing this magic half plate armor.',
        description: '+1 bonus to AC while wearing this magic half plate armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC (16 + Dex mod max 2) while wearing this magic half plate armor.',
        description: '+1 bonus to AC while wearing this magic half plate armor.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'half plate', 'magic'],
    ),
    MagicItem(
      id: 'half_plate_plus_2',
      name: 'Half Plate +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 17 + Dex Mod (max 2)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus to AC (17 + Dex mod max 2) while wearing this magic half plate armor.',
        description: '+2 bonus to AC while wearing this magic half plate armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC (17 + Dex mod max 2) while wearing this magic half plate armor.',
        description: '+2 bonus to AC while wearing this magic half plate armor.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'half plate', 'magic'],
    ),

    MagicItem(
      id: 'breastplate_plus_1',
      name: 'Breastplate +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 15 + Dex Mod (max 2; No Stealth Penalty)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to AC (15 + Dex mod max 2) with no Stealth disadvantage while wearing this magic breastplate.',
        description: '+1 bonus to AC with no Stealth disadvantage while wearing this magic breastplate.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC (15 + Dex mod max 2) with no Stealth disadvantage.',
        description: '+1 bonus to AC with no Stealth disadvantage.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'breastplate', 'magic', 'stealth friendly'],
    ),
    MagicItem(
      id: 'breastplate_plus_2',
      name: 'Breastplate +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 16 + Dex Mod (max 2; No Stealth Penalty)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus to AC (16 + Dex mod max 2) with no Stealth disadvantage while wearing this magic breastplate.',
        description: '+2 bonus to AC with no Stealth disadvantage while wearing this magic breastplate.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC (16 + Dex mod max 2) with no Stealth disadvantage.',
        description: '+2 bonus to AC with no Stealth disadvantage.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'breastplate', 'magic', 'stealth friendly'],
    ),

    MagicItem(
      id: 'studded_leather_plus_1',
      name: 'Studded Leather +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 13 + Full Dex Mod'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to AC (13 + Dex modifier) while wearing this magic studded leather armor.',
        description: '+1 bonus to AC while wearing this magic studded leather armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC (13 + Dex modifier) while wearing this magic studded leather armor.',
        description: '+1 bonus to AC while wearing this magic studded leather armor.',
        activation: 'Passive',
      ),
      tags: ['armor', 'light', 'studded leather', 'magic'],
    ),
    MagicItem(
      id: 'studded_leather_plus_2',
      name: 'Studded Leather +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 14 + Full Dex Mod'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 bonus to AC (14 + Dex modifier) while wearing this magic studded leather armor.',
        description: '+2 bonus to AC while wearing this magic studded leather armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC (14 + Dex modifier) while wearing this magic studded leather armor.',
        description: '+2 bonus to AC while wearing this magic studded leather armor.',
        activation: 'Passive',
      ),
      tags: ['armor', 'light', 'studded leather', 'magic'],
    ),

    MagicItem(
      id: 'chain_mail_plus_1',
      name: 'Chain Mail +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 17 (Heavy Armor; Str 13 required)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to AC (Total AC 17) while wearing this magic chain mail.',
        description: '+1 bonus to AC while wearing this magic chain mail.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC (Total AC 17) while wearing this magic chain mail.',
        description: '+1 bonus to AC while wearing this magic chain mail.',
        activation: 'Passive',
      ),
      tags: ['armor', 'heavy', 'chain mail', 'magic'],
    ),
    MagicItem(
      id: 'chain_shirt_plus_1',
      name: 'Chain Shirt +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'AC 14 + Dex Mod (max 2; No Stealth Penalty)'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 bonus to AC (14 + Dex mod max 2) with no Stealth penalty while wearing this magic chain shirt.',
        description: '+1 bonus to AC with no Stealth penalty while wearing this magic chain shirt.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC (14 + Dex mod max 2) with no Stealth penalty.',
        description: '+1 bonus to AC with no Stealth penalty.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'chain shirt', 'magic'],
    ),

    // =========================================================================
    // 3. GENERIC MAGIC ARMOR / SHIELD +1 / +2 / +3
    // =========================================================================
    MagicItem(
      id: 'item_armor_plus_1',
      name: 'Armor +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 bonus to AC'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +1 bonus to AC while wearing this magic armor.',
        description: 'You have a +1 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +1 bonus to AC while wearing this magic armor.',
        description: 'You have a +1 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_armor_plus_2',
      name: 'Armor +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 bonus to AC'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +2 bonus to AC while wearing this magic armor.',
        description: 'You have a +2 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +2 bonus to AC while wearing this magic armor.',
        description: 'You have a +2 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_armor_plus_3',
      name: 'Armor +3',
      category: ItemCategory.armor,
      rarity: ItemRarity.legendary,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+3 bonus to AC'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'You have a +3 bonus to AC while wearing this magic armor.',
        description: 'You have a +3 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +3 bonus to AC while wearing this magic armor.',
        description: 'You have a +3 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'defense', 'ac', 'legendary'],
    ),

    MagicItem(
      id: 'item_shield_plus_1',
      name: 'Shield +1',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+3 Total AC (+2 Base Shield + 1 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have a +1 bonus to AC. This bonus is in addition to the shield\'s normal bonus to AC (+2), giving a total of +3 AC.',
        description: 'While holding this shield, you have a +1 bonus to AC. This bonus is in addition to the shield\'s normal bonus to AC.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC while wielding this shield (+3 AC total).',
        description: 'While wielding this magic shield, you gain a +1 bonus to Armor Class (total +3 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_shield_plus_2',
      name: 'Shield +2',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+4 Total AC (+2 Base Shield + 2 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have a +2 bonus to AC in addition to the normal shield bonus (+4 AC total).',
        description: 'While holding this shield, you have a +2 bonus to AC in addition to the normal shield bonus.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC while wielding this shield (+4 AC total).',
        description: 'While wielding this magic shield, you gain a +2 bonus to Armor Class (total +4 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_shield_plus_3',
      name: 'Shield +3',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+5 Total AC (+2 Base Shield + 3 Magic Bonus)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have a +3 bonus to AC in addition to the normal shield bonus (+5 AC total).',
        description: 'While holding this shield, you have a +3 bonus to AC in addition to the normal shield bonus.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 bonus to AC while wielding this shield (+5 AC total).',
        description: 'While wielding this magic shield, you gain a +3 bonus to Armor Class (total +5 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'defense', 'ac'],
    ),

    // =========================================================================
    // 4. SPECIAL & ARTIFACT SHIELDS & ARMOR
    // =========================================================================
    MagicItem(
      id: 'item_animated_shield',
      name: 'Animated Shield',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.sustain, label: 'Bonus Action: Shield Hovers & Protects for 1 Minute (Leaves Both Hands Free)'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Speak command word as bonus action: shield hovers around you for 1 minute, granting +2 AC while leaving both hands free.',
        description: 'While holding this shield, you can speak its command word as a bonus action to cause it to animate. The shield leaps into the air and hovers in your space to protect you as if you were wielding it, leaving your hands free. The shield remains animated for 1 minute, until you use a bonus action to end this effect, or until you are incapacitated or die, at which point the shield falls to the ground or into your hand if you have one free.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bonus Action: shield animates for 1 minute, granting +2 AC while freeing both hands for two-handed weapons/casting.',
        description: 'Speak command word as a Bonus Action: shield hovers for 1 minute to provide +2 AC with both hands free.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'animated', 'hands free', 'defense', 'ac'],
    ),
    MagicItem(
      id: 'item_adamantine_armor',
      name: 'Adamantine Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Critical Hits against you become Normal Hits'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While you\'re wearing it, any critical hit against you becomes a normal hit.',
        description: 'This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While you\'re wearing it, any critical hit against you becomes a normal hit.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Critical Hits against you turn into normal hits.',
        description: 'While wearing this armor, any Critical Hit scored against you becomes a normal hit.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'adamantine', 'crit immunity', 'defense'],
    ),
    MagicItem(
      id: 'item_mithral_armor',
      name: 'Mithral Armor',
      category: ItemCategory.armor,
      rarity: ItemRarity.uncommon,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'No Disadvantage on Stealth; No Strength Requirement'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Mithral is a light, flexible metal. If the armor normally imposes disadvantage on Dexterity (Stealth) checks or has a Strength requirement, the mithral version of the armor doesn\'t.',
        description: 'Mithral is a light, flexible metal. If the armor normally imposes disadvantage on Dexterity (Stealth) checks or has a Strength requirement, the mithral version of the armor doesn\'t.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Removes Stealth disadvantage and Strength requirements from heavy/medium armor.',
        description: 'Lightweight mithral eliminates Stealth disadvantage and Strength score requirements on all armor types.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'mithral', 'stealth', 'strength'],
    ),
    MagicItem(
      id: 'item_dragon_scale_mail',
      name: 'Dragon Scale Mail',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Scale Mail, Damage Resistance, Advantage vs Dragon Breath & Sense Dragons 30 Miles'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 scale mail granting resistance to dragon damage type, advantage on saves against dragon breath weapons and Frightful Presence, and action to sense dragon locations in 30 miles.',
        description: 'Dragon scale mail is made of the scales of one kind of dragon. While wearing this armor, you gain a +1 bonus to AC, you have resistance to one damage type determined by the dragon species (Black/Copper: Acid, Blue/Bronze: Lightning, Green: Poison, Red/Brass/Gold: Fire, White/Silver: Cold), and you have advantage on saving throws against the breath weapons and Frightful Presence of dragons. Once per day, you can focus to detect the location of any dragon within 30 miles.',
        activation: 'Passive / 1 Action (Detect)',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Scale Mail; Resistance to dragon element; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description: '+1 Scale Mail granting elemental Resistance, Advantage on saves vs Dragon breath weapons and Frightful Presence, and 30-mile dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'dragon', 'resistance', 'breath weapon'],
    ),
    MagicItem(
      id: 'item_dwarven_plate',
      name: 'Dwarven Plate',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+2 Plate Armor (AC 20) & Reaction: Reduce Forced Push/Prone by 10 ft'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+2 plate armor. If an effect moves you against your will along the ground, you can use your reaction to reduce the distance you are moved by up to 10 feet.',
        description: 'While wearing this armor, you gain a +2 bonus to AC. In addition, if an effect moves you against your will along the ground, you can use your reaction to reduce the distance you are moved by up to 10 feet.',
        activation: 'Passive / 1 Reaction',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 Plate Armor (AC 20); Reaction to resist forced movement by 10 feet.',
        description: '+2 bonus to AC. When an effect pushes you, use Reaction to reduce forced movement by up to 10 feet.',
        activation: 'Passive / 1 Reaction',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'plate', 'dwarven', 'defense', 'forced movement'],
    ),
    MagicItem(
      id: 'item_elven_chain',
      name: 'Elven Chain',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Chain Shirt (AC 14 + Dex max 2); Proficient Even If You Lack Medium Armor Proficiency'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 chain shirt. You are considered proficient with this armor even if you lack medium armor proficiency.',
        description: 'You gain a +1 bonus to AC while you wear this armor. You are considered proficient with this armor even if you lack proficiency with medium armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Chain Shirt; grants proficiency to wearers who lack medium armor proficiency.',
        description: '+1 AC bonus. Any character is proficient while wearing this armor, making it ideal for wizards, sorcerers, and rogues.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'elven', 'medium armor', 'proficiency', 'spellcaster'],
    ),
    MagicItem(
      id: 'item_glamoured_studded_leather',
      name: 'Glamoured Studded Leather',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: '+1 Studded Leather (AC 13 + Dex); Bonus Action: Disguise Armor as Any Outfit'),
      ],
      rules2014: ItemEditionDetails(
        summary: '+1 studded leather armor. Bonus action: speak command word to disguise the armor as normal clothing or other armor.',
        description: 'While wearing this armor, you gain a +1 bonus to AC. You can also use a bonus action to speak the armor\'s command word and cause the armor to assume the appearance of a normal set of clothing or some other kind of armor. You decide what it looks like, including its color, style, and accessories, but the armor retains its normal bulk and weight. The illusory appearance lasts until you use this property again or remove the armor.',
        activation: '1 Bonus Action / Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 Studded Leather; Bonus Action: illusory shift into clothing or other armor suits.',
        description: '+1 bonus to AC. Use Bonus Action to change visual appearance into normal clothes or distinct armor styles at will.',
        activation: '1 Bonus Action / Passive',
      ),
      isChangedIn2024: false,
      tags: ['armor', 'glamour', 'disguise', 'stealth'],
    ),
    MagicItem(
      id: 'item_spellguard_shield',
      name: 'Spellguard Shield',
      category: ItemCategory.armor,
      rarity: ItemRarity.veryRare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Advantage on Saves vs Spells; Spell Attack Rolls against you have Disadvantage'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'While holding this shield, you have advantage on saving throws against spells and other magical effects, and spell attacks have disadvantage against you.',
        description: 'While holding this shield, you have advantage on saving throws against spells and other magical effects, and spell attacks have disadvantage against you.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Advantage on all saving throws vs spells/magical effects; Spell attacks against you suffer Disadvantage.',
        description: 'While wielding this shield, gain Advantage on saving throws vs spells and other magical effects, and spell attacks against you have Disadvantage.',
        activation: 'Passive',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'spellguard', 'magic resistance', 'defense'],
    ),
    MagicItem(
      id: 'item_shield_of_missile_attraction',
      name: 'Shield of Missile Attraction',
      category: ItemCategory.armor,
      rarity: ItemRarity.rare,
      requiresAttunement: true,
      actionRings: [
        ActionTraitRing(ringType: ActionRingType.reaction, label: 'Resistance to Ranged Weapon Damage; Cursed: Pulls Ranged Attacks within 10 ft to You'),
      ],
      rules2014: ItemEditionDetails(
        summary: 'Grants resistance to damage from ranged weapon attacks. Cursed: whenever a ranged weapon attack is made against a target within 10 feet of you, the curse redirects the attack to you.',
        description: 'While holding this shield, you have resistance to damage from ranged weapon attacks. Curse: This shield is cursed. Whenever a ranged weapon attack is made against a target within 10 feet of you, the curse causes you to become the target instead.',
        activation: 'Passive / Cursed Trigger',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Resistance to Ranged Weapon Damage; Cursed redirection of projectile attacks within 10 ft.',
        description: 'Provides Resistance to damage from ranged weapon attacks. Cursed: pulls ranged attacks within 10 feet directly to yourself.',
        activation: 'Passive / Cursed Trigger',
      ),
      isChangedIn2024: false,
      tags: ['shield', 'curse', 'missile', 'ranged defense'],
    ),
  ];
}
