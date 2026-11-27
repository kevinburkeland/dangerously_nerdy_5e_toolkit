import '../magic_item_data.dart';

/// Comprehensive SRD 5.1 & 5.2 Armor & Shields Catalog
/// Includes standard nonmagical suits, specific named magic armor/shield tiers, and legendary relics.
class SrdArmorAndShields {
  SrdArmorAndShields._();

  static const List<EquipmentItem> items = [
    // =========================================================================
    // 1. STANDARD NONMAGICAL ARMOR & SHIELDS
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'armor_plate', ruleset: RulesetVersion.v2024), name: 'Plate Armor (Full Plate)',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 18. Heavy armor providing peak nonmagical protection. Requires Str 15 and imposes Disadvantage on Stealth checks.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 18. Heavy armor composed of shaped, interlocking metal plates covering the entire body. Requires Str 15 and imposes Disadvantage on Stealth.',
        description:
            'Plate consists of shaped, interlocking metal plates to cover the entire body. A suit of plate includes gauntlets, heavy leather boots, a visored helmet, and thick layers of padding underneath the armor. Buckles and straps distribute the weight over the body.',
        properties: [
          'Armor Class: 18 (no Dex modifier added).',
          'Strength Requirement: Str 15.',
          'Stealth: Disadvantage.',
          'Weight: 65 lbs.',
          'Cost: 1,500 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'AC 18. Heavy armor providing peak nonmagical protection. Requires Str 15 and imposes Disadvantage on Stealth checks.',
        description:
            'Plate consists of shaped, interlocking metal plates covering the entire body with underlying arming doublet and gauntlets.',
        properties: [
          'Armor Class: 18.',
          'Strength: 15.',
          'Stealth: Disadvantage.',
          'Weight: 65 lbs.',
          'Cost: 1,500 gp.',
        ],
      ),
      tags: ['armor', 'heavy', 'plate', 'nonmagical', 'ac 18'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'heavy', 'plate', 'nonmagical', 'ac 18'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 18, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_half_plate', ruleset: RulesetVersion.v2024), name: 'Half Plate Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 15 + Dex modifier (max 2). Medium armor with Stealth Disadvantage.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 15 + Dex modifier (max 2). Medium armor covering vital areas with shaped metal plates. Imposes Disadvantage on Stealth.',
        description:
            'Half plate consists of shaped metal plates that cover most of the wearer\'s body. It does not include leg protection beyond simple greaves attached with leather straps.',
        properties: [
          'Armor Class: 15 + Dex modifier (max 2).',
          'Stealth: Disadvantage.',
          'Weight: 40 lbs.',
          'Cost: 750 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'AC 15 + Dex modifier (max 2). Medium armor with Stealth Disadvantage.',
        description:
            'Half plate provides superior medium armor defense with shaped steel breastplate, pauldrons, and greaves.',
        properties: [
          'Armor Class: 15 + Dex modifier (max 2).',
          'Stealth: Disadvantage.',
          'Weight: 40 lbs.',
          'Cost: 750 gp.',
        ],
      ),
      tags: ['armor', 'medium', 'half plate', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'half plate', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 15, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_breastplate', ruleset: RulesetVersion.v2024), name: 'Breastplate',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 14 + Dex modifier (max 2). Medium armor with no Stealth disadvantage.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 14 + Dex modifier (max 2). Medium armor consisting of a fitted metal chest piece worn with supple leather. Imposes NO penalty on Stealth.',
        description:
            'This armor consists of a fitted metal chest piece worn with supple leather. Although it leaves the legs and arms relatively unprotected, this armor provides good protection for the wearer\'s vital organs while leaving the wearer relatively unencumbered.',
        properties: [
          'Armor Class: 14 + Dex modifier (max 2).',
          'Stealth: Normal (No Disadvantage).',
          'Weight: 20 lbs.',
          'Cost: 400 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'AC 14 + Dex modifier (max 2). Medium armor with no Stealth disadvantage.',
        description: 'Fitted steel chest piece leaving limbs unencumbered.',
        properties: [
          'Armor Class: 14 + Dex modifier (max 2).',
          'Stealth: Normal.',
          'Weight: 20 lbs.',
          'Cost: 400 gp.',
        ],
      ),
      tags: [
        'armor',
        'medium',
        'breastplate',
        'nonmagical',
        'stealth friendly'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'breastplate', 'nonmagical', 'stealth friendly'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_splint', ruleset: RulesetVersion.v2024), name: 'Splint Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 17. Heavy armor made of vertical metal splints on leather backing.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 17. Heavy armor made of narrow vertical strips of metal riveted to a backing of leather. Requires Str 15 and imposes Disadvantage on Stealth.',
        description:
            'This armor is made of narrow vertical strips of metal riveted to a backing of leather that is worn over cloth padding. Flexible chain mail protects the joints.',
        properties: [
          'Armor Class: 17.',
          'Strength: 15.',
          'Stealth: Disadvantage.',
          'Weight: 60 lbs.',
          'Cost: 200 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'AC 17. Heavy armor made of vertical metal splints on leather backing.',
        description:
            'Heavy armor offering robust defense for frontline martial combatants.',
        properties: [
          'Armor Class: 17.',
          'Strength: 15.',
          'Stealth: Disadvantage.',
          'Weight: 60 lbs.',
          'Cost: 200 gp.',
        ],
      ),
      tags: ['armor', 'heavy', 'splint', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'heavy', 'splint', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 17, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_chain_mail', ruleset: RulesetVersion.v2024), name: 'Chain Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 16. Classic heavy armor made of interlocking steel rings.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 16. Heavy armor made of interlocking metal rings worn over a layer of quilted fabric. Requires Str 13 and imposes Disadvantage on Stealth.',
        description:
            'Made of interlocking metal rings, chain mail includes a layer of quilted fabric worn underneath the mail to prevent chafing and to cushion the impact of blows. The suit includes gauntlets.',
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
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'heavy', 'chain mail', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 16, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_scale_mail', ruleset: RulesetVersion.v2024), name: 'Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 14 + Dex modifier (max 2). Overlapping metal scales on leather.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 14 + Dex modifier (max 2). Medium armor consisting of a coat and leggings of leather covered with overlapping pieces of metal.',
        description:
            'This armor consists of a coat and leggings (and perhaps a separate skirt) of leather covered with overlapping pieces of metal, much like the scales of a fish. The suit includes gauntlets.',
        properties: [
          'Armor Class: 14 + Dex modifier (max 2).',
          'Stealth: Disadvantage.',
          'Weight: 45 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'AC 14 + Dex modifier (max 2). Overlapping metal scales on leather.',
        description: 'Medium armor of overlapping metal scales.',
        properties: [
          'Armor Class: 14 + Dex modifier (max 2).',
          'Stealth: Disadvantage.',
          'Weight: 45 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['armor', 'medium', 'scale mail', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'scale mail', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_chain_shirt', ruleset: RulesetVersion.v2024), name: 'Chain Shirt',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 13 + Dex modifier (max 2). Medium armor with no Stealth disadvantage.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 13 + Dex modifier (max 2). Medium armor made of interlocking metal rings worn between layers of clothing or leather.',
        description:
            'Made of interlocking metal rings, a chain shirt is worn between layers of clothing or leather. This armor offers modest protection to the wearer\'s upper body and allows the sound of the rings rubbing together to be muffled by outer garments.',
        properties: [
          'Armor Class: 13 + Dex modifier (max 2).',
          'Stealth: Normal.',
          'Weight: 20 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'AC 13 + Dex modifier (max 2). Medium armor with no Stealth disadvantage.',
        description:
            'Interlocking metal ring shirt worn under tunics or leathers.',
        properties: [
          'Armor Class: 13 + Dex modifier (max 2).',
          'Stealth: Normal.',
          'Weight: 20 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['armor', 'medium', 'chain shirt', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'chain shirt', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 13, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_studded_leather', ruleset: RulesetVersion.v2024), name: 'Studded Leather Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 12 + Dex modifier. Premier light armor reinforced with steel rivets.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 12 + Dex modifier. Light armor made of tough but flexible leather reinforced with close-set rivets or spikes.',
        description:
            'Made from tough but flexible leather, studded leather is reinforced with close-set rivets or spikes.',
        properties: [
          'Armor Class: 12 + Dex modifier (full).',
          'Stealth: Normal.',
          'Weight: 13 lbs.',
          'Cost: 45 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'AC 12 + Dex modifier. Premier light armor reinforced with steel rivets.',
        description:
            'Flexible boiled leather reinforced with close-set rivets.',
        properties: [
          'Armor Class: 12 + Dex modifier.',
          'Stealth: Normal.',
          'Weight: 13 lbs.',
          'Cost: 45 gp.',
        ],
      ),
      tags: ['armor', 'light', 'studded leather', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'light', 'studded leather', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 12, 'armorType': 'light' },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_leather', ruleset: RulesetVersion.v2024), name: 'Leather Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 11 + Dex modifier. Standard boiled leather suit.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 11 + Dex modifier. Light armor made of boiled and cured leather.',
        description:
            'The breastplate and shoulder protectors of this armor are made of leather that has been stiffened by being boiled in oil. The rest of the armor is made of softer and more flexible materials.',
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
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'light', 'leather', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 11, 'armorType': 'light' },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_padded', ruleset: RulesetVersion.v2024), name: 'Padded Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 11 + Dex modifier. Quilted cloth armor with Stealth Disadvantage.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 11 + Dex modifier. Quilted layers of cloth and batting. Imposes Disadvantage on Stealth.',
        description:
            'Padded armor consists of quilted layers of cloth and batting.',
        properties: [
          'Armor Class: 11 + Dex modifier.',
          'Stealth: Disadvantage.',
          'Weight: 8 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'AC 11 + Dex modifier. Quilted cloth armor with Stealth Disadvantage.',
        description: 'Quilted fabric and batting padding.',
        properties: [
          'Armor Class: 11 + Dex modifier.',
          'Stealth: Disadvantage.',
          'Weight: 8 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['armor', 'light', 'padded', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'light', 'padded', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 11, 'armorType': 'light' },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_hide', ruleset: RulesetVersion.v2024), name: 'Hide Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 12 + Dex modifier (max 2). Medium armor of cured pelts.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 12 + Dex modifier (max 2). Crude armor made from thick furs and pelts.',
        description:
            'This crude armor consists of thick furs and pelts. It is commonly worn by barbarian tribes, evil humanoids, and other folk who lack the tools and materials to make better armor.',
        properties: [
          'Armor Class: 12 + Dex modifier (max 2).',
          'Stealth: Normal.',
          'Weight: 12 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 12 + Dex modifier (max 2). Medium armor of cured pelts.',
        description: 'Thick pelt armor providing basic medium defense.',
        properties: [
          'Armor Class: 12 + Dex modifier (max 2).',
          'Stealth: Normal.',
          'Weight: 12 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['armor', 'medium', 'hide', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'hide', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 12, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_ring_mail', ruleset: RulesetVersion.v2024), name: 'Ring Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'AC 14. Heavy armor with no Strength requirement.',
      rules2014: ItemEditionDetails(
        summary:
            'AC 14. Heavy armor consisting of large metal rings sewn into leather backing. Has no Strength requirement and imposes Disadvantage on Stealth.',
        description:
            'This armor is leather armor with heavy rings sewn into it. The rings help reinforce the armor against blows from swords and axes.',
        properties: [
          'Armor Class: 14.',
          'Stealth: Disadvantage.',
          'Weight: 40 lbs.',
          'Cost: 30 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'AC 14. Heavy armor with no Strength requirement.',
        description: 'Leather armor reinforced with heavy iron rings.',
        properties: [
          'Armor Class: 14.',
          'Stealth: Disadvantage.',
          'Weight: 40 lbs.',
          'Cost: 30 gp.',
        ],
      ),
      tags: ['armor', 'heavy', 'ring mail', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'heavy', 'ring mail', 'nonmagical'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'armor_shield_standard', ruleset: RulesetVersion.v2024), name: 'Shield',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: '+2 bonus to AC while held in one hand.',
      rules2014: ItemEditionDetails(
        summary:
            '+2 bonus to AC. Made from wood or metal and carried in one hand. You can benefit from only one shield at a time.',
        description:
            'A shield is made from wood or metal and is carried in one hand. Wielding a shield increases your Armor Class by 2. You can benefit from only one shield at a time.',
        properties: [
          'Armor Class: +2 bonus.',
          'Requires: 1 hand.',
          'Weight: 6 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC while held in one hand.',
        description:
            'A shield held in one hand provides a +2 bonus to Armor Class.',
        properties: [
          'Armor Class: +2 bonus.',
          'Weight: 6 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['shield', 'defense', 'ac', 'nonmagical'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['shield', 'defense', 'ac', 'nonmagical'], 'isShield': true, 'shieldBonus': 2, 'defaultSlot': EquipmentSlot.shield },
    ),

    // =========================================================================
    // 2. SPECIFIC MAGIC ARMOR VARIANTS (+1, +2, +3)
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'plate_plus_1', ruleset: RulesetVersion.v2024), name: 'Plate Armor +1',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'Total AC 19. +1 magical defense bonus applied to full plate armor.',
      rules2014: ItemEditionDetails(
        summary:
            'You have a +1 bonus to AC while wearing this suit of magic plate armor (Total AC 19).',
        description:
            'You have a +1 bonus to AC while wearing this suit of magic plate armor (Total AC 19). Requires Str 15 and imposes Disadvantage on Stealth.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Total AC 19. +1 magical defense bonus applied to full plate armor.',
        description:
            'You have a +1 bonus to AC while wearing this magic plate armor (Total AC 19).',
        activation: 'Passive',
      ),
      tags: ['armor', 'heavy', 'plate', 'magic', 'ac 19'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'heavy', 'plate', 'magic', 'ac 19'], 'bonusAc': 2, 'acBonus': 1, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 18, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'plate_plus_2', ruleset: RulesetVersion.v2024), name: 'Plate Armor +2',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'Total AC 20. +2 magical defense bonus applied to full plate armor.',
      rules2014: ItemEditionDetails(
        summary:
            'You have a +2 bonus to AC while wearing this suit of magic plate armor (Total AC 20).',
        description:
            'Masterwork enchanted full plate granting a +2 bonus to Armor Class (Total AC 20).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Total AC 20. +2 magical defense bonus applied to full plate armor.',
        description:
            'Masterwork enchanted full plate granting a +2 bonus to Armor Class (Total AC 20).',
        activation: 'Passive',
      ),
      tags: ['armor', 'heavy', 'plate', 'magic', 'ac 20'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'heavy', 'plate', 'magic', 'ac 20'], 'bonusAc': 2, 'acBonus': 2, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 18, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'plate_plus_3', ruleset: RulesetVersion.v2024), name: 'Plate Armor +3',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'Total AC 21. Legendary +3 enchanted full plate armor.',
      rules2014: ItemEditionDetails(
        summary:
            'You have a +3 bonus to AC while wearing this suit of magic plate armor (Total AC 21).',
        description:
            'Legendary suit of impenetrable full plate offering a +3 bonus to Armor Class (Total AC 21).',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Total AC 21. Legendary +3 enchanted full plate armor.',
        description:
            'Legendary suit of impenetrable full plate offering a +3 bonus to Armor Class (Total AC 21).',
        activation: 'Passive',
      ),
      tags: ['armor', 'heavy', 'plate', 'magic', 'legendary', 'ac 21'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'heavy', 'plate', 'magic', 'legendary', 'ac 21'], 'bonusAc': 3, 'acBonus': 3, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 18, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),

    EquipmentItem(
      id: EntityId(slug: 'half_plate_plus_1', ruleset: RulesetVersion.v2024), name: 'Half Plate +1',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: '+1 bonus to AC (16 + Dex mod max 2) while wearing this magic half plate armor.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 bonus to AC (16 + Dex mod max 2) while wearing this magic half plate armor.',
        description:
            '+1 bonus to AC while wearing this magic half plate armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 bonus to AC (16 + Dex mod max 2) while wearing this magic half plate armor.',
        description:
            '+1 bonus to AC while wearing this magic half plate armor.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'half plate', 'magic'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'half plate', 'magic'], 'bonusAc': 1, 'acBonus': 1, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 15, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'half_plate_plus_2', ruleset: RulesetVersion.v2024), name: 'Half Plate +2',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: '+2 bonus to AC (17 + Dex mod max 2) while wearing this magic half plate armor.',
      rules2014: ItemEditionDetails(
        summary:
            '+2 bonus to AC (17 + Dex mod max 2) while wearing this magic half plate armor.',
        description:
            '+2 bonus to AC while wearing this magic half plate armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+2 bonus to AC (17 + Dex mod max 2) while wearing this magic half plate armor.',
        description:
            '+2 bonus to AC while wearing this magic half plate armor.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'half plate', 'magic'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'half plate', 'magic'], 'bonusAc': 2, 'acBonus': 2, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 15, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    EquipmentItem(
      id: EntityId(slug: 'breastplate_plus_1', ruleset: RulesetVersion.v2024), name: 'Breastplate +1',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: '+1 bonus to AC (15 + Dex mod max 2) with no Stealth disadvantage.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 bonus to AC (15 + Dex mod max 2) with no Stealth disadvantage while wearing this magic breastplate.',
        description:
            '+1 bonus to AC with no Stealth disadvantage while wearing this magic breastplate.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 bonus to AC (15 + Dex mod max 2) with no Stealth disadvantage.',
        description: '+1 bonus to AC with no Stealth disadvantage.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'breastplate', 'magic', 'stealth friendly'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'breastplate', 'magic', 'stealth friendly'], 'bonusAc': 1, 'acBonus': 1, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'breastplate_plus_2', ruleset: RulesetVersion.v2024), name: 'Breastplate +2',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: '+2 bonus to AC (16 + Dex mod max 2) with no Stealth disadvantage.',
      rules2014: ItemEditionDetails(
        summary:
            '+2 bonus to AC (16 + Dex mod max 2) with no Stealth disadvantage while wearing this magic breastplate.',
        description:
            '+2 bonus to AC with no Stealth disadvantage while wearing this magic breastplate.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+2 bonus to AC (16 + Dex mod max 2) with no Stealth disadvantage.',
        description: '+2 bonus to AC with no Stealth disadvantage.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'breastplate', 'magic', 'stealth friendly'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'breastplate', 'magic', 'stealth friendly'], 'bonusAc': 2, 'acBonus': 2, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    EquipmentItem(
      id: EntityId(slug: 'studded_leather_plus_1', ruleset: RulesetVersion.v2024), name: 'Studded Leather +1',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: '+1 bonus to AC (13 + Dex modifier) while wearing this magic studded leather armor.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 bonus to AC (13 + Dex modifier) while wearing this magic studded leather armor.',
        description:
            '+1 bonus to AC while wearing this magic studded leather armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 bonus to AC (13 + Dex modifier) while wearing this magic studded leather armor.',
        description:
            '+1 bonus to AC while wearing this magic studded leather armor.',
        activation: 'Passive',
      ),
      tags: ['armor', 'light', 'studded leather', 'magic'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'light', 'studded leather', 'magic'], 'bonusAc': 1, 'acBonus': 1, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 12, 'armorType': 'light' },
    ),
    EquipmentItem(
      id: EntityId(slug: 'studded_leather_plus_2', ruleset: RulesetVersion.v2024), name: 'Studded Leather +2',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: '+2 bonus to AC (14 + Dex modifier) while wearing this magic studded leather armor.',
      rules2014: ItemEditionDetails(
        summary:
            '+2 bonus to AC (14 + Dex modifier) while wearing this magic studded leather armor.',
        description:
            '+2 bonus to AC while wearing this magic studded leather armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+2 bonus to AC (14 + Dex modifier) while wearing this magic studded leather armor.',
        description:
            '+2 bonus to AC while wearing this magic studded leather armor.',
        activation: 'Passive',
      ),
      tags: ['armor', 'light', 'studded leather', 'magic'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'light', 'studded leather', 'magic'], 'bonusAc': 2, 'acBonus': 2, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 12, 'armorType': 'light' },
    ),

    EquipmentItem(
      id: EntityId(slug: 'chain_mail_plus_1', ruleset: RulesetVersion.v2024), name: 'Chain Mail +1',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: '+1 bonus to AC (Total AC 17) while wearing this magic chain mail.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 bonus to AC (Total AC 17) while wearing this magic chain mail.',
        description: '+1 bonus to AC while wearing this magic chain mail.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 bonus to AC (Total AC 17) while wearing this magic chain mail.',
        description: '+1 bonus to AC while wearing this magic chain mail.',
        activation: 'Passive',
      ),
      tags: ['armor', 'heavy', 'chain mail', 'magic'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'heavy', 'chain mail', 'magic'], 'bonusAc': 1, 'acBonus': 1, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 16, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'chain_shirt_plus_1', ruleset: RulesetVersion.v2024), name: 'Chain Shirt +1',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: '+1 bonus to AC (14 + Dex mod max 2) with no Stealth penalty.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 bonus to AC (14 + Dex mod max 2) with no Stealth penalty while wearing this magic chain shirt.',
        description:
            '+1 bonus to AC with no Stealth penalty while wearing this magic chain shirt.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC (14 + Dex mod max 2) with no Stealth penalty.',
        description: '+1 bonus to AC with no Stealth penalty.',
        activation: 'Passive',
      ),
      tags: ['armor', 'medium', 'chain shirt', 'magic'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'medium', 'chain shirt', 'magic'], 'bonusAc': 1, 'acBonus': 1, 'defaultSlot': EquipmentSlot.armor, 'baseAc': 13, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // =========================================================================
    // 3. GENERIC MAGIC ARMOR / SHIELD +1 / +2 / +3
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'item_armor_plus_1', ruleset: RulesetVersion.v2024), name: 'Armor +1',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: 'You have a +1 bonus to AC while wearing this magic armor.',
      rules2014: ItemEditionDetails(
        summary: 'You have a +1 bonus to AC while wearing this magic armor.',
        description:
            'You have a +1 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +1 bonus to AC while wearing this magic armor.',
        description:
            'You have a +1 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['armor', 'defense', 'ac'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'defense', 'ac'], 'bonusAc': 1, 'acBonus': 1, 'defaultSlot': EquipmentSlot.armor },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_armor_plus_2', ruleset: RulesetVersion.v2024), name: 'Armor +2',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: 'You have a +2 bonus to AC while wearing this magic armor.',
      rules2014: ItemEditionDetails(
        summary: 'You have a +2 bonus to AC while wearing this magic armor.',
        description:
            'You have a +2 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +2 bonus to AC while wearing this magic armor.',
        description:
            'You have a +2 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['armor', 'defense', 'ac'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'defense', 'ac'], 'bonusAc': 2, 'acBonus': 2, 'defaultSlot': EquipmentSlot.armor },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_armor_plus_3', ruleset: RulesetVersion.v2024), name: 'Armor +3',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: false,
      descriptionMarkdown: 'You have a +3 bonus to AC while wearing this magic armor.',
      rules2014: ItemEditionDetails(
        summary: 'You have a +3 bonus to AC while wearing this magic armor.',
        description:
            'You have a +3 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'You have a +3 bonus to AC while wearing this magic armor.',
        description:
            'You have a +3 bonus to AC while wearing this magic armor.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['armor', 'defense', 'ac', 'legendary'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'defense', 'ac', 'legendary'], 'bonusAc': 3, 'acBonus': 3, 'defaultSlot': EquipmentSlot.armor },
    ),

    EquipmentItem(
      id: EntityId(slug: 'item_shield_plus_1', ruleset: RulesetVersion.v2024), name: 'Shield +1',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: '+1 bonus to AC while wielding this shield (+3 AC total).',
      rules2014: ItemEditionDetails(
        summary:
            'While holding this shield, you have a +1 bonus to AC. This bonus is in addition to the shield\'s normal bonus to AC (+2), giving a total of +3 AC.',
        description:
            'While holding this shield, you have a +1 bonus to AC. This bonus is in addition to the shield\'s normal bonus to AC.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 bonus to AC while wielding this shield (+3 AC total).',
        description:
            'While wielding this magic shield, you gain a +1 bonus to Armor Class (total +3 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['shield', 'defense', 'ac'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['shield', 'defense', 'ac'], 'bonusAc': 1, 'acBonus': 1, 'isShield': true, 'shieldBonus': 2, 'defaultSlot': EquipmentSlot.shield },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_shield_plus_2', ruleset: RulesetVersion.v2024), name: 'Shield +2',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: '+2 bonus to AC while wielding this shield (+4 AC total).',
      rules2014: ItemEditionDetails(
        summary:
            'While holding this shield, you have a +2 bonus to AC in addition to the normal shield bonus (+4 AC total).',
        description:
            'While holding this shield, you have a +2 bonus to AC in addition to the normal shield bonus.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 bonus to AC while wielding this shield (+4 AC total).',
        description:
            'While wielding this magic shield, you gain a +2 bonus to Armor Class (total +4 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['shield', 'defense', 'ac'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['shield', 'defense', 'ac'], 'bonusAc': 2, 'acBonus': 2, 'isShield': true, 'shieldBonus': 2, 'defaultSlot': EquipmentSlot.shield },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_shield_plus_3', ruleset: RulesetVersion.v2024), name: 'Shield +3',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: '+3 bonus to AC while wielding this shield (+5 AC total).',
      rules2014: ItemEditionDetails(
        summary:
            'While holding this shield, you have a +3 bonus to AC in addition to the normal shield bonus (+5 AC total).',
        description:
            'While holding this shield, you have a +3 bonus to AC in addition to the normal shield bonus.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: '+3 bonus to AC while wielding this shield (+5 AC total).',
        description:
            'While wielding this magic shield, you gain a +3 bonus to Armor Class (total +5 AC).',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['shield', 'defense', 'ac'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['shield', 'defense', 'ac'], 'bonusAc': 3, 'acBonus': 3, 'isShield': true, 'shieldBonus': 2, 'defaultSlot': EquipmentSlot.shield },
    ),

    // =========================================================================
    // 4. SPECIAL & ARTIFACT SHIELDS & ARMOR
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'item_animated_shield', ruleset: RulesetVersion.v2024), name: 'Animated Shield',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Bonus Action: shield animates for 1 minute, granting +2 AC while freeing both hands for two-handed weapons/casting.',
      rules2014: ItemEditionDetails(
        summary:
            'Speak command word as bonus action: shield hovers around you for 1 minute, granting +2 AC while leaving both hands free.',
        description:
            'While holding this shield, you can speak its command word as a bonus action to cause it to animate. The shield leaps into the air and hovers in your space to protect you as if you were wielding it, leaving your hands free. The shield remains animated for 1 minute, until you use a bonus action to end this effect, or until you are incapacitated or die, at which point the shield falls to the ground or into your hand if you have one free.',
        activation: '1 Bonus Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Bonus Action: shield animates for 1 minute, granting +2 AC while freeing both hands for two-handed weapons/casting.',
        description:
            'Speak command word as a Bonus Action: shield hovers for 1 minute to provide +2 AC with both hands free.',
        activation: '1 Bonus Action',
      ),
      isChangedIn2024: false, tags: ['shield', 'animated', 'hands free', 'defense', 'ac'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['shield', 'animated', 'hands free', 'defense', 'ac'], 'isShield': true, 'shieldBonus': 2, 'defaultSlot': EquipmentSlot.shield },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_adamantine_armor', ruleset: RulesetVersion.v2024), name: 'Adamantine Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Critical Hits against you turn into normal hits.',
      rules2014: ItemEditionDetails(
        summary:
            'This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While you\'re wearing it, any critical hit against you becomes a normal hit.',
        description:
            'This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While you\'re wearing it, any critical hit against you becomes a normal hit.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Critical Hits against you turn into normal hits.',
        description:
            'While wearing this armor, any Critical Hit scored against you becomes a normal hit.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['armor', 'adamantine', 'crit immunity', 'defense'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'adamantine', 'crit immunity', 'defense'], 'defaultSlot': EquipmentSlot.armor },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_mithral_armor', ruleset: RulesetVersion.v2024), name: 'Mithral Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'uncommon', rarityTier: ItemRarity.uncommon,
      requiresAttunement: false,
      descriptionMarkdown: 'Removes Stealth disadvantage and Strength requirements from heavy/medium armor.',
      rules2014: ItemEditionDetails(
        summary:
            'Mithral is a light, flexible metal. If the armor normally imposes disadvantage on Dexterity (Stealth) checks or has a Strength requirement, the mithral version of the armor doesn\'t.',
        description:
            'Mithral is a light, flexible metal. If the armor normally imposes disadvantage on Dexterity (Stealth) checks or has a Strength requirement, the mithral version of the armor doesn\'t.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Removes Stealth disadvantage and Strength requirements from heavy/medium armor.',
        description:
            'Lightweight mithral eliminates Stealth disadvantage and Strength score requirements on all armor types.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['armor', 'mithral', 'stealth', 'strength'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'mithral', 'stealth', 'strength'], 'defaultSlot': EquipmentSlot.armor },
    ),
    // Red Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_red_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Red Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Fire Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of red dragon scales granting Fire Resistance, advantage on saves against dragon breath weapons and Frightful Presence, and action to sense dragon locations in 30 miles.',
        description:
            'While wearing this crimson dragon scale armor, you gain a +1 bonus to AC, you have resistance to Fire damage, and you have advantage on saving throws against the breath weapons and Frightful Presence of dragons. Once per day, you can focus to detect the location of any dragon within 30 miles.',
        activation: 'Passive / 1 Action (Detect)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Fire Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail crafted from red dragon scales granting Fire Resistance, Advantage on saves vs Dragon breath weapons and Frightful Presence, and 30-mile dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'red dragon',
        'fire',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'red dragon', 'fire', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // Blue Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_blue_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Blue Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Lightning Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of blue dragon scales granting Lightning Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Made from iridescent blue dragon scales. Grants +1 AC, Lightning Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Lightning Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Lightning Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'blue dragon',
        'lightning',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'blue dragon', 'lightning', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // Green Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_green_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Green Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Poison Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of green dragon scales granting Poison Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Crafted from forest-green dragon scales. Grants +1 AC, Poison Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Poison Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Poison Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'green dragon',
        'poison',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'green dragon', 'poison', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // White Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_white_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'White Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Cold Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of white dragon scales granting Cold Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Crafted from arctic-white dragon scales. Grants +1 AC, Cold Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Cold Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Cold Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'white dragon',
        'cold',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'white dragon', 'cold', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // Black Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_black_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Black Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Acid Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of black dragon scales granting Acid Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Crafted from lustrous black dragon scales. Grants +1 AC, Acid Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Acid Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Acid Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'black dragon',
        'acid',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'black dragon', 'acid', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // Gold Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_gold_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Gold Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Fire Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of gold dragon scales granting Fire Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Crafted from gleaming gold dragon scales. Grants +1 AC, Fire Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Fire Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Fire Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'gold dragon',
        'fire',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'gold dragon', 'fire', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // Silver Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_silver_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Silver Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Cold Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of silver dragon scales granting Cold Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Crafted from polished silver dragon scales. Grants +1 AC, Cold Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Cold Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Cold Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'silver dragon',
        'cold',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'silver dragon', 'cold', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // Bronze Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_bronze_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Bronze Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Lightning Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of bronze dragon scales granting Lightning Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Crafted from bronze dragon scales. Grants +1 AC, Lightning Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Lightning Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Lightning Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'bronze dragon',
        'lightning',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'bronze dragon', 'lightning', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // Brass Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_brass_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Brass Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Fire Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of brass dragon scales granting Fire Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Crafted from brass dragon scales. Grants +1 AC, Fire Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Fire Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Fire Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'brass dragon',
        'fire',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'brass dragon', 'fire', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),

    // Copper Dragon Scale Mail
    EquipmentItem(
      id: EntityId(slug: 'item_copper_dragon_scale_mail', ruleset: RulesetVersion.v2024), name: 'Copper Dragon Scale Mail',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Scale Mail; Acid Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 scale mail made of copper dragon scales granting Acid Resistance, advantage on saves vs breath/frightful presence, and 30-mile dragon detection.',
        description:
            'Crafted from copper dragon scales. Grants +1 AC, Acid Resistance, and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Scale Mail; Acid Resistance; Advantage vs dragon breath/frightful presence; 30-mile dragon sense.',
        description:
            '+1 Scale Mail granting Acid Resistance and dragon detection.',
        activation: 'Passive / 1 Action',
      ),
      isChangedIn2024: false, tags: [
        'armor',
        'dragon',
        'copper dragon',
        'acid',
        'resistance',
        'scale mail'
      ],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'dragon', 'copper dragon', 'acid', 'resistance', 'scale mail'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_dwarven_plate', ruleset: RulesetVersion.v2024), name: 'Dwarven Plate',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: false,
      descriptionMarkdown: '+2 Plate Armor (AC 20); Reaction to resist forced movement by 10 feet.',
      rules2014: ItemEditionDetails(
        summary:
            '+2 plate armor. If an effect moves you against your will along the ground, you can use your reaction to reduce the distance you are moved by up to 10 feet.',
        description:
            'While wearing this armor, you gain a +2 bonus to AC. In addition, if an effect moves you against your will along the ground, you can use your reaction to reduce the distance you are moved by up to 10 feet.',
        activation: 'Passive / 1 Reaction',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+2 Plate Armor (AC 20); Reaction to resist forced movement by 10 feet.',
        description:
            '+2 bonus to AC. When an effect pushes you, use Reaction to reduce forced movement by up to 10 feet.',
        activation: 'Passive / 1 Reaction',
      ),
      isChangedIn2024: false, tags: ['armor', 'plate', 'dwarven', 'defense', 'forced movement'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'plate', 'dwarven', 'defense', 'forced movement'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 18, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_elven_chain', ruleset: RulesetVersion.v2024), name: 'Elven Chain',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: '+1 Chain Shirt; grants proficiency to wearers who lack medium armor proficiency.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 chain shirt. You are considered proficient with this armor even if you lack medium armor proficiency.',
        description:
            'You gain a +1 bonus to AC while you wear this armor. You are considered proficient with this armor even if you lack proficiency with medium armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Chain Shirt; grants proficiency to wearers who lack medium armor proficiency.',
        description:
            '+1 AC bonus. Any character is proficient while wearing this armor, making it ideal for wizards, sorcerers, and rogues.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['armor', 'elven', 'medium armor', 'proficiency', 'spellcaster'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'elven', 'medium armor', 'proficiency', 'spellcaster'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 13, 'armorType': 'medium', 'maxDexBonus': 2 },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_glamoured_studded_leather', ruleset: RulesetVersion.v2024), name: 'Glamoured Studded Leather',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: false,
      descriptionMarkdown: '+1 Studded Leather; Bonus Action: illusory shift into clothing or other armor suits.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 studded leather armor. Bonus action: speak command word to disguise the armor as normal clothing or other armor.',
        description:
            'While wearing this armor, you gain a +1 bonus to AC. You can also use a bonus action to speak the armor\'s command word and cause the armor to assume the appearance of a normal set of clothing or some other kind of armor. You decide what it looks like, including its color, style, and accessories, but the armor retains its normal bulk and weight. The illusory appearance lasts until you use this property again or remove the armor.',
        activation: '1 Bonus Action / Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Studded Leather; Bonus Action: illusory shift into clothing or other armor suits.',
        description:
            '+1 bonus to AC. Use Bonus Action to change visual appearance into normal clothes or distinct armor styles at will.',
        activation: '1 Bonus Action / Passive',
      ),
      isChangedIn2024: false, tags: ['armor', 'glamour', 'disguise', 'stealth'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'glamour', 'disguise', 'stealth'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 12, 'armorType': 'light' },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_spellguard_shield', ruleset: RulesetVersion.v2024), name: 'Spellguard Shield',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: 'Advantage on all saving throws vs spells/magical effects; Spell attacks against you suffer Disadvantage.',
      rules2014: ItemEditionDetails(
        summary:
            'While holding this shield, you have advantage on saving throws against spells and other magical effects, and spell attacks have disadvantage against you.',
        description:
            'While holding this shield, you have advantage on saving throws against spells and other magical effects, and spell attacks have disadvantage against you.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Advantage on all saving throws vs spells/magical effects; Spell attacks against you suffer Disadvantage.',
        description:
            'While wielding this shield, gain Advantage on saving throws vs spells and other magical effects, and spell attacks against you have Disadvantage.',
        activation: 'Passive',
      ),
      isChangedIn2024: false, tags: ['shield', 'spellguard', 'magic resistance', 'defense'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['shield', 'spellguard', 'magic resistance', 'defense'], 'isShield': true, 'shieldBonus': 2, 'defaultSlot': EquipmentSlot.shield },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_shield_of_missile_attraction', ruleset: RulesetVersion.v2024), name: 'Shield of Missile Attraction',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Resistance to Ranged Weapon Damage; Cursed redirection of projectile attacks within 10 ft.',
      rules2014: ItemEditionDetails(
        summary:
            'Grants resistance to damage from ranged weapon attacks. Cursed: whenever a ranged weapon attack is made against a target within 10 feet of you, the curse redirects the attack to you.',
        description:
            'While holding this shield, you have resistance to damage from ranged weapon attacks. Curse: This shield is cursed. Whenever a ranged weapon attack is made against a target within 10 feet of you, the curse causes you to become the target instead.',
        activation: 'Passive / Cursed Trigger',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Resistance to Ranged Weapon Damage; Cursed redirection of projectile attacks within 10 ft.',
        description:
            'Provides Resistance to damage from ranged weapon attacks. Cursed: pulls ranged attacks within 10 feet directly to yourself.',
        activation: 'Passive / Cursed Trigger',
      ),
      isChangedIn2024: false, tags: ['shield', 'curse', 'missile', 'ranged defense'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['shield', 'curse', 'missile', 'ranged defense'], 'isShield': true, 'shieldBonus': 2, 'defaultSlot': EquipmentSlot.shield },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_armor_of_invulnerability', ruleset: RulesetVersion.v2024), name: 'Armor of Invulnerability',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true,
      descriptionMarkdown: 'Plate armor granting Resistance to nonmagical damage; Action for 10 minutes of complete immunity to nonmagical damage.',
      rules2014: ItemEditionDetails(
        summary:
            'Plate armor. Resistance to nonmagical damage. Action (1/day): gain immunity to nonmagical damage for 10 minutes.',
        description:
            'You have resistance to nonmagical damage while you wear this armor. Additionally, you can use an action to make yourself immune to nonmagical damage for 10 minutes or until you are no longer wearing the armor. Once this special action is used, it can\'t be used again until the next dawn.',
        activation: 'Passive / 1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Plate armor granting Resistance to nonmagical damage; Action for 10 minutes of complete immunity to nonmagical damage.',
        description:
            'Legendary plate armor granting passive damage reduction and a daily surge of absolute physical invulnerability.',
        activation: 'Passive / 1 Action (1/Long Rest)',
      ),
      tags: ['armor', 'plate', 'invulnerability', 'immunity', 'legendary'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'plate', 'invulnerability', 'immunity', 'legendary'], 'defaultSlot': EquipmentSlot.armor },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_armor_of_resistance', ruleset: RulesetVersion.v2024), name: 'Armor of Resistance',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Grants Resistance to one designated damage type.',
      rules2014: ItemEditionDetails(
        summary:
            'You have resistance to one type of damage while you wear this armor (Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, or Thunder).',
        description:
            'You have resistance to one type of damage while you wear this armor. The DM chooses the type or determines it randomly.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants Resistance to one designated damage type.',
        description:
            'Enchanted suit granting persistent Resistance to an elemental or energy damage type.',
        activation: 'Passive',
      ),
      tags: ['armor', 'resistance', 'elemental', 'defense'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'resistance', 'elemental', 'defense'], 'defaultSlot': EquipmentSlot.armor },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_armor_of_vulnerability', ruleset: RulesetVersion.v2024), name: 'Armor of Vulnerability',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'rare', rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: 'Plate armor granting Resistance to one weapon damage type and Vulnerability to the other two.',
      rules2014: ItemEditionDetails(
        summary:
            'Plate armor granting resistance to one physical damage type (bludgeoning, piercing, or slashing). Cursed: you are vulnerable to the other two physical damage types.',
        description:
            'While wearing this armor, you have resistance to one of the following damage types: bludgeoning, piercing, or slashing. Curse: This armor is cursed. Attuning to it curses you until you are targeted by the Remove Curse spell. While cursed, you have vulnerability to the two other damage types associated with this armor.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Plate armor granting Resistance to one weapon damage type and Vulnerability to the other two.',
        description:
            'Cursed plate armor with dual-edged resistance and vulnerability.',
        activation: 'Passive',
      ),
      tags: ['armor', 'plate', 'cursed', 'vulnerability', 'resistance'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'plate', 'cursed', 'vulnerability', 'resistance'], 'defaultSlot': EquipmentSlot.armor },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_demon_armor', ruleset: RulesetVersion.v2024), name: 'Demon Armor',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'veryRare', rarityTier: ItemRarity.veryRare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 Plate Armor with 1d8 claw unarmed strikes and Abyssal fluency. Cursed disadvantage against demons.',
      rules2014: ItemEditionDetails(
        summary:
            '+1 plate armor (AC 19). Gauntlets have claws dealing 1d8 slashing (magic +1). Cursed: cannot remove without Remove Curse; disadvantage on attacks and saves vs demons.',
        description:
            'While wearing this armor, you gain a +1 bonus to AC, and you can understand and speak Abyssal. In addition, the armor\'s clawed gauntlets turn unarmed strikes with your hands into magic weapons that deal slashing damage, with a +1 bonus to attack rolls and damage rolls and a damage die of 1d8. Curse: Once you don this cursed armor, you can\'t doff it unless you are targeted by the Remove Curse spell. You have disadvantage on attack rolls against demons and on saving throws against their spells and special abilities.',
        activation: 'Passive',
      ),
      rules2024: ItemEditionDetails(
        summary:
            '+1 Plate Armor with 1d8 claw unarmed strikes and Abyssal fluency. Cursed disadvantage against demons.',
        description:
            'Demonic plate armor offering claw weaponry and Abyssal speech, bound with a fiendish curse.',
        activation: 'Passive',
      ),
      tags: ['armor', 'plate', 'demon', 'cursed', 'claws', 'unarmed'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'plate', 'demon', 'cursed', 'claws', 'unarmed'], 'defaultSlot': EquipmentSlot.armor },
    ),
    EquipmentItem(
      id: EntityId(slug: 'item_plate_armor_of_etherealness', ruleset: RulesetVersion.v2024), name: 'Plate Armor of Etherealness',
      itemType: 'armor', category: ItemCategory.armor, rarity: 'legendary', rarityTier: ItemRarity.legendary,
      requiresAttunement: true,
      descriptionMarkdown: 'Plate armor; Action to shift into the Border Ethereal for 10 minutes (1/Long Rest).',
      rules2014: ItemEditionDetails(
        summary:
            'Plate armor. Action: speak command word to gain the effect of the Etherealness spell for up to 10 minutes or until dismissed as a bonus action.',
        description:
            'While you wear this armor, you can use an action to speak its command word. When you do so, you gain the effect of the Etherealness spell for 10 minutes or until you use a bonus action to dismiss the effect. Once used, this property can\'t be used again until the next dawn.',
        activation: '1 Action (1/Day)',
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Plate armor; Action to shift into the Border Ethereal for 10 minutes (1/Long Rest).',
        description:
            'Legendary plate armor allowing dimensional phasing into the Border Ethereal plane.',
        activation: '1 Action (1/Long Rest)',
      ),
      tags: ['armor', 'plate', 'etherealness', 'phase', 'legendary'],
      customProperties: { 'cost': null, 'category': 'armor', 'tags': ['armor', 'plate', 'etherealness', 'phase', 'legendary'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 18, 'armorType': 'heavy', 'maxDexBonus': 0 },
    ),
  ];
}
