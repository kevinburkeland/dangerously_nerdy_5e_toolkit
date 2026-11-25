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
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy armor with Base AC 16.',
      customProperties: {'baseAc': 16, 'armorType': 'heavy'},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'leather-armor', ruleset: RulesetVersion.v2024),
      name: 'Leather Armor',
      itemType: 'Light Armor',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Light armor Base AC 11 + DEX modifier.',
      customProperties: {'baseAc': 11, 'armorType': 'light'},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'breastplate', ruleset: RulesetVersion.v2024),
      name: 'Breastplate',
      itemType: 'Medium Armor',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Medium armor Base AC 14 + DEX (max 2).',
      customProperties: {'baseAc': 14, 'armorType': 'medium', 'maxDexBonus': 2},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'shield', ruleset: RulesetVersion.v2024),
      name: 'Shield',
      itemType: 'Shield',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: '+2 Shield AC.',
      customProperties: {'isShield': true, 'acBonus': 2},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'longsword', ruleset: RulesetVersion.v2024),
      name: 'Longsword',
      itemType: 'Martial Melee Weapon',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Versatile 1d8 slashing (1d10 two-handed).',
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
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy, two-handed 2d6 slashing.',
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
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Finesse, Light 1d6 piercing.',
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
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy, two-handed ranged weapon 1d8 piercing.',
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
      rarity: 'Rare',
      requiresAttunement: true,
      descriptionMarkdown: '+1 AC and Saving Throws when attuned.',
      customProperties: {'acBonus': 1},
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(
          slug: 'gauntlets-of-ogre-power', ruleset: RulesetVersion.v2024),
      name: 'Gauntlets of Ogre Power',
      itemType: 'Wondrous Item',
      rarity: 'Uncommon',
      requiresAttunement: true,
      descriptionMarkdown: 'Sets wearer Strength to 19.',
      customProperties: {
        'abilityOverrides': {'strength': 19}
      },
    ));

    baseLayer.registerEntity(const EquipmentItem(
      id: EntityId(slug: 'potion-of-healing', ruleset: RulesetVersion.v2024),
      name: 'Potion of Healing',
      itemType: 'Potion',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heals 2d4 + 2 HP.',
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

