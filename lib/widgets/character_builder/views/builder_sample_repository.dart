import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_equipment_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/domain/core_types.dart';
import '../../../services/repository/layered_priority_repository.dart';

/// Populates the builder's initial sample SRD repository entries.
void populateBuilderSampleRepository(LayeredPriorityRepository repository) {
    final baseLayer = PriorityLayer(
      layerId: 'base-srd',
      name: 'SRD Baseline',
      priority: LayerPriority.baseRuleset,
    );

    // Register all SRD items
    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'chain-mail', ruleset: RulesetVersion.v2024),
      name: 'Chain Mail',
      itemType: 'Heavy Armor',
      category: ItemCategory.armor,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy armor with Base AC 16.',
      rules2014: ItemEditionDetails(
        summary: 'Heavy armor with Base AC 16.',
        description: 'Heavy armor with Base AC 16.',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Heavy armor with Base AC 16.',
        description: 'Heavy armor with Base AC 16.',
      ),
      customProperties: {'baseAc': 16, 'armorType': 'heavy'},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'leather-armor', ruleset: RulesetVersion.v2024),
      name: 'Leather Armor',
      itemType: 'Light Armor',
      category: ItemCategory.armor,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: 'Light armor Base AC 11 + DEX modifier.',
      rules2014: ItemEditionDetails(
        summary: 'Light armor Base AC 11 + DEX modifier.',
        description: 'Light armor Base AC 11 + DEX modifier.',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Light armor Base AC 11 + DEX modifier.',
        description: 'Light armor Base AC 11 + DEX modifier.',
      ),
      customProperties: {'baseAc': 11, 'armorType': 'light'},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'breastplate', ruleset: RulesetVersion.v2024),
      name: 'Breastplate',
      itemType: 'Medium Armor',
      category: ItemCategory.armor,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: 'Medium armor Base AC 14 + DEX (max 2).',
      rules2014: ItemEditionDetails(
        summary: 'Medium armor Base AC 14 + DEX (max 2).',
        description: 'Medium armor Base AC 14 + DEX (max 2).',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Medium armor Base AC 14 + DEX (max 2).',
        description: 'Medium armor Base AC 14 + DEX (max 2).',
      ),
      customProperties: {'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'shield', ruleset: RulesetVersion.v2024),
      name: 'Shield',
      itemType: 'Shield',
      category: ItemCategory.armor,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: '+2 Shield AC.',
      rules2014: ItemEditionDetails(
        summary: '+2 Shield AC.',
        description: '+2 Shield AC.',
      ),
      rules2024: ItemEditionDetails(
        summary: '+2 Shield AC.',
        description: '+2 Shield AC.',
      ),
      customProperties: {'isShield': true, 'acBonus': 2},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'longsword', ruleset: RulesetVersion.v2024),
      name: 'Longsword',
      itemType: 'Martial Melee Weapon',
      category: ItemCategory.weapon,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: 'Versatile 1d8 slashing (1d10 two-handed).',
      rules2014: ItemEditionDetails(
        summary: 'Versatile 1d8 slashing (1d10 two-handed).',
        description: 'Versatile 1d8 slashing (1d10 two-handed).',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Versatile 1d8 slashing (1d10 two-handed).',
        description: 'Versatile 1d8 slashing (1d10 two-handed).',
      ),
      customProperties: {
        'isWeapon': true,
        'damageFormula': '1d8',
        'damageType': 'slashing'
      },
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'greatsword', ruleset: RulesetVersion.v2024),
      name: 'Greatsword',
      itemType: 'Martial Melee Weapon',
      category: ItemCategory.weapon,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy, two-handed 2d6 slashing.',
      rules2014: ItemEditionDetails(
        summary: 'Heavy, two-handed 2d6 slashing.',
        description: 'Heavy, two-handed 2d6 slashing.',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Heavy, two-handed 2d6 slashing.',
        description: 'Heavy, two-handed 2d6 slashing.',
      ),
      customProperties: {
        'isWeapon': true,
        'damageFormula': '2d6',
        'damageType': 'slashing'
      },
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'shortsword', ruleset: RulesetVersion.v2024),
      name: 'Shortsword',
      itemType: 'Martial Melee Weapon',
      category: ItemCategory.weapon,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: 'Finesse, Light 1d6 piercing.',
      rules2014: ItemEditionDetails(
        summary: 'Finesse, Light 1d6 piercing.',
        description: 'Finesse, Light 1d6 piercing.',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Finesse, Light 1d6 piercing.',
        description: 'Finesse, Light 1d6 piercing.',
      ),
      customProperties: {
        'isWeapon': true,
        'isFinesse': true,
        'damageFormula': '1d6',
        'damageType': 'piercing'
      },
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'longbow', ruleset: RulesetVersion.v2024),
      name: 'Longbow',
      itemType: 'Martial Ranged Weapon',
      category: ItemCategory.weapon,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy, two-handed ranged weapon 1d8 piercing.',
      rules2014: ItemEditionDetails(
        summary: 'Heavy, two-handed ranged weapon 1d8 piercing.',
        description: 'Heavy, two-handed ranged weapon 1d8 piercing.',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Heavy, two-handed ranged weapon 1d8 piercing.',
        description: 'Heavy, two-handed ranged weapon 1d8 piercing.',
      ),
      customProperties: {
        'isWeapon': true,
        'isRanged': true,
        'damageFormula': '1d8',
        'damageType': 'piercing',
        'range': '150/600 ft',
      },
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'ring-of-protection', ruleset: RulesetVersion.v2024),
      name: 'Ring of Protection',
      itemType: 'Ring',
      category: ItemCategory.ring,
      rarity: 'Rare',
      rarityTier: ItemRarity.rare,
      requiresAttunement: true,
      descriptionMarkdown: '+1 AC and Saving Throws when attuned.',
      rules2014: ItemEditionDetails(
        summary: '+1 AC and Saving Throws when attuned.',
        description: '+1 AC and Saving Throws when attuned.',
      ),
      rules2024: ItemEditionDetails(
        summary: '+1 AC and Saving Throws when attuned.',
        description: '+1 AC and Saving Throws when attuned.',
      ),
      customProperties: {'acBonus': 1},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(
          slug: 'gauntlets-of-ogre-power', ruleset: RulesetVersion.v2024),
      name: 'Gauntlets of Ogre Power',
      itemType: 'Wondrous Item',
      category: ItemCategory.wondrousItem,
      rarity: 'Uncommon',
      rarityTier: ItemRarity.uncommon,
      requiresAttunement: true,
      descriptionMarkdown: 'Sets wearer Strength to 19.',
      rules2014: ItemEditionDetails(
        summary: 'Sets wearer Strength to 19.',
        description: 'Sets wearer Strength to 19.',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sets wearer Strength to 19.',
        description: 'Sets wearer Strength to 19.',
      ),
      customProperties: {
        'abilityOverrides': {'strength': 19}
      },
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'potion-of-healing', ruleset: RulesetVersion.v2024),
      name: 'Potion of Healing',
      itemType: 'Potion',
      category: ItemCategory.potion,
      rarity: 'Common',
      rarityTier: ItemRarity.common,
      requiresAttunement: false,
      descriptionMarkdown: 'Heals 2d4 + 2 HP.',
      rules2014: ItemEditionDetails(
        summary: 'Heals 2d4 + 2 HP.',
        description: 'Heals 2d4 + 2 HP.',
      ),
      rules2024: ItemEditionDetails(
        summary: 'Heals 2d4 + 2 HP.',
        description: 'Heals 2d4 + 2 HP.',
      ),
      customProperties: {},
    ));

    // Register all SRD Feats, Classes, Species, Backgrounds
    for (final feat in SrdFeatsLibrary.allFeats) {
      baseLayer.registerEntity(feat);
    }
    for (final cls in SrdClassesLibrary.allClasses) {
      baseLayer.registerEntity(cls);
    }
    for (final sp in SrdSpeciesLibrary.allSpecies) {
      baseLayer.registerEntity(sp);
    }
    for (final bg in SrdBackgroundsLibrary.allBackgrounds) {
      baseLayer.registerEntity(bg);
    }
    for (final eq in SrdEquipmentLibrary.allEquipmentItems) {
      baseLayer.registerEntity(eq);
    }

    repository.addLayer(baseLayer);
  }

